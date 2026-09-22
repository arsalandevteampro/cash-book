import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/report_export_service.dart';
import '../services/settings_service.dart';
import '../services/transaction_service.dart';
import '../ads/interstitial_ad_manager.dart';

Future<void> showExportReportSheet(
  BuildContext context, {
  List<Transaction>? initialFilteredTransactions,
  bool? hasActiveFilters,
  String? filterDescription,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => ExportReportSheet(
      initialFilteredTransactions: initialFilteredTransactions,
      hasActiveFilters: hasActiveFilters,
      filterDescription: filterDescription,
    ),
  );
}

class ExportReportSheet extends StatefulWidget {
  const ExportReportSheet({
    super.key,
    this.initialFilteredTransactions,
    this.hasActiveFilters,
    this.filterDescription,
  });

  final List<Transaction>? initialFilteredTransactions;
  final bool? hasActiveFilters;
  final String? filterDescription;

  @override
  State<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<ExportReportSheet> {
  late ReportType _reportType;
  ReportFormat _reportFormat = ReportFormat.pdf;
  DateTime _selectedDay = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  bool _isDownloading = false;
  bool _isSharing = false;
  bool get _isExporting => _isDownloading || _isSharing;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, 1);
    _rangeEnd = now;

    if ((widget.hasActiveFilters ?? false) &&
        widget.initialFilteredTransactions != null &&
        widget.initialFilteredTransactions!.isNotEmpty) {
      _reportType = ReportType.filtered;
    } else {
      _reportType = ReportType.daily;
    }

