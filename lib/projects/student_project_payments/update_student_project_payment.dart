import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateStudentPaymentForm extends StatefulWidget {
  @override
  _UpdateStudentPaymentFormState createState() =>
      _UpdateStudentPaymentFormState();
}

class _UpdateStudentPaymentFormState extends State<UpdateStudentPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedStudentId;
  String? _selectedProjectCode;
  String? _selectedItemId;

  List<Student> _students = [];
  List<Student> _searchResults = [];
  List<Project> _projects = [];
  List<ProjectItem> _projectItems = [];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final studentBox = Hive.box<Student>('students');
    final projectBox = Hive.box<Project>('projects');
    final projectItemBox = Hive.box<ProjectItem>('projectItems');

    setState(() {
      _students = studentBox.values.toList();
      _projects = projectBox.values.toList();
      _projectItems = projectItemBox.values.toList();
      _searchResults = _students;
    });
  }

  Future<void> _updatePayment() async {
    if (_formKey.currentState!.validate()) {
      final paymentBox =
          Hive.box<ProjectStudentPayment>('projectStudentPayments');
      final amountPaid = double.parse(_amountController.text);
      final Box<ProjectItem> box =
          await Hive.openBox<ProjectItem>('projectItems');

      final List<ProjectItem> filteredPaymentPurposes = box.values
          .where((paymentPurpose) =>
              paymentPurpose.projectItemCode == _selectedItemId)
          .toList();

      final itemAmount = filteredPaymentPurposes.first.amount;
      debugPrint('Item Amount: $itemAmount');

      // Find existing payment record
      final existingPayments =
          paymentBox.values.cast<ProjectStudentPayment>().where(
                (payment) =>
                    payment.studentId == _selectedStudentId &&
                    payment.projectCode == _selectedProjectCode &&
                    payment.itemId == _selectedItemId,
              );
      ProjectStudentPayment? existingPayment =
          existingPayments.isNotEmpty ? existingPayments.first : null;

      if (existingPayment != null) {
        // Update the existing payment record
        existingPayment
          ..amountPaid = amountPaid
          ..balance = itemAmount - amountPaid
          ..lastModified = DateTime.now()
          ..syncStatus = false
          ..operationType = 'update';
        existingPayment.save();

        debugPrint(
            'Payment Updated: ${existingPayment.amountPaid}, New Balance: ${existingPayment.balance}');
      } else {
        // No existing payment found; provide feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No existing payment found for update')),
        );
      }

      // Reset form
      _formKey.currentState!.reset();
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment updated successfully')),
      );
    }
  }

  void _searchStudent(String query) {
    setState(() {
      _searchResults = _students
          .where((student) =>
              (student.name.toLowerCase().contains(query.toLowerCase()) ||
                  student.surname
                      .toLowerCase()
                      .contains(query.toLowerCase())) &&
              student.termId == globalTermId)
          .toList();
    });
  }

  void _showStudentSearchModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search Student',
                              suffixIcon: Icon(Icons.search),
                            ),
                            onChanged: (query) {
                              setState(() {
                                _searchResults = _students
                                    .where((student) =>
                                        (student.name.toLowerCase().contains(
                                                query.toLowerCase()) ||
                                            student.surname
                                                .toLowerCase()
                                                .contains(
                                                    query.toLowerCase())) &&
                                        student.termId == globalTermId)
                                    .toList();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _searchResults.isEmpty
                                ? const Center(
                                    child: Text("No students found."))
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final student = _searchResults[index];
                                      return ListTile(
                                        title: Text(
                                            '${student.name} ${student.surname}'),
                                        onTap: () {
                                          setState(() {
                                            _selectedStudentId =
                                                student.studentIdNumber;
                                          });
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ProjectItem> _filteredProjectItems = _projectItems.where((item) {
      return item.projectCode == _selectedProjectCode;
    }).toList();
    return CenteredFormContainer(
      title: 'Update Student Project Payment',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                _selectedStudentId == null
                    ? 'Select Student'
                    : 'Selected: $_selectedStudentId',
              ),
              trailing: const Icon(Icons.search),
              onTap: _showStudentSearchModal,
            ),
            DropdownButtonFormField<String>(
              value: _selectedProjectCode,
              items: _projects
                  .map((project) => DropdownMenuItem(
                        value: project.projectCode,
                        child: Text(project.name),
                      ))
                  .toList(),
              decoration: InputDecoration(labelText: 'Select Project'),
              onChanged: (value) {
                setState(() {
                  _selectedProjectCode = value;
                  // Filter items based on the selected project code
                  _filteredProjectItems = _projectItems
                      .where((item) => item.projectCode == _selectedProjectCode)
                      .toList();
                  // Reset the selected item when project changes
                  _selectedItemId = null;
                });
                _populateAmountField(); // Update the amount field
              },
              validator: (value) =>
                  value == null ? 'Please select a project' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedItemId,
              items: _filteredProjectItems
                  .map((item) => DropdownMenuItem(
                        value: item.projectItemCode,
                        child: Text('${item.projectItemCode}  ${item.name}'),
                      ))
                  .toList(),
              decoration: InputDecoration(labelText: 'Select Item'),
              onChanged: (value) {
                setState(() {
                  _selectedItemId = value;
                });
                _populateAmountField(); // Update the amount field
              },
              validator: (value) =>
                  value == null ? 'Please select an item' : null,
            ),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter amount' : null,
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _updatePayment,
                child: const Text('Update Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _populateAmountField() async {
    if (_selectedStudentId != null &&
        _selectedProjectCode != null &&
        _selectedItemId != null) {
      final paymentBox =
          Hive.box<ProjectStudentPayment>('projectStudentPayments');

      // Filter matching payment records
      final matchingPayments =
          paymentBox.values.cast<ProjectStudentPayment>().where(
                (payment) =>
                    payment.studentId == _selectedStudentId &&
                    payment.projectCode == _selectedProjectCode &&
                    payment.itemId == _selectedItemId,
              );

      if (matchingPayments.isNotEmpty) {
        final existingPayment = matchingPayments.first;
        setState(() {
          _amountController.text = existingPayment.amountPaid.toString();
        });
      } else {
        setState(() {
          _amountController.clear();
        });
      }
    }
  }
}
