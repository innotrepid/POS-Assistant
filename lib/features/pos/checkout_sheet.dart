import 'package:flutter/material.dart';

import '../../core/models/customer.dart';
import '../../core/utils/money.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';
import 'customer_picker_sheet.dart';

class CheckoutResult {
  final String saleId;
  final double total;
  final String paymentType;

  const CheckoutResult({
    required this.saleId,
    required this.total,
    required this.paymentType,
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
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  Customer? _customer;
  bool _submitting = false;
  String? _error;

  double get _subtotal => widget.cart.subtotal;

  double get _discount => Money.parse(_discountController.text);

  double get _total {
    final t = Money.round(_subtotal - _discount);
    return t < 0 ? 0 : t;
  }

  bool get _needsCustomer {
    if (_paymentType == 'credit') return true;
    final paid = Money.parse(_paidController.text);
    return paid < _total;
  }

  @override
  void initState() {
    super.initState();
    _paidController.text = _total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _paidController.dispose();
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
      final paid = Money.parse(_paidController.text);
      final discount = Money.parse(_discountController.text);

      if (_needsCustomer && _customer == null) {
        throw ArgumentError('Select a customer for credit or partial payment.');
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

      final saleId = await widget.salesService.createSale(
        customerId: _customer?.id,
        items: items,
        paidAmount: paid,
        discount: discount,
        paymentType: _paymentType,
        paymentReference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        CheckoutResult(
          saleId: saleId,
          total: _total,
          paymentType: _paymentType,
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
            Text(
              'Checkout',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Subtotal ${Money.format(_subtotal)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              decoration: const InputDecoration(
                labelText: 'Sale discount',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                setState(() {
                  if (_paymentType != 'credit') {
                    _paidController.text = _total.toStringAsFixed(2);
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
                for (final type in ['cash', 'mpesa', 'card', 'credit'])
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
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paidController,
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            if (_paymentType == 'mpesa') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'M-Pesa reference',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_needsCustomer) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _customer == null
                      ? 'Select customer'
                      : _customer!.name,
                ),
                subtitle: _customer?.phone == null
                    ? const Text('Required for credit / balance')
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
                  : const Text('Complete sale'),
            ),
          ],
        ),
      ),
    );
  }
}