    // Preload Interstitial Ad so it's ready when user taps Download or Share
    InterstitialAdManager.instance.preloadAd();
  }

  List<Transaction> get _transactions =>
      Provider.of<TransactionService>(context, listen: false).transactions;

  String get _bookName =>
      Provider.of<TransactionService>(context, listen: false).currentBookName;

  SettingsService get _settings =>
      Provider.of<SettingsService>(context, listen: false);

  List<Transaction> get _previewTransactions {
    switch (_reportType) {
      case ReportType.daily:
        return ReportExportService.transactionsForDay(_transactions, _selectedDay);
      case ReportType.monthly:
        return ReportExportService.transactionsForMonth(
          _transactions,
          _selectedYear,
          _selectedMonth,
        );
      case ReportType.customRange:
        return ReportExportService.transactionsForRange(
          _transactions,
          _rangeStart,
          _rangeEnd,
        );
      case ReportType.filtered:
        return widget.initialFilteredTransactions ?? _transactions;
      case ReportType.all:
        return List<Transaction>.from(_transactions)
          ..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  ReportSummary get _previewSummary =>
      ReportExportService.summarize(_previewTransactions);

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF006D5B),
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
    }
  }

  Future<void> _exportReport({required bool isShare}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      if (isShare) {
        _isSharing = true;
      } else {
        _isDownloading = true;
      }
    });

    try {
      final transactions = _previewTransactions;
      DateTime periodStart = _selectedDay;
      DateTime? periodEnd;

      switch (_reportType) {
        case ReportType.daily:
          periodStart = _selectedDay;
          periodEnd = null;
          break;
        case ReportType.monthly:
          periodStart = DateTime(_selectedYear, _selectedMonth, 1);
          periodEnd = DateTime(_selectedYear, _selectedMonth + 1, 0);
          break;
        case ReportType.customRange:
          periodStart = _rangeStart;
          periodEnd = _rangeEnd;
          break;
        case ReportType.filtered:
        case ReportType.all:
          if (transactions.isNotEmpty) {
            final sortedDates = transactions.map((t) => t.date).toList()..sort();
            periodStart = sortedDates.first;
            periodEnd = sortedDates.last;
          } else {
            periodStart = DateTime.now();
            periodEnd = DateTime.now();
          }
          break;
      }

      String? savedPath;

      if (isShare) {
        await ReportExportService.exportAndShare(
          format: _reportFormat,
          reportType: _reportType,
          bookName: _bookName,
          currencySymbol: _settings.currencySymbol,
          transactions: transactions,
          periodStart: periodStart,
          periodEnd: periodEnd,
          filterDescription: widget.filterDescription,
          formatCurrency: _settings.formatCurrency,
        );
      } else {
        savedPath = await ReportExportService.exportAndDownload(
          format: _reportFormat,
          reportType: _reportType,
          bookName: _bookName,
          currencySymbol: _settings.currencySymbol,
          transactions: transactions,
          periodStart: periodStart,
          periodEnd: periodEnd,
          filterDescription: widget.filterDescription,
          formatCurrency: _settings.formatCurrency,
        );
      }

      if (!mounted) {
        return;
      }

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isShare
                ? 'Report shared successfully'
                : 'Report downloaded successfully: ${savedPath ?? ''}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${isShare ? 'share' : 'download'} report: $error',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isSharing = false;
        });
      }
    }
  }

  Widget _buildReportTypeSelector() {
    final showFiltered = widget.initialFilteredTransactions != null &&
        (widget.hasActiveFilters ?? false);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showFiltered)
          _buildChip(
            type: ReportType.filtered,
            label: 'Filtered (${widget.initialFilteredTransactions!.length})',
            icon: Icons.filter_alt_rounded,
          ),
        _buildChip(
          type: ReportType.daily,
          label: 'Daily',
          icon: Icons.today_rounded,
        ),
        _buildChip(
          type: ReportType.monthly,
          label: 'Monthly',
          icon: Icons.calendar_month_rounded,
        ),
        _buildChip(
          type: ReportType.customRange,
          label: 'Date Range',
          icon: Icons.date_range_rounded,
        ),
        _buildChip(
          type: ReportType.all,
          label: 'All Time',
          icon: Icons.all_inclusive_rounded,
        ),
      ],
    );
  }

  Widget _buildChip({
    required ReportType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _reportType == type;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : const Color(0xFF006D5B),
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _reportType = type);
        }
      },
      selectedColor: const Color(0xFF006D5B),
      backgroundColor: Colors.grey.withValues(alpha: 0.08),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
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

  Widget _buildPeriodConfig(List<String> months, List<int> years) {
    switch (_reportType) {
      case ReportType.daily:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded, color: Color(0xFF006D5B)),
          title: const Text('Report Date'),
          subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDay)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _pickDay,
        );

      case ReportType.monthly:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: List.generate(months.length, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(months[index]),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMonth = value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: years
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text('$year'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedYear = value);
                  }
                },
              ),
            ),
          ],
        );

      case ReportType.customRange:
        return InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF006D5B).withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF006D5B).withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, color: Color(0xFF006D5B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Date Range (Tap to change)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('MMM d, yyyy').format(_rangeStart)} – ${DateFormat('MMM d, yyyy').format(_rangeEnd)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_rounded,
                    size: 20, color: Color(0xFF006D5B)),
              ],
            ),
          ),
        );

      case ReportType.filtered:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF006D5B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF006D5B).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, color: Color(0xFF006D5B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exporting Filtered Screen View',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.filterDescription != null &&
                              widget.filterDescription!.isNotEmpty
                          ? widget.filterDescription!
                          : 'Includes only transactions matching your active filters.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case ReportType.all:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.all_inclusive_rounded, color: Colors.grey),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All transactions in this book will be included in the report without date or category restrictions.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      DateTime.now().year - 2019,
      (index) => 2020 + index,
    ).reversed.toList();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final mediaQuery = MediaQuery.of(context);
    final bottomNavPadding = mediaQuery.viewPadding.bottom > 0
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Pinned Header (Always visible, never scrolled away)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Report',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Export PDF or CSV report for $_bookName.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable Options & Preview
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Type',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildReportTypeSelector(),
                  const SizedBox(height: 18),
                  Text(
                    'File Format',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ReportFormat>(
                    segments: const [
                      ButtonSegment(
                        value: ReportFormat.pdf,
                        label: Text('PDF'),
                        icon: Icon(Icons.picture_as_pdf_rounded),
                      ),
                      ButtonSegment(
                        value: ReportFormat.csv,
                        label: Text('CSV'),
                        icon: Icon(Icons.table_chart_rounded),
                      ),
                    ],
                    selected: {_reportFormat},
                    onSelectionChanged: (selection) {
                      setState(() => _reportFormat = selection.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildPeriodConfig(months, years),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006D5B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF006D5B).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF006D5B),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text('Transactions: ${_previewSummary.transactionCount}'),
                        Text(
                          'Income: ${_settings.formatCurrency(_previewSummary.income)}',
                        ),
                        Text(
                          'Expense: ${_settings.formatCurrency(_previewSummary.expense)}',
                        ),
                        Text(
                          'Balance: ${_settings.formatCurrency(_previewSummary.balance)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Pinned Bottom Action Bar (Download & Share) with navigation bar inset
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              10,
              24,
              14 + (bottomNavPadding > 0 ? bottomNavPadding : 6),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).bottomSheetTheme.backgroundColor ??
                  Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting
                        ? null
                        : () {
                            InterstitialAdManager.instance.showAdThen(
                              onComplete: () => _exportReport(isShare: false),
                            );
                          },
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_rounded),
                    label: Text(
                      _isDownloading
                          ? 'Downloading...'
                          : 'Download ${_reportFormat == ReportFormat.pdf ? 'PDF' : 'CSV'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                          color: Color(0xFF006D5B), width: 1.5),
                      foregroundColor: const Color(0xFF006D5B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExporting
                        ? null
                        : () {
                            InterstitialAdManager.instance.showAdThen(
                              onComplete: () => _exportReport(isShare: true),
                            );
                          },
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_rounded),
                    label: Text(
                      _isSharing
                          ? 'Sharing...'
                          : 'Share ${_reportFormat == ReportFormat.pdf ? 'PDF' : 'CSV'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF006D5B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
