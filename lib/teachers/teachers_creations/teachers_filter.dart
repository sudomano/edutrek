import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart'; // For date formatting
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
// ignore: unused_import
import 'package:printing/printing.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';

class ViewTeachersScreenfilter extends StatefulWidget {
  const ViewTeachersScreenfilter({Key? key}) : super(key: key);

  @override
  _ViewTeachersScreenStatefilter createState() =>
      _ViewTeachersScreenStatefilter();
}

class _ViewTeachersScreenStatefilter extends State<ViewTeachersScreenfilter> {
  String? _selectedStatus;
  String? _selectedGender;
  String? _selectedSurname;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSortAscending = true;

  List<Teachers> _filteredStudents = [];

  List<String> _genders = ['All', 'Male', 'Female'];
  List<String> _status = [];

  String capitalize(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final studentBox = await Hive.openBox<Teachers>('teachers');

    // Fetch unique employment statuses for the current term and add "All" option
    _status.add('All');
    _status.addAll(studentBox.values
        .where((student) => student.terms!.contains(
            globalTermId)) // Only include records for the current term
        .map((student) => student.employmentStatus)
        .toSet()
        .toList());

    setState(() {});
  }

  void _filterStudents() {
    final studentBox = Hive.box<Teachers>('teachers');
    _filteredStudents = studentBox.values
        .where((student) => student.terms!
            .contains(globalTermId)) // Filter by the current term ID
        .toList();

    if (_selectedStatus != null && _selectedStatus != "All") {
      _filteredStudents = _filteredStudents
          .where((student) => student.employmentStatus == _selectedStatus)
          .toList();
    }

    if (_selectedGender != null && _selectedGender != "All") {
      _filteredStudents = _filteredStudents
          .where((student) => student.gender == _selectedGender)
          .toList();
    }

    if (_selectedSurname != null && _selectedSurname!.isNotEmpty) {
      _filteredStudents = _filteredStudents
          .where((student) => student.IdNumber.toLowerCase()
              .contains(_selectedSurname!.toLowerCase()))
          .toList();
    }

    if (_selectedStartDate != null || _selectedEndDate != null) {
      _filteredStudents = _filteredStudents.where((student) {
        final studentDOB = student.dateOfBirth;
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

    setState(() {});
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterStudents(); // Reapply the filter to reflect the sorting order change
    });
  }

  // Function to generate a PDF containing the teacher information
  Future<Uint8List> generateTeachersPDF(List<Teachers> teachers) async {
    final pdf = pw.Document();
    final headerTextStyle = pw.TextStyle(
      fontSize: 6.0, // Font size for headers
      fontWeight: pw.FontWeight.bold,
    );

    final cellTextStyle = const pw.TextStyle(
      fontSize: 6.0, // Font size for table cells
    );
    final headers = [
      pw.Text('Staff Name', style: headerTextStyle),
      pw.Text('Staff Surname', style: headerTextStyle),
      pw.Text('Staff ID Number', style: headerTextStyle),
      pw.Text('Staff Gender', style: headerTextStyle),
      pw.Text('Staff Date of Birth', style: headerTextStyle),
      pw.Text('Staff Phone', style: headerTextStyle),
      pw.Text('Staff Email', style: headerTextStyle),
      pw.Text('Staff Home Address', style: headerTextStyle),
      pw.Text('Staff Qualifications', style: headerTextStyle),
      pw.Text('Staff Hire Date', style: headerTextStyle),
      pw.Text('Staff Employment Status', style: headerTextStyle),
      pw.Text('Staff School Term', style: headerTextStyle),
      pw.Text('Terms Associated', style: headerTextStyle),
    ];

    final data = teachers.map((teacher) {
      return [
        pw.Text(teacher.name, style: cellTextStyle),
        pw.Text(teacher.surname, style: cellTextStyle),
        pw.Text(teacher.IdNumber, style: cellTextStyle),
        pw.Text(teacher.gender, style: cellTextStyle),
        pw.Text(teacher.dateOfBirth.toString(), style: cellTextStyle),
        pw.Text(teacher.phoneNumber, style: cellTextStyle),
        pw.Text(teacher.email, style: cellTextStyle),
        pw.Text(teacher.address, style: cellTextStyle),
        pw.Text(teacher.qualifications, style: cellTextStyle),
        pw.Text(teacher.hireDate.toString(), style: cellTextStyle),
        pw.Text(teacher.employmentStatus, style: cellTextStyle),
        pw.Text(teacher.termId ?? 'None', style: cellTextStyle),
        pw.Text(teacher.terms?.join(", ") ?? (''), style: cellTextStyle),
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Staff Information',
                  style: const pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerStyle:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                border: pw.TableBorder.all(color: PdfColors.black),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> savePDFToFile(Uint8List pdfBytes, String fileName) async {
    try {
      if (await Permission.storage.request().isGranted) {
        Directory? directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName.pdf';
        final file = File(path);
        await file.writeAsBytes(pdfBytes);
        print("PDF saved to $path");
      }
    } catch (e) {
      print("Error saving PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'Filter Search Staff',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              Uint8List pdfBytes = await generateTeachersPDF(_filteredStudents);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(pdfBytes, 'students_report');
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
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            child: Column(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: _buildCard(
                          title: 'View by Employment Status',
                          child: _buildClassDropdown(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Id Number',
                        child: _buildSurnameField(),
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
                        child: ElevatedButton(
                          onPressed: _filterStudents,
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _filteredStudents.isEmpty
                    ? const Center(
                        child: Text(
                          'No Staff found.',
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      )
                    : _buildStudentsTable(),
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
    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      hint: const Text('Select Employment Status'),
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
        });
      },
      items: _status.map((class_) {
        return DropdownMenuItem(
          value: class_,
          child: Text(class_),
        );
      }).toList(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSurnameField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Staff by Id Number',
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
                  headingRowHeight: 40,
                  dataRowHeight: 60,
                  columns: const [
                    DataColumn(
                        label: Text('Id', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Name', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Surname', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label:
                            Text('ID Number', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Gender', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Date of Birth',
                            style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Phone', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Email', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Home Address',
                            style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Qualifications',
                            style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label:
                            Text('Hire Date', style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text('Employment Status',
                            style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text("Teacher's Assigned Class",
                            style: TextStyle(fontSize: 11))),
                    DataColumn(
                        label: Text("Term", style: TextStyle(fontSize: 11))),

                    DataColumn(
                        label: Text('Terms Associated',
                            style: TextStyle(fontSize: 11))), // New column

                    // DataColumn(
                    //     label: Text("Mods", style: TextStyle(fontSize: 11))),
                  ],
                  rows: _filteredStudents.map((teacher) {
                    return DataRow(cells: [
                      DataCell(Text(capitalize(teacher.id.toString()),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(capitalize(teacher.name),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(capitalize(teacher.surname),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(teacher.IdNumber,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(capitalize(teacher.gender),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          DateFormat('yyyy-MM-dd').format(teacher.dateOfBirth),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(teacher.phoneNumber,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(teacher.email,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(capitalize(teacher.address),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(capitalize(teacher.qualifications),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          DateFormat('yyyy-MM-dd').format(teacher.hireDate),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(capitalize(teacher.employmentStatus),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(
                        teacher.assignedClasses != null &&
                                teacher.assignedClasses!.isNotEmpty
                            ? Container(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: teacher.assignedClasses!
                                        .map((className) => Text(
                                              '- $className',
                                              style:
                                                  const TextStyle(fontSize: 11),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              )
                            : const Text(
                                'No classes Assigned',
                                style: TextStyle(fontSize: 11),
                              ),
                      ),
                      DataCell(Text(capitalize(teacher.termId),
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          capitalize(teacher.terms?.join(", ") ?? ('')),
                          style: const TextStyle(fontSize: 11))),

                      // DataCell(Text(
                      //     capitalize(teacher.modifiedFields.toString()),
                      //     style: const TextStyle(fontSize: 11))),
                    ]);
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
      TextCellValue('National ID Number'),
      TextCellValue('Gender'),
      TextCellValue('Date of Birth'),
      TextCellValue(' Phone Number'),
      TextCellValue('Email address'),
      TextCellValue('Physical Address'),
      TextCellValue('Hired Date'),
      TextCellValue('Qualifocations'),
      TextCellValue('Employment Status'),
      TextCellValue('Assigned Classes'),
      TextCellValue('Terms Associated'), // New column
    ]);

    // Add the data rows (wrap each value accordingly)
    for (var student in _filteredStudents) {
      sheetObject.appendRow([
        IntCellValue(student.id ?? 0), // Assuming student.id is a number
        TextCellValue(student.name),
        TextCellValue(student.surname),
        TextCellValue(student.IdNumber),
        TextCellValue(student.gender),
        TextCellValue(
            student.dateOfBirth.toString()), // Only the year part of the age
        TextCellValue(student.phoneNumber),
        TextCellValue(student.email),
        TextCellValue(student.address),
        TextCellValue(student.hireDate.toString()),
        TextCellValue(student.qualifications),
        TextCellValue(student.employmentStatus),
        TextCellValue(student.assignedClasses.toString()),
        TextCellValue(
            student.terms?.join(", ") ?? ('')), // New field to display terms
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
