import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  User? get user => _auth.currentUser;
  bool get isLoggedIn => user != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AuthService() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _translateError(e.code);
    }
  }

  Future<String?> registerWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _translateError(e.code);
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return 'Anulowano';
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return null;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return 'Błąd logowania przez Google';
    }
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    await user?.delete();
  }

  String _translateError(String code) {
    switch (code) {
      case 'user-not-found': return 'Nie znaleziono konta z tym emailem';
      case 'wrong-password': return 'Błędne hasło';
      case 'email-already-in-use': return 'Email jest już używany';
      case 'weak-password': return 'Hasło jest za słabe (min. 6 znaków)';
      case 'invalid-email': return 'Nieprawidłowy format email';
      case 'too-many-requests': return 'Za dużo prób. Spróbuj ponownie za chwilą';
      case 'operation-not-allowed': return 'Ta metoda logowania jest wyłączona';
      default: return 'Błąd logowania ($code)';
    }
  }
}
