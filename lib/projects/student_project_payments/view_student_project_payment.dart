/*import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/student.dart';

class ViewStudentProjectPayment extends StatefulWidget {
  const ViewStudentProjectPayment({Key? key}) : super(key: key);

  @override
  _ViewStudentProjectPaymentState createState() =>
      _ViewStudentProjectPaymentState();
}

class _ViewStudentProjectPaymentState extends State<ViewStudentProjectPayment> {
  String? _selectedProject;
  String? _selectedItem;
  String? _selectedStudent;
  List<ProjectStudentPayment> _filteredPayments = [];
  List<ProjectStudentPayment> _allPayments = [];
  Map<String, String> _studentNames = {};
  Map<String, String> _projectNames = {};
  Map<String, String> _itemNames = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final paymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
    final studentNames = await fetchStudentNames();
    final projectNames = await fetchProjectNames();
    final itemNames = await fetchItemNames();

    setState(() {
      _allPayments = paymentBox.values.toList();
      _filteredPayments = List.from(_allPayments);
      _studentNames = studentNames;
      _projectNames = projectNames;
      _itemNames = itemNames;
    });
  }

  void _filterPayments() {
    setState(() {
      _filteredPayments = _allPayments.where((payment) {
        final projectName =
            _projectNames[payment.projectCode] ?? 'Unknown Project';
        final itemName = _itemNames[payment.itemId] ?? 'Unknown Item';
        final studentName =
            _studentNames[payment.studentId] ?? 'Unknown Student';

        final matchesProject = _selectedProject == null ||
            _selectedProject == 'All' ||
            projectName == _selectedProject;
        final matchesItem = _selectedItem == null ||
            _selectedItem == 'All' ||
            itemName == _selectedItem;
        final matchesStudent = _selectedStudent == null ||
            _selectedStudent!.isEmpty ||
            studentName.toLowerCase().contains(_selectedStudent!.toLowerCase());

        return matchesProject && matchesItem && matchesStudent;
      }).toList();
    });
  }

  Future<Map<String, String>> fetchStudentNames() async {
    final studentBox = await Hive.openBox<Student>('students');
    return {
      for (var student in studentBox.values)
        student.studentIdNumber.toString():
            '${student.name} ${student.surname} ${student.class_}'
    };
  }

  Future<Map<String, String>> fetchProjectNames() async {
    final projectBox = await Hive.openBox<Project>('projects');
    return {
      for (var project in projectBox.values) project.projectCode: project.name
    };
  }

  Future<Map<String, String>> fetchItemNames() async {
    final itemBox = await Hive.openBox<ProjectItem>('projectItems');
    return {
      for (var item in itemBox.values)
        item.projectItemCode: '${item.name} ${item.amount}'
    };
  }

  Future<Uint8List> generateProjectItemsPDF(
      List<ProjectStudentPayment> items) async {
    final pdf = pw.Document();

    final studentNames = await fetchStudentNames();
    final projectNames = await fetchProjectNames();
    final itemNames = await fetchItemNames();

    final headers = [
      'Item Name',
      'Project Name',
      'Student Name',
      'Amount Paid',
      'Balance'
    ];

    final data = items.map((item) {
      final itemName = itemNames[item.itemId] ?? 'Unknown Item';
      final projectName = projectNames[item.projectCode] ?? 'Unknown Project';
      final studentName = studentNames[item.studentId] ?? 'Unknown Student';

      return [
        itemName,
        projectName,
        studentName,
        item.amountPaid.toStringAsFixed(2),
        item.balance.toString(),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Project Item Payments Information',
                    style: const pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
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
                0: const pw.FlexColumnWidth(),
                1: const pw.FlexColumnWidth(),
                2: const pw.FlexColumnWidth(),
                3: const pw.FlexColumnWidth(),
                4: const pw.FlexColumnWidth(),
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
      if (await Permission.storage.request().isGranted) {
        final downloadDir = Directory('/storage/emulated/0/Download');

        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Download directory created.")));
        }

        String filePath = path.join(downloadDir.path, '$fileName.pdf');
        int fileIndex = 1;

        while (await File(filePath).exists()) {
          filePath = path.join(downloadDir.path, '$fileName-$fileIndex.pdf');
          fileIndex++;
        }

        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("PDF saved to $filePath")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Permission denied for storage access.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving PDF: $e")));
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'View Project Item Payments',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              Uint8List pdfBytes =
                  await generateProjectItemsPDF(_filteredPayments);
              await savePDFToFile(
                  context, pdfBytes, 'Filtered_Project_Item_Payments_Report');
            },
          ),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0, // Optional: Add a subtle shadow
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      value: _selectedProject,
                      isExpanded: true,
                      hint: const Text('Select Project'),
                      items: ['All', ..._projectNames.values]
                          .map((project) => DropdownMenuItem(
                                value: project,
                                child: Text(project),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProject = value;
                          _filterPayments();
                        });
                      },
                    ),
                    const SizedBox(height: 8.0), // Spacing between filters
                    DropdownButton<String>(
                      value: _selectedItem,
                      isExpanded: true,
                      hint: const Text('Select Item'),
                      items: ['All', ..._itemNames.values]
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedItem = value;
                          _filterPayments();
                        });
                      },
                    ),
                    const SizedBox(height: 8.0), // Spacing between filters
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by Student',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedStudent = value;
                          _filterPayments();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16.0), // Spacing between filters and table
          // Data Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Project Name')),
                    DataColumn(label: Text('Project Item Name')),
                    DataColumn(label: Text('Student Name')),
                    DataColumn(label: Text('Amount Paid')),
                    DataColumn(label: Text('Balance')),
                  ],
                  rows: _filteredPayments.map((payment) {
                    final projectName =
                        _projectNames[payment.projectCode] ?? 'Unknown Project';
                    final itemName =
                        _itemNames[payment.itemId] ?? 'Unknown Item';
                    final studentName =
                        _studentNames[payment.studentId] ?? 'Unknown Student';

                    return DataRow(cells: [
                      DataCell(Text(projectName)),
                      DataCell(Text(itemName)),
                      DataCell(Text(studentName)),
                      DataCell(Text(payment.amountPaid.toStringAsFixed(2))),
                      DataCell(Text(payment.balance.toString())),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 */