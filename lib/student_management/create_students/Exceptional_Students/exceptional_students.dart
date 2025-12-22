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
  Set<String> _selectedTerms = {};

  final List<String> _typeOptions = ['PERCENTAGE', 'AMOUNT', 'OTHER'];
  final List<String> _statusOptions = ['ACTIVE', 'PAUSED', 'STOPPED'];

  bool _isEditing = false;
  bool _applyToAllStudents = false;
  bool _removeFromAllStudents = false;

  String? _globalTermId;
  bool _isComputing = false;

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
      _selectedTerms = Set<String>.from(exception.terms ?? []);
    });
  }

  Future<void> _saveException() async {
    if (_formKey.currentState!.validate()) {
      final isNew = !_isEditing;
      final now = DateTime.now();
      final updated = ExceptionalStudents(
        exceptionId:
            _currentException?.exceptionId ?? const Uuid().v4(), // UUID
        exceptionName: _exceptionNameController.text,
        exceptionStatus: _selectedStatus,
        exceptionType: _selectedType,
        exceptionFigure: _exceptionFigureController.text,
        syncStatus: false,
        lastModified: now,
        operationType: isNew ? 'create' : 'update',
        modifiedFields: [
          'exceptionName',
          'exceptionType',
          'exceptionFigure',
          'exceptionStatus',
          'terms'
        ],
        terms: _selectedTerms.toList(),
      );

      if (isNew) {
        _box.add(updated);
      } else {
        if (_currentException != null) {
          final now = DateTime.now();

          final key =
              _box.keyAt(_box.values.toList().indexOf(_currentException!));
          final updatedException = _currentException!
            ..exceptionName = updated.exceptionName
            ..exceptionType = updated.exceptionType
            ..exceptionFigure = updated.exceptionFigure
            ..exceptionStatus = updated.exceptionStatus
            ..terms = updated.terms
            ..lastModified = now
            ..operationType = 'update'
            ..syncStatus = false;

          _box.put(key, updatedException); // ✅ Safe update
          final studentBox = Hive.box<Student>('students');
          final paymentPurposeBox =
              Hive.box<PaymentPurpose>('payment_purposes');

          // Ensure the updated object has the latest fields including terms
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
// ======= IMPROVED APPLY/REMOVE BLOCK START =======
      if (_applyToAllStudents &&
          updated.terms != null &&
          updated.terms!.isNotEmpty) {
        setState(() => _isComputing = true);

        final studentBox = Hive.box<Student>('students');
        final globalTermIds = updated.terms!; // selected terms
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

          //
          // 1) Student now qualifies → ensure exception assigned
          //
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

          //
          // 2) Student no longer qualifies → remove exception
          //
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

          //
          // 3) Student still qualifies → update stored exception instance
          //
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
// ======= IMPROVED APPLY/REMOVE BLOCK END =======
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
        return; // stop further processing
      }

      _resetForm();
    }
  }

  void _deleteException(ExceptionalStudents exception) {
    final studentBox = Hive.box<Student>('students');
    final paymentPurposeBox = Hive.box<PaymentPurpose>('payment_purposes');

    final now = DateTime.now();

// Remove from students
    for (var student in studentBox.values) {
      if (student.exceptions != null &&
          student.exceptions!
              .any((e) => e.exceptionId == exception.exceptionId)) {
        student.exceptions!
            .removeWhere((e) => e.exceptionId == exception.exceptionId);

        final key =
            studentBox.keyAt(studentBox.values.toList().indexOf(student));
        student
          ..syncStatus = false
          ..operationType = 'update'
          ..lastModified = now;
        studentBox.put(key, student);
      }
    }

// Remove from payment purposes
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

// Finally, delete the exception
    exception.delete();
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _currentException = null;
      _exceptionNameController.clear();
      _exceptionFigureController.clear();
      _selectedType = 'PERCENTAGE';
      _selectedStatus = 'ACTIVE';
      _selectedTerms.clear();
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
      appBar: AppBar(title: Center(child: const Text('Exceptional Students'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isWideScreen
                ? Row(
                    children: [
                      // Left panel: Form
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _exceptionNameController,
                                  decoration: const InputDecoration(
                                      labelText: 'Exception Name'),
                                  validator: (value) =>
                                      value!.isEmpty ? 'Enter a name' : null,
                                ),
                                DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  items: _typeOptions
                                      .map((type) => DropdownMenuItem(
                                          value: type, child: Text(type)))
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _selectedType = value!),
                                  decoration: const InputDecoration(
                                      labelText: 'Exception Type'),
                                ),
                                if (_selectedType == "PERCENTAGE")
                                  TextFormField(
                                    controller: _exceptionFigureController,
                                    decoration: InputDecoration(
                                      labelText: '$_selectedType Value',
                                    ),
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
                                    decoration: InputDecoration(
                                      labelText: '$_selectedType Value',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Enter an  amount';
                                      }
                                      final parsed = double.tryParse(value);
                                      if (parsed == null) {
                                        return 'Enter a valid number';
                                      }
                                      if (parsed < 0) {
                                        return 'Amount value must be atleast 0 ';
                                      }
                                      return null;
                                    },
                                  ),
                                DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  items: _statusOptions
                                      .map((status) => DropdownMenuItem(
                                          value: status, child: Text(status)))
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _selectedStatus = value!),
                                  decoration: const InputDecoration(
                                      labelText: 'Exception Status'),
                                ),
                                const SizedBox(height: 10),
                                const Text("Associated Terms",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                _buildTermsChecklist(),
                                const SizedBox(height: 10),
                                Column(
                                  children: [
                                    CheckboxListTile(
                                      title: const Text(
                                          "Apply to students under selected terms"),
                                      value: _applyToAllStudents,
                                      onChanged: (value) {
                                        setState(() {
                                          _applyToAllStudents = value ?? false;
                                          if (_applyToAllStudents)
                                            _removeFromAllStudents = false;
                                        });
                                      },
                                    ),
                                    CheckboxListTile(
                                      title: const Text(
                                          "Remove from all students"),
                                      value: _removeFromAllStudents,
                                      onChanged: (value) {
                                        setState(() {
                                          _removeFromAllStudents =
                                              value ?? false;
                                          if (_removeFromAllStudents)
                                            _applyToAllStudents = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: _saveException,
                                  child: Text(_isEditing ? 'Update' : 'Add'),
                                ),
                                if (_isEditing)
                                  TextButton(
                                    onPressed: _resetForm,
                                    child: const Text('Cancel'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const VerticalDivider(width: 1),

                      // Right panel: List
                      Expanded(
                        flex: 2,
                        child: ValueListenableBuilder(
                          valueListenable: _box.listenable(),
                          builder: (context, Box<ExceptionalStudents> box, _) {
                            if (box.isEmpty) {
                              return const Center(
                                  child: Text("No exceptions added."));
                            }
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(12.0),
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  const Row(
                                    children: [
                                      _TableHeaderCell('Exception Name'),
                                      _TableHeaderCell('Type'),
                                      _TableHeaderCell('Value'),
                                      _TableHeaderCell('Status'),
                                      _TableHeaderCell('Terms'),
                                      _TableHeaderCell('Actions'),
                                    ],
                                  ),
                                  const Divider(),

                                  // Data rows
                                  ...box.values
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final exception = entry.value;

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _TableCell(
                                            exception.exceptionName ?? ''),
                                        _TableCell(
                                            exception.exceptionType ?? ''),
                                        _TableCell(
                                            exception.exceptionFigure ?? ''),
                                        _TableCell(
                                            exception.exceptionStatus ?? ''),
                                        _TableCell(
                                          (exception.terms ?? [])
                                              .map((term) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 4),
                                                    child:
                                                        Chip(label: Text(term)),
                                                  ))
                                              .toList(),
                                          isWrap: true,
                                        ),
                                        _TableCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _startEdit(exception),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () =>
                                                    _deleteException(exception),
                                              ),
                                            ],
                                          ),
                                          isWidget: true,
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _exceptionNameController,
                                decoration: const InputDecoration(
                                    labelText: 'Exception Name'),
                                validator: (value) =>
                                    value!.isEmpty ? 'Enter a name' : null,
                              ),
                              DropdownButtonFormField<String>(
                                value: _selectedType,
                                items: _typeOptions
                                    .map((type) => DropdownMenuItem(
                                        value: type, child: Text(type)))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedType = value!),
                                decoration: const InputDecoration(
                                    labelText: 'Exception Type'),
                              ),
                              if (_selectedType == "PERCENTAGE")
                                TextFormField(
                                  controller: _exceptionFigureController,
                                  decoration: InputDecoration(
                                      labelText: '$_selectedType Value'),
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
                                  decoration: InputDecoration(
                                      labelText: '$_selectedType Value'),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter amount value';
                                    }
                                    final parsed = double.tryParse(value);
                                    if (parsed == null) {
                                      return 'Enter a valid number';
                                    }
                                    if (parsed < 0) {
                                      return 'Amount must be atleast 0';
                                    }
                                    return null;
                                  },
                                ),
                              DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                items: _statusOptions
                                    .map((status) => DropdownMenuItem(
                                        value: status, child: Text(status)))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedStatus = value!),
                                decoration: const InputDecoration(
                                    labelText: 'Exception Status'),
                              ),
                              const SizedBox(height: 10),
                              const Text("Associated Terms",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              _buildTermsChecklist(),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _saveException,
                                child: Text(_isEditing ? 'Update' : 'Add'),
                              ),
                              if (_isEditing)
                                TextButton(
                                  onPressed: _resetForm,
                                  child: const Text('Cancel'),
                                ),
                            ],
                          ),
                        ),
                        const Divider(),
                        ValueListenableBuilder(
                          valueListenable: _box.listenable(),
                          builder: (context, Box<ExceptionalStudents> box, _) {
                            if (box.isEmpty) {
                              return const Center(
                                  child: Text("No exceptions added."));
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      _TableHeaderCell('Exception Name'),
                                      _TableHeaderCell('Type'),
                                      _TableHeaderCell('Value'),
                                      _TableHeaderCell('Status'),
                                      _TableHeaderCell('Terms'),
                                      _TableHeaderCell('Actions'),
                                    ],
                                  ),
                                  const Divider(),
                                  ...box.values
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final exception = entry.value;
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _TableCell(
                                            exception.exceptionName ?? ''),
                                        _TableCell(
                                            exception.exceptionType ?? ''),
                                        _TableCell(
                                            exception.exceptionFigure ?? ''),
                                        _TableCell(
                                            exception.exceptionStatus ?? ''),
                                        _TableCell(
                                          (exception.terms ?? [])
                                              .map((term) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 4),
                                                    child:
                                                        Chip(label: Text(term)),
                                                  ))
                                              .toList(),
                                          isWrap: true,
                                        ),
                                        _TableCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _startEdit(exception),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () =>
                                                    _deleteException(exception),
                                              ),
                                            ],
                                          ),
                                          isWidget: true,
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )
          ],
        ),
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String label;
  const _TableHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final dynamic content;
  final bool isWidget;
  final bool isWrap;

  const _TableCell(this.content, {this.isWidget = false, this.isWrap = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: isWidget
          ? content
          : isWrap
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: content,
                  ),
                )
              : Text(content.toString()),
    );
  }
}
