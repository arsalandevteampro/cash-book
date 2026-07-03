import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../services/report_export_service.dart';
import '../services/settings_service.dart';
import '../services/transaction_service.dart';

Future<void> showExportReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: const ExportReportSheet(),
    ),
  );
}

class ExportReportSheet extends StatefulWidget {
  const ExportReportSheet({super.key});

  @override
  State<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<ExportReportSheet> {
  ReportType _reportType = ReportType.daily;
  ReportFormat _reportFormat = ReportFormat.pdf;
  DateTime _selectedDay = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isExporting = false;

  List<Transaction> get _transactions =>
      Provider.of<TransactionService>(context, listen: false).transactions;

  String get _bookName =>
      Provider.of<TransactionService>(context, listen: false).currentBookName;

  SettingsService get _settings =>
      Provider.of<SettingsService>(context, listen: false);

  List<Transaction> get _previewTransactions {
    if (_reportType == ReportType.daily) {
      return ReportExportService.transactionsForDay(_transactions, _selectedDay);
    }
    return ReportExportService.transactionsForMonth(
      _transactions,
      _selectedYear,
      _selectedMonth,
    );
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

  Future<void> _exportReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isExporting = true);

    try {
      final transactions = _previewTransactions;
      final exportArgs = (
        format: _reportFormat,
        bookName: _bookName,
        currencySymbol: _settings.currencySymbol,
        transactions: transactions,
        formatCurrency: _settings.formatCurrency,
      );

      if (_reportType == ReportType.daily) {
        await ReportExportService.exportAndShare(
          format: exportArgs.format,
          reportType: ReportType.daily,
          bookName: exportArgs.bookName,
          currencySymbol: exportArgs.currencySymbol,
          transactions: exportArgs.transactions,
          periodStart: _selectedDay,
          formatCurrency: exportArgs.formatCurrency,
        );
      } else {
        final periodStart = DateTime(_selectedYear, _selectedMonth, 1);
        await ReportExportService.exportAndShare(
          format: exportArgs.format,
          reportType: ReportType.monthly,
          bookName: exportArgs.bookName,
          currencySymbol: exportArgs.currencySymbol,
          transactions: exportArgs.transactions,
          periodStart: periodStart,
          periodEnd: DateTime(_selectedYear, _selectedMonth + 1, 0),
          formatCurrency: exportArgs.formatCurrency,
        );
      }

      if (!mounted) {
        return;
      }

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report exported successfully')),
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to export report: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
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

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            Text(
              'Export Report',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Export a daily or monthly report for $_bookName.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Report Type',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReportType>(
              segments: const [
                ButtonSegment(
                  value: ReportType.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.today_rounded),
                ),
                ButtonSegment(
                  value: ReportType.monthly,
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month_rounded),
                ),
              ],
              selected: {_reportType},
              onSelectionChanged: (selection) {
                setState(() => _reportType = selection.first);
              },
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            if (_reportType == ReportType.daily)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded, color: Color(0xFF006D5B)),
                title: const Text('Report Date'),
                subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDay)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickDay,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
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
                      value: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
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
              ),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportReport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(
                  _isExporting
                      ? 'Exporting...'
                      : 'Export & Share ${_reportFormat == ReportFormat.pdf ? 'PDF' : 'CSV'}',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
