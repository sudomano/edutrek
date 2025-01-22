import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/global%20files/global_term_id.dart'; // Import global term ID

class DeleteItem extends StatefulWidget {
  const DeleteItem({Key? key}) : super(key: key);

  @override
  _DeleteSchoolScreenState createState() => _DeleteSchoolScreenState();
}

class _DeleteSchoolScreenState extends State<DeleteItem> {
  final _formKey = GlobalKey<FormState>();
  final _searchController =
      TextEditingController(); // Controller for the search input
  List<ProjectItem> _foundSchools = []; // List of found schools for display

  void _searchSchool() async {
    final box =
        await Hive.openBox<ProjectItem>('projectItems'); // Open School Hive box
    final schools = box.values.toList(); // Get all schools from the box
    final searchTerm = _searchController.text.toLowerCase(); // Search term

    // Filter schools by search term and global term ID
    final schoolsWithName = schools
        .where((school) => school.name.toLowerCase().startsWith(searchTerm))
        .toList();

    // Sort alphabetically by school name
    schoolsWithName.sort((a, b) => a.name.compareTo(b.name.toString()));

    setState(() {
      _foundSchools = schoolsWithName;
    });
  }

  void _deleteSchool(ProjectItem schoolToDelete) async {
    final box = await Hive.openBox<ProjectItem>('projectItems');
    if (schoolToDelete.projectItemCode != null) {
      await box
          .delete(schoolToDelete.key); // Delete the school if termId matches

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ProjectItem Deleted Successfully')),
      );

      setState(() {
        _foundSchools.remove(schoolToDelete); // Remove from the UI list
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ProjectItem cannot be deleted')),
      );
    }
  }

  void _confirmDeleteAllSchools() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Projects'),
          content: const Text(
              'Are you sure you want to delete all Project Items? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllSchools,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAllSchools() async {
    final box = await Hive.openBox<ProjectItem>('projectItems');
    // Filter schools by global term ID
    final schoolsToDelete = box.values
        .cast<ProjectItem>()
        .where((s) => s.projectItemCode != null)
        .toList();

    for (var school in schoolsToDelete) {
      await box
          .delete(school.key); // Delete all schools with the matching term ID
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${schoolsToDelete.length} ProjectItem Deleted Successfully')),
    );

    setState(() {
      _foundSchools.clear();
      Navigator.pop(context); // Clear the displayed list
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete ProjectItem',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_forever, color: Colors.red, // Title color
            ),
            onPressed: _confirmDeleteAllSchools,
            tooltip: 'Delete All Project Items',
          ),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0,
        // Optional: Add a subtle shadow
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Enter ProjectItem Name to Search',
                      filled: true,
                      fillColor: Colors.white
                          .withOpacity(0.3), // Transparent background
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none, // No border
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a ProjectItem Name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: _searchSchool,
                      child: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_foundSchools.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _foundSchools.length,
                        itemBuilder: (context, index) {
                          final foundSchool = _foundSchools[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text('Name: ${foundSchool.name}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Code: ${foundSchool.projectItemCode}',
                                  style: const TextStyle(fontSize: 16)),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteSchool(foundSchool),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose controller to avoid memory leaks
    super.dispose();
  }
}
