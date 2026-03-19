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
  String _selectedStatus = 'active';
  String _selectedProjectType = 'sales';
  String _selectedParticipationType = 'optional';
  bool _studentPayable = true;

  void _saveProject() async {
    if (_formKey.currentState!.validate()) {
      // Check if a project with the same name and term already exists
      final box = Hive.box<Project>('projects');

      final exists = box.values.any(
        (p) => p.name.toLowerCase() == _nameController.text.toLowerCase(),
      );

      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project already exists')),
        );
        return;
      }

      final now = DateTime.now();
      // Create a new Project instance
      final newProject = Project(
        projectCode: uuid.v4(),
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        status: _selectedStatus,
        projectType: _selectedProjectType,
        participationType: _selectedParticipationType,
        createdAt: now,
        updatedAt: now,
        syncStatus: false, // Default to not synced
        lastModified: DateTime.now(),
        operationType: 'create',
        studentPayable: _studentPayable,
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
            SwitchListTile(
              title: const Text('Only Students Must Pay for This Project?'),
              subtitle: Text(
                _studentPayable
                    ? 'Payments will be collected from students only'
                    : 'Project is externally funded or internal',
              ),
              value: _studentPayable,
              onChanged: (v) => setState(() => _studentPayable = v),
            ),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project Name'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),

            /// Project Type
            DropdownButtonFormField<String>(
              value: _selectedProjectType,
              decoration: const InputDecoration(labelText: 'Project Type'),
              items: const [
                DropdownMenuItem(value: 'sales', child: Text('Sales (Goods)')),
                DropdownMenuItem(value: 'service', child: Text('Services')),
              ],
              onChanged: (value) =>
                  setState(() => _selectedProjectType = value!),
            ),

            /// Participation Type
            DropdownButtonFormField<String>(
              value: _selectedParticipationType,
              decoration:
                  const InputDecoration(labelText: 'Participation Type'),
              items: const [
                DropdownMenuItem(value: 'optional', child: Text('Optional')),
                DropdownMenuItem(
                    value: 'compulsory', child: Text('Compulsory')),
              ],
              onChanged: (value) =>
                  setState(() => _selectedParticipationType = value!),
            ),

            /// Status
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value!),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProject,
              child: const Text('Save Project'),
            ),
          ],
        ),
      ),
    );
  }
}
