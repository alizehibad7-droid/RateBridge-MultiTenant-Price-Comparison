import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';

class ActiveCompanyInvite {
  final String companyId;
  final String? companyName;
  final String? plan;

  const ActiveCompanyInvite({
    required this.companyId,
    this.companyName,
    this.plan,
  });
}

class UserRepository {
  final FirebaseAuthService _authService;
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;
  UserModel? _cachedUser;

  UserRepository(
    this._authService,
    this._firestoreService, {
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  UserModel? get cachedUser => _cachedUser;

  Future<UserModel?> getSessionUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      _cachedUser = null;
      return null;
    }

    // Web can fire auth state before the ID token is attached to Firestore.
    await firebaseUser.getIdToken();

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
      final data = Map<String, dynamic>.from(doc.data()!);
      // Ensure uid is set from document ID
      if (data['uid'] == null || data['uid'].toString().isEmpty) {
        data['uid'] = doc.id;
      }
      return UserModel.fromMap(data);
    });
  }

  Future<void> updateUserDoc(String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
    if (_cachedUser != null && _cachedUser!.uid == uid) {
      _cachedUser = await _firestoreService.getUser(uid);
    }
  }

  Future<void> updateFcmToken(String uid, String? token) async {
    if (token == null) {
      // Clear all tokens on logout if desired, or just do nothing if we want to keep them.
      // Usually we just stop sending if the token expires.
      // But user specifically asked for "Each user document should store an FCM token array".
      await _db.collection('users').doc(uid).update({'fcmTokens': []});
      if (_cachedUser != null && _cachedUser!.uid == uid) {
        _cachedUser = _cachedUser!.copyWith(fcmTokens: <String>[]);
      }
    } else {
      await _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token])
      });
      if (_cachedUser != null && _cachedUser!.uid == uid) {
        final currentTokens = List<String>.from(_cachedUser!.fcmTokens);
        if (!currentTokens.contains(token)) {
          currentTokens.add(token);
        }
        _cachedUser = _cachedUser!.copyWith(fcmTokens: currentTokens);
      }
    }
  }

  Future<void> deleteUserDoc(String uid) async {
    await _db.collection('users').doc(uid).delete();
    if (_cachedUser?.uid == uid) {
      _cachedUser = null;
    }
  }

  Future<ActiveCompanyInvite?> findActiveCompanyByInviteCode(String code) async {
    final query = await _db
        .collection('companies')
        .where('inviteCode', isEqualTo: code)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();
    return ActiveCompanyInvite(
      companyId: doc.id,
      companyName: (data['name'] ?? data['companyName']) as String?,
      plan: data['plan'] as String? ?? 'free',
    );
  }

  Future<void> linkFieldUserToCompany({
    required String companyId,
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required String cnicNumber,
    required String jobTitle,
    required String assignedSite,
  }) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('fieldUsers')
        .doc(uid)
        .set({
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'cnicNumber': cnicNumber,
      'jobTitle': jobTitle,
      'assignedSite': assignedSite,
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }
}
