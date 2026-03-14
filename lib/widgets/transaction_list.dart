import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../models/transaction.dart';
import '../screens/add_transaction_screen.dart';

class TransactionList extends StatelessWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final transactions = transactionService.transactions;
    final textTheme = Theme.of(context).textTheme;

    return transactions.isEmpty
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
            padding: const EdgeInsets.only(top: 8, bottom: 80), // Padding for FAB
            itemCount: transactions.length,
            itemBuilder: (ctx, index) {
              final tx = transactions[index];
              return _TransactionItem(transaction: tx, settingsService: settingsService);
            },
          );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final SettingsService settingsService;

  const _TransactionItem({
    required this.transaction,
    required this.settingsService,
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
        return Icons.more_horiz;
    }
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
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
    final Color color = isIncome ? Colors.green.shade600 : Colors.red.shade600;
    final IconData icon = isIncome ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(26), // 10% opacity
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          transaction.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM d, yyyy').format(transaction.date)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(_getPaymentMethodIcon(transaction.paymentMethod), size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _getPaymentMethodLabel(transaction.paymentMethod),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'} ${settingsService.currencySymbol} ${transaction.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => AddTransactionScreen(transaction: transaction),
            ),
          );
        },
        onLongPress: () {
          _showDeleteConfirmation(context, transaction.id);
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
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
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await Provider.of<TransactionService>(context, listen: false).deleteTransaction(id);
                
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
                  final transactionService = Provider.of<TransactionService>(context, listen: false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${transactionService.error ?? e.toString()}'),
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
