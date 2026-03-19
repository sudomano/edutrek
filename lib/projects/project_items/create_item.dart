import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class CreateProjectItemForm extends StatefulWidget {
  @override
  State<CreateProjectItemForm> createState() => _CreateProjectItemFormState();
}

class _CreateProjectItemFormState extends State<CreateProjectItemForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers

  final TextEditingController _nameController = TextEditingController();

  String? _selectedProjectCode;
  String _itemType = 'goods'; // goods | service
  bool _trackStock = true;
  bool _active = true;

  void _saveProjectItem() async {
    if (!_formKey.currentState!.validate()) return;

    final itemBox = Hive.box<ProjectItem>('projectItems');

    final exists = itemBox.values.any(
      (i) =>
          i.projectCode == _selectedProjectCode &&
          (i.name?.toLowerCase() ?? '') == _nameController.text.toLowerCase() &&
          (i.active ?? false),
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item already exists for this project')),
      );
      return;
    }

    final newItem = ProjectItem(
      projectItemCode: uuid.v4(),
      projectCode: _selectedProjectCode!,
      name: _nameController.text.trim(),
      itemType: _itemType,
      active: _active,
      trackStock: _itemType == 'goods' ? _trackStock : false,
      syncStatus: false,
      lastModified: DateTime.now(),
      operationType: 'create',
    );

    await itemBox.add(newItem);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project Item created successfully')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final projects = Hive.box<Project>('projects')
        .values
        .where((p) => p.status.toLowerCase() == 'active')
        .toList();

    return CenteredFormContainer(
      title: 'New Project Item',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedProjectCode,
              decoration: const InputDecoration(labelText: 'Project'),
              items: projects
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.projectCode,
                      child: Text(p.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedProjectCode = v;
                  // Get the selected project
                  final project =
                      projects.firstWhere((p) => p.projectCode == v);
                  // Set itemType based on projectType
                  _itemType =
                      project.projectType == 'sales' ? 'goods' : 'service';
                  // TrackStock only relevant for goods
                  _trackStock = _itemType == 'goods';
                });
              },
              validator: (v) => v == null ? 'Select project' : null,
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter item name' : null,
            ),
            DropdownButtonFormField<String>(
              value: _itemType,
              decoration: const InputDecoration(labelText: 'Item Type'),
              items: [
                DropdownMenuItem(
                  value: _itemType,
                  child: Text(
                    _itemType.toUpperCase(),
                  ),
                )
              ],
              onChanged: null, // Disabled: follows projectType
            ),
            SwitchListTile(
              title: const Text('Track Stock'),
              value: _trackStock,
              onChanged: _itemType == 'service'
                  ? null
                  : (v) => setState(() => _trackStock = v),
            ),
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProjectItem,
              child: const Text('Save Item'),
            ),
          ],
        ),
      ),
    );
  }
}
