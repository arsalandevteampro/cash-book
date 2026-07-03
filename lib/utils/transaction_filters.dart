import '../models/transaction.dart';

/// Shared helpers for filtering transactions by date and payment method.
class TransactionFilters {
  TransactionFilters._();

  static const List<String> presetPeriods = [
    'Today',
    'This Week',
    'This Month',
    'Last 3 Months',
    'This Year',
  ];

  static String paymentLabel(Transaction transaction) {
    if (transaction.paymentMethod == PaymentMethod.other &&
        transaction.customPaymentMethod != null) {
      return transaction.customPaymentMethod!;
    }

    final name = transaction.paymentMethod.name;
    return name[0].toUpperCase() +
        name.substring(1).replaceAll(RegExp(r'(?=[A-Z])'), ' ');
  }

  static bool hasActiveDateFilter(String? selectedPeriod) {
    return selectedPeriod != null && selectedPeriod != 'All Time';
  }

  static bool matchesDate({
    required DateTime transactionDate,
    required String? selectedPeriod,
    DateTime? customStartDate,
    DateTime? customEndDate,
    DateTime? singleDate,
    DateTime? now,
  }) {
    if (!hasActiveDateFilter(selectedPeriod)) {
      return true;
    }

    final range = _resolveDateRange(
      selectedPeriod: selectedPeriod!,
      customStartDate: customStartDate,
      customEndDate: customEndDate,
      singleDate: singleDate,
      now: now,
    );

    final day = DateTime(
      transactionDate.year,
      transactionDate.month,
      transactionDate.day,
    );

    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  static ({DateTime start, DateTime end}) _resolveDateRange({
    required String selectedPeriod,
    DateTime? customStartDate,
    DateTime? customEndDate,
    DateTime? singleDate,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    switch (selectedPeriod) {
      case 'Today':
        startDate = DateTime(current.year, current.month, current.day);
        endDate = DateTime(current.year, current.month, current.day);
        break;
      case 'This Week':
        startDate = current.subtract(Duration(days: current.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(current.year, current.month, current.day);
        break;
      case 'This Month':
        startDate = DateTime(current.year, current.month, 1);
        endDate = DateTime(current.year, current.month, current.day);
        break;
      case 'Last 3 Months':
        startDate = DateTime(current.year, current.month - 3, current.day);
        endDate = DateTime(current.year, current.month, current.day);
        break;
      case 'This Year':
        startDate = DateTime(current.year, 1, 1);
        endDate = DateTime(current.year, current.month, current.day);
        break;
      case 'Single Date':
        final picked = singleDate ?? current;
        startDate = DateTime(picked.year, picked.month, picked.day);
        endDate = startDate;
        break;
      case 'Custom':
        startDate = customStartDate ?? DateTime(current.year, current.month, 1);
        final customEnd = customEndDate ?? current;
        endDate = DateTime(customEnd.year, customEnd.month, customEnd.day);
        break;
      default:
        startDate = DateTime(current.year, current.month, 1);
        endDate = DateTime(current.year, current.month, current.day);
    }

    return (start: startDate, end: endDate);
  }
}
