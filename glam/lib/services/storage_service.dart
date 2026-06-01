import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'token';
  static const String _keyProfile = 'profile';

  // Save both token and user profile
  static Future<void> saveSession(String token, Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyProfile, jsonEncode(profile));
  }

  // Get saved JWT token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Get saved user profile map
  static Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileStr = prefs.getString(_keyProfile);
    if (profileStr == null || profileStr.isEmpty) return null;
    try {
      return jsonDecode(profileStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Clear session on logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyProfile);
  }
}
