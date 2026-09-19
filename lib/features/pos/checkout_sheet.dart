import 'package:flutter/material.dart';

import '../../core/models/customer.dart';
import '../../core/safety/safety_dialogs.dart';
import '../../core/utils/money.dart';
import '../../services/debtor_service.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';
import 'customer_picker_sheet.dart';

class CheckoutResult {
  final String saleId;
  final double total;
  final String paymentType;
  final double changeGiven;

  const CheckoutResult({
    required this.saleId,
    required this.total,
    required this.paymentType,
    this.changeGiven = 0,
  });
}

class CheckoutSheet extends StatefulWidget {
  final CartController cart;
  final SalesService salesService;

  const CheckoutSheet({
    super.key,
    required this.cart,
    required this.salesService,
  });

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  String _paymentType = 'cash';
  final _paidController = TextEditingController();
  final _tenderedController = TextEditingController();
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _debtors = DebtorService();
  Customer? _customer;
  bool _submitting = false;
  String? _error;

  double get _subtotal => widget.cart.subtotal;

  double get _discount => Money.parse(_discountController.text);

  double get _total {
    final t = Money.round(_subtotal - _discount);
    return t < 0 ? 0 : t;
  }

  bool get _isCredit => _paymentType == 'credit';

  double get _change {
    if (_paymentType != 'cash') return 0;
    final tendered = Money.parse(_tenderedController.text);
    if (tendered > _total) return Money.round(tendered - _total);
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _paidController.text = _total.toStringAsFixed(2);
    _tenderedController.text = _total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _paidController.dispose();
    _tenderedController.dispose();
    _referenceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final selected = await showCustomerPicker(context);
    if (selected != null && mounted) {
      setState(() => _customer = selected);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final discount = Money.parse(_discountController.text);
      final paid = _isCredit
          ? Money.parse(_paidController.text)
          : (_paymentType == 'cash'
              ? Money.parse(_tenderedController.text)
              : Money.parse(_paidController.text));

      if (_isCredit && _customer == null) {
        throw ArgumentError('Select a customer for credit sales.');
      }

      if ((_paymentType == 'mpesa' || _paymentType == 'bank') &&
          _referenceController.text.trim().isEmpty) {
        throw ArgumentError(
          '${_paymentType.toUpperCase()} requires a transaction/reference number.',
        );
      }

      final ref = _referenceController.text.trim();
      if (ref.isNotEmpty) {
        final dup = await widget.salesService.isDuplicateReference(ref);
        if (dup) {
          final ok = await showSafetyWarning(
            context,
            title: 'Duplicate reference',
            whatHappened: 'Reference "$ref" was used on a previous payment.',
            whyItMatters:
                'Duplicate M-Pesa/bank references may mean a double-recorded payment.',
            affected: ref,
            level: SafetyLevel.caution,
          );
          if (!ok) {
            setState(() => _submitting = false);
            return;
          }
        }
      }

      final items = widget.cart.lines
          .map(
            (line) => SaleLineInput(
              productId: line.isQuickSale ? null : line.product?.id,
              productName: line.name,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              unitCost: line.isQuickSale ? null : line.product?.costPrice,
              discount: line.discount,
              isQuickSale: line.isQuickSale,
            ),
          )
          .toList();

      double? existingBalance;
      if (_customer != null) {
        existingBalance = await _debtors.getBalance(_customer!.id);
      }

      final warnings = await widget.salesService.preflightWarnings(
        items: items,
        discount: discount,
        isCreditSale: _isCredit,
        customerId: _customer?.id,
        customerExistingBalance: existingBalance,
        customerCreditLimit: _customer?.creditLimit,
      );

      final acknowledged = <String>[];
      for (final w in warnings) {
        final critical = w.contains('BELOW COST') || w.contains('DEBT');
        final ok = await showSafetyWarning(
          context,
          title: critical ? 'Risk warning' : 'Please confirm',
          whatHappened: w,
          whyItMatters: critical
              ? 'This affects profit or customer debt. Proceed only if intentional.'
              : 'Confirm you understand this adjustment.',
          level: critical ? SafetyLevel.critical : SafetyLevel.caution,
        );
        if (!ok) {
          setState(() => _submitting = false);
          return;
        }
        acknowledged.add(w);
      }

      final confirmLines = <String>[
        'Subtotal ${Money.format(_subtotal)}',
        if (discount > 0) 'Discount -${Money.format(discount)}',
        'Total ${Money.format(_total)}',
        'Payment ${_paymentType.toUpperCase()}',
        if (_paymentType == 'cash')
          'Tendered ${Money.format(Money.parse(_tenderedController.text))}',
        if (_change > 0) 'Change ${Money.format(_change)}',
        if (_isCredit) 'Credit / debt sale',
        if (_customer != null) 'Customer ${_customer!.name}',
        if (ref.isNotEmpty) 'Ref $ref',
      ];

      final confirmed = await showSaleConfirmation(
        context,
        lines: confirmLines,
      );
      if (!confirmed) {
        setState(() => _submitting = false);
        return;
      }

      final paymentAmount = _isCredit
          ? paid
          : (_paymentType == 'cash'
              ? (_change > 0 ? _total : paid)
              : paid);

      final result = await widget.salesService.createSale(
        customerId: _customer?.id,
        items: items,
        discount: discount,
        isCreditSale: _isCredit,
        amountTendered:
            _paymentType == 'cash' ? Money.parse(_tenderedController.text) : null,
        payments: [
          if (paymentAmount > 0 || _paymentType == 'cash')
            PaymentInput(
              paymentType: _isCredit && paymentAmount == 0 ? 'cash' : _paymentType,
              amount: _isCredit ? paymentAmount : (_paymentType == 'cash' ? Money.parse(_tenderedController.text) : paymentAmount),
              reference: ref.isEmpty ? null : ref,
            ),
        ],
        warningsAcknowledged: acknowledged,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        CheckoutResult(
          saleId: result.saleId,
          total: _total,
          paymentType: _paymentType,
          changeGiven: result.changeGiven,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checkout', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Subtotal ${Money.format(_subtotal)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'Sale discount (amount)',
                border: OutlineInputBorder(),
                helperText: 'Warnings appear if discount is large or total is zero',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                setState(() {
                  if (!_isCredit) {
                    _paidController.text = _total.toStringAsFixed(2);
                    _tenderedController.text = _total.toStringAsFixed(2);
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Total ${Money.format(_total)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final type in ['cash', 'mpesa', 'card', 'bank', 'credit'])
                  ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: _paymentType == type,
                    onSelected: (_) {
                      setState(() {
                        _paymentType = type;
                        if (type == 'credit') {
                          _paidController.text = '0';
                        } else {
                          _paidController.text = _total.toStringAsFixed(2);
                          _tenderedController.text = _total.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_paymentType == 'cash') ...[
              TextField(
                controller: _tenderedController,
                decoration: const InputDecoration(
                  labelText: 'Cash received',
                  border: OutlineInputBorder(),
                  helperText: 'Change is calculated automatically',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              if (_change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Change ${Money.format(_change)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.greenAccent,
                        ),
                  ),
                ),
            ] else if (!_isCredit) ...[
              TextField(
                controller: _paidController,
                decoration: const InputDecoration(
                  labelText: 'Amount paid',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              TextField(
                controller: _paidController,
                decoration: const InputDecoration(
                  labelText: 'Amount paid now (optional)',
                  border: OutlineInputBorder(),
                  helperText: 'Rest becomes customer debt',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_paymentType == 'mpesa' ||
                _paymentType == 'bank' ||
                _paymentType == 'card') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: _paymentType == 'mpesa'
                      ? 'M-Pesa reference (required)'
                      : _paymentType == 'bank'
                          ? 'Bank reference (required)'
                          : 'Card reference (optional)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_isCredit) ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                child: const ListTile(
                  leading: Icon(Icons.warning, color: Colors.red),
                  title: Text('Credit / debt sale'),
                  subtitle: Text('Unpaid balance will be recorded as debt.'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _customer == null ? 'Select customer (required)' : _customer!.name,
                ),
                subtitle: _customer?.phone == null
                    ? null
                    : Text(_customer!.phone!),
                trailing: const Icon(Icons.person_search),
                onTap: _pickCustomer,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Review & complete'),
            ),
          ],
        ),
      ),
    );
  }
}
