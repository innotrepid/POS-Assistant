import 'package:flutter/material.dart';

import '../../core/models/customer.dart';
import '../../services/customer_service.dart';

Future<Customer?> showCustomerPicker(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const CustomerPickerSheet(),
  );
}

class CustomerPickerSheet extends StatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  final _service = CustomerService();
  final _search = TextEditingController();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() => _loading = true);
    try {
      final list = (query == null || query.trim().isEmpty)
          ? await _service.getAllCustomers()
          : await _service.searchCustomers(query);
      if (!mounted) return;
      setState(() {
        _customers = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customers = [];
        _loading = false;
      });
    }
  }

  Future<void> _createCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      final customer = await _service.createCustomer(
        name: nameCtrl.text,
        phone: phoneCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(customer);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Select customer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'New customer',
                    onPressed: _createCustomer,
                    icon: const Icon(Icons.person_add),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search name or phone',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _load(query: v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? const Center(
                          child: Text('No customers. Tap + to add one.'),
                        )
                      : ListView.separated(
                          itemCount: _customers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            return ListTile(
                              title: Text(c.name),
                              subtitle: c.phone == null ? null : Text(c.phone!),
                              onTap: () => Navigator.of(context).pop(c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
