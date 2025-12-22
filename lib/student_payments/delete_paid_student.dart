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

  void _searchPaymentsBySurname() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _showDialog('Please enter a surname to search');
      return;
    }

    final paymentBox = await Hive.openBox<StudentPayment>('student_payments');
    final payments = paymentBox.values
        .where((payment) =>
            payment.studentSurname
                .toLowerCase()
                .contains(query.toLowerCase()) &&
            payment.termId == globalTermId)
        .toList();

    setState(() {
      _matchingPayments = payments;
    });
  }

  void _deletePayment(StudentPayment paymentToDelete) async {
    final box = await Hive.openBox<StudentPayment>('student_payments');
    final key = box.keys.firstWhere((k) => box.get(k) == paymentToDelete);
    await box.delete(key);

    _showDialog('Payment record deleted successfully');

    setState(() {
      _matchingPayments.remove(paymentToDelete);
    });
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Delete Submission Feedback"),
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

  void _confirmDeleteAllPayments() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Payments'),
          content: const Text(
              'Are you sure you want to delete all payment records? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllPayments,
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
    final box = await Hive.openBox<StudentPayment>('student_payments');

    // Retrieve payments with the current global term ID
    final paymentsToDelete =
        box.values.where((payment) => payment.termId == globalTermId).toList();

    for (var payment in paymentsToDelete) {
      final key = box.keys.firstWhere((k) => box.get(k) == payment);
      await box.delete(key);
    }

    _showDialog(
        'All payment records for the current term deleted successfully');

    setState(() {
      _matchingPayments.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Paid Student by Surname',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.white,
            ),
            onPressed: _confirmDeleteAllPayments,
            tooltip: 'Delete All Payments',
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Enter Surname to Search',
                      filled: true,
                      fillColor: const Color.fromARGB(255, 137, 133, 133)
                          .withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a surname';
                      }
                      return null;
                    },
                  ),
                  Center(child: const SizedBox(height: 20)),
                  Center(
                    child: ElevatedButton(
                      onPressed: _searchPaymentsBySurname,
                      child: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_matchingPayments.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _matchingPayments.length,
                        itemBuilder: (context, index) {
                          final payment = _matchingPayments[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                '${payment.studentName} ${payment.studentSurname}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Class: ${payment.studentClass} | Amount Paid: ${payment.amountToPay} | Purpose: ${payment.paymentPurpose}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deletePayment(payment),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_matchingPayments.isEmpty)
                    const Center(
                      child: Text(
                        'No payments found for this surname',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
