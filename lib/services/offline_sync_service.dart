import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  static const String _keyPendingOrders = 'offline_pending_orders';
  static const String _keyPendingCategories = 'offline_pending_categories';
  static const String _keyPendingProducts = 'offline_pending_products';

  /// Start background periodic auto-sync engine (runs every 15s)
  void startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await syncAllPending();
    });
    // Trigger initial check
    syncAllPending();
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  // ==========================================
  // --- 1. ORDERS OFFLINE QUEUE ---
  // ==========================================

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    try {
      final str = await _storage.read(key: _keyPendingOrders);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> queueOrder(Map<String, dynamic> orderPayload) async {
    try {
      final list = await getPendingOrders();
      final item = {
        'queue_id': 'ORDER-Q-${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
        'payload': orderPayload,
      };
      list.add(item);
      await _storage.write(key: _keyPendingOrders, value: jsonEncode(list));
      debugPrint('[OfflineSync] Queued new offline order. Total pending orders: ${list.length}');
    } catch (e) {
      debugPrint('[OfflineSync] Error queueing order: $e');
    }
  }

  // ==========================================
  // --- 2. CATEGORIES OFFLINE QUEUE ---
  // ==========================================

  Future<List<Map<String, dynamic>>> getPendingCategories() async {
    try {
      final str = await _storage.read(key: _keyPendingCategories);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> queueCategoryAction({
    required String action, // 'create', 'update', 'delete'
    required Map<String, dynamic> data,
    int? id,
  }) async {
    try {
      final list = await getPendingCategories();
      list.add({
        'queue_id': 'CAT-Q-${DateTime.now().millisecondsSinceEpoch}',
        'action': action,
        'id': id,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _storage.write(key: _keyPendingCategories, value: jsonEncode(list));
      debugPrint('[OfflineSync] Queued category $action. Total pending: ${list.length}');
    } catch (e) {
      debugPrint('[OfflineSync] Error queueing category action: $e');
    }
  }

  // ==========================================
  // --- 3. PRODUCTS OFFLINE QUEUE ---
  // ==========================================

  Future<List<Map<String, dynamic>>> getPendingProducts() async {
    try {
      final str = await _storage.read(key: _keyPendingProducts);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> queueProductAction({
    required String action, // 'create', 'update', 'delete'
    required Map<String, dynamic> data,
    int? id,
  }) async {
    try {
      final list = await getPendingProducts();
      list.add({
        'queue_id': 'PROD-Q-${DateTime.now().millisecondsSinceEpoch}',
        'action': action,
        'id': id,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _storage.write(key: _keyPendingProducts, value: jsonEncode(list));
      debugPrint('[OfflineSync] Queued product $action. Total pending: ${list.length}');
    } catch (e) {
      debugPrint('[OfflineSync] Error queueing product action: $e');
    }
  }

  // ==========================================
  // --- 4. TOTAL PENDING ITEMS COUNT ---
  // ==========================================

  Future<int> getTotalPendingCount() async {
    final orders = await getPendingOrders();
    final cats = await getPendingCategories();
    final prods = await getPendingProducts();
    final staff = (await _apiService.getLocalStaffMembers())
        .where((s) => s['is_synced'] != true)
        .length;
    return orders.length + cats.length + prods.length + staff;
  }

  // ==========================================
  // --- 5. MASTER AUTO-SYNC ENGINE ---
  // ==========================================

  Future<Map<String, dynamic>> syncAllPending() async {
    if (_isSyncing) {
      return {'success': false, 'message': 'Sync already in progress'};
    }

    _isSyncing = true;
    int syncedOrders = 0;
    int syncedCategories = 0;
    int syncedProducts = 0;

    try {
      // 1. Verify Internet / Server connectivity
      final health = await _apiService.checkServerHealth();
      final isOnline = health['isOnline'] == true;
      if (!isOnline) {
        _isSyncing = false;
        return {'success': false, 'message': 'Server is currently offline.'};
      }

      final token = await _apiService.getToken();
      if (token == null || token.isEmpty) {
        _isSyncing = false;
        return {'success': false, 'message': 'No user logged in to sync.'};
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final baseUrl = ApiConfig.baseUrl;

      // 2. Sync Staff Members
      try {
        await _apiService.getStaffMembers(); // triggers staff auto-sync
      } catch (_) {}

      // 3. Sync Categories Queue
      final pendingCats = await getPendingCategories();
      final remainingCats = <Map<String, dynamic>>[];
      for (final item in pendingCats) {
        try {
          final action = item['action']?.toString();
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final id = item['id'];

          http.Response? res;
          if (action == 'create') {
            res = await http.post(
              Uri.parse('$baseUrl/categories'),
              headers: headers,
              body: jsonEncode({
                'name': data['name'],
                'slug': data['slug'],
                'image': data['image'],
                'description': data['description'],
                'status': data['status'] ?? 'active',
              }),
            ).timeout(const Duration(seconds: 5));
          } else if (action == 'update' && id != null) {
            res = await http.put(
              Uri.parse('$baseUrl/categories/$id'),
              headers: headers,
              body: jsonEncode({
                'name': data['name'],
                'slug': data['slug'],
                'image': data['image'],
                'description': data['description'],
                'status': data['status'] ?? 'active',
              }),
            ).timeout(const Duration(seconds: 5));
          } else if (action == 'delete' && id != null) {
            res = await http.delete(
              Uri.parse('$baseUrl/categories/$id'),
              headers: headers,
            ).timeout(const Duration(seconds: 5));
          }

          if (res != null && (res.statusCode == 200 || res.statusCode == 201)) {
            syncedCategories++;
          } else {
            remainingCats.add(item);
          }
        } catch (_) {
          remainingCats.add(item);
        }
      }
      await _storage.write(key: _keyPendingCategories, value: jsonEncode(remainingCats));

      // 4. Sync Products Queue
      final pendingProds = await getPendingProducts();
      final remainingProds = <Map<String, dynamic>>[];
      for (final item in pendingProds) {
        try {
          final action = item['action']?.toString();
          final data = item['data'] as Map<String, dynamic>? ?? {};
          final id = item['id'];

          http.Response? res;
          if (action == 'create') {
            res = await http.post(
              Uri.parse('$baseUrl/products'),
              headers: headers,
              body: jsonEncode(data),
            ).timeout(const Duration(seconds: 6));
          } else if (action == 'update' && id != null) {
            res = await http.put(
              Uri.parse('$baseUrl/products/$id'),
              headers: headers,
              body: jsonEncode(data),
            ).timeout(const Duration(seconds: 6));
          } else if (action == 'delete' && id != null) {
            res = await http.delete(
              Uri.parse('$baseUrl/products/$id'),
              headers: headers,
            ).timeout(const Duration(seconds: 5));
          }

          if (res != null && (res.statusCode == 200 || res.statusCode == 201)) {
            syncedProducts++;
          } else {
            remainingProds.add(item);
          }
        } catch (_) {
          remainingProds.add(item);
        }
      }
      await _storage.write(key: _keyPendingProducts, value: jsonEncode(remainingProds));

      // 5. Sync Orders Queue
      final pendingOrders = await getPendingOrders();
      final remainingOrders = <Map<String, dynamic>>[];
      for (final item in pendingOrders) {
        try {
          final payload = item['payload'] as Map<String, dynamic>? ?? {};
          final res = await http.post(
            Uri.parse('$baseUrl/orders'),
            headers: headers,
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200 || res.statusCode == 201) {
            syncedOrders++;
            debugPrint('[OfflineSync] Successfully synced order ${item['queue_id']} to backend database!');
          } else {
            remainingOrders.add(item);
          }
        } catch (_) {
          remainingOrders.add(item);
        }
      }
      await _storage.write(key: _keyPendingOrders, value: jsonEncode(remainingOrders));

      debugPrint('[OfflineSync] Batch sync completed. Synced: $syncedOrders orders, $syncedProducts products, $syncedCategories categories.');

      return {
        'success': true,
        'syncedOrders': syncedOrders,
        'syncedCategories': syncedCategories,
        'syncedProducts': syncedProducts,
        'remainingOrders': remainingOrders.length,
      };
    } catch (e) {
      debugPrint('[OfflineSync] syncAllPending error: $e');
      return {'success': false, 'message': 'Sync error: $e'};
    } finally {
      _isSyncing = false;
    }
  }
}
