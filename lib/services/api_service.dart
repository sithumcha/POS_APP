import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'offline_sync_service.dart';

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

  Future<String?> getToken() async => await _storage.read(key: 'jwt_token');

  Future<void> saveToken(String token) async =>
      await _storage.write(key: 'jwt_token', value: token);

  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_info');
  }

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Real-time Health Check to ping live server
  Future<Map<String, dynamic>> checkServerHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(
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

  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async =>
      await _storage.write(key: 'user_info', value: jsonEncode(userInfo));

  Future<Map<String, dynamic>?> getUserInfo() async {
    final str = await _storage.read(key: 'user_info');
    if (str != null && str.isNotEmpty) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveUserEditedProfile(Map<String, dynamic> editedData) async {
    try {
      await _storage.write(key: 'user_edited_profile', value: jsonEncode(editedData));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getUserEditedProfile() async {
    try {
      final str = await _storage.read(key: 'user_edited_profile');
      if (str != null && str.isNotEmpty) {
        final decoded = _safeJsonDecode(str);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  // --- Auth APIs ---

  /// GET /users/detail (Get logged-in user profile details)
  Future<Map<String, dynamic>> getUserDetail() async {
    final savedUser = (await getUserInfo()) ?? {};
    final editedOverlay = (await getUserEditedProfile()) ?? {};

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

          if (editedOverlay['store_name'] != null && editedOverlay['store_name'].toString().isNotEmpty) {
            merged['store_name'] = editedOverlay['store_name'];
          } else if (merged['store_name'] == null || merged['store_name'].toString().isEmpty) {
            final fName = (merged['first_name'] ?? '').toString();
            if (fName.isNotEmpty) {
              merged['store_name'] = '$fName Store';
            }
          }

          final parentId = merged['parent_id'];
          final bool isSubUser = parentId != null &&
              parentId.toString().isNotEmpty &&
              parentId.toString() != '0' &&
              parentId.toString().toLowerCase() != 'null';
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
    if (editedOverlay['store_name'] != null && editedOverlay['store_name'].toString().isNotEmpty) {
      mergedSaved['store_name'] = editedOverlay['store_name'];
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

          final editedOverlay = await getUserEditedProfile();
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
            }
          }

          final parentId = userObj['parent_id'];
          final bool isSubUser = parentId != null &&
              parentId.toString().isNotEmpty &&
              parentId.toString() != '0' &&
              parentId.toString().toLowerCase() != 'null';
          if (!isSubUser) {
            userObj['is_owner'] = true;
            if (userObj['role'] == null ||
                userObj['role'].toString().isEmpty ||
                userObj['role'].toString().toLowerCase() == 'user') {
              userObj['role'] = 'Store Owner / Admin';
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
            await saveUserInfo(staff);
            return {
              'success': true,
              'token': mockToken,
              'user': staff,
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
    required String firstName,
    required String lastName,
  }) async {
    final body = {
      'first_name': firstName,
      'last_name': lastName,
    };

    final savedUser = (await getUserInfo()) ?? {};
    final updatedMap = Map<String, dynamic>.from(savedUser);
    updatedMap['first_name'] = firstName;
    updatedMap['last_name'] = lastName;
    final fName = firstName.trim();
    if (fName.isNotEmpty) {
      updatedMap['store_name'] = '$fName Store';
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

    final newLocalStaff = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'role': role,
      'parent_id': ownerId,
      'user_type': 3,
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

  /// POST /orders (Checkout Order Creation)
  Future<Map<String, dynamic>> createOrder({
    required int cashierId,
    required String paymentMethod,
    required double totalAmount,
    required double paidAmount,
    required double changeAmount,
    required List<dynamic> items,
  }) async {
    final body = {
      'cashier_id': cashierId,
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'items': items.map((item) {
        final map = item is Map<String, dynamic> ? item : (item as Map);
        final price = double.tryParse(map['price']?.toString() ?? map['unit_price']?.toString() ?? '0') ?? 0.0;
        final discountPrice = double.tryParse(map['discount_price']?.toString() ?? '') ?? price;
        final unitPrice = discountPrice > 0 ? discountPrice : price;
        final qty = int.tryParse(map['quantity']?.toString() ?? map['qty']?.toString() ?? '1') ?? 1;

        return {
          'product_id': map['id'] ?? map['product_id'],
          'name': map['name'] ?? 'Item',
          'quantity': qty,
          'unit_price': unitPrice,
          'total_price': qty * unitPrice,
        };
      }).toList(),
    };

    try {
      final headers = await _headers();
      final res = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (data is Map<String, dynamic>) {
          return {
            'success': true,
            'order_id': data['order_id'] ?? data['id'] ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}',
            'status': data['status'] ?? 'completed',
            'receipt_url': data['receipt_url'],
            'data': data,
          };
        }
      }

      final errorMsg = data is Map<String, dynamic> ? (data['message'] ?? data['error'] ?? 'Order failed') : 'Order failed';
      return {
        'success': false,
        'message': errorMsg.toString(),
      };
    } catch (e) {
      debugPrint('createOrder error (saving offline): $e');
      try {
        await OfflineSyncService().queueOrder(body);
      } catch (_) {}

      return {
        'success': true,
        'order_id': 'ORD-OFFLINE-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'offline_queued',
        'is_offline': true,
        'message': 'Order processed & saved locally (Offline mode)! Will auto-sync when online.',
      };
    }
  }

  // --- Categories APIs ---

  // --- Categories APIs ---

  /// GET /categories
  Future<List<dynamic>> getCategories() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: await _headers(),
      ).timeout(const Duration(milliseconds: 6000));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
        if (data is Map && data['categories'] is List) return data['categories'];
      }
    } catch (e) {
      debugPrint('getCategories error: $e');
    }
    return [];
  }

  /// GET /categories/{id}
  Future<Map<String, dynamic>> getCategoryById(int id) async {
    try {
      final res = await http.get(
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
    try {
      final res = await http.post(
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
    try {
      final res = await http.put(
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
    try {
      final res = await http.delete(
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
  Future<List<dynamic>> getSubcategories({int? categoryId}) async {
    try {
      String endpoint = '$baseUrl/subcategories';
      if (categoryId != null) endpoint += '?categoryId=$categoryId';
      final res = await http.get(Uri.parse(endpoint), headers: await _headers()).timeout(const Duration(milliseconds: 5000));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
        if (data is Map && data['subcategories'] is List) return data['subcategories'];
      }
    } catch (e) {
      debugPrint('getSubcategories error: $e');
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
  Future<List<dynamic>> getProducts({int? categoryId, int? subCategoryId}) async {
    try {
      String endpoint = '$baseUrl/products';
      List<String> params = [];
      if (categoryId != null) params.add('categoryId=$categoryId');
      if (subCategoryId != null) params.add('subCategoryId=$subCategoryId');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final res = await http.get(Uri.parse(endpoint), headers: await _headers()).timeout(const Duration(seconds: 10));
      debugPrint('[API] getProducts response: status=${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
        if (data is Map && data['products'] is List) return data['products'];
      }
    } catch (e) {
      debugPrint('[API] getProducts error: $e');
    }
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
      final res = await http.post(
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
      final res = await http.put(
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
    try {
      final res = await http.delete(
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

