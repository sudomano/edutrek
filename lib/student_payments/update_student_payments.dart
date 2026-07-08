import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class UpdatePaymentScreen extends StatefulWidget {
  const UpdatePaymentScreen({Key? key}) : super(key: key);

  @override
  _UpdatePaymentScreenState createState() => _UpdatePaymentScreenState();
}

class _UpdatePaymentScreenState extends State<UpdatePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentSearchController = TextEditingController();
  Student? _selectedStudent;
  StudentPayment? _selectedPayment;
  PaymentPurpose? _selectedPaymentPurpose;
  double? _paymentAmount;
  String? _receiptNumber;
  DateTime _paymentDate = DateTime.now();
  List<StudentPayment> _studentPayments = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 1. SEARCH STUDENT (Only Active Students)
  // =========================================================================
  void _searchStudent() {
    final query = _studentSearchController.text.trim();

    if (query.isEmpty) {
      _showDialog('Please enter a surname to search');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studentBox = Hive.box<Student>('students');

      // ✅ ONLY SEARCH ACTIVE (NON-DELETED) STUDENTS
      final matchingStudents = studentBox.values
          .where((student) =>
              student.surname.toLowerCase().contains(query.toLowerCase()) &&
              student.terms!.contains(globalTermId!) &&
              !(student.isDeleted ?? false)) // ✅ FILTER OUT DELETED
          .toList();

      setState(() => _isLoading = false);

      if (matchingStudents.isEmpty) {
        _showDialog('No matching students found for "$query"');
      } else {
        _showStudentSelectionDialog(matchingStudents);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('Error searching students: $e');
    }
  }

  // =========================================================================
  // 2. STUDENT SELECTION DIALOG
  // =========================================================================
  void _showStudentSelectionDialog(List<Student> students) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a Student'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  title: Text('${student.name} ${student.surname}'),
                  subtitle: Text(
                      'Class: ${student.class_} | ID: ${student.studentIdNumber}'),
                  onTap: () {
                    setState(() {
                      _selectedStudent = student;
                      _getStudentPayments();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 3. GET STUDENT PAYMENTS (Only Active Payments)
  // =========================================================================
  void _getStudentPayments() {
    if (_selectedStudent == null) return;

    setState(() => _isLoading = true);

    try {
      final paymentBox = Hive.box<StudentPayment>('student_payments');

      // ✅ ONLY FETCH ACTIVE (NON-DELETED) PAYMENTS
      final payments = paymentBox.values
          .where((payment) =>
              payment.studentName.toLowerCase() ==
                  _selectedStudent!.name.toLowerCase() &&
              payment.studentSurname.toLowerCase() ==
                  _selectedStudent!.surname.toLowerCase() &&
              payment.termId == globalTermId &&
              !(payment.isDeleted ?? false)) // ✅ FILTER OUT DELETED
          .toList();

      setState(() {
        _studentPayments = payments;
        _isLoading = false;
      });

      if (payments.isEmpty) {
        _showDialog(
            'No active payments found for ${_selectedStudent!.name} ${_selectedStudent!.surname}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('Error fetching payments: $e');
    }
  }

  // =========================================================================
  // 4. SHOW UPDATE DIALOG
  // =========================================================================
  void _showUpdateDialog(StudentPayment payment) {
    _selectedPayment = payment;
    final isDeleted = payment.isDeleted ?? false;

    // ✅ FILTER OUT DELETED PAYMENT PURPOSES
    final allPurposes = Hive.box<PaymentPurpose>('payment_purposes')
        .values
        .where((p) => !(p.isDeleted ?? false)) // ✅ FILTER OUT DELETED
        .toList();

    _selectedPaymentPurpose = allPurposes.firstWhere(
        (purpose) =>
            purpose.paymentPurpose.toLowerCase() ==
                payment.paymentPurpose.toLowerCase() &&
            purpose.termId == globalTermId,
        orElse: () => PaymentPurpose(
            paymentPurpose: '',
            termId: globalTermId,
            id: -1,
            purposeAmount: -1));

    _paymentAmount = payment.amountToPay;
    _paymentDate = payment.paymentDate;
    _receiptNumber = payment.receiptNumber;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  const Text('Update Payment'),
                  if (isDeleted) ...[
                    const Spacer(),
                    const Chip(
                      label: Text('DELETED'),
                      backgroundColor: Colors.red,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ],
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDeleted) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '⚠️ This payment is marked as deleted.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (payment.deletedAt != null)
                              Text(
                                'Deleted: ${payment.deletedAt!.toLocal()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            if (payment.deletedBy != null)
                              Text(
                                'By: ${payment.deletedBy}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            if (payment.deleteReason != null)
                              Text(
                                'Reason: ${payment.deleteReason}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Student Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Class: ${_selectedStudent!.class_}'),
                          Text('Receipt: ${payment.receiptNumber ?? 'N/A'}'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Payment Purpose (Read-only)
                    Text(
                      'Purpose: ${_selectedPaymentPurpose?.paymentPurpose.toUpperCase() ?? 'None'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Payment Amount
                    TextFormField(
                      initialValue: _paymentAmount?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !isDeleted,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        _paymentAmount = double.tryParse(value);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Payment Date
                    ListTile(
                      title: const Text('Payment Date'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(_paymentDate),
                        style: TextStyle(
                          color: isDeleted ? Colors.grey : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.calendar_today,
                          color: isDeleted ? Colors.grey : null,
                        ),
                        onPressed: isDeleted
                            ? null
                            : () async {
                                final selectedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _paymentDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (selectedDate != null) {
                                  setStateDialog(() {
                                    _paymentDate = selectedDate;
                                  });
                                }
                              },
                      ),
                    ),

                    if (isDeleted)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Cannot update a deleted payment. Restore it first.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (!isDeleted)
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _updatePayment(payment);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Update Payment'),
                  ),
                if (isDeleted)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _restorePayment(payment);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Payment'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 5. UPDATE PAYMENT (Preserve Deletion Status)
  // =========================================================================
  Future<void> _updatePayment(StudentPayment payment) async {
    if (_selectedPayment == null) {
      _showDialog('Please select a payment to update');
      return;
    }

    if (_selectedPaymentPurpose == null) {
      _showDialog('Please select a payment purpose');
      return;
    }

    if (_paymentAmount == null || _paymentAmount! <= 0) {
      _showDialog('Please enter a valid payment amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

      List<String> modifiedFields = payment.modifiedFields ?? [];

      // Track changes
      if (payment.receiptNumber != _receiptNumber) {
        if (!modifiedFields.contains('receiptNumber')) {
          modifiedFields.add('receiptNumber');
        }
      }

      if (payment.paymentPurpose.toLowerCase() !=
          _selectedPaymentPurpose!.paymentPurpose.toLowerCase()) {
        if (!modifiedFields.contains('paymentPurpose')) {
          modifiedFields.add('paymentPurpose');
        }
      }

      if (payment.amountToPay != _paymentAmount) {
        if (!modifiedFields.contains('amountToPay')) {
          modifiedFields.add('amountToPay');
        }
      }

      if (payment.paymentDate != _paymentDate) {
        if (!modifiedFields.contains('paymentDate')) {
          modifiedFields.add('paymentDate');
        }
      }

      if (payment.termId != globalTermId) {
        if (!modifiedFields.contains('termId')) {
          modifiedFields.add('termId');
        }
      }

      // ✅ PRESERVE DELETION STATUS
      final updatedPayment = payment.copyWith(
        paymentPurpose: _selectedPaymentPurpose!.paymentPurpose,
        receiptNumber: _receiptNumber,
        amountToPay: _paymentAmount!,
        paymentDate: _paymentDate,
        termId: globalTermId,
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'update',
        modifiedFields: modifiedFields,
        // ✅ Preserve deletion fields
        isDeleted: payment.isDeleted ?? false,
        deletedAt: payment.deletedAt,
        deletedBy: payment.deletedBy,
        deleteReason: payment.deleteReason,
        deletedSyncStatus: payment.deletedSyncStatus ?? false,
      );

      if (payment.key != null) {
        await paymentBox.put(payment.key, updatedPayment);
      } else {
        await paymentBox.add(updatedPayment);
      }

      setState(() => _isLoading = false);
      _showDialog('✅ Payment updated successfully');

      // Refresh the list
      _getStudentPayments();
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error updating payment: $e');
    }
  }

  // =========================================================================
  // 6. RESTORE DELETED PAYMENT
  // =========================================================================
  Future<void> _restorePayment(StudentPayment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Restore payment:\n\n'
          'Purpose: ${payment.paymentPurpose}\n'
          'Amount: \$${payment.amountToPay?.toStringAsFixed(2) ?? '0.00'}\n'
          'Student: ${payment.studentName} ${payment.studentSurname}\n'
          'Deleted: ${payment.deletedAt?.toLocal() ?? 'Unknown'}',
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
      final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

      // ✅ Restore the payment
      payment.restoreDeleted();
      payment.syncStatus = false;
      payment.deletedSyncStatus = false;
      payment.operationType = 'update';
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

      if (payment.key != null) {
        await paymentBox.put(payment.key, payment);
      } else {
        await paymentBox.add(payment);
      }

      setState(() => _isLoading = false);
      _showDialog('✅ Payment restored successfully!\n'
          'Purpose: ${payment.paymentPurpose}\n'
          'Restoration will sync to host when online.');

      // Refresh the list
      _getStudentPayments();
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('❌ Error restoring payment: $e');
    }
  }

  // =========================================================================
  // 7. HELPER: Show Dialog
  // =========================================================================
  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Update Feedback"),
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
  // 8. BUILD UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Update Student Payment'),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(255, 255, 255, 1),
                    Color.fromARGB(255, 231, 240, 239),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // ✅ Search Field
                  TextFormField(
                    controller: _studentSearchController,
                    decoration: InputDecoration(
                      labelText: 'Search Student by Surname or Name',
                      hintText: 'e.g. Smith, John, 2024-001',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchStudent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _searchStudent(),
                  ),

                  const SizedBox(height: 16),

                  // ✅ Selected Student Info
                  if (_selectedStudent != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedStudent!.name} ${_selectedStudent!.surname}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Class: ${_selectedStudent!.class_} | ID: ${_selectedStudent!.studentIdNumber}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedStudent = null;
                                _studentPayments.clear();
                              });
                            },
                            tooltip: 'Clear selection',
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ✅ Payment List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _studentPayments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      size: 64,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedStudent == null
                                          ? 'Search and select a student first'
                                          : 'No active payments found for this student',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _studentPayments.length,
                                itemBuilder: (context, index) {
                                  final payment = _studentPayments[index];
                                  final isDeleted = payment.isDeleted ?? false;

                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    color:
                                        isDeleted ? Colors.grey.shade100 : null,
                                    child: ListTile(
                                      leading: isDeleted
                                          ? const Icon(Icons.delete_outline,
                                              color: Colors.grey)
                                          : Icon(
                                              Icons.payment,
                                              color: Colors.blue.shade700,
                                            ),
                                      title: Text(
                                        '${payment.paymentPurpose.toUpperCase()}',
                                        style: TextStyle(
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDeleted ? Colors.grey : null,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Amount: \$${payment.amountToPay?.toStringAsFixed(2) ?? '0.00'}',
                                            style: TextStyle(
                                              decoration: isDeleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isDeleted
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                          ),
                                          Text(
                                            'Date: ${DateFormat('yyyy-MM-dd').format(payment.paymentDate)}',
                                            style: TextStyle(
                                              decoration: isDeleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isDeleted
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                          ),
                                          if (isDeleted &&
                                              payment.deletedAt != null)
                                            Text(
                                              'Deleted: ${payment.deletedAt!.toLocal()}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red),
                                            ),
                                        ],
                                      ),
                                      trailing: isDeleted
                                          ? IconButton(
                                              icon: const Icon(Icons.restore,
                                                  color: Colors.green),
                                              onPressed: () =>
                                                  _restorePayment(payment),
                                              tooltip: 'Restore Payment',
                                            )
                                          : const Icon(Icons.edit,
                                              color: Colors.blue),
                                      onTap: isDeleted
                                          ? () => _showUpdateDialog(
                                              payment) // ✅ Show dialog even for deleted (with restore option)
                                          : () => _showUpdateDialog(payment),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
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
