import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:agrifor_app/repositories/user_repository.dart';

class AuthService {
  AuthService({UserRepository? userRepository, GoogleSignIn? googleSignIn})
      : _userRepository =
            userRepository ?? UserRepository(FirebaseFirestore.instance),
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureProducerDoc(
      userCredential.user,
      name: googleUser.displayName,
    );
    return userCredential.user;
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // autocura: garante o doc /users/{uid} mesmo se ele não tiver sido
    // criado corretamente no cadastro (ex: app fechou no meio do processo).
    // Não temos o "nome completo" digitado no cadastro aqui — só um
    // fallback de emergência baseado no displayName do Auth (se existir)
    // ou no prefixo do e-mail.
    await _ensureProducerDoc(
      userCredential.user,
      name: userCredential.user?.displayName,
    );
    return userCredential.user;
  }

  Future<User?> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await userCredential.user?.updateDisplayName(name);
    await userCredential.user?.reload();
    await _ensureProducerDoc(_auth.currentUser, name: name);
    return _auth.currentUser;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Garante o doc inicial em /users/{uid}, mas NUNCA sobrescreve um
  /// usuário que já existe (ex: já vinculado a uma propriedade, ou
  /// promovido a admin). Sempre cria como 'producer' com propertyId
  /// null — único formato aceito pelas Firestore rules no self-signup.
  ///
  /// [name] é o "nome completo" já conhecido nesse ponto do fluxo
  /// (digitado no cadastro, ou vindo do displayName do Google/Auth).
  /// Se vier nulo ou em branco, cai no fallback do prefixo do e-mail
  /// para nunca travar o login por falta de nome.
  Future<void> _ensureProducerDoc(User? user, {String? name}) async {
    if (user == null || user.email == null) return;
    final existing = await _userRepository.getById(user.uid);
    if (existing != null) return;

    final resolvedName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : user.email!.split('@').first;

    await _userRepository.createProducerDoc(
      uid: user.uid,
      email: user.email!,
      name: resolvedName,
    );
  }
}