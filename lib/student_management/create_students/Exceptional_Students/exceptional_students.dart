import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';

class ExceptionalStudentsScreen extends StatefulWidget {
  @override
  _ExceptionalStudentsScreenState createState() =>
      _ExceptionalStudentsScreenState();
}

class _ExceptionalStudentsScreenState extends State<ExceptionalStudentsScreen> {
  final Box<ExceptionalStudents> _box =
      Hive.box<ExceptionalStudents>('exceptionalStudentsBox');
  late final Box<Terms> _termBox;

  final _formKey = GlobalKey<FormState>();
  ExceptionalStudents? _currentException;

  final _exceptionNameController = TextEditingController();
  final _exceptionFigureController = TextEditingController();

  String _selectedType = 'PERCENTAGE';
  String _selectedStatus = 'ACTIVE';
  int _priorityFlag = 0; // 0 = less priority, 1 = top priority
  Set<String> _selectedTerms = {};

  final List<String> _typeOptions = ['PERCENTAGE', 'AMOUNT', 'OTHER'];
  final List<String> _statusOptions = ['ACTIVE', 'PAUSED', 'STOPPED'];

  bool _isEditing = false;
  bool _applyToAllStudents = false;
  bool _removeFromAllStudents = false;

  String? _globalTermId;
  bool _isComputing = false;
  bool _showDeleted = false; // ✅ Toggle to show deleted exceptions

  @override
  void initState() {
    super.initState();
    _termBox = Hive.box<Terms>('terms');
  }

  @override
  void dispose() {
    _exceptionNameController.dispose();
    _exceptionFigureController.dispose();
    super.dispose();
  }

  void _startEdit(ExceptionalStudents exception) {
    setState(() {
      _isEditing = true;
      _currentException = exception;
      _exceptionNameController.text = exception.exceptionName ?? '';
      _exceptionFigureController.text = exception.exceptionFigure ?? '';
      _selectedType = exception.exceptionType ?? 'PERCENTAGE';
      _selectedStatus = exception.exceptionStatus ?? 'ACTIVE';
      _priorityFlag = exception.priorityFlag ?? 0;
      _selectedTerms = Set<String>.from(exception.terms ?? []);
    });
  }

