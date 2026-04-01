import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _key = 'theme_mode';
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// يرجع وضع الثيم المحفوظ أو 'system' كافتراضي
  ThemeMode get themeMode {
    final mode = _prefs.getString(_key);
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// حفظ وضع الثيم وتغييره في التطبيق فوراً
  void saveThemeMode(ThemeMode mode) {
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    _prefs.setString(_key, modeStr);
    Get.changeThemeMode(mode);
  }

  /// التبديل التلقائي (دائري) بين الأوضاع الثلاثة للأيقونة السريعة
  void cycleTheme() {
    final currentMode = themeMode;
    if (currentMode == ThemeMode.system) {
      saveThemeMode(ThemeMode.light);
    } else if (currentMode == ThemeMode.light) {
      saveThemeMode(ThemeMode.dark);
    } else {
      saveThemeMode(ThemeMode.system);
    }
  }

  /// الحصول على أيقونة تمثل الوضع الحالي
  IconData get themeIcon {
    final mode = themeMode;
    if (mode == ThemeMode.system) return Icons.brightness_auto_rounded;
    if (mode == ThemeMode.light) return Icons.light_mode_rounded;
    return Icons.dark_mode_rounded;
  }

  /// نص يمثل الوضع الحالي للعرض في الإعدادات
  String get themeModeName {
    final mode = themeMode;
    if (mode == ThemeMode.system) return "تلقائي (حسب النظام)";
    if (mode == ThemeMode.light) return "الوضع الفاتح";
    return "الوضع الداكن";
  }
}

