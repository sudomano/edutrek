import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/global files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart'; // Replace 'your_app_name' with your actual app's name

class CreateClass extends StatefulWidget {
  const CreateClass({super.key});

  @override
  _AddClass createState() => _AddClass();
}

class _AddClass extends State<CreateClass> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Create Classes',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('Class Name (required)', _classNameController),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Create Class'),
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

  Future<int> getNextId() async {
    final box = await Hive.openBox<Classes>('classes');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (globalTermId != null) {
        final newPkValue = uuid.v4();

        final className = _classNameController.text;
        final classCode = newPkValue;

        final box = await Hive.openBox<Classes>('classes');
        final existingClass = box.values.cast<Classes>().firstWhere(
              (c) =>
                  (c.className.trim().toLowerCase() ==
                          className.trim().toLowerCase() ||
                      (c.classCode?.trim().toLowerCase() ==
                          classCode.trim().toLowerCase())) &&
                  c.termId == globalTermId,
              orElse: () =>
                  Classes(id: -1, className: '', date: DateTime(1970)),
            );

        if (existingClass.id != -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class already exists')),
          );
          return;
        }
        int newId = await getNextId();
        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('className');
        modifiedFields.add('classCode');
        modifiedFields.add('date');
        modifiedFields.add('termId');
        // Ensure the termId is set from globalTermId
        final newClass = Classes(
          id: newId, // Generate a unique ID
          className: toBeginningOfSentenceCase(className),
          classCode: classCode,

          date: DateTime.now(),
          termId: globalTermId, // Set the termId from globalTermId
          syncStatus: false, // Set syncStatus to false
          lastModified: DateTime.now(), // Set lastModified to current datetime
          operationType: 'create', // Set operationType to 'create'
          modifiedFields: modifiedFields,
        );

        box.add(newClass); // Add the new class to the Hive box

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class Added Successfully')),
        );
        _classNameController.clear();
        // Navigator.pop(context); // Return to the previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No Selected Term Was Found. Create A New Term or Switch Terms To AnExisting One.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }
}
