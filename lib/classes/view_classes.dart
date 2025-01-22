import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
// ignore: unused_import
import 'package:flutter_pdfview/flutter_pdfview.dart'; // For PDF preview
// ignore: unused_import
import 'package:printing/printing.dart';
import 'package:zitf_system/global%20files/global_term_id.dart'; // Import for global term ID
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import '../database/classes.dart'; // Import the Classes model
import 'package:path/path.dart' as path; // To handle file name extensions

class ViewClassesScreen extends StatelessWidget {
  const ViewClassesScreen({super.key});

  // Helper function to capitalize the first letter of each word
  String capitalize(String value) {
    var result = value[0].toUpperCase();
    for (int i = 1; i < value.length; i++) {
      if (value[i - 1] == " ") {
        result = result + value[i].toUpperCase();
      } else {
        result = result + value[i];
      }
    }
    return result;
  }

  Future<Uint8List> generateClassesPDF(
      List<Classes> classes, bool isLandscape) async {
    final pdf = pw.Document();
    // Determine page format based on orientation
    final pageFormat =
        isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    // Headers for the table
    final headers = ['Class Name', 'Created On', 'Current Term'];

    // Map the data from your classes list to table rows
    final data = classes.map((classItem) {
      return [
        classItem.className, // Class name or empty string
        DateFormat.yMMMd().format(classItem.date), // Format date
        classItem.termId?.toString() ??
            '', // Convert term ID to string or empty
      ];
    }).toList();

    // Adding the page to the document using MultiPage
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32), // Add margins for layout
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title of the page
                pw.Text('Classes Information',
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
    return OrientationBuilder(
      builder: (context, orientation) {
        // Determine if the orientation is landscape
        final isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          appBar: AppBar(
            title: const Center(
                child: Text(
              'View Classes',
              style: const TextStyle(
                fontSize: 14.0, // Adjust font size
                fontWeight: FontWeight.normal, // Font weight
                color: Colors.white, // Title color
                letterSpacing: 1.2, // Slight letter spacing for elegance
              ),
            )),
            actions: [
              // Action button to generate the PDF
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: () async {
                  final box = await Hive.openBox<Classes>('classes');
                  List<Classes> classes = box.values
                      .where((classItem) => classItem.termId == globalTermId)
                      .toList();
                  Uint8List pdfBytes =
                      await generateClassesPDF(classes, isLandscape);

                  bool confirmSave =
                      await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

                  if (confirmSave) {
                    await savePDFToFile(context, pdfBytes, 'classes_report');
                  }
                },
              ),
            ],
            backgroundColor: const Color.fromARGB(255, 38, 140,
                191), // Optional: Customize AppBar background color
            elevation: 4.0, // Optional: Add a subtle shadow
          ),
          // Body to display the list of classes
          body: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 252, 251, 252),
                  Color.fromARGB(255, 247, 247, 247),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: FutureBuilder<List<Classes>>(
              future: Hive.openBox<Classes>('classes').then((box) {
                var classes = box.values
                    .where((classItem) => classItem.termId == globalTermId)
                    .toList();
                classes.sort((a, b) =>
                    a.className.compareTo(b.className)); // Sort alphabetically
                return classes;
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasData) {
                  final List<Classes> classes = snapshot.data!;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final fontSize = maxWidth < 600
                          ? 12.0
                          : 14.0; // Adjust font size based on device width

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Center(
                              child: DataTable(
                                headingRowHeight: 40,
                                dataRowHeight: 60,
                                columns: [
                                  DataColumn(
                                      label: Text('Class Name',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Created On',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Current Term',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                ],
                                rows: classes.map((classItem) {
                                  return DataRow(cells: [
                                    DataCell(Text(
                                        capitalize(classItem.className),
                                        style: TextStyle(fontSize: fontSize))),
                                    DataCell(Text(
                                        DateFormat.yMMMd()
                                            .format(classItem.date),
                                        style: TextStyle(fontSize: fontSize))),
                                    DataCell(Text(
                                        classItem.termId?.toString() ?? '',
                                        style: TextStyle(fontSize: fontSize))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: Text('No classes found.'),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}
