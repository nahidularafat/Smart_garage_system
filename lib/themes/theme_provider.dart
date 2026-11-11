// lib/themes/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode;

  ThemeProvider(this._isDarkMode); // Constructor to set initial theme

  bool get isDarkMode => _isDarkMode;

  ThemeData get themeData => _isDarkMode ? ThemeData.dark() : ThemeData.light();

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemeToPrefs(); // ✅ থিমের অবস্থা সেভ করা হচ্ছে
    notifyListeners();
  }

  // ✅ SharedPreferences-এ থিমের অবস্থা সেভ করার ফাংশন
  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }
}

// ✅ অ্যাপ চালু হওয়ার সময় সেভ করা থিম লোড করার জন্য Helper ফাংশন
Future<bool> loadThemeFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isDarkMode') ?? false; // যদি কিছু সেভ না থাকে, তবে ডিফল্ট light মোড
}