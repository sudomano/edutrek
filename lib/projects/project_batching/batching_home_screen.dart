import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/projects/project_batching/batching_price_screen.dart';
import 'package:zitf_system/projects/project_batching/view_batching.dart';

class SelectProjectItemForBatch extends StatefulWidget {
  const SelectProjectItemForBatch({super.key});

  @override
  State<SelectProjectItemForBatch> createState() =>
      _SelectProjectItemForBatchState();
}

class _SelectProjectItemForBatchState extends State<SelectProjectItemForBatch> {
  String _searchQuery = '';
  String? _selectedProject;
  String? _selectedItemType;

  List<ProjectItem> _allItems = [];
  Map<String, String> _projectMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
    final projectBox = await Hive.openBox<Project>('projects');

    setState(() {
      _allItems = projectItemBox.values.where((e) => e.active == true).toList();
      _projectMap = {for (final p in projectBox.values) p.projectCode: p.name};
    });
  }

  List<ProjectItem> get _filteredItems {
    return _allItems.where((item) {
      final projectName = _projectMap[item.projectCode] ?? '';

      final matchesSearch =
          item.name!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              projectName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesProject =
          _selectedProject == null || _selectedProject == projectName;

      final matchesType =
          _selectedItemType == null || _selectedItemType == item.itemType;

      return matchesSearch && matchesProject && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projectMap.values.toList();
    final itemTypes = ['goods', 'service'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Project Item'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _filters(projects, itemTypes),
              const SizedBox(height: 12),
              Expanded(child: _itemList()),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _filters(List<String> projects, List<String> itemTypes) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search item or project',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedProject,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Projects')),
                      ...projects.map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedProject = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedItemType,
                    decoration: const InputDecoration(labelText: 'Item Type'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Types')),
                      DropdownMenuItem(value: 'goods', child: Text('Goods')),
                      DropdownMenuItem(
                          value: 'service', child: Text('Service')),
                    ],
                    onChanged: (v) => setState(() => _selectedItemType = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _itemList() {
    if (_filteredItems.isEmpty) {
      return const Center(child: Text('No items found'));
    }

    return ListView.separated(
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isGoods = item.itemType == 'goods';
        final projectName = _projectMap[item.projectCode] ?? 'Deleted Project';

        return Card(
          elevation: 2,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 16),

            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name!.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                _typeBadge(isGoods),
              ],
            ),

            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                projectName.toUpperCase(),
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            // 👁 View existing
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectItemViewScreen(projectItem: item),
                ),
              );
            },

            // ➕ Create new
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, size: 28),
              color: isGoods ? Colors.blue : Colors.green,
              tooltip: isGoods ? 'Add new batch' : 'Add service price',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateProductBatchScreen(projectItem: item),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  Widget _typeBadge(bool isGoods) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGoods ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isGoods ? 'GOODS' : 'SERVICE',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isGoods ? Colors.blue : Colors.green,
        ),
      ),
    );
  }
}
