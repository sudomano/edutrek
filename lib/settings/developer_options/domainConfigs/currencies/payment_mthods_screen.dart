import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/database/projects/payment_method_model.dart';
import 'package:zitf_system/settings/developer_options/domainConfigs/currencies/payment_method_ui_rules.dart';

class PaymentMethodsSettingsScreen extends StatelessWidget {
  const PaymentMethodsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<PaymentMethod>('payment_methods');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<PaymentMethod> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('No payment methods configured'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: box.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final method = box.getAt(i)!;

              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(method.methodType ?? 'Unnamed Method'),
                subtitle: Text(
                  [
                    if (method.provider != null) method.provider,
                    if (method.currency != null) method.currency,
                  ].join(' • '),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      _openEditor(context, method: method);
                    } else if (v == 'delete') {
                      _confirmDelete(context, method);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void _openEditor(BuildContext context, {PaymentMethod? method}) {
  String selectedMethod = method?.safeMethodType ?? 'cash';

  final amountCtrl =
      TextEditingController(text: method?.amount?.toString() ?? '');
  final currencyCtrl =
      TextEditingController(text: method?.safeCurrency ?? 'USD');
  final providerCtrl = TextEditingController(text: method?.provider ?? '');
  final phoneCtrl = TextEditingController(text: method?.phoneNumber ?? '');
  final refCtrl = TextEditingController(text: method?.reference ?? '');
  final accNumberCtrl =
      TextEditingController(text: method?.accountNumber ?? '');
  final accNameCtrl = TextEditingController(text: method?.accountName ?? '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          final visibleFields = paymentMethodFields[selectedMethod] ?? [];

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method == null
                        ? 'Add Payment Method'
                        : 'Edit Payment Method',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// METHOD TYPE DROPDOWN
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration:
                        const InputDecoration(labelText: 'Payment Method'),
                    items: paymentMethodFields.keys
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.replaceAll('_', ' ').toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => selectedMethod = v!);
                    },
                  ),

                  if (visibleFields.contains('amount'))
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),

                  if (visibleFields.contains('currency'))
                    TextField(
                      controller: currencyCtrl,
                      decoration: const InputDecoration(labelText: 'Currency'),
                    ),

                  if (visibleFields.contains('provider'))
                    TextField(
                      controller: providerCtrl,
                      decoration: const InputDecoration(labelText: 'Provider'),
                    ),

                  if (visibleFields.contains('phoneNumber'))
                    TextField(
                      controller: phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number'),
                    ),

                  if (visibleFields.contains('accountNumber'))
                    TextField(
                      controller: accNumberCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account Number'),
                    ),

                  if (visibleFields.contains('accountName'))
                    TextField(
                      controller: accNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account Name'),
                    ),

                  if (visibleFields.contains('reference'))
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(labelText: 'Reference'),
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final box = Hive.box<PaymentMethod>('payment_methods');

                        final updated = (method ?? PaymentMethod()).copyWith(
                          methodType: selectedMethod,
                          amount: double.tryParse(amountCtrl.text),
                          currency: currencyCtrl.text.trim(),
                          provider: providerCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim(),
                          reference: refCtrl.text.trim(),
                          accountNumber: accNumberCtrl.text.trim(),
                          accountName: accNameCtrl.text.trim(),
                          paymentDate: DateTime.now(),
                          lastModified: DateTime.now(),
                          operationType: method == null ? 'create' : 'update',
                        );

                        if (method == null) {
                          box.add(updated);
                        } else {
                          method
                            ..methodType = updated.methodType
                            ..amount = updated.amount
                            ..currency = updated.currency
                            ..provider = updated.provider
                            ..phoneNumber = updated.phoneNumber
                            ..reference = updated.reference
                            ..accountNumber = updated.accountNumber
                            ..accountName = updated.accountName
                            ..lastModified = updated.lastModified
                            ..operationType = 'update'
                            ..save();
                        }

                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _confirmDelete(BuildContext context, PaymentMethod method) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Payment Method'),
      content: const Text(
        'This will remove the payment method from the system.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            method.delete();
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