  Future<void> _saveException() async {
    if (_formKey.currentState!.validate()) {
      final isNew = !_isEditing;
      final now = DateTime.now();

      // Update modified fields list
      List<String> modifiedFields = [
        'exceptionName',
        'exceptionType',
        'exceptionFigure',
        'exceptionStatus',
        'terms',
        'priorityFlag',
      ];

      // ✅ If restoring a deleted exception, clear deletion fields
      if (_currentException != null &&
          (_currentException!.isDeleted ?? false)) {
        modifiedFields.addAll([
          'isDeleted',
          'deletedAt',
          'deletedBy',
          'deleteReason',
          'deletedSyncStatus'
        ]);
      }

      final updated = ExceptionalStudents(
        exceptionId: _currentException?.exceptionId ?? const Uuid().v4(),
        exceptionName: _exceptionNameController.text,
        exceptionStatus: _selectedStatus,
        exceptionType: _selectedType,
        exceptionFigure: _exceptionFigureController.text,
        syncStatus: false,
        lastModified: now,
        operationType: isNew ? 'create' : 'update',
        modifiedFields: modifiedFields,
        terms: _selectedTerms.toList(),
        priorityFlag: _priorityFlag,
        // ✅ If restoring, clear deletion flags
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        deleteReason: null,
        deletedSyncStatus: false,
      );

      if (isNew) {
        _box.add(updated);
      } else {
        if (_currentException != null) {
          final key =
              _box.keyAt(_box.values.toList().indexOf(_currentException!));
          final updatedException = _currentException!
            ..exceptionName = updated.exceptionName
            ..exceptionType = updated.exceptionType
            ..exceptionFigure = updated.exceptionFigure
            ..exceptionStatus = updated.exceptionStatus
            ..terms = updated.terms
            ..priorityFlag = updated.priorityFlag
            ..lastModified = now
            ..operationType = 'update'
            ..syncStatus = false
            ..isDeleted = false
            ..deletedAt = null
            ..deletedBy = null
            ..deleteReason = null
            ..deletedSyncStatus = false;

          _box.put(key, updatedException);
          final studentBox = Hive.box<Student>('students');
          final paymentPurposeBox =
              Hive.box<PaymentPurpose>('payment_purposes');

          final updatedId = updated.exceptionId;

          // Update references in Student models
          for (final key in studentBox.keys) {
            final student = studentBox.get(key);
            if (student == null) continue;

            final hasMatch =
                student.exceptions?.any((e) => e.exceptionId == updatedId) ??
                    false;
            if (hasMatch) {
              final updatedExceptions = student.exceptions!.map((e) {
                return e.exceptionId == updatedId ? updated : e;
              }).toList();

              student
                ..exceptions = updatedExceptions
                ..syncStatus = false
                ..operationType = 'update'
                ..lastModified = now;

              await studentBox.put(key, student);
            }
          }

          // Update references in PaymentPurpose models
          for (final key in paymentPurposeBox.keys) {
            final pp = paymentPurposeBox.get(key);
            if (pp == null) continue;

            final hasMatch =
                pp.exceptions?.any((e) => e.exceptionId == updatedId) ?? false;
            if (hasMatch) {
              final updatedExceptions = pp.exceptions!.map((e) {
                return e.exceptionId == updatedId ? updated : e;
              }).toList();

              pp
                ..exceptions = updatedExceptions
                ..syncStatus = false
                ..operationType = 'update'
                ..lastModified = now;

              await paymentPurposeBox.put(key, pp);
            }
          }
        }
      }

      // Apply/Remove logic
      if (_applyToAllStudents &&
          updated.terms != null &&
          updated.terms!.isNotEmpty) {
        setState(() => _isComputing = true);

        final studentBox = Hive.box<Student>('students');
        final globalTermIds = updated.terms!;
        final now = DateTime.now();
        final exceptionId = updated.exceptionId;

        for (final key in studentBox.keys) {
          final student = studentBox.get(key);
          if (student == null) continue;

          final studentTerms = student.terms ?? [];
          final matches = studentTerms.any((t) => globalTermIds.contains(t));

          final existingList = (student.exceptions ?? []);

          final hasException =
              existingList.any((e) => e.exceptionId == exceptionId);

          if (matches && !hasException) {
            existingList.add(updated);
            student
              ..exceptions = existingList
              ..operationType = 'update'
              ..syncStatus = false
              ..lastModified = now;
            await studentBox.put(key, student);
            continue;
          }

          if (!matches && hasException) {
            existingList.removeWhere((e) => e.exceptionId == exceptionId);
            student
              ..exceptions = existingList
              ..operationType = 'update'
              ..syncStatus = false
              ..lastModified = now;
            await studentBox.put(key, student);
            continue;
          }

          if (matches && hasException) {
            final updatedExceptions = existingList.map((e) {
              return e.exceptionId == exceptionId ? updated : e;
            }).toList();
            student
              ..exceptions = updatedExceptions
              ..operationType = 'update'
              ..syncStatus = false
              ..lastModified = now;
            await studentBox.put(key, student);
          }
        }

        setState(() => _isComputing = false);
      }

      if (_removeFromAllStudents && !isNew) {
        setState(() => _isComputing = true);

        final studentBox = Hive.box<Student>('students');
        final exceptionId = updated.exceptionId;
        final now = DateTime.now();

        for (final key in studentBox.keys) {
          final student = studentBox.get(key);
          if (student == null) continue;

          if (student.exceptions != null &&
              student.exceptions!.any((e) => e.exceptionId == exceptionId)) {
            student.exceptions!
                .removeWhere((e) => e.exceptionId == exceptionId);
            student
              ..exceptions = student.exceptions
              ..syncStatus = false
              ..operationType = 'update'
              ..lastModified = now;

            await studentBox.put(key, student);
          }
        }

        setState(() => _isComputing = false);
        _resetForm();
        return;
      }

      _resetForm();
    }
  }

