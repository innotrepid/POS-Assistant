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

class _SplitLeg {
  String type;
  final TextEditingController amountCtrl;
  final TextEditingController refCtrl;

  _SplitLeg({
    this.type = 'cash',
    String amount = '',
  })  : amountCtrl = TextEditingController(text: amount),
        refCtrl = TextEditingController();

  void dispose() {
    amountCtrl.dispose();
    refCtrl.dispose();
  }
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
  bool _splitMode = false;
  String _paymentType = 'cash';
  final _paidController = TextEditingController();
  final _tenderedController = TextEditingController();
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _debtors = DebtorService();
  final List<_SplitLeg> _legs = [];
  Customer? _customer;
  bool _submitting = false;
  String? _error;

  double get _subtotal => widget.cart.subtotal;

  double get _discount => Money.parse(_discountController.text);

  double get _total {
    final t = Money.round(_subtotal - _discount);
    return t < 0 ? 0 : t;
  }

  bool get _isCredit => !_splitMode && _paymentType == 'credit';

  double get _splitPaid {
    var sum = 0.0;
    for (final leg in _legs) {
      sum = Money.round(sum + Money.parse(leg.amountCtrl.text));
    }
    return sum;
  }

  double get _splitRemaining => Money.round(_total - _splitPaid);

  double get _change {
    if (_splitMode) return 0;
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
    for (final leg in _legs) {
      leg.dispose();
    }
    super.dispose();
  }

  void _enterSplitMode() {
    setState(() {
      _splitMode = true;
      _paymentType = 'split';
      for (final leg in _legs) {
        leg.dispose();
      }
      _legs.clear();
      _legs.add(_SplitLeg(type: 'cash', amount: _total.toStringAsFixed(2)));
    });
  }

  void _exitSplitMode(String type) {
    setState(() {
      _splitMode = false;
      _paymentType = type;
      for (final leg in _legs) {
        leg.dispose();
      }
      _legs.clear();
      if (type == 'credit') {
        _paidController.text = '0';
      } else {
        _paidController.text = _total.toStringAsFixed(2);
        _tenderedController.text = _total.toStringAsFixed(2);
      }
    });
  }

  void _addLeg() {
    setState(() {
      final remaining = _splitRemaining;
      _legs.add(
        _SplitLeg(
          type: 'mpesa',
          amount: remaining > 0 ? remaining.toStringAsFixed(2) : '0',
        ),
      );
    });
  }

  void _removeLeg(int index) {
    if (_legs.length <= 1) return;
    setState(() {
      _legs[index].dispose();
      _legs.removeAt(index);
    });
  }

  Future<void> _pickCustomer() async {
    final selected = await showCustomerPicker(context);
    if (selected != null && mounted) {
      setState(() => _customer = selected);
    }
  }

