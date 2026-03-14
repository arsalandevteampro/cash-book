import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../widgets/transaction_list.dart';
import 'add_transaction_screen.dart';
import 'settings_screen.dart';
import 'analysis_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AnalysisScreen()),
              );
            },
            tooltip: 'Analysis',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildBalanceCard(context, transactionService, settingsService, colorScheme),
          const Expanded(child: TransactionList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddTransactionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBalanceCard(BuildContext context, TransactionService transactionService, SettingsService settingsService, ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(77), // 30% opacity
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Balance',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '${settingsService.currencySymbol} ${transactionService.balance.toStringAsFixed(2)}',
            style: textTheme.displayMedium?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeExpenseItem(
                'Income',
                transactionService.totalIncome,
                settingsService.currencySymbol,
                Colors.green.shade300,
                Icons.arrow_upward,
                textTheme,
                colorScheme,
              ),
              _buildIncomeExpenseItem(
                'Expense',
                transactionService.totalExpense,
                settingsService.currencySymbol,
                Colors.red.shade300,
                Icons.arrow_downward,
                textTheme,
                colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseItem(String title, double amount, String currencySymbol, Color color, IconData icon, TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$currencySymbol ${amount.toStringAsFixed(2)}',
          style: textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

}
