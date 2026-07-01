import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService;

  FirebaseAuthService(this._firestoreService);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createUser(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> deleteAccount() async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.delete();
    }
  }

  Future<UserModel?> login(String email, String password) async {
    final credential = await signIn(email, password);
    if (credential.user != null) {
      return await _firestoreService.getUser(credential.user!.uid);
    }
    return null;
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String companyId,
    String phone = '',
    String city = '',
    String status = 'active',
  }) async {
    final credential = await createUser(email, password);

    final userModel = UserModel(
      uid: credential.user!.uid,
      email: email,
      name: name,
      role: role,
      companyId: companyId,
      phone: phone,
      city: city,
      status: status,
      createdAt: DateTime.now(),
    );

    await _firestoreService.saveUser(userModel);
    return userModel;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user found.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}
