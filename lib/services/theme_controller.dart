import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme choice and persists it across launches.
///
/// Modes: [ThemeMode.system] (default — follows the device), [ThemeMode.light],
/// [ThemeMode.dark]. Driven from the Me screen selector; consumed by
/// [MaterialApp]'s `themeMode` in main.dart.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'themeMode'; // 'system' | 'light' | 'dark'

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Load the saved preference. Safe to call before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _decode(prefs.getString(_prefsKey));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(mode));
  }

  static ThemeMode _decode(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
