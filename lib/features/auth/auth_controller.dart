import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  final AuthService _service = AuthService();

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;
  User? user;

  void loadCurrentUser() {
    user = _service.currentUser;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      user = await _service.signInWithGoogle();
      status = user != null ? AuthStatus.success : AuthStatus.idle;
    } catch (e) {
      errorMessage = 'Erro ao fazer login com Google. Tente novamente.';
      status = AuthStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      user = await _service.signInWithEmail(email: email, password: password);
      status = user != null ? AuthStatus.success : AuthStatus.idle;
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapFirebaseError(e.code);
      status = AuthStatus.error;
    } catch (e) {
      errorMessage = 'Erro ao fazer login. Tente novamente.';
      status = AuthStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> registerWithEmail({required String name, required String email, required String password}) async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      user = await _service.registerWithEmail(name: name, email: email, password: password);
      status = user != null ? AuthStatus.success : AuthStatus.idle;
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapFirebaseError(e.code);
      status = AuthStatus.error;
    } catch (e) {
      errorMessage = 'Erro ao criar conta. Tente novamente.';
      status = AuthStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    user = null;
    status = AuthStatus.idle;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Este e-mail já está em uso.';
      case 'invalid-email':        return 'E-mail inválido.';
      case 'weak-password':        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'user-not-found':       return 'Usuário não encontrado.';
      case 'wrong-password':       return 'Senha incorreta.';
      case 'too-many-requests':    return 'Muitas tentativas. Tente novamente mais tarde.';
      default:                     return 'Ocorreu um erro. Tente novamente.';
    }
  }
}