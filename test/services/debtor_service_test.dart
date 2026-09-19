import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_assistant/core/database/app_database.dart';
import 'package:pos_assistant/services/debtor_service.dart';
import 'package:pos_assistant/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DebtorService', () {
    late AppDatabase appDb;
    late SalesService sales;
    late DebtorService debtors;
    late String productId;
    late String customerId;

    setUp(() async {
      appDb = AppDatabase.memory();
      sales = SalesService(database: appDb);
      debtors = DebtorService(database: appDb);

      final db = await appDb.database;
      final now = DateTime.now().toIso8601String();
      productId = const Uuid().v4();
      customerId = const Uuid().v4();

      await db.insert('products', {
        'id': productId,
        'name': 'Sugar',
        'unit': 'piece',
        'selling_price': 100,
        'cost_price': 80,
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
        'name': 'John',
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('stock_movements', {
        'id': const Uuid().v4(),
        'product_id': productId,
        'movement_type': 'opening_balance',
        'quantity': 50,
        'created_at': now,
      });
    });

    tearDown(() async {
      await appDb.close();
    });

    test('credit sale increases balance; repayment reduces it', () async {
      await sales.createSale(
        customerId: customerId,
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Sugar',
            quantity: 2,
            unitPrice: 100,
          ),
        ],
        paidAmount: 0,
        paymentType: 'credit',
      );

      expect(await debtors.getBalance(customerId), 200);

      final outstanding = await debtors.listOutstanding();
      expect(outstanding.length, 1);
      expect(outstanding.first.balance, 200);

      await debtors.recordRepayment(
        customerId: customerId,
        amount: 50,
        paymentType: 'cash',
      );

      expect(await debtors.getBalance(customerId), 150);

      await debtors.recordRepayment(
        customerId: customerId,
        amount: 150,
        paymentType: 'mpesa',
        reference: 'ABC123',
      );

      expect(await debtors.getBalance(customerId), 0);
      expect(await debtors.listOutstanding(), isEmpty);
    });

    test('rejects overpayment', () async {
      await sales.createSale(
        customerId: customerId,
        items: [
          SaleLineInput(
            productId: productId,
            productName: 'Sugar',
            quantity: 1,
            unitPrice: 100,
          ),
        ],
        paidAmount: 0,
        paymentType: 'credit',
      );

      expect(
        () => debtors.recordRepayment(
          customerId: customerId,
          amount: 150,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
