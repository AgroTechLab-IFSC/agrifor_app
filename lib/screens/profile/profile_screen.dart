import 'package:flutter/material.dart';
import 'package:agrifor_app/controllers/user_profile_controller.dart';
import 'package:agrifor_app/models/app_user_model.dart';
// ajuste este import se o caminho do seu AuthController for diferente
import 'package:agrifor_app/controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileController _profileController = UserProfileController();
  final AuthController _authController = AuthController();

  @override
  void dispose() {
    _profileController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) _authController.signOut();
  }

  String _roleLabel(UserRole role) {
    return role == UserRole.admin ? 'Administrador' : 'Produtor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: _profileController,
        builder: (context, _) {
          final profile = _profileController.profile;

          if (_profileController.loading || profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text(
                    profile.email.isNotEmpty ? profile.email[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  profile.email,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _roleLabel(profile.role),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 32),
              if (profile.isProducer && profile.propertyId == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    'Sua conta ainda não está vinculada a nenhuma '
                    'propriedade. Entre em contato com o administrador.',
                    style: TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sair', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}