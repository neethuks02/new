import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agency_head/core/network/api_service.dart';

class AuthService {
  static const String _userKey = 'user_data';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Try unified login endpoint (POST api/login) which handles all roles (1, 2, 4, 5, 6)
      Map<String, dynamic> response;
      try {
        response = await ApiService.login(email, password);
      } catch (_) {
        // Fallback to manager_login
        response = await ApiService.managerLogin(email, password);
      }

      if (response['status'] == true && response['data'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(response['data']));
      }
      return response;
    } catch (e) {
      return {'status': false, 'message': 'Login failed: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  /// Check if the currently logged-in user has permission to create sheets.
  /// Field Executives (group_id = 4) and Backend Staff (group_id = 5) with can_create_sheet == true,
  /// or Managers/Admins (group_id = 6 or 1).
  static Future<bool> canCreateSheet() async {
    final user = await getUser();
    if (user == null) return false;
    final can = user['can_create_sheet'];
    if (can == true || can == 1 || can == '1' || can == 'true') {
      return true;
    }
    final groupId = int.tryParse(user['group_id']?.toString() ?? '0') ?? 0;
    return groupId == 6 || groupId == 1 || groupId == 4 || groupId == 5;
  }
}
