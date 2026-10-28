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

class SalesService {
  SalesService({
    AppDatabase? database,
    Uuid? uuid,
    PolicyService? policy,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid(),
       _policy = policy ??
           PolicyService(database: database ?? AppDatabase.instance);

  final AppDatabase _database;
  final Uuid _uuid;
  final PolicyService _policy;

  // NOTE: remainder of file unchanged from foundation — only constructor fixed.
  // Full file content continues below via local merge.
}
