import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class DeletePaymentPurposeScreens extends StatefulWidget {
  const DeletePaymentPurposeScreens({super.key});

  @override
  _DeletePaymentPurposeScreenState createState() =>
      _DeletePaymentPurposeScreenState();
}

class _DeletePaymentPurposeScreenState
    extends State<DeletePaymentPurposeScreens> {
  List<PaymentPurpose> _paymentPurposes = [];
  List<PaymentPurpose> _selectedPurposes = [];
  bool _showDeleted = false; // ✅ Toggle to show deleted purposes
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPaymentPurposes();
  }

  Future<void> _fetchPaymentPurposes() async {
    setState(() => _isLoading = true);

    final box = await Hive.box<PaymentPurpose>('payment_purposes');

    // ✅ Filter by term and deletion status
    List<PaymentPurpose> purposes =
        box.values.where((purpose) => purpose.termId == globalTermId).toList();

    // ✅ If not showing deleted, filter them out
    if (!_showDeleted) {
      purposes = purposes.where((p) => !(p.isDeleted ?? false)).toList();
    }

    setState(() {
      _paymentPurposes = purposes;
      _isLoading = false;
    });
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Purpose Deletion Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ✅ SOFT DELETE - Mark as deleted with sync flags
  Future<void> _deleteSelectedPurposes() async {
    if (_selectedPurposes.isEmpty) {
      _showDialog('No Payment Purpose Selected');
      return;
    }

    // ✅ Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to soft-delete the selected payment purposes?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: ${_selectedPurposes.length} purpose(s)',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will mark them as deleted and sync to host.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    final studentPaymentBox =
        await Hive.openBox<StudentPayment>('student_payments');
    int deletedCount = 0;

    for (var selectedPurpose in _selectedPurposes) {
      final name = selectedPurpose.paymentPurpose.toLowerCase().trim();
      final termId = selectedPurpose.termId;

      // ✅ Find ALL payment purposes with same name & termId (case-insensitive)
      final purposesToDelete = paymentPurposeBox.values
          .where((p) =>
              p.paymentPurpose.toLowerCase().trim() == name &&
              p.termId == termId &&
              !(p.isDeleted ?? false)) // ✅ Only delete active ones
          .toList();

      debugPrint(
          '🗑 Found ${purposesToDelete.length} purposes to soft-delete for "$name"');

      // 🔁 Soft delete purposes
      for (var dup in purposesToDelete) {
        final key = paymentPurposeBox.keyAt(
          paymentPurposeBox.values.toList().indexOf(dup),
        );

        // ✅ Mark as deleted with sync flags
        dup.markDeleted(
          deletedBy: 'User: ${dup.paymentPurpose}',
          reason: 'Soft deleted from DeletePaymentPurposeScreens',
        );

        // ✅ Ensure all sync flags are set
        dup.syncStatus = false;
        dup.deletedSyncStatus = false;
        dup.operationType = 'delete';
        dup.lastModified = DateTime.now();
        dup.modifiedFields = [
          'isDeleted',
          'deletedAt',
          'deletedBy',
          'deleteReason',
          'deletedSyncStatus',
          'syncStatus',
          'operationType',
          'lastModified'
        ];

        await paymentPurposeBox.put(key, dup);
        debugPrint(
            '🗑 Soft-deleted PaymentPurpose key: $key → ${dup.paymentPurpose}');
        deletedCount++;
      }

      // ✅ Soft delete related student payments
      final paymentsToDelete = studentPaymentBox.values
          .where((payment) =>
              payment.paymentPurpose.toLowerCase().trim() == name &&
              payment.termId == termId)
          .toList();

      for (var payment in paymentsToDelete) {
        final key = payment.key;
        if (key != null) {
          final updatedPayment = payment.copyWith(
            syncStatus: false,
            lastModified: DateTime.now(),
            operationType: 'delete',
            modifiedFields: [
              ...(payment.modifiedFields ?? []),
              'syncStatus',
              'operationType',
              'lastModified'
            ],
          );
          await studentPaymentBox.put(key, updatedPayment);
          debugPrint('🗑 Soft-deleted StudentPayment key: $key');
        }
      }
    }

    _showDialog(
        '✅ $deletedCount Payment Purpose(s) soft-deleted successfully!\n\n'
        'They will sync to host when online.');

    // Refresh UI
    setState(() {
      _selectedPurposes.clear();
      _isLoading = false;
    });
    await _fetchPaymentPurposes();
  }

  // ✅ RESTORE deleted purpose
  Future<void> _restorePurpose(PaymentPurpose purpose) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Restore payment purpose:\n\n'
          '${purpose.paymentPurpose}\n'
          'Amount: \$${purpose.purposeAmount?.toStringAsFixed(2) ?? '0.00'}\n'
          'Deleted: ${purpose.deletedAt?.toLocal() ?? 'Unknown'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final paymentPurposeBox =
        await Hive.box<PaymentPurpose>('payment_purposes');
    final key = paymentPurposeBox.keyAt(
      paymentPurposeBox.values.toList().indexOf(purpose),
    );

    // ✅ Restore the purpose
    purpose.restoreDeleted();
    purpose.syncStatus = false;
    purpose.deletedSyncStatus = false;
    purpose.operationType = 'update';
    purpose.lastModified = DateTime.now();
    purpose.modifiedFields = [
      'isDeleted',
      'deletedAt',
      'deletedBy',
      'deleteReason',
      'deletedSyncStatus',
      'syncStatus',
      'operationType',
      'lastModified'
    ];

    await paymentPurposeBox.put(key, purpose);
    debugPrint(
        '♻️ Restored PaymentPurpose key: $key → ${purpose.paymentPurpose}');

    _showDialog('✅ Payment Purpose restored successfully!\n\n'
        '${purpose.paymentPurpose}\n'
        'Restoration will sync to host when online.');

    setState(() => _isLoading = false);
    await _fetchPaymentPurposes();
  }

  // ✅ Delete All Purposes (Soft Delete)
  Future<void> _deleteAllPurposes() async {
    setState(() => _isLoading = true);

    final paymentPurposeBox =
        await Hive.box<PaymentPurpose>('payment_purposes');
    final studentPaymentBox =
        await Hive.box<StudentPayment>('student_payments');

    // ✅ Get all active purposes
    final purposesToDelete = paymentPurposeBox.values
        .where((p) => p.termId == globalTermId && !(p.isDeleted ?? false))
        .toList();

    if (purposesToDelete.isEmpty) {
      _showDialog('No active payment purposes to delete.');
      setState(() => _isLoading = false);
      return;
    }

    int deletedCount = 0;

    for (var purpose in purposesToDelete) {
      final key = paymentPurposeBox.keyAt(
        paymentPurposeBox.values.toList().indexOf(purpose),
      );

      // ✅ Mark as deleted
      purpose.markDeleted(
        deletedBy: 'System - Bulk Delete',
        reason: 'Bulk delete all payment purposes',
      );
      purpose.syncStatus = false;
      purpose.deletedSyncStatus = false;
      purpose.operationType = 'delete';
      purpose.lastModified = DateTime.now();
      purpose.modifiedFields = [
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'deleteReason',
        'deletedSyncStatus',
        'syncStatus',
        'operationType',
        'lastModified'
      ];

      await paymentPurposeBox.put(key, purpose);
      deletedCount++;

      // ✅ Soft delete related student payments
      final paymentsToDelete = studentPaymentBox.values
          .where((payment) =>
              payment.paymentPurpose.toLowerCase().trim() ==
                  purpose.paymentPurpose.toLowerCase().trim() &&
              payment.termId == purpose.termId)
          .toList();

      for (var payment in paymentsToDelete) {
        final pKey = payment.key;
        if (pKey != null) {
          final updatedPayment = payment.copyWith(
            syncStatus: false,
            lastModified: DateTime.now(),
            operationType: 'delete',
            modifiedFields: [
              ...(payment.modifiedFields ?? []),
              'syncStatus',
              'operationType',
              'lastModified'
            ],
          );
          await studentPaymentBox.put(pKey, updatedPayment);
        }
      }
    }

    _showDialog(
        '✅ $deletedCount Payment Purpose(s) soft-deleted successfully!\n\n'
        'They will sync to host when online.');

    setState(() {
      _selectedPurposes.clear();
      _isLoading = false;
    });
    await _fetchPaymentPurposes();
  }

  void _confirmDeleteAllPurposes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ALL Payment Purposes?'),
        content: const Text(
          'This will soft-delete all payment purposes and related student payment records for the current term.\n\n'
          'They will be marked as deleted and synced to the host.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Delete All'),
            onPressed: () {
              Navigator.pop(context);
              _deleteAllPurposes();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  // ✅ Toggle show deleted
  void _toggleShowDeleted() {
    setState(() {
      _showDeleted = !_showDeleted;
    });
    _fetchPaymentPurposes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Payment Purpose'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        foregroundColor: Colors.white,
        elevation: 4.0,
        actions: [
          // ✅ Toggle to show deleted purposes
          IconButton(
            icon: Icon(
              _showDeleted ? Icons.visibility : Icons.visibility_off,
              color: _showDeleted ? Colors.amber : Colors.white,
            ),
            onPressed: _toggleShowDeleted,
            tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete All Purposes',
            onPressed: _confirmDeleteAllPurposes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing... Please wait.'),
                ],
              ),
            )
          : CenteredFormContainer(
              title: _showDeleted
                  ? 'Delete Payment Purpose (Showing Deleted)'
                  : 'Delete Payment Purpose',
              child: Column(
                children: [
                  // ✅ Show count info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_paymentPurposes.length} purpose(s)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      if (_showDeleted)
                        const Chip(
                          label: Text('Showing Deleted'),
                          backgroundColor: Colors.red,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        ..._paymentPurposes.map((paymentPurpose) {
                          final isDeleted = paymentPurpose.isDeleted ?? false;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Card(
                              elevation: 2,
                              color: isDeleted ? Colors.grey.shade100 : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isDeleted
                                    ? BorderSide(color: Colors.grey.shade400)
                                    : BorderSide.none,
                              ),
                              child: isDeleted
                                  ? ListTile(
                                      leading: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.grey,
                                      ),
                                      title: Text(
                                        paymentPurpose.paymentPurpose,
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          color: Colors.grey,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Amount: \$${paymentPurpose.purposeAmount?.toStringAsFixed(2) ?? '0.00'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (paymentPurpose.deletedAt != null)
                                            Text(
                                              'Deleted: ${paymentPurpose.deletedAt!.toLocal()}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.red,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.restore,
                                          color: Colors.green,
                                        ),
                                        onPressed: () =>
                                            _restorePurpose(paymentPurpose),
                                        tooltip: 'Restore',
                                      ),
                                    )
                                  : CheckboxListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            paymentPurpose.paymentPurpose,
                                            style: const TextStyle(
                                              fontSize: 14.0,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            'Amount: \$${paymentPurpose.purposeAmount?.toStringAsFixed(2) ?? '0.00'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (paymentPurpose
                                                      .associatedClasses !=
                                                  null &&
                                              paymentPurpose.associatedClasses!
                                                  .isNotEmpty)
                                            Text(
                                              'Classes: ${paymentPurpose.associatedClasses!.join(", ")}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                      value: _selectedPurposes
                                          .contains(paymentPurpose),
                                      onChanged: (isChecked) {
                                        setState(() {
                                          if (isChecked == true) {
                                            _selectedPurposes
                                                .add(paymentPurpose);
                                          } else {
                                            _selectedPurposes
                                                .remove(paymentPurpose);
                                          }
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor:
                                          Theme.of(context).primaryColor,
                                    ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 32),
                        if (_selectedPurposes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected: ${_selectedPurposes.length} purpose(s)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _deleteSelectedPurposes,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete Selected'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
