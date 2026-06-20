import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _waitForAuthAndRedirect();
  }

  Future<void> _waitForAuthAndRedirect() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Attendre que AuthProvider soit initialisé (document Firestore chargé)
    // Timeout de sécurité de 5 secondes maximum
    const maxWait = Duration(seconds: 5);
    const pollInterval = Duration(milliseconds: 100);
    final deadline = DateTime.now().add(maxWait);

    while (!authProvider.initialized && DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollInterval);
    }

    if (!mounted) return;

    // go_router gère la redirection via son redirect() — on navigue simplement
    // vers /home si connecté, /login sinon. Le redirect() dans main.dart
    // corrigera si nécessaire.
    if (authProvider.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.volunteer_activism, size: 96, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'BénévolesApp',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Reconnaissance des actions positives',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.green),
          ],
        ),
      ),
    );
  }
}