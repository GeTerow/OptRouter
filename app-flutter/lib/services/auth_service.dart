import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmedName);
    }
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  static String messageFor(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'Este e-mail já está cadastrado.',
      'invalid-email' => 'Informe um e-mail válido.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' =>
        'E-mail ou senha inválidos.',
      'network-request-failed' =>
        'Não foi possível conectar. Verifique sua internet e tente novamente.',
      'operation-not-allowed' =>
        'O login por e-mail e senha ainda não está habilitado no Firebase.',
      'too-many-requests' =>
        'Muitas tentativas em sequência. Aguarde um pouco e tente novamente.',
      'user-disabled' => 'Esta conta foi desativada.',
      'weak-password' => 'Use uma senha com pelo menos 6 caracteres.',
      _ => 'Não foi possível autenticar. Tente novamente.',
    };
  }
}
