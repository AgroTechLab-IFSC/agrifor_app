import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrifor_app/models/app_user_model.dart';
import 'package:agrifor_app/repositories/user_repository.dart';

/// Observa o estado de autenticação e mantém sincronizado o PERFIL
/// (role, propertyId) do usuário logado, lendo /users/{uid} em tempo
/// real.
///
/// Diferente do AuthController (que cuida de login/cadastro), este
/// controller só responde "quem está logado, e qual o perfil dele" —
/// é o que as telas usam pra decidir o que mostrar: navegação de
/// admin, de produtor, ou nada ainda (perfil carregando).
class UserProfileController extends ChangeNotifier {
  UserProfileController({UserRepository? userRepository})
      : _userRepository =
            userRepository ?? UserRepository(FirebaseFirestore.instance) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  final UserRepository _userRepository;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUserModel?>? _profileSub;

  AppUserModel? _profile;
  bool _loading = true;

  AppUserModel? get profile => _profile;
  bool get loading => _loading;
  bool get isLoggedIn => _profile != null;
  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get isProducer => _profile?.isProducer ?? false;

  void _onAuthChanged(User? user) {
    _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    _profileSub = _userRepository.watchById(user.uid).listen((profile) {
      _profile = profile;
      _loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}