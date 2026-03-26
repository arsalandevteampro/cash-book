import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/financial_goals.dart';

class DatabaseService {
  static const String _transactionsBoxPrefix = 'transactions_';
  static const String _settingsBoxName = 'settings';
  static const String _goalsBoxName = 'goals';
  static const String _preferencesKey = 'preferences';
  static const String _booksKey = 'books';
  static const String _currentBookIdKey = 'currentBookId';
  static const String _defaultBookId = 'default-book';
  static const String _defaultBookName = 'My Book';

  static final Map<String, Box<Transaction>> _transactionsBoxes = {};
  static Box<Transaction>? _activeTransactionsBox;
  static Box<Map>? _settingsBox;
  static Box<FinancialGoals>? _goalsBox;

  // Initialize Hive and open boxes
  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🗄️ Initializing Hive database...');
      }

      await Hive.initFlutter();

      // Register adapters
      Hive.registerAdapter(TransactionAdapter());
      Hive.registerAdapter(TransactionTypeAdapter());
      Hive.registerAdapter(PaymentMethodAdapter());
      Hive.registerAdapter(FinancialGoalsAdapter());

      // Open main boxes
      _settingsBox = await Hive.openBox<Map>(_settingsBoxName);
      _goalsBox = await Hive.openBox<FinancialGoals>(_goalsBoxName);

      // Initialize default settings if not exists
      await _initializeDefaultSettings();
      await _ensureTransactionsBoxOpen(getCurrentBookId());

      if (kDebugMode) {
        print('✅ Hive database initialized successfully');
        print('📊 Transactions: ${_activeTransactionsBox!.length}');
        print('⚙️ Settings: ${_settingsBox!.length}');
        print('🎯 Goals: ${_goalsBox!.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Hive database: $e');
      }
      // If still error, just try to continue without crash if possible, or rethrow
      rethrow;
    }
  }

  // Initialize default settings
  static Future<void> _initializeDefaultSettings() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final settings = Map<String, dynamic>.from(
      _settingsBox!.get(_preferencesKey) ?? {},
    );

    settings.putIfAbsent('currency', () => 'Rs');
    settings.putIfAbsent('theme', () => 'system');
    settings.putIfAbsent('createdAt', () => now);
    settings.putIfAbsent(_booksKey, () => [
      {'id': _defaultBookId, 'name': _defaultBookName, 'createdAt': now},
    ]);
    settings.putIfAbsent(_currentBookIdKey, () => _defaultBookId);

    await _settingsBox!.put(_preferencesKey, settings);
    if (kDebugMode) {
      print('✅ Default settings initialized');
    }
  }

  static Future<void> _ensureTransactionsBoxOpen(String bookId) async {
    if (_transactionsBoxes.containsKey(bookId)) {
      _activeTransactionsBox = _transactionsBoxes[bookId];
      return;
    }

    final boxName = '$_transactionsBoxPrefix$bookId';
    try {
      final box = await Hive.openBox<Transaction>(boxName);
      _transactionsBoxes[bookId] = box;
      _activeTransactionsBox = box;
    } catch (e) {
      if (kDebugMode) {
        print(
          '⚠️ Error opening transactions box "$boxName": $e. Clearing and re-opening...',
        );
      }
      await Hive.deleteBoxFromDisk(boxName);
      final box = await Hive.openBox<Transaction>(boxName);
      _transactionsBoxes[bookId] = box;
      _activeTransactionsBox = box;
    }
  }

  static String getCurrentBookId() {
    final settings = Map<String, dynamic>.from(
      _settingsBox?.get(_preferencesKey) ?? {},
    );
    return settings[_currentBookIdKey] as String? ?? _defaultBookId;
  }

  static List<Map<String, dynamic>> getAllBooks() {
    final settings = Map<String, dynamic>.from(
      _settingsBox?.get(_preferencesKey) ?? {},
    );
    final rawBooks = settings[_booksKey];
    if (rawBooks is! List) {
      return [
        {
          'id': _defaultBookId,
          'name': _defaultBookName,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
      ];
    }

    return rawBooks
        .whereType<Map>()
        .map((book) => Map<String, dynamic>.from(book))
        .toList();
  }

  static Future<void> createBook(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final books = getAllBooks();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    books.add({
      'id': id,
      'name': cleanName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    await updateSetting(_booksKey, books);
    await switchBook(id);
  }

  static Future<void> renameBook(String bookId, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final books = getAllBooks();
    final index = books.indexWhere((book) => book['id'] == bookId);
    if (index < 0) return;
    books[index]['name'] = cleanName;
    await updateSetting(_booksKey, books);
  }

  static Future<void> deleteBook(String bookId) async {
    final books = getAllBooks();
    if (books.length <= 1) {
      throw Exception('At least one book is required.');
    }
    final index = books.indexWhere((book) => book['id'] == bookId);
    if (index < 0) return;

    final isCurrent = getCurrentBookId() == bookId;
    books.removeAt(index);
    await updateSetting(_booksKey, books);

    if (isCurrent) {
      final fallbackBookId = books.first['id'] as String? ?? _defaultBookId;
      await switchBook(fallbackBookId);
    }

    final box = _transactionsBoxes.remove(bookId);
    await box?.close();
    await Hive.deleteBoxFromDisk('$_transactionsBoxPrefix$bookId');
    await _goalsBox!.delete('current_goals_$bookId');
  }

  static Future<void> switchBook(String bookId) async {
    final books = getAllBooks();
    final exists = books.any((book) => book['id'] == bookId);
    if (!exists) return;

    await updateSetting(_currentBookIdKey, bookId);
    await _ensureTransactionsBoxOpen(bookId);
  }

  // Transaction operations
  static Future<void> addTransaction(Transaction transaction) async {
    try {
      await _activeTransactionsBox!.put(transaction.id, transaction);
      if (kDebugMode) {
        print('✅ Transaction added: ${transaction.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding transaction: $e');
      }
      rethrow;
    }
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    try {
      await _activeTransactionsBox!.put(transaction.id, transaction);
      if (kDebugMode) {
        print('✅ Transaction updated: ${transaction.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating transaction: $e');
      }
      rethrow;
    }
  }

  static Future<void> deleteTransaction(String id) async {
    try {
      await _activeTransactionsBox!.delete(id);
      if (kDebugMode) {
        print('✅ Transaction deleted: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting transaction: $e');
      }
      rethrow;
    }
  }

  static List<Transaction> getAllTransactions() {
    return _activeTransactionsBox!.values.toList();
  }

  static Transaction? getTransaction(String id) {
    return _activeTransactionsBox!.get(id);
  }

  static Stream<List<Transaction>> watchTransactions() {
    return _activeTransactionsBox!.watch().map((_) => getAllTransactions());
  }

  // Settings operations
  static Future<void> updateSetting(String key, dynamic value) async {
    try {
      final settings = Map<String, dynamic>.from(
        _settingsBox!.get(_preferencesKey) ?? {},
      );
      settings[key] = value;
      settings['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      await _settingsBox!.put(_preferencesKey, settings);
      if (kDebugMode) {
        print('✅ Setting updated: $key = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating setting: $e');
      }
      rethrow;
    }
  }

  static T? getSetting<T>(String key) {
    final settings = _settingsBox!.get(_preferencesKey);
    return settings?[key] as T?;
  }

  static Map<String, dynamic> getAllSettings() {
    return Map<String, dynamic>.from(_settingsBox!.get(_preferencesKey) ?? {});
  }

  static Stream<Map<String, dynamic>> watchSettings() {
    return _settingsBox!.watch().map((_) => getAllSettings());
  }

  // Custom Lists operations
  static List<String> getCustomCategories() {
    final settings = _settingsBox!.get(_preferencesKey);
    return List<String>.from(settings?['customCategories'] ?? []);
  }

  static Future<void> addCustomCategory(String category) async {
    final categories = getCustomCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      await updateSetting('customCategories', categories);
    }
  }

  static List<String> getCustomPaymentMethods() {
    final settings = _settingsBox!.get(_preferencesKey);
    return List<String>.from(settings?['customPaymentMethods'] ?? []);
  }

  static Future<void> addCustomPaymentMethod(String paymentMethod) async {
    final methods = getCustomPaymentMethods();
    if (!methods.contains(paymentMethod)) {
      methods.add(paymentMethod);
      await updateSetting('customPaymentMethods', methods);
    }
  }

  static List<Map<String, String>> getCustomCurrencies() {
    final settings = _settingsBox!.get(_preferencesKey);
    if (settings == null || settings['customCurrencies'] == null) {
      return [];
    }
    try {
      final List<dynamic> custom = settings['customCurrencies'];
      return custom
          .where((e) => e != null && e is Map)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error loading custom currencies: $e');
      return [];
    }
  }

  static Future<void> addCustomCurrency(Map<String, String> currency) async {
    final currencies = getCustomCurrencies();
    // Check if already exists by symbol
    if (!currencies.any((c) => c['symbol'] == currency['symbol'])) {
      currencies.add(currency);
      await updateSetting('customCurrencies', currencies);
    }
  }

  // Financial Goals operations
  static Future<void> saveFinancialGoals(FinancialGoals goals) async {
    try {
      await _goalsBox!.put('current_goals_${getCurrentBookId()}', goals);
      if (kDebugMode) {
        print('✅ Financial goals saved');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving financial goals: $e');
      }
      rethrow;
    }
  }

  static FinancialGoals? getFinancialGoals() {
    return _goalsBox!.get('current_goals_${getCurrentBookId()}');
  }

  static Stream<FinancialGoals?> watchFinancialGoals() {
    return _goalsBox!.watch().map((_) => getFinancialGoals());
  }

  static Future<void> clearAllData() async {
    try {
      for (final box in _transactionsBoxes.values) {
        await box.clear();
      }
      await _settingsBox!.clear();
      await _goalsBox!.clear();
      await _initializeDefaultSettings();
      await _ensureTransactionsBoxOpen(getCurrentBookId());
      if (kDebugMode) {
        print('✅ All data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing data: $e');
      }
      rethrow;
    }
  }

  static Future<void> close() async {
    try {
      for (final box in _transactionsBoxes.values) {
        await box.close();
      }
      _transactionsBoxes.clear();
      _activeTransactionsBox = null;
      await _settingsBox?.close();
      await _goalsBox?.close();
      if (kDebugMode) {
        print('✅ Database closed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error closing database: $e');
      }
    }
  }

  // Get database statistics
  static Map<String, int> getStats() {
    return {
      'transactions': _activeTransactionsBox?.length ?? 0,
      'settings': _settingsBox?.length ?? 0,
      'goals': _goalsBox?.length ?? 0,
    };
  }

  // Export all data for backup
  static Future<Map<String, dynamic>> exportDataAsync() async {
    final books = getAllBooks();
    final Map<String, List<Map<String, dynamic>>> transactionsByBook = {};
    for (final book in books) {
      final bookId = book['id'] as String;
      final boxName = '$_transactionsBoxPrefix$bookId';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<Transaction>(boxName);
        _transactionsBoxes[bookId] = Hive.box<Transaction>(boxName);
      }
      final box = _transactionsBoxes[bookId];
      final items = (box?.values.toList() ?? []).map((t) => t.toMap()).toList();
      transactionsByBook[bookId] = items;
    }
    final settings = Map<String, dynamic>.from(
      _settingsBox!.get(_preferencesKey) ?? {},
    );
    final Map<String, Map<String, dynamic>> goalsByBook = {};
    for (final book in books) {
      final bookId = book['id'] as String;
      final goals = _goalsBox!.get('current_goals_$bookId');
      if (goals != null) {
        goalsByBook[bookId] = goals.toMap();
      }
    }

    return {
      'transactionsByBook': transactionsByBook,
      'settings': settings,
      'goalsByBook': goalsByBook,
    };
  }

  // Import data from backup
  static Future<void> importData(Map<String, dynamic> data) async {
    try {
      await clearAllData();

      if (data.containsKey('settings') && data['settings'] != null) {
        await _settingsBox!.put(
          _preferencesKey,
          Map<String, dynamic>.from(data['settings']),
        );
      }
      await _ensureTransactionsBoxOpen(getCurrentBookId());

      if (data.containsKey('transactionsByBook') &&
          data['transactionsByBook'] != null) {
        final Map txMapByBook = Map<String, dynamic>.from(
          data['transactionsByBook'],
        );
        for (final entry in txMapByBook.entries) {
          final bookId = entry.key.toString();
          await _ensureTransactionsBoxOpen(bookId);
          final rawList = entry.value as List;
          for (final txMap in rawList) {
            final tx = Transaction.fromMap(Map<String, dynamic>.from(txMap));
            await _transactionsBoxes[bookId]!.put(tx.id, tx);
          }
        }
      }
      if (data.containsKey('transactions') && data['transactions'] != null) {
        final List txList = data['transactions'];
        final currentBookId = getCurrentBookId();
        await _ensureTransactionsBoxOpen(currentBookId);
        for (final txMap in txList) {
          final tx = Transaction.fromMap(Map<String, dynamic>.from(txMap));
          await _transactionsBoxes[currentBookId]!.put(tx.id, tx);
        }
      }

      if (data.containsKey('goalsByBook') && data['goalsByBook'] != null) {
        final Map rawGoals = Map<String, dynamic>.from(data['goalsByBook']);
        for (final entry in rawGoals.entries) {
          final goals = FinancialGoals.fromMap(
            Map<String, dynamic>.from(entry.value),
          );
          await _goalsBox!.put('current_goals_${entry.key}', goals);
        }
      }
      if (data.containsKey('goals') && data['goals'] != null) {
        final goals = FinancialGoals.fromMap(
          Map<String, dynamic>.from(data['goals']),
        );
        await _goalsBox!.put('current_goals_${getCurrentBookId()}', goals);
      }

      if (kDebugMode) {
        print('✅ Data imported successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error importing data: $e');
      }
      rethrow;
    }
  }
}
