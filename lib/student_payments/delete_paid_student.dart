import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class DeletePaidStudentBySurname extends StatefulWidget {
  const DeletePaidStudentBySurname({Key? key}) : super(key: key);

  @override
  _DeletePaidStudentBySurnameState createState() =>
      _DeletePaidStudentBySurnameState();
}

class _DeletePaidStudentBySurnameState
    extends State<DeletePaidStudentBySurname> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  List<StudentPayment> _matchingPayments = [];
  List<StudentPayment> _deletedPayments = [];
  bool _isLoading = false;
  bool _showDeleted = false; // ✅ Toggle to show deleted payments

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 1. SEARCH PAYMENTS (Only Active Payments)
  // =========================================================================
  void _searchPaymentsBySurname() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _showDialog('Please enter a surname to search');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

      // ✅ ONLY SEARCH ACTIVE (NON-DELETED) PAYMENTS
      List<StudentPayment> payments = paymentBox.values
          .where((payment) =>
              payment.studentSurname.toLowerCase().contains(query) &&
              payment.termId == globalTermId &&
              !(payment.isDeleted ?? false)) // ✅ FILTER OUT DELETED
          .toList();

      // ✅ Also fetch deleted payments for this student if showing deleted
      if (_showDeleted) {
        final deleted = paymentBox.values
            .where((payment) =>
                payment.studentSurname.toLowerCase().contains(query) &&
                payment.termId == globalTermId &&
                (payment.isDeleted ?? false))
            .toList();
        _deletedPayments = deleted;
      } else {
        _deletedPayments = [];
      }

      setState(() {
        _matchingPayments = payments;
        _isLoading = false;
      });

      if (payments.isEmpty && _deletedPayments.isEmpty) {
        _showDialog('No payments found for "$query"');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('Error searching payments: $e');
    }
  }

  // =========================================================================
  // 2. SOFT DELETE PAYMENT
  // =========================================================================
  void _deletePayment(StudentPayment paymentToDelete) async {
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
              'Soft delete this payment record?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
                'Student: ${paymentToDelete.studentName} ${paymentToDelete.studentSurname}'),
            Text('Purpose: ${paymentToDelete.paymentPurpose}'),
            Text(
                'Amount: \$${paymentToDelete.amountToPay?.toStringAsFixed(2) ?? '0.00'}'),
            const SizedBox(height: 8),
            const Text(
              'This will mark it as deleted and sync to host.',
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

    try {
      final box = await Hive.openBox<StudentPayment>('student_payments');
      final key = box.keys.firstWhere(
        (k) {
          final p = box.get(k);
          return p?.id == paymentToDelete.id;
        },
        orElse: () => throw Exception('Payment not found'),
      );

      // ✅ Get the current payment
      final currentPayment = box.get(key);
      if (currentPayment == null) {
        throw Exception('Payment data is null');
      }

      // ✅ Mark as SOFT DELETED with sync flags
      currentPayment.markDeleted(
        deletedBy:
            'User: ${currentPayment.studentName} ${currentPayment.studentSurname}',
        reason: 'Soft deleted from DeletePaidStudentBySurname',
      );

      // ✅ Ensure all sync flags are properly set
      currentPayment.syncStatus = false; // ⭐ Needs sync
      currentPayment.deletedSyncStatus = false; // ⭐ Deletion needs sync
      currentPayment.operationType = 'delete'; // ⭐ Operation type
      currentPayment.lastModified = DateTime.now(); // ⭐ Timestamp
      currentPayment.modifiedFields = [
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'deleteReason',
        'deletedSyncStatus',
        'syncStatus',
        'operationType',
        'lastModified'
      ];

      // ✅ Save the updated (soft-deleted) payment
      await box.put(key, currentPayment);

      _showDialog('✅ Payment soft-deleted successfully!\n\n'
          'Student: ${currentPayment.studentName} ${currentPayment.studentSurname}\n'
          'Purpose: ${currentPayment.paymentPurpose}\n'
          'Amount: \$${currentPayment.amountToPay?.toStringAsFixed(2) ?? '0.00'}\n'
          'Deletion will sync to host when online.');

      // ✅ Remove from active list
      setState(() {
        _matchingPayments.remove(paymentToDelete);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error deleting payment: $e');
    }
  }

  // =========================================================================
  // 3. RESTORE DELETED PAYMENT
  // =========================================================================
  void _restorePayment(StudentPayment paymentToRestore) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Restore payment record?\n\n'
          'Student: ${paymentToRestore.studentName} ${paymentToRestore.studentSurname}\n'
          'Purpose: ${paymentToRestore.paymentPurpose}\n'
          'Amount: \$${paymentToRestore.amountToPay?.toStringAsFixed(2) ?? '0.00'}\n'
          'Deleted: ${paymentToRestore.deletedAt?.toLocal() ?? 'Unknown'}',
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

    try {
      final box = await Hive.openBox<StudentPayment>('student_payments');
      final key = box.keys.firstWhere(
        (k) {
          final p = box.get(k);
          return p?.id == paymentToRestore.id;
        },
        orElse: () => throw Exception('Payment not found'),
      );

      final currentPayment = box.get(key);
      if (currentPayment == null) {
        throw Exception('Payment data is null');
      }

      // ✅ Restore the payment
      currentPayment.restoreDeleted();
      currentPayment.syncStatus = false;
      currentPayment.deletedSyncStatus = false;
      currentPayment.operationType = 'update';
      currentPayment.lastModified = DateTime.now();
      currentPayment.modifiedFields = [
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'deleteReason',
        'deletedSyncStatus',
        'syncStatus',
        'operationType',
        'lastModified'
      ];

      await box.put(key, currentPayment);

      _showDialog('✅ Payment restored successfully!\n\n'
          'Student: ${currentPayment.studentName} ${currentPayment.studentSurname}\n'
          'Purpose: ${currentPayment.paymentPurpose}\n'
          'Restoration will sync to host when online.');

      // ✅ Remove from deleted list and refresh search
      setState(() {
        _deletedPayments.remove(paymentToRestore);
        _isLoading = false;
      });

      // ✅ Re-run search to refresh lists
      _searchPaymentsBySurname();
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error restoring payment: $e');
    }
  }

  // =========================================================================
  // 4. SOFT DELETE ALL PAYMENTS
  // =========================================================================
  void _confirmDeleteAllPayments() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Payments'),
          content: const Text(
            'Are you sure you want to soft-delete ALL payment records for the current term?\n\n'
            'This will mark them as deleted and sync to host.\n'
            'This action can be reversed by restoring individual payments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllPayments();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAllPayments() async {
    setState(() => _isLoading = true);

    try {
      final box = await Hive.openBox<StudentPayment>('student_payments');

      // ✅ Only get ACTIVE (non-deleted) payments for current term
      final paymentsToDelete = box.values
          .where((payment) =>
              payment.termId == globalTermId && !(payment.isDeleted ?? false))
          .toList();

      if (paymentsToDelete.isEmpty) {
        setState(() => _isLoading = false);
        _showDialog('No active payments to delete.');
        return;
      }

      int deletedCount = 0;

      for (var payment in paymentsToDelete) {
        try {
          final key = box.keys.firstWhere(
            (k) {
              final p = box.get(k);
              return p?.id == payment.id;
            },
            orElse: () => throw Exception('Payment not found'),
          );

          // ✅ Mark as SOFT DELETED
          payment.markDeleted(
            deletedBy: 'System - Bulk Delete',
            reason: 'Bulk delete all payments for current term',
          );
          payment.syncStatus = false;
          payment.deletedSyncStatus = false;
          payment.operationType = 'delete';
          payment.lastModified = DateTime.now();
          payment.modifiedFields = [
            'isDeleted',
            'deletedAt',
            'deletedBy',
            'deleteReason',
            'deletedSyncStatus',
            'syncStatus',
            'operationType',
            'lastModified'
          ];

          await box.put(key, payment);
          deletedCount++;
        } catch (e) {
          debugPrint('Error deleting payment ${payment.id}: $e');
        }
      }

      _showDialog('✅ $deletedCount payment(s) soft-deleted successfully!\n\n'
          'They will sync to host when online.');

      setState(() {
        _matchingPayments.clear();
        _deletedPayments.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error deleting all payments: $e');
    }
  }

  // =========================================================================
  // 5. TOGGLE SHOW DELETED
  // =========================================================================
  void _toggleShowDeleted() {
    setState(() {
      _showDeleted = !_showDeleted;
    });
    if (_searchController.text.isNotEmpty) {
      _searchPaymentsBySurname();
    }
  }

  // =========================================================================
  // 6. HELPER: Show Dialog
  // =========================================================================
  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Delete Feedback"),
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

  // =========================================================================
  // 7. BUILD UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    // ✅ Combine active and deleted payments for display
    List<StudentPayment> displayPayments = List.from(_matchingPayments);
    if (_showDeleted) {
      displayPayments.addAll(_deletedPayments);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Paid Student by Surname',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // ✅ Toggle to show deleted payments
          IconButton(
            icon: Icon(
              _showDeleted ? Icons.visibility : Icons.visibility_off,
              color: _showDeleted ? Colors.amber : Colors.white,
            ),
            onPressed: _toggleShowDeleted,
            tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.white,
            ),
            onPressed: _confirmDeleteAllPayments,
            tooltip: 'Delete All Payments',
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Search Field
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Enter Surname to Search',
                          hintText: 'e.g. Smith, John',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _matchingPayments.clear();
                                      _deletedPayments.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (_) => _searchPaymentsBySurname(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a surname';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ✅ Status Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active: ${_matchingPayments.length} payments',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          if (_showDeleted)
                            Text(
                              'Deleted: ${_deletedPayments.length} payments',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ✅ Search Button
                      Center(
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _searchPaymentsBySurname,
                          child: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ Payment List
                      if (displayPayments.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: displayPayments.length,
                            itemBuilder: (context, index) {
                              final payment = displayPayments[index];
                              final isDeleted = payment.isDeleted ?? false;

                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                                color: isDeleted ? Colors.grey.shade100 : null,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: isDeleted
                                      ? const Icon(Icons.delete_outline,
                                          color: Colors.grey)
                                      : const Icon(Icons.payment,
                                          color: Colors.blue),
                                  title: Text(
                                    '${payment.studentName} ${payment.studentSurname}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      decoration: isDeleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDeleted ? Colors.grey : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Class: ${payment.studentClass} | Amount: \$${payment.amountToPay?.toStringAsFixed(2) ?? '0.00'}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDeleted ? Colors.grey : null,
                                        ),
                                      ),
                                      Text(
                                        'Purpose: ${payment.paymentPurpose}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDeleted ? Colors.grey : null,
                                        ),
                                      ),
                                      if (isDeleted &&
                                          payment.deletedAt != null)
                                        Text(
                                          'Deleted: ${payment.deletedAt!.toLocal()}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      if (isDeleted &&
                                          payment.deleteReason != null)
                                        Text(
                                          'Reason: ${payment.deleteReason}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isDeleted
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.restore,
                                            color: Colors.green,
                                          ),
                                          onPressed: () =>
                                              _restorePayment(payment),
                                          tooltip: 'Restore Payment',
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deletePayment(payment),
                                          tooltip: 'Soft Delete',
                                        ),
                                ),
                              );
                            },
                          ),
                        ),

                      if (displayPayments.isEmpty && !_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.payment,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No payments found for this search',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Processing...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
