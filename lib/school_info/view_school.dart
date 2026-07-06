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
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import '../database/school_info.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;

class ViewSchoolsScreen extends StatefulWidget {
  const ViewSchoolsScreen({super.key});

  @override
  State<ViewSchoolsScreen> createState() => _ViewSchoolsScreenState();
}

class _ViewSchoolsScreenState extends State<ViewSchoolsScreen> {
  Future<List<School>> _schoolsFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;

  // ✅ State for deletion management
  bool _showDeleted = false;
  List<School> _activeSchools = [];
  List<School> _deletedSchools = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    _role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    await _loadSchools();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSchools() async {
    final schools = (_role == DeviceRole.host)
        ? await _fetchSchoolsFromHive()
        : await _fetchSchoolsFromServer();

    _activeSchools = schools.where((s) => !(s.isDeleted ?? false)).toList();
    _deletedSchools = schools.where((s) => s.isDeleted ?? false).toList();

    setState(() {
      _schoolsFuture = Future.value(schools);
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
      // ✅ Include deleted schools in fetch
      final url =
          Uri.parse('http://$_hostIp:8080/api/school?include_deleted=true');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List;
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

  // ✅ SOFT DELETE School
  Future<void> _softDeleteSchool(School school, {String? reason}) async {
    try {
      final currentUser = await getLoggedInUser();

      // Mark as deleted locally
      school.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await school.save();

      // Send delete request to server (if client)
      if (_role == DeviceRole.client && _hostIp != null) {
        final response = await http.delete(
          Uri.parse('http://$_hostIp:8080/api/school'
              '?schoolCode=${school.schoolCode}'
              '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
              '&reason=${Uri.encodeComponent(reason ?? "")}'),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          school.deletedSyncStatus = true;
          school.syncStatus = true;
          school.operationType = 'none';
          await school.save();
        }
      }

      await _loadSchools();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('School ${school.schoolName} deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting school: $e')));
    }
  }

  // ✅ RESTORE School
  Future<void> _restoreSchool(School school) async {
    try {
      school.restoreDeleted();
      await school.save();

      if (_role == DeviceRole.client && _hostIp != null) {
        final response = await http.post(
          Uri.parse('http://$_hostIp:8080/api/school'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'restore',
            'schoolCode': school.schoolCode,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          school.syncStatus = true;
          school.deletedSyncStatus = true;
          school.operationType = 'none';
          await school.save();
        }
      }

      await _loadSchools();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('School ${school.schoolName} restored successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error restoring school: $e')));
    }
  }

  // ✅ PERMANENTLY DELETE School
  Future<void> _permanentlyDeleteSchool(School school) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete School'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${school.schoolName}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await school.delete();
        await _loadSchools();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('School ${school.schoolName} permanently deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error permanently deleting school: $e')));
      }
    }
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(School school) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete School'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${school.schoolName}"?'),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Reason for deletion (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => reason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _softDeleteSchool(school, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
      'School Email',
      'Status'
    ];

    final data = schools.where((school) => school.termId != null).map((school) {
      final isDeleted = school.isDeleted ?? false;
      return [
        school.schoolName ?? '',
        school.schoolAddress ?? '',
        school.schoolPhoneNumber ?? '',
        school.schoolEmail ?? '',
        isDeleted ? 'DELETED' : 'ACTIVE',
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

  @override
  Widget build(BuildContext context) {
    final displayList = _showDeleted ? _deletedSchools : _activeSchools;
    final isHost = _role == DeviceRole.host;

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
          // ✅ Toggle deleted schools
          if (_deletedSchools.isNotEmpty)
            IconButton(
              icon: Icon(
                _showDeleted ? Icons.visibility : Icons.visibility_off,
                color: _showDeleted ? Colors.orange : Colors.white,
              ),
              onPressed: () => setState(() => _showDeleted = !_showDeleted),
            ),
          // ✅ Deleted count badge
          if (_deletedSchools.isNotEmpty && !_showDeleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_deletedSchools.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSchools,
          ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<School>>(
              future: _schoolsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasData) {
                  final allSchools = snapshot.data!;
                  if (displayList.isEmpty) {
                    return Center(
                      child: Text(
                        _showDeleted
                            ? 'No deleted schools'
                            : 'No schools found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
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
                              dataRowHeight: 70,
                              columnSpacing: 12,
                              columns: const [
                                DataColumn(label: Text('Id')),
                                DataColumn(label: Text('Logo')),
                                DataColumn(label: Text('School Name')),
                                DataColumn(label: Text('Address')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: displayList.map((schoolItem) {
                                final isDeleted = schoolItem.isDeleted ?? false;

                                return DataRow(
                                  color: isDeleted
                                      ? WidgetStateProperty.all(
                                          Colors.grey.shade100)
                                      : null,
                                  cells: [
                                    DataCell(Text(
                                      schoolItem.id?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    )),
                                    DataCell(
                                      schoolItem.schoolLogoPath != null
                                          ? Image.file(
                                              File(schoolItem.schoolLogoPath!),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.broken_image,
                                                      size: 40),
                                            )
                                          : const Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                              color: Colors.grey),
                                    ),
                                    DataCell(Text(
                                      toBeginningOfSentenceCase(
                                              schoolItem.schoolName ?? '') ??
                                          '',
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isDeleted ? Colors.grey : null,
                                      ),
                                    )),
                                    DataCell(Text(
                                      toBeginningOfSentenceCase(
                                              schoolItem.schoolAddress ?? '') ??
                                          '',
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isDeleted ? Colors.grey : null,
                                      ),
                                    )),
                                    DataCell(Text(
                                      schoolItem.schoolPhoneNumber ?? '',
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isDeleted ? Colors.grey : null,
                                      ),
                                    )),
                                    DataCell(Text(
                                      schoolItem.schoolEmail ?? '',
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isDeleted ? Colors.grey : null,
                                      ),
                                    )),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDeleted
                                              ? Colors.red.shade100
                                              : Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isDeleted ? 'DELETED' : 'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDeleted
                                                ? Colors.red.shade700
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
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

  void _editSchool(School school) {
    // Navigate to edit school screen
    // You can implement this based on your existing edit screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon...')),
    );
  }
}
