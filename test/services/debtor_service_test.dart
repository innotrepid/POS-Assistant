import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mercate/core/database/app_database.dart';
import 'package:mercate/services/debtor_service.dart';
import 'package:mercate/services/sales_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DebtorService', () {
    late AppDatabase db;
    late DebtorService debtors;
    late SalesService sales;

    setUp(() async {
      db = AppDatabase.memory();
      await db.database;
      debtors = DebtorService(database: db);
      sales = SalesService(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('credit sale increases balance; repayment reduces it', () async {
      final customerId = const Uuid().v4();
      final database = await db.database;
      await database.insert('customers', {
        'id': customerId,
        'name': 'Test Customer',
        'phone': '0700000000',
        'active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await sales.createSale(
        customerId: customerId,
        items: [
          const SaleLineInput(
            productName: 'Test item',
            quantity: 1,
            unitPrice: 100,
            isQuickSale: true,
          ),
        ],
        payments: const [],
        isCreditSale: true,
      );

      final afterCredit = await debtors.getBalance(customerId);
      expect(afterCredit, 100);

      await debtors.recordRepayment(
        customerId: customerId,
        amount: 40,
        paymentType: 'cash',
      );

      final afterPay = await debtors.getBalance(customerId);
      expect(afterPay, 60);
    });
  });
}
