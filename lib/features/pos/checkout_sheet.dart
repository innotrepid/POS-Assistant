import 'package:flutter/material.dart';

import '../../core/models/customer.dart';
import '../../core/safety/safety_dialogs.dart';
import '../../core/utils/money.dart';
import '../../services/debtor_service.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';
import 'customer_picker_sheet.dart';

// RESTORE_MARKER - full file follows in same content
class CheckoutResult {
  final String saleId;
  final double total;
  final String paymentType;
  final double changeGiven;
  const CheckoutResult({required this.saleId, required this.total, required this.paymentType, this.changeGiven = 0});
}

class CheckoutSheet extends StatefulWidget {
  final CartController cart;
  final SalesService salesService;
  const CheckoutSheet({super.key, required this.cart, required this.salesService});
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
  double get _change {
    if (_splitMode || _paymentType != 'cash') return 0;
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
    if (selected != null && mounted) setState(() => _customer = selected);
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final discount = Money.parse(_discountController.text);
      if (_isCredit && _customer == null) {
        throw ArgumentError('Select a customer for credit sale.');
      }
      final ref = _referenceController.text.trim();
      if ((_paymentType == 'mpesa' || _paymentType == 'bank') && ref.isEmpty) {
        throw ArgumentError('${_paymentType.toUpperCase()} requires a reference.');
      }
      final items = widget.cart.lines.map((line) => SaleLineInput(
        productId: line.isQuickSale ? null : line.product?.id,
        productName: line.name,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        unitCost: line.isQuickSale ? null : line.product?.costPrice,
        discount: line.discount,
        isQuickSale: line.isQuickSale,
      )).toList();

      List<PaymentInput> payments;
      if (_isCredit) {
        final paid = Money.parse(_paidController.text);
        payments = paid > 0
            ? [PaymentInput(paymentType: 'cash', amount: paid, reference: ref.isEmpty ? null : ref)]
            : const [];
      } else if (_paymentType == 'cash') {
        payments = [PaymentInput(paymentType: 'cash', amount: Money.parse(_tenderedController.text), reference: ref.isEmpty ? null : ref)];
      } else {
        payments = [PaymentInput(paymentType: _paymentType, amount: Money.parse(_paidController.text), reference: ref.isEmpty ? null : ref)];
      }

      final result = await widget.salesService.createSale(
        customerId: _customer?.id,
        items: items,
        discount: discount,
        isCreditSale: _isCredit,
        amountTendered: _paymentType == 'cash' ? Money.parse(_tenderedController.text) : null,
        payments: payments,
        warningsAcknowledged: const [],
      );
      if (!mounted) return;
      Navigator.of(context).pop(CheckoutResult(
        saleId: result.saleId,
        total: _total,
        paymentType: _paymentType,
        changeGiven: result.changeGiven,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _submitting = false; });
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
              decoration: const InputDecoration(labelText: 'Sale discount (amount)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {
                if (!_isCredit) {
                  _paidController.text = _total.toStringAsFixed(2);
                  _tenderedController.text = _total.toStringAsFixed(2);
                }
              }),
            ),
            const SizedBox(height: 8),
            Text('Total ${Money.format(_total)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ['cash', 'mpesa', 'card', 'bank', 'credit'])
                  ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: _paymentType == type,
                    onSelected: (_) => setState(() {
                      _paymentType = type;
                      if (type == 'credit') {
                        _paidController.text = '0';
                      } else {
                        _paidController.text = _total.toStringAsFixed(2);
                        _tenderedController.text = _total.toStringAsFixed(2);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_paymentType == 'cash') ...[
              TextField(
                controller: _tenderedController,
                decoration: const InputDecoration(labelText: 'Cash received', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              if (_change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Change ${Money.format(_change)}'),
                ),
            ] else if (!_isCredit) ...[
              TextField(
                controller: _paidController,
                decoration: const InputDecoration(labelText: 'Amount paid', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ] else ...[
              TextField(
                controller: _paidController,
                decoration: const InputDecoration(labelText: 'Amount paid now (optional)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(_customer?.name ?? 'Select customer'),
                trailing: const Icon(Icons.person_search),
                onTap: _pickCustomer,
              ),
            ],
            if (_paymentType == 'mpesa' || _paymentType == 'bank') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: _paymentType == 'mpesa' ? 'M-Pesa reference' : 'Bank reference',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Working…' : 'Complete sale'),
            ),
          ],
        ),
      ),
    );
  }
}
