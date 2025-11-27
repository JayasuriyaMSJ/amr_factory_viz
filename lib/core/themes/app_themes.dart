import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// enum ThemeOption { system, light, dark }

// class ThemeProvider extends ChangeNotifier {
//   ThemeOption _themeOption = ThemeOption.system;
//   late SharedPreferences _prefs;

//   ThemeOption get themeOption => _themeOption;

//   ThemeProvider() {
//     _loadTheme();
//   }

//   Future<void> _loadTheme() async {
//     _prefs = await SharedPreferences.getInstance();
//     final themeIndex = _prefs.getInt('theme_option') ?? 0;
//     _themeOption = ThemeOption.values[themeIndex];
//     notifyListeners();
//   }

//   Future<void> setTheme(ThemeOption option) async {
//     _themeOption = option;
//     await _prefs.setInt('theme_option', option.index);
//     notifyListeners();
//   }

//   ThemeMode get themeMode {
//     switch (_themeOption) {
//       case ThemeOption.light:
//         return ThemeMode.light;
//       case ThemeOption.dark:
//         return ThemeMode.dark;
//       case ThemeOption.system:
//       default:
//         return ThemeMode.system;
//     }
//   }
// }


enum ThemeOption { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  ThemeOption _themeOption = ThemeOption.system;
  late SharedPreferences _prefs;

  ThemeOption get themeOption => _themeOption;

  ThemeProvider() {
    loadTheme();
  }

  Future<void> loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final themeIndex = _prefs.getInt('theme_option') ?? 0;
    _themeOption = ThemeOption.values[themeIndex];
    notifyListeners();
  }

  Future<void> setTheme(ThemeOption option) async {
    _themeOption = option;
    await _prefs.setInt('theme_option', option.index);
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_themeOption) {
      case ThemeOption.light:
        return ThemeMode.light;
      case ThemeOption.dark:
        return ThemeMode.dark;
      case ThemeOption.system:
      default:
        return ThemeMode.system;
    }
  }
}