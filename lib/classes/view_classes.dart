// ignore_for_file: unused_local_variable

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
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'package:zitf_system/classes/delete_class.dart';
import 'package:zitf_system/classes/update_class.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/student_management/student_filter.dart';
import '../database/classes.dart';
import 'package:path/path.dart' as path;

class ViewClassesScreen extends StatefulWidget {
  const ViewClassesScreen({super.key});

  @override
  State<ViewClassesScreen> createState() => _ViewClassesScreenState();
}

class _ViewClassesScreenState extends State<ViewClassesScreen> {
  late Future<List<Classes>> _classesFuture;

  @override
  void initState() {
    super.initState();
    _loadClasses(); // load classes on start
  }

  void _loadClasses() {
    _classesFuture = Hive.openBox<Classes>('classes').then((box) {
      var classes = box.values
          .where((classItem) => classItem.terms!.contains(globalTermId))
          .toList();
      classes.sort((a, b) => a.className.compareTo(b.className));
      return classes;
    });
  }

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
    final pageFormat =
        isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    final headers = [
      'Class Name',
      'Created On',
      'Current Term',
      'Terms Associated'
    ];

    final data = classes.map((classItem) {
      return [
        classItem.className,
        DateFormat.yMMMd().format(classItem.date),
        classItem.termId?.toString() ?? '',
        classItem.terms?.join(", ") ?? (''),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Classes Information',
                    style: const pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
              columnWidths: {
                0: const pw.FlexColumnWidth(),
                1: const pw.FlexColumnWidth(),
                2: const pw.FlexColumnWidth(),
                3: const pw.FlexColumnWidth(),
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
        Directory? directory = await getExternalStorageDirectory();

        if (directory != null) {
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
              content: Text("Error: External storage directory not found.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Permission denied for storage access.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving PDF: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        return Scaffold(
          appBar: AppBar(
            title: const Center(
                child: Text(
              'View Classes',
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.normal,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            )),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Classes',
                onPressed: () {
                  _loadClasses(); // reload the future
                  setState(() {}); // refresh the screen
                },
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: () async {
                  final box = await Hive.openBox<Classes>('classes');
                  List<Classes> classes = box.values
                      .where((classItem) =>
                          classItem.terms!.contains(globalTermId))
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
            backgroundColor: const Color.fromARGB(255, 38, 140, 191),
            elevation: 4.0,
          ),
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
              future: _classesFuture,
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
                      final fontSize = maxWidth < 600 ? 12.0 : 14.0;

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Center(
                              child: DataTable(
                                headingRowHeight: 40,
                                dataRowHeight: 60,
                                columns: const [
                                  DataColumn(label: Text('Class Name')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: classes.map((classItem) {
                                  return DataRow(cells: [
                                    DataCell(Text(
                                        capitalize(classItem.className),
                                        style: TextStyle(fontSize: fontSize))),
                                    DataCell(
                                      SizedBox(
                                        width:
                                            150, // Fixed width so Actions column stays pinned
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Tooltip(
                                                message: 'View Students',
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.visibility,
                                                      color: Colors.blue),
                                                  iconSize:
                                                      24, // Small but consistent size
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ViewStudentsScreenfilter(
                                                          selectedClassName:
                                                              classItem
                                                                  .className,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'Edit Class',
                                                child: IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      color: Colors.green),
                                                  iconSize: 24,
                                                  onPressed: () async {
                                                    final result =
                                                        await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            UpdateClassScreen(
                                                          classCode: classItem
                                                              .classCode!, // ✅ PASS CLASSCODE HERE
                                                        ),
                                                      ),
                                                    );
                                                    if (result == true) {
                                                      // 👇 Rebuild by calling setState
                                                      setState(() {});
                                                    }
                                                  },
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'Delete Class',
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.red),
                                                  iconSize: 24,
                                                  onPressed: () async {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            DeleteClassScreen(
                                                          classToDelete:
                                                              classItem, // 👈 pass the class you clicked
                                                        ),
                                                      ),
                                                    );
                                                    _loadClasses(); // refresh list
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
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
