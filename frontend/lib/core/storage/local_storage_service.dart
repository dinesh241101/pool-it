import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static LocalStorageService? _instance;
  late SharedPreferences _prefs;

  LocalStorageService._();

  static Future<LocalStorageService> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  Future<void> saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> saveJson(String key, dynamic value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  dynamic getJson(String key) {
    final value = _prefs.getString(key);
    if (value == null) return null;
    return jsonDecode(value);
  }

  Future<void> saveList(String key, List<dynamic> list) async {
    await _prefs.setString(key, jsonEncode(list));
  }

  List<dynamic> getList(String key) {
    final value = _prefs.getString(key);
    if (value == null) return [];
    return jsonDecode(value) as List<dynamic>;
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
