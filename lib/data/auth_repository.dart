import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app/config.dart';
import '../domain/models.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(
    clientId: Platform.isIOS && AppConfig.iosClientId.isNotEmpty
        ? AppConfig.iosClientId
        : null,
    serverClientId: AppConfig.webClientId.isEmpty
        ? null
        : AppConfig.webClientId,
  );
  Stream<User?> get changes => _auth.authStateChanges();
  Future<void> email(
    String email,
    String password, {
    bool register = false,
  }) async {
    if (register) {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } else {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  Future<void> google() async {
    final account = await _google.signIn();
    if (account == null) return;
    final credentials = await account.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: credentials.accessToken,
        idToken: credentials.idToken,
      ),
    );
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
  Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }

  static String message(Object error) {
    if (error is AppFailure) return error.message;
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Revisa el correo electrónico.',
        'weak-password' => 'Elige una contraseña de al menos seis caracteres.',
        'email-already-in-use' =>
          'Este correo ya tiene una cuenta. Usa Iniciar sesión.',
        'network-request-failed' => 'Se necesita conexión para iniciar sesión.',
        'too-many-requests' => 'Espera un momento antes de volver a intentar.',
        _ =>
          'No se pudo iniciar sesión. Revisa tus datos y vuelve a intentarlo.',
      };
    }
    return 'No se pudo completar la operación. Vuelve a intentarlo.';
  }
}
