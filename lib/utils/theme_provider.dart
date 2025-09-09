import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isCustomTheme = false;
  Map<String, dynamic>? _customThemeData;
  final UserService _userService = UserService();

  bool get isDarkMode => _isDarkMode;
  bool get isCustomTheme => _isCustomTheme;
  Map<String, dynamic>? get customThemeData => _customThemeData;

  // Initialize theme based on system preference for first-time users
  Future<void> initializeTheme(BuildContext context) async {
    try {
      final currentUser = _userService.getCurrentUser();
      if (currentUser != null) {
        final userModel = await _userService.getUser(currentUser.uid);
        if (userModel != null) {
          // User exists, load their saved theme preference
          _isDarkMode = userModel.settings.darkModeEnabled;
        } else {
          // First-time user, use system theme
          _isDarkMode = _getSystemTheme(context);
          // Save the system theme preference
          await _saveThemeToUser(_isDarkMode);
        }
      } else {
        // No user logged in, use system theme
        _isDarkMode = _getSystemTheme(context);
      }
      notifyListeners();
    } catch (e) {
      print('Error initializing theme: $e');
      // Fallback to system theme
      _isDarkMode = _getSystemTheme(context);
      notifyListeners();
    }
  }

  // Get system theme preference
  bool _getSystemTheme(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    return brightness == Brightness.dark;
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeToUser(_isDarkMode);
    notifyListeners();
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    _saveThemeToUser(isDark);
    notifyListeners();
  }

  void loadThemeFromUser(UserModel user) {
    _isDarkMode = user.settings.darkModeEnabled;
    notifyListeners();
  }

  Future<void> _saveThemeToUser(bool isDark) async {
    try {
      final currentUser = _userService.getCurrentUser();
      if (currentUser != null) {
        await _userService.updateSetting(
          currentUser.uid,
          'darkModeEnabled',
          isDark,
        );
      }
    } catch (e) {
      print('Error saving theme to user: $e');
    }
  }

  ThemeData get lightTheme {
    if (_isCustomTheme && _customThemeData != null) {
      return _buildCustomTheme(_customThemeData!, false);
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B46C1),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF6B46C1).withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.black54),
        labelStyle: const TextStyle(color: Colors.black87),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
        bodySmall: TextStyle(color: Colors.black54),
        labelLarge: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: Colors.black87),
        labelSmall: TextStyle(color: Colors.black54),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
    );
  }

  ThemeData get darkTheme {
    if (_isCustomTheme && _customThemeData != null) {
      return _buildCustomTheme(_customThemeData!, true);
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B46C1),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          shadowColor: const Color(0xFF6B46C1).withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white70),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  void applyCustomTheme(Map<String, dynamic> themeData) {
    // Apply custom theme colors
    final primaryColor = _hexToColor(themeData['primaryColor'] ?? '#6B46C1');
    final secondaryColor = _hexToColor(
      themeData['secondaryColor'] ?? '#9F7AEA',
    );
    final backgroundColor = _hexToColor(
      themeData['backgroundColor'] ?? '#1A202C',
    );
    final surfaceColor = _hexToColor(themeData['surfaceColor'] ?? '#2D3748');
    final textColor = _hexToColor(themeData['textColor'] ?? '#F7FAFC');

    // Store the custom theme data
    _customThemeData = themeData;
    _isCustomTheme = true;

    // Save the custom theme to user settings
    _saveCustomThemeToUser(themeData);

    notifyListeners();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF${hex}', radix: 16));
  }

  void _saveCustomThemeToUser(Map<String, dynamic> themeData) async {
    try {
      final currentUser = _userService.getCurrentUser();
      if (currentUser != null) {
        await _userService.updateSetting(
          currentUser.uid,
          'customTheme',
          themeData,
        );
      }
    } catch (e) {
      print('Error saving custom theme to user: $e');
    }
  }

  void resetToDefaultTheme() {
    _isCustomTheme = false;
    _customThemeData = null;
    _saveCustomThemeToUser({});
    // Keep the current dark mode setting when resetting
    notifyListeners();
  }

  ThemeData _buildCustomTheme(Map<String, dynamic> themeData, bool isDark) {
    final primaryColor = _hexToColor(themeData['primaryColor'] ?? '#6B46C1');
    final secondaryColor = _hexToColor(
      themeData['secondaryColor'] ?? '#9F7AEA',
    );
    final backgroundColor = _hexToColor(
      themeData['backgroundColor'] ?? '#1A202C',
    );
    final surfaceColor = _hexToColor(themeData['surfaceColor'] ?? '#2D3748');
    final textColor = _hexToColor(themeData['textColor'] ?? '#F7FAFC');

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
        onPrimary: textColor,
        onSecondary: textColor,
        onSurface: textColor,
        onBackground: textColor,
        error: Colors.red,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: isDark ? 12 : 4,
        shadowColor: primaryColor.withOpacity(isDark ? 0.5 : 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isDark ? 6 : 4,
          shadowColor: primaryColor.withOpacity(isDark ? 0.4 : 0.3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: textColor.withOpacity(0.7)),
        labelStyle: TextStyle(color: textColor),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: textColor.withOpacity(0.7)),
        labelLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textColor),
        labelSmall: TextStyle(color: textColor.withOpacity(0.7)),
      ),
      iconTheme: IconThemeData(color: textColor),
    );
  }
}
