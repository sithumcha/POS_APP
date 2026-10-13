import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/store_setup_screen.dart';
import 'services/api_service.dart';
import 'services/offline_sync_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/security_check_service.dart';
import 'theme/app_theme.dart';

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

  await NotificationService().initialize();
  await PermissionService().requestAllAppPermissions();
  OfflineSyncService().startPeriodicSync();

  runApp(PosApp(isDeviceSecure: isDeviceSecure));
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
        if (userInfo != null && userInfo.isNotEmpty && (userInfo['email'] ?? '').toString().isNotEmpty) {
          _isLoggedIn = true;
          _userEmail = userInfo['email']?.toString() ?? '';
          _storeName = userInfo['store_name']?.toString() ?? 'POS STORE';

          final role = (userInfo['role'] ?? '').toString().toLowerCase();
          final isStaff = role.contains('cashier') || role.contains('staff') || role.contains('employee');

          if (!isStaff) {
            _isStoreSetupDone = await _apiService.isStoreSetupCompleted();
          } else {
            _isStoreSetupDone = true;
          }
        } else {
          // Orphaned token without valid user profile -> clear session
          await _apiService.clearToken();
          _isLoggedIn = false;
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (_) {
      _isLoggedIn = false;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const TerminalInitializingScreen();
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

/// Modern Emerald / Mint Terminal Initializing Screen (Mirrors Web Splash Screen)
class TerminalInitializingScreen extends StatelessWidget {
  const TerminalInitializingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FA), Color(0xFFFAFCFD), Color(0xFFEDF6F2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 10),
              // Brand Presentation & Progress Core
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emerald Glow Icon Box
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C076).withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Center(
                          child: Icon(Icons.flash_on_rounded, size: 52, color: Color(0xFF00C076)),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C076),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // App Brand Title
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Quicke',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'App',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF00C076),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SELL SMARTER, GROW FASTER.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Cloud Gateway Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00C076),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cloud Gateway Connected',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  // Animated Progress Bar
                  Container(
                    width: 240,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C076)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C076),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Starting QuickeApp POS...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Security Signature Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 5),
                    Text(
                      'End-to-End Encrypted POS System',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
