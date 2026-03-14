import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/financial_goals.dart';

class DatabaseService {
  static const String _transactionsBoxName = 'transactions';
  static const String _settingsBoxName = 'settings';
  static const String _usersBoxName = 'users';
  static const String _goalsBoxName = 'goals';

  static Box<Transaction>? _transactionsBox;
  static Box<Map>? _settingsBox;
  static Box<Map>? _usersBox;
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
      _transactionsBox = await Hive.openBox<Transaction>(_transactionsBoxName);
      _settingsBox = await Hive.openBox<Map>(_settingsBoxName);
      _usersBox = await Hive.openBox<Map>(_usersBoxName);
      _goalsBox = await Hive.openBox<FinancialGoals>(_goalsBoxName);

      // Initialize default settings if not exists
      await _initializeDefaultSettings();

      if (kDebugMode) {
        print('✅ Hive database initialized successfully');
        print('📊 Transactions: ${_transactionsBox!.length}');
        print('⚙️ Settings: ${_settingsBox!.length}');
        print('👥 Users: ${_usersBox!.length}');
        print('🎯 Goals: ${_goalsBox!.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Hive database: $e');
      }
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
      final settings = Map<String, dynamic>.from(_settingsBox!.get('preferences') ?? {});
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

  // User operations (simple local user management)
  static Future<void> createUser(String username, String password) async {
    try {
      final user = {
        'username': username,
        'password': password, // In production, hash this
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
      };
      await _usersBox!.put('current_user', user);
      if (kDebugMode) {
        print('✅ User created: $username');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating user: $e');
      }
      rethrow;
    }
  }

  static Future<bool> authenticateUser(String username, String password) async {
    try {
      final user = _usersBox!.get('current_user');
      if (user != null && 
          user['username'] == username && 
          user['password'] == password) {
        if (kDebugMode) {
          print('✅ User authenticated: $username');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error authenticating user: $e');
      }
      return false;
    }
  }

  static Map<String, dynamic>? getCurrentUser() {
    final user = _usersBox!.get('current_user');
    return user != null ? Map<String, dynamic>.from(user) : null;
  }

  static Future<void> signOut() async {
    try {
      await _usersBox!.delete('current_user');
      if (kDebugMode) {
        print('✅ User signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing out: $e');
      }
      rethrow;
    }
  }

  static bool isUserLoggedIn() {
    return _usersBox!.get('current_user') != null;
  }

  // Utility methods
  static Future<void> clearAllData() async {
    try {
      await _transactionsBox!.clear();
      await _settingsBox!.clear();
      await _usersBox!.clear();
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
      await _usersBox?.close();
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
      'users': _usersBox?.length ?? 0,
      'goals': _goalsBox?.length ?? 0,
    };
  }
}
