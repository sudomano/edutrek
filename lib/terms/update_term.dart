import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateTermScreen extends StatefulWidget {
  final int index; // Index of the term to update

  const UpdateTermScreen({Key? key, required this.index}) : super(key: key);

  @override
  _UpdateTermScreenState createState() => _UpdateTermScreenState();
}

class _UpdateTermScreenState extends State<UpdateTermScreen> {
  final _formKey = GlobalKey<FormState>();
  final _termNameController = TextEditingController(); // For term name
  final _termIdController = TextEditingController(); // For term name
  final _startDateController = TextEditingController(); // For start date
  final _endDateController = TextEditingController(); // For end date
  final _statusController = TextEditingController(); // For status
  bool _isActive = false; // For active status
  Terms? _currentTerm; // Term being updated

  @override
  void initState() {
    super.initState();
    final Box<Terms> box = Hive.box<Terms>('terms');

    // Check if the term at the given index is valid
    if (widget.index < 0 || widget.index >= box.length) {
      // Handle invalid index or term not found
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid term index')),
        );
      });
      return;
    }

    _currentTerm = box.getAt(widget.index);

    // Ensure _currentTerm is not null
    if (_currentTerm == null) {
      // Handle null term
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term not found')),
        );
      });
      return;
    }
    _termIdController.text = _currentTerm!.termId;
    _termNameController.text = _currentTerm!.termName;
    _startDateController.text =
        _currentTerm!.startDate.toLocal().toString().split(' ')[0];
    _endDateController.text =
        _currentTerm!.endDate?.toLocal().toString().split(' ')[0] ?? '';
    _statusController.text = _currentTerm!.status;
    _isActive = _currentTerm!.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Term',
      child: Form(
        key: _formKey, // Key for form validation
        child: ListView(
          children: [
            const SizedBox(height: 20),
            _buildTextField(
                'Term Name', _termNameController), // Input for term name
            const SizedBox(height: 20), // Add spacing
            _buildDatePicker('Start Date',
                _startDateController), // Date picker for start date
            const SizedBox(height: 20), // Add spacing
            _buildDatePicker(
                'End Date', _endDateController), // Date picker for end date
            const SizedBox(height: 20), // Add spacing
            _buildTextField('Status', _statusController), // Input for status
            const SizedBox(height: 20), // Add spacing
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (bool value) {
                final box = Hive.box<Terms>('terms');

                // Check if any other term has isActive == true
                final hasActiveTerm = box.values.any(
                  (term) =>
                      term.isActive && term.termId != _currentTerm!.termId,
                );

                if (hasActiveTerm && value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Only one term can be active at a time')),
                  );
                  return; // Prevent switching to true if another term is already active
                }

                setState(() {
                  _isActive = value;
                  _statusController.text =
                      _isActive ? 'opened' : 'closed'; // Update status
                });
              },
            ),

            const SizedBox(height: 20), // Add spacing
            ElevatedButton(
              onPressed: _updateTerm,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 13, 13, 13),
                backgroundColor:
                    Color.fromARGB(255, 227, 229, 232), // Set text color
                elevation: 3, // Add elevation
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10), // Add rounded corners
                ),
              ),
              child: const Text('Update'),
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
        filled: true, // Add background color
        fillColor: Colors.white, // Set background color
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label'; // Ensure input is not empty
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true, // Add background color
        fillColor: Colors.white, // Set background color
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _selectDate(context, controller),
        ),
      ),
      readOnly: true, // Prevent manual text input
    );
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.parse(controller.text) // Use existing date if available
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (selectedDate != null) {
      controller.text = selectedDate
          .toLocal()
          .toString()
          .split(' ')[0]; // Format date as yyyy-MM-dd
    }
  }

  void _updateTerm() async {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<Terms>('terms');
      final termId = _termNameController.text.toLowerCase();

      // Check if term with the same name already exists
      final existingTerm = box.values.firstWhere(
        (t) => t.termName.toLowerCase() == termId,
        orElse: () => Terms(
            termId: '',
            startDate: DateTime(1970),
            endDate: DateTime(1970),
            termName: '',
            isActive: false,
            status: ''),
      );

      // If an existing term is found and it's not the one being updated
      if (existingTerm.termName.isNotEmpty &&
          existingTerm.termId != _currentTerm!.termId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term with this name already exists')),
        );
        return;
      }

      DateTime startDate;
      DateTime endDate;

      try {
        startDate = DateTime.parse(_startDateController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid start date format')),
        );
        return;
      }

      try {
        endDate = DateTime.parse(_endDateController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid end date format')),
        );
        return;
      }
      int? newId = existingTerm.id;

      List<String> modifiedFields = _currentTerm?.modifiedFields ??
          []; // Initialize with existing modified fields

// Append new modifications without overwriting
      if (newId != null) {
        if (_currentTerm?.id != newId) {
          if (!modifiedFields.contains('id')) {
            modifiedFields.add('id');
          }
        }
      }

      if (_currentTerm?.termId.toLowerCase() !=
          _termIdController.text.toLowerCase()) {
        if (!modifiedFields.contains('termId')) {
          modifiedFields.add('termId');
        }
      }

      if (_currentTerm?.termName.toLowerCase() !=
          _termNameController.text.toLowerCase()) {
        if (!modifiedFields.contains('termName')) {
          modifiedFields.add('termName');
        }
      }

      if (_currentTerm?.startDate != startDate) {
        if (!modifiedFields.contains('startDate')) {
          modifiedFields.add('startDate');
        }
      }

      if (_currentTerm?.isActive != _isActive) {
        if (!modifiedFields.contains('isActive')) {
          modifiedFields.add('isActive');
        }
      }

      if (_currentTerm?.status.toLowerCase() !=
          _statusController.text.toLowerCase()) {
        if (!modifiedFields.contains('status')) {
          modifiedFields.add('status');
        }
      }

      final updatedTerm = Terms(
        id: newId,
        termId: _termIdController.text, // Keep existing termId
        termName: _termNameController.text, // Get updated term name
        startDate: startDate, // Update start date
        endDate: endDate, // Update end date
        isActive: _isActive, // Update active status
        status: _statusController.text, // Update status
        operationType: 'update',
        syncStatus: false,
        lastModified: DateTime.now(),
        modifiedFields: modifiedFields,
      );

      box.putAt(widget.index, updatedTerm); // Update the Hive box

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Term Updated Successfully')),
      );

      Navigator.pop(context); // Return to the previous screen
    }
  }

  @override
  void dispose() {
    _termNameController.dispose(); // Clean up to avoid memory leaks
    _startDateController.dispose();
    _endDateController.dispose();
    _statusController.dispose();
    super.dispose();
  }
}
