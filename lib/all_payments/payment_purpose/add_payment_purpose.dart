import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchClasses(); // Fetch classes when screen loads
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    final classes = box.values
        .where((purposeItem) =>
            purposeItem.termId != null && purposeItem.termId == globalTermId)
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
            _buildClassesList(),
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
      if (globalTermId != null) {
        int newId = await getNextId();

        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('paymentPurpose');
        modifiedFields.add('purposeCode');
        modifiedFields.add('purposeAmount');
        modifiedFields.add('termId');
        modifiedFields.add('associatedClasses');

        final paymentPurpose = _purposeController.text.toLowerCase();
        final newPkValue = uuid.v4();

        final newPurpose = PaymentPurpose(
          id: newId,
          paymentPurpose: paymentPurpose,
          purposeCode: newPkValue,
          purposeAmount: double.parse(_amountController.text),
          termId: globalTermId,
          associatedClasses: _selectedClasses, // Save the selected classes
          syncStatus: false, // Set syncStatus to false
          lastModified: DateTime.now(), // Set lastModified to current datetime
          operationType: 'create', // Set operationType to 'create'
          modifiedFields: modifiedFields,
        );

        final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
        final existingPurpose = box.values.cast<PaymentPurpose>().firstWhere(
              (c) =>
                  ((c.paymentPurpose.toLowerCase() ==
                      paymentPurpose.toLowerCase())) &&
                  c.termId == globalTermId,
              orElse: () => PaymentPurpose(
                id: -1,
                paymentPurpose: 'empty',
                purposeAmount: -0.0,
                termId: '',
              ),
            );

        if (existingPurpose.paymentPurpose.toLowerCase() != 'empty') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment Purpose Already Exists')),
          );
          return;
        }

        box.add(newPurpose); // Add the new payment purpose

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Purpose Added Successfully')),
        );

        Navigator.pop(context); // Return to the previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No Selected School Term Was Found. Create A New Term or Switch Terms To AnExisting One.')),
        );
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
