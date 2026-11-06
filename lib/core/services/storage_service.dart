import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserData = 'user_data';
  static const String _keyUserName = 'user_name';
  static const String _keyUserAvatar = 'user_avatar';
  static const String _keyLastEmail = 'last_email';
  static const String _keyDiscoveryFilter = 'discovery_filter';

  static SharedPreferences? _prefs;
  static final Map<String, String> _memoryCache = {};

  static Map<String, dynamic>? decodeJwt(String token) {
    try {
      final clean = token.replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '').trim();
      final parts = clean.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final payloadStr = utf8.decode(base64Url.decode(normalized));
        final decoded = jsonDecode(payloadStr);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final key in [_keyToken, _keyUserId, _keyUserData, _keyUserName, _keyUserAvatar, _keyLastEmail]) {
        final val = _prefs?.getString(key);
        if (val != null && val.isNotEmpty) {
          _memoryCache[key] = val;
        }
      }
    } catch (e) {
      debugPrint('Warning: SharedPreferences init error: $e');
    }
  }

  static Future<void> saveLastEmail(String email) async {
    _memoryCache[_keyLastEmail] = email;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_keyLastEmail, email);
    } catch (_) {}
  }

  static String? getLastEmail() {
    try {
      return _prefs?.getString(_keyLastEmail) ?? _memoryCache[_keyLastEmail];
    } catch (_) {
      return _memoryCache[_keyLastEmail];
    }
  }

  static Future<void> saveToken(String token) async {
    _memoryCache[_keyToken] = token;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_keyToken, token);
      
      // Auto-extract user ID and info from JWT token payload
      final payload = decodeJwt(token);
      if (payload != null) {
        final uid = payload['_id'] ?? payload['id'] ?? payload['userId'];
        if (uid != null && uid.toString().isNotEmpty) {
          await saveUserId(uid.toString());
        }
      }
    } catch (_) {}
  }

  static String? getToken() {
    try {
      return _prefs?.getString(_keyToken) ?? _memoryCache[_keyToken];
    } catch (_) {
      return _memoryCache[_keyToken];
    }
  }

  static Future<void> saveUserId(String userId) async {
    _memoryCache[_keyUserId] = userId;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_keyUserId, userId);
    } catch (_) {}
  }

  static String? getUserId() {
    try {
      return _prefs?.getString(_keyUserId) ?? _memoryCache[_keyUserId];
    } catch (_) {
      return _memoryCache[_keyUserId];
    }
  }

  static Future<void> saveUserData(String jsonString) async {
    _memoryCache[_keyUserData] = jsonString;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_keyUserData, jsonString);
    } catch (_) {}
  }

  static String? getUserDataString() {
    try {
      return _prefs?.getString(_keyUserData) ?? _memoryCache[_keyUserData];
    } catch (_) {
      return _memoryCache[_keyUserData];
    }
  }

  static Future<void> saveUserProfileInfo(
      {required String name, required String avatar}) async {
    _memoryCache[_keyUserName] = name;
    _memoryCache[_keyUserAvatar] = avatar;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_keyUserName, name);
      await _prefs?.setString(_keyUserAvatar, avatar);
    } catch (_) {}
  }

  static String? getUserName() {
    try {
      final cached = _prefs?.getString(_keyUserName) ?? _memoryCache[_keyUserName];
      if (cached != null && cached.isNotEmpty && cached != 'Prem Jodo Member') {
        return cached;
      }
      final userData = getUserDataString();
      if (userData != null && userData.isNotEmpty) {
        final decoded = Uri.decodeFull(userData);
        final match =
            RegExp(r'"(?:name|fullName|userName)"\s*:\s*"([^"]+)"').firstMatch(userData) ??
                RegExp(r'"(?:name|fullName|userName)"\s*:\s*"([^"]+)"').firstMatch(decoded);
        if (match != null && match.group(1) != null) {
          return match.group(1);
        }
      }
      return cached;
    } catch (_) {
      return _memoryCache[_keyUserName];
    }
  }

  static String? getUserAvatar() {
    try {
      final cached = _prefs?.getString(_keyUserAvatar) ?? _memoryCache[_keyUserAvatar];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      final userData = getUserDataString();
      if (userData != null && userData.isNotEmpty) {
        final decoded = Uri.decodeFull(userData);
        final match = RegExp(
                r'"(?:photos|photoUrl|avatar|profilePhoto)"\s*:\s*\[\s*"([^"]+)"')
            .firstMatch(userData) ??
            RegExp(r'"(?:photoUrl|avatar|profilePhoto)"\s*:\s*"([^"]+)"')
                .firstMatch(userData) ??
            RegExp(r'"(?:photoUrl|avatar|profilePhoto)"\s*:\s*"([^"]+)"')
                .firstMatch(decoded);
        if (match != null && match.group(1) != null) {
          return match.group(1);
        }
      }
      return cached;
    } catch (_) {
      return _memoryCache[_keyUserAvatar];
    }
  }

  static Future<void> saveDiscoveryFilter(Map<String, dynamic> filterMap) async {
    final str = jsonEncode(filterMap);
    _memoryCache[_keyDiscoveryFilter] = str;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_keyDiscoveryFilter, str);
    } catch (_) {}
  }

  static Map<String, dynamic>? getDiscoveryFilter() {
    try {
      final val = _prefs?.getString(_keyDiscoveryFilter) ?? _memoryCache[_keyDiscoveryFilter];
      if (val != null && val.isNotEmpty) {
        final decoded = jsonDecode(val);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearAuth() async {
    _memoryCache.remove(_keyToken);
    _memoryCache.remove(_keyUserId);
    _memoryCache.remove(_keyUserData);
    _memoryCache.remove(_keyUserName);
    _memoryCache.remove(_keyUserAvatar);
    try {
      await _prefs?.remove(_keyToken);
      await _prefs?.remove(_keyUserId);
      await _prefs?.remove(_keyUserData);
      await _prefs?.remove(_keyUserName);
      await _prefs?.remove(_keyUserAvatar);
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      await _prefs?.clear();
    } catch (_) {}
  }
}
