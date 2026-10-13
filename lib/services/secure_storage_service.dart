import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hardware-Backed Keystore / Keychain Encrypted Storage Service
/// Stores auth tokens, user identifiers, and sensitive session credentials
/// securely using EncryptedSharedPreferences (Android) and Keychain (iOS).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyToken = 'auth_token';
  static const _keyLegacyJwt = 'jwt_token';
  static const _keyUserId = 'user_id';
  static const _keyUserType = 'user_type';
  static const _keyUserRole = 'user_role';

  /// Save session credentials into encrypted Keystore/Keychain
  static Future<void> saveSession({
    required String token,
    required int userId,
    required int userType,
    String? role,
  }) async {
    // Strip multi-line spaces/newlines before saving Bearer token
    final cleanToken = token.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
    await _storage.write(key: _keyToken, value: cleanToken);
    await _storage.write(key: _keyLegacyJwt, value: cleanToken);
    await _storage.write(key: _keyUserId, value: userId.toString());
    await _storage.write(key: _keyUserType, value: userType.toString());
    if (role != null) {
      await _storage.write(key: _keyUserRole, value: role);
    }
  }

  /// Retrieve sanitized Bearer token
  static Future<String?> getToken() async {
    final token = await _storage.read(key: _keyToken) ?? await _storage.read(key: _keyLegacyJwt);
    if (token == null) return null;
    return token.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
  }

  /// Save just token
  static Future<void> saveToken(String token) async {
    final cleanToken = token.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
    await _storage.write(key: _keyToken, value: cleanToken);
    await _storage.write(key: _keyLegacyJwt, value: cleanToken);
  }

  /// Retrieve stored user id
  static Future<int?> getUserId() async {
    final val = await _storage.read(key: _keyUserId);
    return val != null ? int.tryParse(val) : null;
  }

  /// Retrieve stored user type
  static Future<int?> getUserType() async {
    final val = await _storage.read(key: _keyUserType);
    return val != null ? int.tryParse(val) : null;
  }

  /// Retrieve stored role
  static Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  /// Clear all credentials and session state on logout or 401 expiry
  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
