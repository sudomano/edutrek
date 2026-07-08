import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'update_payment_purpose_screen.dart';

class SelectPaymentPurposeToUpdate extends StatefulWidget {
  const SelectPaymentPurposeToUpdate({super.key});

  @override
  _SelectPaymentPurposeToUpdateState createState() =>
      _SelectPaymentPurposeToUpdateState();
}

class _SelectPaymentPurposeToUpdateState
    extends State<SelectPaymentPurposeToUpdate> {
  bool _showDeleted = false;
  List<PaymentPurpose> _filteredPaymentPurposes = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentPurposes();
  }

  void _loadPaymentPurposes() {
    final box = Hive.box<PaymentPurpose>('payment_purposes');

    // ✅ Filter by term and deletion status
    final purposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();

    // ✅ If not showing deleted, filter them out
    if (!_showDeleted) {
      _filteredPaymentPurposes =
          purposes.where((p) => !(p.isDeleted ?? false)).toList();
    } else {
      _filteredPaymentPurposes = purposes;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Select Purpose to Update',
        actions: [
          // ✅ Toggle to show deleted purposes
          IconButton(
            icon: Icon(
              _showDeleted ? Icons.visibility : Icons.visibility_off,
              color: _showDeleted ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDeleted = !_showDeleted;
                _loadPaymentPurposes();
              });
            },
            tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _filteredPaymentPurposes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No payment purposes available for this term.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a new payment purpose or check other terms.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredPaymentPurposes.length,
                  itemBuilder: (context, index) {
                    final paymentPurpose = _filteredPaymentPurposes[index];
                    final isDeleted = paymentPurpose.isDeleted ?? false;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: isDeleted ? Colors.grey.shade100 : null,
                      child: ListTile(
                        leading: isDeleted
                            ? const Icon(Icons.delete_outline,
                                color: Colors.grey)
                            : const Icon(Icons.payment, color: Colors.blue),
                        title: Text(
                          paymentPurpose.paymentPurpose ?? 'Unnamed',
                          style: TextStyle(
                            decoration:
                                isDeleted ? TextDecoration.lineThrough : null,
                            color: isDeleted ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount: \$${paymentPurpose.purposeAmount?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(
                                decoration: isDeleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDeleted ? Colors.grey : null,
                              ),
                            ),
                            if (paymentPurpose.associatedClasses != null &&
                                paymentPurpose.associatedClasses!.isNotEmpty)
                              Text(
                                'Classes: ${paymentPurpose.associatedClasses!.join(", ")}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDeleted
                                      ? Colors.grey
                                      : Colors.grey.shade600,
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            if (paymentPurpose.exceptions != null &&
                                paymentPurpose.exceptions!.isNotEmpty)
                              Text(
                                'Exceptions: ${paymentPurpose.exceptions!.map((e) => e.exceptionName).join(", ")}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDeleted
                                      ? Colors.grey
                                      : Colors.grey.shade600,
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            if (isDeleted && paymentPurpose.deletedAt != null)
                              Text(
                                'Deleted: ${DateFormat('yyyy-MM-dd HH:mm').format(paymentPurpose.deletedAt!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                        trailing: isDeleted
                            ? const Icon(
                                Icons.block,
                                color: Colors.grey,
                              )
                            : const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                        onTap: isDeleted
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        UpdatePaymentPurposeScreen(
                                      existingPurpose: paymentPurpose,
                                    ),
                                  ),
                                );
                              },
                        // ✅ Disable tap for deleted items
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
