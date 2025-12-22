import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class AddPaymentPurposeScreen extends StatefulWidget {
  const AddPaymentPurposeScreen({super.key});

  @override
  _AddPaymentPurposeScreenState createState() =>
      _AddPaymentPurposeScreenState();
}

class _AddPaymentPurposeScreenState extends State<AddPaymentPurposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();

  List<String> _classes = []; // List of class names
  List<String> _selectedClasses = []; // Selected classes

  List<ExceptionalStudents> _exceptionNames = [];
  List<ExceptionalStudents> _selectedExceptionNames = [];
  bool _forNewcomersOnly = false;

  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];

  @override
  void initState() {
    super.initState();
    _fetchClasses(); // Fetch classes when screen loads
    _fetchExceptionalStudents(); // <- new
    _loadTerms(); // Load terms on init
  }

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    setState(() {
      _availableTerms = termsBox.values.map((term) => term.termId).toList();
      _selectedTerms = List.from(_availableTerms); // Preselect all
    });
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Purpose Submission Feedback"),
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

  void _fetchExceptionalStudents() async {
    final box =
        await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
    final all = box.values.toList();

    setState(() {
      _exceptionNames = all
          .where((e) => e.exceptionStatus!.toLowerCase() == 'active')
          .toList();
    });
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    final classes = box.values
        .where((purposeItem) =>
            purposeItem.termId != null &&
            purposeItem.terms!.contains(globalTermId))
        .map((e) => e.className)
        .toList();
    setState(() {
      _classes = classes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Payment Purpose',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('Payment Purpose Name', _purposeController),
            const SizedBox(height: 16),
            _buildAmountField('Payment Purpose Amount', _amountController),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text(
              'Exceptional To New Comers ONLY',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            CheckboxListTile(
              title: const Text("Applicable To Newcomers ONLY"),
              value: _forNewcomersOnly,
              onChanged: (val) {
                setState(() {
                  _forNewcomersOnly = val ?? false;
                });
              },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text(
              'Select Other Applicable Exceptions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            MultiSelectDialogField<ExceptionalStudents>(
              items: _exceptionNames
                  .map((e) => MultiSelectItem<ExceptionalStudents>(
                      e, e.exceptionName.toString()))
                  .toList(),
              title: const Text("Exceptional Students"),
              searchable: true,
              listType: MultiSelectListType.CHIP,
              initialValue: _selectedExceptionNames,
              onConfirm: (values) {
                setState(() {
                  _selectedExceptionNames = values;
                });
                print(
                    "🎯 Selected exceptions: ${values.map((e) => e.exceptionName)}");
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedExceptionNames
                  .map((e) => Chip(
                        label: Text(e.exceptionName.toString()),
                        backgroundColor: Colors.blue.shade100,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text(
              'Must Be Paid By Classes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _buildClassesList(),
            const SizedBox(height: 32),
            Text(
              'Apply Payment Purpose To These Terms',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            MultiSelectDialogField<String>(
              items: _availableTerms
                  .map((e) => MultiSelectItem<String>(e, e))
                  .toList(),
              initialValue: _selectedTerms,
              listType: MultiSelectListType.CHIP,
              searchable: true,
              title: const Text("Terms"),
              onConfirm: (values) {
                setState(() {
                  _selectedTerms = values;
                });
              },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Create Payment Purpose'),
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

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTerms.isEmpty) {
        _showDialog('Please select at least one term.');
        return;
      }
      if (globalTermId != null) {
        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('paymentPurpose');
        modifiedFields.add('purposeCode');
        modifiedFields.add('purposeAmount');
        modifiedFields.add('termId');
        modifiedFields.add('associatedClasses');
        modifiedFields.add('associatedExceptions');
        modifiedFields.add('forNewcomersOnly');

        final paymentPurpose = _purposeController.text.toLowerCase();
        for (var termId in _selectedTerms) {
          final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
          int newId = await getNextId();
          final newPkValue = uuid.v4();

          // Check for duplicate in the term
          bool alreadyExists = box.values.any((pp) =>
              pp.paymentPurpose.toLowerCase() == paymentPurpose &&
              pp.termId == termId);

          if (alreadyExists) continue;

          final newPurpose = PaymentPurpose(
            id: newId,
            paymentPurpose: paymentPurpose,
            purposeCode: newPkValue,
            purposeAmount: double.parse(_amountController.text),
            termId: termId,
            associatedClasses: _selectedClasses, // Save the selected classes
            syncStatus: false, // Set syncStatus to false
            lastModified:
                DateTime.now(), // Set lastModified to current datetime
            operationType: 'create', // Set operationType to 'create'
            exceptions: _selectedExceptionNames, // New line
            forNewcomersOnly: _forNewcomersOnly, // New line
            modifiedFields: modifiedFields,
          );

          final existingPurpose = box.values.cast<PaymentPurpose>().firstWhere(
                (c) =>
                    ((c.paymentPurpose.toLowerCase() ==
                        paymentPurpose.toLowerCase())) &&
                    c.termId == termId,
                orElse: () => PaymentPurpose(
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
        }
        _showDialog('Payment Purpose Added Successfully');

        Navigator.pop(context); // Return to the previous screen
      } else {
        _showDialog(
            'No Selected School Term Was Found. Create A New Term or Switch Terms To AnExisting One.');
      }
    }
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
