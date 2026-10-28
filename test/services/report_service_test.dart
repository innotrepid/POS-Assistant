import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/services/report_service.dart';
import 'package:mercate/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReportService', () {
    late AppDatabase db;
    late ReportService reports;
    late SalesService sales;

    setUp(() async {
      db = AppDatabase.memory();
      await db.database;
      reports = ReportService(database: db);
      sales = SalesService(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('day sales includes cash sale and gross profit', () async {
      await sales.createSale(
        items: [
          const SaleLineInput(
            productName: 'Quick',
            quantity: 2,
            unitPrice: 50,
            unitCost: 20,
            isQuickSale: true,
          ),
        ],
        payments: const [
          PaymentInput(paymentType: 'cash', amount: 100),
        ],
      );

      final day = await reports.daySales(DateTime.now());
      expect(day['sales_total'], 100);
      expect(day['sale_count'], 1);
    });
  });
}
