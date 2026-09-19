import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_assistant/core/database/app_database.dart';
import 'package:pos_assistant/services/report_service.dart';
import 'package:pos_assistant/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReportService', () {
    late AppDatabase appDb;
    late SalesService sales;
    late ReportService reports;
    late String productId;

    setUp(() async {
      appDb = AppDatabase.memory();
      sales = SalesService(database: appDb);
      reports = ReportService(database: appDb);

      final db = await appDb.database;
      final now = DateTime.now().toIso8601String();
      productId = const Uuid().v4();

      await db.insert('products', {
        'id': productId,
        'name': 'Soap',
        'unit': 'piece',
        'selling_price': 50,
        'cost_price': 30,
        'minimum_stock': 0,
        'reorder_quantity': 0,
        'active': 1,
        'track_batches': 0,
        'has_expiry': 0,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('stock_movements', {
        'id': const Uuid().v4(),
        'product_id': productId,
        'movement_type': 'opening_balance',
        'quantity': 20,
        'unit_cost': 30,
        'created_at': now,
      });
    });

    tearDown(() async {
      await appDb.close();
    });

    test('day sales includes cash sale and gross profit', () async {
      await sales.createSale(
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Soap',
            quantity: 2,
            unitPrice: 50,
            unitCost: 30,
          ),
        ],
        payments: [
          const PaymentInput(paymentType: 'cash', amount: 100),
        ],
      );

      final day = await reports.daySales();
      expect(day.saleCount, 1);
      expect(day.salesTotal, 100);
      expect(day.cash, 100);
      expect(day.estimatedCost, 60);
      expect(day.grossProfit, 40);
    });
  });
}
