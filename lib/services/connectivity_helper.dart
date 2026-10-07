import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Helper to verify active internet connectivity.
class ConnectivityHelper {
  ConnectivityHelper._();

  /// Returns true if device is connected to Wi-Fi or Mobile Data AND has active internet access.
  /// Uses a real HTTP 204 captive-portal request to ensure actual data transfer capability,
  /// preventing false positives from SIMs with zero balance / no package or DNS caching.
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none) ||
          connectivityResult.isEmpty) {
        return false;
      }

      // Real HTTPS 204 check (Android standard captive-portal & internet verification).
      // Uses TLS encryption to guarantee direct connection to Google and avoid HTTP interception.
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await client
            .getUrl(Uri.parse('https://clients3.google.com/generate_204'))
            .timeout(const Duration(seconds: 3));
        request.followRedirects = false;
        final response = await request.close()
            .timeout(const Duration(seconds: 3));

        return response.statusCode == 204;
      } catch (_) {
        return false;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }
}
