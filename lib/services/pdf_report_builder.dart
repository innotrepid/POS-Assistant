import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/money.dart';
import 'report_service.dart';

class PdfReportBuilder {
  Future<Uint8List> buildBusinessReport({
    required DaySalesReport day,
    required List<StockRow> stock,
    required List<PartyBalanceRow> debtors,
    required List<PartyBalanceRow> creditors,
  }) async {
    final doc = pw.Document();

    final stockValue = stock.fold<double>(0, (s, r) => s + r.stockValue);
    final debtorsTotal = debtors.fold<double>(0, (s, r) => s + r.balance);
    final creditorsTotal =
        creditors.fold<double>(0, (s, r) => s + r.balance);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'POS Assistant — Business report',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text('Generated ${_nowLabel()}'),
          pw.SizedBox(height: 16),

          pw.Text(
            'Sales — ${day.businessDate}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _kv('Sales count', '${day.saleCount}'),
          _kv('Sales total', Money.format(day.salesTotal)),
          _kv('Paid', Money.format(day.paidTotal)),
          _kv('New credit', Money.format(day.creditTotal)),
          _kv('Cash', Money.format(day.cash)),
          _kv('M-Pesa', Money.format(day.mpesa)),
          _kv('Card', Money.format(day.card)),
          if (day.other > 0) _kv('Other', Money.format(day.other)),
          _kv('Est. cost of goods', Money.format(day.estimatedCost)),
          _kv('Gross profit (est.)', Money.format(day.grossProfit)),
          _kv('Expenses', Money.format(day.expensesTotal)),
          pw.SizedBox(height: 20),

          pw.Text(
            'Stock on hand',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _kv('Stock value (at cost)', Money.format(stockValue)),
          pw.SizedBox(height: 6),
          if (stock.isEmpty)
            pw.Text('No products')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Product', 'Qty', 'Cost', 'Value'],
              data: stock
                  .take(40)
                  .map(
                    (r) => [
                      r.name,
                      _qty(r.quantity),
                      r.costPrice == null
                          ? '-'
                          : Money.format(r.costPrice!),
                      Money.format(r.stockValue),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          if (stock.length > 40)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                '... and ${stock.length - 40} more products',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Debtors',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _kv('Total owed to you', Money.format(debtorsTotal)),
          ...debtors.take(25).map(
                (d) => _kv(d.name, Money.format(d.balance)),
              ),
          if (debtors.isEmpty) pw.Text('None'),
          pw.SizedBox(height: 16),

          pw.Text(
            'Creditors',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _kv('Total you owe', Money.format(creditorsTotal)),
          ...creditors.take(25).map(
                (c) => _kv(c.name, Money.format(c.balance)),
              ),
          if (creditors.isEmpty) pw.Text('None'),

          pw.SizedBox(height: 24),
          pw.Text(
            'Offline report · POS Assistant',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    return Uint8List.fromList(bytes);
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.Text(value),
        ],
      ),
    );
  }

  String _qty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _nowLabel() {
    final n = DateTime.now();
    return '${n.year}-${_2(n.month)}-${_2(n.day)} '
        '${_2(n.hour)}:${_2(n.minute)}';
  }

  String _2(int n) => n.toString().padLeft(2, '0');
}
