import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/store_setup_screen.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/security_check_service.dart';
import 'theme/app_theme.dart';
import 'utils/web_splash_helper.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Device Integrity & Anti-Screen-Recording Security Guard
  final isDeviceSecure = await SecurityCheckService.verifyDeviceIntegrity();

  // 2. Setup global 401 Unauthorized Auto-Logout handler
  ApiService.onSessionExpired = () {
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  // 3. Fast launch: mount app UI immediately without blocking on peripheral services
  runApp(PosApp(isDeviceSecure: isDeviceSecure));

  // 4. Concurrently initialize non-critical services in background
  Future.microtask(() async {
    try {
      await NotificationService().initialize();
      await PermissionService().requestAllAppPermissions();
      OfflineSyncService().startPeriodicSync();
    } catch (e) {
      debugPrint('Background init error: $e');
    }
  });
}

class PosApp extends StatelessWidget {
  final bool isDeviceSecure;
  const PosApp({super.key, this.isDeviceSecure = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'POS App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isDeviceSecure ? const AuthCheckWrapper() : const DeviceCompromisedScreen(),
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
  bool _isChecking = true;
  bool _isLoggedIn = false;
  bool _isStoreSetupDone = true;
  String _userEmail = '';
  String _storeName = 'POS STORE';

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removeWebSplash();
    });
  }

  Future<void> _checkSavedSession() async {
    try {
      final token = await _apiService.getToken();
      if (token != null && token.isNotEmpty) {
        final userInfo = await _apiService.getUserInfo();
        if (userInfo != null && userInfo.isNotEmpty && (userInfo['email'] ?? '').toString().isNotEmpty) {
          final role = (userInfo['role'] ?? '').toString().toLowerCase();
          final isStaff = role.contains('cashier') || role.contains('staff') || role.contains('employee');
          final storeName = (userInfo['store_name'] ?? '').toString().trim();
          final email = (userInfo['email'] ?? '').toString().trim();

          // INSTANT check: if user already has an active store name, onboarding is complete!
          // This avoids waiting for slow network timeouts or remote API calls on refresh.
          final hasValidStore = storeName.isNotEmpty &&
              storeName != 'Admin Store' &&
              storeName != 'User Store' &&
              storeName != 'POS STORE';

          bool setupDone = isStaff || hasValidStore;
          if (!setupDone) {
            setupDone = await _apiService.isStoreSetupCompleted();
          }

          if (!mounted) return;
          setState(() {
            _isLoggedIn = true;
            _userEmail = email;
            _storeName = storeName.isNotEmpty ? storeName : 'POS STORE';
            _isStoreSetupDone = setupDone;
            _isChecking = false;
          });

          // Dismiss splash as soon as session is restored and first frame paints
          WidgetsBinding.instance.addPostFrameCallback((_) {
            removeWebSplash();
          });
          return;
        } else {
          await _apiService.clearToken();
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _isChecking = false;
    });

    // Dismiss splash when switching to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removeWebSplash();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. While reading saved session credentials, display clean branded loader (NO blank white screen!)
    if (_isChecking) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C076).withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFF00C076).withOpacity(0.15)),
                ),
                padding: const EdgeInsets.all(14),
                child: const CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C076)),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Connecting to POS Terminal...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                  letterSpacing: 0.02,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. User is logged in: direct them immediately to the active POS or Setup Screen
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

    // 3. Not logged in: directly render LoginScreen
    return const LoginScreen();
  }
}

/// Screen displayed when app is launched on a rooted / jailbroken device
class DeviceCompromisedScreen extends StatelessWidget {
  const DeviceCompromisedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withOpacity(0.35), width: 2),
                ),
                child: const Icon(Icons.gpp_bad_rounded, size: 48, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'Security Alert',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This device appears to be Rooted or Jailbroken. To protect sensitive customer payment transactions and merchant keys, POS operations are disabled on modified environments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                  label: const Text(
                    'Exit Application',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

