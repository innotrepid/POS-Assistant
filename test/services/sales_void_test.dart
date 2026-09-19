import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_assistant/core/database/app_database.dart';
import 'package:pos_assistant/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SalesService.voidSale', () {
    late AppDatabase appDb;
    late SalesService sales;
    late String productId;
    late String customerId;

    setUp(() async {
      appDb = AppDatabase.memory();
      sales = SalesService(database: appDb, uuid: const Uuid());

      final db = await appDb.database;
      final now = DateTime.now().toIso8601String();
      productId = const Uuid().v4();
      customerId = const Uuid().v4();

      await db.insert('products', {
        'id': productId,
        'name': 'Tea',
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

      await db.insert('customers', {
        'id': customerId,
        'name': 'Ann',
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('stock_movements', {
        'id': const Uuid().v4(),
        'product_id': productId,
        'movement_type': 'opening_balance',
        'quantity': 10,
        'unit_cost': 30,
        'created_at': now,
      });
    });

    tearDown(() async {
      await appDb.close();
    });

    Future<double> stock() async {
      final db = await appDb.database;
      final r = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS s FROM stock_movements WHERE product_id = ?',
        [productId],
      );
      return (r.first['s'] as num).toDouble();
    }

    test('void restores stock and is idempotent', () async {
      final created = await sales.createSale(
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Tea',
            quantity: 3,
            unitPrice: 50,
            unitCost: 30,
          ),
        ],
        payments: [
          const PaymentInput(paymentType: 'cash', amount: 150),
        ],
      );

      expect(await stock(), 7);

      final voided = await sales.voidSale(
        saleId: created.saleId,
        reason: 'Customer returned goods',
      );

      expect(voided.refundedAmount, 150);
      expect(voided.stockRestored, isTrue);
      expect(await stock(), 10);

      final sale = await sales.getSale(created.saleId);
      expect(sale!['sale_status'], 'voided');

      expect(
        () => sales.voidSale(
          saleId: created.saleId,
          reason: 'again',
        ),
        throwsA(isA<StateError>()),
      );

      // Stock must not double-restore
      expect(await stock(), 10);
    });

    test('void reverses credit debt', () async {
      final created = await sales.createSale(
        customerId: customerId,
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Tea',
            quantity: 2,
            unitPrice: 50,
          ),
        ],
        payments: const [],
        isCreditSale: true,
      );

      final db = await appDb.database;
      var debt = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS b FROM debtor_transactions WHERE customer_id = ?',
        [customerId],
      );
      expect((debt.first['b'] as num).toDouble(), 100);

      await sales.voidSale(
        saleId: created.saleId,
        reason: 'Wrong customer',
      );

      debt = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS b FROM debtor_transactions WHERE customer_id = ?',
        [customerId],
      );
      expect((debt.first['b'] as num).toDouble(), 0);
    });

    test('void requires reason', () async {
      final created = await sales.createSale(
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Tea',
            quantity: 1,
            unitPrice: 50,
          ),
        ],
        payments: [
          const PaymentInput(paymentType: 'cash', amount: 50),
        ],
      );

      expect(
        () => sales.voidSale(saleId: created.saleId, reason: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
