import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateClassScreen extends StatefulWidget {
  final String classCode;

  const UpdateClassScreen({super.key, required this.classCode});

  @override
  _UpdateClassScreenState createState() => _UpdateClassScreenState();
}

class _UpdateClassScreenState extends State<UpdateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();

  late Classes _currentClass;
  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];
  bool _isSubmitting = false;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initializeData();
    _loadTerms();
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

  Future<void> _initializeData() async {
    final box = await Hive.openBox<Classes>('classes');

    final currentClass = box.values.firstWhere(
      (c) => c.classCode == widget.classCode,
      orElse: () => Classes(
        id: -1,
        className: '',
        classCode: '',
        date: DateTime(1970),
        termId: globalTermId,
      ),
    );

    if (currentClass.id == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Selected class not found')),
      );
      return;
    }

    setState(() {
      _currentClass = currentClass;
      _classNameController.text = currentClass.className;
      _selectedTerms = List<String>.from(currentClass.terms ?? []);
    });
  }

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    // ✅ Only load active (non-deleted) terms
    final activeTerms = termsBox.values
        .where((t) => !(t.isDeleted ?? false))
        .map((term) => term.termId)
        .toList();
    setState(() {
      _availableTerms = activeTerms;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = _currentClass.isDeleted ?? false;
    final isHost = _role == DeviceRole.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Class'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        foregroundColor: Colors.white,
        elevation: 4.0,
        actions: [
          // ✅ Show deletion status
          if (isDeleted)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DELETED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: CenteredFormContainer(
        title: 'Update Class',
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Status indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDeleted ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isDeleted ? Colors.red.shade300 : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDeleted ? Icons.delete_outline : Icons.check_circle,
                      color: isDeleted ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDeleted
                            ? '⚠️ This class is deleted. Update to restore it.'
                            : '✅ Class is active',
                        style: TextStyle(
                          color: isDeleted
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField('Class Name', _classNameController),
              const SizedBox(height: 20),
              _buildTermSelection(),
              const SizedBox(height: 20),

              // ✅ Update button with loading state
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _updateClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 38, 140, 191),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update Class',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              // ✅ Restore button for deleted classes
              if (isDeleted)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _restoreClass,
                      icon: const Icon(Icons.restore, color: Colors.green),
                      label: const Text(
                        'Restore This Class',
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermSelection() {
    return _availableTerms.isEmpty
        ? const Text('No terms available')
        : Column(
            children: _availableTerms.map((term) {
              return CheckboxListTile(
                title: Text(term),
                value: _selectedTerms.contains(term),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTerms.add(term);
                    } else {
                      _selectedTerms.remove(term);
                    }
                  });
                },
              );
            }).toList(),
          );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Future<void> _updateClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final box = await Hive.openBox<Classes>('classes');

      final currentClass = box.values.firstWhere(
        (c) => c.classCode == widget.classCode,
        orElse: () => Classes(
          id: -1,
          className: '',
          classCode: '',
          date: DateTime(1970),
          termId: globalTermId,
        ),
      );

      if (currentClass.id == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Class not found')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final oldClassName = currentClass.className;
      final className = _classNameController.text.trim().toLowerCase();

      // ✅ Check for duplicate names (excluding deleted and current)
      final existingClass = box.values.firstWhere(
        (c) =>
            c.className.toLowerCase() == className.toLowerCase() &&
            c.classCode != widget.classCode &&
            !(c.isDeleted ?? false),
        orElse: () => Classes(
          id: -1,
          className: '',
          classCode: '',
          date: DateTime(1970),
          termId: globalTermId,
        ),
      );

      if (existingClass.id != -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class with this name already exists')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // ✅ Track modified fields
      List<String> modifiedFields = currentClass.modifiedFields ?? [];
      if (currentClass.className != className &&
          !modifiedFields.contains('className')) {
        modifiedFields.add('className');
      }
      if (currentClass.terms?.join(',') != _selectedTerms.join(',') &&
          !modifiedFields.contains('terms')) {
        modifiedFields.add('terms');
      }

      // ✅ If class was deleted, restore on update
      final isDeleted = currentClass.isDeleted ?? false;

      final updatedClass = currentClass.copyWith(
        id: currentClass.id,
        className: className,
        date: DateTime.now(),
        termId: globalTermId,
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'update',
        modifiedFields: modifiedFields,
        terms: List<String>.from(_selectedTerms),
        // ✅ Restore if was deleted
        isDeleted: false,
        deletedSyncStatus: false,
      );

      // Delete the original record and insert updated
      await box.delete(widget.classCode);
      await box.put(widget.classCode, updatedClass);

      // Update related records
      await _updateStudentsTerms(oldClassName, className, updatedClass.terms);
      await _updateRelatedRecords(oldClassName, className);

      // ✅ Send update to server if client
      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        await _sendUpdateToServer(updatedClass);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDeleted
              ? '✅ Class restored and updated successfully'
              : '✅ Class Updated Successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating class: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendUpdateToServer(Classes classObj) async {
    if (_hostIp == null || _hostIp!.isEmpty) return;

    try {
      final classJson = {
        'classCode': classObj.classCode,
        'className': classObj.className,
        'date': classObj.date.toIso8601String(),
        'termId': classObj.termId,
        'terms': classObj.terms,
        'operationType': 'update',
        'syncStatus': 0,
        'lastModified': DateTime.now().toIso8601String(),
        'isDeleted': classObj.isDeleted ?? false,
        'deletedSyncStatus': classObj.deletedSyncStatus ?? false,
        'modifiedFields': classObj.modifiedFields,
      };

      final response = await http.put(
        Uri.parse('http://$_hostIp:8080/api/classes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(classJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        classObj.syncStatus = true;
        classObj.operationType = 'none';
        await classObj.save();
      }
    } catch (e) {
      print('Error sending update to server: $e');
    }
  }

  Future<void> _updateStudentsTerms(
      String oldClassName, String newClassName, List<String>? newTerms) async {
    final studentBox = await Hive.openBox<Student>('students');

    for (var student in studentBox.values
        .where((s) => s.class_ == oldClassName && !(s.isDeleted ?? false))) {
      List<String> studentTerms = List<String>.from(student.terms ?? []);

      if (newTerms != null) {
        for (var term in newTerms) {
          if (!studentTerms.contains(term)) {
            studentTerms.add(term);
          }
        }
        studentTerms.removeWhere((term) => !newTerms.contains(term));
      }

      await studentBox.put(
        student.key,
        student.copyWith(
          terms: studentTerms,
          syncStatus: false,
          lastModified: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _updateRelatedRecords(
      String oldClassName, String newClassName) async {
    final studentBox = await Hive.openBox<Student>('students');
    for (var student in studentBox.values
        .where((s) => s.class_ == oldClassName && !(s.isDeleted ?? false))) {
      await studentBox.put(
        student.key,
        student.copyWith(
          class_: newClassName,
          syncStatus: false,
          lastModified: DateTime.now(),
        ),
      );
    }

    final paymentsBox = await Hive.openBox<StudentPayment>('student_payments');
    for (var payment in paymentsBox.values.where(
        (p) => p.studentClass == oldClassName && !(p.isDeleted ?? false))) {
      await paymentsBox.put(
        payment.key,
        payment.copyWith(
          studentClass: newClassName,
          syncStatus: false,
          lastModified: DateTime.now(),
        ),
      );
    }

    final teachersBox = await Hive.openBox<Teachers>('teachers');
    for (var teacher in teachersBox.values.where(
        (t) => t.assignedClass == oldClassName && !(t.isDeleted ?? false))) {
      await teachersBox.put(
        teacher.key,
        teacher.copyWith(
          syncStatus: false,
          lastModified: DateTime.now(),
        ),
      );
    }
  }

  // ✅ Restore class
  Future<void> _restoreClass() async {
    setState(() => _isSubmitting = true);

    try {
      _currentClass.restoreDeleted();
      await _currentClass.save();

      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        final response = await http.post(
          Uri.parse('http://$_hostIp:8080/api/classes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'restore',
            'classCode': _currentClass.classCode,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _currentClass.syncStatus = true;
          _currentClass.deletedSyncStatus = true;
          await _currentClass.save();
        }
      }

      // Reload data
      await _initializeData();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Class restored successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring class: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }
}
