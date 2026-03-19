import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as path;

import 'package:zitf_system/database/projects/project_model.dart';

class ViewProjects extends StatelessWidget {
  const ViewProjects({super.key});

  // Capitalize helper
  String capitalize(String value) {
    if (value.isEmpty) return '';
    return value
        .split(' ')
        .map(
            (e) => e.isNotEmpty ? '${e[0].toUpperCase()}${e.substring(1)}' : '')
        .join(' ');
  }

  // Generate PDF for projects
  Future<Uint8List> generateProjectPDF(List<Project> projects) async {
    final pdf = pw.Document();

    final headers = [
      'Project Code',
      'Project Name',
      'Description',
      'Status',
      'Type',
      'Participation'
    ];

    final data = projects.map((p) {
      return [
        p.projectCode,
        p.name,
        p.description ?? '',
        p.status,
        p.projectType,
        p.participationType
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Text('Projects Report', style: const pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            headerStyle:
                pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.black),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // Save PDF to file
  Future<void> savePDFToFile(
      BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      if (await Permission.storage.request().isGranted) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        String filePath = path.join(downloadDir.path, '$fileName.pdf');
        int index = 1;
        while (await File(filePath).exists()) {
          filePath = path.join(downloadDir.path, '$fileName-$index.pdf');
          index++;
        }

        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF saved to $filePath')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final verticalController = ScrollController();
    final horizontalController = ScrollController();

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('View Projects', style: TextStyle(fontSize: 14)),
        ),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final box = await Hive.openBox<Project>('projects');
              final projects = box.values.toList();
              if (projects.isEmpty) return;

              final pdfBytes = await generateProjectPDF(projects);

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Save PDF'),
                  content: const Text('Do you want to save the generated PDF?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await savePDFToFile(context, pdfBytes, 'Projects_Report');
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Project>>(
          future: Hive.openBox<Project>('projects').then(
            (box) => box.values
                .where((p) => p.status.toLowerCase() != 'deleted')
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No projects found.'));
            }

            final projects = snapshot.data!;

            return Scrollbar(
              controller: verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: verticalController,
                scrollDirection: Axis.vertical,
                child: Scrollbar(
                  controller: horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Project Code')),
                        DataColumn(label: Text('Project Name')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Participation')),
                        DataColumn(label: Text('Student Payable?')),
                      ],
                      rows: projects.map((p) {
                        return DataRow(cells: [
                          DataCell(Text(capitalize(p.projectCode))),
                          DataCell(Text(capitalize(p.name))),
                          DataCell(Text(p.description ?? '')),
                          DataCell(Text(p.status)),
                          DataCell(Text(p.projectType)),
                          DataCell(Text(p.participationType)),
                          DataCell(
                            Text(p.studentPayable == true ? 'Yes' : 'No'),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
