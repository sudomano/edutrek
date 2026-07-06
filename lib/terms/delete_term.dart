import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class DeleteTermScreen extends StatefulWidget {
  const DeleteTermScreen({Key? key}) : super(key: key);

  @override
  _DeleteTermScreenState createState() => _DeleteTermScreenState();
}

class _DeleteTermScreenState extends State<DeleteTermScreen> {
  final _formKey = GlobalKey<FormState>();
  final _termController = TextEditingController();
  List<Terms> _foundTerms = [];
  List<Terms> _deletedTerms = [];
  bool _showDeleted = false;
  bool _isLoading = false;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAllTerms();
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

  // ✅ FIXED: Properly typed method with casting
  void _loadAllTerms() {
    setState(() => _isLoading = true);

    try {
      final box = Hive.box<Terms>('terms');
      final allTerms = box.values
          .where((item) => item is Terms) // ✅ Type guard
          .cast<Terms>() // ✅ Cast to Terms
          .toList();

      _foundTerms = allTerms.where((t) => !(t.isDeleted ?? false)).toList()
        ..sort((a, b) => a.termId.compareTo(b.termId));

      _deletedTerms = allTerms.where((t) => t.isDeleted ?? false).toList()
        ..sort((a, b) => a.termId.compareTo(b.termId));
    } catch (e) {
      print('Error loading terms: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _searchTerm() {
    final searchTerm = _termController.text.toLowerCase().trim();

    if (searchTerm.isEmpty) {
      _loadAllTerms();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final box = Hive.box<Terms>('terms');
      final allTerms =
          box.values.where((item) => item is Terms).cast<Terms>().toList();

      final matchedTerms = allTerms
          .where((term) =>
              term.termId.toLowerCase().contains(searchTerm) &&
              term.status.toLowerCase() != 'opened' &&
              !(term.isDeleted ?? false))
          .toList()
        ..sort((a, b) => a.termId.compareTo(b.termId));

      if (matchedTerms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No active terms found. Note: Opened terms cannot be deleted. '
              'If the term is opened, close it by creating a new term.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        _foundTerms = [];
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _foundTerms = matchedTerms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error searching terms: $e');
    }
  }

  // ✅ SOFT DELETE Term
  Future<void> _softDeleteTerm(Terms termToDelete, {String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await getLoggedInUser();

      // Mark term as deleted locally
      termToDelete.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await termToDelete.save();

      // ✅ Also mark related records with this termId
      await _markRelatedRecordsDeleted(termToDelete.termId);

      // Send delete request to server (if client)
      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final response = await http.delete(
            Uri.parse('http://$_hostIp:8080/api/terms'
                '?termId=${termToDelete.termId}'
                '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
                '&reason=${Uri.encodeComponent(reason ?? "")}'),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            termToDelete.deletedSyncStatus = true;
            termToDelete.syncStatus = true;
            termToDelete.operationType = 'none';
            await termToDelete.save();
          }
        } catch (e) {
          print('Error syncing deletion to server: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Term "${termToDelete.termName}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadAllTerms();
      _termController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting term: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Mark related records as deleted
  Future<void> _markRelatedRecordsDeleted(String termId) async {
    try {
      final boxes = [
        Hive.box<Student>('students'),
        Hive.box<Classes>('classes'),
        Hive.box<Teachers>('teachers'),
        Hive.box<StudentPayment>('student_payments'),
        Hive.box<TeacherPayment>('teacher_payments'),
        Hive.box<PaymentPurpose>('payment_purposes'),
        Hive.box<TeacherPaymentsPurposes>('teacher_payments_purposes'),
        Hive.box<Withdrawal>('withdrawals'),
      ];

      for (var box in boxes) {
        for (var key in box.keys) {
          var item = box.get(key);
          if (item != null) {
            // Check if item has termId field and isDeleted method
            try {
              // Use reflection-like approach with dynamic
              final dynamic dynamicItem = item;
              final itemTermId = dynamicItem.termId;
              if (itemTermId == termId) {
                // Check if it has markDeleted method
                if (dynamicItem.markDeleted != null) {
                  dynamicItem.markDeleted(
                    deletedBy: 'system',
                    reason: 'Term ${termId} deleted',
                  );
                  await box.put(key, dynamicItem);
                }
              }
            } catch (e) {
              // Item doesn't have termId or markDeleted method - skip
            }
          }
        }
      }
    } catch (e) {
      print('Error marking related records as deleted: $e');
    }
  }

  // ✅ RESTORE Term
  Future<void> _restoreTerm(Terms term) async {
    setState(() => _isLoading = true);

    try {
      term.restoreDeleted();
      await term.save();

      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final response = await http.post(
            Uri.parse('http://$_hostIp:8080/api/terms'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'restore',
              'termId': term.termId,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            term.syncStatus = true;
            term.deletedSyncStatus = true;
            term.operationType = 'none';
            await term.save();
          }
        } catch (e) {
          print('Error syncing restore to server: $e');
        }
      }

      _loadAllTerms();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Term "${term.termName}" restored successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring term: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ PERMANENTLY DELETE Term
  Future<void> _permanentlyDeleteTerm(Terms term) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${term.termName}"?'),
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
        await term.delete();
        _loadAllTerms();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Term "${term.termName}" permanently deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error permanently deleting term: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(Terms term) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${term.termName}"?'),
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
              _softDeleteTerm(term, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ✅ Confirm delete all terms
  void _confirmDeleteAllTerms() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Terms'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete all terms? All records associated with all terms will be lost! This action cannot be undone.',
              ),
              SizedBox(height: 12),
              Text(
                'Note: Terms will be soft-deleted and can be restored.',
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
              onPressed: _deleteAllTerms,
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

  // ✅ Soft delete all terms
  Future<void> _deleteAllTerms() async {
    setState(() => _isLoading = true);

    try {
      final termsBox = Hive.box<Terms>('terms');
      final allTerms = termsBox.values
          .where((item) => item is Terms)
          .cast<Terms>()
          .where((t) => !(t.isDeleted ?? false))
          .toList();

      if (allTerms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active terms to delete')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final currentUser = await getLoggedInUser();

      for (var term in allTerms) {
        term.markDeleted(
          deletedBy: currentUser?.username ?? 'system',
          reason: 'Bulk delete all terms',
        );
        await term.save();
      }

      // Mark related records
      final termIds = allTerms.map((t) => t.termId).toList();
      for (var termId in termIds) {
        await _markRelatedRecordsDeleted(termId);
      }

      // Sync to server if client
      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          await http.post(
            Uri.parse('http://$_hostIp:8080/api/terms/bulk-delete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'termIds': termIds,
              'deletedBy': currentUser?.username ?? 'system',
              'reason': 'Bulk delete all terms',
            }),
          );
        } catch (e) {
          print('Error syncing bulk delete: $e');
        }
      }

      globalTermId = null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${allTerms.length} Terms deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadAllTerms();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting terms: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _showDeleted ? _deletedTerms : _foundTerms;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Term',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (_deletedTerms.isNotEmpty)
            IconButton(
              icon: Icon(
                _showDeleted ? Icons.visibility : Icons.visibility_off,
                color: _showDeleted ? Colors.orange : Colors.white,
              ),
              onPressed: () => setState(() => _showDeleted = !_showDeleted),
              tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
            ),
          if (_deletedTerms.isNotEmpty && !_showDeleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_deletedTerms.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _confirmDeleteAllTerms,
            tooltip: 'Delete All Terms',
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
                          controller: _termController,
                          decoration: InputDecoration(
                            labelText: _showDeleted
                                ? 'Search in deleted terms'
                                : 'Enter Term Name to Search',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _termController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _termController.clear();
                                      _loadAllTerms();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            if (value.isEmpty) {
                              _loadAllTerms();
                            }
                          },
                          onFieldSubmitted: (value) => _searchTerm(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _searchTerm,
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
                                onPressed: _loadAllTerms,
                                child: const Text('Show All'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_showDeleted && _deletedTerms.isNotEmpty)
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
                                  'Showing deleted terms. Tap "Show All" to view active terms.',
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
                                    ? 'No deleted terms found'
                                    : 'No terms found. Try a different search.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: displayList.length,
                              itemBuilder: (context, index) {
                                final term = displayList[index];
                                final isDeleted = term.isDeleted ?? false;

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
                                      term.termName,
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
                                          'ID: ${term.termId}',
                                          style: TextStyle(
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                        Text(
                                          'Started: ${term.startDate.toLocal().toString().split(' ')[0]}',
                                          style: TextStyle(
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                        if (isDeleted && term.deletedAt != null)
                                          Text(
                                            'Deleted: ${term.deletedAt!.toString().substring(0, 16)}',
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
                                            onPressed: () => _restoreTerm(term),
                                            tooltip: 'Restore',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_forever,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _permanentlyDeleteTerm(term),
                                            tooltip: 'Delete Forever',
                                          ),
                                        ] else if (term.status.toLowerCase() !=
                                            'opened') ...[
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _showDeleteConfirmation(term),
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
    _termController.dispose();
    super.dispose();
  }
}
