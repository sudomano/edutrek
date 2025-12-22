import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class AddTeacherPaymentPurposeScreen extends StatefulWidget {
  const AddTeacherPaymentPurposeScreen({super.key});

  @override
  _AddTeacherPaymentPurposeScreenState createState() =>
      _AddTeacherPaymentPurposeScreenState();
}

class _AddTeacherPaymentPurposeScreenState
    extends State<AddTeacherPaymentPurposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  final _amountController = TextEditingController();
  List<String> _classes = []; // List of class names
  List<String> _selectedClasses = []; // Selected classes

  @override
  void initState() {
    super.initState();
    _fetchClasses(); // Fetch classes when screen loads
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.box<Teachers>('teachers');
    final classes = box.values
        .where((purposeItem) =>
            purposeItem.termId != null &&
            purposeItem.terms!.contains(globalTermId))
        .map((e) => '${e.IdNumber} (${e.surname} ${e.name})')
        .toList();
    setState(() {
      _classes = classes;
    });
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾  Payment Purpose Submission Feedback"),
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

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Payment Purposes',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: 16),
            _buildTextField('Payment Purpose Name', _purposeController),
            const SizedBox(height: 16),
            _buildAmountField('Payment Purpose Amount', _amountController),
            const SizedBox(height: 32),
            _buildClassesList(),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Create Staff Payment Purpose'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildAmountField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildClassesList() {
    // Boolean to track the Select/Deselect All state
    bool _selectAll = _selectedClasses.length == _classes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select/Deselect All Checkbox
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: (isChecked) {
                    setState(() {
                      if (isChecked == true) {
                        // Select all classes
                        _selectedClasses = List.from(_classes);
                      } else {
                        // Deselect all classes
                        _selectedClasses.clear();
                      }
                    });
                  },
                ),
                Text(
                  'Select All',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14.0, // Reduced font size
                        color: Colors.black87, // Slightly muted color
                      ),
                ),
              ],
            ),
          ),
          // List of checkboxes for individual classes
          ..._classes.map((className) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  title: Text(
                    className,
                    style: const TextStyle(
                      fontSize: 14.0, // Reduced font size
                      color:
                          Colors.black87, // Slightly muted for professionalism
                    ),
                  ),
                  value: _selectedClasses.contains(className),
                  onChanged: (isChecked) {
                    setState(() {
                      if (isChecked == true) {
                        _selectedClasses.add(className);
                      } else {
                        _selectedClasses.remove(className);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Theme.of(context)
                      .primaryColor, // Primary color for checked state
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<TeacherPaymentsPurposes>(
        'teacher_payments_purposes');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (globalTermId != null) {
        int newId = await getNextId();

        final paymentPurpose = _purposeController.text.toLowerCase();
        final paymentPurposeCode = uuid.v4();
        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('purposeCode');
        modifiedFields.add('paymentPurpose');
        modifiedFields.add('purposeAmount');
        modifiedFields.add('associatedStaff');
        modifiedFields.add('termId');
        final newPurpose = TeacherPaymentsPurposes(
          id: newId,
          purposeCode: paymentPurposeCode,
          paymentPurpose: paymentPurpose,
          purposeAmount: double.parse(_amountController.text),
          associatedStaff: _selectedClasses,
          termId: globalTermId,
          syncStatus: false, // Set syncStatus to false
          lastModified: DateTime.now(), // Set lastModified to current datetime
          operationType: 'create', // Set operationType to 'create'
          modifiedFields: modifiedFields,
        );

        final box =
            Hive.box<TeacherPaymentsPurposes>('teacher_payments_purposes');
        final existingPurpose =
            box.values.cast<TeacherPaymentsPurposes>().firstWhere(
                  (c) =>
                      (c.paymentPurpose.toLowerCase() ==
                              paymentPurpose.toLowerCase() ||
                          c.purposeCode?.toLowerCase() ==
                              paymentPurposeCode.toLowerCase()) &&
                      c.termId == globalTermId,
                  orElse: () => TeacherPaymentsPurposes(
                    id: -1,
                    paymentPurpose: 'empty',
                    purposeAmount: -0.0,
                    termId: '',
                  ),
                );

        if (existingPurpose.paymentPurpose.toLowerCase() != 'empty') {
          _showDialog('Payment Purpose Already Exists');
          return;
        }

        box.add(newPurpose); // Add the new payment purpose

        _showDialog('Payment Purpose Added Successfully');

        Navigator.pop(context); // Return to the previous screen
      }
    } else {
      _showDialog(
          'No Selected School Term Was Found. Create A New Term or Switch Terms To AnExisting One.');
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
