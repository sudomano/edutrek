import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class StudentPaymentForm extends StatefulWidget {
  @override
  _StudentPaymentFormState createState() => _StudentPaymentFormState();
}

class _StudentPaymentFormState extends State<StudentPaymentForm> {
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
      _searchResults = _students; // Initialize search results.
    });
  }

  Future<void> _processPayment() async {
    if (_formKey.currentState!.validate()) {
      final paymentBox =
          Hive.box<ProjectStudentPayment>('projectStudentPayments');
      final amountPaid = double.parse(_amountController.text);

      // Search for an existing payment record.
      final existingPaymentss =
          paymentBox.values.cast<ProjectStudentPayment>().where(
                (payment) =>
                    payment.studentId == _selectedStudentId &&
                    payment.projectCode == _selectedProjectCode &&
                    payment.itemId == _selectedItemId,
              );
      ProjectStudentPayment? existingPayment =
          existingPaymentss.isNotEmpty ? existingPaymentss.first : null;

      if (existingPayment != null) {
        // Update existing record.
        debugPrint('Existing payment found. Updating record...');
        existingPayment
          ..amountPaid += amountPaid
          ..balance -= amountPaid // Assuming balance decreases with payment.
          ..lastModified = DateTime.now()
          ..syncStatus = false // Mark as unsynced.
          ..operationType = 'update';
        existingPayment.save();

        debugPrint(
            'Updated Payment: ${existingPayment.amountPaid}, New Balance: ${existingPayment.balance}');
      } else {
        // Create new record.
        debugPrint('No existing payment found. Creating new record...');
        final Box<ProjectItem> box =
            await Hive.openBox<ProjectItem>('projectItems');

        // Filter payment purposes based on termId == globalTermId
        final List<ProjectItem> filteredPaymentPurposes = box.values
            .where((paymentPurpose) =>
                paymentPurpose.projectItemCode == _selectedItemId)
            .toList();

        final itemAmount = filteredPaymentPurposes.first.amount;
        debugPrint('Item Amount: $itemAmount');

        final newPayment = ProjectStudentPayment(
          projectStudentPaymentCode:
              DateTime.now().toIso8601String(), // Unique code.
          studentId: _selectedStudentId!,
          projectCode: _selectedProjectCode!,
          itemId: _selectedItemId!,
          amountPaid: amountPaid,
          balance: itemAmount - amountPaid, // Example balance logic.
          syncStatus: false,
          lastModified: DateTime.now(),
          operationType: 'create',
        );

        paymentBox.add(newPayment);

        debugPrint('New Payment Created: $newPayment');
      }

      // Reset form.
      _formKey.currentState!.reset();
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment processed successfully')),
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
                            decoration: InputDecoration(
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
                          SizedBox(height: 10),
                          Expanded(
                            child: _searchResults.isEmpty
                                ? Center(child: Text("No students found."))
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
      title: 'Make Student Project Payment',
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
              trailing: Icon(Icons.search),
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
              },
              validator: (value) =>
                  value == null ? 'Please select a project' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedItemId,
              items: _filteredProjectItems
                  .map((item) => DropdownMenuItem(
                        value: item.projectItemCode,
                        child: Text('  ${item.name}'),
                      ))
                  .toList(),
              decoration: InputDecoration(labelText: 'Select Item'),
              onChanged: (value) {
                setState(() {
                  _selectedItemId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select an item' : null,
            ),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter amount' : null,
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _processPayment,
                child: Text('Submit Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
