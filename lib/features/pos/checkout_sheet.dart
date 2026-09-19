import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../../services/sales_service.dart';
import 'cart_controller.dart';

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
  final _customerIdController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  bool _submitting = false;
  String? _error;

  double get _subtotal => widget.cart.subtotal;

  double get _discount => Money.parse(_discountController.text);

  double get _total {
    final t = Money.round(_subtotal - _discount);
    return t < 0 ? 0 : t;
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
    _customerIdController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final paid = Money.parse(_paidController.text);
      final discount = Money.parse(_discountController.text);
      final customerId = _customerIdController.text.trim();

      final items = widget.cart.lines
          .map(
            (line) => SaleLineInput(
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              unitCost: line.product.costPrice,
              discount: line.discount,
            ),
          )
          .toList();

      final saleId = await widget.salesService.createSale(
        customerId: customerId.isEmpty ? null : customerId,
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
            if (_paymentType == 'credit' ||
                Money.parse(_paidController.text) < _total) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customerIdController,
                decoration: const InputDecoration(
                  labelText: 'Customer ID (required for credit)',
                  helperText: 'Paste customer UUID for now — picker comes later',
                  border: OutlineInputBorder(),
                ),
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
