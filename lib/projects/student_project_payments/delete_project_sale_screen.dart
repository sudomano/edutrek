import 'package:flutter/material.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';

Future<void> showSoftDeleteTransactionDialog(
  BuildContext context,
  ProjectSaleTransaction transaction,
) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Transaction'),
      content: const Text(
        'This will mark the transaction as deleted. You can restore it later.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            transaction
              ..isDeleted = true
              ..deletedAt!.add(DateTime.now())
              ..operationType = 'delete'
              ..lastModified = DateTime.now();

            await transaction.save();

            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
