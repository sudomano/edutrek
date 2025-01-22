// ignore_for_file: unused_import

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // For PDF preview
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart'; // To handle file name extensions

class ViewAllTeacherPayments extends StatefulWidget {
  const ViewAllTeacherPayments({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ViewAllTeacherPayments> {
  String? _selectedStudent;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSortAscending = true;

  List<String> _selectedClasses = [];
  List<String> _selectedPaymentPurposes = [];

  List<String> _classes = [];
  List<String> _purposes = [];

  List<TeacherPayment> _filteredPayments = [];
  // ignore: unused_field
  List<String> _students = [];
  List<String> _paymentPurposes = [''];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final paymentBox = await Hive.openBox<TeacherPayment>('teacher_payments');

    // Filter payments by globalTermId
    final filteredPayments = paymentBox.values
        .where((payment) => payment.termId == globalTermId)
        .toList();

    // Fetch unique classes from filtered payments
    _classes = ['All'];

    _classes.addAll(filteredPayments
        .map((payment) => payment.studentClass)
        .toSet()
        .toList());
    _selectedClasses = ['All']; // Default selection

    // Fetch unique payment purposes from filtered payments
    _purposes = ['All'];

    _paymentPurposes.addAll(filteredPayments
        .map((payment) => payment.paymentPurpose)
        .toSet()
        .toList());
    _selectedPaymentPurposes = ['All']; // Default selection

    _filteredPayments.sort((a, b) => _isSortAscending
        ? a.studentSurname.compareTo(b.studentSurname)
        : b.studentSurname.compareTo(a.studentSurname));

    setState(() {});
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterPayments(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<void> _fetchStudentsForClass(String studentClass) async {
    final paymentBox = Hive.box<TeacherPayment>('teacher_payments');

    // Fetch unique students for the selected class
    _students = paymentBox.values
        .where((payment) =>
            payment.studentClass == studentClass &&
            payment.termId == globalTermId)
        .map((payment) => payment.studentName)
        .toSet()
        .toList();

    setState(() {});
  }

  void _filterPayments() {
    final paymentBox = Hive.box<TeacherPayment>('teacher_payments');
    _filteredPayments = paymentBox.values
        .where((payment) => payment.termId == globalTermId)
        .toList();

    if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
      _filteredPayments = _filteredPayments.where((payment) {
        return _selectedClasses.contains(payment.studentClass);
      }).toList();
    }

    if (_selectedStudent != null && _selectedStudent!.isNotEmpty) {
      _filteredPayments = _filteredPayments
          .where((payment) => payment.studentSurname
              .toLowerCase()
              .contains(_selectedStudent!.toLowerCase()))
          .toList();
    }

    if (_selectedPaymentPurposes.isNotEmpty &&
        !_selectedPaymentPurposes.contains("All")) {
      _filteredPayments = _filteredPayments.where((payment) {
        return _selectedPaymentPurposes.contains(payment.paymentPurpose);
      }).toList();
    }

    if (_selectedStartDate != null || _selectedEndDate != null) {
      _filteredPayments = _filteredPayments.where((payment) {
        final paymentDate = payment.paymentDate;
        if (_selectedStartDate != null && _selectedEndDate != null) {
          return paymentDate.isAfter(_selectedStartDate!) &&
              paymentDate.isBefore(_selectedEndDate!);
        } else if (_selectedStartDate != null) {
          return paymentDate.isAfter(_selectedStartDate!);
        } else if (_selectedEndDate != null) {
          return paymentDate.isBefore(_selectedEndDate!);
        }
        return true;
      }).toList();
    }
    _filteredPayments.sort((a, b) => _isSortAscending
        ? a.studentSurname.compareTo(b.studentSurname)
        : b.studentSurname.compareTo(a.studentSurname));
    setState(() {});
  }

  Future<Uint8List> generateStudentsPDF(
      List<TeacherPayment> student_payments) async {
    final pdf = pw.Document();

    final headers = [
      'Staff Name',
      'Staff Surname',
      'Staff Class',
      'Staff Purpose',
      'Staff Amount',
      'Staff Date',
      'School Term'
    ];
    final data = _filteredPayments.map((student) {
      return [
        student.studentName,
        student.studentSurname,
        student.studentClass,
        student.paymentPurpose,
        student.amountToPay,
        DateFormat('yyyy-MM-dd').format(student.paymentDate),
        student.termId.toString(),
      ];
    }).toList();

    // Create a PDF page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4
            .landscape, // Set to A4 landscape        margin: pw.EdgeInsets.all(32), // Add margins for layout
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title of the page
                pw.Text('Staff Payments Summary Information',
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
                for (var i = 0; i < headers.length; i++)
                  i: const pw.FlexColumnWidth(), // Equal width for all columns
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
          'View Paid Staff By',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              Uint8List pdfBytes = await generateStudentsPDF(_filteredPayments);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(context, pdfBytes, 'staff_payment_report');
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
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    title: 'View by Staff Surname',
                    child: _buildSearchStudentField(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Staff Payment Purpose',
                    child: _buildPaymentPurposeDropdown(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Payment Period',
                    child: _buildSearchPaymentPeriod(),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _filterPayments,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        backgroundColor: Color.fromARGB(255, 238, 246, 248),
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
                  Text(
                    'Records Found: ${_filteredPayments.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              child: _filteredPayments.isEmpty
                  ? const Center(
                      child: Text(
                        'No payments found.',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    )
                  : _buildPaymentsTable(),
            ),
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

  Widget _buildPaymentPurposeDropdown() {
    return MultiSelectChip(
      items: _purposes,
      initialSelectedItems: _selectedPaymentPurposes,
      onSelectionChanged: (selectedPurposes) {
        setState(() {
          _selectedPaymentPurposes = selectedPurposes;
        });
      },
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

  Widget _buildSearchStudentField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Student by Surame',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedStudent = value;
        });
      },
    );
  }

  Widget _buildSearchPaymentPeriod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Payment Period:', style: TextStyle(fontSize: 16)),
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
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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

  Widget _buildPaymentsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Id')),
              DataColumn(label: Text('Receipt Number')),
              DataColumn(label: Text('Staff Name')),
              DataColumn(label: Text('Staff Surname')),
              DataColumn(label: Text('Payment Purpose')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Payment Date')),
              DataColumn(label: Text('term ')),
              DataColumn(label: Text('mods ')),
            ],
            rows: _filteredPayments.map((payment) {
              return DataRow(
                cells: [
                  DataCell(Text(payment.id.toString())),
                  DataCell(Text(payment.receiptNumber.toString())),
                  DataCell(Text(payment.studentName)),
                  DataCell(Text(payment.studentSurname)),
                  DataCell(Text(payment.paymentPurpose)),
                  DataCell(Text(payment.amountToPay.toString())),
                  DataCell(Text(payment.paymentDate.toString())),
                  DataCell(Text(payment.termId.toString())),
                  DataCell(Text(payment.modifiedFields.toString())),
                ],
              );
            }).toList(),
          ),
        ),
      ),
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
      TextCellValue('Payment Purpose'),
      TextCellValue('Amount'),
      TextCellValue('Payment Date'),
      TextCellValue('Term'),
    ]);

    // Add the data rows (wrap each value accordingly)
    for (var payment_info in _filteredPayments) {
      sheetObject.appendRow([
        IntCellValue(
            payment_info.id ?? 0), // Assuming payment_info.id is a number
        TextCellValue(payment_info.studentName),
        TextCellValue(payment_info.studentSurname),
        TextCellValue(payment_info.paymentPurpose),
        TextCellValue(payment_info.amountToPay.toString()),

        TextCellValue(payment_info.paymentDate.toString()),
        TextCellValue(payment_info.termId ?? ''),
      ]);
    }

    // Use FilePicker to choose save location
    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        fileName: 'Student_Payments.xlsx',
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
