import 'package:hive/hive.dart';

part 'financial_goals.g.dart';

@HiveType(typeId: 3)
class FinancialGoals extends HiveObject {
  @HiveField(0)
  double monthlyIncomeTarget;
  
  @HiveField(1)
  double monthlyExpenseLimit;
  
  @HiveField(2)
  double savingsTarget;
  
  @HiveField(3)
  DateTime lastUpdated;

  FinancialGoals({
    required this.monthlyIncomeTarget,
    required this.monthlyExpenseLimit,
    required this.savingsTarget,
    required this.lastUpdated,
  });

  // Default goals
  static FinancialGoals getDefault() {
    return FinancialGoals(
      monthlyIncomeTarget: 50000.0,
      monthlyExpenseLimit: 30000.0,
      savingsTarget: 20000.0,
      lastUpdated: DateTime.now(),
    );
  }

  // Create a copy with updated fields
  FinancialGoals copyWith({
    double? monthlyIncomeTarget,
    double? monthlyExpenseLimit,
    double? savingsTarget,
    DateTime? lastUpdated,
  }) {
    return FinancialGoals(
      monthlyIncomeTarget: monthlyIncomeTarget ?? this.monthlyIncomeTarget,
      monthlyExpenseLimit: monthlyExpenseLimit ?? this.monthlyExpenseLimit,
      savingsTarget: savingsTarget ?? this.savingsTarget,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'FinancialGoals(monthlyIncomeTarget: $monthlyIncomeTarget, monthlyExpenseLimit: $monthlyExpenseLimit, savingsTarget: $savingsTarget, lastUpdated: $lastUpdated)';
  }
}
