import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../models/transaction.dart';
import '../widgets/transaction_list.dart';
import '../widgets/pulse_animation.dart';
import 'add_transaction_screen.dart';
import 'settings_screen.dart';
import 'analysis_screen.dart';
import 'manage_books_screen.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/ui_kit/glass_card.dart';
import '../widgets/ui_kit/loading_skeleton.dart';
import '../widgets/ui_kit/empty_state.dart';
import '../widgets/export_report_sheet.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';
import '../core/constants.dart';
import '../utils/transaction_filters.dart';
import 'package:intl/intl.dart';
import '../widgets/rating_dialog.dart';
import '../services/rating_service.dart';
import '../ads/banner_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<String> _selectedCategories = [];
  final List<String> _selectedPaymentMethods = [];
  TransactionType? _selectedType;
  String? _selectedPeriod;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime? _singleDate;

  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isAutoBackingUp = false;
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _isBalanceVisible = DatabaseService.getSetting<bool>('isBalanceVisible') ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionService>(context, listen: false).addListener(_onTransactionChanged);
      _checkAutoBackup();
      _checkRatingPrompt();
      _trackTransactionsForRating();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile)) {
        _checkAutoBackup();
      }
    });
  }

  void _onTransactionChanged() {
    if (!mounted) return;
    final freq = Provider.of<SettingsService>(context, listen: false).backupFrequency;
    if (freq == 'Immediately') {
      _checkAutoBackup();
    }
    _trackTransactionsForRating();
  }

  void _trackTransactionsForRating() {
    final count =
        Provider.of<TransactionService>(context, listen: false).transactions.length;
    RatingService.trackTransactionAdded(count);
  }

  Future<void> _checkRatingPrompt() async {
    await maybeShowRatingPrompt(context);
  }

  Future<void> _checkAutoBackup() async {
    if (_isAutoBackingUp || !mounted) return;
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final freq = settingsService.backupFrequency;
    if (freq == 'Never') return;

    final lastBackup = settingsService.lastBackupTimestamp;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastBackup;

    const dayMs = 24 * 60 * 60 * 1000;
    bool shouldBackup = false;

    if (freq == 'Immediately') shouldBackup = true;
    else if (freq == 'Daily' && diff > dayMs) shouldBackup = true;
    else if (freq == 'Weekly' && diff > 7 * dayMs) shouldBackup = true;
    else if (freq == 'Monthly' && diff > 30 * dayMs) shouldBackup = true;

    if (!shouldBackup) return;

    final txService = Provider.of<TransactionService>(context, listen: false);
    bool hasUnsynced = false;
    for (final tx in txService.transactions) {
      final txTime = tx.updatedAt ?? int.tryParse(tx.id) ?? 0;
      if (txTime > lastBackup) {
        hasUnsynced = true;
        break;
      }
    }

    if (!hasUnsynced) return;

    _isAutoBackingUp = true;
    try {
      final account = await GoogleDriveService.signInSilently();
      if (account != null) {
        final backupData = await DatabaseService.exportDataAsync();
        backupData['frequency'] = freq;
        backupData['timestamp'] = DateTime.now().toIso8601String();
        final result = await GoogleDriveService.backupToGoogleDrive(backupData);
        if (result.success && mounted) {
          await settingsService.setLastBackupTimestamp(DateTime.now().millisecondsSinceEpoch);
        }
      }
    } finally {
      _isAutoBackingUp = false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    Provider.of<TransactionService>(context, listen: false).removeListener(_onTransactionChanged);
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
          _selectedCategories.isEmpty || _selectedCategories.contains(tx.category);
      final matchesPayment =
          _selectedPaymentMethods.isEmpty ||
          _selectedPaymentMethods.contains(TransactionFilters.paymentLabel(tx));
      final matchesType = _selectedType == null || tx.type == _selectedType;
      final matchesDate = TransactionFilters.matchesDate(
        transactionDate: tx.date,
        selectedPeriod: _selectedPeriod,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
        singleDate: _singleDate,
      );

      return matchesSearch &&
          matchesCategory &&
          matchesPayment &&
          matchesType &&
          matchesDate;
    }).toList();

    final hasActiveFilters = _selectedCategories.isNotEmpty ||
        _selectedPaymentMethods.isNotEmpty ||
        _selectedType != null ||
        TransactionFilters.hasActiveDateFilter(_selectedPeriod);

    // Calculate filtered totals
    final filteredBalance = transactions.fold(0.0, (sum, item) {
      return sum +
          (item.type == TransactionType.income ? item.amount : -item.amount);
    });

    final filteredIncome = transactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, item) => sum + item.amount);

    final filteredExpense = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: GestureDetector(
          onTap: () => _showBookTreeBottomSheet(context, transactionService),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _buildBreadcrumb(transactionService),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF006D5B), size: 18),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => transactionService.refresh(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF006D5B)),
            onPressed: () => showExportReportSheet(context),
            tooltip: 'Export Report',
          ),
          IconButton(
            icon: const Icon(Icons.analytics_rounded, color: Color(0xFF006D5B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AnalysisScreen()),
              );
            },
            tooltip: 'Analysis',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF006D5B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => transactionService.refresh(),
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(
                child: _buildBalanceCard(
                  context,
                  filteredBalance,
                  filteredIncome,
                  filteredExpense,
                  settingsService,
                  colorScheme,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildBooksBar(context, transactionService),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchBarDelegate(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildSearchAndFilterBar(
                      context,
                      settingsService,
                      hasActiveFilters,
                    ),
                  ),
                  height: hasActiveFilters
                      ? 118.0
                      : 80.0,
                ),
              ),
            ];
          },
          body: transactionService.isLoading
              ? ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) => const TransactionSkeleton(),
                )
              : transactions.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyState(
                      title: hasActiveFilters || _searchQuery.isNotEmpty
                          ? 'No transactions found'
                          : 'No transactions yet',
                      message: hasActiveFilters || _searchQuery.isNotEmpty
                          ? 'Try changing your search or filters'
                          : 'Tap the + button to add your first transaction',
                      icon: hasActiveFilters || _searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.account_balance_wallet_rounded,
                    ),
                  ),
                )
              : TransactionList(transactions: transactions),
        ),
      ),
      floatingActionButton: PulseAnimation(
        color: const Color(0xFF00D084),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const AddTransactionScreen()),
            );
          },
          backgroundColor: const Color(0xFF00D084),
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: const SafeArea(
        top: false,
        child: BannerAdWidget(),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    double balance,
    double totalIncome,
    double totalExpense,
    SettingsService settingsService,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF006D5B), // Deep Emerald
            Color(0xFF00D084), // Mint/Emerald
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006D5B).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Balance',
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isBalanceVisible = !_isBalanceVisible;
                    });
                    DatabaseService.updateSetting('isBalanceVisible', _isBalanceVisible);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      _isBalanceVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: Colors.white.withOpacity(0.85),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isBalanceVisible)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${settingsService.currencySymbol} ',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: settingsService.formatAmount(balance),
                        style: const TextStyle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBalanceVisible = true;
                  });
                  DatabaseService.updateSetting('isBalanceVisible', true);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to reveal balance',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    opacity: 0.15,
                    blur: 10,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _buildIncomeExpenseItem(
                      'INCOME',
                      totalIncome,
                      settingsService,
                      const Color(0xFF00D084),
                      Icons.arrow_downward_rounded,
                      textTheme,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    opacity: 0.15,
                    blur: 10,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _buildIncomeExpenseItem(
                      'EXPENSE',
                      totalExpense,
                      settingsService,
                      const Color(0xFFFF8A80),
                      Icons.arrow_upward_rounded,
                      textTheme,
                    ),
                  ),
                ),
              ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 12),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_isBalanceVisible)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              settingsService.formatCurrency(amount),
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  'Protected',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    SettingsService settingsService,
    bool hasActiveFilters,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
        children: [
          Expanded(
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
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF262626),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.4)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  onPressed: () =>
                      _showFilterBottomSheet(context, settingsService),
                  tooltip: 'Filters',
                ),
                if (hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD54F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  if (TransactionFilters.hasActiveDateFilter(_selectedPeriod))
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InputChip(
                        avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(_dateFilterLabel()),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedPeriod = null;
                            _customStartDate = null;
                            _customEndDate = null;
                            _singleDate = null;
                          });
                        },
                      ),
                    ),
                  if (_selectedType != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InputChip(
                        avatar: Icon(
                          _selectedType == TransactionType.income
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 16,
                          color: _selectedType == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                        ),
                        label: Text(_selectedType == TransactionType.income ? 'Income' : 'Expense'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedType = null;
                          });
                        },
                      ),
                    ),
                  ..._selectedCategories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InputChip(
                          label: Text(cat),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedCategories.remove(cat);
                            });
                          },
                        ),
                      )),
                  ..._selectedPaymentMethods.map((method) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InputChip(
                          label: Text(method),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedPaymentMethods.remove(method);
                            });
                          },
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dateFilterLabel() {
    if (_selectedPeriod == 'Single Date' && _singleDate != null) {
      return DateFormat('MMM d, yyyy').format(_singleDate!);
    }
    if (_selectedPeriod == 'Custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      return '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}';
    }
    return _selectedPeriod ?? 'All Time';
  }

  Widget _buildBooksBar(
    BuildContext context,
    TransactionService transactionService,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = transactionService.currentBookPath;
    final pathString = path.map((b) => b['name']?.toString() ?? '').where((n) => n.isNotEmpty).join(' > ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBookTreeBottomSheet(context, transactionService),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFF006D5B).withOpacity(0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF006D5B).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006D5B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: Color(0xFF006D5B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ACTIVE CASH BOOK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00D084),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transactionService.currentBookName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pathString.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          pathString,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF006D5B).withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006D5B).withOpacity(isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.unfold_more_rounded,
                        color: Color(0xFF006D5B),
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tree',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006D5B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    SettingsService settingsService,
  ) {
    final allCategories = {
      ...AppConstants.defaultCategories,
      ...settingsService.customCategories,
      ...Provider.of<TransactionService>(context, listen: false).transactions.map((tx) => tx.category),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final payments = {
      'Cash',
      'Online',
      'Card',
      'Bank Transfer',
      'UPI',
      'Other',
      ...settingsService.customPaymentMethods,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategories.clear();
                            _selectedPaymentMethods.clear();
                            _selectedType = null;
                            _selectedPeriod = null;
                            _customStartDate = null;
                            _customEndDate = null;
                            _singleDate = null;
                          });
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('All Time'),
                        selected:
                            _selectedPeriod == null ||
                            _selectedPeriod == 'All Time',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPeriod = selected ? 'All Time' : null;
                            _customStartDate = null;
                            _customEndDate = null;
                            _singleDate = null;
                          });
                          setState(() {});
                        },
                      ),
                      ...TransactionFilters.presetPeriods.map((period) {
                        return ChoiceChip(
                          label: Text(period),
                          selected: _selectedPeriod == period,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedPeriod = selected ? period : null;
                              _customStartDate = null;
                              _customEndDate = null;
                              _singleDate = null;
                            });
                            setState(() {});
                          },
                        );
                      }),
                      ChoiceChip(
                        label: Text(
                          _singleDate != null
                              ? DateFormat('MMM d').format(_singleDate!)
                              : 'Pick Date',
                        ),
                        selected: _selectedPeriod == 'Single Date',
                        onSelected: (selected) async {
                          if (!selected) return;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _singleDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              _selectedPeriod = 'Single Date';
                              _singleDate = picked;
                              _customStartDate = null;
                              _customEndDate = null;
                            });
                            setState(() {});
                          }
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          _customStartDate != null && _customEndDate != null
                              ? '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}'
                              : 'Custom Range',
                        ),
                        selected: _selectedPeriod == 'Custom',
                        onSelected: (selected) async {
                          if (!selected) return;
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange:
                                _customStartDate != null &&
                                    _customEndDate != null
                                ? DateTimeRange(
                                    start: _customStartDate!,
                                    end: _customEndDate!,
                                  )
                                : null,
                          );
                          if (picked != null) {
                            setModalState(() {
                              _selectedPeriod = 'Custom';
                              _customStartDate = picked.start;
                              _customEndDate = picked.end;
                              _singleDate = null;
                            });
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transaction Type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: _selectedType == TransactionType.income,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedType = selected ? TransactionType.income : null;
                          });
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Expense'),
                        selected: _selectedType == TransactionType.expense,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedType = selected ? TransactionType.expense : null;
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: allCategories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedCategories.add(cat);
                            } else {
                              _selectedCategories.remove(cat);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Payment Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: payments.map((method) {
                      final isSelected = _selectedPaymentMethods.contains(method);
                      return FilterChip(
                        label: Text(method),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedPaymentMethods.add(method);
                            } else {
                              _selectedPaymentMethods.remove(method);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Bottom padding
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  // ── Breadcrumb title widget ─────────────────────────────────────────────
  Widget _buildBreadcrumb(TransactionService transactionService) {
    final path = transactionService.currentBookPath;
    if (path.isEmpty) {
      return const Text(
        'My Book',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF006D5B)),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < path.length; i++) ...
          [
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF006D5B)),
              ),
            Flexible(
              child: Text(
                path[i]['name']?.toString() ?? '',
                style: TextStyle(
                  fontSize: i == path.length - 1 ? 17 : 13,
                  fontWeight: i == path.length - 1 ? FontWeight.w700 : FontWeight.w400,
                  color: const Color(0xFF006D5B),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
      ],
    );
  }

  // ── Tree-view Book Selector ───────────────────────────────────────────────
  Future<void> _showBookTreeBottomSheet(
    BuildContext context,
    TransactionService transactionService,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String sheetSearchQuery = '';
        final Set<String> sheetCollapsedBookIds = {};

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void refresh() => setModalState(() {});
            final rootBooks = transactionService.rootBooks;
            final allBooks = transactionService.books;

            final displayBooks = sheetSearchQuery.isEmpty
                ? rootBooks
                : allBooks
                    .where((b) => (b['name']?.toString() ?? '')
                        .toLowerCase()
                        .contains(sheetSearchQuery.toLowerCase()))
                    .toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.40,
              maxChildSize: 0.92,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_tree_rounded,
                            color: Color(0xFF006D5B),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Select Cash Book',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _showCreateBookDialog(transactionService);
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New Book'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF006D5B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Search Field inside sheet
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        onChanged: (val) => setModalState(() => sheetSearchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search book tree...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: Theme.of(ctx).brightness == Brightness.dark
                              ? const Color(0xFF1E1E1E)
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: displayBooks.isEmpty
                          ? Center(
                              child: Text(
                                'No books found',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            )
                          : ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.only(bottom: 12),
                              children: [
                                ...displayBooks.map((b) {
                                  if (sheetSearchQuery.isNotEmpty) {
                                    return _buildSingleBookNode(
                                      ctx: ctx,
                                      book: b,
                                      transactionService: transactionService,
                                    );
                                  }
                                  return _buildBookTreeNode(
                                    ctx: ctx,
                                    book: b,
                                    transactionService: transactionService,
                                    depth: 0,
                                    refresh: refresh,
                                    collapsedBookIds: sheetCollapsedBookIds,
                                  );
                                }),
                              ],
                            ),
                    ),
                    // Sticky Bottom Bar with Manage All Books Full Screen option
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).cardColor,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(ctx).dividerColor.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ManageBooksScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.fullscreen_rounded, size: 20),
                          label: const Text('Manage All Books (Full Screen)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006D5B),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSingleBookNode({
    required BuildContext ctx,
    required Map<String, dynamic> book,
    required TransactionService transactionService,
  }) {
    final id = book['id']?.toString() ?? '';
    final name = book['name']?.toString() ?? 'Book';
    final isCurrent = id == transactionService.currentBookId;

    return ListTile(
      leading: Icon(
        Icons.menu_book_rounded,
        color: isCurrent ? const Color(0xFF006D5B) : Colors.grey,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          color: isCurrent ? const Color(0xFF006D5B) : null,
        ),
      ),
      trailing: isCurrent
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF006D5B))
          : null,
      onTap: () async {
        Navigator.of(ctx).pop();
        if (!isCurrent) {
          await transactionService.switchBook(id);
        }
      },
    );
  }

  /// Builds one tree node and its children recursively.
  Widget _buildBookTreeNode({
    required BuildContext ctx,
    required Map<String, dynamic> book,
    required TransactionService transactionService,
    required int depth,
    required VoidCallback refresh,
    required Set<String> collapsedBookIds,
  }) {
    final id = book['id']?.toString() ?? '';
    final name = book['name']?.toString() ?? 'Book';
    final isCurrent = id == transactionService.currentBookId;
    final children = transactionService.getDirectSubBooks(id);
    final hasChildren = children.isNotEmpty;
    final isExpanded = !collapsedBookIds.contains(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            Navigator.of(ctx).pop();
            if (id != transactionService.currentBookId) {
              await transactionService.switchBook(id);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0 + depth * 20.0,
              right: 8,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  InkWell(
                    onTap: () {
                      if (collapsedBookIds.contains(id)) {
                        collapsedBookIds.remove(id);
                      } else {
                        collapsedBookIds.add(id);
                      }
                      refresh();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        color: const Color(0xFF006D5B),
                        size: 20,
                      ),
                    ),
                  )
                else if (depth > 0) ...[
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  hasChildren
                      ? (isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded)
                      : isCurrent
                          ? Icons.menu_book_rounded
                          : Icons.book_outlined,
                  size: 20,
                  color: isCurrent
                      ? const Color(0xFF006D5B)
                      : hasChildren
                          ? const Color(0xFFE0A800)
                          : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                      color: isCurrent ? const Color(0xFF006D5B) : null,
                    ),
                  ),
                ),
                if (isCurrent)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF006D5B)),
                  ),
                // Add sub-book
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: 'Add sub-book',
                  color: const Color(0xFF006D5B),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _showCreateSubBookDialog(transactionService, parentId: id, parentName: name);
                  },
                ),
                // Rename
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Rename',
                  color: Colors.grey.shade600,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showRenameBookDialog(transactionService, id, name);
                  },
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showDeleteBookDialog(transactionService, id, name);
                  },
                ),
              ],
            ),
          ),
        ),
        // Render children recursively
        if (hasChildren && isExpanded)
          ...children.map((child) => _buildBookTreeNode(
                ctx: ctx,
                book: child,
                transactionService: transactionService,
                depth: depth + 1,
                refresh: refresh,
                collapsedBookIds: collapsedBookIds,
              )),
      ],
    );
  }

  Future<void> _showRenameBookDialog(
    TransactionService transactionService,
    String bookId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Book'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'New book name'),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final cleanName = (name ?? '').trim();
    if (cleanName.isEmpty || cleanName == currentName) return;
    final isDuplicate = transactionService.books.any(
      (book) =>
          book['id'] != bookId &&
          (book['name']?.toString().toLowerCase() ?? '') ==
              cleanName.toLowerCase(),
    );
    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book name already exists. Choose another name.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await transactionService.renameBook(bookId, cleanName);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Book renamed to "$cleanName"')));
    }
  }

  Future<void> _showDeleteBookDialog(
    TransactionService transactionService,
    String bookId,
    String name,
  ) async {
    final subBooks = transactionService.getDirectSubBooks(bookId);
    final hasChildren = subBooks.isNotEmpty;
    final rootBooks = transactionService.rootBooks;
    final isRoot = !transactionService.books
        .any((b) => b['id'] == bookId && b['parentId'] != null);
    if (isRoot && rootBooks.length <= 1 && !hasChildren) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one book is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Book'),
          content: Text(
            hasChildren
                ? 'Delete "$name" and ALL its sub-books? This will permanently remove all transactions inside them.'
                : 'Delete "$name"? This will permanently remove all transactions and goals in this book.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    await transactionService.deleteBook(bookId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Book "$name" deleted')));
    }
  }

  Future<void> _showCreateBookDialog(TransactionService transactionService) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create New Book'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Book name (e.g. Home, Office)',
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    final cleanName = (name ?? '').trim();
    if (cleanName.isEmpty) return;
    await transactionService.createBook(cleanName);
  }

  Future<void> _showCreateSubBookDialog(
    TransactionService transactionService, {
    required String parentId,
    required String parentName,
  }) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Sub-Book'),
              const SizedBox(height: 2),
              Text(
                'Under: $parentName',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Sub-book name',
              prefixIcon: const Icon(Icons.subdirectory_arrow_right_rounded, size: 18),
              prefixIconColor: const Color(0xFF006D5B),
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    final cleanName = (name ?? '').trim();
    if (cleanName.isEmpty) return;
    await transactionService.createSubBook(cleanName, parentId: parentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sub-book "$cleanName" created under "$parentName"')),
      );
    }
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickySearchBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
