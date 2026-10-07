import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthCheckWrapper(),
    );
  }
}

class AuthCheckWrapper extends StatefulWidget {
  const AuthCheckWrapper({super.key});

  @override
  State<AuthCheckWrapper> createState() => _AuthCheckWrapperState();
}

class _AuthCheckWrapperState extends State<AuthCheckWrapper> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final String _userEmail = 'admin@pos.com';

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    try {
      final token = await _apiService.getToken();
      if (token != null && token.isNotEmpty) {
        _isLoggedIn = true;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (_isLoggedIn) {
      return PosScreen(
        userEmail: _userEmail,
        storeName: 'MY SUPERMARKET POS',
      );
    }

    return const LoginScreen();
  }
}
