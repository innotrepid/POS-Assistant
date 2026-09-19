import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SaleLineInput', () {
    test('calculates line total correctly', () {
      const item = SaleLineInput(
        productId: 'product-1',
        productName: 'Milk',
        quantity: 3,
        unitPrice: 70,
        discount: 10,
      );
      expect(item.total, 200);
    });
  });

  group('SalesService.createSale', () {
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
        'name': 'Milk 500ml',
        'unit': 'piece',
        'selling_price': 70,
        'cost_price': 50,
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
        'name': 'Mary',
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('stock_movements', {
        'id': const Uuid().v4(),
        'product_id': productId,
        'movement_type': 'opening_balance',
        'quantity': 10,
        'unit_cost': 50,
        'created_at': now,
      });
    });

    tearDown(() async {
      await appDb.close();
    });

    test('cash sale deducts stock and records payment', () async {
      final result = await sales.createSale(
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Milk 500ml',
            quantity: 2,
            unitPrice: 70,
            unitCost: 50,
          ),
        ],
        payments: [
          const PaymentInput(paymentType: 'cash', amount: 140),
        ],
      );

      final sale = await sales.getSale(result.saleId);
      expect(sale!['total'], 140);
      expect(sale['payment_status'], 'paid');

      final db = await appDb.database;
      final stock = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS s FROM stock_movements WHERE product_id = ?',
        [productId],
      );
      expect((stock.first['s'] as num).toDouble(), 8);
    });

    test('cash tendered calculates change', () async {
      final result = await sales.createSale(
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Milk 500ml',
            quantity: 1,
            unitPrice: 70,
          ),
        ],
        payments: [
          const PaymentInput(paymentType: 'cash', amount: 100),
        ],
        amountTendered: 100,
      );
      expect(result.changeGiven, 30);
      final sale = await sales.getSale(result.saleId);
      expect(sale!['paid_amount'], 70);
    });

    test('mpesa without reference is rejected', () async {
      expect(
        () => sales.createSale(
          items: [
            SaleLineInput(
              productId: productId,
              productName: 'Milk 500ml',
              quantity: 1,
              unitPrice: 70,
            ),
          ],
          payments: [
            const PaymentInput(paymentType: 'mpesa', amount: 70),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('underpay without explicit credit is rejected', () async {
      expect(
        () => sales.createSale(
          items: [
            SaleLineInput(
              productId: productId,
              productName: 'Milk 500ml',
              quantity: 1,
              unitPrice: 70,
            ),
          ],
          payments: [
            const PaymentInput(paymentType: 'cash', amount: 20),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('credit sale requires customer and creates debtor row', () async {
      final result = await sales.createSale(
        customerId: customerId,
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Milk 500ml',
            quantity: 1,
            unitPrice: 70,
            unitCost: 50,
          ),
        ],
        payments: const [],
        isCreditSale: true,
      );

      final sale = await sales.getSale(result.saleId);
      expect(sale!['payment_status'], 'unpaid');

      final db = await appDb.database;
      final debtors = await db.query(
        'debtor_transactions',
        where: 'sale_id = ?',
        whereArgs: [result.saleId],
      );
      expect(debtors.length, 1);
    });

    test('rejects sale with insufficient stock', () async {
      expect(
        () => sales.createSale(
          items: [
            SaleLineInput(
              productId: productId,
              productName: 'Milk 500ml',
              quantity: 20,
              unitPrice: 70,
            ),
          ],
          payments: [
            const PaymentInput(paymentType: 'cash', amount: 1400),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
