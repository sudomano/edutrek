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

  List<String> _classes = [];
  List<String> _selectedClasses = [];

  List<ExceptionalStudents> _exceptionNames = [];
  List<ExceptionalStudents> _selectedExceptionNames = [];
  bool _forNewcomersOnly = false;

  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _fetchExceptionalStudents();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    // ✅ Only load active (non-deleted) terms
    final activeTerms = termsBox.values
        .where((t) => !(t.isDeleted ?? false))
        .map((term) => term.termId)
        .toList();

    setState(() {
      _availableTerms = activeTerms;
      _selectedTerms = List.from(_availableTerms);
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
    // ✅ Only load active (non-deleted) exceptions
    final all = box.values.where((e) => !(e.isDeleted ?? false)).toList();

    setState(() {
      _exceptionNames = all
          .where((e) => e.exceptionStatus!.toLowerCase() == 'active')
          .toList();
    });
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    // ✅ Only load active (non-deleted) classes
    final classes = box.values
        .where((purposeItem) =>
            purposeItem.termId != null &&
            purposeItem.terms!.contains(globalTermId) &&
            !(purposeItem.isDeleted ?? false))
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
        final parsed = double.tryParse(value);
        if (parsed == null) {
          return 'Please enter a valid amount';
        }
        if (parsed < 0) {
          return 'Amount must be greater than 0';
        }
        return null;
      },
    );
  }

  Widget _buildClassesList() {
    bool _selectAll =
        _selectedClasses.length == _classes.length && _classes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_classes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (isChecked) {
                      setState(() {
                        if (isChecked == true) {
                          _selectedClasses = List.from(_classes);
                        } else {
                          _selectedClasses.clear();
                        }
                      });
                    },
                  ),
                  Text(
                    'Select All',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 14.0,
                          color: Colors.black87,
                        ),
                  ),
                ],
              ),
            ),
          if (_classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'No classes available for the current term.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
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
                      fontSize: 14.0,
                      color: Colors.black87,
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
                  activeColor: Theme.of(context).primaryColor,
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

      if (globalTermId == null) {
        _showDialog(
            'No Selected School Term Was Found. Create A New Term or Switch Terms To An Existing One.');
        return;
      }

      final paymentPurpose = _purposeController.text.trim().toLowerCase();
      final amount = double.parse(_amountController.text.trim());

      // ✅ Prepare modified fields for new purpose
      List<String> modifiedFields = [
        'id',
        'paymentPurpose',
        'purposeCode',
        'purposeAmount',
        'termId',
        'associatedClasses',
        'exceptions',
        'forNewcomersOnly',
        'syncStatus',
        'lastModified',
        'operationType'
      ];

      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      int createdCount = 0;

      for (var termId in _selectedTerms) {
        // ✅ Check for duplicate in the term (only check active purposes)
        bool alreadyExists = box.values.any((pp) =>
            pp.paymentPurpose.toLowerCase() == paymentPurpose &&
            pp.termId == termId &&
            !(pp.isDeleted ?? false)); // ✅ Only check active records

        if (alreadyExists) {
          _showDialog(
              'Payment Purpose "$paymentPurpose" already exists for term $termId.');
          continue;
        }

        int newId = await getNextId();
        final newPkValue = uuid.v4();

        final newPurpose = PaymentPurpose(
          id: newId,
          paymentPurpose: paymentPurpose,
          purposeCode: newPkValue,
          purposeAmount: amount,
          termId: termId,
          associatedClasses:
              _selectedClasses.isNotEmpty ? _selectedClasses : null,
          syncStatus: false, // ✅ Needs sync
          lastModified: DateTime.now(),
          operationType: 'create',
          exceptions: _selectedExceptionNames.isNotEmpty
              ? _selectedExceptionNames
              : null,
          forNewcomersOnly: _forNewcomersOnly,
          modifiedFields: modifiedFields,
          // ✅ Deletion fields - new purpose is not deleted
          isDeleted: false,
          deletedAt: null,
          deletedBy: null,
          deleteReason: null,
          deletedSyncStatus: true,
        );

        await box.add(newPurpose);
        createdCount++;

        print('✅ Payment Purpose created: $paymentPurpose for term: $termId');
        print('   Purpose Code: ${newPurpose.purposeCode}');
        print('   Sync Status: ${newPurpose.syncStatus}');
        print('   Modified Fields: ${newPurpose.modifiedFields}');
      }

      if (createdCount > 0) {
        _showDialog('✅ $createdCount Payment Purpose(s) Added Successfully!\n\n'
            'Purpose: $paymentPurpose\n'
            'Amount: \$${amount.toStringAsFixed(2)}\n'
            'Terms: ${_selectedTerms.join(", ")}\n'
            'Classes: ${_selectedClasses.isNotEmpty ? _selectedClasses.join(", ") : "All Classes"}\n'
            'Exceptions: ${_selectedExceptionNames.isNotEmpty ? _selectedExceptionNames.map((e) => e.exceptionName).join(", ") : "None"}\n'
            'Newcomers Only: ${_forNewcomersOnly ? "Yes" : "No"}\n\n'
            '📤 Ready to sync to host when online.');

        Navigator.pop(context);
      } else {
        _showDialog(
            'No new payment purposes were created. They may already exist.');
      }
    }
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
    // ✅ Only count active (non-deleted) purposes
    final activePurposes =
        box.values.where((p) => !(p.isDeleted ?? false)).toList();

    if (activePurposes.isEmpty) return 1;

    int currentMaxId = activePurposes
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
