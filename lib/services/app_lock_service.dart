import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService extends ChangeNotifier {
  static const String _keyLockEnabled = 'app_lock_enabled';
  static const String _keyLockType = 'app_lock_type'; // 'pin' or 'pattern'
  static const String _keySavedPin = 'app_lock_saved_pin';
  static const String _keySavedPattern = 'app_lock_saved_pattern';
  static const String _keyBiometricEnabled = 'app_lock_biometric_enabled';
  static const String _keyPrivacyVeilEnabled = 'app_lock_privacy_veil_enabled';
  static const MethodChannel _securityChannel = MethodChannel('com.arsalandev.cashbook/security');

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLockEnabled = false;
  String _lockType = 'pin';
  String _savedPin = '';
  String _savedPattern = '';
  bool _isBiometricEnabled = true;
  bool _isPrivacyVeilEnabled = false;
  bool _isAuthenticating = false;

  bool get isLockEnabled => _isLockEnabled;
  String get lockType => _lockType;
  String get savedPin => _savedPin;
  String get savedPattern => _savedPattern;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isPrivacyVeilEnabled => _isPrivacyVeilEnabled;
  bool get isAuthenticating => _isAuthenticating;
  bool get hasPin => _savedPin.isNotEmpty;
  bool get hasPattern => _savedPattern.isNotEmpty;

  AppLockService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLockEnabled = prefs.getBool(_keyLockEnabled) ?? false;
    _lockType = prefs.getString(_keyLockType) ?? 'pin';
    _savedPin = prefs.getString(_keySavedPin) ?? '';
    _savedPattern = prefs.getString(_keySavedPattern) ?? '';
    _isBiometricEnabled = prefs.getBool(_keyBiometricEnabled) ?? true;
    _isPrivacyVeilEnabled = prefs.getBool(_keyPrivacyVeilEnabled) ?? false;
    await _syncNativeSecureMode(_isPrivacyVeilEnabled);
    notifyListeners();
  }

  Future<void> setLockEnabled(bool value) async {
    _isLockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockEnabled, value);
    notifyListeners();
  }

  Future<void> setLockType(String type) async {
    _lockType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLockType, type);
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    _savedPin = pin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedPin, pin);
    notifyListeners();
  }

  Future<void> setPattern(String pattern) async {
    _savedPattern = pattern;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedPattern, pattern);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _isBiometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, value);
    notifyListeners();
  }

  Future<void> setPrivacyVeilEnabled(bool value) async {
    _isPrivacyVeilEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyVeilEnabled, value);
    await _syncNativeSecureMode(value);
    notifyListeners();
  }

  Future<void> _syncNativeSecureMode(bool enabled) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _securityChannel.invokeMethod('setSecureMode', {'enabled': enabled});
      }
    } catch (e) {
      debugPrint('SecurityChannel setSecureMode error: $e');
    }
  }

  /// Check if hardware supports biometrics / fingerprint
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate user via Fingerprint / Face ID / System credentials
  Future<bool> authenticateBiometrics({String reason = 'Authenticate to access Cash Book'}) async {
    if (_isAuthenticating) return false;
    try {
      _isAuthenticating = true;
      notifyListeners();
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }
}
