import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/cloudinary_service.dart';
import '../repositories/user_repository.dart';
import '../services/category_seed_service.dart';
import '../services/plan_limit_service.dart';
import '../utils/app_exception.dart';
import '../utils/invite_code_generator.dart';
import '../utils/pakistan_validators.dart';

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
        await CategorySeedService(_firestore).seedIfEmpty();
      } else {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _mapAuthError(e);
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
      final firebaseUser = userCredential.user;
      final uid = firebaseUser?.uid;
      if (uid == null) throw Exception("Authentication failed");

      await firebaseUser!.getIdToken(true);
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
    required String companyType,
    required int yearsInOperation,
    String? registrationNumber,
    required String designation,
    required String cnic,
    required String city,
    required String address,
    required String estimatedMonthlyVolume,
    required int activeSitesCount,
    required Uint8List cnicFrontBytes,
    required Uint8List cnicBackBytes,
    Uint8List? registrationCertBytes,
    Uint8List? officePhotoBytes,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    isRegistered = false;
    notifyListeners();

    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final companyRef = _firestore.collection('companies').doc();
      final companyId = companyRef.id;
      final uploadFolder = 'ratebridge/companies/$companyId';

      final cnicFrontUrl = await CloudinaryService.uploadImageBytes(
        bytes: cnicFrontBytes,
        folder: uploadFolder,
        filename: 'cnic_front.jpg',
      );
      final cnicBackUrl = await CloudinaryService.uploadImageBytes(
        bytes: cnicBackBytes,
        folder: uploadFolder,
        filename: 'cnic_back.jpg',
      );

      if (cnicFrontUrl == null || cnicBackUrl == null) {
        await cred.user?.delete();
        _status = AuthStatus.error;
        _errorMessage =
            'Could not upload CNIC photos. Please check your connection and try again.';
        return;
      }

      String? registrationCertUrl;
      String? officePhotoUrl;

      if (registrationCertBytes != null) {
        registrationCertUrl = await CloudinaryService.uploadImageBytes(
          bytes: registrationCertBytes,
          folder: uploadFolder,
          filename: 'registration_cert.jpg',
        );
      }
      if (officePhotoBytes != null) {
        officePhotoUrl = await CloudinaryService.uploadImageBytes(
          bytes: officePhotoBytes,
          folder: uploadFolder,
          filename: 'office_photo.jpg',
        );
      }

      final normalizedPhone = PakistanValidators.normalizePhone(phone);
      final normalizedCnic = PakistanValidators.digitsOnly(cnic);
      final trimmedRegNo = registrationNumber?.trim() ?? '';

      await companyRef.set({
        'id': companyId,
        'name': companyName.trim(),
        'companyName': companyName.trim(),
        'registrationNumber': trimmedRegNo,
        'companyType': companyType,
        'yearsInOperation': yearsInOperation,
        'ceoFullName': fullName.trim(),
        'designation': designation,
        'cnicNumber': normalizedCnic,
        'cnicFrontUrl': cnicFrontUrl,
        'cnicBackUrl': cnicBackUrl,
        'city': city.trim(),
        'address': address.trim(),
        'phone': normalizedPhone,
        'estimatedMonthlyVolume': estimatedMonthlyVolume,
        'activeSitesCount': activeSitesCount,
        if (registrationCertUrl != null)
          'registrationCertUrl': registrationCertUrl,
        if (officePhotoUrl != null) 'officePhotoUrl': officePhotoUrl,
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
        phone: normalizedPhone,
        city: city.trim(),
        address: address.trim(),
        cnic: normalizedCnic,
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
      await cred?.user?.delete();
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
    String? businessRegistrationNumber,
    required List<String> deliveryCoverageAreas,
    required Uint8List cnicFrontBytes,
    required Uint8List cnicBackBytes,
    Uint8List? shopPhotoBytes,
    Uint8List? businessLicenseBytes,
    Uint8List? certificationBytes,
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
      final uploadFolder = 'ratebridge/suppliers/$uid';

      final cnicFrontUrl = await CloudinaryService.uploadImageBytes(
        bytes: cnicFrontBytes,
        folder: uploadFolder,
        filename: 'cnic_front.jpg',
      );
      final cnicBackUrl = await CloudinaryService.uploadImageBytes(
        bytes: cnicBackBytes,
        folder: uploadFolder,
        filename: 'cnic_back.jpg',
      );

      if (cnicFrontUrl == null || cnicBackUrl == null) {
        await cred.user?.delete();
        _status = AuthStatus.error;
        _errorMessage =
            'Could not upload CNIC photos. Please check your connection and try again.';
        return;
      }

      String? shopPhotoUrl;
      String? businessLicenseUrl;
      String? certificationUrl;

      if (shopPhotoBytes != null) {
        shopPhotoUrl = await CloudinaryService.uploadImageBytes(
          bytes: shopPhotoBytes,
          folder: uploadFolder,
          filename: 'shop_photo.jpg',
        );
      }
      if (businessLicenseBytes != null) {
        businessLicenseUrl = await CloudinaryService.uploadImageBytes(
          bytes: businessLicenseBytes,
          folder: uploadFolder,
          filename: 'business_license.jpg',
        );
      }
      if (certificationBytes != null) {
        certificationUrl = await CloudinaryService.uploadImageBytes(
          bytes: certificationBytes,
          folder: uploadFolder,
          filename: 'certification.jpg',
        );
      }

      if (shopPhotoUrl == null &&
          businessLicenseUrl == null &&
          certificationUrl == null) {
        await cred.user?.delete();
        _status = AuthStatus.error;
        _errorMessage =
            'Upload at least one business proof document (shop photo, license, or certification).';
        return;
      }

      final normalizedPhone = PakistanValidators.normalizePhone(phone);
      final normalizedCnic = PakistanValidators.formatCnic(cnic);
      final trimmedNtn = businessRegistrationNumber?.trim();
      final declaredCategories = categories;

      final userData = UserModel(
        uid: uid,
        email: email.trim(),
        name: ownerName.trim(),
        role: 'Supplier',
        companyId: '',
        phone: normalizedPhone,
        city: city.trim(),
        address: businessAddress.trim(),
        cnic: normalizedCnic,
        businessType: businessType,
        status: 'pending',
        approved: false,
        createdAt: DateTime.now(),
      );

      await _userRepo.createUserDoc(uid, userData);

      await _firestore.collection('suppliers').doc(uid).set({
        'id': uid,
        'name': businessName.trim(),
        'businessName': businessName.trim(),
        'ownerName': ownerName.trim(),
        'ownerFullName': ownerName.trim(),
        'email': email.trim(),
        'phone': normalizedPhone,
        'contact': normalizedPhone,
        'city': city.trim(),
        'cnic': normalizedCnic,
        'cnicNumber': normalizedCnic,
        'cnicFrontUrl': cnicFrontUrl,
        'cnicBackUrl': cnicBackUrl,
        'businessType': businessType,
        'materialType': businessType,
        'businessAddress': businessAddress.trim(),
        'deliveryCoverageAreas': deliveryCoverageAreas,
        'categories': declaredCategories,
        'declaredCategories': declaredCategories,
        'yearsInBusiness': yearsInBusiness,
        if (trimmedNtn != null && trimmedNtn.isNotEmpty)
          'businessRegistrationNumber': trimmedNtn,
        if (shopPhotoUrl != null) 'shopPhotoUrl': shopPhotoUrl,
        if (businessLicenseUrl != null) 'businessLicenseUrl': businessLicenseUrl,
        if (certificationUrl != null) 'certificationUrl': certificationUrl,
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
      await CategorySeedService(_firestore).seedIfEmpty();
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
        inviteError =
            'Invalid invite code. Confirm the code from your CEO and that the company is approved.';
        return false;
      }

      final doc = query.docs.first;
      pendingInviteCompanyId = doc.id;
      pendingInviteCompanyName =
          doc.data()['name'] ?? doc.data()['companyName'];
      inviteError = null;
      return true;
    } on FirebaseException catch (e) {
      pendingInviteCompanyId = null;
      pendingInviteCompanyName = null;
      if (e.code == 'permission-denied') {
        inviteError =
            'Could not verify code. Firestore access denied — deploy the latest security rules.';
      } else if (e.code == 'failed-precondition') {
        inviteError =
            'Could not verify code. Firestore index is building — try again in a minute.';
      } else {
        inviteError = 'Could not verify code. Check your connection.';
      }
      return false;
    } catch (_) {
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
    required String cnicNumber,
    required String jobTitle,
    required String assignedSite,
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

      // Count only active field users. Missing companies fail closed rather
      // than allowing an unbounded registration.
      await PlanLimitService.ensureFieldUserCapacity(_firestore, companyId);

      final normalizedPhone = PakistanValidators.normalizePhone(phone);
      final normalizedCnic = PakistanValidators.formatCnic(cnicNumber);

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
        phone: normalizedPhone,
        city: '',
        cnic: normalizedCnic,
        jobTitle: jobTitle.trim(),
        assignedSite: assignedSite.trim(),
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
        'phone': normalizedPhone,
        'cnicNumber': normalizedCnic,
        'jobTitle': jobTitle.trim(),
        'assignedSite': assignedSite.trim(),
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      _user = userData;
      isRegistered = true;
      _status = AuthStatus.authenticated;
      _startUserSubscription(uid);
    } on AppException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
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
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) await _userRepo.updateFcmToken(uid, token);
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }

  Future<void> clearFcmToken(String uid) async {
    try {
      await _userRepo.updateFcmToken(uid, null);
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } catch (e) {
      return _mapAuthError(e);
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return _mapAuthError(e);
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
        case 'requires-recent-login':
          return 'Please sign out and sign in again, then retry changing your password.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return e.message ?? 'Authentication error. Please try again.';
      }
    }
    if (e is FirebaseException && e.plugin == 'cloud_firestore') {
      if (e.code == 'permission-denied') {
        return 'Could not load your profile. Ask an admin to verify your account exists in Firestore.';
      }
    }
    final message = e.toString();
    if (message.contains('User model not found')) {
      return 'Signed in, but no profile was found. Please register or contact your company admin.';
    }
    return message;
  }

  static String generateInviteCode() => InviteCodeGenerator.generate();

  @override
  void dispose() {
    _cancelUserSubscription();
    super.dispose();
  }
}
