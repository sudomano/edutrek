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
  List<PaymentPurpose> _paymentPurposes = []; // List to hold payment purposes
  List<PaymentPurpose> _selectedPurposes =
      []; // List of selected purposes for deletion

  @override
  void initState() {
    super.initState();
    _fetchPaymentPurposes(); // Fetch payment purposes when screen loads
  }

  Future<void> _fetchPaymentPurposes() async {
    final box = await Hive.box<PaymentPurpose>('payment_purposes');
    final purposes = box.values
        .where((purpose) =>
            purpose.termId == globalTermId) // Filter by globalTermId
        .toList();

    setState(() {
      _paymentPurposes = purposes;
    });
  }

  Future<void> _deleteStudentPayments(String paymentPurpose) async {
    final Box<StudentPayment> studentPaymentBox = Hive.box('student_payments');

    // Filter the StudentPayment records where termId matches globalTermId and paymentPurpose matches
    final List<int> keysToDelete = studentPaymentBox.keys.cast<int>().where(
      (key) {
        final payment = studentPaymentBox.get(key);
        return payment?.termId == globalTermId &&
            payment?.paymentPurpose.toLowerCase() ==
                paymentPurpose.toLowerCase();
      },
    ).toList();

    // Delete all matching records
    for (var key in keysToDelete) {
      await studentPaymentBox.delete(key);
    }
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 School Submission Feedback"),
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

  Future<void> _deleteSelectedPurposes() async {
    if (_selectedPurposes.isEmpty) {
      _showDialog('No Payment Purpose Selected');
      return;
    }

    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');

    for (var selectedPurpose in _selectedPurposes) {
      final name = selectedPurpose.paymentPurpose.toLowerCase().trim();
      final termId = selectedPurpose.termId;

      // 🧹 Find ALL payment purposes with same name & termId (case-insensitive)
      final purposesToDelete = paymentPurposeBox.values
          .where((p) =>
              p.paymentPurpose.toLowerCase().trim() == name &&
              p.termId == termId)
          .toList();

      debugPrint(
          '🗑 Found ${purposesToDelete.length} purposes to delete for "$name"');

      // 🔁 Delete purposes
      for (var dup in purposesToDelete) {
        final key = paymentPurposeBox.keyAt(
          paymentPurposeBox.values.toList().indexOf(dup),
        );
        debugPrint(
            '🗑 Deleting PaymentPurpose key: $key → ${dup.paymentPurpose}');
        await paymentPurposeBox.delete(key);
      }
    }

    _showDialog('Selected Payment Purposes and Related Records Deleted');

    // Refresh UI
    _selectedPurposes.clear();
    await _fetchPaymentPurposes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Payment Purpose'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete All Purposes',
            onPressed: _confirmDeleteAllPurposes,
          ),
        ],
      ),
      body: CenteredFormContainer(
        title: 'Delete Payment Purpose',
        child: ListView(
          children: [
            ..._paymentPurposes.map((paymentPurpose) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CheckboxListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16.0),
                    title: Text(
                      paymentPurpose.paymentPurpose,
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.black87,
                      ),
                    ),
                    value: _selectedPurposes.contains(paymentPurpose),
                    onChanged: (isChecked) {
                      setState(() {
                        if (isChecked == true) {
                          _selectedPurposes.add(paymentPurpose);
                        } else {
                          _selectedPurposes.remove(paymentPurpose);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _deleteSelectedPurposes,
              child: const Text('Delete Selected Payment Purposes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAllPurposes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ALL Payment Purposes?'),
        content: const Text(
          'This will remove all payment purposes and related student payment records across all terms. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete All'),
            onPressed: () {
              Navigator.pop(context);
              _deleteAllPurposes();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllPurposes() async {
    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');

    // 🧹 Then delete all payment purposes
    await paymentPurposeBox.clear();

    _showDialog('All Payment Purposes Deleted Successfully');

    // Refresh list
    _selectedPurposes.clear();
    _fetchPaymentPurposes();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
