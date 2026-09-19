import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_assistant/core/database/app_database.dart';
import 'package:pos_assistant/services/creditor_service.dart';
import 'package:pos_assistant/services/purchase_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Purchase + creditor', () {
    late AppDatabase appDb;
    late PurchaseService purchases;
    late CreditorService creditors;
    late String productId;
    late String supplierId;

    setUp(() async {
      appDb = AppDatabase.memory();
      purchases = PurchaseService(database: appDb);
      creditors = CreditorService(database: appDb);

      final db = await appDb.database;
      final now = DateTime.now().toIso8601String();
      productId = const Uuid().v4();
      supplierId = const Uuid().v4();

      await db.insert('products', {
        'id': productId,
        'name': 'Rice',
        'unit': 'kg',
        'selling_price': 150,
        'cost_price': 100,
        'minimum_stock': 0,
        'reorder_quantity': 0,
        'active': 1,
        'track_batches': 0,
        'has_expiry': 0,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('suppliers', {
        'id': supplierId,
        'name': 'Wakulima',
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
    });

    tearDown(() async {
      await appDb.close();
    });

    test('credit purchase increases stock and creditor balance', () async {
      await purchases.createPurchase(
        supplierId: supplierId,
        items: [
          PurchaseLineInput(
            productId: productId,
            productName: 'Rice',
            quantity: 10,
            unitCost: 100,
          ),
        ],
        paidAmount: 0,
      );

      final db = await appDb.database;
      final stock = await db.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS s FROM stock_movements WHERE product_id = ?',
        [productId],
      );
      expect((stock.first['s'] as num).toDouble(), 10);

      expect(await creditors.getBalance(supplierId), 1000);

      await creditors.recordPayment(
        supplierId: supplierId,
        amount: 400,
        paymentType: 'cash',
      );

      expect(await creditors.getBalance(supplierId), 600);
    });

    test('full cash purchase leaves zero creditor balance', () async {
      await purchases.createPurchase(
        supplierId: supplierId,
        items: [
          PurchaseLineInput(
            productId: productId,
            productName: 'Rice',
            quantity: 5,
            unitCost: 100,
          ),
        ],
        paidAmount: 500,
      );

      expect(await creditors.getBalance(supplierId), 0);
      expect(await creditors.listOutstanding(), isEmpty);
    });
  });
}
