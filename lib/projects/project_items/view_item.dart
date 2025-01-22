import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:path/path.dart' as path;

class ViewProjectItems extends StatelessWidget {
  const ViewProjectItems({super.key});

  Future<Uint8List> generateProjectItemsPDF(List<ProjectItem> items) async {
    final pdf = pw.Document();

    final headers = [
      'Item Code',
      'Project Code',
      'Item Name',
      'Item Amount',
      'Student Fee'
    ];

    final data = items.map((item) {
      return [
        item.projectItemCode ?? '',
        item.projectCode ?? '',
        item.name ?? '',
        item.amount.toStringAsFixed(2),
        item.isStudentFee ? 'Yes' : 'No',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Project Items Information',
                    style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
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
                0: pw.FlexColumnWidth(),
                1: pw.FlexColumnWidth(),
                2: pw.FlexColumnWidth(),
                3: pw.FlexColumnWidth(),
                4: pw.FlexColumnWidth(),
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
              SnackBar(content: Text("Download directory created.")));
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Permission denied for storage access.")));
      }
    } catch (e) {
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
              'View Project Items',
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.normal,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 38, 140, 191),
          elevation: 4.0,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.picture_as_pdf,
                color: Colors.white,
              ),
              onPressed: () async {
                final box = await Hive.openBox<ProjectItem>('projectItems');
                List<ProjectItem> items = box.values.toList();
                Uint8List pdfBytes = await generateProjectItemsPDF(items);

                bool confirmSave = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Save PDF'),
                    content:
                        const Text('Do you want to save the generated PDF?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );

                if (confirmSave == true) {
                  await savePDFToFile(
                      context, pdfBytes, 'Project_Items_Report');
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
                Color.fromARGB(255, 247, 250, 247),
                Color.fromARGB(255, 252, 253, 253),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FutureBuilder<List<ProjectItem>>(
            future: Hive.openBox<ProjectItem>('projectItems').then((box) {
              var schools = box.values
                  .where((schoolItem) => schoolItem.projectItemCode != null)
                  .toList();

              schools.sort((a, b) => (a.name ?? '')
                  .toLowerCase()
                  .compareTo((b.name ?? '').toLowerCase()));

              return schools;
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (snapshot.hasData) {
                final List<ProjectItem> schools = snapshot.data!;
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
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowHeight: 60,
                            columns: [
                              DataColumn(
                                  label: Text(' Item Name',
                                      style: TextStyle(fontSize: fontSize))),
                              DataColumn(
                                  label: Text('Item Amount',
                                      style: TextStyle(fontSize: fontSize))),
                              DataColumn(
                                  label: Text('Student Payable?',
                                      style: TextStyle(fontSize: fontSize))),
                            ],
                            rows: schools.map((schoolItem) {
                              return DataRow(cells: [
                                DataCell(Text(schoolItem.name.toString() ?? '',
                                    style: TextStyle(fontSize: fontSize))),
                                DataCell(Text(
                                    schoolItem.amount.toString() ?? '0.0',
                                    style: TextStyle(fontSize: fontSize))),
                                DataCell(Text(
                                    schoolItem.isStudentFee ? 'Yes' : 'No',
                                    style: TextStyle(fontSize: fontSize))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              } else {
                return const Center(
                  child: Text('No projects items info found.'),
                );
              }
            },
          ),
        ));
  }
}
