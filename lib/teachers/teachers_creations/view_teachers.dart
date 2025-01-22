import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart'; // To handle file name extensions

class ViewTeachersScreen extends StatelessWidget {
  const ViewTeachersScreen({Key? key}) : super(key: key);

  // Helper function to capitalize the first letter of each word
  String capitalize(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  // Function to generate a PDF containing the teacher information
  Future<Uint8List> generateTeachersPDF(List<Teachers> teachers) async {
    final pdf = pw.Document();
    final headerTextStyle = pw.TextStyle(
      fontSize: 6.0, // Font size for headers
      fontWeight: pw.FontWeight.bold,
    );

    final cellTextStyle = pw.TextStyle(
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
      ];
    }).toList();

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
                pw.Text('Staff Information', style: pw.TextStyle(fontSize: 24)),
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
                8: pw.FlexColumnWidth(), // Class Name column
                9: pw.FlexColumnWidth(), // Created On column
                10: pw.FlexColumnWidth(), // Current Term column
                11: pw.FlexColumnWidth(), // Current Term column
                12: pw.FlexColumnWidth(), // Class Name column
              },
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Function to save the generated PDF to the device's storage
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
            SnackBar(content: Text("Permission denied for storage access. ")));
        print("Permission denied for storage access.");
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
        title: Center(child: const Text('View Staff')),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        actions: [
          // Action button to generate the PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final box = await Hive.openBox<Teachers>('teachers');
              List<Teachers> teachers = box.values
                  .where((teacher) => teacher.termId == globalTermId)
                  .toList();
              Uint8List pdfBytes = await generateTeachersPDF(teachers);

              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                await savePDFToFile(context, pdfBytes, 'teachers_report');
              }
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, 1),
              Color.fromRGBO(255, 255, 255, 1)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Teachers>>(
          future: Hive.openBox<Teachers>('teachers').then((box) {
            var teachers =
                box.values.where((c) => c.termId == globalTermId).toList();
            teachers.sort((a, b) => a.surname.compareTo(b.surname));
            return teachers;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.hasData) {
              final List<Teachers> teachers = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final fontSize = maxWidth < 600 ? 12.0 : 14.0;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowHeight: 60,
                      columns: [
                        DataColumn(
                            label: Text('Id',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Name',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Surname',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('ID Number',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Gender',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Date of Birth',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Phone',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Email',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Home Address',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Qualifications',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Hire Date',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text('Employment Status',
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text("Teacher's Assigned Class",
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text("Term",
                                style: TextStyle(fontSize: fontSize))),
                        DataColumn(
                            label: Text("mods",
                                style: TextStyle(fontSize: fontSize))),
                      ],
                      rows: teachers.map((teacher) {
                        return DataRow(cells: [
                          DataCell(Text(capitalize(teacher.id.toString()),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(teacher.name),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(teacher.surname),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(teacher.IdNumber,
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(teacher.gender),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(
                              DateFormat('yyyy-MM-dd')
                                  .format(teacher.dateOfBirth),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(teacher.phoneNumber,
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(teacher.email,
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(teacher.address),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(teacher.qualifications),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(
                              DateFormat('yyyy-MM-dd').format(teacher.hireDate),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(capitalize(teacher.employmentStatus),
                              style: TextStyle(fontSize: fontSize))),
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
                                                  style: TextStyle(
                                                      fontSize: fontSize),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  )
                                : Text(
                                    'No classes Assigned',
                                    style: TextStyle(fontSize: fontSize),
                                  ),
                          ),
                          DataCell(Text(capitalize(teacher.termId),
                              style: TextStyle(fontSize: fontSize))),
                          DataCell(Text(
                              capitalize(teacher.modifiedFields.toString()),
                              style: TextStyle(fontSize: fontSize))),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              );
            } else {
              return const Center(
                child: Text('No teacher data available for this term.'),
              );
            }
          },
        ),
      ),
    );
  }
}
