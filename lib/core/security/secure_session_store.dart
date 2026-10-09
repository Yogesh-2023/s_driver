import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureSessionStore {
  SecureSessionStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _cookieKey = 'session_cookie';
  static const _tokenKey = 'auth_token';
  static const _csrfKey = 'csrf_token';

  static Future<String?> readCookie() => _readAndMigrate(_cookieKey);
  static Future<String?> readToken() => _readAndMigrate(_tokenKey);
  static Future<String?> readCsrfToken() => _readAndMigrate(_csrfKey);
  static Future<void> writeCookie(String value) => _write(_cookieKey, value);
  static Future<void> writeToken(String value) => _write(_tokenKey, value);
  static Future<void> writeCsrfToken(String value) => _write(_csrfKey, value);

  static Future<void> clear() async {
    try {
      await Future.wait([
        _storage.delete(key: _cookieKey),
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _csrfKey),
      ]);
    } on MissingPluginException {
      // The legacy values below are still cleared if native registration fails.
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cookieKey);
    await preferences.remove(_tokenKey);
  }

  static Future<String?> _readAndMigrate(String key) async {
    String? secureValue;
    try {
      secureValue = await _storage.read(key: key);
    } on MissingPluginException {
      return (await SharedPreferences.getInstance()).getString(key);
    }
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }
    final preferences = await SharedPreferences.getInstance();
    final legacyValue = preferences.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) return null;
    try {
      await _storage.write(key: key, value: legacyValue);
      await preferences.remove(key); // Clear legacy plaintext value once migrated
    } on MissingPluginException {
      // Keep legacy value if secure storage is unavailable
    }
    return legacyValue;
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
    }
  }
}
