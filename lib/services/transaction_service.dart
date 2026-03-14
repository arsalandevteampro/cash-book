import 'package:flutter/foundation.dart';
import 'dart:collection';

import '../models/transaction.dart';
import 'database_service.dart';

class TransactionService with ChangeNotifier {
  final List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  UnmodifiableListView<Transaction> get transactions => UnmodifiableListView(_transactions);
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get balance => _transactions.fold(0.0, (sum, item) {
        return sum + (item.type == TransactionType.income ? item.amount : -item.amount);
      });

  double get totalIncome => _transactions
      .where((tx) => tx.type == TransactionType.income)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpense => _transactions
      .where((tx) => tx.type == TransactionType.expense)
      .fold(0.0, (sum, item) => sum + item.amount);

  // Initialize with Hive database
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Load transactions from Hive
      _transactions.clear();
      _transactions.addAll(DatabaseService.getAllTransactions());
      
      // Sort by date (newest first)
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      
      _setError(null);
      if (kDebugMode) {
        print('✅ Loaded ${_transactions.length} transactions from Hive');
      }
    } catch (e) {
      _setError('Failed to initialize: $e');
      if (kDebugMode) {
        print('Error initializing transactions: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addTransaction(String title, double amount, TransactionType type, DateTime date, PaymentMethod paymentMethod) async {
    try {
      final newTransaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        date: date,
        type: type,
        paymentMethod: paymentMethod,
      );

      // Save to Hive database
      await DatabaseService.addTransaction(newTransaction);
      
      // Update local list
      _transactions.insert(0, newTransaction); // Insert at beginning for newest first
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Transaction added: ${newTransaction.title}');
      }
    } catch (e) {
      _setError('Failed to add transaction: $e');
      if (kDebugMode) {
        print('Error adding transaction: $e');
      }
    }
  }

  Future<void> updateTransaction(Transaction updatedTransaction) async {
    try {
      // Update in Hive database
      await DatabaseService.updateTransaction(updatedTransaction);
      
      // Update local list
      final txIndex = _transactions.indexWhere((tx) => tx.id == updatedTransaction.id);
      if (txIndex >= 0) {
        _transactions[txIndex] = updatedTransaction;
        _setError(null);
        notifyListeners();
        
        if (kDebugMode) {
          print('✅ Transaction updated: ${updatedTransaction.title}');
        }
      }
    } catch (e) {
      _setError('Failed to update transaction: $e');
      if (kDebugMode) {
        print('Error updating transaction: $e');
      }
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      // Delete from Hive database
      await DatabaseService.deleteTransaction(id);
      
      // Update local list
      _transactions.removeWhere((tx) => tx.id == id);
      _setError(null);
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Transaction deleted: $id');
      }
    } catch (e) {
      _setError('Failed to delete transaction: $e');
      if (kDebugMode) {
        print('Error deleting transaction: $e');
      }
    }
  }

  // Get transactions by date range
  List<Transaction> getTransactionsByDateRange(DateTime start, DateTime end) {
    return _transactions.where((tx) {
      return tx.date.isAfter(start.subtract(const Duration(days: 1))) &&
             tx.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // Get transactions by type
  List<Transaction> getTransactionsByType(TransactionType type) {
    return _transactions.where((tx) => tx.type == type).toList();
  }

  // Get recent transactions (last N days)
  List<Transaction> getRecentTransactions(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _transactions.where((tx) => tx.date.isAfter(cutoffDate)).toList();
  }

  // Search transactions
  List<Transaction> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;
    
    final lowercaseQuery = query.toLowerCase();
    return _transactions.where((tx) {
      return tx.title.toLowerCase().contains(lowercaseQuery);
    }).toList();
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
