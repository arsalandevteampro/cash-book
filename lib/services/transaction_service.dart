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

  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  Map<String, ({double before, double after})> _txBalances = const {};
  List<String> _recentTitles = const [];

  UnmodifiableListView<Transaction> get transactions =>
      UnmodifiableListView(_transactions);
  List<Map<String, dynamic>> get books => List.unmodifiable(_books);
  String get currentBookId => _currentBookId;
  String get currentBookName {
    for (final book in _books) {
      if (book['id'] == _currentBookId) {
        return (book['name'] as String?) ?? 'My Book';
      }
    }
    return 'My Book';
  }

  /// Breadcrumb path for the current book, e.g. [Main, Business, Store 1]
  List<Map<String, dynamic>> get currentBookPath =>
      DatabaseService.getBookPath(_currentBookId);

  /// Root-level books only
  List<Map<String, dynamic>> get rootBooks => DatabaseService.getRootBooks();
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get balance => _balance;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  Map<String, ({double before, double after})> get txBalances => _txBalances;
  List<String> get recentTitles => _recentTitles;

  void _recalculateTotals() {
    double income = 0.0;
    double expense = 0.0;
    final seen = <String>{};
    final titles = <String>[];

    for (final tx in _transactions) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
      final t = tx.title.trim();
      if (t.isNotEmpty && titles.length < 100 && seen.add(t.toLowerCase())) {
        titles.add(t);
      }
    }
    _totalIncome = income;
    _totalExpense = expense;
    _balance = income - expense;
    _recentTitles = List.unmodifiable(titles);

    // Calculate before and after running balance for all transactions in chronological order (oldest to newest)
    final sortedAll = List<Transaction>.from(_transactions)
      ..sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        final idA = int.tryParse(a.id) ?? 0;
        final idB = int.tryParse(b.id) ?? 0;
        return idA.compareTo(idB);
      });

    final Map<String, ({double before, double after})> balances = {};
    double running = 0.0;
    for (final tx in sortedAll) {
      final prev = running;
      if (tx.type == TransactionType.income) {
        running += tx.amount;
      } else {
        running -= tx.amount;
      }
      balances[tx.id] = (before: prev, after: running);
    }
    _txBalances = balances;
  }

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
      _recalculateTotals();

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
      _recalculateTotals();
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
        _recalculateTotals();
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
      _recalculateTotals();
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

  /// Create a sub-book under [parentId].
  Future<void> createSubBook(String name, {required String parentId}) async {
    try {
      await DatabaseService.createSubBook(name, parentId: parentId);
      await initialize();
    } catch (e) {
      _setError('Failed to create sub-book: $e');
    }
  }

  /// Get direct children of [parentId].
  List<Map<String, dynamic>> getDirectSubBooks(String parentId) =>
      DatabaseService.getDirectSubBooks(parentId);

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
