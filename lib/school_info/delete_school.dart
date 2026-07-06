import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class DeleteSchoolScreen extends StatefulWidget {
  const DeleteSchoolScreen({Key? key}) : super(key: key);

  @override
  _DeleteSchoolScreenState createState() => _DeleteSchoolScreenState();
}

class _DeleteSchoolScreenState extends State<DeleteSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  List<School> _foundSchools = [];
  List<School> _deletedSchools = [];
  bool _showDeleted = false;
  bool _isLoading = false;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAllSchools();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = stringToDeviceRole(prefs.getString('device_role') ?? '');
      _hostIp = prefs.getString('host_ip');
    });
  }

  DeviceRole? stringToDeviceRole(String role) {
    switch (role) {
      case 'client':
        return DeviceRole.client;
      case 'host':
        return DeviceRole.host;
      default:
        return null;
    }
  }

  void _loadAllSchools() async {
    setState(() => _isLoading = true);
    try {
      final box = await Hive.openBox<School>('school');
      final allSchools = box.values.where((s) => s.termId != null).toList();

      _foundSchools = allSchools.where((s) => !(s.isDeleted ?? false)).toList();
      _deletedSchools = allSchools.where((s) => s.isDeleted ?? false).toList();

      // Sort alphabetically
      _foundSchools
          .sort((a, b) => (a.schoolName ?? '').compareTo(b.schoolName ?? ''));
      _deletedSchools
          .sort((a, b) => (a.schoolName ?? '').compareTo(b.schoolName ?? ''));
    } catch (e) {
      print('Error loading schools: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchSchool() async {
    final box = await Hive.openBox<School>('school');
    final searchTerm = _searchController.text.toLowerCase().trim();

    if (searchTerm.isEmpty) {
      _loadAllSchools();
      return;
    }

    final allSchools = box.values.where((s) => s.termId != null).toList();

    final matchedSchools = allSchools
        .where((school) =>
            (school.schoolName?.toLowerCase().contains(searchTerm) ?? false) &&
            !(school.isDeleted ?? false))
        .toList()
      ..sort((a, b) => (a.schoolName ?? '').compareTo(b.schoolName ?? ''));

    setState(() {
      _foundSchools = matchedSchools;
    });
  }

  // ✅ SOFT DELETE School
  Future<void> _softDeleteSchool(School school, {String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await getLoggedInUser();

      // Mark as deleted locally
      school.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await school.save();

      // Send delete request to server (if client)
      if (_role == DeviceRole.client && _hostIp != null) {
        try {
          final response = await http.delete(
            Uri.parse('http://$_hostIp:8080/api/school'
                '?schoolCode=${school.schoolCode}'
                '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
                '&reason=${Uri.encodeComponent(reason ?? "")}'),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            school.deletedSyncStatus = true;
            school.syncStatus = true;
            school.operationType = 'none';
            await school.save();
          }
        } catch (e) {
          print('Error syncing deletion to server: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('School ${school.schoolName} deleted successfully')),
      );

      _loadAllSchools();
      _searchController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting school: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ RESTORE School
  Future<void> _restoreSchool(School school) async {
    setState(() => _isLoading = true);

    try {
      school.restoreDeleted();
      await school.save();

      if (_role == DeviceRole.client && _hostIp != null) {
        try {
          final response = await http.post(
            Uri.parse('http://$_hostIp:8080/api/school'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'restore',
              'schoolCode': school.schoolCode,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            school.syncStatus = true;
            school.deletedSyncStatus = true;
            school.operationType = 'none';
            await school.save();
          }
        } catch (e) {
          print('Error syncing restore to server: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('School ${school.schoolName} restored successfully')),
      );

      _loadAllSchools();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring school: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ PERMANENTLY DELETE School
  Future<void> _permanentlyDeleteSchool(School school) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete School'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${school.schoolName}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await school.delete();
        _loadAllSchools();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('School ${school.schoolName} permanently deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error permanently deleting school: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(School school) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete School'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${school.schoolName}"?'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Reason for deletion (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => reason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _softDeleteSchool(school, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ✅ Delete all schools (soft delete)
  Future<void> _deleteAllSchools() async {
    setState(() => _isLoading = true);

    try {
      final box = await Hive.openBox<School>('school');
      final schoolsToDelete = box.values
          .where((s) => s.termId != null && !(s.isDeleted ?? false))
          .toList();

      if (schoolsToDelete.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No schools to delete')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final currentUser = await getLoggedInUser();

      for (var school in schoolsToDelete) {
        school.markDeleted(
          deletedBy: currentUser?.username ?? 'system',
          reason: 'Bulk delete all schools',
        );
        await school.save();
      }

      // Sync to server if client
      if (_role == DeviceRole.client && _hostIp != null) {
        // Send bulk delete to server
        final schoolCodes = schoolsToDelete.map((s) => s.schoolCode).toList();
        try {
          await http.post(
            Uri.parse('http://$_hostIp:8080/api/school/bulk-delete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'schoolCodes': schoolCodes,
              'deletedBy': currentUser?.username ?? 'system',
              'reason': 'Bulk delete all schools',
            }),
          );
        } catch (e) {
          print('Error syncing bulk delete: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${schoolsToDelete.length} Schools deleted successfully'),
        ),
      );

      _loadAllSchools();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting schools: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Show delete all confirmation dialog
  void _confirmDeleteAllSchools() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Schools'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure you want to delete all schools for the current term? This action cannot be undone.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Schools will be soft-deleted and can be restored.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllSchools,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _showDeleted ? _deletedSchools : _foundSchools;
    final hasDeleted = _deletedSchools.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete School',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // ✅ Show deleted toggle
          if (hasDeleted)
            IconButton(
              icon: Icon(
                _showDeleted ? Icons.visibility : Icons.visibility_off,
                color: _showDeleted ? Colors.orange : Colors.white,
              ),
              onPressed: () => setState(() => _showDeleted = !_showDeleted),
              tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
            ),
          // ✅ Deleted count badge
          if (hasDeleted && !_showDeleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_deletedSchools.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          // ✅ Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllSchools,
            tooltip: 'Refresh',
          ),
          // ✅ Delete all button
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllSchools,
            tooltip: 'Delete All Schools',
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Search field
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: _showDeleted
                          ? 'Search in deleted schools'
                          : 'Enter School Name to Search',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadAllSchools();
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        _loadAllSchools();
                      }
                    },
                    onFieldSubmitted: (value) => _searchSchool(),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Search button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _searchSchool,
                          child: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loadAllSchools,
                          child: const Text('Show All'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ✅ Status indicator
                  if (_showDeleted && _deletedSchools.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Showing deleted schools. Tap "Show All" to view active schools.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ✅ School list
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (displayList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          _showDeleted
                              ? 'No deleted schools found'
                              : 'No schools found. Try a different search.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final school = displayList[index];
                          final isDeleted = school.isDeleted ?? false;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            color: isDeleted ? Colors.grey.shade100 : null,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                school.schoolName ?? 'Unnamed School',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDeleted ? Colors.grey : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Term: ${school.termId ?? "N/A"}',
                                    style: TextStyle(
                                      color: isDeleted ? Colors.grey : null,
                                    ),
                                  ),
                                  if (isDeleted && school.deletedAt != null)
                                    Text(
                                      'Deleted: ${school.deletedAt!.toString().substring(0, 16)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDeleted) ...[
                                    // ✅ Restore button
                                    IconButton(
                                      icon: const Icon(Icons.restore,
                                          color: Colors.green),
                                      onPressed: () => _restoreSchool(school),
                                      tooltip: 'Restore',
                                    ),
                                    // ✅ Permanent delete
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _permanentlyDeleteSchool(school),
                                      tooltip: 'Delete Forever',
                                    ),
                                  ] else ...[
                                    // ✅ Delete button
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _showDeleteConfirmation(school),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ],
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
    _searchController.dispose();
    super.dispose();
  }
}
