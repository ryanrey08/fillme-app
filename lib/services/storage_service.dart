import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class StorageService {
  SharedPreferences? _prefs;
  
  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Auth Token
  Future<void> saveToken(String token) async {
    final p = await prefs;
    await p.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    final p = await prefs;
    return p.getString(AppConstants.tokenKey);
  }

  Future<void> deleteToken() async {
    final p = await prefs;
    await p.remove(AppConstants.tokenKey);
  }

  // User Data
  Future<void> saveUser(UserModel user) async {
    final p = await prefs;
    await p.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final p = await prefs;
    final userJson = p.getString(AppConstants.userKey);
    if (userJson == null) return null;
    return UserModel.fromJson(jsonDecode(userJson));
  }

  Future<void> deleteUser() async {
    final p = await prefs;
    await p.remove(AppConstants.userKey);
  }

  // Guest Mode
  Future<void> setGuestMode(bool isGuest) async {
    final p = await prefs;
    await p.setBool(AppConstants.guestKey, isGuest);
  }

  Future<bool> isGuestMode() async {
    final p = await prefs;
    return p.getBool(AppConstants.guestKey) ?? false;
  }

  Future<void> saveGuestData(GuestUser guest) async {
    final p = await prefs;
    await p.setString('guest_data', jsonEncode(guest.toJson()));
  }

  Future<GuestUser?> getGuestData() async {
    final p = await prefs;
    final guestJson = p.getString('guest_data');
    if (guestJson == null) return null;
    return GuestUser.fromJson(jsonDecode(guestJson));
  }

  Future<GuestUser> createGuestUser() async {
    final guest = GuestUser(
      localId: const Uuid().v4(),
      createdAt: DateTime.now(),
    );
    await saveGuestData(guest);
    await setGuestMode(true);
    return guest;
  }

  Future<void> clearGuestData() async {
    final p = await prefs;
    await p.remove('guest_data');
    await p.remove(AppConstants.guestKey);
  }

  // Theme
  Future<void> saveTheme(String theme) async {
    final p = await prefs;
    await p.setString(AppConstants.themeKey, theme);
  }

  Future<String> getTheme() async {
    final p = await prefs;
    return p.getString(AppConstants.themeKey) ?? 'light';
  }

  // Clear all data
  Future<void> clearAll() async {
    final p = await prefs;
    await p.clear();
  }

  // Generic methods for custom data
  Future<void> setString(String key, String value) async {
    final p = await prefs;
    await p.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final p = await prefs;
    return p.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    final p = await prefs;
    await p.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final p = await prefs;
    return p.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    final p = await prefs;
    await p.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final p = await prefs;
    return p.getInt(key);
  }

  Future<void> setDouble(String key, double value) async {
    final p = await prefs;
    await p.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    final p = await prefs;
    return p.getDouble(key);
  }

  Future<void> remove(String key) async {
    final p = await prefs;
    await p.remove(key);
  }
}
