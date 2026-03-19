import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';

class DeleteProjectItem extends StatefulWidget {
  const DeleteProjectItem({Key? key}) : super(key: key);

  @override
  State<DeleteProjectItem> createState() => _DeleteProjectItemState();
}

class _DeleteProjectItemState extends State<DeleteProjectItem> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  List<ProjectItem> _foundItems = [];

  void _searchItem() async {
    final box = Hive.box<ProjectItem>('projectItems');
    final items = box.values.toList();
    final searchTerm = _searchController.text.toLowerCase();

    final filtered = items
        .where((item) => (item.name ?? '').toLowerCase().startsWith(searchTerm))
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    setState(() => _foundItems = filtered);
  }

  void _deleteItem(ProjectItem item) async {
    final box = Hive.box<ProjectItem>('projectItems');
    await box.delete(item.key);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project Item deleted successfully')),
    );

    setState(() => _foundItems.remove(item));
  }

  void _confirmDeleteAllItems() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Project Items'),
        content: const Text(
            'Are you sure you want to delete all Project Items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _deleteAllItems,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _deleteAllItems() async {
    final box = Hive.box<ProjectItem>('projectItems');
    final allItems = box.values.toList();

    for (var item in allItems) {
      await box.delete(item.key);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${allItems.length} items deleted successfully')),
    );

    setState(() => _foundItems.clear());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Project Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Delete All Project Items',
            onPressed: _confirmDeleteAllItems,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Enter Project Item Name to Search',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.3),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _searchItem,
                child: const Text('Search'),
              ),
              const SizedBox(height: 20),
              if (_foundItems.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _foundItems.length,
                    itemBuilder: (_, index) {
                      final item = _foundItems[index];
                      final projectMap = {
                        for (final p in Hive.box<Project>('projects').values)
                          p.projectCode: p.name
                      };

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        child: ListTile(
                          title: Text(
                            item.name ?? '',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Project: ${projectMap[item.projectCode] ?? 'Deleted project'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
