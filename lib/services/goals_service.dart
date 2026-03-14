import 'package:flutter/foundation.dart';

import '../models/financial_goals.dart';
import 'database_service.dart';

class GoalsService with ChangeNotifier {
  FinancialGoals _goals = FinancialGoals.getDefault();
  bool _isLoading = false;
  String? _error;

  FinancialGoals get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize with Hive database
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Load goals from Hive
      final goals = DatabaseService.getFinancialGoals();
      if (goals != null) {
        _goals = goals;
      } else {
        // Create default goals if none exist
        _goals = FinancialGoals.getDefault();
        await DatabaseService.saveFinancialGoals(_goals);
      }
      
      _setError(null);
      if (kDebugMode) {
        print('✅ Loaded financial goals from Hive');
      }
    } catch (e) {
      _setError('Failed to initialize goals: $e');
      if (kDebugMode) {
        print('Error initializing goals: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateGoals({
    required double monthlyIncomeTarget,
    required double monthlyExpenseLimit,
    required double savingsTarget,
  }) async {
    try {
      final updatedGoals = _goals.copyWith(
        monthlyIncomeTarget: monthlyIncomeTarget,
        monthlyExpenseLimit: monthlyExpenseLimit,
        savingsTarget: savingsTarget,
        lastUpdated: DateTime.now(),
      );

      // Save to Hive database
      await DatabaseService.saveFinancialGoals(updatedGoals);
      
      // Update local goals
      _goals = updatedGoals;
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Financial goals updated');
      }
    } catch (e) {
      _setError('Failed to update goals: $e');
      if (kDebugMode) {
        print('Error updating goals: $e');
      }
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  // Refresh data from database
  Future<void> refresh() async {
    await initialize();
  }
}
