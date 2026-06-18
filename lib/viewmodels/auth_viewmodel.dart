import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../repositories/user_repository.dart';
import '../utils/invite_code_generator.dart';

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final UserRepository _userRepo;
  final FirebaseAuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  AuthStatus _status = AuthStatus.loading;
  String? _errorMessage;
  StreamSubscription? _userSubscription;

  bool isRegistered = false;
  String? pendingInviteCompanyId;
  String? pendingInviteCompanyName;
  bool isValidatingInvite = false;
  String? inviteError;

  AuthViewModel(this._userRepo, this._authService) {
    _initSession();
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser == null) {
        _cancelUserSubscription();
        _user = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      } else {
        _initSession();
      }
    });
  }

  UserModel? get user => _user;
  UserModel? get currentUser => _user; 
  String? get companyId => _user?.companyId; 
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _user != null;
  String? get role => _user?.role;

  Future<void> _initSession() async {
    try {
      final user = await _userRepo.getSessionUser();
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        _startUserSubscription(user.uid);
        notifyListeners();
        await updateFcmToken(user.uid);
      } else {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _startUserSubscription(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _userRepo.watchUserDoc(uid).listen((updatedUser) {
      _user = updatedUser;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error watching user doc: $e");
    });
  }

  void _cancelUserSubscription() {
    _userSubscription?.cancel();
    _userSubscription = null;
  }

  Future<void> checkAuthState() => _initSession();

  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final userCredential = await _authService.signIn(email, password);
      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception("Authentication failed");
      
      _user = await _userRepo.getUserDoc(uid);
      _status = AuthStatus.authenticated;
      _startUserSubscription(uid);
      notifyListeners();
      await updateFcmToken(uid);
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> registerCEO({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String companyName,
    required String city,
    required String address,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    isRegistered = false;
    notifyListeners();

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final companyRef = _firestore.collection('companies').doc();
      final companyId = companyRef.id;

      await companyRef.set({
        'id': companyId,
        'name': companyName.trim(),
        'companyName': companyName.trim(), 
        'registrationNumber': '', 
        'city': city.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'ceoUid': uid,
        'status': 'pending',
        'inviteCode': null,
        'createdAt': FieldValue.serverTimestamp(),
        'plan': 'free',
        'aiEnabled': false,
      });

      final userData = UserModel(
        uid: uid,
        email: email.trim(),
        name: fullName.trim(),
        role: 'CEO',
        companyId: companyId,
        phone: phone.trim(),
        city: city.trim(),
        address: address.trim(),
        status: 'pending',
        approved: false,
        createdAt: DateTime.now(),
      );

      await _userRepo.createUserDoc(uid, userData);
      _user = userData;
      isRegistered = true;
      _status = AuthStatus.authenticated;
      _startUserSubscription(uid);
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapAuthError(e);
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Registration failed. Please try again.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> registerSupplier({
    required String ownerName,
    required String businessName,
    required String email,
    required String password,
    required String phone,
    required String city,
    required String cnic,
    required String businessType,
    required String businessAddress,
    required List<String> categories,
    required int yearsInBusiness,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    isRegistered = false;
    notifyListeners();

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final userData = UserModel(
        uid: uid,
        email: email.trim(),
        name: ownerName.trim(),
        role: 'Supplier',
        companyId: '',
        phone: phone.trim(),
        city: city.trim(),
        address: businessAddress.trim(),
        cnic: cnic.trim(),
        businessType: businessType,
        status: 'pending',
        approved: false,
        createdAt: DateTime.now(),
      );

      await _userRepo.createUserDoc(uid, userData);

      // Save to suppliers collection with dual field names for maximum compatibility
      await _firestore.collection('suppliers').doc(uid).set({
        'id': uid,
        'name': businessName.trim(), 
        'businessName': businessName.trim(),
        'ownerName': ownerName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'contact': phone.trim(), 
        'city': city.trim(),
        'cnic': cnic.trim(),
        'businessType': businessType,
        'materialType': businessType, 
        'businessAddress': businessAddress.trim(),
        'categories': categories,
        'yearsInBusiness': yearsInBusiness,
        'status': 'pending',
        'onboardingComplete': false,
        'totalCompanies': 0,
        'rating': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _user = userData;
      isRegistered = true;
      _status = AuthStatus.authenticated;
      _startUserSubscription(uid);
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapAuthError(e);
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Registration failed. Please try again.';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> validateInviteCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      clearInviteValidation();
      return false;
    }

    isValidatingInvite = true;
    inviteError = null;
    notifyListeners();

    try {
      final query = await _firestore
          .collection('companies')
          .where('inviteCode', isEqualTo: trimmed)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        pendingInviteCompanyId = null;
        pendingInviteCompanyName = null;
        inviteError = 'Invalid invite code. Ask your CEO.';
        return false;
      }

      final doc = query.docs.first;
      pendingInviteCompanyId = doc.id;
      pendingInviteCompanyName = doc.data()['name'] ?? doc.data()['companyName'];
      inviteError = null;
      return true;
    } catch (e) {
      pendingInviteCompanyId = null;
      pendingInviteCompanyName = null;
      inviteError = 'Could not verify code. Check your connection.';
      return false;
    } finally {
      isValidatingInvite = false;
      notifyListeners();
    }
  }

  void clearInviteValidation() {
    inviteError = null;
    pendingInviteCompanyId = null;
    pendingInviteCompanyName = null;
    notifyListeners();
  }

  Future<void> registerFieldUser({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String inviteCode,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    isRegistered = false;
    notifyListeners();

    try {
      final valid = await validateInviteCode(inviteCode);
      if (!valid || pendingInviteCompanyId == null) {
        _status = AuthStatus.error;
        _errorMessage = inviteError ?? 'Invalid invite code. Ask your CEO.';
        return;
      }

      final companyId = pendingInviteCompanyId!;

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final userData = UserModel(
        uid: uid,
        email: email.trim(),
        name: fullName.trim(),
        role: 'field_user',
        companyId: companyId,
        phone: phone.trim(),
        city: '', 
        status: 'active', 
        approved: true,
        createdAt: DateTime.now(),
      );

      await _userRepo.createUserDoc(uid, userData);

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('fieldUsers')
          .doc(uid)
          .set({
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      _user = userData;
      isRegistered = true;
      _status = AuthStatus.authenticated;
      _startUserSubscription(uid);
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _mapAuthError(e);
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Registration failed. Please try again.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _userRepo.updateFcmToken(uid, token);
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      _cancelUserSubscription();
      await _userRepo.logout();
      _user = null;
      _status = AuthStatus.unauthenticated;
      isRegistered = false;
      pendingInviteCompanyId = null;
      pendingInviteCompanyName = null;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> signOut() => logout();

  Future<void> deleteAccount() async {
    try {
      final uid = _user?.uid;
      if (uid != null) {
        await _authService.deleteAccount();
        await logout();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password is too weak (minimum 8 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return e.message ?? 'Authentication error. Please try again.';
      }
    }
    return e.toString();
  }

  static String generateInviteCode() => InviteCodeGenerator.generate();

  @override
  void dispose() {
    _cancelUserSubscription();
    super.dispose();
  }
}
