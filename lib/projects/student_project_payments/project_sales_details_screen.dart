import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/projects/student_project_payments/delete_project_sale_screen.dart';
import 'package:zitf_system/projects/student_project_payments/update_project_sale_screen.dart';

class ProjectSaleTransactionDetailScreen extends StatelessWidget {
  final ProjectSaleTransaction transaction;

  const ProjectSaleTransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final hasArrears = (transaction.arrears ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectSaleTransactionUpdateScreen(
                    transaction: transaction,
                  ),
                ),
              );

              if (updated == true && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () =>
                showSoftDeleteTransactionDialog(context, transaction),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Student ID', transaction.studentId),
                    _row('Project', transaction.projectCode),
                    _row('Item', transaction.sellUnitNameSnapshot),
                    _row('Quantity', transaction.quantitySold.toString()),
                    _row('Payment Method', transaction.paymentMethod),
                    _row('Currency', transaction.currency ?? ''),
                    _row(
                      'Total Amount',
                      transaction.totalAmount.toStringAsFixed(2),
                    ),
                    _row(
                      'Paid',
                      transaction.amountPaid.toStringAsFixed(2),
                    ),
                    if (hasArrears)
                      _row(
                        'Arrears',
                        transaction.arrears!.toStringAsFixed(2),
                        valueColor: Colors.red,
                      ),
                    _row(
                      'Date',
                      DateFormat.yMMMMd()
                          .add_jm()
                          .format(transaction.transactionDate),
                    ),
                    if (transaction.referenceNumber != null)
                      _row(
                        'Reference',
                        transaction.referenceNumber!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              transaction.delete();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
