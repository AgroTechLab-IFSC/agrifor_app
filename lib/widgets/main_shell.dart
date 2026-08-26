// lib/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:agrifor_app/controllers/user_profile_controller.dart';
import 'package:agrifor_app/services/auth_service.dart';
import 'package:agrifor_app/screens/auth/login_screen.dart';
import 'package:agrifor_app/screens/home/home_screen.dart';
import 'package:agrifor_app/screens/property/properties_screen.dart';
import 'package:agrifor_app/screens/property/my_property_screen.dart';
import 'package:agrifor_app/screens/admin/admin_dashboard_screen.dart';
import 'package:agrifor_app/screens/admin/admin_categories_screen.dart';

// Mesmo verde usado no header do Login e nas outras telas (0xFF2E7D32)
// — sem isso, o AppBar cai no verde claro que o Material 3 gera
// sozinho a partir do ColorScheme do app.
const _kBrandGreen = Color(0xFF2E7D32);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final UserProfileController _profileController = UserProfileController();

  @override
  void dispose() {
    _profileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _profileController,
      builder: (context, _) {
        if (_profileController.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_profileController.isLoggedIn) {
          return const _PublicShell();
        }

        if (_profileController.isAdmin) {
          return const _AdminShell();
        }

        return const _ProducerShell();
      },
    );
  }
}

/// Visitante: sem login, sem opção de edição em lugar nenhum.
class _PublicShell extends StatefulWidget {
  const _PublicShell();

  @override
  State<_PublicShell> createState() => _PublicShellState();
}

class _PublicShellState extends State<_PublicShell> {
  int _index = 0;

  // Não é mais `static const`: SearchScreen deixou de ter construtor
  // const (agora recebe repositórios opcionais e resolve defaults no
  // initializer), então a lista de telas não é mais uma constante de
  // compilação. Instanciada uma vez aqui no State, não a cada build.
  final _screens = [const HomeScreen(), PropertiesScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kBrandGreen,
        foregroundColor: Colors.white,
        title: const Text('Agrifor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Entrar',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFF2E7D32),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
        ],
      ),
    );
  }
}

/// Produtor: mapa + buscar + própria propriedade. Sem aba de perfil —
/// logout fica no AppBar.
class _ProducerShell extends StatefulWidget {
  const _ProducerShell();

  @override
  State<_ProducerShell> createState() => _ProducerShellState();
}

class _ProducerShellState extends State<_ProducerShell> {
  int _index = 0;
  final _auth = AuthService();

  // Mesma razão do _PublicShellState: SearchScreen não é mais const,
  // então a lista de telas também não pode ser.
  final _screens = [
    const HomeScreen(),
    PropertiesScreen(),
    const MyPropertyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kBrandGreen,
        foregroundColor: Colors.white,
        title: const Text('Agrifor'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.red,
            ), // vermelho, ação de sair da conta
            tooltip: 'Sair',
            onPressed: _auth.signOut,
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFF2E7D32),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(
            icon: Icon(Icons.agriculture_outlined),
            label: 'Minha Propriedade',
          ),
        ],
      ),
    );
  }
}

/// Admin: painel + propriedades + categorias. Sem mapa, sem perfil.
/// Não existe mais aba "Produtores" separada — o vínculo de produtor
/// foi consolidado dentro de Propriedades. Também não existe mais
/// AdminPropertiesScreen: a mesma PropertiesScreen usada pelo público
/// e pelo produtor resolve as ações de admin internamente (ver
/// PropertiesScreen — decide via role do usuário logado, não por uma
/// flag externa).
class _AdminShell extends StatefulWidget {
  const _AdminShell();

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _index = 0;
  final _auth = AuthService();

  // Não é mais static const: PropertiesScreen não tem construtor
  // const (mesma razão do _PublicShellState/_ProducerShellState).
  final _screens = [
    const AdminDashboardScreen(),
    PropertiesScreen(),
    const AdminCategoriesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kBrandGreen,
        foregroundColor: Colors.white,
        title: const Text('Agrifor — Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _auth.signOut,
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFF2E7D32),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Painel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.landscape_outlined),
            label: 'Propriedades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            label: 'Categorias',
          ),
        ],
      ),
    );
  }
}