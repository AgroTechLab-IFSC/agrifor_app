import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'widgets/main_shell.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agrifor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/home', // MainShell decide o que mostrar (visitante/produtor/admin)
      routes: {
        '/login':    (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home':     (_) => const MainShell(),
      },
    );
  }
}