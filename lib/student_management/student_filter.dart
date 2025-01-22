import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // For PDF preview
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart'; // To handle file name extensions
import 'package:excel/excel.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart';

class ViewStudentsScreenfilter extends StatefulWidget {
  const ViewStudentsScreenfilter({Key? key}) : super(key: key);

  @override
  _ViewStudentsScreenStatefilter createState() =>
      _ViewStudentsScreenStatefilter();
}

class _ViewStudentsScreenStatefilter extends State<ViewStudentsScreenfilter> {
  String? _selectedGender;
  String? _selectedSurname;
  String? _selectedReg;

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSortAscending = true;
  List<String> _selectedClasses = [];

  List<Student> _filteredStudents = [];
  List<String> _classes = [];
  List<String> _genders = ['All', 'Male', 'Female'];

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final studentBox = await Hive.openBox<Student>('students');
    final _filteredStudentsBox = studentBox.values
        .where((classItem) => classItem.termId == globalTermId)
        .toList();
    // Fetch unique classes and add "All" option
    _classes = ['All'];
    _classes.addAll(
        _filteredStudentsBox.map((student) => student.class_).toSet().toList());
    _selectedClasses = ['All']; // Default selection

    setState(() {});
  }

  Future<void> _filterStudents() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      final studentBox = Hive.box<Student>('students');
      _filteredStudents = studentBox.values
          .where((classItem) => classItem.termId == globalTermId)
          .toList();

      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
        _filteredStudents = _filteredStudents.where((student) {
          return _selectedClasses.contains(student.class_);
        }).toList();
      }

      if (_selectedGender != null && _selectedGender != "All") {
        _filteredStudents = _filteredStudents
            .where((student) =>
                student.gender == _selectedGender &&
                student.termId == globalTermId)
            .toList();
      }

      if (_selectedSurname != null && _selectedSurname!.isNotEmpty) {
        _filteredStudents = _filteredStudents
            .where((student) =>
                student.surname
                    .toLowerCase()
                    .contains(_selectedSurname!.toLowerCase()) &&
                student.termId == globalTermId)
            .toList();
      }

      if (_selectedReg != null && _selectedReg!.isNotEmpty) {
        _filteredStudents = _filteredStudents
            .where((student) =>
                student.studentIdNumber!
                    .toLowerCase()
                    .trim()
                    .contains(_selectedReg!.toLowerCase().trim()) &&
                student.termId == globalTermId)
            .toList();
      }

      if (_selectedStartDate != null || _selectedEndDate != null) {
        _filteredStudents = _filteredStudents.where((student) {
          final studentDOB = student.age;
          if (_selectedStartDate != null && _selectedEndDate != null) {
            return studentDOB.isAfter(_selectedStartDate!) &&
                studentDOB.isBefore(_selectedEndDate!);
          } else if (_selectedStartDate != null) {
            return studentDOB.isAfter(_selectedStartDate!);
          } else if (_selectedEndDate != null) {
            return studentDOB.isBefore(_selectedEndDate!);
          }
          return true;
        }).toList();
      }

      // Sort students by surname
      _filteredStudents.sort((a, b) => _isSortAscending
          ? a.surname.compareTo(b.surname)
          : b.surname.compareTo(a.surname));
    } catch (error) {
      // Log error if needed
      print("Error filtering students: $error");
    } finally {
      setState(() {
        _isSyncing = false; // Always reset syncing state
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterStudents(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<Uint8List> generateStudentsPDF(List<Student> students) async {
    final pdf = pw.Document();

    final headers = [
      'Name',
      'Surname',
      'Class',
      'Gender',
      'Date of Birth',
      'Address',
      'Parent Number'
    ];
    final data = _filteredStudents.map((student) {
      return [
        student.name,
        student.surname,
        student.class_,
        student.gender,
        DateFormat('yyyy-MM-dd').format(student.age ?? DateTime.now()),
        student.physicalAddress,
        student.paymentStatus,
      ];
    }).toList();

    // Create a PDF page

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32), // Add margins for layout
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title of the page
                pw.Text('Student Information',
                    style: const pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
            // The table should now automatically split across multiple pages
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
              columnWidths: {
                0: const pw.FlexColumnWidth(), // Class Name column
                1: const pw.FlexColumnWidth(), // Created On column
                2: const pw.FlexColumnWidth(), // Current Term column
                3: const pw.FlexColumnWidth(), // Class Name column
                4: const pw.FlexColumnWidth(), // Created On column
                5: const pw.FlexColumnWidth(), // Current Term column
                6: const pw.FlexColumnWidth(), // Created On column
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
                const SnackBar(content: Text("Download directory created.")));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Error: External storage directory not found.")));
        }
      } else {
        // Show permission denied notification
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Permission denied for storage access.")));
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
        title: const Text(
          'View Students Filter',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              final studentBox = await Hive.openBox<Student>('students');
              List<Student> students = studentBox.values
                  .where((student) => student.termId == globalTermId)
                  .toList();
              Uint8List pdfBytes = await generateStudentsPDF(_filteredStudents);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(context, pdfBytes, 'students_report');
              }
            },
          ),
          IconButton(
              icon: const Icon(
                Icons.edit_document,
                color: Colors.white,
              ),
              onPressed: () async {
                generateAndSaveSpreadsheet();
              }),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0, // Optional: Add a subtle shadow
      ),
      body: Center(
        child: Container(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCard(
                        title: 'View by Class',
                        child: _buildClassDropdown(),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Surname',
                        child: _buildSurnameField(),
                      ),
                      _buildCard(
                        title: 'View by Registration Number',
                        child: _buildRegField(),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Gender',
                        child: _buildGenderDropdown(),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Date of Birth',
                        child: _buildDOBPicker(),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: _isSyncing
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed:
                                    _filterStudents, // Disable button when loading
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                  backgroundColor:
                                      const Color.fromARGB(255, 232, 236, 242),
                                  textStyle: const TextStyle(
                                      fontSize: 18), // Button background color
                                ),
                                child: const Text('Apply Filters'),
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
                          const SizedBox(height: 20),
                          // Records Found Header
                        ],
                      ),
                      Text(
                        'Records Found: ${_filteredStudents.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _filteredStudents.isEmpty
                          ? const Center(
                              child: Text(
                                'No students found.',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 16),
                              ),
                            )
                          : _buildStudentsTable(), // Records Found Header
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildClassDropdown() {
    return MultiSelectChip(
      items: _classes,
      initialSelectedItems: _selectedClasses,
      onSelectionChanged: (selectedClasses) {
        setState(() {
          _selectedClasses = selectedClasses;
        });
      },
    );
  }

  Widget _buildSurnameField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Student by Surname',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedSurname = value;
        });
      },
    );
  }

  Widget _buildRegField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Student by Reg Number',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedReg = value;
        });
      },
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      hint: const Text('Select Gender'),
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
      items: _genders.map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDOBPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Date of Birth Period:',
            style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context, true),
                child: Text(_selectedStartDate != null
                    ? 'From: ${_selectedStartDate!.toLocal()}'.split(' ')[0]
                    : 'From: Select Start Date'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context, false),
                child: Text(_selectedEndDate != null
                    ? 'To: ${_selectedEndDate!.toLocal()}'.split(' ')[0]
                    : 'To: Select End Date'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Widget _buildStudentsTable() {
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();

    // Horizontal scroll increment value
    const double scrollIncrement = 100.0; // You can adjust the value as needed

    // Function to scroll horizontally by increment
    void _scrollLeft() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset - scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Function to scroll horizontally by decrement
    void _scrollRight() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset + scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    return Stack(
      children: [
        // Main table with vertical and horizontal scrolling
        Scrollbar(
          thumbVisibility: true,
          controller: horizontalScrollController,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              thumbVisibility: true,
              controller: verticalScrollController,
              child: SingleChildScrollView(
                controller: verticalScrollController,
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Student Registration Number')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Surname')),
                    DataColumn(label: Text('Class')),
                    DataColumn(label: Text('Gender')),
                    DataColumn(label: Text('Date of Birth')),
                    DataColumn(label: Text('Nationality')),
                    DataColumn(label: Text('District')),
                    DataColumn(label: Text('National ID Number')),
                    DataColumn(label: Text('Student Registration Position')),
                    DataColumn(label: Text('Physical Address')),
                    DataColumn(label: Text('Parent Name')),
                    DataColumn(label: Text('Parent Phone Number')),
                    DataColumn(label: Text('Religion')),
                    DataColumn(label: Text('Denomination')),
                    DataColumn(label: Text('Former School')),
                    DataColumn(label: Text('Former School Results')),
                    DataColumn(label: Text('Emergency Contact Name')),
                    DataColumn(label: Text('Emergency Contact Number')),
                    DataColumn(label: Text('Health Status')),
                    DataColumn(label: Text('Health Detailed Information')),
                    DataColumn(label: Text(' modified Information')),
                  ],
                  rows: _filteredStudents.map((student) {
                    return DataRow(
                      cells: [
                        DataCell(Text(student.studentIdNumber.toString())),
                        DataCell(Text(student.name)),
                        DataCell(Text(student.surname)),
                        DataCell(Text(student.class_)),
                        DataCell(Text(student.gender)),
                        DataCell(Text(student.age.toString().split(' ')[0])),
                        DataCell(Text(student.nationality.toString())),
                        DataCell(Text(student.district.toString())),
                        DataCell(Text(student.nationalIdNumber.toString())),
                        DataCell(Text(student.regNumber.toString())),
                        DataCell(Text(student.physicalAddress.toString())),
                        DataCell(Text(student.paymentStatus.toString())),
                        DataCell(Text(student.phoneNumber.toString())),
                        DataCell(Text(student.religion.toString())),
                        DataCell(Text(student.denomination.toString())),
                        DataCell(Text(student.formerSchool.toString())),
                        DataCell(Text(student.previousSchoolPerformanceResults
                            .toString())),
                        DataCell(Text(student.emergencyContactName.toString())),
                        DataCell(
                            Text(student.emergencyContactNumber.toString())),
                        DataCell(Text((student.healthStauts.toString()))),
                        DataCell(Text(
                            (student.healthDetailedInformation.toString()))),
                        DataCell(Text(student.modifiedFields.toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        // Floating arrow buttons for scrolling horizontally (Sticky at the bottom)
        Positioned(
          bottom: 100, // Position the arrows at the bottom
          left: 60,
          right: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left arrow button to scroll left
              FloatingActionButton(
                onPressed: _scrollLeft,
                child: const Icon(Icons.arrow_back),
                mini: true,
                backgroundColor: Colors.blue,
              ),
              // Right arrow button to scroll right
              FloatingActionButton(
                onPressed: _scrollRight,
                child: const Icon(Icons.arrow_forward),
                mini: true,
                backgroundColor: Colors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void generateAndSaveSpreadsheet() async {
    // Create an Excel document
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Students'];

    // Add the headers
    sheetObject.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Surname'),
      TextCellValue('Class'),
      TextCellValue('Gender'),
      TextCellValue('Date of Birth'),
      TextCellValue('Nationality'),
      TextCellValue('District'),
      TextCellValue('National ID Number'),
      TextCellValue('Student Registration Number'),
      TextCellValue('Student Registration Position'),
      TextCellValue('Physical Address'),
      TextCellValue('Parent Name'),
      TextCellValue('Parent Phone Number'),
      TextCellValue('Religion'),
      TextCellValue('Denomination'),
      TextCellValue('Former School'),
      TextCellValue('Former School Results'),
      TextCellValue('Emergency Contact Name'),
      TextCellValue('Emergency Contact Number'),
      TextCellValue('Health Condition'),
      TextCellValue('Healthe Condition Details'),
    ]);

    // Add the data rows (wrap each value accordingly)
    for (var student in _filteredStudents) {
      sheetObject.appendRow([
        IntCellValue(student.id ?? 0), // Assuming student.id is a number
        TextCellValue(student.name),
        TextCellValue(student.surname),
        TextCellValue(student.class_),
        TextCellValue(student.gender),
        TextCellValue(student.age
            .toString()
            .split(' ')[0]), // Only the year part of the age
        TextCellValue(student.nationality ?? ''),
        TextCellValue(student.district ?? ''),
        TextCellValue(student.nationalIdNumber ?? ''),
        TextCellValue(student.studentIdNumber ?? ''),
        TextCellValue(student.regNumber),
        TextCellValue(student.physicalAddress ?? ''),
        TextCellValue(student.paymentStatus),
        TextCellValue(student.phoneNumber),
        TextCellValue(student.religion ?? ''),
        TextCellValue(student.denomination ?? ''),
        TextCellValue(student.formerSchool ?? ''),
        TextCellValue(student.previousSchoolPerformanceResults ?? ''),
        TextCellValue(student.emergencyContactName ?? ''),
        TextCellValue(student.emergencyContactNumber ?? ''),
        TextCellValue(student.healthStauts ?? ''),

        TextCellValue(student.healthDetailedInformation ?? ''),
      ]);
    }

    // Use FilePicker to choose save location
    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        fileName: 'Students.xlsx',
      );

      if (savePath != null) {
        // Write the file
        File(savePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(excel.encode()!);

        print('Spreadsheet saved at: $savePath');
      } else {
        print('File save operation was canceled.');
      }
    } catch (e) {
      print('Error saving spreadsheet: $e');
    }
  }
}
