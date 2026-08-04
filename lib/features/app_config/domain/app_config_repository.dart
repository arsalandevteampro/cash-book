import '../data/models/access_request_model.dart';

abstract class AppConfigRepository {
  /// Stream for the current app mode: "testing" or "production"
  Stream<String> watchAppMode();

  /// Stream of all testing-approved emails
  Stream<List<String>> watchTestingEmails();

  /// Submit a request for beta access for a specific app
  Future<void> submitAccessRequest(String name, String email, String appId, String appName);

  /// Stream the status of a specific request for a specific app
  Stream<AccessRequestModel?> watchRequestByEmailAndApp(String email, String appId);
}
