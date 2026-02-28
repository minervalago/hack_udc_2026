import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<bool> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
