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

    final stockValue = stock.fold<double>(0, (s, r) => s + r.stockValue);
    final debtorsTotal = debtors.fold<double>(0, (s, r) => s + r.balance);
    final creditorsTotal =
        creditors.fold<double>(0, (s, r) => s + r.balance);

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
                  'Generated ${_nowLabel()} · Offline · Mercate',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
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
          _sectionTitle('Stock on hand', primary),
          pw.SizedBox(height: 4),
          _kv('Stock value (at cost)', Money.format(stockValue)),
          pw.SizedBox(height: 6),
          if (stock.isEmpty)
            pw.Text('No active products')
          else
            _table(
              headers: const ['Product', 'Qty', 'Value'],
              rows: stock
                  .take(50)
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
          _sectionTitle('Debtors (owed to you)', primary),
          pw.SizedBox(height: 4),
          _kv('Total', Money.format(debtorsTotal)),
          pw.SizedBox(height: 6),
          if (debtors.isEmpty)
            pw.Text('None')
          else
            _table(
              headers: const ['Customer', 'Phone', 'Balance'],
              rows: debtors
                  .take(40)
                  .map(
                    (d) => [
                      d.name,
                      d.phone?.trim().isNotEmpty == true ? d.phone! : '—',
                      Money.format(d.balance),
                    ],
                  )
                  .toList(),
            ),

          pw.SizedBox(height: 18),
          _sectionTitle('Creditors (you owe)', primary),
          pw.SizedBox(height: 4),
          _kv('Total', Money.format(creditorsTotal)),
          pw.SizedBox(height: 6),
          if (creditors.isEmpty)
            pw.Text('None')
          else
            _table(
              headers: const ['Supplier', 'Phone', 'Balance'],
              rows: creditors
                  .take(40)
                  .map(
                    (c) => [
                      c.name,
                      c.phone?.trim().isNotEmpty == true ? c.phone! : '—',
                      Money.format(c.balance),
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
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

  pw.Widget _summaryGrid(List<(String, String)> items) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        for (var i = 0; i < items.length; i += 2)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  items[i].$1,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  items[i].$2,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              if (i + 1 < items.length) ...[
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(12, 3, 0, 3),
                  child: pw.Text(
                    items[i + 1].$1,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    items[i + 1].$2,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ] else ...[
                pw.SizedBox(),
                pw.SizedBox(),
              ],
            ],
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
          i: i == 0
              ? const pw.FlexColumnWidth(2.2)
              : const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < row.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    row[i],
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: i == 0 ? pw.TextAlign.left : pw.TextAlign.right,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _nowLabel() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
}
