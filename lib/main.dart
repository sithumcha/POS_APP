import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  OfflineSyncService().startPeriodicSync();
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
  String _userEmail = '';
  String _storeName = 'POS STORE';

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    try {
      final token = await _apiService.getToken();
      if (token != null && token.isNotEmpty) {
        final userInfo = await _apiService.getUserInfo();
        _isLoggedIn = true;
        if (userInfo != null) {
          _userEmail = userInfo['email']?.toString() ?? '';
          _storeName = userInfo['store_name']?.toString() ?? 'POS STORE';
        }
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
        storeName: _storeName,
      );
    }

    return const LoginScreen();
  }
}
