/*import 'package:flutter/material.dart';
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

  Student? _selectedStudent;
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
    final studentBox = await Hive.openBox<Student>('students');
    final projectBox = await Hive.openBox<Project>('projects');
    final projectItemBox = await Hive.openBox<ProjectItem>('projectItems');

    setState(() {
      _students = studentBox.values.toList();
      _projects = projectBox.values.toList();
      _projectItems = projectItemBox.values.toList();
      _searchResults = _students; // Initialize search results.
    });
  }

  Future<void> _processPayment() async {
    debugPrint(
        '[DEBUG] Processing Payment for Student: ${_selectedStudent?.name} (${_selectedStudent?.studentIdNumber})');

    if (_formKey.currentState!.validate()) {
      final paymentBox =
          await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
      final amountPaid = double.parse(_amountController.text);

      // Search for an existing payment record.
      final existingPaymentss =
          paymentBox.values.cast<ProjectStudentPayment>().where(
                (payment) =>
                    payment.studentId == _selectedStudent?.studentIdNumber &&
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
          studentId: _selectedStudent!.studentIdNumber.toString(),
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
        const SnackBar(content: Text('Payment processed successfully')),
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
              student.terms!.contains(globalTermId))
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
                              labelText: 'Searche Student',
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
                                        student.terms!.contains(globalTermId))
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
                                        subtitle: Text(
                                            'ID: ${student.studentIdNumber} | Class: ${student.class_}'),
                                        onTap: () {
                                          debugPrint(
                                              '[DEBUG] Student selected in modal: ${student.name} (${student.studentIdNumber})');
                                          Navigator.pop(context);
                                          setState(() {
                                            _selectedStudent = student;
                                          });
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
      title: 'Make Student Project Paymentss',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: _selectedStudent == null
                  ? const Text('Select Student')
                  : Text(
                      'Selected: ${_selectedStudent!.studentIdNumber} - ${_selectedStudent!.name} ${_selectedStudent!.surname} ${_selectedStudent!.class_} ${_selectedStudent!.terms?.join(', ') ?? ''}'),
              subtitle: Text('ID: ${_selectedStudent?.studentIdNumber ?? ''}'),
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
              decoration: const InputDecoration(labelText: 'Select Project'),
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
              decoration: const InputDecoration(labelText: 'Select Item'),
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
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter amount' : null,
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  debugPrint(
                      '[DEBUG] Submit tapped for student: ${_selectedStudent?.name} (${_selectedStudent?.studentIdNumber})');
                  _selectedStudent == null ? null : _processPayment();
                },
                child: const Text('Submit Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 */