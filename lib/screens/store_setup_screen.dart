import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_input_with_country_code.dart';
import '../widgets/ui_animation_helper.dart';
import 'pos_screen.dart';

class StoreSetupScreen extends StatefulWidget {
  final String userEmail;
  final String initialStoreName;
  final bool isEditing;

  const StoreSetupScreen({
    super.key,
    required this.userEmail,
    this.initialStoreName = '',
    this.isEditing = false,
  });

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // Onboarding Wizard Steps:
  // Step 0 = Store Profile (Brand Name, Address, Contact, Logo)
  // Step 1 = Billing & Tax Settings (Currency, Tax Rate, Receipt Policies)
  // Step 2 = Hardware & POS Setup (Receipt Printer size, Barcode mode, Payment methods)
  // Step 3 = Quick-Start Catalog (Default category & Starter demo inventory)
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDemoProductsLoaded = false;
  bool _isCategoryCreated = false;

  // --- Step 1 Controllers (Store Identity) ---
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  String _phoneCountryCode = '+94';
  String _whatsappCountryCode = '+94';
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _existingLogoUrl;

  // --- Step 2 Controllers (Financial & Receipt Configurations) ---
  String _selectedCurrency = 'LKR';
  final _customCurrencyController = TextEditingController();
  double _taxRate = 0.0;
  final _customTaxController = TextEditingController(text: '0');
  bool _taxIncluded = true;
  final _thankYouController = TextEditingController(text: 'Thank you for shopping with us! Please come again.');
  final _returnPolicyController = TextEditingController(text: 'Returns accepted within 7 days with original receipt. No cash refunds.');

  // --- Step 3 Controllers (Hardware & Peripheral Devices) ---
  String _paperSize = '58mm'; // Standard 58mm or wide 80mm thermal paper
  bool _autoPrintReceipt = true;
  String _scannerMode = 'camera'; // Mobile camera scanner vs external USB/Bluetooth barcode gun
  final Set<String> _enabledPaymentMethods = {'Cash', 'Card', 'Bank Transfer / QR Pay'};

  // --- Step 4 Controllers (Catalog Initialization) ---
  final _firstCategoryController = TextEditingController(text: 'General');

  @override
  void initState() {
    super.initState();
    // Load persisted settings or drafts from local storage & backend
    _loadAllInitialSettings();

    // Auto-save draft on every keystroke so form state persists across page refreshes
    _nameController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _whatsappController.addListener(_onFieldChanged);
    _customCurrencyController.addListener(_onFieldChanged);
    _customTaxController.addListener(_onFieldChanged);
    _thankYouController.addListener(_onFieldChanged);
    _returnPolicyController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    _saveSetupDraft();
  }

