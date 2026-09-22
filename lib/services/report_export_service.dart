import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'report_file_writer.dart'
    if (dart.library.html) 'report_file_writer_web.dart';

import '../models/transaction.dart';
import '../utils/transaction_filters.dart';

enum ReportType { daily, monthly, customRange, filtered, all }

enum ReportFormat { csv, pdf }

class ReportSummary {
  const ReportSummary({
    required this.income,
    required this.expense,
    required this.balance,
    required this.transactionCount,
  });

  final double income;
  final double expense;
  final double balance;
  final int transactionCount;
}

class ReportExportService {
  ReportExportService._();

  static const PdfColor _brandColor = PdfColor.fromInt(0xFF006D5B);
  static const PdfColor _incomeColor = PdfColor.fromInt(0xFF00D084);
  static const PdfColor _expenseColor = PdfColor.fromInt(0xFFFF8A80);

  static List<Transaction> transactionsForDay(
    List<Transaction> transactions,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);

    return transactions.where((transaction) {
      return TransactionFilters.matchesDate(
        transactionDate: transaction.date,
        selectedPeriod: 'Custom',
        customStartDate: start,
        customEndDate: end,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<Transaction> transactionsForMonth(
    List<Transaction> transactions,
    int year,
    int month,
  ) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    return transactions.where((transaction) {
      return TransactionFilters.matchesDate(
        transactionDate: transaction.date,
        selectedPeriod: 'Custom',
        customStartDate: start,
        customEndDate: end,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<Transaction> transactionsForRange(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
  ) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return transactions.where((transaction) {
      return TransactionFilters.matchesDate(
        transactionDate: transaction.date,
        selectedPeriod: 'Custom',
        customStartDate: rangeStart,
        customEndDate: rangeEnd,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static ReportSummary summarize(List<Transaction> transactions) {
    final income = transactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final expense = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return ReportSummary(
      income: income,
      expense: expense,
      balance: income - expense,
      transactionCount: transactions.length,
    );
  }

  static String reportTitle(ReportType reportType) {
    switch (reportType) {
      case ReportType.daily:
        return 'Daily Cash Book Report';
      case ReportType.monthly:
        return 'Monthly Cash Book Report';
      case ReportType.customRange:
        return 'Date Range Cash Book Report';
      case ReportType.filtered:
        return 'Filtered Cash Book Report';
      case ReportType.all:
        return 'Complete Cash Book Report';
    }
  }

  static String periodLabel(
    ReportType reportType,
    DateTime periodStart, {
    DateTime? periodEnd,
    String? filterDescription,
  }) {
    switch (reportType) {
      case ReportType.daily:
        return DateFormat('EEEE, MMM d, yyyy').format(periodStart);
      case ReportType.monthly:
        return DateFormat('MMMM yyyy').format(periodStart);
      case ReportType.customRange:
        final end = periodEnd ?? periodStart;
        return '${DateFormat('MMM d, yyyy').format(periodStart)} – ${DateFormat('MMM d, yyyy').format(end)}';
      case ReportType.filtered:
        if (filterDescription != null && filterDescription.trim().isNotEmpty) {
          return filterDescription;
        }
        final end = periodEnd ?? periodStart;
        return 'Filtered Data (${DateFormat('MMM d, yyyy').format(periodStart)} – ${DateFormat('MMM d, yyyy').format(end)})';
      case ReportType.all:
        return 'All Time';
    }
  }

  static String buildCsv({
    required ReportType reportType,
    required String bookName,
    required String currencySymbol,
    required List<Transaction> transactions,
    required ReportSummary summary,
    required DateTime periodStart,
    DateTime? periodEnd,
    String? filterDescription,
  }) {
    final generatedAt = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
    final buffer = StringBuffer();
    final title = reportTitle(reportType);
    final period = periodLabel(
      reportType,
      periodStart,
      periodEnd: periodEnd,
      filterDescription: filterDescription,
    );

    buffer.writeln(title);
    buffer.writeln('Book,${_csv(bookName)}');
    buffer.writeln('Period,${_csv(period)}');
    buffer.writeln('Generated,${_csv(generatedAt)}');
    buffer.writeln();
    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Amount ($currencySymbol)');
    buffer.writeln('Total Income,${summary.income.toStringAsFixed(2)}');
    buffer.writeln('Total Expense,${summary.expense.toStringAsFixed(2)}');
    buffer.writeln('Net Balance,${summary.balance.toStringAsFixed(2)}');
    buffer.writeln('Transactions,${summary.transactionCount}');
    buffer.writeln();
    buffer.writeln('TRANSACTIONS');
    buffer.writeln(
      'Date,Title,Category,Type,Payment Method,Amount ($currencySymbol)',
    );

    if (transactions.isEmpty) {
      buffer.writeln('No transactions found for this period,,,,,');
    } else {
      for (final transaction in transactions) {
        buffer.writeln(
          [
            _csv(DateFormat('yyyy-MM-dd').format(transaction.date)),
            _csv(transaction.title),
            _csv(transaction.category),
            _csv(transaction.type.name),
            _csv(TransactionFilters.paymentLabel(transaction)),
            transaction.amount.toStringAsFixed(2),
          ].join(','),
        );
      }
    }

    return buffer.toString();
  }

  static Future<Uint8List> buildPdf({
    required ReportType reportType,
    required String bookName,
    required String currencySymbol,
    required List<Transaction> transactions,
    required ReportSummary summary,
    required DateTime periodStart,
    DateTime? periodEnd,
    String? filterDescription,
    String Function(double amount)? formatCurrency,
  }) async {
    final generatedAt = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());
    final title = reportTitle(reportType);
    final period = periodLabel(
      reportType,
      periodStart,
      periodEnd: periodEnd,
      filterDescription: filterDescription,
    );
    final formatAmount =
        formatCurrency ?? (amount) => '$currencySymbol ${amount.toStringAsFixed(2)}';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Cash Book',
                style: pw.TextStyle(
                  color: _brandColor,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Generated on $generatedAt',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: _brandColor,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  bookName,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xCCFFFFFF),
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  period,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xCCFFFFFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              pw.Expanded(
                child: _summaryCard(
                  'Income',
                  formatAmount(summary.income),
                  _incomeColor,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _summaryCard(
                  'Expense',
                  formatAmount(summary.expense),
                  _expenseColor,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _summaryCard(
                  'Balance',
                  formatAmount(summary.balance),
                  _brandColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Transactions: ${summary.transactionCount}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Transactions',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _brandColor,
            ),
          ),
          pw.SizedBox(height: 8),
          if (transactions.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'No transactions found for this period.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.4),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableHeader('Date'),
                    _tableHeader('Title'),
                    _tableHeader('Category'),
                    _tableHeader('Type'),
                    _tableHeader('Payment'),
                    _tableHeader('Amount'),
                  ],
                ),
                ...transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final transaction = entry.value;
                  final isIncome = transaction.type == TransactionType.income;
                  final rowColor =
                      index.isEven ? PdfColors.white : PdfColors.grey100;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowColor),
                    children: [
                      _tableCell(DateFormat('MMM d').format(transaction.date)),
                      _tableCell(transaction.title),
                      _tableCell(transaction.category),
                      _tableCell(
                        transaction.type.name[0].toUpperCase() +
                            transaction.type.name.substring(1),
                        color: isIncome ? _incomeColor : _expenseColor,
                      ),
                      _tableCell(TransactionFilters.paymentLabel(transaction)),
                      _tableCell(
                        '${isIncome ? '+' : '-'}${formatAmount(transaction.amount)}',
                        align: pw.TextAlign.right,
                        bold: true,
                        color: isIncome ? _incomeColor : _expenseColor,
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _brandColor,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    PdfColor? color,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static Future<void> exportAndShare({
    required ReportFormat format,
    required ReportType reportType,
    required String bookName,
    required String currencySymbol,
    required List<Transaction> transactions,
    required DateTime periodStart,
    DateTime? periodEnd,
    String? filterDescription,
    String Function(double amount)? formatCurrency,
  }) async {
    final summary = summarize(transactions);
    final subject = switch (reportType) {
      ReportType.daily =>
        'Daily report - ${DateFormat('MMM d, yyyy').format(periodStart)}',
      ReportType.monthly =>
        'Monthly report - ${DateFormat('MMMM yyyy').format(periodStart)}',
      ReportType.customRange =>
        'Date Range report - ${DateFormat('MMM d, yyyy').format(periodStart)} to ${DateFormat('MMM d, yyyy').format(periodEnd ?? periodStart)}',
      ReportType.filtered =>
        'Filtered report - ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
      ReportType.all =>
        'All Time report - ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
    };

    final filePrefix = switch (reportType) {
      ReportType.daily =>
        'cashbook_daily_${DateFormat('yyyy-MM-dd').format(periodStart)}',
      ReportType.monthly =>
        'cashbook_monthly_${DateFormat('yyyy-MM').format(periodStart)}',
      ReportType.customRange =>
        'cashbook_range_${DateFormat('yyyyMMdd').format(periodStart)}_to_${DateFormat('yyyyMMdd').format(periodEnd ?? periodStart)}',
      ReportType.filtered =>
        'cashbook_filtered_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      ReportType.all =>
        'cashbook_all_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    };

    late final String fileName;
    late final Uint8List bytes;
    late final String mimeType;

    if (format == ReportFormat.csv) {
      final csv = buildCsv(
        reportType: reportType,
        bookName: bookName,
        currencySymbol: currencySymbol,
        transactions: transactions,
        summary: summary,
        periodStart: periodStart,
        periodEnd: periodEnd,
        filterDescription: filterDescription,
      );
      fileName = '$filePrefix.csv';
      mimeType = 'text/csv';
      bytes = Uint8List.fromList(utf8.encode(csv));
    } else {
      bytes = await buildPdf(
        reportType: reportType,
        bookName: bookName,
        currencySymbol: currencySymbol,
        transactions: transactions,
        summary: summary,
        periodStart: periodStart,
        periodEnd: periodEnd,
        filterDescription: filterDescription,
        formatCurrency: formatCurrency,
      );
      fileName = '$filePrefix.pdf';
      mimeType = 'application/pdf';
    }

    if (kIsWeb) {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        subject: '$subject ($bookName)',
        text: 'Cash Book $subject',
      );
      return;
    }

    final directory = await getTemporaryDirectory();
    final filePath = await writeReportFile(
      directoryPath: directory.path,
      fileName: fileName,
      bytes: bytes,
    );

    await Share.shareXFiles(
      [XFile(filePath, mimeType: mimeType, name: fileName)],
      subject: '$subject ($bookName)',
      text: 'Cash Book $subject',
    );
  }

  static Future<String> exportAndDownload({
    required ReportFormat format,
    required ReportType reportType,
    required String bookName,
    required String currencySymbol,
    required List<Transaction> transactions,
    required DateTime periodStart,
    DateTime? periodEnd,
    String? filterDescription,
    String Function(double amount)? formatCurrency,
  }) async {
    final summary = summarize(transactions);

    final filePrefix = switch (reportType) {
      ReportType.daily =>
        'cashbook_daily_${DateFormat('yyyy-MM-dd').format(periodStart)}',
      ReportType.monthly =>
        'cashbook_monthly_${DateFormat('yyyy-MM').format(periodStart)}',
      ReportType.customRange =>
        'cashbook_range_${DateFormat('yyyyMMdd').format(periodStart)}_to_${DateFormat('yyyyMMdd').format(periodEnd ?? periodStart)}',
      ReportType.filtered =>
        'cashbook_filtered_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      ReportType.all =>
        'cashbook_all_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    };

    late final String fileName;
    late final Uint8List bytes;

    if (format == ReportFormat.csv) {
      final csv = buildCsv(
        reportType: reportType,
        bookName: bookName,
        currencySymbol: currencySymbol,
        transactions: transactions,
        summary: summary,
        periodStart: periodStart,
        periodEnd: periodEnd,
        filterDescription: filterDescription,
      );
      fileName = '$filePrefix.csv';
      bytes = Uint8List.fromList(utf8.encode(csv));
    } else {
      bytes = await buildPdf(
        reportType: reportType,
        bookName: bookName,
        currencySymbol: currencySymbol,
        transactions: transactions,
        summary: summary,
        periodStart: periodStart,
        periodEnd: periodEnd,
        filterDescription: filterDescription,
        formatCurrency: formatCurrency,
      );
      fileName = '$filePrefix.pdf';
    }

    return saveReportFile(fileName: fileName, bytes: bytes);
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
