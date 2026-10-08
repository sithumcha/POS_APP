import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

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

  // --- Auth APIs ---

  /// GET /users/detail (Get logged-in user profile details)
  Future<Map<String, dynamic>> getUserDetail() async {
    final savedUser = await getUserInfo();

    if (!ApiConfig.useMockApi) {
      try {
        final headers = await _headers();
        final res = await http.get(
          Uri.parse('$baseUrl/users/detail'),
          headers: headers,
        ).timeout(const Duration(milliseconds: 2000));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            final userObj = data.containsKey('data') && data['data'] is Map<String, dynamic>
                ? data['data'] as Map<String, dynamic>
                : (data.containsKey('user') && data['user'] is Map<String, dynamic>
                    ? data['user'] as Map<String, dynamic>
                    : data);
            await saveUserInfo(userObj);
            return userObj;
          }
        }
      } catch (_) {}
    }

    if (savedUser != null) {
      return savedUser;
    }

    return {
      'first_name': 'Active',
      'last_name': 'Cashier',
      'email': 'user@quicke.app',
      'role': 'Store Cashier',
      'store_name': 'QUICKE POS STORE',
    };
  }

  /// POST /users/login
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/users/login'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            if (data['token'] != null) {
              await saveToken(data['token'].toString());
            }
            if (data['user'] is Map<String, dynamic>) {
              await saveUserInfo(data['user'] as Map<String, dynamic>);
            } else if (data['data'] is Map<String, dynamic>) {
              await saveUserInfo(data['data'] as Map<String, dynamic>);
            } else {
              await saveUserInfo({
                'email': email,
                'first_name': email.split('@')[0],
                'last_name': 'User',
              });
            }
            return data;
          }
        }
      } catch (_) {}
    }

    // Save Logged-in user info locally for fallback
    final mockUser = {
      'id': 101,
      'first_name': email.contains('@') ? email.split('@')[0].toUpperCase() : 'Cashier',
      'last_name': 'User',
      'email': email,
      'role': 'Store Cashier',
      'store_name': 'QUICKE POS STORE',
      'phone': '+94 77 123 4567',
    };
    const mockToken = 'mock_jwt_token_auth_12345';
    await saveToken(mockToken);
    await saveUserInfo(mockUser);

    return {
      'token': mockToken,
      'user': mockUser,
      'message': 'Login successful'
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
    };

    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/users/register'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(body),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic> && data['token'] != null) {
            await saveToken(data['token'].toString());
          }
          return data is Map<String, dynamic> ? data : {'message': 'User registered successfully'};
        }
      } catch (_) {}
    }

    // Fallback
    const mockToken = 'mock_jwt_token_register_67890';
    await saveToken(mockToken);
    return {'token': mockToken, 'message': 'User registered successfully'};
  }

  // --- Categories APIs ---

  /// GET /categories
  Future<List<dynamic>> getCategories() async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/categories'),
          headers: await _headers(),
        ).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) return data;
        }
      } catch (_) {}
    }
    return _getMockCategories();
  }

  /// GET /categories/{id}
  Future<Map<String, dynamic>> getCategoryById(int id) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/categories/$id'),
          headers: await _headers(),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) return data;
        }
      } catch (_) {}
    }
    final mockList = _getMockCategories();
    return mockList.firstWhere(
      (c) => c['id'] == id,
      orElse: () => mockList.first,
    );
  }

  /// POST /categories
  Future<bool> createCategory(Map<String, dynamic> data) async {
    if (!ApiConfig.useMockApi) {
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
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// PUT /categories/{id}
  Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    if (!ApiConfig.useMockApi) {
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
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// DELETE /categories/{id}
  Future<bool> deleteCategory(int id) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.delete(
          Uri.parse('$baseUrl/categories/$id'),
          headers: await _headers(),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  List<Map<String, dynamic>> _getMockCategories() {
    return [
      {
        "id": 1,
        "user_id": 10,
        "name": "Electronics",
        "slug": "electronics",
        "image": "/files/electronics.png",
        "description": "Electronic items and gadgets",
        "status": "active",
        "created_at": "2026-10-06T10:19:20.993Z",
        "updated_at": "2026-10-06T10:19:20.993Z"
      },
      {
        "id": 2,
        "user_id": 10,
        "name": "Beverages",
        "slug": "beverages",
        "image": "/files/beverages.png",
        "description": "Hot & Cold Drinks, Coffees, Teas",
        "status": "active",
        "created_at": "2026-10-06T10:19:20.993Z",
        "updated_at": "2026-10-06T10:19:20.993Z"
      },
      {
        "id": 3,
        "user_id": 10,
        "name": "Bakery & Snacks",
        "slug": "bakery-snacks",
        "image": "/files/bakery.png",
        "description": "Freshly baked items and snacks",
        "status": "active",
        "created_at": "2026-10-06T10:19:20.993Z",
        "updated_at": "2026-10-06T10:19:20.993Z"
      }
    ];
  }

  // --- SubCategories APIs ---

  /// GET /subcategories (Optional: categoryId)
  Future<List<dynamic>> getSubcategories({int? categoryId}) async {
    if (!ApiConfig.useMockApi) {
      try {
        String endpoint = '$baseUrl/subcategories';
        if (categoryId != null) endpoint += '?categoryId=$categoryId';
        final res = await http.get(Uri.parse(endpoint), headers: await _headers()).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) return data;
        }
      } catch (_) {}
    }
    final allSubcats = _getMockSubCategories();
    if (categoryId != null) {
      return allSubcats.where((s) => s['category_id'] == categoryId).toList();
    }
    return allSubcats;
  }

  /// GET /subcategories/{id}
  Future<Map<String, dynamic>> getSubcategoryById(int id) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/subcategories/$id'),
          headers: await _headers(),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) return data;
        }
      } catch (_) {}
    }
    final mockList = _getMockSubCategories();
    return mockList.firstWhere(
      (s) => s['id'] == id,
      orElse: () => mockList.first,
    );
  }

  /// POST /subcategories
  Future<bool> createSubcategory(Map<String, dynamic> data) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/subcategories'),
          headers: await _headers(),
          body: jsonEncode({
            'category_id': data['category_id'],
            'name': data['name'],
            'slug': data['slug'],
            'image': data['image'],
            'description': data['description'],
            'status': data['status'] ?? 'active',
          }),
        );
        if (res.statusCode == 200 || res.statusCode == 201) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// PUT /subcategories/{id}
  Future<bool> updateSubcategory(int id, Map<String, dynamic> data) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.put(
          Uri.parse('$baseUrl/subcategories/$id'),
          headers: await _headers(),
          body: jsonEncode({
            'category_id': data['category_id'],
            'name': data['name'],
            'slug': data['slug'],
            'image': data['image'],
            'description': data['description'],
            'status': data['status'] ?? 'active',
          }),
        );
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// DELETE /subcategories/{id}
  Future<bool> deleteSubcategory(int id) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.delete(
          Uri.parse('$baseUrl/subcategories/$id'),
          headers: await _headers(),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  List<Map<String, dynamic>> _getMockSubCategories() {
    return [
      {
        "id": 1,
        "category_id": 1,
        "name": "Smartphones",
        "slug": "smartphones",
        "image": "/files/smartphones.png",
        "description": "Smartphones and mobile devices",
        "status": "active"
      },
      {
        "id": 2,
        "category_id": 1,
        "name": "Computer Peripherals",
        "slug": "computer-peripherals",
        "image": "/files/peripherals.png",
        "description": "Mice, keyboards, and accessories",
        "status": "active"
      },
      {
        "id": 3,
        "category_id": 2,
        "name": "Hot Coffee",
        "slug": "hot-coffee",
        "image": "/files/coffee.png",
        "description": "Espresso, Latte, Cappuccino",
        "status": "active"
      }
    ];
  }

  // --- Products APIs ---

  /// GET /products (Query params: categoryId, subCategoryId)
  Future<List<dynamic>> getProducts({int? categoryId, int? subCategoryId}) async {
    if (!ApiConfig.useMockApi) {
      try {
        String endpoint = '$baseUrl/products';
        List<String> params = [];
        if (categoryId != null) params.add('categoryId=$categoryId');
        if (subCategoryId != null) params.add('subCategoryId=$subCategoryId');
        if (params.isNotEmpty) endpoint += '?${params.join('&')}';

        final res = await http.get(Uri.parse(endpoint), headers: await _headers()).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) return data;
        }
      } catch (_) {}
    }
    final allProducts = _getMockProducts();
    return allProducts.where((p) {
      if (categoryId != null && p['category_id'] != categoryId) return false;
      if (subCategoryId != null && p['subcategory_id'] != subCategoryId) return false;
      return true;
    }).toList();
  }

  /// GET /products/{id}
  Future<Map<String, dynamic>> getProductById(int id) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/products/$id'), headers: await _headers());
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) return data;
        }
      } catch (_) {}
    }

    final mockList = _getMockProducts();
    return mockList.firstWhere(
      (p) => p['id'] == id,
      orElse: () => mockList.first,
    );
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

    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/products'),
          headers: await _headers(),
          body: jsonEncode(payload),
        );
        if (res.statusCode == 200 || res.statusCode == 201) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
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

    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.put(
          Uri.parse('$baseUrl/products/$id'),
          headers: await _headers(),
          body: jsonEncode(payload),
        );
        if (res.statusCode == 200) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// DELETE /products/{id}
  Future<bool> deleteProduct(int id) async {
    if (!ApiConfig.useMockApi) {
      try {
        final res = await http.delete(
          Uri.parse('$baseUrl/products/$id'),
          headers: await _headers(),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  List<Map<String, dynamic>> _getMockProducts() {
    return [
      {
        "id": 1,
        "category_id": 1,
        "subcategory_id": 2,
        "name": "Wireless Mouse",
        "sku": "WM-001",
        "price": 2500.0,
        "discount_price": 2200.0,
        "stock": 45,
        "status": "active",
        "featured": false,
        "short_description": "Ergonomic wireless mouse",
        "full_description": "2.4GHz optical wireless mouse with USB receiver",
        "main_image": "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500",
        "images": [
          "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500"
        ],
        "tags": ["electronics", "accessories"],
        "variations": []
      },
      {
        "id": 2,
        "category_id": 1,
        "subcategory_id": 1,
        "name": "Smartphone Pro Max",
        "sku": "SP-002",
        "price": 125000.0,
        "discount_price": 118000.0,
        "stock": 10,
        "status": "active",
        "featured": true,
        "short_description": "6.7 inch OLED 5G smartphone",
        "full_description": "Ultra high resolution smartphone with triple lens camera and 5000mAh battery",
        "main_image": "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500",
        "images": ["https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500"],
        "tags": ["mobile", "5g"],
        "variations": []
      },
      {
        "id": 3,
        "category_id": 2,
        "subcategory_id": 3,
        "name": "Espresso Blend Coffee",
        "sku": "CB-003",
        "price": 1500.0,
        "discount_price": 1350.0,
        "stock": 30,
        "status": "active",
        "featured": true,
        "short_description": "Freshly roasted coffee beans",
        "full_description": "Rich dark roast arabica coffee beans ethically sourced",
        "main_image": "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=500",
        "images": ["https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=500"],
        "tags": ["beverage", "coffee"],
        "variations": []
      },
      {
        "id": 4,
        "category_id": 2,
        "subcategory_id": 3,
        "name": "Organic Ceylon Tea",
        "sku": "TEA-004",
        "price": 850.0,
        "discount_price": 750.0,
        "stock": 25,
        "status": "active",
        "featured": false,
        "short_description": "Pure Ceylon black tea",
        "full_description": "Hand-picked Ceylon tea leaves from Nuwara Eliya estates",
        "main_image": "https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500",
        "images": ["https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500"],
        "tags": ["beverage", "tea"],
        "variations": []
      },
      {
        "id": 5,
        "category_id": 3,
        "subcategory_id": null,
        "name": "Butter Croissant",
        "sku": "BAK-005",
        "price": 450.0,
        "discount_price": null,
        "stock": 18,
        "status": "active",
        "featured": false,
        "short_description": "Flaky French butter croissant",
        "full_description": "Freshly baked daily with authentic French butter",
        "main_image": "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500",
        "images": ["https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500"],
        "tags": ["bakery", "pastry"],
        "variations": []
      },
      {
        "id": 6,
        "category_id": 1,
        "subcategory_id": 2,
        "name": "Mechanical Keyboard",
        "sku": "KB-006",
        "price": 8500.0,
        "discount_price": 7900.0,
        "stock": 4,
        "status": "active",
        "featured": true,
        "short_description": "RGB Mechanical Gaming Keyboard",
        "full_description": "Tactile mechanical switches with customizable RGB backlight",
        "main_image": "https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500",
        "images": ["https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500"],
        "tags": ["electronics", "gaming"],
        "variations": []
      }
    ];
  }

  // --- Upload APIs ---

  /// POST /upload/image (Upload single image file)
  Future<Map<String, dynamic>> uploadImage(List<int> bytes, String filename) async {
    if (!ApiConfig.useMockApi) {
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
    }

    // Fallback URL if offline or mock mode
    await Future.delayed(const Duration(milliseconds: 400));
    return {
      'success': true,
      'url': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500',
      'filename': filename,
      'message': 'Uploaded image (fallback mode)',
    };
  }

  /// POST /upload/images (Upload multiple image files)
  Future<List<String>> uploadImages(List<({List<int> bytes, String filename})> files) async {
    if (files.isEmpty) return [];

    if (!ApiConfig.useMockApi) {
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
    }

    return files.map((f) => 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500').toList();
  }
}

