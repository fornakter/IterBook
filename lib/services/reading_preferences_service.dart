import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing reading display preferences
class ReadingPreferencesService extends ChangeNotifier {
  static const String _fontSizeKey = 'reading_font_size';
  static const String _backgroundColorKey = 'reading_background_color';
  static const String _textColorKey = 'reading_text_color';

  // Default values
  static const double defaultFontSize = 48.0;
  static const double minFontSize = 24.0;
  static const double maxFontSize = 72.0;
  static const int defaultBackgroundColor = 0xFF000000; // Black
  static const int defaultTextColor = 0xFFFFFFFF; // White

  // Preset color options
  static const List<Color> backgroundPresets = [
    Colors.black,
    Color(0xFF1A1A2E), // Dark blue
    Color(0xFF2D2D2D), // Dark grey
    Color(0xFFF5F5DC), // Beige (sepia)
    Colors.white,
  ];

  static const List<Color> textPresets = [
    Colors.white,
    Color(0xFFE0E0E0), // Light grey
    Color(0xFF5C4033), // Sepia brown
    Colors.black,
  ];

  double _fontSize = defaultFontSize;
  Color _backgroundColor = const Color(defaultBackgroundColor);
  Color _textColor = const Color(defaultTextColor);
  bool _isLoaded = false;

  // Getters
  double get fontSize => _fontSize;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  bool get isLoaded => _isLoaded;

  /// Initialize and load preferences from storage
  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      _fontSize = prefs.getDouble(_fontSizeKey) ?? defaultFontSize;
      _backgroundColor = Color(
        prefs.getInt(_backgroundColorKey) ?? defaultBackgroundColor,
      );
      _textColor = Color(
        prefs.getInt(_textColorKey) ?? defaultTextColor,
      );

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reading preferences: $e');
      _isLoaded = true;
    }
  }

  /// Set font size
  Future<void> setFontSize(double size) async {
    final clampedSize = size.clamp(minFontSize, maxFontSize);
    if (_fontSize == clampedSize) return;

    _fontSize = clampedSize;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, _fontSize);
    } catch (e) {
      debugPrint('Error saving font size: $e');
    }
  }

  /// Set background color
  Future<void> setBackgroundColor(Color color) async {
    if (_backgroundColor == color) return;

    _backgroundColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_backgroundColorKey, color.toARGB32());
    } catch (e) {
      debugPrint('Error saving background color: $e');
    }
  }

  /// Set text color
  Future<void> setTextColor(Color color) async {
    if (_textColor == color) return;

    _textColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_textColorKey, color.toARGB32());
    } catch (e) {
      debugPrint('Error saving text color: $e');
    }
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    _fontSize = defaultFontSize;
    _backgroundColor = const Color(defaultBackgroundColor);
    _textColor = const Color(defaultTextColor);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fontSizeKey);
      await prefs.remove(_backgroundColorKey);
      await prefs.remove(_textColorKey);
    } catch (e) {
      debugPrint('Error resetting preferences: $e');
    }
  }
}
