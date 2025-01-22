import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class CreateProjectForm extends StatefulWidget {
  @override
  _CreateProjectFormState createState() => _CreateProjectFormState();
}

class _CreateProjectFormState extends State<CreateProjectForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedStatus = 'Active'; // Default status

  void _saveProject() async {
    if (_formKey.currentState!.validate()) {
      // Check if a project with the same name and term already exists
      final box = Hive.box<Project>('projects');

      final existingSchools = box.values.cast<Project>().where(
            (s) =>
                ((s.name.toLowerCase() == _nameController.text.toLowerCase())),
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

      final projectCode = uuid.v4();
      // Create a new Project instance
      final newProject = Project(
        projectCode: projectCode,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        status: _selectedStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: false, // Default to not synced
        lastModified: DateTime.now(),
        operationType: 'create',
      );

      // Save to Hive
      await box.add(newProject);

      // Show success message and clear the form
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project created successfully!')),
      );

      _formKey.currentState!.reset();
      _nameController.clear();
      _descriptionController.clear();

      // Optionally, navigate back
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'New Project',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Project Code

            // Project Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Project Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project name';
                }
                return null;
              },
            ),

            // Description (optional)
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),

            // Status
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(labelText: 'Status'),
              items: ['Active', 'Closed']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedStatus = newValue!;
                });
              },
            ),

            // Save Button
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProject,
              child: Text('Save Project'),
            ),
          ],
        ),
      ),
    );
  }
}
