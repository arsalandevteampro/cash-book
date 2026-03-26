import 'package:flutter/foundation.dart';
import 'dart:collection';

import '../models/transaction.dart';
import 'database_service.dart';

class TransactionService with ChangeNotifier {
  final List<Transaction> _transactions = [];
  List<Map<String, dynamic>> _books = [];
  String _currentBookId = '';
  bool _isLoading = false;
  String? _error;

  UnmodifiableListView<Transaction> get transactions =>
      UnmodifiableListView(_transactions);
  List<Map<String, dynamic>> get books => List.unmodifiable(_books);
  String get currentBookId => _currentBookId;
  String get currentBookName {
    final book = _books.where((b) => b['id'] == _currentBookId).toList();
    if (book.isEmpty) return 'My Book';
    return (book.first['name'] as String?) ?? 'My Book';
  }
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get balance => _transactions.fold(0.0, (sum, item) {
    return sum +
        (item.type == TransactionType.income ? item.amount : -item.amount);
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
      _books = DatabaseService.getAllBooks();
      _currentBookId = DatabaseService.getCurrentBookId();

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

  Future<void> addTransaction(
    String title,
    double amount,
    TransactionType type,
    DateTime date,
    PaymentMethod paymentMethod,
    String category, {
    String? customPaymentMethod,
  }) async {
    try {
      final newTransaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        date: date,
        type: type,
        paymentMethod: paymentMethod,
        category: category,
        customPaymentMethod: customPaymentMethod,
      );

      // Save to Hive database
      await DatabaseService.addTransaction(newTransaction);

      // Update local list
      _transactions.insert(
        0,
        newTransaction,
      ); // Insert at beginning for newest first
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
      final txToSave = updatedTransaction.copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Update in Hive database
      await DatabaseService.updateTransaction(txToSave);

      // Update local list
      final txIndex = _transactions.indexWhere(
        (tx) => tx.id == txToSave.id,
      );
      if (txIndex >= 0) {
        _transactions[txIndex] = txToSave;
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

  Future<void> createBook(String name) async {
    try {
      await DatabaseService.createBook(name);
      await initialize();
    } catch (e) {
      _setError('Failed to create book: $e');
    }
  }

  Future<void> switchBook(String bookId) async {
    try {
      await DatabaseService.switchBook(bookId);
      await initialize();
    } catch (e) {
      _setError('Failed to switch book: $e');
    }
  }

  Future<void> renameBook(String bookId, String name) async {
    try {
      await DatabaseService.renameBook(bookId, name);
      await initialize();
    } catch (e) {
      _setError('Failed to rename book: $e');
    }
  }

  Future<void> deleteBook(String bookId) async {
    try {
      await DatabaseService.deleteBook(bookId);
      await initialize();
    } catch (e) {
      _setError('Failed to delete book: $e');
    }
  }
}
