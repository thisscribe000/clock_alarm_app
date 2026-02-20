import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'settings_theme';
  static const String _decimalPlacesKey = 'settings_decimal_places';
  static const String _hapticKey = 'settings_haptic_feedback';
  static const String _autoUpdateKey = 'settings_auto_update';
  static const String _favoritesKey = 'currency_favorites';

  ThemeMode _themeMode = ThemeMode.system;
  int _decimalPlaces = 5;
  bool _hapticFeedback = true;
  bool _autoUpdateRates = true;
  List<String> _favoriteCurrencies = ['us dollar', 'euro', 'pound'];

  ThemeMode get themeMode => _themeMode;
  int get decimalPlaces => _decimalPlaces;
  bool get hapticFeedback => _hapticFeedback;
  bool get autoUpdateRates => _autoUpdateRates;
  List<String> get favoriteCurrencies => _favoriteCurrencies;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeIndex = prefs.getInt(_themeKey) ?? 1;
    _themeMode = ThemeMode.values[themeIndex];
    
    // Load decimal places and sanitize stored value (avoid removed options)
    final storedPlaces = prefs.getInt(_decimalPlacesKey);
    final allowedPlaces = <int>{3, 5};
    if (storedPlaces == null) {
      _decimalPlaces = 5;
    } else if (!allowedPlaces.contains(storedPlaces)) {
      // If prefs contains a removed option (eg. 8), reset to default and persist
      _decimalPlaces = 5;
      await prefs.setInt(_decimalPlacesKey, _decimalPlaces);
    } else {
      _decimalPlaces = storedPlaces;
    }
    _hapticFeedback = prefs.getBool(_hapticKey) ?? true;
    _autoUpdateRates = prefs.getBool(_autoUpdateKey) ?? true;
    
    final favorites = prefs.getStringList(_favoritesKey);
    if (favorites != null) {
      _favoriteCurrencies = favorites;
    }
    
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setDecimalPlaces(int places) async {
    _decimalPlaces = places;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_decimalPlacesKey, places);
    notifyListeners();
  }

  Future<void> setHapticFeedback(bool enabled) async {
    _hapticFeedback = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoUpdateRates(bool enabled) async {
    _autoUpdateRates = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateKey, enabled);
    notifyListeners();
  }

  // Favorites methods
  Future<void> addFavorite(String currencyName) async {
    if (!_favoriteCurrencies.contains(currencyName)) {
      _favoriteCurrencies.add(currencyName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteCurrencies);
      notifyListeners();
    }
  }

  Future<void> removeFavorite(String currencyName) async {
    _favoriteCurrencies.remove(currencyName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteCurrencies);
    notifyListeners();
  }

  bool isFavorite(String currencyName) {
    return _favoriteCurrencies.contains(currencyName);
  }
}