import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateProjects extends StatefulWidget {
  final dynamic hiveKey; // Hive key instead of index
  const UpdateProjects({super.key, required this.hiveKey});

  @override
  State<UpdateProjects> createState() => _UpdateProjectsState();
}

class _UpdateProjectsState extends State<UpdateProjects> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late Project currentProject;

  bool _isActive = true;
  bool _studentPayable = false;

  String _projectType = 'sales';
  String _participationType = 'optional';

  final List<String> _modifiedFields = [];

  @override
  void initState() {
    super.initState();

    final box = Hive.box<Project>('projects');

    currentProject = box.get(widget.hiveKey)!;

    _nameController.text = currentProject.name;
    _descriptionController.text = currentProject.description ?? '';

    _isActive = currentProject.status.toLowerCase() == 'active';
    _studentPayable = currentProject.studentPayable ?? false;
    _projectType = currentProject.projectType;
    _participationType = currentProject.participationType;
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Project',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _readOnlyField('Project Code', currentProject.projectCode),
            const SizedBox(height: 16),
            _buildTextField('Project Name', _nameController),
            const SizedBox(height: 16),
            _buildTextField(
              'Description',
              _descriptionController,
              maxLines: 3,
              isRequired: false,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Project Type',
              value: _projectType,
              items: const ['sales', 'services'],
              onChanged: (val) {
                _projectType = val!;
                _modifiedFields.add('projectType');
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Participation Type',
              value: _participationType,
              items: const ['compulsory', 'optional'],
              onChanged: (val) {
                _participationType = val!;
                _modifiedFields.add('participationType');
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Project Status'),
              subtitle: Text(_isActive ? 'active' : 'closed'),
              value: _isActive,
              onChanged: (value) {
                setState(() => _isActive = value);
                _modifiedFields.add('status');
              },
            ),
            SwitchListTile(
              title: const Text('Student Payable'),
              value: _studentPayable,
              onChanged: (value) {
                setState(() => _studentPayable = value);
                _modifiedFields.add('studentPayable');
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateProject,
              child: const Text('Update Project'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------

  Widget _readOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        disabledBorder: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Please enter $label';
        }
        return null;
      },
      onChanged: (_) => _modifiedFields.add(label.toLowerCase()),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e.toUpperCase()),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  // ---------------- UPDATE LOGIC ----------------

  void _updateProject() async {
    if (!_formKey.currentState!.validate()) return;

    final box = Hive.box<Project>('projects');
    final newName = _nameController.text.trim();

    // Prevent duplicate names (excluding self)
    final duplicate = box.values.any(
      (p) =>
          p.name.toLowerCase() == newName.toLowerCase() &&
          p.projectCode != currentProject.projectCode,
    );

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project with this name already exists'),
        ),
      );
      return;
    }

    final updatedProject = currentProject.copyWith(
      name: newName,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      status: _isActive ? 'active' : 'closed',
      projectType: _projectType,
      participationType: _participationType,
      studentPayable: _studentPayable,
      updatedAt: DateTime.now(),
      lastModified: DateTime.now(),
      syncStatus: false,
      operationType: 'update',
      modifiedFields: _modifiedFields.toSet().toList(),
    );

    await box.put(widget.hiveKey, updatedProject); // ✅ safe update by key

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project updated successfully')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
