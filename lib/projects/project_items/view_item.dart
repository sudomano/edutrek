import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as path;

import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';

class ViewProjectItems extends StatelessWidget {
  const ViewProjectItems({super.key});

  // Generate PDF using ProjectItem fields
  Future<Uint8List> generateProjectItemsPDF(
      List<ProjectItem> items, Map<String, String> projectMap) async {
    final pdf = pw.Document();

    final headers = [
      'Item Name',
      'Project Name',
      'Item Type',
      'Active',
      'Track Stock'
    ];

    final data = items.map((item) {
      final projectName = projectMap[item.projectCode] ?? 'Deleted project';
      return [
        item.name ?? '',
        projectName,
        item.itemType ?? '',
        (item.active ?? false) ? 'Yes' : 'No',
        (item.trackStock ?? false) ? 'Yes' : 'No',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('Project Items Report',
              style: const pw.TextStyle(fontSize: 24)),
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

  Future<void> savePDFToFile(
      BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      if (await Permission.storage.request().isGranted) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists())
          await downloadDir.create(recursive: true);

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
            const SnackBar(content: Text("Storage permission denied.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving PDF: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: const Text('View Project Items',
                style: TextStyle(fontSize: 16))),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final itemBox = await Hive.openBox<ProjectItem>('projectItems');
              final items = itemBox.values.toList();
              if (items.isEmpty) return;

              final projectBox = Hive.box<Project>('projects');
              final projectMap = {
                for (var p in projectBox.values) p.projectCode: p.name
              };

              final pdfBytes = await generateProjectItemsPDF(items, projectMap);

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Save PDF'),
                  content: const Text('Do you want to save the generated PDF?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Save')),
                  ],
                ),
              );

              if (confirm == true) {
                await savePDFToFile(context, pdfBytes, 'Project_Items_Report');
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ProjectItem>>(
        future: Hive.openBox<ProjectItem>('projectItems').then((box) =>
            box.values.toList()
              ..sort((a, b) => (a.name ?? '')
                  .toLowerCase()
                  .compareTo((b.name ?? '').toLowerCase()))),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final items = snapshot.data!;
            final projectBox = Hive.box<Project>('projects');
            final projectMap = {
              for (var p in projectBox.values) p.projectCode: p.name
            };

            return Center(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                constraints: BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Project')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Item Type')),
                        DataColumn(label: Text('Active')),
                        DataColumn(label: Text('Tracks Stock')),
                      ],
                      rows: items
                          .map(
                            (item) => DataRow(cells: [
                              DataCell(Text(projectMap[item.projectCode] ??
                                  'Deleted project')),
                              DataCell(Text(item.name ?? '')),
                              DataCell(Text(item.itemType ?? '')),
                              DataCell(
                                  Text((item.active ?? false) ? 'Yes' : 'No')),
                              DataCell(Text(
                                  (item.trackStock ?? false) ? 'Yes' : 'No')),
                            ]),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            );
          } else {
            return const Center(child: Text('No project items found.'));
          }
        },
      ),
    );
  }
}
