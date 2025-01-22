import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class ViewAttendanceScreen extends StatefulWidget {
  @override
  _ViewAttendanceScreenState createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<ViewAttendanceScreen> {
  final Box<Student> _studentBox = Hive.box<Student>('students');
  late List<Student> _students;
  String? _selectedClass;
  List<String> _classes = [];
  String? _selectedDate;
  List<String> _dates = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadStudents();
  }

  void _loadClasses() {
    // Load classes where termId matches globalTermId
    _classes = _studentBox.values
        .where((student) => student.termId == globalTermId)
        .map((student) => student.class_)
        .toSet()
        .toList();
    _selectedClass = _classes.isNotEmpty ? _classes.first : null;

    // Load available dates where termId matches globalTermId
    _dates = _studentBox.values
        .where((student) => student.termId == globalTermId)
        .expand((student) => student.presentDates
            .map((date) => DateFormat('yyyy-MM-dd').format(date)))
        .toSet()
        .toList();
    _selectedDate = _dates.isNotEmpty ? _dates.first : null;
  }

  void _loadStudents() {
    setState(() {
      _students = _selectedClass != null
          ? _studentBox.values
              .where(
                  (s) => s.class_ == _selectedClass && s.termId == globalTermId)
              .toList()
          : _studentBox.values.where((s) => s.termId == globalTermId).toList();

      if (_selectedDate != null) {
        DateTime selectedDate = DateFormat('yyyy-MM-dd').parse(_selectedDate!);
        _students = _students
            .where((student) =>
                student.presentDates.contains(selectedDate) ||
                student.absentDates.contains(selectedDate))
            .toList();
      }
    });
  }

  void _deleteClassAttendance() {
    if (_selectedClass != null) {
      List<Student> studentsInClass = _studentBox.values
          .where((student) =>
              student.class_ == _selectedClass &&
              student.termId == globalTermId)
          .toList();

      for (Student student in studentsInClass) {
        student.presentDates.clear();
        student.absentDates.clear();
        student.save();
      }

      _loadStudents();
    }
  }

  void _updateStudentAttendance(Student student, DateTime date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text('Update Attendance for ${student.name} ${student.surname}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Mark attendance on ${DateFormat('yyyy-MM-dd').format(date)}'),
              Row(
                children: [
                  Text('Present'),
                  Checkbox(
                    value: student.presentDates.contains(date),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          student.presentDates.add(date);
                          student.absentDates.remove(date);
                        } else {
                          student.presentDates.remove(date);
                        }
                      });
                      student.save();
                      Navigator.pop(context);
                    },
                  ),
                  Text('Absent'),
                  Checkbox(
                    value: student.absentDates.contains(date),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          student.absentDates.add(date);
                          student.presentDates.remove(date);
                        } else {
                          student.absentDates.remove(date);
                        }
                      });
                      student.save();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteStudentAttendanceHistory(Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text('Delete Attendance for ${student.name} ${student.surname}'),
          content: Text(
              'Are you sure you want to delete all attendance records for this student?'),
          actions: [
            TextButton(
              onPressed: () {
                student.presentDates.clear();
                student.absentDates.clear();
                student.save();
                _loadStudents();
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
          if (_selectedClass != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteClassAttendance,
              tooltip: 'Delete All Class Attendance',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedClass,
              items: _classes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedClass = value;
                  _loadStudents();
                });
              },
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedDate,
              items: _dates
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDate = value;
                  _loadStudents();
                });
              },
            ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Surname')),
                    DataColumn(label: Text('Class')),
                    DataColumn(label: Text('Total Days')),
                    DataColumn(label: Text('Present Days')),
                    DataColumn(label: Text('Absent Days')),
                    DataColumn(label: Text('Attendance %')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _students.map((student) {
                    int totalDays = student.presentDates.length +
                        student.absentDates.length;
                    int presentDays = student.presentDates.length;
                    int absentDays = student.absentDates.length;
                    double attendancePercentage =
                        totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

                    return DataRow(
                      cells: [
                        DataCell(Text(student.name)),
                        DataCell(Text(student.surname)),
                        DataCell(Text(student.class_)),
                        DataCell(Text('$totalDays')),
                        DataCell(
                          InkWell(
                            onTap: () =>
                                _showDetailedAttendance(context, student, true),
                            child: Text(
                              '$presentDays',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          InkWell(
                            onTap: () => _showDetailedAttendance(
                                context, student, false),
                            child: Text(
                              '$absentDays',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(
                            '${attendancePercentage.toStringAsFixed(2)}%')),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () => _updateStudentAttendance(
                                    student,
                                    DateFormat('yyyy-MM-dd')
                                        .parse(_selectedDate!)),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () =>
                                    _deleteStudentAttendanceHistory(student),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailedAttendance(
      BuildContext context, Student student, bool isPresent) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        List<DateTime> dates =
            isPresent ? student.presentDates : student.absentDates;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    isPresent ? 'Present Days' : 'Absent Days',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: dates.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                              DateFormat('yyyy-MM-dd').format(dates[index])),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                dates.removeAt(index);
                              });
                              student.save();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
