import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../models/transaction.dart';
import '../screens/add_transaction_screen.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction>? transactions;
  const TransactionList({super.key, this.transactions});

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final displayTransactions = transactions ?? transactionService.transactions;
    final textTheme = Theme.of(context).textTheme;

    // Calculate before and after running balance for all transactions in chronological order (oldest to newest)
    final allTxs = transactionService.transactions;
    final sortedAll = List<Transaction>.from(allTxs)
      ..sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        final idA = int.tryParse(a.id) ?? 0;
        final idB = int.tryParse(b.id) ?? 0;
        return idA.compareTo(idB);
      });

    final Map<String, ({double before, double after})> txBalances = {};
    double running = 0.0;
    for (final tx in sortedAll) {
      final prev = running;
      if (tx.type == TransactionType.income) {
        running += tx.amount;
      } else {
        running -= tx.amount;
      }
      txBalances[tx.id] = (before: prev, after: running);
    }

    return displayTransactions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No transactions yet!', style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Tap the "Add Transaction" button to get started.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 80,
            ), // Padding for FAB
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: displayTransactions.length + 1,
            itemBuilder: (ctx, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions (${displayTransactions.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final tx = displayTransactions[index - 1];
              final bal = txBalances[tx.id];
              return _TransactionItem(
                key: ValueKey(tx.id),
                transaction: tx,
                settingsService: settingsService,
                beforeBalance: bal?.before,
                afterBalance: bal?.after,
              );
            },
          );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final SettingsService settingsService;
  final double? beforeBalance;
  final double? afterBalance;

  const _TransactionItem({
    super.key,
    required this.transaction,
    required this.settingsService,
    this.beforeBalance,
    this.afterBalance,
  });

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.online:
        return Icons.online_prediction;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.upi:
        return Icons.phone_android;
      case PaymentMethod.other:
        return Icons.payment;
    }
  }

  String _getPaymentMethodLabel(Transaction tx) {
    if (tx.paymentMethod == PaymentMethod.other &&
        tx.customPaymentMethod != null &&
        tx.customPaymentMethod!.isNotEmpty) {
      return tx.customPaymentMethod!;
    }
    switch (tx.paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.online:
        return 'Online';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final Color color = isIncome
        ? const Color(0xFF00D084) // Emerald
        : const Color(0xFFFF5F5F); // Rose-red

    final lastBackupTime = settingsService.lastBackupTimestamp;
    final txLastModified = transaction.updatedAt ?? int.tryParse(transaction.id) ?? 0;
    final isBackedUp = lastBackupTime > 0 && txLastModified <= lastBackupTime;
    final backupIcon = isBackedUp 
        ? const Icon(Icons.cloud_done_rounded, size: 14, color: Colors.green)
        : const Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.orange);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light 
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.grey.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) =>
                    AddTransactionScreen(transaction: transaction),
              ),
            );
          },
          onLongPress: () {
            _showDeleteConfirmation(context, transaction.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category, Payment Method & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D084).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                transaction.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF006D5B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getPaymentMethodIcon(transaction.paymentMethod),
                              size: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getPaymentMethodLabel(transaction),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        backupIcon,
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d').format(transaction.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Middle Row: Title & Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${settingsService.currencySymbol} ',
                              style: TextStyle(
                                fontSize: 12,
                                color: color.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: settingsService.formatCurrency(transaction.amount).replaceFirst(settingsService.currencySymbol, '').trim(),
                              style: TextStyle(
                                fontSize: 17,
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (beforeBalance != null && afterBalance != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade100
                          : Colors.grey.shade900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Before: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              settingsService.formatCurrency(beforeBalance!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: Colors.grey.shade400,
                        ),
                        Row(
                          children: [
                            Text(
                              'After: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              settingsService.formatCurrency(afterBalance!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(ctx).pop();

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                await Provider.of<TransactionService>(
                  context,
                  listen: false,
                ).deleteTransaction(id);

                // Close loading dialog
                if (context.mounted) Navigator.of(context).pop();

                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // Close loading dialog
                if (context.mounted) Navigator.of(context).pop();

                // Show error message
                if (context.mounted) {
                  final transactionService = Provider.of<TransactionService>(
                    context,
                    listen: false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error: ${transactionService.error ?? e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
