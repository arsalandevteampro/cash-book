import 'package:cloud_firestore/cloud_firestore.dart';

class AccessRequestModel {
  final String id;
  final String name;
  final String email;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String adminMessage;
  final String appId;
  final String appName;
  final DateTime? createdAt;

  AccessRequestModel({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.adminMessage = '',
    this.appId = '',
    this.appName = '',
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'status': status,
        'adminMessage': adminMessage,
        'appId': appId,
        'appName': appName,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory AccessRequestModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      return null;
    }

    return AccessRequestModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      status: map['status'] ?? 'pending',
      adminMessage: map['adminMessage'] ?? '',
      appId: map['appId'] ?? '',
      appName: map['appName'] ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }
}
