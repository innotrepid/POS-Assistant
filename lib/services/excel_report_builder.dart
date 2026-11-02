import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/money.dart';
import 'report_service.dart';

/// Builds multi-sheet .xlsx workbooks for offline share (Excel / Sheets).
class ExcelReportBuilder {
  Future<Uint8List> buildWorkbook({
    required String shopName,
    required DaySalesReport day,
    required List<StockRow> itemsSold,
    required List<StockRow> stock,
    required List<PartyBalanceRow> debtors,
    required List<PartyBalanceRow> creditors,
    required List<CategoryTotal> expensesByCategory,
    required List<StockRow> lowStock,
    PeriodSeries? week,
    PeriodSeries? month,
  }) async {
    final excel = Excel.createExcel();

    // Default sheet is often "Sheet1" — rename / replace with Summary.
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null) {
      excel.rename(defaultName, 'Summary');
    }

    _writeSummary(
      excel['Summary']!,
      shopName: shopName,
      day: day,
    );
    _writeItemsSold(excel['Items sold']!, itemsSold);
    _writeStock(excel['Stock']!, stock);
    _writeParties(excel['Debtors']!, debtors, 'Customer');
    _writeParties(excel['Creditors']!, creditors, 'Supplier');
    _writeExpenses(excel['Expenses']!, expensesByCategory);
    _writeLowStock(excel['Low stock']!, lowStock);
    if (week != null) {
      _writePeriod(excel['Week']!, week);
    }
    if (month != null) {
      _writePeriod(excel['Month']!, month);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Could not encode Excel file.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> shareWorkbook({
    required String shopName,
    required DaySalesReport day,
    required List<StockRow> itemsSold,
    required List<StockRow> stock,
    required List<PartyBalanceRow> debtors,
    required List<PartyBalanceRow> creditors,
    required List<CategoryTotal> expensesByCategory,
    required List<StockRow> lowStock,
    PeriodSeries? week,
    PeriodSeries? month,
  }) async {
    final bytes = await buildWorkbook(
      shopName: shopName,
      day: day,
      itemsSold: itemsSold,
      stock: stock,
      debtors: debtors,
      creditors: creditors,
      expensesByCategory: expensesByCategory,
      lowStock: lowStock,
      week: week,
      month: month,
    );
    final dir = await getTemporaryDirectory();
    final name = 'mercate-report-${day.businessDate}.xlsx';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: name,
        ),
      ],
      subject: 'Mercate report ${day.businessDate}',
      text: 'Shop report · $shopName · ${day.businessDate}',
    );
  }

  void _writeSummary(
    Sheet sheet, {
    required String shopName,
    required DaySalesReport day,
  }) {
    _headers(sheet, ['Field', 'Value']);
    final rows = <List<String>>[
      ['Shop', shopName.isEmpty ? 'My shop' : shopName],
      ['Business date', day.businessDate],
      ['Sales count', '${day.saleCount}'],
      ['Sales total', _n(day.salesTotal)],
      ['Cash', _n(day.cash)],
      ['M-Pesa', _n(day.mpesa)],
      ['Card', _n(day.card)],
      ['Other paid', _n(day.other)],
      ['New credit (deni)', _n(day.creditTotal)],
      ['Est. cost of goods', _n(day.estimatedCost)],
      ['Est. gross profit', _n(day.grossProfit)],
      ['Expenses', _n(day.expensesTotal)],
      ['Generated', DateTime.now().toIso8601String()],
    ];
    for (var i = 0; i < rows.length; i++) {
      sheet.appendRow([
        TextCellValue(rows[i][0]),
        TextCellValue(rows[i][1]),
      ]);
    }
  }

  void _writeItemsSold(Sheet sheet, List<StockRow> items) {
    _headers(sheet, ['Product', 'Qty', 'Avg sell', 'Est. cost value']);
    for (final r in items) {
      sheet.appendRow([
        TextCellValue(r.name),
        DoubleCellValue(r.quantity),
        DoubleCellValue(r.sellingPrice),
        DoubleCellValue(r.stockValue),
      ]);
    }
  }

  void _writeStock(Sheet sheet, List<StockRow> stock) {
    _headers(sheet, ['Product', 'Qty on hand', 'Cost', 'Sell', 'Value at cost']);
    for (final r in stock) {
      sheet.appendRow([
        TextCellValue(r.name),
        DoubleCellValue(r.quantity),
        DoubleCellValue(r.costPrice ?? 0),
        DoubleCellValue(r.sellingPrice),
        DoubleCellValue(r.stockValue),
      ]);
    }
  }

  void _writeParties(
    Sheet sheet,
    List<PartyBalanceRow> rows,
    String nameHeader,
  ) {
    _headers(sheet, [nameHeader, 'Phone', 'Balance']);
    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r.name),
        TextCellValue(r.phone ?? ''),
        DoubleCellValue(r.balance),
      ]);
    }
  }

  void _writeExpenses(Sheet sheet, List<CategoryTotal> rows) {
    _headers(sheet, ['Category', 'Total']);
    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r.category),
        DoubleCellValue(r.total),
      ]);
    }
  }

  void _writeLowStock(Sheet sheet, List<StockRow> rows) {
    _headers(sheet, ['Product', 'Qty on hand', 'Sell price']);
    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r.name),
        DoubleCellValue(r.quantity),
        DoubleCellValue(r.sellingPrice),
      ]);
    }
  }

  void _writePeriod(Sheet sheet, PeriodSeries series) {
    _headers(sheet, [
      'Date',
      'Label',
      'Sales',
      'Sale count',
      'Expenses',
      'Gross profit',
    ]);
    for (final d in series.days) {
      sheet.appendRow([
        TextCellValue(d.businessDate),
        TextCellValue(d.shortLabel),
        DoubleCellValue(d.salesTotal),
        IntCellValue(d.saleCount),
        DoubleCellValue(d.expensesTotal),
        DoubleCellValue(d.grossProfit),
      ]);
    }
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(series.title),
      DoubleCellValue(series.salesTotal),
      IntCellValue(series.saleCount),
      DoubleCellValue(series.expensesTotal),
      DoubleCellValue(series.grossProfit),
    ]);
  }

  void _headers(Sheet sheet, List<String> headers) {
    sheet.appendRow([
      for (final h in headers) TextCellValue(h),
    ]);
  }

  String _n(double v) => Money.round(v).toStringAsFixed(2);
}
