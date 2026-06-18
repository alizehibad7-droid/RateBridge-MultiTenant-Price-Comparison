import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirebaseAuthService _authService;
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserModel? _cachedUser;

  UserRepository(this._authService, this._firestoreService);

  UserModel? get cachedUser => _cachedUser;

  Future<UserModel?> getSessionUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      _cachedUser = null;
      return null;
    }
    
    final user = await _firestoreService.getUser(firebaseUser.uid);
    _cachedUser = user;
    return user;
  }

  Future<UserModel?> login(String email, String password) async {
    final user = await _authService.login(email, password);
    _cachedUser = user;
    return user;
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String companyId,
    String? phoneNumber,
    String status = 'active',
  }) async {
    final user = await _authService.register(
      email: email,
      password: password,
      name: name,
      role: role,
      companyId: companyId,
      phone: phoneNumber ?? '',
      status: status,
    );
    _cachedUser = user;
    return user;
  }

  Future<void> logout() async {
    _cachedUser = null;
    await _authService.signOut();
  }

  // --- Requested API methods ---

  Future<void> createUserDoc(String uid, UserModel user) async {
    await _firestoreService.saveUser(user);
    _cachedUser = user;
  }

  Future<UserModel> getUserDoc(String uid) async {
    final user = await _firestoreService.getUser(uid);
    if (user == null) {
      throw Exception("User model not found for UID: $uid");
    }
    _cachedUser = user;
    return user;
  }

  Stream<UserModel> watchUserDoc(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw Exception("User doc does not exist");
      }
      return UserModel.fromMap(doc.data()!);
    });
  }

  Future<void> updateUserDoc(String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
    if (_cachedUser != null && _cachedUser!.uid == uid) {
      _cachedUser = await _firestoreService.getUser(uid);
    }
  }

  Future<void> updateFcmToken(String uid, String? token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
    if (_cachedUser != null && _cachedUser!.uid == uid) {
      _cachedUser = _cachedUser!.copyWith(fcmToken: token);
    }
  }

  Future<void> deleteUserDoc(String uid) async {
    await _db.collection('users').doc(uid).delete();
    if (_cachedUser?.uid == uid) {
      _cachedUser = null;
    }
  }
}
