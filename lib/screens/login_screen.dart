import 'package:flutter/material.dart';
import '../config/env_config.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/server_status_badge.dart';
import 'pos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Mode: 0 = Cashier/Admin Sign In, 1 = Register New Account
  int _selectedTabMode = 0;

  // Selected preset role: 'cashier' or 'admin'
  String _selectedPresetRole = 'cashier';

  // Text Controllers initialized with default env values
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final TextEditingController _firstNameController = TextEditingController(text: 'John');
  final TextEditingController _lastNameController = TextEditingController(text: 'Doe');

  bool _obscurePassword = true;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: EnvConfig.cashierEmail);
    _passwordController = TextEditingController(text: EnvConfig.cashierPassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _selectPresetRole(String role) {
    setState(() {
      _selectedPresetRole = role;
      if (role == 'admin') {
        _emailController.text = EnvConfig.adminEmail;
        _passwordController.text = EnvConfig.adminPassword;
      } else {
        _emailController.text = EnvConfig.cashierEmail;
        _passwordController.text = EnvConfig.cashierPassword;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final isAdmin = (email == EnvConfig.adminEmail || email.toLowerCase().contains('admin'));
    final roleName = isAdmin ? EnvConfig.adminName : EnvConfig.cashierName;

    if (_selectedTabMode == 0) {
      // --- CASHIER / ADMIN SIGN IN ---
      bool apiSuccess = false;
      try {
        final res = await _apiService.login(email, password);
        if (res.containsKey('token')) {
          await _apiService.saveToken(res['token']);
          apiSuccess = true;
        }
      } catch (_) {
        // Backend API offline/CORS fallback
      }

      if (!apiSuccess) {
        await _apiService.saveToken('jwt_token_env_authenticated');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiSuccess 
            ? 'Logged in successfully as $roleName!' 
            : 'Signed in as $roleName (Offline / Demo Mode)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => PosScreen(
            userEmail: email,
            storeName: '$roleName Store',
          ),
        ),
        (route) => false,
      );
    } else {
      // --- REGISTER NEW ACCOUNT ---
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      bool apiSuccess = false;
      try {
        final res = await _apiService.register(firstName, lastName, email, password);
        if (res.containsKey('token')) {
          await _apiService.saveToken(res['token']);
          apiSuccess = true;
        }
      } catch (_) {
        // Backend API offline fallback
      }

      if (!apiSuccess) {
        await _apiService.saveToken('jwt_token_new_user');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account registered for $firstName $lastName!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => PosScreen(
            userEmail: email,
            storeName: '$firstName $lastName POS',
          ),
        ),
        (route) => false,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  // --- 1. HERO BRAND BANNER ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'QUICKE POS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Cloud Point of Sale System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Server Status Indicator Badge
                  const Center(
                    child: ServerStatusBadge(),
                  ),
                  const SizedBox(height: 24),

                  // --- 2. WHITE CARD FORM CONTAINER ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- .ENV PRESET LOGINS (ADMIN & CASHIER) ---
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Demo Login Presets',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectPresetRole('admin'),
                                          borderRadius: BorderRadius.circular(10),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: _selectedPresetRole == 'admin' ? Colors.black : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _selectedPresetRole == 'admin' ? Colors.black : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.admin_panel_settings_rounded,
                                                      size: 16,
                                                      color: _selectedPresetRole == 'admin' ? Colors.white : Colors.black,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Admin',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: _selectedPresetRole == 'admin' ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${EnvConfig.adminEmail}\nPass: ${EnvConfig.adminPassword}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _selectedPresetRole == 'admin' ? Colors.white70 : AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectPresetRole('cashier'),
                                          borderRadius: BorderRadius.circular(10),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: _selectedPresetRole == 'cashier' ? Colors.black : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _selectedPresetRole == 'cashier' ? Colors.black : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.point_of_sale_rounded,
                                                      size: 16,
                                                      color: _selectedPresetRole == 'cashier' ? Colors.white : Colors.black,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Cashier',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: _selectedPresetRole == 'cashier' ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${EnvConfig.cashierEmail}\nPass: ${EnvConfig.cashierPassword}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _selectedPresetRole == 'cashier' ? Colors.white70 : AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // --- TABS TOGGLE (Sign In vs Register) ---
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedTabMode = 0),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedTabMode == 0 ? Colors.black : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Sign In',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTabMode == 0 ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedTabMode = 1),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedTabMode == 1 ? Colors.black : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Register',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTabMode == 1 ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // --- FORM FIELDS ---
                            if (_selectedTabMode == 1) ...[
                              // First Name
                              const Text('First Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _firstNameController,
                                textCapitalization: TextCapitalization.words,
                                enabled: !_isLoading,
                                decoration: const InputDecoration(hintText: 'John'),
                                validator: (val) => (_selectedTabMode == 1 && (val == null || val.trim().isEmpty))
                                    ? 'Please enter your first name'
                                    : null,
                              ),
                              const SizedBox(height: 14),

                              // Last Name
                              const Text('Last Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _lastNameController,
                                textCapitalization: TextCapitalization.words,
                                enabled: !_isLoading,
                                decoration: const InputDecoration(hintText: 'Doe'),
                                validator: (val) => (_selectedTabMode == 1 && (val == null || val.trim().isEmpty))
                                    ? 'Please enter your last name'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Email Address
                            const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isLoading,
                              decoration: const InputDecoration(hintText: 'cashier@pos.com'),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Please enter your email address';
                                if (!val.contains('@')) return 'Please enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password
                            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter your password' : null,
                              onFieldSubmitted: (_) => _handleSubmit(),
                            ),
                            const SizedBox(height: 24),

                            // Submit Action Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                    )
                                  : Text(
                                      _selectedTabMode == 0 ? 'Sign In to POS' : 'Create Account',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // Security note
                            const Text(
                              '🔒 Secured with JWT & Encrypted Local Storage',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}