  /// AUTO-SAVE SETUP DRAFT LOGIC:
  /// Serializes active onboarding wizard progress into local storage.
  /// Prevents data loss if the cashier or store owner reloads the browser tab.
  Future<void> _saveSetupDraft() async {
    if (widget.isEditing) return;
    try {
      await _apiService.saveSetupDraft({
        'current_step': _currentStep,
        'store_name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone_code': _phoneCountryCode,
        'whatsapp': _whatsappController.text.trim(),
        'whatsapp_code': _whatsappCountryCode,
        'currency': _selectedCurrency,
        'custom_currency': _customCurrencyController.text.trim(),
        'tax_rate': _taxRate,
        'tax_rate_str': _customTaxController.text.trim(),
        'tax_included': _taxIncluded,
        'thank_you': _thankYouController.text.trim(),
        'return_policy': _returnPolicyController.text.trim(),
        'paper_size': _paperSize,
        'auto_print': _autoPrintReceipt,
        'scanner_mode': _scannerMode,
        'payment_methods': _enabledPaymentMethods.toList(),
        'first_category': _firstCategoryController.text.trim(),
        'logo_url': _existingLogoUrl ?? '',
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _addressController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _whatsappController.removeListener(_onFieldChanged);
    _customCurrencyController.removeListener(_onFieldChanged);
    _customTaxController.removeListener(_onFieldChanged);
    _thankYouController.removeListener(_onFieldChanged);
    _returnPolicyController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _customCurrencyController.dispose();
    _customTaxController.dispose();
    _thankYouController.dispose();
    _returnPolicyController.dispose();
    _firstCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadAllInitialSettings() async {
    final isStaff = await _apiService.isStaffUser();
    if (isStaff) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Restricted: Only Store Owner can modify store branding & settings.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (!widget.isEditing) {
        final draft = await _apiService.getSetupDraft();
        if (draft != null) {
          // Restore user's draft if they refreshed the browser mid-wizard!
          final draftStep = int.tryParse(draft['current_step']?.toString() ?? '0') ?? 0;
          _currentStep = draftStep.clamp(0, 3);
          _nameController.text = (draft['store_name'] ?? widget.initialStoreName).toString();
          _addressController.text = (draft['address'] ?? '').toString();
          _phoneController.text = (draft['phone'] ?? '').toString();
          _phoneCountryCode = (draft['phone_code'] ?? '+94').toString();
          _whatsappController.text = (draft['whatsapp'] ?? '').toString();
          _whatsappCountryCode = (draft['whatsapp_code'] ?? '+94').toString();
          _selectedCurrency = (draft['currency'] ?? 'LKR').toString();
          _customCurrencyController.text = (draft['custom_currency'] ?? '').toString();
          _taxRate = (draft['tax_rate'] is num ? (draft['tax_rate'] as num).toDouble() : 0.0);
          _customTaxController.text = (draft['tax_rate_str'] ?? '0').toString();
          _taxIncluded = draft['tax_included'] == true;
          _thankYouController.text = (draft['thank_you'] ?? 'Thank you for shopping with us! Please come again.').toString();
          _returnPolicyController.text = (draft['return_policy'] ?? 'Returns accepted within 7 days with original receipt. No cash refunds.').toString();
          _paperSize = (draft['paper_size'] ?? '58mm').toString();
          _autoPrintReceipt = draft['auto_print'] != false;
          _scannerMode = (draft['scanner_mode'] ?? 'camera').toString();
          if (draft['first_category'] != null) {
            _firstCategoryController.text = draft['first_category'].toString();
          }
          _existingLogoUrl = (draft['logo_url'] ?? '').toString().isNotEmpty ? draft['logo_url'].toString() : null;
        } else {
          // First-Time Setup Wizard without draft: Keep ALL fields clean and empty! No dummy auto-fill!
          String name = widget.initialStoreName.trim();
          if (name == 'Admin Store' || name == 'User Store' || name == 'Store Owner Store') {
            name = '';
          }
          _nameController.text = name;
          _addressController.text = '';
          _phoneController.text = '';
          _whatsappController.text = '';
          _phoneCountryCode = '+94';
          _whatsappCountryCode = '+94';
          _existingLogoUrl = null;
        }
      } else {
        final branding = await _apiService.getStoreBranding();
        String name = (branding['store_name'] ?? widget.initialStoreName).toString().trim();
        if (name == 'Admin Store' || name == 'User Store' || name == 'Store Owner Store') {
          name = '';
        }

        String addr = (branding['address'] ?? '').toString().trim();
        if (addr.contains('Market Street') || addr.contains('San Francisco')) addr = '';

        String phone = (branding['phone'] ?? '').toString().trim();
        if (phone.contains('555') || phone.contains('012-3456')) phone = '';

        String wa = (branding['whatsapp'] ?? '').toString().trim();
        if (wa.contains('555') || wa == '15550123456') wa = '';

        // Extract country code if present
        for (var c in kSupportedCountryCodes) {
          if (phone.startsWith(c.code)) {
            _phoneCountryCode = c.code;
            phone = phone.substring(c.code.length).trim();
            break;
          }
        }
        for (var c in kSupportedCountryCodes) {
          if (wa.startsWith(c.dial)) {
            _whatsappCountryCode = c.code;
            wa = wa.substring(c.dial.length).trim();
            break;
          }
        }

        _nameController.text = name;
        _addressController.text = addr;
        _phoneController.text = phone;
        _whatsappController.text = wa;
        _existingLogoUrl = (branding['logo_url'] ?? '').toString().isNotEmpty ? branding['logo_url'].toString() : null;
      }

      final billing = await _apiService.getBillingSettings();
      final hardware = await _apiService.getHardwareSettings();

      // Billing settings
      _selectedCurrency = (billing['currency_symbol'] ?? 'LKR').toString();
      _taxRate = double.tryParse((billing['tax_rate'] ?? 0.0).toString()) ?? 0.0;
      _customTaxController.text = _taxRate == _taxRate.roundToDouble() ? _taxRate.toStringAsFixed(0) : _taxRate.toString();
      _taxIncluded = billing['tax_included'] != false;
      if (billing['thank_you_message'] != null && billing['thank_you_message'].toString().isNotEmpty) {
        _thankYouController.text = billing['thank_you_message'].toString();
      }
      if (billing['return_policy'] != null && billing['return_policy'].toString().isNotEmpty) {
        _returnPolicyController.text = billing['return_policy'].toString();
      }

      // Hardware settings
      _paperSize = (hardware['paper_size'] ?? '58mm').toString();
      _autoPrintReceipt = hardware['auto_print'] != false;
      _scannerMode = (hardware['scanner_mode'] ?? 'camera').toString();
      if (hardware['payment_methods'] is List) {
        _enabledPaymentMethods.clear();
        for (var m in hardware['payment_methods']) {
          _enabledPaymentMethods.add(m.toString());
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageName = file.name;
        });

        // Upload logo immediately and cache in draft
        _apiService.uploadImage(bytes, file.name).then((uploadRes) {
          if (uploadRes['success'] == true && uploadRes['url'] != null) {
            final url = uploadRes['url'].toString();
            if (mounted) {
              setState(() {
                _existingLogoUrl = url;
              });
              _saveSetupDraft();
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your store name before proceeding.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _saveSetupDraft();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _saveSetupDraft();
    }
  }

  Future<void> _handleQuickCreateCategory() async {
    final catName = _firstCategoryController.text.trim();
    if (catName.isEmpty) return;

    setState(() => _isSaving = true);
    final res = await _apiService.createCategory({
      'name': catName,
      'slug': catName.toLowerCase().replaceAll(' ', '-'),
      'description': '$catName category items',
      'status': 'active',
    });
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isCategoryCreated = res;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res ? 'Category "$catName" created!' : 'Category already exists or created.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSeedDemoProducts() async {
    setState(() => _isSaving = true);
    final catName = _firstCategoryController.text.trim().isNotEmpty ? _firstCategoryController.text.trim() : 'General';
    final ok = await _apiService.seedDemoProducts(categoryName: catName);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isDemoProductsLoaded = ok;
      _isCategoryCreated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Loaded 3 demo products with barcode & prices!' : 'Failed to seed sample items.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _finishWizardAndLaunch() async {
    final storeName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'POS Store';
    final address = _addressController.text.trim();

    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    String phone = '';
    if (rawPhone.isNotEmpty) {
      final cleanDigits = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
      phone = '$_phoneCountryCode $cleanDigits';
    }

    final rawWa = _whatsappController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    String whatsapp = '';
    if (rawWa.isNotEmpty) {
      final cleanDigits = rawWa.startsWith('0') ? rawWa.substring(1) : rawWa;
      final dial = getCountryByCode(_whatsappCountryCode).dial;
      whatsapp = '$dial$cleanDigits';
    }

    setState(() => _isSaving = true);

    String logoUrl = _existingLogoUrl ?? '';

    // 1. Upload Logo if newly selected
    if (_pickedImageBytes != null && _pickedImageName != null) {
      final uploadRes = await _apiService.uploadImage(
        _pickedImageBytes!,
        _pickedImageName!,
      );
      if (uploadRes['success'] == true && uploadRes['url'] != null) {
        logoUrl = uploadRes['url'].toString();
      }
    }

    // 2. Update CMS Header
    await _apiService.updateCmsHeader({
      'store_name': storeName,
      'title': storeName,
      if (logoUrl.isNotEmpty) 'logo_url': logoUrl,
    });

    // 3. Update CMS Contact
    if (address.isNotEmpty || phone.isNotEmpty) {
      await _apiService.updateCmsContact({
        'address': address,
        'phone': phone,
        'email': widget.userEmail,
      });
    }

    // 4. Update CMS WhatsApp
    if (whatsapp.isNotEmpty) {
      await _apiService.updateCmsWhatsapp({
        'whatsapp_number': whatsapp,
        'number': whatsapp,
        'phoneNumber': whatsapp,
      });
    }

    // 5. Update User Profile
    await _apiService.updateUserProfile(storeName: storeName, logoUrl: logoUrl);

    // 6. Save Store Branding
    final consolidatedBranding = {
      'store_name': storeName,
      'logo_url': logoUrl,
      'address': address,
      'phone': phone,
      'email': widget.userEmail,
      'whatsapp': whatsapp,
    };
    await _apiService.saveStoreBranding(consolidatedBranding);

    // 7. Save Billing & Tax settings
    final effectiveCurrency = _selectedCurrency == 'Custom' ? _customCurrencyController.text.trim() : _selectedCurrency;
    final billingSettings = {
      'currency_symbol': effectiveCurrency.isNotEmpty ? effectiveCurrency : 'LKR',
      'currency_code': effectiveCurrency.isNotEmpty ? effectiveCurrency : 'LKR',
      'tax_rate': _taxRate,
      'tax_included': _taxIncluded,
      'thank_you_message': _thankYouController.text.trim(),
      'return_policy': _returnPolicyController.text.trim(),
    };
    await _apiService.saveBillingSettings(billingSettings);

    // 8. Save Hardware & Terminal settings
    final hardwareSettings = {
      'paper_size': _paperSize,
      'auto_print': _autoPrintReceipt,
      'scanner_mode': _scannerMode,
      'payment_methods': _enabledPaymentMethods.toList(),
    };
    await _apiService.saveHardwareSettings(hardwareSettings);

    // 9. Clear Setup Draft and Mark Setup Completed
    await _apiService.clearSetupDraft();
    await _apiService.setStoreSetupCompleted(true);

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('POS System configured and ready for billing!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (widget.isEditing) {
      Navigator.pop(context, consolidatedBranding);
    } else {
      AppNavigator.pushAndRemoveUntil(
        context,
        PosScreen(
          userEmail: widget.userEmail,
          storeName: storeName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isEditing
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          widget.isEditing ? 'Store & Terminal Settings' : 'Setup Your Store Wizard',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          // Step 1 and Step 2 have NO skip button - store identity and billing/tax are required!
          if (_currentStep == 2)
            TextButton(
              onPressed: () {
                setState(() => _currentStep = 3);
                _saveSetupDraft();
              },
              child: const Text('Skip Step', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          else if (_currentStep == 3)
            TextButton(
              onPressed: _finishWizardAndLaunch,
              child: const Text('Skip & Launch', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                // Top Stepper Navigation Bar
                _buildStepperHeader(),

                // Step Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _buildCurrentStepContent(),
                      ),
                    ),
                  ),
                ),

                // Bottom Step Controls
                _buildBottomControls(),
              ],
            ),
    );
  }

  // --- STEPPER HEADER ---
  Widget _buildStepperHeader() {
    final steps = [
      {'title': 'Store Identity', 'icon': Icons.storefront_rounded},
      {'title': 'Billing & Taxes', 'icon': Icons.receipt_long_rounded},
      {'title': 'POS Hardware', 'icon': Icons.print_rounded},
      {'title': 'Ready & Launch', 'icon': Icons.rocket_launch_rounded},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepIndex = index ~/ 2;
                final isDone = _currentStep > stepIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isDone ? Colors.black : const Color(0xFFE2E8F0),
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final isCurrent = _currentStep == stepIndex;
              final isDone = _currentStep > stepIndex;

              return InkWell(
                onTap: () {
                  if (_currentStep > 0 || _nameController.text.trim().isNotEmpty) {
                    setState(() => _currentStep = stepIndex);
                    _saveSetupDraft();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.black
                              : (isDone ? const Color(0xFF10B981) : const Color(0xFFF1F5F9)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrent ? Colors.black : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text(
                                  '${stepIndex + 1}',
                                  style: TextStyle(
                                    color: isCurrent ? Colors.white : AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (MediaQuery.of(context).size.width > 500)
                        Text(
                          steps[stepIndex]['title'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isCurrent ? Colors.black : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of 4: ${steps[_currentStep]['title']}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    Widget content;
    switch (_currentStep) {
      case 0:
        content = _buildStep1StoreProfile();
        break;
      case 1:
        content = _buildStep2BillingAndTax();
        break;
      case 2:
        content = _buildStep3HardwareAndTerminal();
        break;
      case 3:
      default:
        content = _buildStep4ReadyAndQuickStart();
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentStep),
        child: content,
      ),
    );
  }

  // ==========================================
  // --- STEP 1: STORE PROFILE & IDENTITY ---
  // ==========================================
  Widget _buildStep1StoreProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Store Identity & Branding',
          subtitle: 'Set up your shop name, logo, address, and phone number to brand your POS register and thermal receipts.',
          icon: Icons.storefront_rounded,
        ),
        const SizedBox(height: 20),

        // Logo Picker Card
        _buildSectionTitle('Store Logo', 'Appears on the top of thermal and digital receipts'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImageBytes != null
                    ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                    : (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty)
                        ? Image.network(
                            _existingLogoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 36, color: Colors.grey),
                          )
                        : const Icon(Icons.storefront_rounded, size: 36, color: Colors.grey),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickLogo(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _pickLogo(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.black),
                          label: const Text('Camera', style: TextStyle(color: Colors.black)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _pickedImageName ?? 'PNG / JPG recommended (1:1 square)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Store Name
        _buildSectionTitle('Store Name *', 'Displayed in POS register top bar & bill header'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: TextFormField(
            controller: _nameController,
            decoration: _inputDecoration(
              label: 'Store Name *',
              hint: 'e.g. Sithum Supermarket',
              icon: Icons.store_rounded,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Address & Phone
        _buildSectionTitle('Shop Location & Hotline', 'Printed at the bottom of customer receipts'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: _inputDecoration(
                  label: 'Shop Address',
                  hint: 'e.g. 123 Galle Road, Colombo 03, Sri Lanka',
                  icon: Icons.location_on_rounded,
                ),
              ),
              const SizedBox(height: 14),
              PhoneInputWithCountryCode(
                label: 'Store Telephone / Mobile',
                hintText: 'e.g. 77 123 4567 or 11 234 5678',
                controller: _phoneController,
                selectedCountryCode: _phoneCountryCode,
                onCountryChanged: (code) {
                  setState(() => _phoneCountryCode = code);
                  _saveSetupDraft();
                },
                icon: Icons.phone_rounded,
                helperText: 'Will appear on customer receipts and bill headers',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // WhatsApp Number
        _buildSectionTitle('Store WhatsApp Number', 'To send digital receipts & e-bills to customers'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: PhoneInputWithCountryCode(
            label: 'WhatsApp Number',
            hintText: 'e.g. 77 123 4567',
            controller: _whatsappController,
            selectedCountryCode: _whatsappCountryCode,
            onCountryChanged: (code) {
              setState(() => _whatsappCountryCode = code);
              _saveSetupDraft();
            },
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF16A34A),
            helperText: 'Auto-formats into international format (e.g. ${getCountryByCode(_whatsappCountryCode).dial}771234567)',
          ),
        ),
      ],
    );
  }

  // ==========================================
  // --- STEP 2: BILLING & TAX SETTINGS ---
  // ==========================================
  Widget _buildStep2BillingAndTax() {
    final currencies = ['LKR', 'Rs.', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AUD (\$)'];
    final taxPresets = [0.0, 2.5, 8.0, 18.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Billing, Currency & Tax Settings',
          subtitle: 'Define your primary currency, sales tax (VAT / SSCL) percentage, and custom return policies on receipts.',
          icon: Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 20),

        // 1. Currency Selection
        _buildSectionTitle('Currency Symbol', 'Primary currency displayed on prices and bills'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: currencies.map((curr) {
                  final isSelected = _selectedCurrency == curr;
                  return ChoiceChip(
                    label: Text(curr),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCurrency = curr);
                      _saveSetupDraft();
                    },
                    selectedColor: Colors.black,
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Selected Currency: $_selectedCurrency',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Tax Rate & Calculation Mode
        _buildSectionTitle('Sales Tax Rate (VAT / SSCL)', 'Automatic tax calculation on checkout bills'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: taxPresets.map((rate) {
                  final isSelected = _taxRate == rate;
                  final label = rate == 0.0 ? '0% (No Tax)' : '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _taxRate = rate;
                            _customTaxController.text = rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();
                          });
                          _saveSetupDraft();
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.black : Colors.white,
                          foregroundColor: isSelected ? Colors.white : Colors.black,
                          side: BorderSide(color: isSelected ? Colors.black : const Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customTaxController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  label: 'Custom Tax Rate (%)',
                  hint: 'e.g. 15.0',
                  icon: Icons.percent_rounded,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  setState(() => _taxRate = parsed);
                },
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Tax Included vs Excluded Radio
              const Text('Tax Mode Calculation:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSelectCard(
                      title: 'Tax Included',
                      subtitle: 'Product price already includes taxes',
                      isSelected: _taxIncluded,
                      onTap: () => setState(() => _taxIncluded = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSelectCard(
                      title: 'Tax Excluded',
                      subtitle: 'Tax added on top of total at checkout',
                      isSelected: !_taxIncluded,
                      onTap: () => setState(() => _taxIncluded = false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Receipt Footer Messages
        _buildSectionTitle('Receipt Footer Messages', 'Custom notes and return policy printed on receipts'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              TextFormField(
                controller: _thankYouController,
                decoration: _inputDecoration(
                  label: 'Thank You Message',
                  hint: 'e.g. Thank you for shopping with us! Please come again.',
                  icon: Icons.favorite_border_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _returnPolicyController,
                maxLines: 2,
                decoration: _inputDecoration(
                  label: 'Return / Exchange Policy Note',
                  hint: 'e.g. Returns accepted within 7 days with original receipt.',
                  icon: Icons.policy_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // --- STEP 3: HARDWARE & POS TERMINAL ---
  // ==========================================
  Widget _buildStep3HardwareAndTerminal() {
    final paymentOptions = [
      {'name': 'Cash', 'desc': 'Physical cash tender with change calculation', 'icon': Icons.payments_outlined},
      {'name': 'Card', 'desc': 'Credit / Debit card payment via POS terminal', 'icon': Icons.credit_card_rounded},
      {'name': 'Bank Transfer / QR Pay', 'desc': 'LankaQR, bank transfer, or UPI apps', 'icon': Icons.qr_code_2_rounded},
      {'name': 'Credit / Customer Tab', 'desc': 'Store credit ledger for regular accounts', 'icon': Icons.account_balance_wallet_outlined},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Hardware & POS Terminal Preferences',
          subtitle: 'Configure your thermal printer paper size, auto-print triggers, barcode scanner mode, and accepted payment options.',
          icon: Icons.print_rounded,
        ),
        const SizedBox(height: 20),

        // 1. Printer Paper Size
        _buildSectionTitle('Thermal Printer Paper Width', 'Match your Bluetooth or desktop ESC/POS printer model'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectCard(
                title: '58mm Roll',
                subtitle: 'Mobile Bluetooth & mini thermal printers (32 columns)',
                isSelected: _paperSize == '58mm',
                onTap: () => setState(() => _paperSize = '58mm'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectCard(
                title: '80mm Roll',
                subtitle: 'Standard desktop counter thermal printers (48 columns)',
                isSelected: _paperSize == '80mm',
                onTap: () => setState(() => _paperSize = '80mm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Auto-Print Receipt Toggle
        _buildSectionTitle('Auto-Print Behavior', 'Print receipt automatically when order checkout succeeds'),
        const SizedBox(height: 10),
        Container(
          decoration: _cardBoxDecoration(),
          child: SwitchListTile(
            title: const Text('Auto-Print on Bill Checkout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('Immediately sends print command to paired thermal printer when sale completes', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            value: _autoPrintReceipt,
            activeColor: Colors.black,
            onChanged: (val) => setState(() => _autoPrintReceipt = val),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Barcode Scanner Mode
        _buildSectionTitle('Barcode Scanner Mode', 'How cashier scans barcodes during checkout'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectCard(
                title: 'Device Camera',
                subtitle: 'Uses tablet or phone camera with auto-focus',
                isSelected: _scannerMode == 'camera',
                onTap: () => setState(() => _scannerMode = 'camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectCard(
                title: 'Handheld Barcode Gun',
                subtitle: 'USB or Bluetooth wireless scanner (Continuous)',
                isSelected: _scannerMode == 'gun',
                onTap: () => setState(() => _scannerMode = 'gun'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Accepted Payment Options
        _buildSectionTitle('Enabled Payment Methods', 'Payment buttons presented on cashier checkout screen'),
        const SizedBox(height: 10),
        Container(
          decoration: _cardBoxDecoration(),
          child: Column(
            children: paymentOptions.map((opt) {
              final name = opt['name'] as String;
              final desc = opt['desc'] as String;
              final icon = opt['icon'] as IconData;
              final isChecked = _enabledPaymentMethods.contains(name);

              return CheckboxListTile(
                secondary: Icon(icon, color: Colors.black, size: 22),
                title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: isChecked,
                activeColor: Colors.black,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _enabledPaymentMethods.add(name);
                    } else {
                      if (_enabledPaymentMethods.length > 1) {
                        _enabledPaymentMethods.remove(name);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Step 3 Skip Helper Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Hardware not ready? Standard defaults (58mm, Camera scanner, Cash & Card) will be applied. You can modify these anytime later.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 3),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                child: const Text('Skip Step ➔'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // --- STEP 4: READY & QUICK-START ---
  // ==========================================
  Widget _buildStep4ReadyAndQuickStart() {
    final suggestions = ['General', 'Beverages & Drinks', 'Bakery & Snacks', 'Grocery & Staples', 'Clothing & Apparel'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Congratulatory Launch Hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF047857).withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                'Ready to Launch POS!',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your store configuration is complete. You can create your first category below or start billing immediately.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFD1FAE5),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Category Creator Card
        _buildSectionTitle('Quick Start: Create First Category', 'Add your first product group so you can begin adding inventory'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstCategoryController,
                      decoration: _inputDecoration(
                        label: 'Category Name',
                        hint: 'e.g. General or Beverages',
                        icon: Icons.category_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleQuickCreateCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isCategoryCreated ? 'Created ✓' : 'Add Category'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onPressed: () {
                      _firstCategoryController.text = s;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Seed Demo Products Card
        _buildSectionTitle('Optional: Load Demo Sample Products', 'Generate 3 starter items (Milk, Bread, Tea) to test billing immediately'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Load Demo Starter Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Auto-creates 3 sample items with prices & stock to test receipt printing.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isSaving ? null : _handleSeedDemoProducts,
                style: OutlinedButton.styleFrom(
                  backgroundColor: _isDemoProductsLoaded ? const Color(0xFFECFDF5) : Colors.white,
                  side: BorderSide(color: _isDemoProductsLoaded ? const Color(0xFF10B981) : Colors.black),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isDemoProductsLoaded ? 'Loaded ✓' : 'Load Demo',
                  style: TextStyle(
                    color: _isDemoProductsLoaded ? const Color(0xFF047857) : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Summary Configuration Card
        _buildSectionTitle('Configuration Summary', 'Settings ready to be activated'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              _buildSummaryPill('Store Name', _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'POS Store'),
              const Divider(height: 12),
              _buildSummaryPill('Currency & Tax', '$_selectedCurrency · ${_taxRate.toStringAsFixed(1)}% Tax (${_taxIncluded ? 'Inclusive' : 'Exclusive'})'),
              const Divider(height: 12),
              _buildSummaryPill('Printer & Scanner', '$_paperSize roll · ${_autoPrintReceipt ? 'Auto-Print ON' : 'Manual'} · ${_scannerMode.toUpperCase()} scanner'),
              const Divider(height: 12),
              _buildSummaryPill('Payment Modes', _enabledPaymentMethods.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Step 4 Skip Helper Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 20, color: Color(0xFF047857)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Want to skip demo items and start with an empty catalog? You can create products anytime from POS.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _finishWizardAndLaunch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                child: const Text('Skip & Start ➔'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- BOTTOM CONTROLS ---
  Widget _buildBottomControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (_currentStep > 0) ...[
                  AnimatedTapButton(
                    scaleDown: 0.94,
                    onTap: _prevStep,
                    child: OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.black),
                      label: const Text('Back', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: AnimatedTapButton(
                    scaleDown: 0.96,
                    onTap: _isSaving ? null : (_currentStep == 3 ? _finishWizardAndLaunch : _nextStep),
                    child: ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : (_currentStep == 3 ? _finishWizardAndLaunch : _nextStep),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              _currentStep == 3 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      label: Text(
                        _isSaving
                            ? 'Saving Settings...'
                            : (_currentStep == 3
                                ? (widget.isEditing ? 'Save All Changes' : 'Launch POS Register 🚀')
                                : 'Next: Step ${_currentStep + 2}'),
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentStep == 3 ? const Color(0xFF047857) : Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_currentStep == 2) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _currentStep = 3);
                  },
                  icon: const Icon(Icons.skip_next_rounded, size: 18, color: AppColors.textSecondary),
                  label: const Text(
                    'Skip Hardware Setup for Now (Use Defaults)',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
            if (_currentStep == 3) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: _isSaving ? null : _finishWizardAndLaunch,
                  icon: const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF047857)),
                  label: const Text(
                    'Skip Quick-Start & Go Straight to Dashboard',
                    style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- REUSABLE HELPER WIDGETS ---
  Widget _buildHeroCard({required String title, required String subtitle, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSelectCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
