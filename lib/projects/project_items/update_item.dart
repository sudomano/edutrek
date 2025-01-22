import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateProjectItemForm extends StatefulWidget {
  final int index;

  const UpdateProjectItemForm({super.key, required this.index});

  @override
  _UpdateProjectItemFormState createState() => _UpdateProjectItemFormState();
}

class _UpdateProjectItemFormState extends State<UpdateProjectItemForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isStudentFee = false;

  String? _selectedProjectCode; // Dropdown selection for project code
  late ProjectItem currentItem;

  @override
  void initState() {
    super.initState();

    // Load the current item from the Hive box
    final itemBox = Hive.box<ProjectItem>('projectItems');
    currentItem = itemBox.getAt(widget.index)!;

    // Populate the text fields with the current item information
    _nameController.text = currentItem.name;
    _amountController.text = currentItem.amount.toString();
    _isStudentFee = currentItem.isStudentFee;
    _selectedProjectCode = currentItem.projectCode;
  }

  @override
  Widget build(BuildContext context) {
    // Fetch all available projects for the dropdown
    final projectBox = Hive.box<Project>('projects');
    final projects = projectBox.values.toList();

    return CenteredFormContainer(
      title: 'Update Project Item',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Select Project
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select Project'),
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
            _buildTextField('Item Name', _nameController),

            // Project Item Code

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
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
              title: const Text('Is this a student fee?'),
              value: _isStudentFee,
              onChanged: (value) {
                setState(() {
                  _isStudentFee = value!;
                });
              },
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProjectItem,
              child: const Text('Update Project Item'),
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
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  void _updateProjectItem() async {
    if (_formKey.currentState!.validate()) {
      final itemBox = Hive.box<ProjectItem>('projectItems');

      // Check if an item with the same code exists (excluding the current item)
      final existingItems = itemBox.values.cast<ProjectItem>().where(
            (item) =>
                item.name.toLowerCase() == _nameController.text.toLowerCase() &&
                item != currentItem,
          );

      if (existingItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Project Item with this code already exists')),
        );
        return;
      }

      // Update the current item
      final updatedItem = currentItem.copyWith(
        projectItemCode: currentItem.projectItemCode,
        projectCode: _selectedProjectCode!,
        name: _nameController.text,
        amount: double.parse(_amountController.text),
        isStudentFee: _isStudentFee,
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'update',
      );

      // Save the updated item to Hive
      await itemBox.putAt(widget.index, updatedItem);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project Item updated successfully!')),
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
