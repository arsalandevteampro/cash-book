import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/financial_goals.dart';

class DatabaseService {
  static const String _transactionsBoxName = 'transactions';
  static const String _settingsBoxName = 'settings';
  static const String _goalsBoxName = 'goals';

  static Box<Transaction>? _transactionsBox;
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

      // Open boxes
      try {
        _transactionsBox = await Hive.openBox<Transaction>(
          _transactionsBoxName,
        );
      } catch (e) {
        if (kDebugMode) {
          print(
            '⚠️ Error opening transactions box: $e. Clearing and re-opening...',
          );
        }
        await Hive.deleteBoxFromDisk(_transactionsBoxName);
        _transactionsBox = await Hive.openBox<Transaction>(
          _transactionsBoxName,
        );
      }

      _settingsBox = await Hive.openBox<Map>(_settingsBoxName);
      _goalsBox = await Hive.openBox<FinancialGoals>(_goalsBoxName);

      // Initialize default settings if not exists
      await _initializeDefaultSettings();

      if (kDebugMode) {
        print('✅ Hive database initialized successfully');
        print('📊 Transactions: ${_transactionsBox!.length}');
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
    if (_settingsBox!.isEmpty) {
      await _settingsBox!.put('preferences', {
        'currency': 'Rs',
        'theme': 'system',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (kDebugMode) {
        print('✅ Default settings initialized');
      }
    }
  }

  // Transaction operations
  static Future<void> addTransaction(Transaction transaction) async {
    try {
      await _transactionsBox!.put(transaction.id, transaction);
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
      await _transactionsBox!.put(transaction.id, transaction);
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
      await _transactionsBox!.delete(id);
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
    return _transactionsBox!.values.toList();
  }

  static Transaction? getTransaction(String id) {
    return _transactionsBox!.get(id);
  }

  static Stream<List<Transaction>> watchTransactions() {
    return _transactionsBox!.watch().map((_) => getAllTransactions());
  }

  // Settings operations
  static Future<void> updateSetting(String key, dynamic value) async {
    try {
      final settings = Map<String, dynamic>.from(
        _settingsBox!.get('preferences') ?? {},
      );
      settings[key] = value;
      settings['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      await _settingsBox!.put('preferences', settings);
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
    final settings = _settingsBox!.get('preferences');
    return settings?[key] as T?;
  }

  static Map<String, dynamic> getAllSettings() {
    return Map<String, dynamic>.from(_settingsBox!.get('preferences') ?? {});
  }

  static Stream<Map<String, dynamic>> watchSettings() {
    return _settingsBox!.watch().map((_) => getAllSettings());
  }

  // Custom Lists operations
  static List<String> getCustomCategories() {
    final settings = _settingsBox!.get('preferences');
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
    final settings = _settingsBox!.get('preferences');
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
    final settings = _settingsBox!.get('preferences');
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
      await _goalsBox!.put('current_goals', goals);
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
    return _goalsBox!.get('current_goals');
  }

  static Stream<FinancialGoals?> watchFinancialGoals() {
    return _goalsBox!.watch().map((_) => getFinancialGoals());
  }

  static Future<void> clearAllData() async {
    try {
      await _transactionsBox!.clear();
      await _settingsBox!.clear();
      await _goalsBox!.clear();
      await _initializeDefaultSettings();
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
      await _transactionsBox?.close();
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
      'transactions': _transactionsBox?.length ?? 0,
      'settings': _settingsBox?.length ?? 0,
      'goals': _goalsBox?.length ?? 0,
    };
  }

  // Export all data for backup
  static Map<String, dynamic> exportData() {
    final transactions = _transactionsBox!.values
        .map((t) => t.toMap())
        .toList();
    final settings = Map<String, dynamic>.from(
      _settingsBox!.get('preferences') ?? {},
    );
    final goals = _goalsBox!.get('current_goals')?.toMap();

    return {'transactions': transactions, 'settings': settings, 'goals': goals};
  }

  // Import data from backup
  static Future<void> importData(Map<String, dynamic> data) async {
    try {
      await clearAllData();

      if (data.containsKey('transactions') && data['transactions'] != null) {
        final List txList = data['transactions'];
        for (var txMap in txList) {
          final tx = Transaction.fromMap(Map<String, dynamic>.from(txMap));
          await _transactionsBox!.put(tx.id, tx);
        }
      }

      if (data.containsKey('settings') && data['settings'] != null) {
        await _settingsBox!.put(
          'preferences',
          Map<String, dynamic>.from(data['settings']),
        );
      }

      if (data.containsKey('goals') && data['goals'] != null) {
        final goals = FinancialGoals.fromMap(
          Map<String, dynamic>.from(data['goals']),
        );
        await saveFinancialGoals(goals);
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
