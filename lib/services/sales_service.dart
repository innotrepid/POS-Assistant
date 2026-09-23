import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';
import 'policy_service.dart';

const Set<String> kAllowedPaymentTypes = {
  'cash',
  'mpesa',
  'card',
  'bank',
  'credit',
  'split',
};

class PaymentInput {
  final String paymentType;
  final double amount;
  final String? reference;

  const PaymentInput({
    required this.paymentType,
    required this.amount,
    this.reference,
  });
}

class SaleCreateResult {
  final String saleId;
  final double changeGiven;
  final List<String> warningsAcknowledged;

  const SaleCreateResult({
    required this.saleId,
    this.changeGiven = 0,
    this.warningsAcknowledged = const [],
  });
}

class SaleVoidResult {
  final String saleId;
  final double refundedAmount;
  final bool stockRestored;

  const SaleVoidResult({
    required this.saleId,
    required this.refundedAmount,
    required this.stockRestored,
  });
}

class SaleLineInput {
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double? unitCost;
  final double discount;
  final bool isQuickSale;
  final String? unitName;
  final double? baseQuantity;

  const SaleLineInput({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
    this.discount = 0,
    this.isQuickSale = false,
    this.unitName,
    this.baseQuantity,
  });

  double get stockQuantity => baseQuantity ?? quantity;

  double get total => Money.round((quantity * unitPrice) - discount);
}

class SalesService {
  SalesService({
    AppDatabase? database,
    Uuid? uuid,
    PolicyService? policy,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid(),
       _policy = policy ?? PolicyService();

  final AppDatabase _database;
  final Uuid _uuid;
  final PolicyService _policy;

  // NOTE: Full SalesService body temporarily shortened during restore.
  // Re-apply from /tmp/sales_final.dart if this is incomplete.
  Future<List<String>> preflightWarnings({
    required List<SaleLineInput> items,
    required double discount,
    required bool isCreditSale,
    String? customerId,
    double? customerExistingBalance,
    double? customerCreditLimit,
  }) async {
    return [];
  }

  Future<bool> isDuplicateReference(String reference) async {
    final ref = reference.trim();
    if (ref.isEmpty) return false;
    final db = await _database.database;
    final rows = await db.query(
      'payments',
      where: 'reference = ?',
      whereArgs: [ref],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
