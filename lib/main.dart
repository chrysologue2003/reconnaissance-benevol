import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/action_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_validation_page.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/post_action_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR', null);
  if (!kIsWeb) {
    await NotificationService().initialize();
  }
  runApp(const BenevolesApp());
}

class BenevolesApp extends StatelessWidget {
  const BenevolesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ActionProvider()),
      ],
      child: const BenevolesAppContent(),
    );
  }
}

class BenevolesAppContent extends StatefulWidget {
  const BenevolesAppContent({super.key});

  @override
  State<BenevolesAppContent> createState() => _BenevolesAppContentState();
}

class _BenevolesAppContentState extends State<BenevolesAppContent> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final location = state.matchedLocation;
        final loggingIn = location == '/login' || location == '/register' || location == '/splash' || location == '/forgot-password';
        if (!isLoggedIn && !loggingIn) {
          return '/login';
        }
        if (isLoggedIn && (location == '/login' || location == '/register' || location == '/splash' || location == '/forgot-password')) {
          return '/home';
        }
        if (location == '/admin' && !authProvider.isAdmin) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/post', builder: (context, state) => const PostActionScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
        GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
        GoRoute(path: '/admin', builder: (context, state) => const AdminDashboard()),
        GoRoute(path: '/admin/validation', builder: (context, state) => const AdminValidationPage()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'BénévolesApp',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