  // ✅ SOFT DELETE - Mark as deleted instead of hard delete
  void _deleteException(ExceptionalStudents exception) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soft delete exception: ${exception.exceptionName}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will mark the exception as deleted and sync to host.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${exception.exceptionStatus}',
              style: TextStyle(
                fontSize: 12,
                color: exception.exceptionStatus == 'ACTIVE'
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performSoftDelete(exception);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performSoftDelete(ExceptionalStudents exception) {
    final studentBox = Hive.box<Student>('students');
    final paymentPurposeBox = Hive.box<PaymentPurpose>('payment_purposes');

    final now = DateTime.now();

    // ✅ Mark exception as deleted
    exception.markDeleted(
      deletedBy: 'User: ${exception.exceptionName}',
      reason: 'Soft deleted from ExceptionalStudentsScreen',
    );
    exception.save();

    // ✅ Update references in Student models
    for (var student in studentBox.values) {
      if (student.exceptions != null &&
          student.exceptions!
              .any((e) => e.exceptionId == exception.exceptionId)) {
        // Remove from student's exceptions list
        student.exceptions!
            .removeWhere((e) => e.exceptionId == exception.exceptionId);

        student
          ..syncStatus = false
          ..operationType = 'update'
          ..lastModified = now;

        final key =
            studentBox.keyAt(studentBox.values.toList().indexOf(student));
        studentBox.put(key, student);
      }
    }

    // ✅ Update references in PaymentPurpose models
    for (var pp in paymentPurposeBox.values) {
      if (pp.exceptions != null &&
          pp.exceptions!.any((e) => e.exceptionId == exception.exceptionId)) {
        pp.exceptions!
            .removeWhere((e) => e.exceptionId == exception.exceptionId);

        final key = paymentPurposeBox
            .keyAt(paymentPurposeBox.values.toList().indexOf(pp));
        pp
          ..syncStatus = false
          ..operationType = 'update'
          ..lastModified = now;
        paymentPurposeBox.put(key, pp);
      }
    }

    _showDialog('✅ Exception soft-deleted successfully.\n'
        'Exception: ${exception.exceptionName}\n'
        'Deletion will sync to host when online.');
  }

  // ✅ Restore deleted exception
  void _restoreException(ExceptionalStudents exception) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Restore exception: ${exception.exceptionName}?\n\n'
          'This will mark the exception as active again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performRestore(exception);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _performRestore(ExceptionalStudents exception) {
    exception.restoreDeleted();
    exception.save();

    _showDialog('✅ Exception restored successfully.\n'
        'Exception: ${exception.exceptionName}\n'
        'Restoration will sync to host when online.');
  }

