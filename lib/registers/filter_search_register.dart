import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart'; // To handle file name extensions

class ViewAttendanceScreenFilter extends StatefulWidget {
  @override
  _ViewAttendanceScreenFilterState createState() =>
      _ViewAttendanceScreenFilterState();
}

class _ViewAttendanceScreenFilterState
    extends State<ViewAttendanceScreenFilter> {
  final Box<Student> _studentBox = Hive.box<Student>('students');
  late List<Student> _students;
  late ValueNotifier<List<Student>> _filteredStudentsNotifier;
  late Map<String, List<Student>> _studentsByClass;
  late List<String> _classes;
  String? _selectedClass = "All"; // Initialize _selectedClass to "All"
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _selectedStudentName;
  bool _isSortAscending = true;
  List<Student> filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _filteredStudentsNotifier = ValueNotifier<List<Student>>([]);
  }

  void _loadStudents() {
    setState(() {
      // Load only students from the current term
      _students = _studentBox.values
          .where((student) => student.termId == globalTermId)
          .toList();

      _studentsByClass = {};
      for (var student in _students) {
        if (_studentsByClass.containsKey(student.class_)) {
          _studentsByClass[student.class_]!.add(student);
        } else {
          _studentsByClass[student.class_] = [student];
        }
      }
      _classes = _studentsByClass.keys.toList();
      _classes.insert(0, "All"); // Add "All" to the classes list
    });
  }

  void _applyFilters() {
    final paymentBox = Hive.box<Student>('students');
    filteredStudents = paymentBox.values
        .where((payment) => payment.termId == globalTermId)
        .toList();
    filteredStudents = _selectedClass == "All"
        ? _students
        : _studentsByClass[_selectedClass] ?? [];

    if (_selectedStartDate != null && _selectedEndDate != null) {
      DateTime startDate = _selectedStartDate!;
      DateTime endDate =
          _selectedEndDate!.add(Duration(days: 1)); // Include the entire day

      filteredStudents = filteredStudents.where((student) {
        List<DateTime> dates = student.presentDates + student.absentDates;
        for (DateTime date in dates) {
          if (date.isAfter(startDate) && date.isBefore(endDate)) {
            return true;
          }
        }
        return false;
      }).toList();
    }
    filteredStudents.sort((a, b) => _isSortAscending
        ? a.surname.compareTo(b.surname)
        : b.surname.compareTo(a.surname));

    if (_selectedStudentName != null && _selectedStudentName!.isNotEmpty) {
      filteredStudents = filteredStudents
          .where((student) =>
              '${student.name} ${student.surname}'
                  .toLowerCase()
                  .contains(_selectedStudentName!.toLowerCase()) &&
              student.termId == globalTermId)
          .toList();
    }

    _filteredStudentsNotifier.value = filteredStudents;
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _applyFilters(); // Reapply the filter to reflect the sorting order change
    });
  }

  void _deleteAllAttendanceForClass(String className) {
    List<Student> students = _studentsByClass[className] ?? [];
    for (var student in students) {
      student.presentDates.clear();
      student.absentDates.clear();
      student.save();
    }
    _loadStudents();
    _applyFilters();
  }

  void _updateStudentAttendance(Student student) {
    // Implement logic to update a student's attendance records, e.g., mark a new day
    // for attendance or update status if necessary.
  }

  void _deleteStudentAttendanceHistory(Student student) {
    student.presentDates.clear();
    student.absentDates.clear();
    student.save();
    _loadStudents();
    _applyFilters();
  }

  Future<Uint8List> generateStudentsPDF(List<Student> student_payments) async {
    final pdf = pw.Document();

    final headers = [
      'Student Name',
      'Student Surname',
      'Student Class',
      'Total Marked Days',
      'Present Days',
      'Absent Days',
      'Attendance %',
      'School Term'
    ];
    final data = filteredStudents.map((student) {
      int totalDays = student.presentDates.length + student.absentDates.length;
      int presentDays = student.presentDates.length;
      int absentDays = student.absentDates.length;
      double attendancePercentage =
          totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

      return [
        student.name ?? '',
        student.surname ?? '',
        student.class_ ?? '',
        '$totalDays',
        '$presentDays',
        '$absentDays',
        '${attendancePercentage.toStringAsFixed(2)}%',
        student.termId,
      ];
    }).toList();

    // Create a PDF page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32), // Add margins for layout
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title of the page
                pw.Text('Attendence Information',
                    style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
            // The table should now automatically split across multiple pages
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              cellStyle: pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
              columnWidths: {
                0: pw.FlexColumnWidth(), // Class Name column
                1: pw.FlexColumnWidth(), // Created On column
                2: pw.FlexColumnWidth(), // Current Term column
                3: pw.FlexColumnWidth(), // Current Term column
                4: pw.FlexColumnWidth(), // Class Name column
                5: pw.FlexColumnWidth(), // Created On column
                6: pw.FlexColumnWidth(), // Current Term column
                7: pw.FlexColumnWidth(), // Current Term column
              },
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<void> savePDFToFile(
      BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        // Get external storage directory
        Directory? directory = await getExternalStorageDirectory();

        if (directory != null) {
          // Define the path to the Download folder
          final downloadDir = Directory('/storage/emulated/0/Download');

          // Create the directory if it doesn't exist
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Download directory created.")));
          }

          // Define the initial file path
          String filePath = path.join(downloadDir.path, '$fileName.pdf');
          int fileIndex = 1;

          // Check if a file with the same name exists and add an index if necessary
          while (await File(filePath).exists()) {
            filePath = path.join(downloadDir.path, '$fileName-$fileIndex.pdf');
            fileIndex++;
          }

          // Save the PDF file
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          // Show success notification
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("PDF saved to $filePath")));
        } else {
          // Show error notification
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error: External storage directory not found.")));
        }
      } else {
        // Show permission denied notification
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Permission denied for storage access.")));
      }
    } catch (e) {
      // Show error notification
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving PDF: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'View Attendance',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            onPressed: () {
              _showFilterOptions(context);
            },
            icon: Icon(Icons.filter_list, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              Uint8List pdfBytes = await generateStudentsPDF(filteredStudents);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(
                    context, pdfBytes, 'student_registers_report');
              }
            },
          ),
          IconButton(
            onPressed: () {
              if (_selectedClass != null && _selectedClass != "All") {
                _deleteAllAttendanceForClass(_selectedClass!);
              }
            },
            icon: Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete All Attendance for Class',
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<List<Student>>(
          valueListenable: _filteredStudentsNotifier,
          builder: (context, filteredStudents, child) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Center(
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
                    rows: filteredStudents.map((student) {
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
                              onTap: () => _showDetailedAttendance(
                                  context, student, true),
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
                                  icon: Icon(Icons.delete),
                                  onPressed: () =>
                                      _deleteStudentAttendanceHistory(student),
                                  tooltip: 'Delete Attendance History',
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
            );
          },
        ),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedClass,
                    hint: Text('Select Class'),
                    onChanged: (value) {
                      setState(() {
                        _selectedClass = value;
                      });
                      _applyFilters();
                    },
                    items: _classes.map((class_) {
                      return DropdownMenuItem(
                        value: class_,
                        child: Text(class_),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedStartDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedStartDate != null) {
                              setState(() {
                                _selectedStartDate = pickedStartDate;
                              });
                              _applyFilters();
                            }
                          },
                          child: Text(_selectedStartDate != null
                              ? DateFormat('yyyy-MM-dd')
                                  .format(_selectedStartDate!)
                              : 'Start Date'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedEndDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedEndDate != null) {
                              setState(() {
                                _selectedEndDate = pickedEndDate;
                              });
                              _applyFilters();
                            }
                          },
                          child: Text(_selectedEndDate != null
                              ? DateFormat('yyyy-MM-dd')
                                  .format(_selectedEndDate!)
                              : 'End Date'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _selectedStudentName = value;
                      });
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      labelText: 'Search by Student Name',
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      child: Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Sort by Surname: ',
                          style: TextStyle(fontSize: 16)),
                      IconButton(
                        icon: Icon(_isSortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        onPressed: _toggleSortOrder,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDateRangeFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedStartDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedStartDate != null) {
                              setState(() {
                                _selectedStartDate = pickedStartDate;
                              });
                              _applyFilters();
                            }
                          },
                          child: Text(_selectedStartDate != null
                              ? DateFormat('yyyy-MM-dd')
                                  .format(_selectedStartDate!)
                              : 'Start Date'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedEndDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedEndDate != null) {
                              setState(() {
                                _selectedEndDate = pickedEndDate;
                              });
                              _applyFilters();
                            }
                          },
                          child: Text(_selectedEndDate != null
                              ? DateFormat('yyyy-MM-dd')
                                  .format(_selectedEndDate!)
                              : 'End Date'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilters();
                    },
                    child: Text('Apply Date Range Filter'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailedAttendance(
      BuildContext context, Student student, bool isPresent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<DateTime> dates =
            isPresent ? student.presentDates : student.absentDates;
        return AlertDialog(
          title: Text(isPresent ? 'Present Dates' : 'Absent Dates'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: dates.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(DateFormat('yyyy-MM-dd').format(dates[index])),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
