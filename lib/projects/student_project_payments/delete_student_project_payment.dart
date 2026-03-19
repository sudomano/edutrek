/*import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/student.dart';

class DeleteStudentProjectPayment extends StatefulWidget {
  const DeleteStudentProjectPayment({Key? key}) : super(key: key);

  @override
  _DeleteStudentProjectPaymentState createState() =>
      _DeleteStudentProjectPaymentState();
}

class _DeleteStudentProjectPaymentState
    extends State<DeleteStudentProjectPayment> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  List<ProjectStudentPayment> _matchingPayments = [];
  Map<String, String> _studentNames = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final studentBox = await Hive.openBox<Student>('students');
    final paymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');

    setState(() {
      _studentNames = {
        for (var student in studentBox.values)
          student.studentIdNumber.toString(): student.surname
      };
    });
  }

  void _searchPaymentsBySurname() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _showSnackbar('Please enter a surname to search');
      return;
    }

    final matchingStudentIds = _studentNames.entries
        .where((entry) => entry.value.toLowerCase().contains(query))
        .map((entry) => entry.key)
        .toList();

    if (matchingStudentIds.isEmpty) {
      setState(() => _matchingPayments.clear());
      _showSnackbar('No matching surname found');
      return;
    }

    final paymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
    final payments = paymentBox.values
        .where((payment) => matchingStudentIds.contains(payment.studentId))
        .toList();

    setState(() {
      _matchingPayments = payments;
    });
  }

  void _deletePayment(ProjectStudentPayment payment) async {
    final paymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');

    try {
      final key = paymentBox.keys.firstWhere(
        (k) => paymentBox.get(k) == payment,
        orElse: () => null,
      );

      if (key != null) {
        await paymentBox.delete(key);
        setState(() => _matchingPayments.remove(payment));
        _showSnackbar('Payment record deleted successfully');
      } else {
        _showSnackbar('Payment not found');
      }
    } catch (e) {
      debugPrint('Error deleting payment: $e');
      _showSnackbar('Error deleting payment');
    }
  }

  void _confirmDeleteAllPayments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Payments'),
        content: const Text(
          'Are you sure you want to delete all payment records? This action cannot be undone.',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _deleteAllPayments() async {
    final paymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');

    await paymentBox.clear();
    setState(() => _matchingPayments.clear());
    _showSnackbar('All payment records deleted successfully');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ignore: prefer_const_constructors
        title: Center(
            child: const Text(
          'Delete Paid Student by Surname',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _confirmDeleteAllPayments,
            tooltip: 'Delete All Payments',
          ),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0, // Optional: Add a subtle shadow
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Enter Surname to Search',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter a surname'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _searchPaymentsBySurname,
                    child: const Text('Search'),
                  ),
                  const SizedBox(height: 16),
                  if (_matchingPayments.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _matchingPayments.length,
                        itemBuilder: (context, index) {
                          final payment = _matchingPayments[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              title: Text(
                                '${payment.studentId} - ${payment.projectCode}',
                              ),
                              subtitle: Text(
                                'Amount Paid: ${payment.amountPaid} | Purpose: ${payment.itemId}',
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
                    )
                  else
                    const Center(
                        child: Text('No payments found for this surname')),
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
 */