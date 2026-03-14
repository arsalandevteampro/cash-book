import 'package:flutter/foundation.dart';
import 'database_service.dart';

class SettingsService with ChangeNotifier {
  String _currencySymbol = 'Rs';
  String _theme = 'system';
  bool _isLoading = false;
  String? _error;

  String get currencySymbol => _currencySymbol;
  String get theme => _theme;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize with Hive database
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Load settings from Hive
      _currencySymbol = DatabaseService.getSetting<String>('currency') ?? 'Rs';
      _theme = DatabaseService.getSetting<String>('theme') ?? 'system';
      
      _setError(null);
      if (kDebugMode) {
        print('✅ Loaded settings from Hive: currency=$_currencySymbol, theme=$_theme');
      }
    } catch (e) {
      _setError('Failed to initialize settings: $e');
      if (kDebugMode) {
        print('Error initializing settings: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setCurrency(String newSymbol) async {
    try {
      // Save to Hive database
      await DatabaseService.updateSetting('currency', newSymbol);
      
      // Update local state
      _currencySymbol = newSymbol;
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Currency updated: $newSymbol');
      }
    } catch (e) {
      _setError('Failed to update currency: $e');
      if (kDebugMode) {
        print('Error updating currency: $e');
      }
    }
  }

  Future<void> setTheme(String newTheme) async {
    try {
      // Save to Hive database
      await DatabaseService.updateSetting('theme', newTheme);
      
      // Update local state
      _theme = newTheme;
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Theme updated: $newTheme');
      }
    } catch (e) {
      _setError('Failed to update theme: $e');
      if (kDebugMode) {
        print('Error updating theme: $e');
      }
    }
  }

  // Get all settings
  Map<String, dynamic> getAllSettings() {
    return DatabaseService.getAllSettings();
  }

  // Update multiple settings at once
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      for (final entry in settings.entries) {
        await DatabaseService.updateSetting(entry.key, entry.value);
      }
      
      // Update local state
      if (settings.containsKey('currency')) {
        _currencySymbol = settings['currency'] as String;
      }
      if (settings.containsKey('theme')) {
        _theme = settings['theme'] as String;
      }
      
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Settings updated: $settings');
      }
    } catch (e) {
      _setError('Failed to update settings: $e');
      if (kDebugMode) {
        print('Error updating settings: $e');
      }
    }
  }

  // Reset to default settings
  Future<void> resetToDefaults() async {
    try {
      await updateSettings({
        'currency': 'Rs',
        'theme': 'system',
      });
      
      // Update local state
      _currencySymbol = 'Rs';
      _theme = 'system';
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Settings reset to defaults');
      }
    } catch (e) {
      _setError('Failed to reset settings: $e');
      if (kDebugMode) {
        print('Error resetting settings: $e');
      }
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  // Refresh settings from database
  Future<void> refresh() async {
    await initialize();
  }
}
