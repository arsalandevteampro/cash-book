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
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/ui_kit/glass_card.dart';
import '../widgets/ui_kit/loading_skeleton.dart';
import '../widgets/ui_kit/empty_state.dart';
import '../services/database_service.dart';
import '../services/google_drive_service.dart';

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

  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isAutoBackingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionService>(context, listen: false).addListener(_onTransactionChanged);
      _checkAutoBackup();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: GestureDetector(
          onTap: () => _showBookSelector(context, transactionService),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transactionService.currentBookName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF006D5B),
                ),
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
                  transactionService,
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
                    child: _buildSearchAndFilterBar(context, settingsService),
                  ),
                  height: 80.0,
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
            Text(
              'Current Balance',
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
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
                    text: settingsService.formatAmount(transactionService.balance),
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
                      transactionService.totalIncome,
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
                      transactionService.totalExpense,
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            settingsService.formatCurrency(amount),
            style: textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    SettingsService settingsService,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
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
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              onPressed: () => _showFilterBottomSheet(context, settingsService),
              tooltip: 'Filters',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksBar(
    BuildContext context,
    TransactionService transactionService,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Books',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showCreateBookDialog(transactionService),
                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF00D084)),
                label: const Text(
                  'NEW BOOK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00D084),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: transactionService.books.map((book) {
                final id = book['id']?.toString() ?? '';
                final name = book['name']?.toString() ?? 'Book';
                final isCurrent = id == transactionService.currentBookId;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () async {
                      if (isCurrent) return;
                      await transactionService.switchBook(id);
                    },
                    onLongPress: () {
                      _showRenameBookDialog(transactionService, id, name);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent 
                            ? const Color(0xFF006D5B) 
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isCurrent 
                          ? [BoxShadow(color: const Color(0xFF006D5B).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : [BoxShadow(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.black.withOpacity(0.04)
                                  : Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )],
                        border: Border.all(
                          color: isCurrent 
                              ? Colors.transparent 
                              : Theme.of(context).dividerColor.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isCurrent ? Colors.white : const Color(0xFF006D5B),
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    SettingsService settingsService,
  ) {
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
    final allCategories = {
      ...defaultCategories,
      ...settingsService.customCategories,
    }.toList();

    final payments = [
      'Cash',
      'Online',
      'Card',
      'Bank Transfer',
      'UPI',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
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
                            _selectedCategory = null;
                            _selectedPaymentMethod = null;
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
                      final isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedCategory = selected ? cat : null;
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
                      final isSelected = _selectedPaymentMethod == method;
                      return ChoiceChip(
                        label: Text(method),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedPaymentMethod = selected ? method : null;
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
            );
          },
        );
      },
    );
  }

  Future<void> _showBookSelector(
    BuildContext context,
    TransactionService transactionService,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Select Book',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...transactionService.books.map((book) {
                final id = book['id']?.toString() ?? '';
                final name = book['name']?.toString() ?? 'Book';
                final isCurrent = id == transactionService.currentBookId;
                return ListTile(
                  leading: Icon(
                    isCurrent
                        ? Icons.check_circle_rounded
                        : Icons.menu_book_rounded,
                  ),
                  title: Text(name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showRenameBookDialog(transactionService, id, name);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showDeleteBookDialog(transactionService, id, name);
                        },
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(ctx).pop(id),
                );
              }),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Create New Book'),
                onTap: () => Navigator.of(ctx).pop('__create__'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected == '__create__') {
      await _showCreateBookDialog(transactionService);
      return;
    }

    if (selected != transactionService.currentBookId) {
      await transactionService.switchBook(selected);
    }
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
    if (transactionService.books.length <= 1) {
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
            'Delete "$name"? This will permanently remove all transactions and goals in this book.',
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
