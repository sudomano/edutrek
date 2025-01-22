import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class DeletePaidTeacherBySurname extends StatefulWidget {
  const DeletePaidTeacherBySurname({Key? key}) : super(key: key);

  @override
  _DeletePaidTeacherBySurnameState createState() =>
      _DeletePaidTeacherBySurnameState();
}

class _DeletePaidTeacherBySurnameState
    extends State<DeletePaidTeacherBySurname> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  List<TeacherPayment> _matchingPayments = [];

  void _searchPaymentsBySurname() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter staff surname to search')),
      );
      return;
    }

    final paymentBox = await Hive.openBox<TeacherPayment>('teacher_payments');
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

  void _deletePayment(TeacherPayment paymentToDelete) async {
    final box = await Hive.openBox<TeacherPayment>('teacher_payments');
    final key = box.keys.firstWhere((k) => box.get(k) == paymentToDelete);
    await box.delete(key);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment record deleted successfully')),
    );

    setState(() {
      _matchingPayments.remove(paymentToDelete);
    });
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
    final box = await Hive.openBox<TeacherPayment>('teacher_payments');
    // Retrieve payments with the current global term ID
    final paymentsToDelete =
        box.values.where((payment) => payment.termId == globalTermId).toList();

    for (var payment in paymentsToDelete) {
      final key = box.keys.firstWhere((k) => box.get(k) == payment);
      await box.delete(key);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All payment records deleted successfully')),
    );

    setState(() {
      _matchingPayments.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Paid Staff by Surname',
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
              color: Colors.red,
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
          constraints: const BoxConstraints(maxWidth: 600),
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
                      labelText: 'Enter Staff Surname to Search',
                      filled: true,
                      fillColor: const Color.fromARGB(255, 189, 187, 187)
                          .withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter teacher surname';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
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
                                'Amount Paid: ${payment.amountToPay} | Purpose: ${payment.paymentPurpose}',
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
