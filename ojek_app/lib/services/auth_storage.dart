import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _kToken = 'auth_token';
  static const _kRole = 'auth_role';
  static const _kUserId = 'auth_user_id';

  static Future<void> saveAuth({required String token, required String role, int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kRole, role);
    if (userId != null) {
      await prefs.setInt(_kUserId, userId);
    }
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRole);
    await prefs.remove(_kUserId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserId);
  }
}