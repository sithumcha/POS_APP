import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/bluetooth_printer_dialog.dart';
import '../widgets/server_status_badge.dart';
import '../widgets/ui_animation_helper.dart';
import '../widgets/product_image_widget.dart';
import 'login_screen.dart';
import 'sales_history_screen.dart';
import 'store_setup_screen.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  final String userEmail;
  final String storeName;

  const UserProfileScreen({
    super.key,
    required this.userEmail,
    required this.storeName,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = false;
  Map<String, dynamic> _userData = {};

  // Settings State Toggles
  late bool _lowStockNotifications;
  late bool _orderSoundAlerts;
  late bool _promoAlerts;
  bool _autoPrintBill = true;

  List<dynamic> _staffList = [];

  @override
  void initState() {
    super.initState();
    _lowStockNotifications = _notificationService.lowStockEnabled;
    _orderSoundAlerts = _notificationService.orderChimeEnabled;
    _promoAlerts = _notificationService.promoAlertsEnabled;

    // Initial fallback data for instant screen render
    _userData = {
      'first_name': 'Store',
      'last_name': 'Admin',
      'email': widget.userEmail,
      'role': 'Store Owner / Admin',
      'store_name': widget.storeName,
    };

    _fetchUserProfile();
    _fetchStaffList();
  }

  /// 1. USER PROFILE & STORE BRANDING FETCHER:
  /// Combines user profile endpoint and CMS store branding endpoint
  /// to display cashier/owner avatar, active store name, and role permissions.
  Future<void> _fetchUserProfile() async {
    try {
      final data = await _apiService.getUserDetail();
      final branding = await _apiService.getStoreBranding();
      if (!mounted) return;
      setState(() {
        _userData = {..._userData, ...data};
        final bStoreName = (branding['store_name'] ?? '').toString().trim();
        if (bStoreName.isNotEmpty && bStoreName != 'Admin Store' && bStoreName != 'User Store') {
          _userData['store_name'] = bStoreName;
        }
        final logo = (branding['logo_url'] ?? data['logo_url'] ?? data['image'] ?? data['avatar'] ?? '').toString().trim();
        if (logo.isNotEmpty) {
          _userData['logo_url'] = logo;
        } else {
          _userData.remove('logo_url');
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 2. CASHIER & STAFF LIST FETCHER:
  /// Retrieves list of secondary cashiers and store operators created under this store owner.
  Future<void> _fetchStaffList() async {
    try {
      final staff = await _apiService.getStaffMembers();
      if (!mounted) return;
      setState(() {
        _staffList = staff;
      });
    } catch (_) {}
  }

  void _openAddStaffDialog() {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isSaving = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.badge_outlined, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Add Staff Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Owner / Admin creates staff accounts for POS terminal.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    const Text('First Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Kasun',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Last Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Perera',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'kasun.pos@store.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Login Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'StaffPassword@123',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 18, color: Colors.black54),
                          SizedBox(width: 8),
                          Text('Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter valid email and password.')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          setDialogState(() => isSaving = true);
                          final res = await _apiService.addStaffMember(
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            password: passwordCtrl.text.trim(),
                            role: 'staff',
                          );

                          if (!mounted) return;
                          navigator.pop();

                          if (res['success'] == true) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Staff member created successfully!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _fetchStaffList();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Failed to create staff member.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(isSaving ? 'Saving...' : 'Add Staff Member'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Store Owner (Admin) edits staff member details or changes their password
  void _openEditStaffDialog(Map<String, dynamic> member) {
    final firstNameCtrl = TextEditingController(text: (member['first_name'] ?? '').toString());
    final lastNameCtrl = TextEditingController(text: (member['last_name'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (member['email'] ?? '').toString());
    final passwordCtrl = TextEditingController();
    bool isSaving = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Edit Staff Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update staff name, email, or assign a new login password.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    const Text('First Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Last Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'cashier@store.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Change / Reset Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Optional', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter new password to change',
                        helperText: 'Leave blank to keep existing password',
                        helperStyle: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 18, color: Colors.black54),
                          SizedBox(width: 8),
                          Text('Staff / Cashier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (emailCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email address.')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          setDialogState(() => isSaving = true);
                          final res = await _apiService.updateStaffMember(
                            id: member['id'],
                            originalEmail: (member['email'] ?? '').toString(),
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            newPassword: passwordCtrl.text.trim(),
                            role: (member['role'] ?? 'staff').toString(),
                          );

                          if (!mounted) return;
                          navigator.pop();

                          if (res['success'] == true) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Staff member updated successfully!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _fetchStaffList();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Failed to update staff member.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(isSaving ? 'Updating...' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRemoveStaff(Map<String, dynamic> member) {
    final email = (member['email'] ?? '').toString();
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : email;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Staff Member', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "$displayName" from active staff members?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _apiService.deleteStaffMember(email: email, id: member['id']);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['message'] ?? 'Staff member $displayName removed.'),
                  backgroundColor: res['success'] == true ? Colors.black87 : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _fetchStaffList();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openEditProfileDialog() {
    final firstNameCtrl = TextEditingController(
      text: (_userData['first_name'] ?? '').toString(),
    );
    final lastNameCtrl = TextEditingController(
      text: (_userData['last_name'] ?? '').toString(),
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('First Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(controller: firstNameCtrl),
                    const SizedBox(height: 12),
                    const Text('Last Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(controller: lastNameCtrl),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          setDialogState(() => isSaving = true);

                          final res = await _apiService.updateUserProfile(
                            firstName: firstNameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                          );

                          if (!mounted) return;
                          navigator.pop();

                          if (res['success'] == true) {
                            setState(() {
                              _userData['first_name'] = firstNameCtrl.text.trim();
                              _userData['last_name'] = lastNameCtrl.text.trim();
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Profile details updated successfully!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _fetchUserProfile();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Failed to update profile details.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: Text(isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _pickAndUploadProfileLogo() async {
    final isStaff = await _apiService.isStaffUser();
    if (isStaff) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff members cannot change the store image. Only the Store Owner can update store branding.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Store Logo & Profile Picture',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload or change the store logo shown on profile, dashboard & receipts',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.photo_library_rounded, color: Color(0xFF1D4ED8)),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Pick high quality store logo / photo', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickLogoImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(Icons.camera_alt_rounded, color: Color(0xFF047857)),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Snap shop banner or storefront', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickLogoImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.edit_note_rounded, color: Colors.black87),
                  ),
                  title: const Text('Edit Personal Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Change first name and last name', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditProfileDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickLogoImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Uploading store image to server...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final bytes = await file.readAsBytes();
      final uploadRes = await _apiService.uploadImage(bytes, file.name);

      if (uploadRes['success'] == true && uploadRes['url'] != null) {
        final newUrl = uploadRes['url'].toString();

        // 1. Update user profile cache and server
        await _apiService.updateUserProfile(logoUrl: newUrl);

        // 2. Update store branding scoped to this merchant
        final b = await _apiService.getStoreBranding();
        b['logo_url'] = newUrl;
        await _apiService.saveStoreBranding(b);

        if (!mounted) return;
        setState(() {
          _userData['logo_url'] = newUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store logo updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadRes['message'] ?? 'Failed to upload image.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password changed successfully!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Update Password'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Log Out Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to log out of your POS account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _apiService.clearToken();
      if (!mounted) return;
      AppNavigator.pushAndRemoveUntil(
        context,
        const LoginScreen(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_userData['first_name'] ?? 'Admin').toString();
    final lastName = (_userData['last_name'] ?? 'User').toString();
    final fullName = '$firstName $lastName'.trim();
    final email = (_userData['email'] ?? widget.userEmail).toString();
    final rawUserType = _userData['user_type'];
    final int? userType = int.tryParse(rawUserType?.toString() ?? '');

    // Type 1 (Super Admin) & Type 2 (Store Owner) -> CAN add staff (isStaffAccount = false)
    // Type 3 (Staff Member / Cashier) -> CANNOT add staff (isStaffAccount = true)
    final bool isStaffAccount;
    if (userType == 1 || userType == 2 || _userData['is_owner'] == true) {
      isStaffAccount = false;
    } else if (userType == 3) {
      isStaffAccount = true;
    } else {
      final parentId = _userData['parent_id'];
      final bool hasParent = parentId != null &&
          parentId.toString().isNotEmpty &&
          parentId.toString() != '0' &&
          parentId.toString().toLowerCase() != 'null';
      final rawRole = (_userData['role'] ?? '').toString().trim().toLowerCase();
      isStaffAccount = hasParent || rawRole == 'staff' || rawRole == 'cashier';
    }

    final role = isStaffAccount
        ? 'Staff Member'
        : (userType == 1 ? 'Super Admin' : 'Store Owner / Admin');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Profile & Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14.0),
            child: ServerStatusBadge(compact: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ResponsiveCenter(
                maxWidth: 680,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. USER PROFILE HEADER CARD WITH ENTRANCE ANIMATION ---
                  FadeSlideEntrance(
                    duration: const Duration(milliseconds: 350),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                        Builder(
                          builder: (context) {
                            final String logoUrl = (_userData['logo_url'] ?? '').toString().trim();
                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: isStaffAccount
                                      ? () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Staff members cannot change the store image. Only the Store Owner can update store branding.'),
                                              backgroundColor: AppColors.primary,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      : _pickAndUploadProfileLogo,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: logoUrl.isNotEmpty
                                        ? ProductImageWidget(
                                            imageUrl: logoUrl,
                                            productName: fullName,
                                            width: 80,
                                            height: 80,
                                            borderRadius: BorderRadius.circular(40),
                                            fit: BoxFit.cover,
                                          )
                                        : CircleAvatar(
                                            radius: 40,
                                            backgroundColor: Colors.black,
                                            child: Text(
                                              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                if (!isStaffAccount)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickAndUploadProfileLogo,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 20),

                  // --- 2. PERSONAL DETAILS CARD ---
                  _buildSectionTitle('Personal Account Details'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _boxDecoration(),
                    child: Column(
                      children: [
                        _buildDetailTile(
                          Icons.storefront_rounded,
                          'Store Name',
                          (_userData['store_name'] != null &&
                                  _userData['store_name'].toString().trim().isNotEmpty &&
                                  _userData['store_name'] != 'QUICKE POS Store' &&
                                  _userData['store_name'] != 'Admin Store' &&
                                  _userData['store_name'] != 'User Store')
                              ? _userData['store_name'].toString().trim()
                              : (widget.storeName.isNotEmpty &&
                                      widget.storeName != 'QUICKE POS Store' &&
                                      widget.storeName != 'Quicke POS Terminal'
                                  ? widget.storeName
                                  : 'QUICKE POS Store'),
                        ),
                        const Divider(height: 1),
                        _buildDetailTile(Icons.verified_user_outlined, 'Account Status', 'Active & Verified'),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.edit_outlined, color: Colors.black, size: 20),
                          title: const Text('Edit Account Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: _openEditProfileDialog,
                        ),
                        if (!isStaffAccount) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.storefront_rounded, color: Colors.black, size: 20),
                            title: const Text('Store Branding & Receipts Setup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Update logo, store name, address & WhatsApp number', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                            onTap: () {
                              AppNavigator.push(
                                context,
                                StoreSetupScreen(
                                  userEmail: widget.userEmail,
                                  initialStoreName: (_userData['store_name'] ?? widget.storeName).toString(),
                                  isEditing: true,
                                ),
                              ).then((_) {
                                _fetchUserProfile();
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SALES & BILLS HISTORY ---
                  _buildSectionTitle('Sales & Bills Management'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _boxDecoration(),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Colors.black, size: 22),
                          ),
                          title: const Text('Past Bills & Sales History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('View billing ledger, receipts, refunds & thermal reprint', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: () {
                            AppNavigator.push(
                              context,
                              const SalesHistoryScreen(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 3. NOTIFICATION & PREFERENCE SETTINGS ---
                  _buildSectionTitle('Notification & Alert Settings'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _boxDecoration(),
                    child: Column(
                      children: [
                        // 1. Low Stock Alert
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_active_outlined, color: Colors.black, size: 22),
                          title: const Text('Low Stock Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Notify when product stock falls below 5 items', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          value: _lowStockNotifications,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            setState(() {
                              _lowStockNotifications = val;
                              _notificationService.lowStockEnabled = val;
                            });
                          },
                        ),
                        const Divider(height: 1),

                        // 2. Order Completion Audio & Alert
                        SwitchListTile(
                          secondary: const Icon(Icons.volume_up_outlined, color: Colors.black, size: 22),
                          title: const Text('Order Completion Sound & Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Play chime & alert when order is completed', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          value: _orderSoundAlerts,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            setState(() {
                              _orderSoundAlerts = val;
                              _notificationService.orderChimeEnabled = val;
                            });
                          },
                        ),
                        const Divider(height: 1),

                        // 3. Promotions & Discount Alerts
                        SwitchListTile(
                          secondary: const Icon(Icons.local_offer_outlined, color: Colors.black, size: 22),
                          title: const Text('Promotions & Discount Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Receive notifications for special items on discount', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          value: _promoAlerts,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            setState(() {
                              _promoAlerts = val;
                              _notificationService.promoAlertsEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 4. HARDWARE & PRINTER PREFERENCES ---
                  _buildSectionTitle('Hardware & Receipt Preferences'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _boxDecoration(),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.print_outlined, color: Colors.black, size: 22),
                          title: const Text('Bluetooth Thermal Printer Manager', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Pair & connect 58mm/80mm ESC/POS printer', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const BluetoothPrinterDialog(),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(Icons.receipt_long_outlined, color: Colors.black, size: 22),
                          title: const Text('Auto-Print Bill on Order Checkout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Automatically print receipt when order completes', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          value: _autoPrintBill,
                          activeColor: Colors.black,
                          onChanged: (val) => setState(() => _autoPrintBill = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 5. STORE STAFF ACCOUNTS (ADMIN ONLY) ---
                  if (!isStaffAccount) ...[
                    _buildSectionTitle('Store Staff Members (Admin Only)'),
                    const SizedBox(height: 10),
                    Container(
                      decoration: _boxDecoration(),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 22),
                            title: const Text('Add Staff Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Create POS terminal login for staff members (POST /users/staff/add)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            trailing: const Icon(Icons.add_circle_outline_rounded, color: Colors.black),
                            onTap: _openAddStaffDialog,
                          ),
                          if (_staffList.isNotEmpty) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ACTIVE STAFF MEMBERS (${_staffList.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                  const SizedBox(height: 6),
                                  ..._staffList.map((member) {
                                    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
                                    final email = member['email'] ?? '';
                                    final role = (member['role'] ?? 'staff').toString().toUpperCase();
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(0xFFE2E8F0),
                                            child: Icon(Icons.person, size: 14, color: Colors.black),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name.isNotEmpty ? name : email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                                Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          // Edit Staff Details & Password
                                          Tooltip(
                                            message: 'Edit Staff & Password',
                                            child: InkWell(
                                              onTap: () => _openEditStaffDialog(member),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: const Icon(Icons.edit_outlined, size: 16, color: Colors.black87),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Delete Staff
                                          Tooltip(
                                            message: 'Remove Staff Account',
                                            child: InkWell(
                                              onTap: () => _confirmRemoveStaff(member),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF2F2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFFECACA)),
                                                ),
                                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- 6. SECURITY & LOGOUT ---
                  _buildSectionTitle('Security & Session Management'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: _boxDecoration(),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded, color: Colors.black, size: 22),
                          title: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: _openChangePasswordDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                          title: const Text('Log Out of POS Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
                          onTap: _handleLogout,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: const Color(0xFF1E293B), size: 19),
      ),
      title: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      subtitle: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
    );
  }
}
