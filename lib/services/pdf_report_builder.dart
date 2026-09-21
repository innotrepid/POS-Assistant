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
              'Mercate — Business report',
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
          _kv('Cash', Money.format(day.salesCash)),
          _kv('M-Pesa', Money.format(day.salesMpesa)),
          _kv('Credit', Money.format(day.salesCredit)),

          pw.SizedBox(height: 16),
          pw.Text(
            'Stock',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _kv('Stock value (cost)', Money.format(stockValue)),
          ...stock.take(40).map(
                (r) => _kv(
                  '${r.name} (${r.quantity} ${r.unit})',
                  Money.format(r.stockValue),
                ),
              ),
          if (stock.isEmpty) pw.Text('No stock'),

          pw.SizedBox(height: 16),
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
            'Offline report · Mercate Assistant',
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

  String _nowLabel() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
}
