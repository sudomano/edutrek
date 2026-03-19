import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateProjectItemForm extends StatefulWidget {
  final int index;

  const UpdateProjectItemForm({super.key, required this.index});

  @override
  State<UpdateProjectItemForm> createState() => _UpdateProjectItemFormState();
}

class _UpdateProjectItemFormState extends State<UpdateProjectItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedProjectCode;
  String _itemType = 'goods';
  bool _trackStock = true;
  bool _active = true;

  late ProjectItem currentItem;

  @override
  void initState() {
    super.initState();

    final projectBox = Hive.box<Project>('projects');
    final itemBox = Hive.box<ProjectItem>('projectItems');

    currentItem = itemBox.getAt(widget.index)!;

    // ✅ SET THIS FIRST
    _selectedProjectCode = currentItem.projectCode;

    debugPrint(
      '🧩 Editing ProjectItem: '
      'itemCode=${currentItem.projectItemCode}, '
      'projectCode=$_selectedProjectCode',
    );

    Project? project;

    try {
      project = projectBox.values.firstWhere(
        (p) {
          debugPrint(
            '🔍 Checking project: '
            'code=${p.projectCode}, '
            'status=${p.status}',
          );
          return p.projectCode == _selectedProjectCode;
        },
      );
    } catch (e) {
      debugPrint(
        '⚠️ Project NOT FOUND for projectCode=$_selectedProjectCode',
      );
      project = null;
    }

    // ✅ SAFE guards (NO crash)
    if (project == null) {
      debugPrint('❌ Orphaned ProjectItem detected');
      _itemType = 'goods';
      _trackStock = true;
    } else if (project.status.toLowerCase() == 'deleted') {
      debugPrint(
        '🚫 ProjectItem belongs to DELETED project '
        '(code=${project.projectCode})',
      );
      _itemType = 'goods';
      _trackStock = true;
    } else {
      _itemType = project.projectType == 'sales' ? 'goods' : 'service';
      _trackStock = _itemType == 'goods';
    }

    _nameController.text = currentItem.name ?? '';
    _active = currentItem.active ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final projects = Hive.box<Project>('projects')
        .values
        .where((p) => p.status.toLowerCase() == 'active')
        .toList();

    return CenteredFormContainer(
      title: 'Update Project Item',
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
                  final project =
                      projects.firstWhere((p) => p.projectCode == v);
                  // Update itemType according to projectType
                  _itemType =
                      project.projectType == 'sales' ? 'goods' : 'service';
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
                  child: Text(_itemType == 'goods' ? 'Goods' : 'Service'),
                ),
              ],
              onChanged: null, // Read-only
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
              onPressed: _updateProjectItem,
              child: const Text('Update Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateProjectItem() async {
    if (!_formKey.currentState!.validate()) return;

    final itemBox = Hive.box<ProjectItem>('projectItems');

    final duplicate = itemBox.values.any(
      (i) =>
          i.projectItemCode != currentItem.projectItemCode &&
          i.projectCode == _selectedProjectCode &&
          (i.name?.toLowerCase() ?? '') == _nameController.text.toLowerCase(),
    );

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item already exists for this project')),
      );
      return;
    }

    final updatedItem = currentItem.copyWith(
      projectCode: _selectedProjectCode,
      name: _nameController.text.trim(),
      itemType: _itemType,
      trackStock: _itemType == 'goods' ? _trackStock : false,
      active: _active,
      syncStatus: false,
      lastModified: DateTime.now(),
      operationType: 'update',
    );

    await itemBox.putAt(widget.index, updatedItem);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project Item updated successfully')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
