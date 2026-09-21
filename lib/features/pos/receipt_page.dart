import 'package:flutter/material.dart';

import '../../core/safety/safety_dialogs.dart';
import '../../core/utils/money.dart';
import '../../services/business_profile_service.dart';
import '../../services/sales_service.dart';
import '../../services/security_service.dart';
import '../security/lock_screen.dart';

class ReceiptPage extends StatefulWidget {
  final String saleId;

  const ReceiptPage({super.key, required this.saleId});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _sales = SalesService();
  final _security = SecurityService();
  final _profiles = BusinessProfileService.instance;
  Map<String, dynamic>? _sale;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _payments = [];
  String _shopName = 'Mercate';
  bool _loading = true;
  bool _voiding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale = await _sales.getSale(widget.saleId);
      final items = await _sales.getSaleItems(widget.saleId);
      final payments = await _sales.getSalePayments(widget.saleId);
      final name = await _profiles.getBusinessName();
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _items = items;
        _payments = payments;
        _shopName = name;
        _loading = false;
        if (sale == null) _error = 'Sale not found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _voidSale() async {
    final sale = _sale;
    if (sale == null) return;

    final status = sale['sale_status'] as String? ?? '';
    if (status != 'completed' && status != 'partially_refunded') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot void a $status sale')),
      );
      return;
    }

    final paid = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
    final total = (sale['total'] as num?)?.toDouble() ?? 0;
    final balance = (sale['balance'] as num?)?.toDouble() ?? 0;

    final confirm = await showSafetyWarning(
      context,
      title: 'Void this sale?',
      whatHappened:
          'Sale total ${Money.format(total)}. '
          'Paid ${Money.format(paid)} will be recorded as refunded. '
          '${balance > 0 ? 'Debt ${Money.format(balance)} will be reversed. ' : ''}'
          'Catalogue stock will be restored.',
      whyItMatters:
          'Voiding cannot be undone. Historical line prices stay on the receipt.',
      affected: 'Sale ${widget.saleId.substring(0, 8)}…',
      proceedLabel: 'Continue',
      level: SafetyLevel.critical,
    );
    if (!confirm || !mounted) return;

    if (await _sales.isLargeRefund(paid > 0 ? paid : total)) {
      final largeOk = await showSafetyWarning(
        context,
        title: 'Large refund',
        whatHappened:
            'Refund amount ${Money.format(paid > 0 ? paid : total)} '
            'is at or above the large-refund threshold.',
        whyItMatters: 'Double-check before returning this much money or stock.',
        level: SafetyLevel.critical,
        proceedLabel: 'I understand',
      );
      if (!largeOk || !mounted) return;
    }

    final identityOk = await _security.requireUnlock(
      biometricReason: 'Confirm void / refund',
      promptPin: () => promptPinDialog(context, title: 'PIN to void sale'),
    );
    if (!identityOk || !mounted) return;

    final reasonCtrl = TextEditingController();
    final reasonOk = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reason for void'),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Void sale'),
            ),
          ],
        );
      },
    );
    if (reasonOk != true || !mounted) return;

    setState(() => _voiding = true);
    try {
      final result = await _sales.voidSale(
        saleId: widget.saleId,
        reason: reasonCtrl.text,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sale voided · refunded ${Money.format(result.refundedAmount)}'
            '${result.stockRestored ? ' · stock restored' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _voiding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _sale?['sale_status'] as String? ?? '';
    final canVoid =
        (status == 'completed' || status == 'partially_refunded') && !_voiding;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          if (canVoid)
            TextButton(onPressed: _voidSale, child: const Text('Void')),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final sale = _sale!;
    final total = (sale['total'] as num?)?.toDouble() ?? 0;
    final paid = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = (sale['balance'] as num?)?.toDouble() ?? 0;
    final discount = (sale['discount'] as num?)?.toDouble() ?? 0;
    final subtotal = (sale['subtotal'] as num?)?.toDouble() ?? 0;
    final payStatus = sale['payment_status'] as String? ?? '';
    final saleStatus = sale['sale_status'] as String? ?? '';
    final created = sale['created_at'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Image.asset(
            'assets/images/mercate_logo.png',
            height: 56,
            errorBuilder: (_, __, ___) => Icon(
              Icons.storefront,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _shopName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          created,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (saleStatus == 'voided') ...[
          const SizedBox(height: 8),
          const Center(
            child: Chip(
              avatar: Icon(Icons.block, size: 18),
              label: Text('VOIDED'),
              backgroundColor: Colors.red,
            ),
          ),
        ],
        const Divider(height: 32),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['product_name']} × ${item['quantity']}',
                  ),
                ),
                Text(
                  Money.format((item['total'] as num?)?.toDouble() ?? 0),
                ),
              ],
            ),
          ),
        const Divider(height: 32),
        _row('Subtotal', Money.format(subtotal)),
        if (discount > 0) _row('Discount', '- ${Money.format(discount)}'),
        _row('Total', Money.format(total), bold: true),
        _row('Paid', Money.format(paid)),
        if (balance > 0) _row('Balance', Money.format(balance)),
        if (_payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Payments', style: Theme.of(context).textTheme.titleSmall),
          for (final p in _payments)
            _row(
              '${p['payment_type']}'
              '${(p['reference'] as String?)?.isNotEmpty == true ? ' · ${p['reference']}' : ''}',
              Money.format((p['amount'] as num?)?.toDouble() ?? 0),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          'Status: $saleStatus · $payStatus',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Sale ID: ${widget.saleId}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