  void _showDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _currentException = null;
      _exceptionNameController.clear();
      _exceptionFigureController.clear();
      _selectedType = 'PERCENTAGE';
      _selectedStatus = 'ACTIVE';
      _priorityFlag = 0;
      _selectedTerms.clear();
      _applyToAllStudents = false;
      _removeFromAllStudents = false;
    });
  }

  Widget _buildTermsChecklist() {
    if (_termBox.isEmpty) return const Text("No terms available.");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _selectedTerms.length == _termBox.length,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedTerms =
                        _termBox.values.map((e) => e.termId.toString()).toSet();
                  } else {
                    _selectedTerms.clear();
                  }
                });
              },
            ),
            const Text("Select All Terms"),
          ],
        ),
        ..._termBox.values.map((term) {
          final termId = term.termId;
          return CheckboxListTile(
            title: Text(term.termId ?? 'Unnamed Term'),
            value: _selectedTerms.contains(termId),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedTerms.add(termId.toString());
                } else {
                  _selectedTerms.remove(termId);
                }
              });
            },
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Exceptional Students Management')),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // ✅ Toggle to show deleted exceptions
          IconButton(
            icon: Icon(
              _showDeleted ? Icons.visibility : Icons.visibility_off,
              color: _showDeleted ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDeleted = !_showDeleted;
              });
            },
            tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
          ),
        ],
      ),
      body: _isComputing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Processing students... Please wait.'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing
                                  ? 'Edit Exception'
                                  : 'Add New Exception',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Exception Name
                            TextFormField(
                              controller: _exceptionNameController,
                              decoration: const InputDecoration(
                                labelText: 'Exception Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.label),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Enter a name' : null,
                            ),
                            const SizedBox(height: 12),
                            // Exception Type
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              items: _typeOptions
                                  .map((type) => DropdownMenuItem(
                                      value: type, child: Text(type)))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedType = value!),
                              decoration: const InputDecoration(
                                labelText: 'Exception Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Exception Value
                            if (_selectedType == "PERCENTAGE")
                              TextFormField(
                                controller: _exceptionFigureController,
                                decoration: const InputDecoration(
                                  labelText: 'Percentage Value',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.percent),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter a percent value';
                                  }
                                  final parsed = double.tryParse(value);
                                  if (parsed == null) {
                                    return 'Enter a valid number';
                                  }
                                  if (parsed > 100 || parsed < 0) {
                                    return 'Percent must be between 0 and 100';
                                  }
                                  return null;
                                },
                              ),
                            if (_selectedType == "AMOUNT")
                              TextFormField(
                                controller: _exceptionFigureController,
                                decoration: const InputDecoration(
                                  labelText: 'Amount Value',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.attach_money),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter an amount';
                                  }
                                  final parsed = double.tryParse(value);
                                  if (parsed == null) {
                                    return 'Enter a valid number';
                                  }
                                  if (parsed < 0) {
                                    return 'Amount must be at least 0';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 12),
                            // Exception Status
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              items: _statusOptions
                                  .map((status) => DropdownMenuItem(
                                      value: status, child: Text(status)))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedStatus = value!),
                              decoration: const InputDecoration(
                                labelText: 'Exception Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.circle),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Priority Flag
                            Card(
                              color: _priorityFlag == 1
                                  ? Colors.red.shade50
                                  : Colors.grey.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.priority_high),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Priority Flag',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _priorityFlag == 1
                                                ? '🔴 Top Priority - This exception will be applied first'
                                                : '⚪ Normal Priority - Applied after priority exceptions',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _priorityFlag == 1
                                                  ? Colors.red
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _priorityFlag == 1,
                                      onChanged: (value) {
                                        setState(() {
                                          _priorityFlag = value ? 1 : 0;
                                        });
                                      },
                                      activeColor: Colors.red,
                                      activeTrackColor: Colors.red.shade200,
                                      inactiveThumbColor: Colors.grey,
                                      inactiveTrackColor: Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Associated Terms
                            const Text(
                              "Associated Terms",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _buildTermsChecklist(),
                            ),
                            const SizedBox(height: 12),
                            // Apply/Remove options
                            Card(
                              color: Colors.blue.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      title: const Text(
                                        "Apply to students under selected terms",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      value: _applyToAllStudents,
                                      onChanged: (value) {
                                        setState(() {
                                          _applyToAllStudents = value ?? false;
                                          if (_applyToAllStudents)
                                            _removeFromAllStudents = false;
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: Colors.blue,
                                    ),
                                    CheckboxListTile(
                                      title: const Text(
                                        "Remove from all students",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      value: _removeFromAllStudents,
                                      onChanged: (value) {
                                        setState(() {
                                          _removeFromAllStudents =
                                              value ?? false;
                                          if (_removeFromAllStudents)
                                            _applyToAllStudents = false;
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saveException,
                                    icon: Icon(_isEditing
                                        ? Icons.update
                                        : Icons.add_circle),
                                    label: Text(_isEditing ? 'Update' : 'Add'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      backgroundColor: _isEditing
                                          ? Colors.orange
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isEditing) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _resetForm,
                                      icon: const Icon(Icons.cancel),
                                      label: const Text('Cancel'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // List Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Exception List',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Total: ${_getFilteredExceptions().length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder(
                            valueListenable: _box.listenable(),
                            builder:
                                (context, Box<ExceptionalStudents> box, _) {
                              final exceptions = _getFilteredExceptions();

                              if (exceptions.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text(
                                      "No exceptions available.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Sort exceptions: priority first, then by name
                              exceptions.sort((a, b) {
                                // First sort by priority (1 first)
                                final priorityCompare = (b.priorityFlag ?? 0)
                                    .compareTo(a.priorityFlag ?? 0);
                                if (priorityCompare != 0)
                                  return priorityCompare;
                                // Then by name
                                return (a.exceptionName ?? '')
                                    .compareTo(b.exceptionName ?? '');
                              });

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        children: [
                                          _TableHeaderCell('Status'),
                                          _TableHeaderCell('Priority'),
                                          _TableHeaderCell('Name'),
                                          _TableHeaderCell('Type'),
                                          _TableHeaderCell('Value'),
                                          _TableHeaderCell('Status'),
                                          _TableHeaderCell('Terms'),
                                          _TableHeaderCell('Actions'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Data rows
                                    ...exceptions.map((exception) {
                                      final isDeleted =
                                          exception.isDeleted ?? false;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 4),
                                        decoration: BoxDecoration(
                                          color: isDeleted
                                              ? Colors.grey.shade100
                                              : (exception.priorityFlag ?? 0) ==
                                                      1
                                                  ? Colors.red.shade50
                                                  : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isDeleted
                                                ? Colors.grey.shade400
                                                : (exception.priorityFlag ??
                                                            0) ==
                                                        1
                                                    ? Colors.red.shade200
                                                    : Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // ✅ Status indicator
                                            _TableCell(
                                              isDeleted
                                                  ? '🗑️'
                                                  : (exception.exceptionStatus
                                                              ?.toUpperCase() ==
                                                          'ACTIVE'
                                                      ? '✅'
                                                      : '⏸️'),
                                            ),
                                            _TableCell(
                                              exception.priorityFlag == 1
                                                  ? '🔴'
                                                  : '⚪',
                                            ),
                                            _TableCell(
                                              exception.exceptionName ?? '',
                                              textColor: isDeleted
                                                  ? Colors.grey
                                                  : null,
                                              decoration: isDeleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                            _TableCell(
                                                exception.exceptionType ?? ''),
                                            _TableCell(
                                              '${exception.exceptionFigure ?? ''}${exception.exceptionType == 'PERCENTAGE' ? '%' : ''}',
                                              textColor: isDeleted
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                            _TableCell(
                                              exception.exceptionStatus ?? '',
                                              textColor: isDeleted
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                            _TableCell(
                                              (exception.terms ?? [])
                                                  .map((term) => Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(right: 4),
                                                        child: Chip(
                                                          label: Text(term),
                                                          backgroundColor:
                                                              isDeleted
                                                                  ? Colors.grey
                                                                      .shade300
                                                                  : Colors.blue
                                                                      .shade100,
                                                          side: BorderSide.none,
                                                          materialTapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                        ),
                                                      ))
                                                  .toList(),
                                              isWrap: true,
                                            ),
                                            _TableCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // ✅ Restore button for deleted
                                                  if (isDeleted)
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.restore,
                                                          color: Colors.green,
                                                          size: 20),
                                                      onPressed: () =>
                                                          _restoreException(
                                                              exception),
                                                      tooltip: 'Restore',
                                                    ),
                                                  // ✅ Edit button (only for active)
                                                  if (!isDeleted)
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.edit,
                                                          color: Colors.blue,
                                                          size: 20),
                                                      onPressed: () =>
                                                          _startEdit(exception),
                                                      tooltip: 'Edit',
                                                    ),
                                                  // ✅ Delete button
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: isDeleted
                                                          ? Colors.grey
                                                          : Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: isDeleted
                                                        ? null
                                                        : () =>
                                                            _deleteException(
                                                                exception),
                                                    tooltip: isDeleted
                                                        ? 'Already deleted'
                                                        : 'Soft Delete',
                                                  ),
                                                ],
                                              ),
                                              isWidget: true,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ✅ Helper to get filtered exceptions based on showDeleted toggle
  List<ExceptionalStudents> _getFilteredExceptions() {
    final allExceptions = _box.values.toList();

    if (_showDeleted) {
      return allExceptions;
    } else {
      // ✅ Only show active (non-deleted) exceptions
      return allExceptions.where((e) => !(e.isDeleted ?? false)).toList();
    }
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _TableHeaderCell extends StatelessWidget {
  final String label;
  const _TableHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final dynamic content;
  final bool isWidget;
  final bool isWrap;
  final Color? textColor;
  final TextDecoration? decoration;

  const _TableCell(
    this.content, {
    this.isWidget = false,
    this.isWrap = false,
    this.textColor,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: isWidget
          ? content
          : isWrap
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: content,
                  ),
                )
              : Text(
                  content.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    decoration: decoration,
                  ),
                ),
    );
  }
}
