import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class MarkAttendanceScreen extends StatefulWidget {
  @override
  _MarkAttendanceScreenState createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedClass;
  DateTime _selectedDate = DateTime.now();
  List<Student> _students = [];
  final Box<Student> _studentBox = Hive.box<Student>('students');
  final List<String> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  void _loadClasses() {
    final classes = _studentBox.values
        .where((student) =>
            student.terms!.contains(globalTermId)) // Filter by termId
        .map((student) => student.class_)
        .toSet()
        .toList();

    setState(() {
      _classes.addAll(classes);
    });
  }

  void _loadStudents(String class_) {
    final students = _studentBox.values
        .where((student) =>
            student.class_ == class_ &&
            student.terms!.contains(globalTermId)) // Filter by class and termId
        .toList();

    setState(() {
      _students = students;
    });
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

  void _markAttendance() async {
    DateTime selectedDateWithoutTime =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    bool isAlreadyMarked = await _isAttendanceAlreadyMarked(
        _selectedClass!, selectedDateWithoutTime);
    if (isAlreadyMarked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Attendance already marked for this class on this date')),
      );
      return;
    }

    for (var student in _students) {
      if (student.isPresent) {
        List<String> modifiedFields = [];
        modifiedFields.add('isPresent');
        modifiedFields.add('absentDates');
        modifiedFields.add('presentDates');

        if (!student.presentDates.contains(selectedDateWithoutTime)) {
          student.presentDates.add(selectedDateWithoutTime);
        }
        student.absentDates.remove(selectedDateWithoutTime);
        student.syncStatus = false;
        student.operationType = 'update';
        student.lastModified = DateTime.now();
        student.modifiedFields = modifiedFields;
      } else {
        List<String> modifiedFields = [];
        modifiedFields.add('isPresent');
        modifiedFields.add('absentDates');
        modifiedFields.add('presentDates');
        if (!student.absentDates.contains(selectedDateWithoutTime)) {
          student.absentDates.add(selectedDateWithoutTime);
        }
        student.presentDates.remove(selectedDateWithoutTime);
        student.syncStatus = false;
        student.operationType = 'update';
        student.lastModified = DateTime.now();
        student.modifiedFields = modifiedFields;
      }
      student.save();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance marked successfully')),
    );
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
                              _loadStudents(value);
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
                                    Checkbox(
                                      value: student.isPresent,
                                      onChanged: (value) {
                                        setState(() {
                                          student.isPresent = value!;
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
                          onPressed: _markAttendance,
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
}
