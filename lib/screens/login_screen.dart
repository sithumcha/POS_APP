import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/server_status_badge.dart';
import '../widgets/ui_animation_helper.dart';
import 'pos_screen.dart';
import 'store_setup_screen.dart';

/// QuickeApp Authentication Screen (Sign In & Account Registration)
/// Supports cashier/staff direct login and store owner onboarding.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Global form key to trigger validation across form fields
  final _formKey = GlobalKey<FormState>();

  // Tracks active mode: 0 = Sign In, 1 = Register
  int _selectedTabMode = 0;

  // Text editing controllers for user input fields
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  // Password visibility toggle flag
  bool _obscurePassword = true;

  // Loading state flag to prevent concurrent multiple API requests
  bool _isLoading = false;

  // Security policy checkbox state for registration mode
  bool _agreedToTerms = true;

  // API service singleton instance for backend communication
  final ApiService _apiService = ApiService();

  // Floating animation controller & curve for the QuickeApp logo bubble
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    // Initialize 4-second subtle vertical floating animation (repeats smoothly back & forth)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Clean up animation controllers and text controllers to prevent memory leaks
    _floatController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  /// Handles both Sign In and Registration submissions based on active tab mode.
  Future<void> _handleSubmit() async {
    // 1. Validate all input fields before proceeding with API request
    if (!_formKey.currentState!.validate()) return;

    // 2. In Register mode, ensure user accepted security terms
    if (_selectedTabMode == 1 && !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Security Policy to register.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Set loading state to true (disables submit button and shows progress indicator)
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final isAdmin = email.toLowerCase().contains('admin');
    final roleName = isAdmin ? 'Admin' : 'Cashier';

    if (_selectedTabMode == 0) {
      // =========================================================================
      // --- LOGIC: CASHIER / STORE OWNER SIGN IN FLOW ---
      // =========================================================================
      try {
        // Send login credentials to backend API
        final res = await _apiService.login(email, password);

        if (!mounted) return;

        if (res['success'] == true) {
          // Fetch authenticated user's profile details
          final userDetail = await _apiService.getUserDetail();
          if (!mounted) return;

          final userObj = res['user'] is Map<String, dynamic> ? res['user'] as Map<String, dynamic> : userDetail;
          final displayName = userObj['first_name'] ?? userDetail['first_name'] ?? roleName;

          // Check user role: user_type == 3 or having parent_id denotes Cashier/Staff account
          final int? userType = int.tryParse((userObj['user_type'] ?? userDetail['user_type'] ?? '').toString());
          final parentId = userObj['parent_id'] ?? userDetail['parent_id'];
          final bool isStaff = userType == 3 ||
              (parentId != null &&
                  parentId.toString().isNotEmpty &&
                  parentId.toString() != '0' &&
                  parentId.toString().toLowerCase() != 'null');

          // Retrieve store branding details (logo, store name) from CMS
          final branding = await _apiService.getStoreBranding();
          final String brandingStoreName = (branding['store_name'] ?? '').toString().trim();
          final String userStoreName = (userDetail['store_name'] ?? userObj['store_name'] ?? '').toString().trim();
          final String adminStoreName = (await _apiService.getAdminStoreName()).trim();
          final String effectiveStoreName = brandingStoreName.isNotEmpty && brandingStoreName != 'Admin Store' && brandingStoreName != 'User Store'
              ? brandingStoreName
              : (adminStoreName.isNotEmpty
                  ? adminStoreName
                  : (userStoreName.isNotEmpty && userStoreName != 'Admin Store' && userStoreName != 'User Store'
                      ? userStoreName
                      : (isStaff ? 'POS Terminal' : '$displayName Store')));

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged in successfully as $displayName!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );

          if (isStaff) {
            // Cashiers / Staff: Never redirect to store setup wizard; navigate directly to POS screen!
            AppNavigator.pushAndRemoveUntil(
              context,
              PosScreen(
                userEmail: email,
                storeName: effectiveStoreName,
              ),
            );
          } else {
            // Store Owner: Check whether store setup wizard has already been completed
            final isSetupDone = await _apiService.isStoreSetupCompleted();
            if (!mounted) return;
            if (!isSetupDone) {
              // Redirect to store setup onboarding screen if initial setup is pending
              AppNavigator.pushAndRemoveUntil(
                context,
                StoreSetupScreen(
                  userEmail: email,
                  initialStoreName: displayName.isNotEmpty ? '$displayName Store' : '',
                ),
              );
            } else {
              // Direct navigation to POS Screen if onboarding is completed
              AppNavigator.pushAndRemoveUntil(
                context,
                PosScreen(
                  userEmail: email,
                  storeName: effectiveStoreName,
                ),
              );
            }
          }
        } else {
          // Display invalid credentials or access denied message returned by API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Invalid email or password. Access denied.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else {
      // =========================================================================
      // --- LOGIC: REGISTER NEW STORE OWNER ACCOUNT ---
      // =========================================================================
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      try {
        // Send registration request to backend API
        final res = await _apiService.register(firstName, lastName, email, password);

        if (!mounted) return;

        if (res['success'] == true) {
          // Initialize store onboarding status to false for new account
          await _apiService.setStoreSetupCompleted(false);
          await _apiService.clearSetupDraft();
          await _apiService.saveStoreBranding({
            'store_name': '$firstName Store',
            'logo_url': '',
            'address': '',
            'phone': '',
            'email': email,
            'whatsapp': '',
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account registered for $firstName $lastName!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Direct newly registered store owner directly to Store Setup Wizard
          if (!mounted) return;
          AppNavigator.pushAndRemoveUntil(
            context,
            StoreSetupScreen(
              userEmail: email,
              initialStoreName: '$firstName Store',
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Registration failed. Email may already be in use.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // =====================================================================
          // --- AMBIENT BACKGROUND GLOW EFFECTS (Emerald, Indigo, Slate) ---
          // =====================================================================
          Positioned(
            top: -120,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.18),
                      const Color(0xFF10B981).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: screenSize.height * 0.28,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.14),
                      const Color(0xFF6366F1).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: screenSize.width * 0.2,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withOpacity(0.12),
                      const Color(0xFF06B6D4).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // =====================================================================
          // --- MAIN SCROLLABLE CONTAINER ---
          // =====================================================================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // =========================================================
                      // --- 1. HERO BRAND HEADER (Animated Logo & Typography) ---
                      // =========================================================
                      FadeSlideEntrance(
                        delay: Duration.zero,
                        duration: const Duration(milliseconds: 200),
                        offset: const Offset(0.0, -0.04),
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, _floatAnimation.value),
                                child: child,
                              ),
                              child: const QuickeLogoBubble(size: 82),
                            ),
                            const SizedBox(height: 14),

                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Quicke',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'App',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            Text(
                              'SELL SMARTER, GROW FASTER.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Center(
                              child: ServerStatusBadge(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // =========================================================
                      // --- 2. MAIN INTERACTIVE CARD CONTAINER ---
                      // =========================================================
                      FadeSlideEntrance(
                        delay: Duration.zero,
                        duration: const Duration(milliseconds: 200),
                        offset: const Offset(0.0, 0.04),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.97),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.06),
                                blurRadius: 36,
                                offset: const Offset(0, 16),
                                spreadRadius: -8,
                              ),
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // --- SEGMENTED SWITCHER CONTROL (Sign In / Register) ---
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final halfWidth = (constraints.maxWidth) / 2;
                                      return Stack(
                                        children: [
                                          AnimatedPositioned(
                                            duration: const Duration(milliseconds: 260),
                                            curve: Curves.easeOutCubic,
                                            left: _selectedTabMode == 0 ? 0 : halfWidth,
                                            top: 0,
                                            bottom: 0,
                                            width: halfWidth,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: AppColors.primaryGradient,
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => setState(() => _selectedTabMode = 0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'Sign In',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: _selectedTabMode == 0
                                                            ? Colors.white
                                                            : const Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => setState(() => _selectedTabMode = 1),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'Register Store',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: _selectedTabMode == 1
                                                            ? Colors.white
                                                            : const Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // --- INPUT FIELDS SECTION ---
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeInOutCubic,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (_selectedTabMode == 1) ...[
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'First Name',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextFormField(
                                                    controller: _firstNameController,
                                                    textCapitalization: TextCapitalization.words,
                                                    enabled: !_isLoading,
                                                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0F172A)),
                                                    decoration: _inputDecoration(
                                                      hint: 'John',
                                                      prefixIcon: Icons.person_outline,
                                                    ),
                                                    validator: (val) => (_selectedTabMode == 1 &&
                                                            (val == null || val.trim().isEmpty))
                                                        ? 'Required'
                                                        : null,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Last Name',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextFormField(
                                                    controller: _lastNameController,
                                                    textCapitalization: TextCapitalization.words,
                                                    enabled: !_isLoading,
                                                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0F172A)),
                                                    decoration: _inputDecoration(
                                                      hint: 'Doe',
                                                      prefixIcon: Icons.badge_outlined,
                                                    ),
                                                    validator: (val) => (_selectedTabMode == 1 &&
                                                            (val == null || val.trim().isEmpty))
                                                        ? 'Required'
                                                        : null,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                      ],

                                      Text(
                                        'Email Address',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        enabled: !_isLoading,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0F172A)),
                                        decoration: _inputDecoration(
                                          hint: 'name@store.com',
                                          prefixIcon: Icons.alternate_email_rounded,
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Please enter your email address';
                                          }
                                          if (!val.contains('@')) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),

                                      Text(
                                        'Password',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        enabled: !_isLoading,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          letterSpacing: 2.0,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        decoration: _inputDecoration(
                                          hint: '••••••••',
                                          prefixIcon: Icons.lock_outline_rounded,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                              size: 19,
                                              color: _obscurePassword ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                            ),
                                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                          ),
                                        ),
                                        validator: (val) =>
                                            (val == null || val.trim().isEmpty) ? 'Please enter your password' : null,
                                        onFieldSubmitted: (_) => _handleSubmit(),
                                      ),

                                      if (_selectedTabMode == 1) ...[
                                        const SizedBox(height: 14),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: Checkbox(
                                                  value: _agreedToTerms,
                                                  activeColor: const Color(0xFF10B981),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                                  onChanged: (val) => setState(() => _agreedToTerms = val ?? true),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'I agree to POS Operator Security Policy and register this terminal for authorized sales.',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    height: 1.35,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // --- SUBMIT ACTION BUTTON ---
                                AnimatedTapButton(
                                  scaleDown: 0.98,
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0F172A).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: _isLoading ? null : _handleSubmit,
                                        child: Center(
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      _selectedTabMode == 0 ? 'Sign In to POS' : 'Create Account',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.only(top: 14),
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_outline_rounded, size: 13.5, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Secured with JWT & Encrypted Local Storage',
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
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'QuickeApp Terminal Edition • v4.2.0 (Fintech Certified)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: const Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIcon: Icon(prefixIcon, size: 19, color: const Color(0xFF94A3B8)),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }
}

/// QuickeApp Signature Lightning Speech Bubble Vector Logo
class QuickeLogoBubble extends StatelessWidget {
  final double size;

  const QuickeLogoBubble({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: QuickeLogoBubblePainter(),
      ),
    );
  }
}

/// CustomPainter rendering the exact QuickeApp Lightning Speech Bubble SVG from HTML
/// Scaled mathematically to any canvas size with round joints and emerald accents.
class QuickeLogoBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate proportional scale factor relative to 96x96 base coordinate space
    final double scale = size.width / 96.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Bubble Outer Contour Path:
    // d="M72 16H24C16.268 16 10 22.268 10 30V54C10 61.732 16.268 68 24 68H28V81.5C28 82.88 29.58 83.66 30.68 82.8L47 70H72C79.732 70 86 63.732 86 56V30C86 22.268 79.732 16 72 16Z"
    final Path bubblePath = Path()
      ..moveTo(72, 16)
      ..lineTo(24, 16)
      ..cubicTo(16.268, 16, 10, 22.268, 10, 30)
      ..lineTo(10, 54)
      ..cubicTo(10, 61.732, 16.268, 68, 24, 68)
      ..lineTo(28, 68)
      ..lineTo(28, 81.5)
      ..cubicTo(28, 82.88, 29.58, 83.66, 30.68, 82.8)
      ..lineTo(47, 70)
      ..lineTo(72, 70)
      ..cubicTo(79.732, 70, 86, 63.732, 86, 56)
      ..lineTo(86, 30)
      ..cubicTo(86, 22.268, 79.732, 16, 72, 16)
      ..close();

    // Fill white background for the speech bubble
    final Paint fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(bubblePath, fillPaint);

    // Stroke bubble outline in Emerald (#10b981)
    final Paint strokePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bubblePath, strokePaint);

    // 2. Interior Wave Radio Line 1:
    // d="M25 36C27.5 40 27.5 46 25 50"
    final Path wave1 = Path()
      ..moveTo(25, 36)
      ..cubicTo(27.5, 40, 27.5, 46, 25, 50);
    final Paint wavePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(wave1, wavePaint);

    // 3. Interior Wave Radio Line 2:
    // d="M33 31C37 38 37 48 33 55"
    final Path wave2 = Path()
      ..moveTo(33, 31)
      ..cubicTo(37, 38, 37, 48, 33, 55);
    canvas.drawPath(wave2, wavePaint);

    // 4. Central Flash Lightning Bolt Path:
    // d="M57 26L42 45H53L45 66L66 42H53L57 26Z"
    final Path boltPath = Path()
      ..moveTo(57, 26)
      ..lineTo(42, 45)
      ..lineTo(53, 45)
      ..lineTo(45, 66)
      ..lineTo(66, 42)
      ..lineTo(53, 42)
      ..lineTo(57, 26)
      ..close();

    // Fill lightning bolt with solid Emerald (#10b981)
    final Paint boltFill = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawPath(boltPath, boltFill);

    // Stroke lightning bolt boundary
    final Paint boltStroke = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(boltPath, boltStroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
