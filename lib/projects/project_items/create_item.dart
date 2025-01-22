import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class CreateProjectItemForm extends StatefulWidget {
  @override
  _CreateProjectItemFormState createState() => _CreateProjectItemFormState();
}

class _CreateProjectItemFormState extends State<CreateProjectItemForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isStudentFee = false;

  String? _selectedProjectCode; // Dropdown selection for project code

  void _saveProjectItem() async {
    if (_formKey.currentState!.validate()) {
      // Check if a project item with the same code exists
      final itemBox = Hive.box<ProjectItem>('projectItems');
      final existingItems = itemBox.values.cast<ProjectItem>().where(
            (item) =>
                item.name.toLowerCase() == _nameController.text.toLowerCase(),
          );
      if (existingItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Project Item with this Name already exists')),
        );
        return;
      }
      final projectItemCode = uuid.v4();
      // Create new ProjectItem
      final newItem = ProjectItem(
        projectItemCode: projectItemCode,
        projectCode: _selectedProjectCode!,
        name: _nameController.text,
        amount: double.parse(_amountController.text),
        isStudentFee: _isStudentFee,
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'create',
      );

      // Save to Hive
      await itemBox.add(newItem);

      // Show success message and clear the form
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project Item created successfully!')),
      );

      _formKey.currentState!.reset();
      _nameController.clear();
      _amountController.clear();
      setState(() {
        _isStudentFee = false;
      });

      // Optionally, navigate back
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fetch all available projects for the dropdown
    final projectBox = Hive.box<Project>('projects');
    final projects = projectBox.values.toList();

    return CenteredFormContainer(
      title: 'New Project Item',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Select Project
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Select Project'),
              value: _selectedProjectCode,
              items: projects
                  .map((project) => DropdownMenuItem(
                        value: project.projectCode,
                        child: Text(project.name),
                      ))
                  .toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedProjectCode = newValue;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a project';
                }
                return null;
              },
            ),

            // Item Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Item Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an item name';
                }
                return null;
              },
            ),
            // Project Item Code

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),

            // Is Student Fee Checkbox
            CheckboxListTile(
              title: Text('Is this a student fee?'),
              value: _isStudentFee,
              onChanged: (value) {
                setState(() {
                  _isStudentFee = value!;
                });
              },
            ),

            // Save Button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProjectItem,
              child: Text('Save Project Item'),
            ),
          ],
        ),
      ),
    );
  }
}
