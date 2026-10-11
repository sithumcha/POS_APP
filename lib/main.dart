import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/store_setup_screen.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  await PermissionService().requestAllAppPermissions();
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
  bool _isStoreSetupDone = true;
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

          final role = (userInfo['role'] ?? '').toString().toLowerCase();
          final isStaff = role.contains('cashier') || role.contains('staff') || role.contains('employee');

          if (!isStaff) {
            _isStoreSetupDone = await _apiService.isStoreSetupCompleted();
          } else {
            _isStoreSetupDone = true;
          }
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
      if (!_isStoreSetupDone) {
        return StoreSetupScreen(
          userEmail: _userEmail,
          initialStoreName: (_storeName.isNotEmpty &&
                  _storeName != 'POS STORE' &&
                  _storeName != 'Admin Store' &&
                  _storeName != 'User Store')
              ? _storeName
              : '',
        );
      }
      return PosScreen(
        userEmail: _userEmail,
        storeName: _storeName,
      );
    }

    return const LoginScreen();
  }
}
