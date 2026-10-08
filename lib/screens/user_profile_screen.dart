import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bluetooth_printer_dialog.dart';
import '../widgets/server_status_badge.dart';
import 'login_screen.dart';

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

  Future<void> _fetchUserProfile() async {
    try {
      final data = await _apiService.getUserDetail();
      if (!mounted) return;
      setState(() {
        _userData = {..._userData, ...data};
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

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
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'StaffPassword@123',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_userData['first_name'] ?? 'Admin').toString();
    final lastName = (_userData['last_name'] ?? 'User').toString();
    final fullName = '$firstName $lastName'.trim();
    final email = (_userData['email'] ?? widget.userEmail).toString();
    final userId = (_userData['id'] ?? 10).toString();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. USER PROFILE HEADER CARD ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.black,
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _openEditProfileDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'ID: #$userId',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                        _buildDetailTile(Icons.storefront_rounded, 'Store Name', widget.storeName),
                        const Divider(height: 1),
                        _buildDetailTile(Icons.verified_user_outlined, 'Account Status', 'Active & Verified'),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.edit_outlined, color: Colors.black, size: 20),
                          title: const Text('Edit Account Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: _openEditProfileDialog,
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
                                          InkWell(
                                            onTap: () => _confirmRemoveStaff(member),
                                            borderRadius: BorderRadius.circular(20),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4.0),
                                              child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        letterSpacing: -0.3,
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.black, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
    );
  }
}
