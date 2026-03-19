import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_model.dart';

class DeleteProjects extends StatefulWidget {
  const DeleteProjects({Key? key}) : super(key: key);

  @override
  State<DeleteProjects> createState() => _DeleteProjectsState();
}

class _DeleteProjectsState extends State<DeleteProjects> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  List<Project> _foundProjects = [];

  void _searchProjects() {
    final box = Hive.box<Project>('projects');
    final searchTerm = _searchController.text.toLowerCase();

    final results = box.values
        .where((p) =>
            p.status.toLowerCase() != 'deleted' &&
            p.name.toLowerCase().contains(searchTerm))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    setState(() => _foundProjects = results);
  }

  Future<void> _softDeleteProject(Project project) async {
    project
      ..status = 'deleted'
      ..syncStatus = false
      ..operationType = 'delete'
      ..lastModified = DateTime.now()
      ..updatedAt = DateTime.now()
      ..modifiedFields = ['status'];

    await project.save(); // 🔥 THIS is the missing piece

    setState(() {
      _foundProjects.removeWhere((p) => p.projectCode == project.projectCode);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project deleted successfully')),
    );
  }

  void _confirmDelete(Project project) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${project.name}"?\n\n'
          'This action can be synced but not immediately undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _softDeleteProject(project);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Project'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Project',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter project name' : null,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _searchProjects();
                  }
                },
                child: const Text('Search'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _foundProjects.isEmpty
                    ? const Center(child: Text('No projects found'))
                    : ListView.builder(
                        itemCount: _foundProjects.length,
                        itemBuilder: (_, index) {
                          final project = _foundProjects[index];
                          return Card(
                            child: ListTile(
                              title: Text(project.name),
                              subtitle: Text('Status: ${project.status}'),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(project),
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
