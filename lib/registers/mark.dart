import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/server/routes/class_factory.dart';
import 'package:zitf_system/server/routes/terms_factory.dart';
import 'package:zitf_system/student_management/bulk_register_marking_api.dart';
import 'package:zitf_system/student_management/fetch_student_register_api.dart';
import 'package:zitf_system/student_management/mark_student_register_fetch_student_api.dart';
import 'package:zitf_system/student_management/update_student_from_client.dart';

class MarkAttendanceScreen extends StatefulWidget {
  @override
  _MarkAttendanceScreenState createState() => _MarkAttendanceScreenState();
}

enum DeviceRole { host, client }

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  List<Student> _students = [];
  List<String> _classes = [];
  List<Terms> _availableTerms = [];
  List<String> _selectedTerms = [];
  bool _isSubmitting = false;

  Future<DeviceRole> _loadDeviceRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('device_role');

    if (roleStr == 'host') return DeviceRole.host;
    return DeviceRole.client; // default safe
  }

  DeviceRole? _role;
  bool _roleReady = false;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    final role = await _loadDeviceRole();

    setState(() {
      _role = role;
      _roleReady = true;
    });

    // 🔐 SAFE: role is now known
    await _loadTerms();
    await _loadClasses();
  }

  Future<void> _loadTerms() async {
    if (!_roleReady) return;

    final now = DateTime.now();

    if (_role == DeviceRole.host) {
      final termsBox = await Hive.openBox<Terms>('terms');
      final terms = termsBox.values.toList();
      final sorted = sortTermsByStatusAndStartDate(terms);

      setState(() {
        _availableTerms = sorted;

        // ✅ SELECT ONLY NON-EXPIRED TERMS
        _selectedTerms = sorted
            .where((t) => t.endDate != null && t.endDate!.isAfter(now))
            .map((t) => t.termId!)
            .toList();
      });
    } else {
      try {
        final terms = await TermApiService.fetchTerms();
        final sorted = sortTermsByStatusAndStartDate(terms);

        setState(() {
          _availableTerms = sorted;

          // ✅ SELECT ONLY NON-EXPIRED TERMS
          _selectedTerms = sorted
              .where((t) => t.endDate != null && t.endDate!.isAfter(now))
              .map((t) => t.termId!)
              .toList();
        });
      } catch (e) {
        setState(() {
          _availableTerms = [];
          _selectedTerms = [];
        });

        _showDialog(
          'Unable to load terms from host.\n'
          'You cannot add students while offline.',
        );
      }
    }
  }

  List<Terms> sortTermsByStatusAndStartDate(List<Terms> terms) {
    final now = DateTime.now();

    terms.sort((a, b) {
      final aExpired = a.endDate != null && a.endDate!.isBefore(now);
      final bExpired = b.endDate != null && b.endDate!.isBefore(now);

      // ✅ Active terms first
      if (aExpired != bExpired) {
        return aExpired ? 1 : -1;
      }

      // ✅ Same group → sort by startDate
      final aStart = a.startDate ?? DateTime(1900);
      final bStart = b.startDate ?? DateTime(1900);

      return bStart.compareTo(aStart); // newest first
    });

    return terms;
  }

  Terms? getActiveTerm() {
    final now = DateTime.now();
    return _availableTerms.firstWhere(
      (term) =>
          term.startDate != null &&
          term.endDate != null &&
          !now.isBefore(term.startDate!) &&
          !now.isAfter(term.endDate!),
      orElse: () => _availableTerms.first,
    );
  }

  Future<void> _loadClasses() async {
    if (!_roleReady) return;

    final currentTerm = getActiveTerm();
    if (currentTerm == null) {
      setState(() => _classes = []);
      return;
    }

    final termId = currentTerm.termId!;

    if (_role == DeviceRole.host) {
      // HOST → Hive
      final box = await Hive.openBox<Classes>('classes');
      setState(() {
        _classes = box.values
            .where((c) => c.terms!.contains(termId))
            .map((c) => c.className)
            .toList();
      });
    } else {
      // CLIENT → API ONLY
      try {
        final classes = await ClassApiService.fetchClasses(termId);
        setState(() => _classes = classes);
      } catch (e) {
        setState(() => _classes = []);
        _showDialog(
          'Unable to load classes from host.\n'
          'You cannot add students while offline.',
        );
      }
    }
  }

  Future<void> _loadStudentsForClass(String className) async {
    if (!_roleReady) return;

    final currentTerm = getActiveTerm();
    if (currentTerm == null) {
      setState(() => _students = []);
      return;
    }

    final termId = currentTerm.termId!;
    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<Student>('students');

      setState(() {
        _students = box.values
            .where((s) =>
                s.class_ == className &&
                s.terms != null &&
                s.terms!.contains(termId))
            .toList();
      });
    } else {
      try {
        final students = await StudentRegisterFetchApi.fetchByClass(
          className: className,
          termId: termId,
        );

        setState(() {
          _students = students;
        });
      } catch (e) {
        setState(() => _students = []);
        _showDialog(
          'Unable to load students from host.\n'
          'Check connection.',
        );
      }
    }
  }

  Future<void> _markAttendance() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    try {
      if (_selectedClass == null) return;

      final date = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final currentTerm = getActiveTerm();
      if (currentTerm == null) {
        setState(() => _classes = []);
        return;
      }

      final termId = currentTerm.termId!;
      // 🔒 CHECK ONLY ON HOST
      if (_role == DeviceRole.host) {
        final alreadyMarked =
            await _isAttendanceAlreadyMarked(_selectedClass!, date);

        if (alreadyMarked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Attendance already marked for this class on this date'),
            ),
          );
          return;
        }
      }

      for (final student in _students) {
        final isPresent = student.isPresent;

        if (_role == DeviceRole.host) {
          for (final student in _students) {
            await _applyAttendanceLocally(student, date, student.isPresent);
          }
        } else {
          await StudentRegisterBulkApiService.markBulkRegister(
            className: _selectedClass!,
            termId: termId,
            date: date,
            students: _students,
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance marked successfully')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _applyAttendanceLocally(
    Student student,
    DateTime date,
    bool isPresent,
  ) async {
    if (isPresent) {
      student.presentDates.add(date);
      student.absentDates.remove(date);
    } else {
      student.absentDates.add(date);
      student.presentDates.remove(date);
    }
    await student.save();
  }

  Future<bool> _isAttendanceAlreadyMarked(String class_, DateTime date) async {
    bool isMarked = false;
    for (var student in _students) {
      if (student.class_ == class_ &&
          (student.presentDates.contains(date) ||
              student.absentDates.contains(date))) {
        isMarked = true;
        break;
      }
    }
    return isMarked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Mark Attendence'),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_classes.isEmpty)
                    const Center(
                        child: Text('No classes available for this term'))
                  else
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedClass,
                          items: _classes.map((className) {
                            return DropdownMenuItem<String>(
                              value: className,
                              child: Text(className),
                            );
                          }).toList(),
                          decoration:
                              const InputDecoration(labelText: 'Select Class'),
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                            if (value != null) {
                              _loadStudentsForClass(value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: TextEditingController(
                            text: DateFormat('EEEE, d MMMM yyyy')
                                .format(_selectedDate),
                          ),
                          decoration: const InputDecoration(labelText: 'Date'),
                          readOnly: true,
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_students.isEmpty)
                          const Center(
                              child: const Text(
                                  'No students found for this class'))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return ListTile(
                                title:
                                    Text("${student.name} ${student.surname}"),
                                subtitle: Text(student.class_),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CheckboxListTile(
                                      title: Text(
                                          "${student.name} ${student.surname}"),
                                      subtitle: Text(student.class_),
                                      value: student.isPresent,
                                      onChanged: (value) {
                                        setState(() {
                                          student.isPresent = value ?? false;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          student.isPresent = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _students.isEmpty ? null : _markAttendance,
                          child: const Text('Mark Attendance'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Student Submission Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
