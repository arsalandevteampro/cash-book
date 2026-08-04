import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/access_request_model.dart';
import '../../domain/app_config_repository.dart';
import '../../services/access_request_rate_limiter.dart';

class AppConfigRepositoryImpl implements AppConfigRepository {
  final FirebaseFirestore _firestore;

  AppConfigRepositoryImpl(this._firestore);

  DocumentReference get _settingsDoc =>
      _firestore.collection('app_config').doc('settings');

  CollectionReference get _requestsCol =>
      _firestore.collection('access_requests');

  @override
  Stream<String> watchAppMode() {
    return _settingsDoc.snapshots().map((snap) {
      if (!snap.exists) return 'production';
      final data = snap.data() as Map<String, dynamic>?;
      return data?['mode'] as String? ?? 'production';
    });
  }

  @override
  Stream<List<String>> watchTestingEmails() {
    return _firestore.collection('testing_emails').snapshots().map((snap) {
      return snap.docs.map((doc) => doc.id).toList();
    });
  }

  @override
  Future<void> submitAccessRequest(String name, String email, String appId, String appName) async {
    final lowerEmail = email.toLowerCase().trim();

    // 1. Check local device rate limit (max 3 requests per 24 hours)
    final rateLimitError = await AccessRequestRateLimiter.checkRateLimit();
    if (rateLimitError != null) {
      throw Exception(rateLimitError);
    }

    // 2. Check if email is already in approved testing emails
    final testingDoc = await _firestore.collection('testing_emails').doc(lowerEmail).get();
    if (testingDoc.exists) {
      throw Exception('This email address ($lowerEmail) is already an approved testing account.');
    }

    // 3. Query if a request already exists for this email and appId
    final query = await _requestsCol
        .where('email', isEqualTo: lowerEmail)
        .where('appId', isEqualTo: appId)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      final existingData = query.docs.first.data() as Map<String, dynamic>;
      final existingStatus = existingData['status'] as String? ?? 'pending';

      if (existingStatus == 'pending') {
        throw Exception('An access request for $lowerEmail is already pending review. Please wait for approval.');
      } else if (existingStatus == 'approved') {
        throw Exception('An access request for $lowerEmail has already been approved.');
      }

      // Update existing request status back to pending if it was previously rejected
      await _requestsCol.doc(query.docs.first.id).set({
        'name': name,
        'email': lowerEmail,
        'status': 'pending',
        'adminMessage': '',
        'appId': appId,
        'appName': appName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new request
      await _requestsCol.add({
        'name': name,
        'email': lowerEmail,
        'status': 'pending',
        'adminMessage': '',
        'appId': appId,
        'appName': appName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Record submission timestamp locally for rate limiting
    await AccessRequestRateLimiter.recordSubmission();
  }

  @override
  Stream<AccessRequestModel?> watchRequestByEmailAndApp(String email, String appId) {
    final lowerEmail = email.toLowerCase().trim();
    return _requestsCol
        .where('email', isEqualTo: lowerEmail)
        .where('appId', isEqualTo: appId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return AccessRequestModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    });
  }
}
