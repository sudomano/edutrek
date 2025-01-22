import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateProjects extends StatefulWidget {
  final int index;

  const UpdateProjects({super.key, required this.index});

  @override
  _UpdateSchoolScreenState createState() => _UpdateSchoolScreenState();
}

class _UpdateSchoolScreenState extends State<UpdateProjects> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _statusController = TextEditingController(); // For status
  final _createdAtController = TextEditingController();
  String currentProjectCode = ''; // For start date
  bool _isActive = true; // For active status

  late Project currentSchool;

  @override
  void initState() {
    super.initState();
    final Box<Project> box = Hive.box<Project>('projects');

    // Load the current school from the Hive box
    currentSchool = box.getAt(widget.index)!;

    // Populate the text fields with the current school information
    _projectNameController.text = currentSchool.name;
    _descriptionController.text = currentSchool.description ?? '';
    _statusController.text = currentSchool.status;
    _createdAtController.text =
        currentSchool.createdAt.toLocal().toString().split(' ')[0];
    currentProjectCode = currentSchool.projectCode;
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Project',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('Project Name', _projectNameController),
            const SizedBox(height: 20),
            _buildTextField('Description', _descriptionController),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Status'),
              value: _isActive,
              onChanged: (bool value) {
                final box = Hive.openBox<Project>('projects');

                setState(() {
                  _isActive = value;
                  _statusController.text =
                      _isActive ? 'Active' : 'Closed'; // Update status
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateSchool,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 15, 15, 15),
                backgroundColor: Color.fromARGB(255, 251, 252, 254),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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

  void _updateSchool() async {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<Project>('projects');

      // Get the updated values from the text fields
      final name = _projectNameController.text.toLowerCase();
      final description = _descriptionController.text;
      final status = _statusController.text;
      DateTime createdAt;

      try {
        createdAt = DateTime.parse(_createdAtController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid created date format')),
        );
        return;
      }

      final existingSchools = box.values.cast<Project>().where(
            (s) => ((s.name.toLowerCase() == name &&
                s.projectCode.toLowerCase() !=
                    currentProjectCode.toLowerCase())),
          );
      Project? existingSchool =
          existingSchools.isNotEmpty ? existingSchools.first : null;

      // Ensure the user isn't updating to a name that already exists
      if (existingSchool != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Project with this Project Name already exists')),
        );
        return;
      }

      // Create the updated school object using copyWith to preserve unchanged fields
      final updatedSchool = currentSchool.copyWith(
        name: name,
        description: description,
        status: status,
        createdAt: createdAt,
        syncStatus: false,
        updatedAt: DateTime.now(),
        lastModified: DateTime.now(),
        operationType: 'update',
      );

      // Update the school in Hive at the specific index
      box.putAt(widget.index, updatedSchool);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project Updated Successfully')),
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _createdAtController.dispose();
    _descriptionController.dispose();
    _projectNameController.dispose();
    _statusController.dispose();

    super.dispose();
  }
}
