import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/follow_up.dart';
import '../services/database_service.dart';
import '../services/follow_up_service.dart';
import '../services/settings_service.dart';
import '../services/transaction_service.dart';
import '../utils/follow_up_launcher.dart';
import 'add_follow_up_screen.dart';

enum FollowUpFilter {
  allPending,
  urgent,
  toReceive,
  toPay,
  completed,
}

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  FollowUpFilter _selectedFilter = FollowUpFilter.allPending;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final followUpService = context.watch<FollowUpService>();
    final settingsService = context.watch<SettingsService>();
    final currencySymbol = settingsService.currencySymbol;

    List<FollowUp> displayedItems;
    switch (_selectedFilter) {
      case FollowUpFilter.allPending:
        displayedItems = followUpService.pendingFollowUps;
        break;
      case FollowUpFilter.urgent:
        displayedItems = [...followUpService.overdueFollowUps, ...followUpService.todayFollowUps];
        break;
      case FollowUpFilter.toReceive:
        displayedItems = followUpService.followUps
            .where((f) => !f.isCompleted && f.type == FollowUpType.toReceive)
            .toList();
        break;
      case FollowUpFilter.toPay:
        displayedItems = followUpService.followUps
            .where((f) => !f.isCompleted && f.type == FollowUpType.toPay)
            .toList();
        break;
      case FollowUpFilter.completed:
        displayedItems = followUpService.completedFollowUps;
        break;
    }

    if (_searchController.text.trim().isNotEmpty) {
      final q = _searchController.text.trim().toLowerCase();
      displayedItems = displayedItems.where((f) {
        return f.contactName.toLowerCase().contains(q) ||
            f.title.toLowerCase().contains(q) ||
            (f.phoneNumber?.contains(q) ?? false) ||
            (f.note?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or note...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                'Follow-ups & Reminders',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close Search' : 'Search',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => followUpService.refresh(),
          ),
        ],
      ),

      body: Column(
        children: [
          // Top Summary Header (Receivable vs Payable)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              isLandscape ? 4 : 8,
              16,
              isLandscape ? 4 : 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'To Receive',
                    amount: followUpService.totalReceivablePending,
                    count: followUpService.toReceivePendingCount,
                    color: const Color(0xFF00D084),
                    icon: Icons.arrow_downward_rounded,
                    currencySymbol: currencySymbol,
                    isDark: isDark,
                    isLandscape: isLandscape,
                  ),
                ),
                SizedBox(width: isLandscape ? 8 : 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'To Pay',
                    amount: followUpService.totalPayablePending,
                    count: followUpService.toPayPendingCount,
                    color: const Color(0xFFFF5F5F),
                    icon: Icons.arrow_upward_rounded,
                    currencySymbol: currencySymbol,
                    isDark: isDark,
                    isLandscape: isLandscape,
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isLandscape ? 2 : 4,
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Pending (${followUpService.pendingCount})',
                  filter: FollowUpFilter.allPending,
                  isLandscape: isLandscape,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Urgent (${followUpService.urgentCount})',
                  filter: FollowUpFilter.urgent,
                  highlightBadge: followUpService.urgentCount > 0,
                  isLandscape: isLandscape,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'To Receive',
                  filter: FollowUpFilter.toReceive,
                  isLandscape: isLandscape,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'To Pay',
                  filter: FollowUpFilter.toPay,
                  isLandscape: isLandscape,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Completed (${followUpService.completedCount})',
                  filter: FollowUpFilter.completed,
                  isLandscape: isLandscape,
                ),
              ],
            ),
          ),

          SizedBox(height: isLandscape ? 4 : 8),

          // Main List View
          Expanded(
            child: displayedItems.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, isLandscape ? 72 : 90),
                    itemCount: displayedItems.length,
                    itemBuilder: (context, index) {
                      final item = displayedItems[index];
                      return _buildFollowUpCard(
                        context,
                        item: item,
                        currencySymbol: currencySymbol,
                        isDark: isDark,
                        isLandscape: isLandscape,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isLandscape
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AddFollowUpScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF006D5B),
              foregroundColor: Colors.white,
              tooltip: 'Add Follow-up',
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AddFollowUpScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFF006D5B),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Follow-up'),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required int count,
    required Color color,
    required IconData icon,
    required String currencySymbol,
    required bool isDark,
    bool isLandscape = false,
  }) {
    if (isLandscape) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$count pending',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '$currencySymbol ${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$currencySymbol ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count pending',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required FollowUpFilter filter,
    bool highlightBadge = false,
    bool isLandscape = false,
  }) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      visualDensity: isLandscape
          ? const VisualDensity(horizontal: -2, vertical: -3)
          : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (highlightBadge) ...[
            const SizedBox(width: 4),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5F5F),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filter),
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: const Color(0xFF006D5B).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? const Color(0xFF006D5B) : Colors.grey.shade600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFF006D5B) : Colors.grey.shade300,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildFollowUpCard(
    BuildContext context, {
    required FollowUp item,
    required String currencySymbol,
    required bool isDark,
    bool isLandscape = false,
  }) {
    final isToReceive = item.type == FollowUpType.toReceive;
    final color = isToReceive ? const Color(0xFF00D084) : const Color(0xFFFF5F5F);

    String statusText;
    Color statusColor;
    if (item.isCompleted) {
      statusText = 'Settled';
      statusColor = Colors.grey.shade500;
    } else if (item.isOverdue) {
      statusText = 'Overdue';
      statusColor = const Color(0xFFFF5F5F);
    } else if (item.isDueToday) {
      statusText = 'Due Today';
      statusColor = const Color(0xFFFFB300);
    } else {
      statusText = DateFormat('dd MMM').format(item.dueDate);
      statusColor = const Color(0xFF006D5B);
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLandscape ? 8 : 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isOverdue
              ? const Color(0xFFFF5F5F).withValues(alpha: 0.5)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: item.isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isLandscape ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Contact Name, Type Chip, and Options Menu
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.contactName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.title.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isToReceive
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: color,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isToReceive ? 'To Receive' : 'To Pay',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // More Popup Menu (Edit / Delete)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => AddFollowUpScreen(followUpToEdit: item),
                        ),
                      );
                    } else if (val == 'copy_as') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => AddFollowUpScreen(copyFrom: item),
                        ),
                      );
                    } else if (val == 'delete') {
                      _confirmDelete(context, item.id);
                    } else if (val == 'copy') {
                      FollowUpLauncher.copyReminder(
                        context,
                        followUp: item,
                        currencySymbol: currencySymbol,
                      );
                    } else if (val == 'snooze_1d') {
                      await context
                          .read<FollowUpService>()
                          .snoozeFollowUp(item.id, const Duration(days: 1));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Follow-up snoozed by +1 Day'),
                            backgroundColor: Color(0xFF006D5B),
                          ),
                        );
                      }
                    } else if (val == 'snooze_3d') {
                      await context
                          .read<FollowUpService>()
                          .snoozeFollowUp(item.id, const Duration(days: 3));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Follow-up snoozed by +3 Days'),
                            backgroundColor: Color(0xFF006D5B),
                          ),
                        );
                      }
                    } else if (val == 'snooze_7d') {
                      await context
                          .read<FollowUpService>()
                          .snoozeFollowUp(item.id, const Duration(days: 7));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Follow-up snoozed by +1 Week'),
                            backgroundColor: Color(0xFF006D5B),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!item.isCompleted) ...[
                      const PopupMenuItem(
                        value: 'snooze_1d',
                        child: Row(
                          children: [
                            Icon(Icons.snooze_rounded, size: 18, color: Color(0xFF006D5B)),
                            SizedBox(width: 8),
                            Text('Snooze +1 Day'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'snooze_3d',
                        child: Row(
                          children: [
                            Icon(Icons.update_rounded, size: 18, color: Color(0xFF006D5B)),
                            SizedBox(width: 8),
                            Text('Snooze +3 Days'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'snooze_7d',
                        child: Row(
                          children: [
                            Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF006D5B)),
                            SizedBox(width: 8),
                            Text('Snooze +1 Week'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 18, color: Colors.blueGrey),
                            SizedBox(width: 8),
                            Text('Copy Reminder Msg'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    ] else ...[
                      const PopupMenuItem(
                        value: 'copy_as',
                        child: Row(
                          children: [
                            Icon(Icons.copy_all_rounded, size: 18, color: Color(0xFF006D5B)),
                            SizedBox(width: 8),
                            Text('Copy as'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Amount & Due Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currencySymbol ${item.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${DateFormat('hh:mm a').format(item.dueDate)})',
                        style: TextStyle(fontSize: 10, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note: ${item.note}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            ],

            if (!item.isCompleted ||
                (item.phoneNumber != null && item.phoneNumber!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Row 3: Action Buttons (Call, WhatsApp, Mark as Done)
              Row(
                children: [
                  // Phone Call Button
                  if (item.phoneNumber != null &&
                      item.phoneNumber!.isNotEmpty) ...[
                    IconButton(
                      onPressed: () => FollowUpLauncher.makePhoneCall(
                        context,
                        item.phoneNumber!,
                      ),
                      icon: const Icon(Icons.call_rounded),
                      color: const Color(0xFF006D5B),
                      tooltip: 'Call ${item.contactName}',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF006D5B).withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => FollowUpLauncher.openWhatsApp(
                        context,
                        followUp: item,
                        currencySymbol: currencySymbol,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      color: const Color(0xFF25D366),
                      tooltip: 'WhatsApp Reminder',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF25D366).withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (!item.isCompleted) ...[
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showCompleteDialog(context, item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006D5B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 16),
                      label:
                          const Text('Mark Done', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, FollowUp item) {
    bool createTransaction = true;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = context.read<SettingsService>().currencySymbol;

    final books = DatabaseService.getAllBooks();
    String selectedBookId = books.any((b) => b['id'] == item.bookId)
        ? item.bookId
        : DatabaseService.getCurrentBookId();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Mark as Settled'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to mark this follow-up as completed?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: const Color(0xFF006D5B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: createTransaction,
                        activeColor: const Color(0xFF006D5B),
                        onChanged: (val) {
                          setDialogState(() => createTransaction = val ?? true);
                        },
                        title: Text(
                          'Record as ${item.type == FollowUpType.toReceive ? "Income" : "Expense"} ($currencySymbol ${item.amount.toStringAsFixed(0)}) in Cash Book',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Automatically adds a transaction entry',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  if (createTransaction && books.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Save to Book:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E232A) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedBookId,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: isDark ? const Color(0xFF1E232A) : Colors.white,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: books.map((b) {
                            final id = b['id'] as String;
                            final name = b['name'] as String? ?? 'Untitled Book';
                            final isCurrent = id == DatabaseService.getCurrentBookId();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.menu_book_rounded,
                                    size: 18,
                                    color: Color(0xFF006D5B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006D5B).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF006D5B),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setDialogState(() => selectedBookId = newVal);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006D5B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    final followUpService = context.read<FollowUpService>();
                    final transactionService = context.read<TransactionService>();

                    await followUpService.markCompleted(
                      item.id,
                      createTransaction: createTransaction,
                      targetBookId: selectedBookId,
                      transactionService: transactionService,
                    );

                    final targetBookName = books.firstWhere(
                      (b) => b['id'] == selectedBookId,
                      orElse: () => {'name': 'Cash Book'},
                    )['name'] as String? ?? 'Cash Book';

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            createTransaction
                                ? 'Marked as completed & saved to "$targetBookName"!'
                                : 'Follow-up marked as completed.',
                          ),
                          backgroundColor: const Color(0xFF006D5B),
                        ),
                      );
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Follow-up?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<FollowUpService>().deleteFollowUp(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF006D5B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 44,
                color: Color(0xFF006D5B),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Follow-ups Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "+ Add Follow-up" to schedule a payment or recovery reminder.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
