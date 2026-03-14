import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
}

@HiveType(typeId: 2)
enum PaymentMethod {
  @HiveField(0)
  cash,
  @HiveField(1)
  online,
  @HiveField(2)
  card,
  @HiveField(3)
  bankTransfer,
  @HiveField(4)
  upi,
  @HiveField(5)
  other,
}

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final double amount;
  
  @HiveField(3)
  final DateTime date;
  
  @HiveField(4)
  final TransactionType type;
  
  @HiveField(5)
  final PaymentMethod paymentMethod;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.paymentMethod,
  });

  // Convert Transaction to Map for compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'type': type.name,
      'paymentMethod': paymentMethod.name,
    };
  }

  // Create Transaction from Map for compatibility
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
    );
  }

  // Create a copy of Transaction with updated fields
  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    PaymentMethod? paymentMethod,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, title: $title, amount: $amount, date: $date, type: $type, paymentMethod: $paymentMethod)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.title == title &&
        other.amount == amount &&
        other.date == date &&
        other.type == type &&
        other.paymentMethod == paymentMethod;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        amount.hashCode ^
        date.hashCode ^
        type.hashCode ^
        paymentMethod.hashCode;
  }
}
