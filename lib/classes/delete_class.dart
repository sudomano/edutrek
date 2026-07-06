import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class DeleteClassScreen extends StatefulWidget {
  final Classes? classToDelete;

  const DeleteClassScreen({Key? key, this.classToDelete}) : super(key: key);

  @override
  _DeleteClassScreenState createState() => _DeleteClassScreenState();
}

class _DeleteClassScreenState extends State<DeleteClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indexController = TextEditingController();
  List<Classes> _foundClasses = [];
  List<Classes> _deletedClasses = [];
  bool _showDeleted = false;
  bool _isLoading = false;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAllClasses();

    if (widget.classToDelete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDeleteConfirmation(widget.classToDelete!);
      });
    }
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

  void _loadAllClasses() {
    setState(() => _isLoading = true);

    try {
      final box = Hive.box<Classes>('classes');
      final allClasses = box.values
          .where((item) => item is Classes)
          .cast<Classes>()
          .where((c) => c.termId != null)
          .toList()
        ..sort((a, b) => a.className.compareTo(b.className));

      _foundClasses = allClasses.where((c) => !(c.isDeleted ?? false)).toList();

      _deletedClasses = allClasses.where((c) => c.isDeleted ?? false).toList();
    } catch (e) {
      print('Error loading classes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchClass() {
    final searchTerm = _indexController.text.toLowerCase().trim();

    if (searchTerm.isEmpty) {
      _loadAllClasses();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final box = Hive.box<Classes>('classes');
      final allClasses = box.values
          .where((item) => item is Classes)
          .cast<Classes>()
          .where((c) => c.termId != null)
          .toList();

      final matchedClasses = allClasses
          .where((c) =>
              c.className.toLowerCase().contains(searchTerm) &&
              !(c.isDeleted ?? false))
          .toList()
        ..sort((a, b) => a.className.compareTo(b.className));

      setState(() {
        _foundClasses = matchedClasses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error searching classes: $e');
    }
  }

  // ✅ SOFT DELETE Class
  Future<void> _softDeleteClass(Classes classObj, {String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await getLoggedInUser();

      // Mark class as deleted locally
      classObj.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await classObj.save();

      // ✅ Also mark related records
      await _markRelatedRecordsDeleted(classObj.className);

      // Send delete request to server (if client)
      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final response = await http.delete(
            Uri.parse('http://$_hostIp:8080/api/classes'
                '?classCode=${classObj.classCode}'
                '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
                '&reason=${Uri.encodeComponent(reason ?? "")}'),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            classObj.deletedSyncStatus = true;
            classObj.syncStatus = true;
            classObj.operationType = 'none';
            await classObj.save();
          }
        } catch (e) {
          print('Error syncing deletion to server: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Class "${classObj.className}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadAllClasses();
      _indexController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting class: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Mark related records as deleted
  Future<void> _markRelatedRecordsDeleted(String className) async {
    try {
      final boxes = [
        Hive.box<Student>('students'),
        Hive.box<StudentPayment>('student_payments'),
        Hive.box<Teachers>('teachers'),
      ];

      for (var box in boxes) {
        for (var key in box.keys) {
          var item = box.get(key);
          if (item != null) {
            try {
              final dynamic dynamicItem = item;
              // Check if it has the class field
              String? classField;
              if (dynamicItem.class_ != null) {
                classField = dynamicItem.class_;
              } else if (dynamicItem.studentClass != null) {
                classField = dynamicItem.studentClass;
              } else if (dynamicItem.assignedClass != null) {
                classField = dynamicItem.assignedClass;
              }

              if (classField == className && dynamicItem.markDeleted != null) {
                dynamicItem.markDeleted(
                  deletedBy: 'system',
                  reason: 'Class ${className} deleted',
                );
                await box.put(key, dynamicItem);
              }
            } catch (e) {
              // Item doesn't have required fields - skip
            }
          }
        }
      }
    } catch (e) {
      print('Error marking related records as deleted: $e');
    }
  }

  // ✅ RESTORE Class
  Future<void> _restoreClass(Classes classObj) async {
    setState(() => _isLoading = true);

    try {
      classObj.restoreDeleted();
      await classObj.save();

      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final response = await http.post(
            Uri.parse('http://$_hostIp:8080/api/classes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'restore',
              'classCode': classObj.classCode,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            classObj.syncStatus = true;
            classObj.deletedSyncStatus = true;
            classObj.operationType = 'none';
            await classObj.save();
          }
        } catch (e) {
          print('Error syncing restore to server: $e');
        }
      }

      _loadAllClasses();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Class "${classObj.className}" restored successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring class: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ PERMANENTLY DELETE Class
  Future<void> _permanentlyDeleteClass(Classes classObj) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${classObj.className}"?'),
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
        await classObj.delete();
        _loadAllClasses();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Class "${classObj.className}" permanently deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error permanently deleting class: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(Classes classObj) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${classObj.className}"?'),
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
              _softDeleteClass(classObj, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ✅ Confirm delete all classes
  void _confirmDeleteAllClasses() {
    final activeCount = _foundClasses.length;
    if (activeCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active classes to delete')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Classes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete all $activeCount classes for the current term?',
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Classes will be soft-deleted and can be restored.',
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
              onPressed: _deleteAllClasses,
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

  // ✅ Soft delete all classes
  Future<void> _deleteAllClasses() async {
    setState(() => _isLoading = true);

    try {
      final classesToDelete = List.from(_foundClasses);

      if (classesToDelete.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active classes to delete')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final currentUser = await getLoggedInUser();

      for (var classObj in classesToDelete) {
        classObj.markDeleted(
          deletedBy: currentUser?.username ?? 'system',
          reason: 'Bulk delete all classes',
        );
        await classObj.save();
        await _markRelatedRecordsDeleted(classObj.className);
      }

      // Sync to server if client
      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final classCodes = classesToDelete.map((c) => c.classCode).toList();
          await http.post(
            Uri.parse('http://$_hostIp:8080/api/classes/bulk-delete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'classCodes': classCodes,
              'deletedBy': currentUser?.username ?? 'system',
              'reason': 'Bulk delete all classes',
            }),
          );
        } catch (e) {
          print('Error syncing bulk delete: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${classesToDelete.length} Classes deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadAllClasses();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting classes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _showDeleted ? _deletedClasses : _foundClasses;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Delete Class',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.normal,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        actions: [
          if (_deletedClasses.isNotEmpty)
            IconButton(
              icon: Icon(
                _showDeleted ? Icons.visibility : Icons.visibility_off,
                color: _showDeleted ? Colors.orange : Colors.white,
              ),
              onPressed: () => setState(() => _showDeleted = !_showDeleted),
              tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
            ),
          if (_deletedClasses.isNotEmpty && !_showDeleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_deletedClasses.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllClasses,
            tooltip: 'Delete All Classes',
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        elevation: 4.0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _indexController,
                          decoration: InputDecoration(
                            labelText: _showDeleted
                                ? 'Search in deleted classes'
                                : 'Enter Class Name to Search',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _indexController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _indexController.clear();
                                      _loadAllClasses();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            if (value.isEmpty) {
                              _loadAllClasses();
                            }
                          },
                          onFieldSubmitted: (value) => _searchClass(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _searchClass,
                                child: const Text('Search'),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loadAllClasses,
                                child: const Text('Show All'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_showDeleted && _deletedClasses.isNotEmpty)
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
                                  'Showing deleted classes. Tap "Show All" to view active classes.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (displayList.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                _showDeleted
                                    ? 'No deleted classes found'
                                    : 'No classes found. Try a different search.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: displayList.length,
                              itemBuilder: (context, index) {
                                final classObj = displayList[index];
                                final isDeleted = classObj.isDeleted ?? false;

                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                  color:
                                      isDeleted ? Colors.grey.shade100 : null,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Text(
                                      classObj.className,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Created: ${classObj.date.toLocal().toString().split(' ')[0]}',
                                          style: TextStyle(
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                        if (isDeleted &&
                                            classObj.deletedAt != null)
                                          Text(
                                            'Deleted: ${classObj.deletedAt!.toString().substring(0, 16)}',
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
                                          IconButton(
                                            icon: const Icon(Icons.restore,
                                                color: Colors.green),
                                            onPressed: () =>
                                                _restoreClass(classObj),
                                            tooltip: 'Restore',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_forever,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _permanentlyDeleteClass(
                                                    classObj),
                                            tooltip: 'Delete Forever',
                                          ),
                                        ] else ...[
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _showDeleteConfirmation(
                                                    classObj),
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
    _indexController.dispose();
    super.dispose();
  }
}
