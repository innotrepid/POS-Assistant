import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/services/customer_service.dart';
import 'package:mercate/services/policy_service.dart';
import 'package:mercate/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('customer insert includes customer_type and settings table exists', () async {
    final appDb = AppDatabase.memory();
    addTearDown(appDb.close);

    final customers = CustomerService(database: appDb, uuid: const Uuid());
    final created = await customers.createCustomer(
      name: 'Amina',
      phone: '0712345678',
    );
    expect(created.name, 'Amina');

    final db = await appDb.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='settings'",
    );
    expect(tables, isNotEmpty);

    final info = await db.rawQuery('PRAGMA table_info(customers)');
    final cols = info.map((r) => r['name'] as String).toSet();
    expect(cols.contains('customer_type'), isTrue);

    final policies = PolicyService(database: appDb);
    expect(await policies.getAllowNegativeStock(), isFalse);
    await policies.setAllowNegativeStock(true);
    expect(await policies.getAllowNegativeStock(), isTrue);

    await db.insert('products', {
      'id': 'p1',
      'name': 'Sukuma',
      'unit': 'bunch',
      'selling_price': 20,
      'minimum_stock': 0,
      'reorder_quantity': 0,
      'active': 1,
      'track_batches': 0,
      'has_expiry': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await db.insert('stock_movements', {
      'id': 'm1',
      'product_id': 'p1',
      'movement_type': 'opening',
      'quantity': 5,
      'created_at': DateTime.now().toIso8601String(),
    });

    final sales = SalesService(database: appDb, uuid: const Uuid());
    final result = await sales.createSale(
      items: const [
        SaleLineInput(
          productId: 'p1',
          productName: 'Sukuma',
          quantity: 1,
          unitPrice: 20,
        ),
      ],
      payments: const [
        PaymentInput(paymentType: 'cash', amount: 20),
      ],
    );
    expect(result.saleId, isNotEmpty);
  });
}
