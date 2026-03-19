import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../models/transaction.dart';
import '../widgets/transaction_list.dart';
import 'add_transaction_screen.dart';
import 'settings_screen.dart';
import 'analysis_screen.dart';
import '../widgets/ui_kit/glass_card.dart';
import '../widgets/ui_kit/loading_skeleton.dart';
import '../widgets/ui_kit/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedPaymentMethod;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final transactions = transactionService.transactions.where((tx) {
      final matchesSearch = tx.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == null || tx.category == _selectedCategory;

      String txPaymentLabel = '';
      if (tx.paymentMethod == PaymentMethod.other &&
          tx.customPaymentMethod != null) {
        txPaymentLabel = tx.customPaymentMethod!;
      } else {
        txPaymentLabel =
            tx.paymentMethod.name[0].toUpperCase() +
            tx.paymentMethod.name
                .substring(1)
                .replaceAll(RegExp(r'(?=[A-Z])'), ' ');
      }

      final matchesPayment =
          _selectedPaymentMethod == null ||
          txPaymentLabel == _selectedPaymentMethod;
      return matchesSearch && matchesCategory && matchesPayment;
    }).toList();

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
          _buildBalanceCard(
            context,
            transactionService,
            settingsService,
            colorScheme,
          ),
          _buildSearchAndFilterBar(context, settingsService),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => transactionService.refresh(),
              color: Theme.of(context).primaryColor,
              backgroundColor: Colors.white,
              child: transactionService.isLoading
                  ? ListView.builder(
                      itemCount: 5,
                      itemBuilder: (context, index) =>
                          const TransactionSkeleton(),
                    )
                  : transactions.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: EmptyState(
                          title: _searchQuery.isNotEmpty
                              ? 'No transactions found'
                              : 'No transactions yet',
                          message: _searchQuery.isNotEmpty
                              ? 'Try searching with a different term'
                              : 'Tap the + button to add your first transaction',
                          icon: _searchQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.account_balance_wallet_rounded,
                        ),
                      ),
                    )
                  : TransactionList(transactions: transactions),
            ),
          ),
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

  Widget _buildBalanceCard(
    BuildContext context,
    TransactionService transactionService,
    SettingsService settingsService,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      child: GlassCard(
        color: colorScheme.primary,
        opacity: 0.9,
        blur: 20,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Balance',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              settingsService.formatCurrency(transactionService.balance),
              style: textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildIncomeExpenseItem(
                    'Income',
                    transactionService.totalIncome,
                    settingsService,
                    const Color(0xFF64FFDA),
                    Icons.arrow_circle_up_rounded,
                    textTheme,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  _buildIncomeExpenseItem(
                    'Expense',
                    transactionService.totalExpense,
                    settingsService,
                    const Color(0xFFFF8A80),
                    Icons.arrow_circle_down_rounded,
                    textTheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseItem(
    String title,
    double amount,
    SettingsService settingsService,
    Color color,
    IconData icon,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: textTheme.labelMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          settingsService.formatCurrency(amount),
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final categories = settingsService.customCategories;
    final defaultCategories = [
      'Food',
      'Transport',
      'Entertainment',
      'Shopping',
      'Bills',
      'Health',
      'Education',
      'Salary',
      'Investment',
      'General',
    ];
    final allCategories = [...defaultCategories, ...categories];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).primaryColor,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                'All Categories',
                _selectedCategory == null,
                () => setState(() => _selectedCategory = null),
              ),
              ...allCategories.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildFilterChip(
                    cat,
                    _selectedCategory == cat,
                    () => setState(() => _selectedCategory = cat),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                'All Payments',
                _selectedPaymentMethod == null,
                () => setState(() => _selectedPaymentMethod = null),
              ),
              ...[
                'Cash',
                'Online',
                'Card',
                'Bank Transfer',
                'UPI',
                'Other',
              ].map(
                (method) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildFilterChip(
                    method,
                    _selectedPaymentMethod == method,
                    () => setState(() => _selectedPaymentMethod = method),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onSelected,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white.withOpacity(0.7) : theme.primaryColor),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.05)
          : theme.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide.none
            : BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
              ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