  Future<List<PaymentInput>> _buildPayments() async {
    if (_splitMode) {
      final payments = <PaymentInput>[];
      for (final leg in _legs) {
        final amt = Money.parse(leg.amountCtrl.text);
        if (amt <= 0) continue;
        final type = leg.type;
        final ref = leg.refCtrl.text.trim();
        if ((type == 'mpesa' || type == 'bank') && ref.isEmpty) {
          throw ArgumentError(
            '${type.toUpperCase()} leg requires a transaction/reference number.',
          );
        }
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
              throw StateError('Checkout cancelled (duplicate reference).');
            }
          }
        }
        payments.add(
          PaymentInput(
            paymentType: type,
            amount: amt,
            reference: ref.isEmpty ? null : ref,
          ),
        );
      }
      if (payments.isEmpty) {
        throw ArgumentError('Add at least one payment with amount > 0.');
      }
      return payments;
    }

    final ref = _referenceController.text.trim();
    if ((_paymentType == 'mpesa' || _paymentType == 'bank') && ref.isEmpty) {
      throw ArgumentError(
        '${_paymentType.toUpperCase()} requires a transaction/reference number.',
      );
    }
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
          throw StateError('Checkout cancelled (duplicate reference).');
        }
      }
    }

    if (_isCredit) {
      final paid = Money.parse(_paidController.text);
      if (paid <= 0) return const [];
      return [
        PaymentInput(
          paymentType: 'cash',
          amount: paid,
          reference: ref.isEmpty ? null : ref,
        ),
      ];
    }

    if (_paymentType == 'cash') {
      final tendered = Money.parse(_tenderedController.text);
      return [
        PaymentInput(
          paymentType: 'cash',
          amount: tendered,
          reference: ref.isEmpty ? null : ref,
        ),
      ];
    }

    final paid = Money.parse(_paidController.text);
    return [
      PaymentInput(
        paymentType: _paymentType,
        amount: paid,
        reference: ref.isEmpty ? null : ref,
      ),
    ];
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final discount = Money.parse(_discountController.text);

      if (_splitMode) {
        if (_splitPaid > _total + 0.001) {
          throw ArgumentError(
            'Split payments ${Money.format(_splitPaid)} exceed '
            'total ${Money.format(_total)}.',
          );
        }
        if (_splitRemaining > 0.001 && _customer == null) {
          throw ArgumentError(
            'Split is short by ${Money.format(_splitRemaining)}. '
            'Pay the rest, or select a customer to put the remainder on credit.',
          );
        }
      }

      if ((_isCredit || (_splitMode && _splitRemaining > 0.001)) &&
          _customer == null) {
        throw ArgumentError('Select a customer for credit / remaining balance.');
      }

      final payments = await _buildPayments();

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
              unitName: line.unitName,
              baseQuantity: line.isQuickSale ? null : line.baseQuantity,
            ),
          )
          .toList();

      double? existingBalance;
      if (_customer != null) {
        existingBalance = await _debtors.getBalance(_customer!.id);
      }

      final useCredit =
          _isCredit || (_splitMode && _splitRemaining > 0.001);

      final warnings = await widget.salesService.preflightWarnings(
        items: items,
        discount: discount,
        isCreditSale: useCredit,
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
        if (_splitMode) ...[
          'Split payments:',
          for (final leg in _legs)
            if (Money.parse(leg.amountCtrl.text) > 0)
              '  ${leg.type.toUpperCase()} '
                  '${Money.format(Money.parse(leg.amountCtrl.text))}'
                  '${leg.refCtrl.text.trim().isEmpty ? '' : ' · ${leg.refCtrl.text.trim()}'}',
          if (_splitRemaining > 0.001)
            'Remainder on credit ${Money.format(_splitRemaining)}',
        ] else ...[
          'Payment ${_paymentType.toUpperCase()}',
          if (_paymentType == 'cash')
            'Tendered ${Money.format(Money.parse(_tenderedController.text))}',
          if (_change > 0) 'Change ${Money.format(_change)}',
          if (_isCredit) 'Credit / debt sale',
        ],
        if (_customer != null) 'Customer ${_customer!.name}',
        if (existingBalance != null && existingBalance > 0)
          'Existing debt ${Money.format(existingBalance)}',
      ];

      final confirmed = await showSaleConfirmation(
        context,
        lines: confirmLines,
      );
      if (!confirmed) {
        setState(() => _submitting = false);
        return;
      }

      final result = await widget.salesService.createSale(
        customerId: _customer?.id,
        items: items,
        discount: discount,
        isCreditSale: useCredit,
        amountTendered: !_splitMode && _paymentType == 'cash'
            ? Money.parse(_tenderedController.text)
            : null,
        payments: payments,
        warningsAcknowledged: acknowledged,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        CheckoutResult(
          saleId: result.saleId,
          total: _total,
          paymentType: _splitMode ? 'split' : _paymentType,
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
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {
                if (!_isCredit && !_splitMode) {
                  _paidController.text = _total.toStringAsFixed(2);
                  _tenderedController.text = _total.toStringAsFixed(2);
                }
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Total ${Money.format(_total)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ['cash', 'mpesa', 'card', 'bank', 'credit'])
                  ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: !_splitMode && _paymentType == type,
                    onSelected: (_) => _exitSplitMode(type),
                  ),
                ChoiceChip(
                  label: const Text('SPLIT'),
                  selected: _splitMode,
                  onSelected: (_) => _enterSplitMode(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_splitMode) _buildSplitSection() else _buildSingleSection(),
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

  Widget _buildSingleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_paymentType == 'cash') ...[
          TextField(
            controller: _tenderedController,
            decoration: const InputDecoration(
              labelText: 'Cash received',
              border: OutlineInputBorder(),
              helperText: 'Change is calculated automatically',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          _customerTile(),
        ],
      ],
    );
  }

  Widget _buildSplitSection() {
    final remaining = _splitRemaining;
    final over = _splitPaid > _total + 0.001;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Split payment',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Add legs until the total is covered. Shortfall can go on credit '
          'if a customer is selected.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _legs.length; i++) _legCard(i),
        TextButton.icon(
          onPressed: _addLeg,
          icon: const Icon(Icons.add),
          label: const Text('Add payment leg'),
        ),
        const SizedBox(height: 8),
        Text(
          'Paid ${Money.format(_splitPaid)} / ${Money.format(_total)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: over
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
        if (remaining > 0.001)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Remaining ${Money.format(remaining)} '
              '(will go on credit if customer selected)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (remaining > 0.001 || _customer != null) ...[
          const SizedBox(height: 8),
          _customerTile(),
        ],
      ],
    );
  }

  Widget _legCard(int index) {
    final leg = _legs[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: leg.type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => leg.type = v);
                    },
                  ),
                ),
                if (_legs.length > 1)
                  IconButton(
                    onPressed: () => _removeLeg(index),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: leg.amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            if (leg.type == 'mpesa' || leg.type == 'bank') ...[
              const SizedBox(height: 8),
              TextField(
                controller: leg.refCtrl,
                decoration: InputDecoration(
                  labelText: leg.type == 'mpesa'
                      ? 'M-Pesa reference'
                      : 'Bank reference',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _customerTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        _customer == null
            ? 'Select customer'
            : _customer!.name,
      ),
      subtitle: _customer?.phone != null ? Text(_customer!.phone!) : null,
      trailing: const Icon(Icons.person_search),
      onTap: _pickCustomer,
    );
  }
}
