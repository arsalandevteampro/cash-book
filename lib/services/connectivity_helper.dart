import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Helper to verify active internet connectivity.
class ConnectivityHelper {
  ConnectivityHelper._();

  /// Returns true if device is connected to Wi-Fi or Mobile Data AND has active internet access.
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none) ||
          connectivityResult.isEmpty) {
        return false;
      }

      // Verify active DNS lookup to ensure actual internet reachability
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
