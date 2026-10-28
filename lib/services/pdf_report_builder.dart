import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/money.dart';
import 'report_service.dart';

class PdfReportBuilder {
  static const _logoAsset = 'assets/images/mercate_logo.png';

  Future<Uint8List> buildBusinessReport({
    required String shopName,
    required DaySalesReport day,
    required List<StockRow> stock,
    required List<PartyBalanceRow> debtors,
    required List<PartyBalanceRow> creditors,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load(_logoAsset);
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final soldValue = stock.fold<double>(0, (s, r) => s + r.stockValue);
    final debtorsTotal = debtors.fold<double>(0, (s, r) => s + r.balance);
    final creditorsTotal = creditors.fold<double>(0, (s, r) => s + r.balance);
    final primary = PdfColor.fromInt(0xFF0D9488);
    final muted = PdfColors.grey700;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 44,
                    height: 44,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shopName.isEmpty ? 'My shop' : shopName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      pw.Text(
                        'Business report · ${day.businessDate}',
                        style: pw.TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  'Mercate',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: muted,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated offline · Mercate',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          _sectionTitle('Sales summary', primary),
          pw.SizedBox(height: 6),
          _summaryGrid([
            ('Sales count', '${day.saleCount}'),
            ('Sales total', Money.format(day.salesTotal)),
            ('Cash', Money.format(day.cash)),
            ('M-Pesa', Money.format(day.mpesa)),
            ('Card', Money.format(day.card)),
            ('New credit', Money.format(day.creditTotal)),
            ('Est. cost of goods', Money.format(day.estimatedCost)),
            ('Est. gross profit', Money.format(day.grossProfit)),
            ('Expenses', Money.format(day.expensesTotal)),
          ]),
          pw.SizedBox(height: 18),
          _sectionTitle('Items sold today', primary),
          pw.SizedBox(height: 4),
          _kv('Est. cost of sold items', Money.format(soldValue)),
          pw.SizedBox(height: 6),
          if (stock.isEmpty)
            pw.Text('No sales recorded today')
          else
            _table(
              headers: const ['Product', 'Qty', 'Est. value'],
              rows: stock
                  .take(80)
                  .map(
                    (r) => [
                      r.name,
                      _fmtQty(r.quantity),
                      Money.format(r.stockValue),
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 18),
          _sectionTitle('Who owes you', primary),
          pw.SizedBox(height: 4),
          _kv('Total outstanding', Money.format(debtorsTotal)),
          pw.SizedBox(height: 6),
          if (debtors.isEmpty)
            pw.Text('No open customer balances')
          else
            _table(
              headers: const ['Customer', 'Phone', 'Balance'],
              rows: debtors
                  .take(40)
                  .map(
                    (r) => [
                      r.name,
                      r.phone ?? '—',
                      Money.format(r.balance),
                    ],
                  )
                  .toList(),
            ),
          if (creditors.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('What you owe suppliers', primary),
            pw.SizedBox(height: 4),
            _kv('Total', Money.format(creditorsTotal)),
            pw.SizedBox(height: 6),
            _table(
              headers: const ['Supplier', 'Phone', 'Balance'],
              rows: creditors
                  .take(40)
                  .map(
                    (r) => [
                      r.name,
                      r.phone ?? '—',
                      Money.format(r.balance),
                    ],
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _sectionTitle(String title, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _summaryGrid(List<(String, String)> cells) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in cells)
          pw.Container(
            width: 150,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(c.$1, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(c.$2, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        for (var i = 0; i < headers.length; i++)
          i: i == 0 ? const pw.FlexColumnWidth(3) : const pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (final cell in row)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                ),
            ],
          ),
      ],
    );
  }

  String _fmtQty(double q) {
    if (q == q.truncateToDouble()) return q.toInt().toString();
    return q.toStringAsFixed(2);
  }
}
