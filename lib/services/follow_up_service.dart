import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/follow_up.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'transaction_service.dart';
import 'notification_service.dart';

class FollowUpService with ChangeNotifier {
  List<FollowUp> _followUps = [];
  bool _isLoading = false;
  static const _uuid = Uuid();

  int _pendingCount = 0;
  int _completedCount = 0;
  int _overdueCount = 0;
  int _todayCount = 0;
  int _toReceivePendingCount = 0;
  int _toPayPendingCount = 0;
  double _totalReceivablePending = 0.0;
  double _totalPayablePending = 0.0;

  List<FollowUp> get followUps => List.unmodifiable(_followUps);
  bool get isLoading => _isLoading;

  int get pendingCount => _pendingCount;
  int get completedCount => _completedCount;
  int get overdueCount => _overdueCount;
  int get todayCount => _todayCount;
  int get toReceivePendingCount => _toReceivePendingCount;
  int get toPayPendingCount => _toPayPendingCount;
  double get totalReceivablePending => _totalReceivablePending;
  double get totalPayablePending => _totalPayablePending;
  int get urgentCount => _overdueCount + _todayCount;

  List<FollowUp> get pendingFollowUps =>
      _followUps.where((f) => !f.isCompleted).toList();

  List<FollowUp> get completedFollowUps =>
      _followUps.where((f) => f.isCompleted).toList();

  List<FollowUp> get overdueFollowUps =>
      _followUps.where((f) => f.isOverdue).toList();

  List<FollowUp> get todayFollowUps =>
      _followUps.where((f) => f.isDueToday).toList();

  List<FollowUp> get upcomingFollowUps =>
      _followUps.where((f) => !f.isCompleted && !f.isOverdue && !f.isDueToday).toList();

  FollowUpService() {
    loadFollowUps();
  }

  void _recalculateCounts() {
    int pending = 0;
    int completed = 0;
    int overdue = 0;
    int today = 0;
    int toReceive = 0;
    int toPay = 0;
    double recPending = 0.0;
    double payPending = 0.0;

    for (final f in _followUps) {
      if (f.isCompleted) {
        completed++;
      } else {
        pending++;
        if (f.isOverdue) overdue++;
        if (f.isDueToday) today++;
        if (f.type == FollowUpType.toReceive) {
          toReceive++;
          recPending += f.amount;
        } else if (f.type == FollowUpType.toPay) {
          toPay++;
          payPending += f.amount;
        }
      }
    }

    _pendingCount = pending;
    _completedCount = completed;
    _overdueCount = overdue;
    _todayCount = today;
    _toReceivePendingCount = toReceive;
    _toPayPendingCount = toPay;
    _totalReceivablePending = recPending;
    _totalPayablePending = payPending;
  }

  Future<void> loadFollowUps() async {
    _isLoading = true;
    notifyListeners();

    try {
      _followUps = DatabaseService.getFollowUps();
      _recalculateCounts();
      NotificationService.instance.rescheduleAll(_followUps);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading follow-ups: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadFollowUps();
  }

  Future<void> addFollowUp({
    required String title,
    required String contactName,
    String? phoneNumber,
    required double amount,
    required DateTime dueDate,
    required FollowUpType type,
    String? note,
  }) async {
    final newFollowUp = FollowUp(
      id: _uuid.v4(),
      title: title.trim(),
      contactName: contactName.trim(),
      phoneNumber: phoneNumber?.trim().isEmpty == true ? null : phoneNumber?.trim(),
      amount: amount,
      dueDate: dueDate,
      type: type,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      bookId: DatabaseService.getCurrentBookId(),
      createdAt: DateTime.now(),
    );

    await DatabaseService.saveFollowUp(newFollowUp);
    await NotificationService.instance.scheduleFollowUpNotification(newFollowUp);
    await loadFollowUps();
  }

  Future<void> updateFollowUp(FollowUp followUp) async {
    await DatabaseService.saveFollowUp(followUp);
    if (followUp.isCompleted) {
      await NotificationService.instance.cancelFollowUpNotification(followUp.id);
    } else {
      await NotificationService.instance.scheduleFollowUpNotification(followUp);
    }
    await loadFollowUps();
  }

  Future<void> deleteFollowUp(String id) async {
    await NotificationService.instance.cancelFollowUpNotification(id);
    await DatabaseService.deleteFollowUp(id);
    await loadFollowUps();
  }

  Future<void> markCompleted(
    String id, {
    bool createTransaction = false,
    String? targetBookId,
    TransactionService? transactionService,
  }) async {
    final index = _followUps.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final item = _followUps[index];
    String? linkedTxId;

    if (createTransaction && transactionService != null) {
      final txType = item.type == FollowUpType.toReceive
          ? TransactionType.income
          : TransactionType.expense;

      final description = '${item.contactName} - ${item.title}'.trim();
      final bookIdToUse = targetBookId ?? item.bookId;

      if (bookIdToUse == DatabaseService.getCurrentBookId()) {
        await transactionService.addTransaction(
          description,
          item.amount,
          txType,
          DateTime.now(),
          PaymentMethod.cash,
          item.type == FollowUpType.toReceive ? 'Recovery' : 'Payment',
          customPaymentMethod: 'Follow-up Settled',
        );
      } else {
        final txId = DateTime.now().millisecondsSinceEpoch.toString();
        final newTx = Transaction(
          id: txId,
          title: description,
          amount: item.amount,
          date: DateTime.now(),
          type: txType,
          paymentMethod: PaymentMethod.cash,
          category: item.type == FollowUpType.toReceive ? 'Recovery' : 'Payment',
          customPaymentMethod: 'Follow-up Settled',
        );
        await DatabaseService.addTransactionToBook(bookIdToUse, newTx);
        linkedTxId = txId;
      }
    }

    final updated = item.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
      linkedTransactionId: linkedTxId ?? item.linkedTransactionId,
    );

    await DatabaseService.saveFollowUp(updated);
    await NotificationService.instance.cancelFollowUpNotification(id);
    await loadFollowUps();
  }

  Future<void> markPending(String id) async {
    final index = _followUps.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final item = _followUps[index];
    final updated = item.copyWith(
      isCompleted: false,
      completedAt: null,
    );

    await DatabaseService.saveFollowUp(updated);
    await NotificationService.instance.scheduleFollowUpNotification(updated);
    await loadFollowUps();
  }

  Future<void> snoozeFollowUp(String id, Duration duration) async {
    final index = _followUps.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final item = _followUps[index];
    final baseDate = item.dueDate.isBefore(DateTime.now())
        ? DateTime.now()
        : item.dueDate;
    final newDueDate = baseDate.add(duration);

    final updated = item.copyWith(
      dueDate: newDueDate,
      isCompleted: false,
      completedAt: null,
    );

    await DatabaseService.saveFollowUp(updated);
    await NotificationService.instance.scheduleFollowUpNotification(updated);
    await loadFollowUps();
  }
}
