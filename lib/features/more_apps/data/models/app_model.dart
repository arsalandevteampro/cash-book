import 'package:cloud_firestore/cloud_firestore.dart';

class AppModel {
  final String id;
  final String name;
  final String description;
  final String packageName;
  final String playStoreUrl;
  final String imageUrl;
  final int priority;
  final bool active;
  final String mode; // 'production' | 'testing'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppModel({
    required this.id,
    required this.name,
    required this.description,
    required this.packageName,
    required this.playStoreUrl,
    required this.imageUrl,
    required this.priority,
    required this.active,
    required this.mode,
    this.createdAt,
    this.updatedAt,
  });

  AppModel copyWith({
    String? id,
    String? name,
    String? description,
    String? packageName,
    String? playStoreUrl,
    String? imageUrl,
    int? priority,
    bool? active,
    String? mode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      packageName: packageName ?? this.packageName,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      priority: priority ?? this.priority,
      active: active ?? this.active,
      mode: mode ?? this.mode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'packageName': packageName,
      'playStoreUrl': playStoreUrl,
      'imageUrl': imageUrl,
      'priority': priority,
      'active': active,
      'mode': mode,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory AppModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return AppModel(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      packageName: map['packageName'] ?? '',
      playStoreUrl: map['playStoreUrl'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      priority: map['priority'] is int ? map['priority'] : int.tryParse(map['priority']?.toString() ?? '') ?? 0,
      active: map['active'] ?? false,
      mode: map['mode'] ?? 'production',
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }
}
