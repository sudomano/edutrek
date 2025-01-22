import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdatePaymentPurposeScreen extends StatefulWidget {
  final PaymentPurpose existingPurpose;

  const UpdatePaymentPurposeScreen({super.key, required this.existingPurpose});

  @override
  _UpdatePaymentPurposeScreenState createState() =>
      _UpdatePaymentPurposeScreenState();
}

class _UpdatePaymentPurposeScreenState
    extends State<UpdatePaymentPurposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _purposeController;
  late TextEditingController _amountController;
  List<String> _classes = [];
  late List<String> _selectedClasses;

  @override
  void initState() {
    super.initState();
    _purposeController =
        TextEditingController(text: widget.existingPurpose.paymentPurpose);
    _amountController = TextEditingController(
        text: widget.existingPurpose.purposeAmount.toString());
    // Ensure _selectedClasses is never null.
    _selectedClasses = widget.existingPurpose.associatedClasses != null
        ? List.from(widget.existingPurpose.associatedClasses as Iterable)
        : <String>[];

    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    final classes = box.values
        .where((classItem) =>
            classItem.termId != null && classItem.termId == globalTermId)
        .map((e) => e.className)
        .toList();

    setState(() {
      _classes = classes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Payment Purpose',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('Payment Purpose', _purposeController),
            const SizedBox(height: 16),
            _buildAmountField('Payment Purpose Amount', _amountController),
            const SizedBox(height: 16),
            _buildClassesList(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _update,
              child: const Text('Update Payment Purpose'),
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
    bool _selectAll = _selectedClasses.length == _classes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Text('Select All'),
            ],
          ),
          ..._classes.map((className) {
            return CheckboxListTile(
              title: Text(className),
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
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _update() async {
    if (_formKey.currentState!.validate()) {
      final purposeCode = widget.existingPurpose.purposeCode;

      List<String> modifiedFields = widget.existingPurpose.modifiedFields ??
          []; // Initialize with existing modified fields

// Append new modifications without overwriting

      if (widget.existingPurpose.paymentPurpose.toLowerCase() !=
          _purposeController.text.toLowerCase()) {
        if (!modifiedFields.contains('paymentPurpose')) {
          modifiedFields.add('paymentPurpose');
        }
      }

      if (widget.existingPurpose.purposeAmount !=
          double.parse(_amountController.text)) {
        if (!modifiedFields.contains('purposeAmount')) {
          modifiedFields.add('purposeAmount');
        }
      }

      if (!const DeepCollectionEquality()
          .equals(widget.existingPurpose.associatedClasses, _selectedClasses)) {
        if (!modifiedFields.contains('associatedClasses')) {
          modifiedFields.add('associatedClasses');
        }
      }

      final updatedPurpose = widget.existingPurpose.copyWith(
        paymentPurpose: _purposeController.text,
        purposeAmount: double.parse(_amountController.text),
        associatedClasses: _selectedClasses,
        syncStatus: false, // Mark for syncing
        lastModified: DateTime.now(), // Update last modified time
        operationType: 'update',
        purposeCode: purposeCode, // Mark operation as update
        modifiedFields: modifiedFields,
      );

      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      final index = box.values
          .toList()
          .indexWhere((purpose) => purpose.id == widget.existingPurpose.id);

      if (index != -1) {
        box.putAt(index, updatedPurpose); // Update the record in Hive
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Purpose Updated Successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Purpose Not Found')),
        );
      }
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
