import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import '../database/school_info.dart';
import 'package:zitf_system/main.dart'; // for getDeviceRole, DeviceRole

class ViewSchoolsScreen extends StatefulWidget {
  const ViewSchoolsScreen({super.key});

  @override
  State<ViewSchoolsScreen> createState() => _ViewSchoolsScreenState();
}

class _ViewSchoolsScreenState extends State<ViewSchoolsScreen> {
  Future<List<School>> _schoolsFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _role = await getDeviceRole();

    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    setState(() {
      _schoolsFuture = (_role == DeviceRole.host)
          ? _fetchSchoolsFromHive()
          : _fetchSchoolsFromServer();
    });
  }

  Future<List<School>> _fetchSchoolsFromHive() async {
    final box = await Hive.openBox<School>('school');
    final schools = box.values.where((s) => s.termId != null).toList();
    schools.sort((a, b) => (a.schoolName ?? '')
        .toLowerCase()
        .compareTo((b.schoolName ?? '').toLowerCase()));
    return schools;
  }

  Future<List<School>> _fetchSchoolsFromServer() async {
    if (_hostIp == null) {
      print("Host IP is null, cannot fetch from server");
      // Show alert in UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Host IP not set. Please configure connection."),
          ),
        );
      });

      return [];
    }

    try {
      final url = Uri.parse('http://$_hostIp:8080/api/school');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;
        return jsonList
            .map((json) => schoolFromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw Exception('Failed to load school data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching school data: $e");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching from host: $e")),
        );
      });
      return [];
    }
  }

  String capitalize(String value) {
    if (value.isEmpty) return value;
    var result = value[0].toUpperCase();
    for (int i = 1; i < value.length; i++) {
      if (value[i - 1] == " ") {
        result += value[i].toUpperCase();
      } else {
        result += value[i];
      }
    }
    return result;
  }

  Future<Uint8List> generateSchoolPDF(List<School> schools) async {
    final pdf = pw.Document();

    final headers = [
      'School Name',
      'School Address',
      'School Phone',
      'School Email'
    ];

    final data = schools.where((school) => school.termId != null).map((school) {
      return [
        school.schoolName ?? '',
        school.schoolAddress ?? '',
        school.schoolPhoneNumber ?? '',
        school.schoolEmail ?? '',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text('School Information',
                style: const pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
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

  @override
  Widget build(BuildContext context) {
    if (_schoolsFuture == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'View School',
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
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final schools = await _schoolsFuture;
              final pdfBytes = await generateSchoolPDF(schools);

              final confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
              if (confirmSave) {
                await savePDFToFile(context, pdfBytes, 'school_report');
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<School>>(
        future: _schoolsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            final schools = snapshot.data!;
            if (schools.isEmpty) {
              return const Center(child: Text('No school info found.'));
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final fontSize = maxWidth < 600 ? 12.0 : 14.0;

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
                              label: Text('Id',
                                  style: TextStyle(fontSize: fontSize))),
                          DataColumn(
                              label: Text('Logo',
                                  style: TextStyle(fontSize: fontSize))),
                          DataColumn(
                              label: Text('School Name',
                                  style: TextStyle(fontSize: fontSize))),
                          DataColumn(
                              label: Text('School Address',
                                  style: TextStyle(fontSize: fontSize))),
                          DataColumn(
                              label: Text('School Phone Number',
                                  style: TextStyle(fontSize: fontSize))),
                          DataColumn(
                              label: Text('School Email',
                                  style: TextStyle(fontSize: fontSize))),
                        ],
                        rows: schools.map((schoolItem) {
                          return DataRow(cells: [
                            DataCell(Text(schoolItem.id.toString(),
                                style: TextStyle(fontSize: fontSize))),
                            DataCell(
                              schoolItem.schoolLogoPath != null
                                  ? Image.file(
                                      File(schoolItem.schoolLogoPath!),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.image_not_supported,
                                      size: 50, color: Colors.grey),
                            ),
                            DataCell(Text(
                                toBeginningOfSentenceCase(
                                        schoolItem.schoolName ?? '') ??
                                    '',
                                style: TextStyle(fontSize: fontSize))),
                            DataCell(Text(
                                toBeginningOfSentenceCase(
                                        schoolItem.schoolAddress ?? '') ??
                                    '',
                                style: TextStyle(fontSize: fontSize))),
                            DataCell(Text(schoolItem.schoolPhoneNumber ?? '',
                                style: TextStyle(fontSize: fontSize))),
                            DataCell(Text(schoolItem.schoolEmail ?? '',
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
            return const Center(child: Text('No school info found.'));
          }
        },
      ),
    );
  }
}
