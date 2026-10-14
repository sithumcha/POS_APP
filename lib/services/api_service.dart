import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'offline_sync_service.dart';
import 'secure_storage_service.dart';

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });
}

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Global callback triggered on HTTP 401 Unauthorized session expiry
  static void Function()? onSessionExpired;

  /// Clear secure storage and trigger session expiry callback
  static void handleSessionExpired() {
    _cachedToken = null;
    _cachedHeaders = null;
    SecureStorageService.clearSession();
    onSessionExpired?.call();
  }

  /// Utility to check HTTP response status code for 401 Unauthorized
  static http.Response checkResponse(http.Response res) {
    if (res.statusCode == 401) {
      debugPrint('⛔ 401 Unauthorized detected! Clearing session...');
      handleSessionExpired();
    }
    return res;
  }

  // Persistent HTTP client for Keep-Alive connection pooling
  static final http.Client _client = http.Client();

  // In-memory token cache (avoids async secure storage read on every API call)
  static String? _cachedToken;
  static Map<String, String>? _cachedHeaders;

  // In-memory catalog response caching for instant UI navigation (0 ms)
  static List<dynamic>? _cachedCategories;
  static DateTime? _categoriesCacheTime;

  static List<dynamic>? _cachedProducts;
  static DateTime? _productsCacheTime;

  static final Map<int, List<dynamic>> _cachedSubcategoriesByCat = {};
  static final Map<int, DateTime> _subcatCacheTimes = {};

  /// Invalidate memory cache on product or category mutations
  static void invalidateCatalogCache() {
    _cachedCategories = null;
    _cachedProducts = null;
    _cachedSubcategoriesByCat.clear();
    _subcatCacheTimes.clear();
  }

  static const String _keyOwnerMerchantToken = 'owner_merchant_token';
  static const String _keyOwnerMerchantId = 'owner_merchant_id';

  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    final token = await _storage.read(key: 'jwt_token') ?? await _storage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      _cachedToken = token.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
      return _cachedToken;
    }
    _cachedToken = await SecureStorageService.getToken();
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    final cleanToken = token.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
    _cachedToken = cleanToken;
    _cachedHeaders = null;
    await SecureStorageService.saveToken(cleanToken);
    await _storage.write(key: 'jwt_token', value: cleanToken);
  }

  /// Returns valid Store Owner / Merchant Token for store-level queries
  Future<String?> getMerchantOwnerToken() async {
    // 1. Cached owner token
    final cached = await _storage.read(key: _keyOwnerMerchantToken);
    if (cached != null && cached.isNotEmpty && !cached.startsWith('LOCAL-')) {
      return cached;
    }

    // 2. Check current token if logged-in user is store owner
    final isStaff = await isStaffUser();
    final currentToken = await getToken();
    if (!isStaff && currentToken != null && currentToken.isNotEmpty && !currentToken.startsWith('LOCAL-')) {
      await _storage.write(key: _keyOwnerMerchantToken, value: currentToken);
      return currentToken;
    }

    return currentToken;
  }

  /// Store completed order locally so it instantly reflects in Sales & Bill History
  Future<void> saveLocalCompletedOrder(Map<String, dynamic> order) async {
    try {
      final list = await getLocalCompletedOrders();
      final orderNo = (order['order_number'] ?? order['receipt_number'] ?? order['id'] ?? '').toString();
      list.removeWhere((o) => (o['order_number'] ?? o['receipt_number'] ?? o['id'] ?? '').toString() == orderNo);
      list.insert(0, order);
      if (list.length > 100) list.removeLast();
      await _storage.write(key: 'local_completed_orders', value: jsonEncode(list));
    } catch (e) {
      debugPrint('saveLocalCompletedOrder error: $e');
    }
  }

  /// Retrieve locally stored completed orders
  Future<List<Map<String, dynamic>>> getLocalCompletedOrders() async {
    try {
      final str = await _storage.read(key: 'local_completed_orders');
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    _cachedUserInfo = null;
    _cachedHeaders = null;
    invalidateCatalogCache();
    await SecureStorageService.clearSession();
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_info');
    await _storage.delete(key: 'owner_merchant_token');
    await _storage.delete(key: 'owner_merchant_id');
    // Wipe legacy global shared keys so they never cross-contaminate between different admins
    await _storage.delete(key: 'store_branding');
    await _storage.delete(key: 'admin_store_branding');
    await _storage.delete(key: 'admin_store_name');
    await _storage.delete(key: 'user_edited_profile');
    await _storage.delete(key: 'pos_setup_draft');
  }

  Future<Map<String, String>> _headers() async {
    String? token = await getToken();
    if (token == null || token.isEmpty || token.startsWith('LOCAL-')) {
      final ownerToken = await getMerchantOwnerToken();
      if (ownerToken != null && ownerToken.isNotEmpty) {
        token = ownerToken;
      }
    }
    if (token != null) {
      token = token.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
    }
    if (_cachedHeaders != null && _cachedHeaders!['Authorization'] == (token != null && token.isNotEmpty ? 'Bearer $token' : null)) {
      return _cachedHeaders!;
    }
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    _cachedHeaders = headers;
    return headers;
  }

  /// Real-time Health Check to ping live server
  Future<Map<String, dynamic>> checkServerHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/categories'),
      ).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      final isOnline = res.statusCode >= 200 && res.statusCode < 500;
      return {
        'isOnline': isOnline,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'statusCode': res.statusCode,
      };
    } catch (_) {
      stopwatch.stop();
      return {
        'isOnline': false,
        'latencyMs': 0,
        'statusCode': 0,
      };
    }
  }

  static Map<String, dynamic>? _cachedUserInfo;

  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    _cachedUserInfo = userInfo;
    await _storage.write(key: 'user_info', value: jsonEncode(userInfo));
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    if (_cachedUserInfo != null) return _cachedUserInfo;
    final str = await _storage.read(key: 'user_info');
    if (str != null && str.isNotEmpty) {
      try {
        _cachedUserInfo = jsonDecode(str) as Map<String, dynamic>;
        return _cachedUserInfo;
      } catch (_) {}
    }
    return null;
  }

  /// Determines whether currently logged-in account is a Staff Member / Cashier.
  /// Type 1 (Super Admin) & Type 2 (Store Owner) -> false (Admin)
  /// Type 3 or accounts having a valid parent_id -> true (Staff)
  Future<bool> isStaffUser([Map<String, dynamic>? userMap]) async {
    final user = userMap ?? (await getUserInfo());
    if (user == null) return false;
    final userType = int.tryParse(user['user_type']?.toString() ?? '');
    if (userType == 1 || userType == 2 || user['is_owner'] == true) {
      return false;
    }
    if (userType == 3) {
      return true;
    }
    final parentId = user['parent_id'];
    final bool hasParent = parentId != null &&
        parentId.toString().isNotEmpty &&
        parentId.toString() != '0' &&
        parentId.toString().toLowerCase() != 'null';
    final rawRole = (user['role'] ?? '').toString().trim().toLowerCase();
    return hasParent || rawRole == 'staff' || rawRole == 'cashier';
  }

  /// Returns the master Store Owner / Admin's store name for inheritance across all staff users
  Future<String> getAdminStoreName() async {
    try {
      final ownerId = await getEffectiveStoreOwnerId();
      if (ownerId.isNotEmpty) {
        final name = await _storage.read(key: 'admin_store_name_$ownerId');
        if (name != null && name.trim().isNotEmpty && name != 'Admin Store' && name != 'User Store') {
          return name.trim();
        }
        final raw = await _storage.read(key: 'store_branding_$ownerId');
        if (raw != null && raw.isNotEmpty) {
          final decoded = _safeJsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final bName = (decoded['store_name'] ?? '').toString().trim();
            if (bName.isNotEmpty && bName != 'Admin Store' && bName != 'User Store') {
              return bName;
            }
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Returns the unique store owner identifier (owner user id or parent_id for staff)
  Future<String> getEffectiveStoreOwnerId() async {
    final user = await getUserInfo();
    if (user == null) return '';
    final parentId = user['parent_id'];
    if (parentId != null &&
        parentId.toString().isNotEmpty &&
        parentId.toString() != '0' &&
        parentId.toString().toLowerCase() != 'null') {
      return parentId.toString();
    }
    final userId = user['id'];
    if (userId != null && userId.toString().isNotEmpty && userId.toString() != '0') {
      return userId.toString();
    }
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    return email;
  }

  Future<void> saveUserEditedProfile(Map<String, dynamic> editedData, {String? email, String? userId}) async {
    try {
      final currentUser = await getUserInfo();
      final id = userId ?? currentUser?['id']?.toString() ?? '';
      final em = (email ?? currentUser?['email'] ?? editedData['email'] ?? '').toString().trim().toLowerCase();
      if (id.isNotEmpty) {
        await _storage.write(key: 'user_edited_profile_$id', value: jsonEncode(editedData));
      }
      if (em.isNotEmpty) {
        await _storage.write(key: 'user_edited_profile_$em', value: jsonEncode(editedData));
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getUserEditedProfile({String? userKey}) async {
    try {
      if (userKey != null && userKey.trim().isNotEmpty) {
        final keyStr = userKey.trim().toLowerCase();
        final str = await _storage.read(key: 'user_edited_profile_$keyStr');
        if (str != null && str.isNotEmpty) {
          final decoded = _safeJsonDecode(str);
          if (decoded is Map<String, dynamic>) return decoded;
        }
      }
      final currentUser = await getUserInfo();
      final uId = currentUser?['id']?.toString() ?? '';
      final uEmail = (currentUser?['email'] ?? '').toString().trim().toLowerCase();
      if (uId.isNotEmpty) {
        final str = await _storage.read(key: 'user_edited_profile_$uId');
        if (str != null && str.isNotEmpty) {
          final decoded = _safeJsonDecode(str);
          if (decoded is Map<String, dynamic>) return decoded;
        }
      }
      if (uEmail.isNotEmpty) {
        final str = await _storage.read(key: 'user_edited_profile_$uEmail');
        if (str != null && str.isNotEmpty) {
          final decoded = _safeJsonDecode(str);
          if (decoded is Map<String, dynamic>) return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  // --- Auth APIs ---

  /// GET /users/detail (Get logged-in user profile details)
  Future<Map<String, dynamic>> getUserDetail() async {
    final savedUser = (await getUserInfo()) ?? {};
    final currentUserId = savedUser['id']?.toString() ?? '';
    final currentUserEmail = (savedUser['email'] ?? '').toString().trim().toLowerCase();
    final editedOverlay = (currentUserId.isNotEmpty
            ? await getUserEditedProfile(userKey: currentUserId)
            : null) ??
        (currentUserEmail.isNotEmpty
            ? await getUserEditedProfile(userKey: currentUserEmail)
            : null) ??
        {};

    try {
      final headers = await _headers();
      final res = await http.get(
        Uri.parse('$baseUrl/users/detail'),
        headers: headers,
      ).timeout(const Duration(milliseconds: 3000));
      if (res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final userObj = data.containsKey('data') && data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : (data.containsKey('user') && data['user'] is Map<String, dynamic>
                  ? data['user'] as Map<String, dynamic>
                  : data);

          final merged = {...userObj};
          if (editedOverlay['first_name'] != null && editedOverlay['first_name'].toString().isNotEmpty) {
            merged['first_name'] = editedOverlay['first_name'];
          } else if (savedUser['first_name'] != null && savedUser['first_name'].toString().isNotEmpty) {
            merged['first_name'] = savedUser['first_name'];
          }

          if (editedOverlay['last_name'] != null && editedOverlay['last_name'].toString().isNotEmpty) {
            merged['last_name'] = editedOverlay['last_name'];
          } else if (savedUser['last_name'] != null && savedUser['last_name'].toString().isNotEmpty) {
            merged['last_name'] = savedUser['last_name'];
          }

          final isStaff = await isStaffUser(merged);
          if (isStaff) {
            merged['is_owner'] = false;
            final adminName = await getAdminStoreName();
            if (adminName.isNotEmpty) {
              merged['store_name'] = adminName;
            } else {
              final branding = await getStoreBranding();
              final bName = (branding['store_name'] ?? '').toString().trim();
              if (bName.isNotEmpty && bName != 'Admin Store' && bName != 'User Store') {
                merged['store_name'] = bName;
              }
            }
          } else {
            if (editedOverlay['store_name'] != null && editedOverlay['store_name'].toString().isNotEmpty) {
              merged['store_name'] = editedOverlay['store_name'];
            } else if (merged['store_name'] == null || merged['store_name'].toString().isEmpty) {
              final fName = (merged['first_name'] ?? '').toString();
              if (fName.isNotEmpty) {
                merged['store_name'] = '$fName Store';
              }
            }
          }

          // Restore logo_url from local cache so server nulls don't erase uploaded store image
          final savedLogo = (editedOverlay['logo_url'] ?? savedUser['logo_url'] ?? '').toString().trim();
          if (savedLogo.isNotEmpty && (merged['logo_url'] == null || merged['logo_url'].toString().isEmpty)) {
            merged['logo_url'] = savedLogo;
            merged['image'] = savedLogo;
            merged['avatar'] = savedLogo;
          }

          final parentId = merged['parent_id'];
          final bool isSubUser = isStaff || (parentId != null &&
              parentId.toString().isNotEmpty &&
              parentId.toString() != '0' &&
              parentId.toString().toLowerCase() != 'null');
          if (!isSubUser) {
            merged['is_owner'] = true;
            if (merged['role'] == null ||
                merged['role'].toString().isEmpty ||
                merged['role'].toString().toLowerCase() == 'user') {
              merged['role'] = 'Store Owner / Admin';
            }
          }

          await saveUserInfo(merged);
          return merged;
        }
      }
    } catch (_) {}

    final mergedSaved = {...savedUser};
    if (editedOverlay['first_name'] != null && editedOverlay['first_name'].toString().isNotEmpty) {
      mergedSaved['first_name'] = editedOverlay['first_name'];
    }
    if (editedOverlay['last_name'] != null && editedOverlay['last_name'].toString().isNotEmpty) {
      mergedSaved['last_name'] = editedOverlay['last_name'];
    }

    final isStaffFallback = await isStaffUser(mergedSaved);
    if (isStaffFallback) {
      mergedSaved['is_owner'] = false;
      final adminName = await getAdminStoreName();
      if (adminName.isNotEmpty) {
        mergedSaved['store_name'] = adminName;
      } else {
        final branding = await getStoreBranding();
        final bName = (branding['store_name'] ?? '').toString().trim();
        if (bName.isNotEmpty && bName != 'Admin Store' && bName != 'User Store') {
          mergedSaved['store_name'] = bName;
        }
      }
    } else {
      if (editedOverlay['store_name'] != null && editedOverlay['store_name'].toString().isNotEmpty) {
        mergedSaved['store_name'] = editedOverlay['store_name'];
      }
      if ((mergedSaved['store_name'] == null || mergedSaved['store_name'].toString().isEmpty)) {
        final fName = (mergedSaved['first_name'] ?? '').toString();
        if (fName.isNotEmpty) {
          mergedSaved['store_name'] = '$fName Store';
        }
      }
    }
    if (editedOverlay['logo_url'] != null && editedOverlay['logo_url'].toString().isNotEmpty) {
      mergedSaved['logo_url'] = editedOverlay['logo_url'];
      mergedSaved['image'] = editedOverlay['logo_url'];
      mergedSaved['avatar'] = editedOverlay['logo_url'];
    }

    if (mergedSaved.isNotEmpty) {
      if ((mergedSaved['store_name'] == null || mergedSaved['store_name'].toString().isEmpty)) {
        final fName = (mergedSaved['first_name'] ?? '').toString();
        if (fName.isNotEmpty) {
          mergedSaved['store_name'] = '$fName Store';
        }
      }
      return mergedSaved;
    }

    return {
      'first_name': '',
      'last_name': '',
      'email': '',
      'role': '',
      'store_name': '',
    };
  }

  /// POST /users/login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // 1. Attempt Remote Server Login
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': cleanEmail, 'password': cleanPassword}),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final isSuccess = data['success'] == true || (data['token'] != null && data['error'] == null);
        if (isSuccess && data['token'] != null && data['token'].toString().isNotEmpty) {
          final tokenStr = data['token'].toString();
          await saveToken(tokenStr);
          final userObj = data['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['user'] as Map)
              : (data['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['data'] as Map) : <String, dynamic>{});

          if (userObj.isEmpty) {
            userObj['email'] = cleanEmail;
            userObj['first_name'] = cleanEmail.contains('@') ? cleanEmail.split('@')[0] : 'User';
            userObj['last_name'] = 'User';
          }

          final userIdStr = userObj['id']?.toString() ?? '';
          final editedOverlay = await getUserEditedProfile(userKey: cleanEmail) ??
              (userIdStr.isNotEmpty ? await getUserEditedProfile(userKey: userIdStr) : null);

          if (editedOverlay != null && editedOverlay.isNotEmpty) {
            final editedEmail = (editedOverlay['email'] ?? '').toString().trim().toLowerCase();
            if (editedEmail.isEmpty || editedEmail == cleanEmail) {
              if (editedOverlay['first_name'] != null && editedOverlay['first_name'].toString().isNotEmpty) {
                userObj['first_name'] = editedOverlay['first_name'];
              }
              if (editedOverlay['last_name'] != null && editedOverlay['last_name'].toString().isNotEmpty) {
                userObj['last_name'] = editedOverlay['last_name'];
              }
              if (editedOverlay['store_name'] != null && editedOverlay['store_name'].toString().isNotEmpty) {
                userObj['store_name'] = editedOverlay['store_name'];
              }
              if (editedOverlay['logo_url'] != null && editedOverlay['logo_url'].toString().isNotEmpty) {
                userObj['logo_url'] = editedOverlay['logo_url'];
                userObj['image'] = editedOverlay['logo_url'];
                userObj['avatar'] = editedOverlay['logo_url'];
              }
            }
          }

          // Also check store branding scoped strictly to this merchant
          final brandingKeys = [
            if (userIdStr.isNotEmpty) 'store_branding_$userIdStr',
            'store_branding_$cleanEmail',
          ];
          for (final key in brandingKeys) {
            try {
              final raw = await _storage.read(key: key);
              if (raw != null && raw.isNotEmpty) {
                final decoded = _safeJsonDecode(raw);
                if (decoded is Map<String, dynamic>) {
                  final bLogo = (decoded['logo_url'] ?? '').toString().trim();
                  if (bLogo.isNotEmpty && (userObj['logo_url'] == null || userObj['logo_url'].toString().isEmpty)) {
                    userObj['logo_url'] = bLogo;
                    userObj['image'] = bLogo;
                    userObj['avatar'] = bLogo;
                  }
                  final bStore = (decoded['store_name'] ?? '').toString().trim();
                  if (bStore.isNotEmpty && bStore != 'Admin Store' && bStore != 'User Store') {
                    userObj['store_name'] = bStore;
                  }
                  break;
                }
              }
            } catch (_) {}
          }

          final parentId = userObj['parent_id'];
          final int? userTypeVal = int.tryParse((userObj['user_type'] ?? '').toString());
          final rawRole = (userObj['role'] ?? '').toString().trim().toLowerCase();
          final bool isSubUser = userTypeVal == 3 ||
              rawRole == 'staff' ||
              rawRole == 'cashier' ||
              (parentId != null &&
                  parentId.toString().isNotEmpty &&
                  parentId.toString() != '0' &&
                  parentId.toString().toLowerCase() != 'null');

          if (!isSubUser) {
            userObj['is_owner'] = true;
            if (userObj['role'] == null ||
                userObj['role'].toString().isEmpty ||
                userObj['role'].toString().toLowerCase() == 'user') {
              userObj['role'] = 'Store Owner / Admin';
            }
            await _storage.write(key: _keyOwnerMerchantToken, value: tokenStr);
            if (userObj['id'] != null) {
              await _storage.write(key: _keyOwnerMerchantId, value: userObj['id'].toString());
            }
            final ownerStoreName = (userObj['store_name'] ?? '').toString().trim();
            if (ownerStoreName.isNotEmpty && ownerStoreName != 'Admin Store' && ownerStoreName != 'User Store') {
              if (userObj['id'] != null) {
                await _storage.write(key: 'admin_store_name_${userObj['id']}', value: ownerStoreName);
                await _storage.write(key: 'store_setup_completed_${userObj['id']}', value: 'true');
              }
              await _storage.write(key: 'store_setup_completed', value: 'true');
            }
          } else {
            // Staff / Cashier member: inherit Store Owner's store name and branding
            userObj['role'] = 'Staff Member';
            userObj['is_owner'] = false;

            // Inherit Admin Store Name
            String inheritedStoreName = await getAdminStoreName();
            if (inheritedStoreName.isEmpty) {
              final localStaff = await getLocalStaffMembers();
              for (var s in localStaff) {
                if ((s['email'] ?? '').toString().trim().toLowerCase() == cleanEmail) {
                  inheritedStoreName = (s['store_name'] ?? '').toString().trim();
                  break;
                }
              }
            }
            if (inheritedStoreName.isEmpty) {
              final branding = await getStoreBranding();
              inheritedStoreName = (branding['store_name'] ?? '').toString().trim();
            }

            if (inheritedStoreName.isNotEmpty && inheritedStoreName != 'Admin Store' && inheritedStoreName != 'User Store') {
              userObj['store_name'] = inheritedStoreName;
            }

            // Inherit logo if present
            final adminBranding = await getStoreBranding();
            final adminLogo = (adminBranding['logo_url'] ?? '').toString().trim();
            if (adminLogo.isNotEmpty) {
              userObj['logo_url'] = adminLogo;
              userObj['image'] = adminLogo;
            }
          }

          await saveUserInfo(userObj);
          return {
            'success': true,
            'token': tokenStr,
            'user': userObj,
            'message': data['message'] ?? 'Login successful',
          };
        }
      }
    } catch (e) {
      debugPrint('Login remote connection error: $e');
    }

    // 2. Local Staff & Cached Credentials Fallback
    try {
      final localStaffList = await getLocalStaffMembers();
      for (final staff in localStaffList) {
        final staffEmail = (staff['email'] ?? '').toString().trim().toLowerCase();
        final staffPass = (staff['password'] ?? '').toString().trim();

        if (staffEmail == cleanEmail) {
          if (staffPass.isEmpty || staffPass == cleanPassword) {
            final mockToken = 'LOCAL-STAFF-TOKEN-${DateTime.now().millisecondsSinceEpoch}';
            await saveToken(mockToken);
            final staffCopy = Map<String, dynamic>.from(staff);
            final adminStore = await getAdminStoreName();
            if (adminStore.isNotEmpty) {
              staffCopy['store_name'] = adminStore;
            }
            await saveUserInfo(staffCopy);
            return {
              'success': true,
              'token': mockToken,
              'user': staffCopy,
              'message': 'Logged in successfully as Staff!',
            };
          } else {
            return {
              'success': false,
              'message': 'Invalid password for staff account.',
            };
          }
        }
      }

      // Check if logged-in user info matches saved cached user
      final savedUser = await getUserInfo();
      if (savedUser != null) {
        final savedEmail = (savedUser['email'] ?? '').toString().trim().toLowerCase();
        if (savedEmail == cleanEmail) {
          final mockToken = 'LOCAL-USER-TOKEN-${DateTime.now().millisecondsSinceEpoch}';
          await saveToken(mockToken);
          return {
            'success': true,
            'token': mockToken,
            'user': savedUser,
            'message': 'Logged in successfully (Offline Mode)',
          };
        }
      }
    } catch (e) {
      debugPrint('Local login check error: $e');
    }

    return {
      'success': false,
      'message': 'Invalid email or password. Access denied.',
    };
  }

  /// POST /users/register
  Future<Map<String, dynamic>> register(
      String firstName, String lastName, String email, String password) async {
    final body = {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'user_type': 1,
      'role': 'admin',
    };

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = _safeJsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final isSuccess = data['success'] == true || (data['token'] != null && data['error'] == null);
        if (isSuccess) {
          if (data['token'] != null) {
            await saveToken(data['token'].toString());
          }
          final userObj = data['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['user'] as Map)
              : <String, dynamic>{
                  'first_name': firstName,
                  'last_name': lastName,
                  'email': email,
                  'user_type': 1,
                  'role': 'Store Owner / Admin',
                };
          userObj['role'] = 'Store Owner / Admin';
          userObj['is_owner'] = true;
          userObj['parent_id'] = null;
          await saveUserInfo(userObj);

          return {
            'success': true,
            'token': data['token'],
            'user': userObj,
            'message': data['message'] ?? 'User registered successfully',
          };
        } else {
          final errorMsg = data['error'] ?? data['message'] ?? 'Registration failed. Email may already be registered.';
          return {
            'success': false,
            'message': errorMsg.toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('Register connection error: $e');
      return {
        'success': false,
        'message': 'Server connection error. Please try again.',
      };
    }

    return {
      'success': false,
      'message': 'Registration failed. Unexpected response from server.',
    };
  }

  /// PUT /users/detail (Update logged in user profile details)
  Future<Map<String, dynamic>> updateUserProfile({
    String? firstName,
    String? lastName,
    String? storeName,
    String? logoUrl,
  }) async {
    final savedUser = (await getUserInfo()) ?? {};
    final updatedMap = Map<String, dynamic>.from(savedUser);

    final String effectiveFirstName = firstName ?? (savedUser['first_name'] ?? '').toString();

    final body = <String, dynamic>{
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      if (storeName != null && storeName.isNotEmpty) 'store_name': storeName,
      if (logoUrl != null && logoUrl.isNotEmpty) ...{
        'logo_url': logoUrl,
        'image': logoUrl,
        'avatar': logoUrl,
      },
    };

    if (firstName != null) updatedMap['first_name'] = firstName;
    if (lastName != null) updatedMap['last_name'] = lastName;
    if (logoUrl != null && logoUrl.isNotEmpty) updatedMap['logo_url'] = logoUrl;
    if (storeName != null && storeName.isNotEmpty) {
      updatedMap['store_name'] = storeName;
    } else if (updatedMap['store_name'] == null || updatedMap['store_name'].toString().isEmpty) {
      final fName = effectiveFirstName.trim();
      if (fName.isNotEmpty) {
        updatedMap['store_name'] = '$fName Store';
      }
    }

    // Persist immediately locally to both active user storage and permanent edited overlay storage
    await saveUserInfo(updatedMap);
    await saveUserEditedProfile(updatedMap);

    try {
      final headers = await _headers();
      http.Response? res;

      final endpoints = [
        ('PUT', '$baseUrl/users/detail'),
        ('PATCH', '$baseUrl/users/detail'),
        ('PUT', '$baseUrl/users/profile'),
        ('POST', '$baseUrl/users/profile'),
        ('PUT', '$baseUrl/users/update'),
        ('POST', '$baseUrl/users/update'),
      ];

      for (final (method, url) in endpoints) {
        try {
          if (method == 'PUT') {
            res = await http.put(Uri.parse(url), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 4));
          } else if (method == 'PATCH') {
            res = await http.patch(Uri.parse(url), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 4));
          } else {
            res = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 4));
          }

          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = _safeJsonDecode(res.body);
            if (data is Map<String, dynamic> && data['success'] != false) {
              final userObj = data['user'] is Map<String, dynamic>
                  ? data['user'] as Map<String, dynamic>
                  : (data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null);
              if (userObj != null) {
                updatedMap.addAll(userObj);
              }
              await saveUserInfo(updatedMap);
              await saveUserEditedProfile(updatedMap);
              return {
                'success': true,
                'message': data['message'] ?? 'Profile details updated successfully!',
                'user': updatedMap,
              };
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('updateUserProfile error: $e');
    }

    return {
      'success': true,
      'message': 'Profile details updated successfully!',
      'user': updatedMap,
    };
  }

  /// POST /users/delete (Deletes user account by ID)
  Future<Map<String, dynamic>> deleteUserAccount(int userId) async {
    try {
      final token = await getToken();
      final res = await http.post(
        Uri.parse('$baseUrl/users/delete'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id': userId}),
      );
      if (res.statusCode == 200) {
        return {'success': true, 'message': 'Account deleted successfully'};
      }
      final data = _safeJsonDecode(res.body);
      return {'success': false, 'message': data?['message'] ?? 'Failed to delete account'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- CMS Content & Store Branding APIs ---

  /// GET /cms/content (Fetch all CMS content including header, contact, whatsapp)
  Future<Map<String, dynamic>> getCmsContent() async {
    try {
      final headers = await _headers();
      final res = await http.get(
        Uri.parse('$baseUrl/cms/content'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          await _storage.write(key: 'cached_cms_content', value: jsonEncode(data));
          return data;
        }
      }
    } catch (e) {
      debugPrint('getCmsContent error: $e');
    }

    try {
      final cached = await _storage.read(key: 'cached_cms_content');
      if (cached != null && cached.isNotEmpty) {
        final decoded = _safeJsonDecode(cached);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}

    return {};
  }

  /// PUT /cms/content/header (Update store header, logo, title)
  Future<Map<String, dynamic>> updateCmsHeader(Map<String, dynamic> headerData) async {
    try {
      final headers = await _headers();
      final res = await http.put(
        Uri.parse('$baseUrl/cms/content/header'),
        headers: headers,
        body: jsonEncode(headerData),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data?['message'] ?? 'Failed to update header'};
    } catch (e) {
      debugPrint('updateCmsHeader error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// PUT /cms/content/contact (Update shop address, phone, email for receipts)
  Future<Map<String, dynamic>> updateCmsContact(Map<String, dynamic> contactData) async {
    try {
      final headers = await _headers();
      final res = await http.put(
        Uri.parse('$baseUrl/cms/content/contact'),
        headers: headers,
        body: jsonEncode(contactData),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data?['message'] ?? 'Failed to update contact'};
    } catch (e) {
      debugPrint('updateCmsContact error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// PUT /cms/content/whatsapp (Update WhatsApp number for digital receipts)
  Future<Map<String, dynamic>> updateCmsWhatsapp(Map<String, dynamic> whatsappData) async {
    try {
      final headers = await _headers();
      final res = await http.put(
        Uri.parse('$baseUrl/cms/content/whatsapp'),
        headers: headers,
        body: jsonEncode(whatsappData),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data?['message'] ?? 'Failed to update whatsapp'};
    } catch (e) {
      debugPrint('updateCmsWhatsapp error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// GET /store/{userId} (Fetch public/store profile by userId)
  Future<Map<String, dynamic>?> getStoreDetail(dynamic userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/store/$userId'),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}
    return null;
  }

  /// Consolidated Store Branding helper (strictly scoped per store owner)
  Future<Map<String, dynamic>> getStoreBranding() async {
    final ownerId = await getEffectiveStoreOwnerId();
    final user = await getUserInfo();
    final email = (user?['email'] ?? '').toString().trim().toLowerCase();
    final userId = user?['id']?.toString() ?? '';
    final isStaff = await isStaffUser();

    // If this is a Staff / Cashier account, ALWAYS prioritize inheriting Store Owner / Admin branding
    if (isStaff) {
      // 1. Check admin_store_branding and admin_store_name scoped to this ownerId
      if (ownerId.isNotEmpty) {
        try {
          final adminBrandingStr = await _storage.read(key: 'admin_store_branding_$ownerId');
          if (adminBrandingStr != null && adminBrandingStr.isNotEmpty) {
            final decoded = _safeJsonDecode(adminBrandingStr);
            if (decoded is Map<String, dynamic>) {
              final bName = (decoded['store_name'] ?? '').toString().trim();
              final bLogo = (decoded['logo_url'] ?? '').toString().trim();
              if ((bName.isNotEmpty && bName != 'Admin Store' && bName != 'User Store') || bLogo.isNotEmpty) {
                return Map<String, dynamic>.from(decoded);
              }
            }
          }
        } catch (_) {}

        final adminName = await getAdminStoreName();
        if (adminName.isNotEmpty) {
          String logo = '';
          try {
            final raw = await _storage.read(key: 'store_branding_$ownerId');
            if (raw != null) {
              final dec = _safeJsonDecode(raw);
              if (dec is Map) logo = (dec['logo_url'] ?? '').toString();
            }
          } catch (_) {}
          return {
            'store_name': adminName,
            'logo_url': logo,
            'address': '',
            'phone': '',
            'email': '',
            'whatsapp': '',
          };
        }
      }

      // 2. Check local_staff_members registry for inherited store_name
      try {
        final localStaff = await getLocalStaffMembers();
        for (final s in localStaff) {
          if ((s['email'] ?? '').toString().trim().toLowerCase() == email) {
            final sName = (s['store_name'] ?? '').toString().trim();
            if (sName.isNotEmpty && sName != 'Admin Store' && sName != 'User Store') {
              return {
                'store_name': sName,
                'logo_url': (s['logo_url'] ?? '').toString(),
                'address': '',
                'phone': '',
                'email': '',
                'whatsapp': '',
              };
            }
          }
        }
      } catch (_) {}
    }

    // Check scoped store branding across only scoped keys (ownerId, userId, email)
    // NEVER fall back to a shared/global 'store_branding' key to prevent cross-account pollution!
    final keysToCheck = [
      if (ownerId.isNotEmpty) 'store_branding_$ownerId',
      if (userId.isNotEmpty && userId != ownerId) 'store_branding_$userId',
      if (email.isNotEmpty) 'store_branding_$email',
    ];

    for (final key in keysToCheck) {
      try {
        final local = await _storage.read(key: key);
        if (local != null && local.isNotEmpty) {
          final decoded = _safeJsonDecode(local);
          if (decoded is Map<String, dynamic>) {
            final logo = (decoded['logo_url'] ?? '').toString().trim();
            final name = (decoded['store_name'] ?? '').toString().trim();
            if (logo.isNotEmpty || (name.isNotEmpty && name != 'Admin Store' && name != 'User Store')) {
              return Map<String, dynamic>.from(decoded);
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback to user profile data for this merchant
    final String fallbackStoreName = (user?['store_name'] ?? '').toString().trim();
    final String userLogo = (user?['logo_url'] ?? user?['image'] ?? user?['avatar'] ?? '').toString().trim();

    String storeName = fallbackStoreName;
    if (storeName.isEmpty && !isStaff && user != null) {
      final firstName = (user['first_name'] ?? '').toString().trim();
      if (firstName.isNotEmpty) {
        storeName = '$firstName Store';
      }
    }

    // 3. If staff, try to inherit Store Owner's branding
    String logoUrl = userLogo;
    if (isStaff && ownerId.isNotEmpty) {
      // First check if owner's branding was cached
      try {
        final ownerBrandingStr = await _storage.read(key: 'store_branding_$ownerId');
        if (ownerBrandingStr != null && ownerBrandingStr.isNotEmpty) {
          final decoded = _safeJsonDecode(ownerBrandingStr);
          if (decoded is Map<String, dynamic>) {
            return Map<String, dynamic>.from(decoded);
          }
        }
      } catch (_) {}

      // Try fetching public store detail of owner
      if (storeName.isEmpty || logoUrl.isEmpty) {
        try {
          final storeDetail = await getStoreDetail(ownerId);
          if (storeDetail != null) {
            if (storeName.isEmpty && storeDetail['store_name'] != null) {
              storeName = storeDetail['store_name'].toString().trim();
            }
            if (logoUrl.isEmpty && (storeDetail['logo_url'] != null || storeDetail['image'] != null)) {
              logoUrl = (storeDetail['logo_url'] ?? storeDetail['image'] ?? '').toString().trim();
            }
          }
        } catch (_) {}
      }
    }

    // 4. Cloud Fallback: Sync store logo and branding from CMS content across devices (PC Web <-> Mac <-> Mobile)
    String address = (user?['address'] ?? '').toString().trim();
    String phone = (user?['phone'] ?? '').toString().trim();
    String whatsapp = '';
    try {
      final cms = await getCmsContent();
      final cmsHeader = cms['header'];
      if (cmsHeader is Map) {
        final cmsLogo = (cmsHeader['logo_url'] ?? '').toString().trim();
        if (logoUrl.isEmpty && cmsLogo.isNotEmpty && !cmsLogo.endsWith('/uploads/logo.png')) {
          logoUrl = cmsLogo;
        }
        final cmsStore = (cmsHeader['store_name'] ?? cmsHeader['title'] ?? '').toString().trim();
        if (storeName.isEmpty && cmsStore.isNotEmpty && cmsStore != 'Admin Store' && cmsStore != 'User Store') {
          storeName = cmsStore;
        }
      }
      if (address.isEmpty && cms['contact'] is Map) {
        address = (cms['contact']['address'] ?? '').toString().trim();
      }
      if (phone.isEmpty && cms['contact'] is Map) {
        phone = (cms['contact']['phone'] ?? '').toString().trim();
      }
      if (cms['whatsapp'] is Map) {
        whatsapp = (cms['whatsapp']['whatsapp_number'] ?? cms['whatsapp']['phoneNumber'] ?? '').toString().trim();
      }
    } catch (_) {}

    final branding = {
      'store_name': (storeName == 'Admin Store' || storeName == 'User Store') ? '' : storeName,
      'logo_url': logoUrl, // Strictly this merchant's logo! Does not leak other admins' photos.
      'address': address,
      'phone': phone,
      'email': (user?['email'] ?? '').toString().trim(),
      'whatsapp': whatsapp,
    };

    if (branding['store_name']!.isNotEmpty || branding['logo_url']!.isNotEmpty) {
      await saveStoreBranding(branding);
    }
    return branding;
  }

  Future<void> saveStoreBranding(Map<String, dynamic> branding) async {
    try {
      final ownerId = await getEffectiveStoreOwnerId();
      final user = await getUserInfo();
      final email = (user?['email'] ?? branding['email'] ?? '').toString().trim().toLowerCase();
      final userId = user?['id']?.toString() ?? '';
      final isStaff = await isStaffUser();

      final encoded = jsonEncode(branding);

      if (ownerId.isNotEmpty) {
        await _storage.write(key: 'store_branding_$ownerId', value: encoded);
      }
      if (email.isNotEmpty) {
        await _storage.write(key: 'store_branding_$email', value: encoded);
      }
      if (userId.isNotEmpty && userId != ownerId) {
        await _storage.write(key: 'store_branding_$userId', value: encoded);
      }

      // If store owner, persist as master admin store branding for all staff to inherit!
      if (!isStaff && ownerId.isNotEmpty) {
        final storeName = (branding['store_name'] ?? '').toString().trim();
        if (storeName.isNotEmpty && storeName != 'Admin Store' && storeName != 'User Store') {
          await _storage.write(key: 'admin_store_name_$ownerId', value: storeName);
        }
        await _storage.write(key: 'admin_store_branding_$ownerId', value: encoded);
      }

      // Explicitly delete un-namespaced keys to protect other admins
      await _storage.delete(key: 'store_branding');
      await _storage.delete(key: 'admin_store_branding');
      await _storage.delete(key: 'admin_store_name');
    } catch (_) {}
  }

  Future<bool> isStoreSetupCompleted() async {
    final ownerId = await getEffectiveStoreOwnerId();
    final user = await getUserInfo();
    final userId = user?['id']?.toString() ?? '';
    final scopeId = ownerId.isNotEmpty ? ownerId : userId;

    if (scopeId.isNotEmpty) {
      final scopedFlag = await _storage.read(key: 'store_setup_completed_$scopeId');
      if (scopedFlag == 'true') return true;
      if (scopedFlag == 'false') return false;
    }

    final flag = await _storage.read(key: 'store_setup_completed');
    if (flag == 'true') return true;
    if (flag == 'false') return false;

    // Fast check: if user already has an active store_name in user info, setup is completed!
    final sName = (user?['store_name'] ?? '').toString().trim();
    if (sName.isNotEmpty && sName != 'Admin Store' && sName != 'User Store' && sName != 'POS STORE') {
      if (scopeId.isNotEmpty) {
        await _storage.write(key: 'store_setup_completed_$scopeId', value: 'true');
      }
      await _storage.write(key: 'store_setup_completed', value: 'true');
      return true;
    }

    // Check scoped branding for this user/owner
    final branding = await getStoreBranding();
    final name = (branding['store_name'] ?? '').toString().trim();
    if (name.isNotEmpty && name != 'Admin Store' && name != 'User Store' && name != 'POS STORE') {
      if (scopeId.isNotEmpty) {
        await _storage.write(key: 'store_setup_completed_$scopeId', value: 'true');
      }
      return true;
    }
    return false;
  }

  Future<void> setStoreSetupCompleted(bool completed) async {
    final ownerId = await getEffectiveStoreOwnerId();
    final user = await getUserInfo();
    final userId = user?['id']?.toString() ?? '';
    final scopeId = ownerId.isNotEmpty ? ownerId : userId;
    if (scopeId.isNotEmpty) {
      await _storage.write(key: 'store_setup_completed_$scopeId', value: completed ? 'true' : 'false');
    }
    await _storage.write(key: 'store_setup_completed', value: completed ? 'true' : 'false');
  }

  Future<void> saveSetupDraft(Map<String, dynamic> draft) async {
    try {
      await _storage.write(key: 'pos_setup_draft', value: jsonEncode(draft));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getSetupDraft() async {
    try {
      final str = await _storage.read(key: 'pos_setup_draft');
      if (str != null && str.isNotEmpty) {
        final decoded = _safeJsonDecode(str);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearSetupDraft() async {
    try {
      await _storage.delete(key: 'pos_setup_draft');
    } catch (_) {}
  }

  // --- Billing & Tax Preferences ---
  Future<Map<String, dynamic>> getBillingSettings() async {
    try {
      final str = await _storage.read(key: 'pos_billing_settings');
      if (str != null && str.isNotEmpty) {
        final decoded = _safeJsonDecode(str);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return {
      'currency_symbol': 'LKR',
      'currency_code': 'LKR',
      'tax_rate': 0.0,
      'tax_included': true,
      'thank_you_message': 'Thank you for shopping with us! Please come again.',
      'return_policy': 'Returns accepted within 7 days with original receipt. No cash refunds.',
    };
  }

  Future<void> saveBillingSettings(Map<String, dynamic> settings) async {
    try {
      await _storage.write(key: 'pos_billing_settings', value: jsonEncode(settings));
    } catch (_) {}
  }

  // --- Hardware & Terminal Preferences ---
  Future<Map<String, dynamic>> getHardwareSettings() async {
    try {
      final str = await _storage.read(key: 'pos_hardware_settings');
      if (str != null && str.isNotEmpty) {
        final decoded = _safeJsonDecode(str);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return {
      'paper_size': '58mm',
      'auto_print': true,
      'scanner_mode': 'camera',
      'payment_methods': ['Cash', 'Card', 'Bank Transfer / QR Pay'],
    };
  }

  Future<void> saveHardwareSettings(Map<String, dynamic> settings) async {
    try {
      await _storage.write(key: 'pos_hardware_settings', value: jsonEncode(settings));
    } catch (_) {}
  }

  /// Seed Demo Starter Products for first-time store owners
  Future<bool> seedDemoProducts({String categoryName = 'General'}) async {
    try {
      final cleanCat = categoryName.trim().isEmpty ? 'General' : categoryName.trim();
      final slug = cleanCat.toLowerCase().replaceAll(' ', '-');

      // 1. Create Category
      await createCategory({
        'name': cleanCat,
        'slug': slug,
        'description': '$cleanCat merchandise and products',
        'status': 'active',
      });

      // 2. Fetch categories to find created ID
      final cats = await getCategories(forceRefresh: true);
      int targetCatId = 1;
      for (var c in cats) {
        if (c is Map && c['name']?.toString().toLowerCase() == cleanCat.toLowerCase()) {
          targetCatId = int.tryParse(c['id']?.toString() ?? '1') ?? 1;
          break;
        }
      }
      if (targetCatId == 1 && cats.isNotEmpty && cats.first is Map) {
        targetCatId = int.tryParse(cats.first['id']?.toString() ?? '1') ?? 1;
      }

      // 3. Create 3 standard quick-starter products
      final demoItems = [
        {
          'category_id': targetCatId,
          'name': 'Fresh Milk 1L',
          'sku': 'MILK-1L-${DateTime.now().millisecond % 900}',
          'price': 480.0,
          'discount_price': 450.0,
          'stock': 35,
          'status': 'active',
          'short_description': 'Pasteurized fresh whole milk carton 1L',
          'main_image': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&auto=format&fit=crop&q=80',
        },
        {
          'category_id': targetCatId,
          'name': 'White Sandwich Bread 450g',
          'sku': 'BREAD-450G-${DateTime.now().millisecond % 900}',
          'price': 190.0,
          'discount_price': 190.0,
          'stock': 24,
          'status': 'active',
          'short_description': 'Freshly baked sliced white sandwich bread loaf',
          'main_image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        },
        {
          'category_id': targetCatId,
          'name': 'Pure Ceylon Black Tea 200g',
          'sku': 'TEA-200G-${DateTime.now().millisecond % 900}',
          'price': 380.0,
          'discount_price': 350.0,
          'stock': 40,
          'status': 'active',
          'short_description': 'Premium single origin highland black tea pack',
          'main_image': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
        },
      ];

      for (var item in demoItems) {
        await createProduct(item);
      }

      invalidateCatalogCache();
      return true;
    } catch (e) {
      debugPrint('seedDemoProducts error: $e');
      return false;
    }
  }
  dynamic _safeJsonDecode(String body) {
    try {
      final trimmed = body.trim();
      if (trimmed.isEmpty || trimmed.startsWith('<') || trimmed.startsWith('<!DOCTYPE')) {
        return null;
      }
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLocalStaffMembers() async {
    try {
      final str = await _storage.read(key: 'local_staff_members');
      if (str != null && str.isNotEmpty) {
        final decoded = _safeJsonDecode(str);
        if (decoded is List) {
          final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final currentUser = await getUserInfo();
          final ownerEmail = (currentUser?['email'] ?? '').toString().trim().toLowerCase();
          if (ownerEmail.isNotEmpty) {
            list.removeWhere((item) =>
                (item['email'] ?? '').toString().trim().toLowerCase() == ownerEmail);
          }
          return list;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveLocalStaffMember(Map<String, dynamic> staff) async {
    try {
      final email = (staff['email'] ?? '').toString().trim().toLowerCase();
      final currentUser = await getUserInfo();
      final ownerEmail = (currentUser?['email'] ?? '').toString().trim().toLowerCase();
      if (ownerEmail.isNotEmpty && email == ownerEmail) return; // Do not save logged-in owner as staff
      final current = await getLocalStaffMembers();
      current.removeWhere((item) => (item['email'] ?? '').toString().trim().toLowerCase() == email);
      current.insert(0, staff);
      await _storage.write(key: 'local_staff_members', value: jsonEncode(current));
    } catch (_) {}
  }

  Future<void> removeLocalStaffMember(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final current = await getLocalStaffMembers();
      current.removeWhere((item) =>
          (item['email'] ?? '').toString().trim().toLowerCase() == cleanEmail);
      await _storage.write(key: 'local_staff_members', value: jsonEncode(current));
    } catch (_) {}
  }

  /// Permanently removes all unsynced/rejected staff members from local database/storage
  Future<void> purgeUnsyncedStaffMembers() async {
    try {
      final current = await getLocalStaffMembers();
      current.removeWhere((item) => item['is_synced'] != true);
      await _storage.write(key: 'local_staff_members', value: jsonEncode(current));
      debugPrint('[ApiService] Successfully purged unsynced staff members from local database.');
    } catch (_) {}
  }

  /// POST /users/staff/delete (Admin deletes a staff member from backend & local storage)
  Future<Map<String, dynamic>> deleteStaffMember({required String email, dynamic id}) async {
    await removeLocalStaffMember(email);
    try {
      final headers = await _headers();
      if (id != null) {
        final parsedId = id is int ? id : int.tryParse(id.toString());
        if (parsedId != null) {
          final res = await http.post(
            Uri.parse('$baseUrl/users/staff/delete'),
            headers: headers,
            body: jsonEncode({'id': parsedId}),
          ).timeout(const Duration(seconds: 6));

          final data = _safeJsonDecode(res.body);
          if (data is Map && data['success'] == false) {
            return {
              'success': false,
              'message': data['message'] ?? data['error'] ?? 'Failed to delete staff on server',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('deleteStaffMember error: $e');
    }
    return {'success': true, 'message': 'Staff member deleted successfully!'};
  }

  /// Update existing staff member details (Name, Email, Role, and Password)
  Future<Map<String, dynamic>> updateStaffMember({
    required dynamic id,
    required String originalEmail,
    required String firstName,
    required String lastName,
    required String email,
    String? newPassword,
    String role = 'staff',
  }) async {
    final cleanOriginalEmail = originalEmail.trim().toLowerCase();
    final cleanNewEmail = email.trim().toLowerCase();

    // 1. Get cached staff details to retain password if not changing
    final localStaffList = await getLocalStaffMembers();
    Map<String, dynamic>? currentCachedStaff;
    for (var s in localStaffList) {
      if ((s['email'] ?? '').toString().trim().toLowerCase() == cleanOriginalEmail) {
        currentCachedStaff = Map<String, dynamic>.from(s);
        break;
      }
    }

    final effectivePassword = (newPassword != null && newPassword.trim().isNotEmpty)
        ? newPassword.trim()
        : (currentCachedStaff?['password'] ?? '');

    // 2. Remove old record from local storage
    await removeLocalStaffMember(cleanOriginalEmail);

    final currentUser = await getUserInfo();
    final ownerId = currentUser?['id'];
    final storeBranding = await getStoreBranding();
    final effectiveStoreName = (currentUser?['store_name'] ?? storeBranding['store_name'] ?? '').toString().trim();

    final updatedLocalStaff = {
      'id': id ?? DateTime.now().millisecondsSinceEpoch,
      'first_name': firstName,
      'last_name': lastName,
      'email': cleanNewEmail,
      'password': effectivePassword,
      'role': role,
      'parent_id': ownerId,
      'user_type': 3,
      'store_name': effectiveStoreName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // 3. Attempt server update by removing old staff ID and re-adding with updated credentials
    try {
      final headers = await _headers();

      if (id != null) {
        final parsedId = id is int ? id : int.tryParse(id.toString());
        if (parsedId != null) {
          try {
            await http.post(
              Uri.parse('$baseUrl/users/staff/delete'),
              headers: headers,
              body: jsonEncode({'id': parsedId}),
            ).timeout(const Duration(seconds: 6));
          } catch (_) {}
        }
      }

      final addRes = await http.post(
        Uri.parse('$baseUrl/users/staff/add'),
        headers: headers,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': cleanNewEmail,
          'password': effectivePassword,
          'user_type': 3,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(addRes.body);
      if (data is Map<String, dynamic>) {
        final isSuccess = (addRes.statusCode == 200 || addRes.statusCode == 201) &&
            data['success'] != false &&
            data['error'] == null;

        if (isSuccess) {
          final staffObj = data['staff'] ?? data['user'] ?? data['data'] ?? data;
          final Map<String, dynamic> finalStaff = staffObj is Map<String, dynamic>
              ? Map<String, dynamic>.from(staffObj)
              : updatedLocalStaff;
          finalStaff['password'] = effectivePassword;
          finalStaff['role'] = role;
          finalStaff['user_type'] = 3;
          await saveLocalStaffMember(finalStaff);
          return {
            'success': true,
            'message': 'Staff member updated successfully!',
            'staff': finalStaff,
          };
        }
      }
    } catch (e) {
      debugPrint('updateStaffMember connection error: $e');
    }

    // Fallback: persist updated staff locally
    await saveLocalStaffMember(updatedLocalStaff);
    return {
      'success': true,
      'message': 'Staff member updated successfully!',
      'staff': updatedLocalStaff,
    };
  }

  /// POST /users/staff/add (Store Owner / Admin creates Cashier account)
  Future<Map<String, dynamic>> addStaffMember({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String role = 'staff',
  }) async {
    final currentUser = await getUserInfo();
    final ownerId = currentUser?['id'];
    final storeBranding = await getStoreBranding();
    final effectiveStoreName = (currentUser?['store_name'] ?? storeBranding['store_name'] ?? '').toString().trim();

    final newLocalStaff = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'role': role,
      'parent_id': ownerId,
      'user_type': 3,
      'store_name': effectiveStoreName,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final headers = await _headers();
      final body = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'user_type': 3,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/users/staff/add'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 8));

      final data = _safeJsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final isSuccess = (res.statusCode == 200 || res.statusCode == 201) &&
            data['success'] != false &&
            data['error'] == null;

        if (isSuccess) {
          final staffObj = data['staff'] ?? data['user'] ?? data['data'] ?? data;
          final Map<String, dynamic> finalStaff = staffObj is Map<String, dynamic>
              ? Map<String, dynamic>.from(staffObj)
              : newLocalStaff;
          finalStaff['role'] = finalStaff['role'] ?? role;
          finalStaff['user_type'] = finalStaff['user_type'] ?? 3;
          finalStaff['password'] = password;
          finalStaff['store_name'] = effectiveStoreName;
          await saveLocalStaffMember(finalStaff);
          return {
            'success': true,
            'message': data['message'] ?? 'Staff member created successfully',
            'staff': finalStaff,
          };
        }

        final errorMsg = data['error'] ?? data['message'] ?? 'Failed to add staff member on server';
        return {
          'success': false,
          'message': errorMsg.toString(),
        };
      }
    } catch (e) {
      debugPrint('Add staff connection error: $e');
      // If offline / network error, save locally as fallback
      await saveLocalStaffMember(newLocalStaff);
      return {
        'success': true,
        'message': 'Staff member created (Offline mode)!',
        'staff': newLocalStaff,
      };
    }

    await saveLocalStaffMember(newLocalStaff);
    return {
      'success': true,
      'message': 'Staff member created successfully!',
      'staff': newLocalStaff,
    };
  }

  /// GET /users/staff (Fetch store staff/cashiers list with auto-sync)
  Future<List<dynamic>> getStaffMembers() async {
    final localList = await getLocalStaffMembers();
    try {
      final headers = await _headers();

      // 1. Auto-sync any unsynced local staff to backend database
      if (headers.containsKey('Authorization') && localList.isNotEmpty) {
        for (var staff in localList) {
          final email = (staff['email'] ?? '').toString().trim().toLowerCase();
          final password = (staff['password'] ?? '').toString().trim();
          final firstName = (staff['first_name'] ?? '').toString().trim();
          final lastName = (staff['last_name'] ?? '').toString().trim();
          final isSynced = staff['is_synced'] == true;

          if (!isSynced && email.isNotEmpty && password.isNotEmpty) {
            try {
              final addRes = await http.post(
                Uri.parse('$baseUrl/users/staff/add'),
                headers: headers,
                body: jsonEncode({
                  'first_name': firstName,
                  'last_name': lastName,
                  'email': email,
                  'password': password,
                  'user_type': 3,
                }),
              ).timeout(const Duration(seconds: 4));

              if (addRes.statusCode == 200 || addRes.statusCode == 201) {
                staff['is_synced'] = true;
                await saveLocalStaffMember(staff);
                debugPrint('Auto-synced local staff to backend database: $email');
              }
            } catch (_) {}
          }
        }
      }

      // 2. Fetch fresh staff list from server
      final res = await http.get(
        Uri.parse('$baseUrl/users/staff'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = _safeJsonDecode(res.body);
        List remoteList = [];
        if (data is List) {
          remoteList = data;
        } else if (data is Map<String, dynamic> && data['data'] is List) {
          remoteList = data['data'] as List;
        } else if (data is Map<String, dynamic> && data['staff'] is List) {
          remoteList = data['staff'] as List;
        }

        final Map<String, dynamic> combined = {};
        for (var item in remoteList) {
          if (item is Map) {
            final email = (item['email'] ?? item['id'] ?? '').toString();
            if (email.isNotEmpty) combined[email] = Map<String, dynamic>.from(item);
          }
        }
        for (var item in localList) {
          final email = (item['email'] ?? item['id'] ?? '').toString();
          if (email.isNotEmpty && !combined.containsKey(email)) {
            combined[email] = item;
          }
        }
        return combined.values.toList();
      }
    } catch (e) {
      debugPrint('getStaffMembers error: $e');
    }

    return localList;
  }

  // ==========================================
  // --- ORDERS & BILLING APIS ---
  // ==========================================

  /// 1. POST /orders/{userId} (Place In-Store Bill / Order)
  Future<Map<String, dynamic>> placeOrder({
    dynamic userId,
    required String paymentMethod,
    required double totalAmount,
    double? subtotal,
    double? paidAmount,
    double? changeAmount,
    required List<dynamic> items,
    Map<String, dynamic>? customerInfo,
  }) async {
    dynamic effectiveUserId = userId;
    final currentUser = await getUserInfo();
    if (effectiveUserId == null) {
      effectiveUserId = currentUser?['id'] ?? 1;
    }

    // Determine the Merchant Store Owner ID:
    // If cashier is a staff member (has parent_id), the merchant store whose inventory is billed is the parent/owner!
    final parentId = currentUser?['parent_id'];
    final bool isStaffUser = parentId != null &&
        parentId.toString().isNotEmpty &&
        parentId.toString() != '0' &&
        parentId.toString().toLowerCase() != 'null';
    final merchantOwnerId = isStaffUser
        ? (parentId is int ? parentId : int.tryParse(parentId.toString()) ?? effectiveUserId)
        : effectiveUserId;

    final String cashierFullName = currentUser != null
        ? '${currentUser['first_name'] ?? ''} ${currentUser['last_name'] ?? ''}'.trim()
        : 'Staff';
    final String cashierEmail = (currentUser?['email'] ?? '').toString().trim();

    final double effectiveSubtotal = subtotal ?? totalAmount;
    final double effectivePaid = paidAmount ?? totalAmount;
    final double effectiveChange = changeAmount ?? (effectivePaid - totalAmount).clamp(0.0, double.infinity);

    final mappedItems = items.map((item) {
      final map = item is Map<String, dynamic> ? item : (item as Map);
      final id = map['id'] ?? map['product_id'] ?? map['productId'];
      final sku = map['sku'] ?? map['product_sku'] ?? 'SKU-$id';
      final name = map['name'] ?? map['product_name'] ?? 'Item';
      final price = double.tryParse(map['price']?.toString() ?? map['unit_price']?.toString() ?? '0') ?? 0.0;
      final discountPrice = double.tryParse(map['discount_price']?.toString() ?? '') ?? price;
      final effectivePrice = (discountPrice > 0 && discountPrice < price) ? discountPrice : (discountPrice > 0 ? discountPrice : price);
      final qty = int.tryParse(map['quantity']?.toString() ?? map['qty']?.toString() ?? '1') ?? 1;
      final variation = map['selectedVariation'] ?? map['selected_variation'] ?? map['variation'];

      return {
        'productId': id,
        'product_id': id,
        'sku': sku,
        'name': name,
        'price': effectivePrice,
        'unit_price': effectivePrice,
        'quantity': qty,
        'selectedVariation': variation,
        'selected_variation': variation,
        'totalPrice': qty * effectivePrice,
        'total_price': qty * effectivePrice,
      };
    }).toList();

    final String customerName = customerInfo?['name'] ?? customerInfo?['customer_name'] ?? 'Walk-in Customer';
    final String customerPhone = customerInfo?['phone'] ?? customerInfo?['customer_phone'] ?? '0770000000';
    final String customerAddress = customerInfo?['address'] ?? customerInfo?['customer_address'] ?? 'In-Store Counter';

    final body = {
      'userId': merchantOwnerId,
      'user_id': merchantOwnerId,
      'merchant_id': merchantOwnerId,
      'cashier_id': effectiveUserId,
      'cashierId': effectiveUserId,
      'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : 'Staff',
      'cashierName': cashierFullName.isNotEmpty ? cashierFullName : 'Staff',
      'customer_name': customerName,
      'customerName': customerName,
      'customer_phone': customerPhone,
      'customerPhone': customerPhone,
      'customer_address': customerAddress,
      'customerAddress': customerAddress,
      'payment_method': paymentMethod,
      'paymentMethod': paymentMethod,
      'subtotal': effectiveSubtotal,
      'total_amount': totalAmount,
      'totalAmount': totalAmount,
      'paid_amount': effectivePaid,
      'paidAmount': effectivePaid,
      'change_amount': effectiveChange,
      'changeAmount': effectiveChange,
      'customer': customerInfo,
      'items': mappedItems,
      'notes': jsonEncode({
        'cashier_id': effectiveUserId,
        'cashierId': effectiveUserId,
        'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : (isStaffUser ? 'Staff' : 'Owner / Admin'),
        'role': isStaffUser ? 'staff' : 'admin',
      }),
    };

    try {
      final headers = await _headers();
      // Route to Merchant Store Owner endpoint POST /orders/{merchantOwnerId}
      http.Response res = await http.post(
        Uri.parse('$baseUrl/orders/$merchantOwnerId'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 404) {
        res = await http.post(
          Uri.parse('$baseUrl/orders'),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        // Order placed successfully: clear product catalog cache so updated inventory stock is fetched
        invalidateCatalogCache();

        if (data is Map<String, dynamic>) {
          final receiptNo = data['receipt_number'] ?? data['order_number'] ?? data['order_id'] ?? data['id'] ?? 'INV-${DateTime.now().millisecondsSinceEpoch % 1000000}';
          final completedOrderRecord = {
            'id': data['id'] ?? data['order_id'] ?? DateTime.now().millisecondsSinceEpoch,
            'order_number': receiptNo,
            'receipt_number': receiptNo,
            'user_id': merchantOwnerId,
            'cashier_id': effectiveUserId,
            'cashierId': effectiveUserId,
            'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : 'Staff',
            'cashier_email': cashierEmail,
            'customer_name': customerName,
            'customer_phone': customerPhone,
            'customer_address': customerAddress,
            'payment_method': paymentMethod,
            'payment_status': 'paid',
            'order_status': 'completed',
            'subtotal': effectiveSubtotal.toStringAsFixed(2),
            'total_amount': totalAmount.toStringAsFixed(2),
            'paid_amount': effectivePaid.toStringAsFixed(2),
            'change_amount': effectiveChange.toStringAsFixed(2),
            'items': mappedItems,
            'notes': jsonEncode({
              'cashier_id': effectiveUserId,
              'cashierId': effectiveUserId,
              'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : (isStaffUser ? 'Staff' : 'Owner / Admin'),
              'cashier_email': cashierEmail,
              'email': cashierEmail,
              'role': isStaffUser ? 'staff' : 'admin',
            }),
            'created_at': DateTime.now().toIso8601String(),
          };
          await saveLocalCompletedOrder(completedOrderRecord);

          return {
            'success': true,
            'order_id': data['order_id'] ?? data['id'] ?? receiptNo,
            'receipt_number': receiptNo,
            'status': data['status'] ?? 'completed',
            'receipt_url': data['receipt_url'],
            'data': data,
          };
        }
      }

      // If backend fails with non-200, save as local completed bill & queue for offline sync
      final fallbackReceipt = 'INV-LOCAL-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final fallbackOrderRecord = {
        'id': 'ORD-$fallbackReceipt',
        'order_number': fallbackReceipt,
        'receipt_number': fallbackReceipt,
        'user_id': merchantOwnerId,
        'cashier_id': effectiveUserId,
        'cashierId': effectiveUserId,
        'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : 'Staff',
        'cashier_email': cashierEmail,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'payment_method': paymentMethod,
        'payment_status': 'paid',
        'order_status': 'completed',
        'subtotal': effectiveSubtotal.toStringAsFixed(2),
        'total_amount': totalAmount.toStringAsFixed(2),
        'paid_amount': effectivePaid.toStringAsFixed(2),
        'change_amount': effectiveChange.toStringAsFixed(2),
        'items': mappedItems,
        'notes': jsonEncode({
          'cashier_id': effectiveUserId,
          'cashierId': effectiveUserId,
          'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : (isStaffUser ? 'Staff' : 'Owner / Admin'),
          'cashier_email': cashierEmail,
          'email': cashierEmail,
          'role': isStaffUser ? 'staff' : 'admin',
        }),
        'created_at': DateTime.now().toIso8601String(),
      };
      await saveLocalCompletedOrder(fallbackOrderRecord);
      try {
        await OfflineSyncService().queueOrder(body);
      } catch (_) {}

      return {
        'success': true,
        'order_id': fallbackReceipt,
        'receipt_number': fallbackReceipt,
        'status': 'completed',
        'message': 'Bill completed and saved locally.',
      };
    } catch (e) {
      debugPrint('placeOrder error (saving offline): $e');
      try {
        await OfflineSyncService().queueOrder(body);
      } catch (_) {}

      final fallbackReceipt = 'OFFLINE-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final offlineOrderRecord = {
        'id': 'ORD-$fallbackReceipt',
        'order_number': fallbackReceipt,
        'receipt_number': fallbackReceipt,
        'user_id': merchantOwnerId,
        'cashier_id': effectiveUserId,
        'cashierId': effectiveUserId,
        'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : 'Staff',
        'cashier_email': cashierEmail,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'payment_method': paymentMethod,
        'payment_status': 'paid',
        'order_status': 'completed',
        'subtotal': effectiveSubtotal.toStringAsFixed(2),
        'total_amount': totalAmount.toStringAsFixed(2),
        'paid_amount': effectivePaid.toStringAsFixed(2),
        'change_amount': effectiveChange.toStringAsFixed(2),
        'items': mappedItems,
        'notes': jsonEncode({
          'cashier_id': effectiveUserId,
          'cashierId': effectiveUserId,
          'cashier_name': cashierFullName.isNotEmpty ? cashierFullName : 'Staff',
          'cashier_email': cashierEmail,
          'email': cashierEmail,
          'role': isStaffUser ? 'staff' : 'admin',
        }),
        'created_at': DateTime.now().toIso8601String(),
      };
      await saveLocalCompletedOrder(offlineOrderRecord);

      return {
        'success': true,
        'order_id': 'ORD-OFFLINE-${DateTime.now().millisecondsSinceEpoch}',
        'receipt_number': fallbackReceipt,
        'status': 'offline_queued',
        'is_offline': true,
        'message': 'Bill processed & saved locally (Offline mode)! Will auto-sync when online.',
      };
    }
  }

  /// Backward-compatible wrapper for existing calls
  Future<Map<String, dynamic>> createOrder({
    required int cashierId,
    required String paymentMethod,
    required double totalAmount,
    required double paidAmount,
    required double changeAmount,
    required List<dynamic> items,
  }) async {
    return placeOrder(
      userId: cashierId,
      paymentMethod: paymentMethod,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      items: items,
    );
  }

  /// 2. GET /orders (Sales / Bills History)
  /// Always uses Merchant Owner Token so Staff users can view orders without 403 Forbidden!
  /// Merges remote backend orders with locally completed orders and pending offline bills.
  Future<Map<String, dynamic>> getOrders({
    String? date,
    String? paymentStatus,
    String? orderStatus,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'All') {
      queryParams['payment_status'] = paymentStatus.toLowerCase();
    }
    if (orderStatus != null && orderStatus.isNotEmpty && orderStatus != 'All') {
      queryParams['order_status'] = orderStatus.toLowerCase();
    }

    final uri = Uri.parse('$baseUrl/orders').replace(queryParameters: queryParams);

    List<dynamic> remoteOrders = [];

    try {
      final ownerToken = await getMerchantOwnerToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (ownerToken != null && ownerToken.isNotEmpty) 'Authorization': 'Bearer $ownerToken',
      };
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          remoteOrders = data;
        } else if (data is Map<String, dynamic>) {
          final list = data['orders'] ?? data['data'] ?? [];
          if (list is List) {
            remoteOrders = list;
          }
        }
      } else {
        debugPrint('getOrders remote returned ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('getOrders remote network error: $e');
    }

    // Retrieve locally saved orders and pending offline orders
    final localOrders = await getLocalCompletedOrders();
    final pendingQueue = await OfflineSyncService().getPendingOrders();
    for (final p in pendingQueue) {
      final payload = p['payload'] as Map<String, dynamic>? ?? {};
      final qId = p['queue_id'] ?? 'OFFLINE-${p['created_at']}';
      localOrders.add({
        'id': qId,
        'order_number': qId,
        'receipt_number': qId,
        'customer_name': payload['customer_name'] ?? 'Walk-in Customer',
        'customer_phone': payload['customer_phone'] ?? '0770000000',
        'total_amount': (payload['total_amount'] ?? payload['totalAmount'] ?? 0.0).toString(),
        'items': payload['items'] ?? [],
        'notes': payload['notes'],
        'cashier_id': payload['cashier_id'] ?? payload['cashierId'],
        'cashier_name': payload['cashier_name'] ?? payload['cashierName'] ?? 'Staff',
        'order_status': 'completed',
        'payment_status': 'paid',
        'created_at': p['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }

    // Merge and deduplicate orders by receipt number / order number / id
    final Map<String, Map<String, dynamic>> mergedMap = {};

    for (final ro in remoteOrders) {
      if (ro is Map) {
        final map = Map<String, dynamic>.from(ro);
        final key = (map['receipt_number'] ?? map['order_number'] ?? map['id'] ?? '').toString();
        if (key.isNotEmpty) mergedMap[key] = map;
      }
    }

    for (final lo in localOrders) {
      final key = (lo['receipt_number'] ?? lo['order_number'] ?? lo['id'] ?? '').toString();
      if (key.isNotEmpty) {
        if (mergedMap.containsKey(key)) {
          final existing = mergedMap[key]!;
          if ((existing['notes'] == null || existing['notes'].toString().isEmpty) && lo['notes'] != null) {
            existing['notes'] = lo['notes'];
          }
          if (existing['cashier_name'] == null && lo['cashier_name'] != null) {
            existing['cashier_name'] = lo['cashier_name'];
          }
        } else {
          mergedMap[key] = lo;
        }
      }
    }

    final mergedList = mergedMap.values.toList();
    mergedList.sort((a, b) {
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return {
      'success': true,
      'orders': mergedList,
    };
  }

  /// 3. GET /orders/{id} (Bill Details & Thermal Re-Print)
  Future<Map<String, dynamic>> getOrderDetails(dynamic orderId) async {
    try {
      final headers = await _headers();
      final res = await http.get(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return {'success': true, 'order': data['order'] ?? data['data'] ?? data};
        }
      }
      return {'success': false, 'message': 'Failed to fetch bill details (HTTP ${res.statusCode})'};
    } catch (e) {
      debugPrint('getOrderDetails error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 4. PUT /orders/{id} (Cancel Bill / Refund)
  Future<Map<String, dynamic>> updateOrderStatus(
    dynamic orderId, {
    String? orderStatus,
    String? paymentStatus,
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (orderStatus != null) {
      body['order_status'] = orderStatus;
      body['orderStatus'] = orderStatus;
    }
    if (paymentStatus != null) {
      body['payment_status'] = paymentStatus;
      body['paymentStatus'] = paymentStatus;
    }
    if (reason != null && reason.isNotEmpty) {
      body['reason'] = reason;
      body['cancel_reason'] = reason;
    }

    try {
      final headers = await _headers();
      final res = await http.put(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 204) {
        return {
          'success': true,
          'message': data is Map<String, dynamic> ? (data['message'] ?? 'Bill status updated') : 'Updated',
          'data': data,
        };
      }
      final msg = data is Map<String, dynamic> ? (data['message'] ?? data['error'] ?? 'Update failed') : 'Failed';
      return {'success': false, 'message': msg.toString()};
    } catch (e) {
      debugPrint('updateOrderStatus error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Remove an order from local completed orders storage
  Future<void> removeLocalCompletedOrder(dynamic orderIdentifier) async {
    try {
      if (orderIdentifier == null) return;
      final list = await getLocalCompletedOrders();
      final targetStr = orderIdentifier.toString().trim();
      list.removeWhere((o) {
        final id = (o['id'] ?? '').toString().trim();
        final orderNo = (o['order_number'] ?? '').toString().trim();
        final receiptNo = (o['receipt_number'] ?? '').toString().trim();
        return id == targetStr || orderNo == targetStr || receiptNo == targetStr;
      });
      await _storage.write(key: 'local_completed_orders', value: jsonEncode(list));
    } catch (e) {
      debugPrint('removeLocalCompletedOrder error: $e');
    }
  }

  /// 5. DELETE /orders/{id} (Permanently delete an order / bill - Admin only)
  Future<Map<String, dynamic>> deleteOrder(
    dynamic orderId, {
    String? orderNumber,
    String? receiptNumber,
  }) async {
    // 1. Clean from local completed cache
    await removeLocalCompletedOrder(orderId);
    if (orderNumber != null) await removeLocalCompletedOrder(orderNumber);
    if (receiptNumber != null) await removeLocalCompletedOrder(receiptNumber);

    // 2. Clean from offline pending queue if present
    try {
      final queueStr = await _storage.read(key: 'offline_pending_orders');
      if (queueStr != null && queueStr.isNotEmpty) {
        final list = jsonDecode(queueStr) as List;
        list.removeWhere((item) {
          final qId = item['queue_id']?.toString() ?? '';
          final p = item['payload'] as Map<String, dynamic>? ?? {};
          final oId = (p['id'] ?? p['order_id'] ?? '').toString();
          final rNo = (p['receipt_number'] ?? p['order_number'] ?? '').toString();
          final target = orderId.toString();
          return qId == target || oId == target || rNo == target;
        });
        await _storage.write(key: 'offline_pending_orders', value: jsonEncode(list));
      }
    } catch (_) {}

    // 3. Delete from remote MySQL backend using merchant owner token
    final parsedId = int.tryParse(orderId.toString());
    if (parsedId != null) {
      try {
        final ownerToken = await getMerchantOwnerToken();
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (ownerToken != null && ownerToken.isNotEmpty) 'Authorization': 'Bearer $ownerToken',
        };
        final res = await http.delete(
          Uri.parse('$baseUrl/orders/$parsedId'),
          headers: headers,
        ).timeout(const Duration(seconds: 8));

        final data = _safeJsonDecode(res.body);
        if (res.statusCode == 200 || res.statusCode == 204) {
          return {
            'success': true,
            'message': data is Map<String, dynamic> ? (data['message'] ?? 'Bill deleted successfully!') : 'Bill deleted successfully!',
          };
        }
      } catch (e) {
        debugPrint('deleteOrder remote error: $e');
      }
    }

    return {'success': true, 'message': 'Bill deleted successfully!'};
  }

  /// 6. GET /orders/stats (Daily Sales Summary / POS KPI)
  Future<Map<String, dynamic>> getOrderStats({String? date}) async {
    try {
      final ownerToken = await getMerchantOwnerToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (ownerToken != null && ownerToken.isNotEmpty) 'Authorization': 'Bearer $ownerToken',
      };
      final query = (date != null && date.isNotEmpty) ? '?date=$date' : '';
      final res = await http.get(
        Uri.parse('$baseUrl/orders/stats$query'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final stats = data['stats'] ?? data['data'] ?? data;
          return {
            'success': true,
            'total_revenue': double.tryParse((stats['total_revenue'] ?? stats['totalRevenue'] ?? stats['revenue'] ?? 0.0).toString()) ?? 0.0,
            'total_bills': int.tryParse((stats['total_bills'] ?? stats['total_orders'] ?? stats['totalOrders'] ?? 0).toString()) ?? 0,
            'avg_bill_value': double.tryParse((stats['avg_bill_value'] ?? stats['avgOrderValue'] ?? 0.0).toString()) ?? 0.0,
            'paid_bills': int.tryParse((stats['paid_bills'] ?? stats['paidOrders'] ?? 0).toString()) ?? 0,
            'cancelled_bills': int.tryParse((stats['cancelled_bills'] ?? stats['cancelledOrders'] ?? 0).toString()) ?? 0,
            'raw': stats,
          };
        }
      }
      return {'success': false, 'message': 'Stats unavailable (HTTP ${res.statusCode})'};
    } catch (e) {
      debugPrint('getOrderStats error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// 6. GET /orders/{userId}/search (Customer / Bill Search)
  Future<List<dynamic>> searchOrders({
    required dynamic userId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final headers = await _headers();
      final encodedQuery = Uri.encodeComponent(query.trim());
      final res = await http.get(
        Uri.parse('$baseUrl/orders/$userId/search?query=$encodedQuery&q=$encodedQuery'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final list = data['orders'] ?? data['data'] ?? data['results'] ?? [];
          if (list is List) return list;
        }
      }
    } catch (e) {
      debugPrint('searchOrders error: $e');
    }
    return [];
  }

  /// 7. GET /orders/{userId}/track/{orderNumber} (Track by Bill Number)
  Future<Map<String, dynamic>?> trackOrderByNumber({
    required dynamic userId,
    required String orderNumber,
  }) async {
    if (orderNumber.trim().isEmpty) return null;

    try {
      final headers = await _headers();
      final cleanNum = Uri.encodeComponent(orderNumber.trim());
      final res = await http.get(
        Uri.parse('$baseUrl/orders/$userId/track/$cleanNum'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return data['order'] ?? data['data'] ?? data;
        }
      }
    } catch (e) {
      debugPrint('trackOrderByNumber error: $e');
    }
    return null;
  }

  // --- Categories APIs ---

  // --- Categories APIs ---

  /// GET /categories
  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null && _categoriesCacheTime != null) {
      if (DateTime.now().difference(_categoriesCacheTime!).inSeconds < 60) {
        return _cachedCategories!;
      }
    }
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/categories'),
        headers: await _headers(),
      ).timeout(const Duration(milliseconds: 6000));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic>? result;
        if (data is List) result = data;
        else if (data is Map && data['data'] is List) result = data['data'];
        else if (data is Map && data['categories'] is List) result = data['categories'];
        if (result != null) {
          _cachedCategories = result;
          _categoriesCacheTime = DateTime.now();
          return result;
        }
      }
    } catch (e) {
      debugPrint('getCategories error: $e');
    }
    return _cachedCategories ?? [];
  }

  /// GET /categories/{id}
  Future<Map<String, dynamic>> getCategoryById(int id) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('getCategoryById error: $e');
    }
    return {};
  }

  /// POST /categories
  Future<bool> createCategory(Map<String, dynamic> data) async {
    invalidateCatalogCache();
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/categories'),
        headers: await _headers(),
        body: jsonEncode({
          'name': data['name'],
          'slug': data['slug'],
          'image': data['image'],
          'description': data['description'],
          'status': data['status'] ?? 'active',
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
    } catch (e) {
      debugPrint('createCategory error (queueing offline): $e');
      try {
        await OfflineSyncService().queueCategoryAction(action: 'create', data: data);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// PUT /categories/{id}
  Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    invalidateCatalogCache();
    try {
      final res = await _client.put(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _headers(),
        body: jsonEncode({
          'name': data['name'],
          'slug': data['slug'],
          'image': data['image'],
          'description': data['description'],
          'status': data['status'] ?? 'active',
        }),
      );
      if (res.statusCode == 200) return true;
    } catch (e) {
      debugPrint('updateCategory error (queueing offline): $e');
      try {
        await OfflineSyncService().queueCategoryAction(action: 'update', data: data, id: id);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// DELETE /categories/{id}
  Future<bool> deleteCategory(int id) async {
    invalidateCatalogCache();
    try {
      final res = await _client.delete(
        Uri.parse('$baseUrl/categories/$id'),
        headers: await _headers(),
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;
    } catch (e) {
      debugPrint('deleteCategory error (queueing offline): $e');
      try {
        await OfflineSyncService().queueCategoryAction(action: 'delete', data: {}, id: id);
        return true;
      } catch (_) {}
    }
    return false;
  }

  // --- SubCategories APIs ---

  /// GET /subcategories (Optional: categoryId)
  Future<List<dynamic>> getSubcategories({int? categoryId, bool forceRefresh = false}) async {
    if (!forceRefresh && categoryId != null && _cachedSubcategoriesByCat.containsKey(categoryId)) {
      final cacheTime = _subcatCacheTimes[categoryId];
      if (cacheTime != null && DateTime.now().difference(cacheTime).inSeconds < 60) {
        return _cachedSubcategoriesByCat[categoryId]!;
      }
    }
    try {
      String endpoint = '$baseUrl/subcategories';
      if (categoryId != null) endpoint += '?categoryId=$categoryId';
      final res = await _client.get(Uri.parse(endpoint), headers: await _headers()).timeout(const Duration(milliseconds: 5000));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic>? result;
        if (data is List) result = data;
        else if (data is Map && data['data'] is List) result = data['data'];
        else if (data is Map && data['subcategories'] is List) result = data['subcategories'];
        if (result != null) {
          if (categoryId != null) {
            _cachedSubcategoriesByCat[categoryId] = result;
            _subcatCacheTimes[categoryId] = DateTime.now();
          }
          return result;
        }
      }
    } catch (e) {
      debugPrint('getSubcategories error: $e');
    }
    if (categoryId != null && _cachedSubcategoriesByCat.containsKey(categoryId)) {
      return _cachedSubcategoriesByCat[categoryId]!;
    }
    return [];
  }

  /// GET /subcategories/{id}
  Future<Map<String, dynamic>> getSubcategoryById(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/subcategories/$id'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('getSubcategoryById error: $e');
    }
    return {};
  }

  /// POST /subcategories
  Future<Map<String, dynamic>> createSubcategory(Map<String, dynamic> data) async {
    final catId = int.tryParse(data['category_id']?.toString() ?? data['categoryId']?.toString() ?? '') ?? 0;
    final Map<String, dynamic> bodyMap = {
      'category_id': catId,
      'name': (data['name'] ?? '').toString().trim(),
      'slug': (data['slug'] != null && data['slug'].toString().trim().isNotEmpty)
          ? data['slug'].toString().trim()
          : (data['name'] ?? '').toString().trim().toLowerCase().replaceAll(' ', '-'),
      'description': (data['description'] != null && data['description'].toString().trim().isNotEmpty)
          ? data['description'].toString().trim()
          : (data['name'] ?? '').toString().trim(),
      'status': data['status'] == 'inactive' ? 'inactive' : 'active',
    };

    if (data['image'] != null && data['image'].toString().trim().isNotEmpty) {
      bodyMap['image'] = data['image'].toString().trim();
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/subcategories'),
        headers: await _headers(),
        body: jsonEncode(bodyMap),
      );
      debugPrint('[API] createSubcategory response: status=${res.statusCode}, body=${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'statusCode': res.statusCode};
      }

      String errorMsg = 'HTTP ${res.statusCode}';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['message'] != null) {
          errorMsg = decoded['message'].toString();
        }
      } catch (_) {}

      return {'success': false, 'statusCode': res.statusCode, 'message': errorMsg};
    } catch (e) {
      debugPrint('[API] createSubcategory error (queueing offline): $e');
      try {
        await OfflineSyncService().queueSubcategoryAction(action: 'create', data: bodyMap);
        return {'success': true, 'message': 'Queued offline', 'isOffline': true};
      } catch (_) {}
      return {'success': false, 'message': e.toString()};
    }
  }

  /// PUT /subcategories/{id}
  Future<Map<String, dynamic>> updateSubcategory(int id, Map<String, dynamic> data) async {
    final catId = int.tryParse(data['category_id']?.toString() ?? data['categoryId']?.toString() ?? '') ?? 0;
    final Map<String, dynamic> bodyMap = {
      'category_id': catId,
      'name': (data['name'] ?? '').toString().trim(),
      'slug': (data['slug'] != null && data['slug'].toString().trim().isNotEmpty)
          ? data['slug'].toString().trim()
          : (data['name'] ?? '').toString().trim().toLowerCase().replaceAll(' ', '-'),
      'description': (data['description'] != null && data['description'].toString().trim().isNotEmpty)
          ? data['description'].toString().trim()
          : (data['name'] ?? '').toString().trim(),
      'status': data['status'] == 'inactive' ? 'inactive' : 'active',
    };

    if (data['image'] != null && data['image'].toString().trim().isNotEmpty) {
      bodyMap['image'] = data['image'].toString().trim();
    }

    // If ID is a local timestamp ID (e.g. > 1,000,000,000), it has not been created on server yet -> create it!
    if (id > 1000000000) {
      debugPrint('[API] Subcategory ID $id is a local ID. Calling createSubcategory instead...');
      return await createSubcategory(data);
    }

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/subcategories/$id'),
        headers: await _headers(),
        body: jsonEncode(bodyMap),
      );
      debugPrint('[API] updateSubcategory response: status=${res.statusCode}, body=${res.body}');

      if (res.statusCode == 200 || res.statusCode == 204) {
        return {'success': true, 'statusCode': res.statusCode};
      }

      // If server returns 404 (does not exist on DB), fallback to create it on DB
      if (res.statusCode == 404) {
        debugPrint('[API] Subcategory ID $id returned 404. Creating it in database now...');
        return await createSubcategory(data);
      }

      String errorMsg = 'HTTP ${res.statusCode}';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['message'] != null) {
          errorMsg = decoded['message'].toString();
        }
      } catch (_) {}

      return {'success': false, 'statusCode': res.statusCode, 'message': errorMsg};
    } catch (e) {
      debugPrint('[API] updateSubcategory error (queueing offline): $e');
      try {
        await OfflineSyncService().queueSubcategoryAction(action: 'update', data: bodyMap, id: id);
        return {'success': true, 'message': 'Queued offline', 'isOffline': true};
      } catch (_) {}
      return {'success': false, 'message': e.toString()};
    }
  }

  /// DELETE /subcategories/{id}
  Future<bool> deleteSubcategory(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/subcategories/$id'),
        headers: await _headers(),
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;
    } catch (e) {
      debugPrint('[API] deleteSubcategory error (queueing offline): $e');
      try {
        await OfflineSyncService().queueSubcategoryAction(action: 'delete', data: {}, id: id);
        return true;
      } catch (_) {}
    }
    return false;
  }

  // --- Products APIs ---

  /// GET /products (Query params: categoryId, subCategoryId)
  Future<List<dynamic>> getProducts({int? categoryId, int? subCategoryId, bool forceRefresh = false}) async {
    final bool isAll = categoryId == null && subCategoryId == null;
    if (!forceRefresh && isAll && _cachedProducts != null && _productsCacheTime != null) {
      if (DateTime.now().difference(_productsCacheTime!).inSeconds < 60) {
        return _cachedProducts!;
      }
    }
    try {
      String endpoint = '$baseUrl/products';
      List<String> params = [];
      if (categoryId != null) params.add('categoryId=$categoryId');
      if (subCategoryId != null) params.add('subCategoryId=$subCategoryId');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final res = await _client.get(Uri.parse(endpoint), headers: await _headers()).timeout(const Duration(seconds: 10));
      debugPrint('[API] getProducts response: status=${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic>? result;
        if (data is List) result = data;
        else if (data is Map && data['data'] is List) result = data['data'];
        else if (data is Map && data['products'] is List) result = data['products'];
        if (result != null) {
          if (isAll) {
            _cachedProducts = result;
            _productsCacheTime = DateTime.now();
          }
          return result;
        }
      }
    } catch (e) {
      debugPrint('[API] getProducts error: $e');
    }
    if (isAll && _cachedProducts != null) return _cachedProducts!;
    return [];
  }

  /// GET /products/{id}
  Future<Map<String, dynamic>> getProductById(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/products/$id'), headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('getProductById error: $e');
    }
    return {};
  }

  /// POST /products
  Future<bool> createProduct(Map<String, dynamic> data) async {
    invalidateCatalogCache();
    final payload = {
      'category_id': data['category_id'],
      'subcategory_id': data['subcategory_id'],
      'name': data['name'],
      'sku': data['sku'],
      'price': (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse(data['price'].toString()) ?? 0.0,
      'discount_price': data['discount_price'] != null ? ((data['discount_price'] is num) ? (data['discount_price'] as num).toDouble() : double.tryParse(data['discount_price'].toString())) : null,
      'stock': data['stock'] is int ? data['stock'] : (int.tryParse(data['stock']?.toString() ?? '') ?? 0),
      'status': data['status'] ?? 'active',
      'featured': data['featured'] ?? false,
      'short_description': data['short_description'] ?? '',
      'full_description': data['full_description'] ?? '',
      'main_image': data['main_image'] ?? '',
      'images': data['images'] ?? [],
      'tags': data['tags'] ?? [],
      'variations': data['variations'] ?? [],
    };

    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/products'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
    } catch (e) {
      debugPrint('createProduct error (queueing offline): $e');
      try {
        await OfflineSyncService().queueProductAction(action: 'create', data: payload);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// PUT /products/{id}
  Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    invalidateCatalogCache();
    final payload = {
      'category_id': data['category_id'],
      'subcategory_id': data['subcategory_id'],
      'name': data['name'],
      'sku': data['sku'],
      'price': (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse(data['price'].toString()) ?? 0.0,
      'discount_price': data['discount_price'] != null ? ((data['discount_price'] is num) ? (data['discount_price'] as num).toDouble() : double.tryParse(data['discount_price'].toString())) : null,
      'stock': data['stock'] is int ? data['stock'] : (int.tryParse(data['stock']?.toString() ?? '') ?? 0),
      'status': data['status'] ?? 'active',
      'featured': data['featured'] ?? false,
      'short_description': data['short_description'] ?? '',
      'full_description': data['full_description'] ?? '',
      'main_image': data['main_image'] ?? '',
      'images': data['images'] ?? [],
      'tags': data['tags'] ?? [],
      'variations': data['variations'] ?? [],
    };

    try {
      final res = await _client.put(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) return true;
    } catch (e) {
      debugPrint('updateProduct error (queueing offline): $e');
      try {
        await OfflineSyncService().queueProductAction(action: 'update', data: payload, id: id);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// DELETE /products/{id}
  Future<bool> deleteProduct(int id) async {
    invalidateCatalogCache();
    try {
      final res = await _client.delete(
        Uri.parse('$baseUrl/products/$id'),
        headers: await _headers(),
      );
      if (res.statusCode == 200 || res.statusCode == 204) return true;
    } catch (e) {
      debugPrint('deleteProduct error (queueing offline): $e');
      try {
        await OfflineSyncService().queueProductAction(action: 'delete', data: {}, id: id);
        return true;
      } catch (_) {}
    }
    return false;
  }

  // --- Upload APIs ---

  /// POST /upload/image (Upload single image file)
  Future<Map<String, dynamic>> uploadImage(List<int> bytes, String filename) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('$baseUrl/upload/image');
      final request = http.MultipartRequest('POST', uri);

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      );
      request.files.add(multipartFile);

      final streamedRes = await request.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          String? rawUrl = data['url'] ?? data['filename'] ?? data['file'] ?? (data['data'] is Map ? data['data']['url'] : null);
          if (rawUrl != null && rawUrl.isNotEmpty) {
            final fullUrl = rawUrl.startsWith('/') ? '$baseUrl$rawUrl' : rawUrl;
            return {
              'success': true,
              'url': fullUrl,
              'filename': data['filename'] ?? filename,
              'raw': data,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error uploading image to API: $e');
    }

    return {
      'success': false,
      'message': 'Failed to upload image to server.',
    };
  }

  /// POST /upload/images (Upload multiple image files)
  Future<List<String>> uploadImages(List<({List<int> bytes, String filename})> files) async {
    if (files.isEmpty) return [];

    try {
      final token = await getToken();
      final uri = Uri.parse('$baseUrl/upload/images');
      final request = http.MultipartRequest('POST', uri);

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      for (final item in files) {
        request.files.add(
          http.MultipartFile.fromBytes('images', item.bytes, filename: item.filename),
        );
      }

      final streamedRes = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map<String, dynamic>) {
          list = data['filenames'] ?? data['urls'] ?? data['images'] ?? [];
        }
        final urls = list.map((e) {
          final str = e.toString();
          return str.startsWith('/') ? '$baseUrl$str' : str;
        }).toList();

        if (urls.isNotEmpty) return urls;
      }
    } catch (e) {
      debugPrint('Error uploading multiple images to API: $e');
    }

    return [];
  }
}

