import 'package:hive/hive.dart';

part 'follow_up.g.dart';

@HiveType(typeId: 4)
enum FollowUpType {
  @HiveField(0)
  toReceive, // Paisa lena hai (Receivable / Customer Recovery)

  @HiveField(1)
  toPay, // Paisa dena hai (Payable / Vendor / Bill / Rent)
}

@HiveType(typeId: 5)
class FollowUp extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String contactName;

  @HiveField(3)
  final String? phoneNumber;

  @HiveField(4)
  final double amount;

  @HiveField(5)
  final DateTime dueDate;

  @HiveField(6)
  final FollowUpType type;

  @HiveField(7)
  final bool isCompleted;

  @HiveField(8)
  final String? note;

  @HiveField(9)
  final String bookId;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime? completedAt;

  @HiveField(12)
  final String? linkedTransactionId;

  FollowUp({
    required this.id,
    required this.title,
    required this.contactName,
    this.phoneNumber,
    required this.amount,
    required this.dueDate,
    required this.type,
    this.isCompleted = false,
    this.note,
    required this.bookId,
    required this.createdAt,
    this.completedAt,
    this.linkedTransactionId,
  });

  bool get isOverdue {
    if (isCompleted) return false;
    final now = DateTime.now();
    return dueDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isDueToday {
    if (isCompleted) return false;
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  FollowUp copyWith({
    String? id,
    String? title,
    String? contactName,
    String? phoneNumber,
    double? amount,
    DateTime? dueDate,
    FollowUpType? type,
    bool? isCompleted,
    String? note,
    String? bookId,
    DateTime? createdAt,
    DateTime? completedAt,
    String? linkedTransactionId,
  }) {
    return FollowUp(
      id: id ?? this.id,
      title: title ?? this.title,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
      bookId: bookId ?? this.bookId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'amount': amount,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'type': type.name,
      'isCompleted': isCompleted,
      'note': note,
      'bookId': bookId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'linkedTransactionId': linkedTransactionId,
    };
  }

  factory FollowUp.fromMap(Map<String, dynamic> map) {
    return FollowUp(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      contactName: map['contactName'] ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      amount: (map['amount'] ?? 0.0).toDouble(),
      dueDate: DateTime.fromMillisecondsSinceEpoch(
        map['dueDate'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      type: FollowUpType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FollowUpType.toReceive,
      ),
      isCompleted: map['isCompleted'] ?? false,
      note: map['note'] as String?,
      bookId: map['bookId'] ?? 'default-book',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      linkedTransactionId: map['linkedTransactionId'] as String?,
    );
  }
}
