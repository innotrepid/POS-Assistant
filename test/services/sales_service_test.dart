import 'package:flutter_test/flutter_test.dart';

import 'package:pos_assistant/services/sales_service.dart';

void main() {
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

    test('calculates line total without discount', () {
      const item = SaleLineInput(
        productId: 'product-1',
        productName: 'Bread',
        quantity: 2,
        unitPrice: 80,
      );

      expect(item.total, 160);
    });
  });
}
