// ignore_for_file: unused_local_variable

import 'dart:convert';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/classes/delete_class.dart';
import 'package:zitf_system/classes/update_class.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/class_serializer.dart';
import 'package:zitf_system/student_management/student_filter.dart';
import '../database/classes.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class ViewClassesScreen extends StatefulWidget {
  const ViewClassesScreen({super.key});

  @override
  State<ViewClassesScreen> createState() => _ViewClassesScreenState();
}

class _ViewClassesScreenState extends State<ViewClassesScreen> {
  Future<List<Classes>> _classesFuture = Future.value([]);
  List<Classes> _allClasses = [];
  List<Classes> _activeClasses = [];
  List<Classes> _deletedClasses = [];
  bool _showDeleted = false;
  bool _isLoading = false;
  DeviceRole? _role;
  String? _hostIp;
  bool get _isHostIpMissing => _hostIp == null || _hostIp!.isEmpty;

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

    await _loadClasses();
    setState(() => _isLoading = false);
  }

  Future<void> _loadClasses() async {
    final classes = (_role == DeviceRole.host)
        ? await _fetchClassesFromHive()
        : await _fetchClassesFromServer();

    _allClasses = classes;
    _activeClasses = classes.where((c) => !(c.isDeleted ?? false)).toList();
    _deletedClasses = classes.where((c) => c.isDeleted ?? false).toList();

    setState(() {
      _classesFuture = Future.value(classes);
    });
  }

  Future<List<Classes>> _fetchClassesFromHive() async {
    final box = await Hive.openBox<Classes>('classes');
    final classes = box.values.where((s) => s.termId != null).toList();
    classes.sort((a, b) => a.className.compareTo(b.className));
    return classes;
  }

  Future<List<Classes>> _fetchClassesFromServer() async {
    if (_isHostIpMissing) {
      debugPrint("Host IP is null, cannot fetch from server");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("⚠️ Host IP not set. Please configure connection.")),
        );
      }
      return [];
    }

    try {
      // ✅ Include deleted classes
      final url =
          Uri.parse('http://$_hostIp:8080/api/classes?include_deleted=true');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List;
        return jsonList
            .map((json) => classesFromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw Exception('Failed to load classes data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching classes data: $e");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDialog("⚠️ Failed to load classes data.");
        }
      });
      return [];
    }
  }

  // ✅ SOFT DELETE Class
  Future<void> _softDeleteClass(Classes classObj, {String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = getLoggedInUser();

      classObj.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await classObj.save();

      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final response = await http.delete(
            Uri.parse('http://$_hostIp:8080/api/classes'
                '?classCode=${classObj.classCode}'
                '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
                '&reason=${Uri.encodeComponent(reason ?? "")}'),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            classObj.deletedSyncStatus = true;
            classObj.syncStatus = true;
            classObj.operationType = 'none';
            await classObj.save();
          }
        } catch (e) {
          print('Error syncing deletion to server: $e');
        }
      }

      await _loadClasses();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Class ${classObj.className} deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting class: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ RESTORE Class
  Future<void> _restoreClass(Classes classObj) async {
    setState(() => _isLoading = true);

    try {
      classObj.restoreDeleted();
      await classObj.save();

      if (_role == DeviceRole.client &&
          _hostIp != null &&
          _hostIp!.isNotEmpty) {
        try {
          final response = await http.post(
            Uri.parse('http://$_hostIp:8080/api/classes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'restore',
              'classCode': classObj.classCode,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            classObj.syncStatus = true;
            classObj.deletedSyncStatus = true;
            classObj.operationType = 'none';
            await classObj.save();
          }
        } catch (e) {
          print('Error syncing restore to server: $e');
        }
      }

      await _loadClasses();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Class ${classObj.className} restored successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error restoring class: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ PERMANENTLY DELETE Class
  Future<void> _permanentlyDeleteClass(Classes classObj) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${classObj.className}"?'),
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
      setState(() => _isLoading = true);
      try {
        await classObj.delete();
        await _loadClasses();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Class ${classObj.className} permanently deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error permanently deleting class: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(Classes classObj) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${classObj.className}"?'),
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
              _softDeleteClass(classObj, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Class Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
      'Status',
      'Action'
    ];
    final data = classes.map((classItem) {
      final isDeleted = classItem.isDeleted ?? false;
      return [
        classItem.className,
        DateFormat.yMMMd().format(classItem.date),
        classItem.termId?.toString() ?? '',
        isDeleted ? 'DELETED' : 'ACTIVE',
        'View',
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
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final admin = loggedInUser.role.toLowerCase() == 'admin';
    final secretary = loggedInUser.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser.role.toLowerCase() == 'teacher';
    final accountant = loggedInUser.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser.role.toLowerCase() == 'sub-admin';
    final administration = loggedInUser.role.toLowerCase() == 'administration';

    final displayList = _showDeleted ? _deletedClasses : _activeClasses;

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
              ),
            ),
            actions: [
              // ✅ Toggle deleted classes
              if (_deletedClasses.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _showDeleted ? Icons.visibility : Icons.visibility_off,
                    color: _showDeleted ? Colors.orange : Colors.white,
                  ),
                  onPressed: () => setState(() => _showDeleted = !_showDeleted),
                  tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
                ),
              // ✅ Deleted count badge
              if (_deletedClasses.isNotEmpty && !_showDeleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_deletedClasses.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Classes',
                onPressed: _loadClasses,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: () async {
                  final classes = await _classesFuture;
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
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
                        final List<Classes> allClasses = snapshot.data!;

                        if (displayList.isEmpty) {
                          return Center(
                            child: Text(
                              _showDeleted
                                  ? 'No deleted classes'
                                  : 'No classes found',
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
                                  child: Center(
                                    child: DataTable(
                                      headingRowHeight: 40,
                                      dataRowHeight: 60,
                                      columns: const [
                                        DataColumn(label: Text('Class Name')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: displayList.map((classItem) {
                                        final isDeleted =
                                            classItem.isDeleted ?? false;

                                        return DataRow(
                                          color: isDeleted
                                              ? WidgetStateProperty.all(
                                                  Colors.grey.shade100)
                                              : null,
                                          cells: [
                                            DataCell(
                                              Text(
                                                capitalize(classItem.className),
                                                style: TextStyle(
                                                  fontSize: fontSize,
                                                  decoration: isDeleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  color: isDeleted
                                                      ? Colors.grey
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                  isDeleted
                                                      ? 'DELETED'
                                                      : 'ACTIVE',
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
                                            DataCell(
                                              SizedBox(
                                                width: 200,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      Tooltip(
                                                        message:
                                                            'View Students',
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.visibility,
                                                            color: Colors.blue,
                                                          ),
                                                          iconSize: 24,
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
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
                                                      if (isDeleted) ...[
                                                        // ✅ Restore button
                                                        Tooltip(
                                                          message:
                                                              'Restore Class',
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.restore,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                            iconSize: 24,
                                                            onPressed: () =>
                                                                _restoreClass(
                                                                    classItem),
                                                          ),
                                                        ),
                                                        // ✅ Permanent delete
                                                        Tooltip(
                                                          message:
                                                              'Delete Forever',
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .delete_forever,
                                                              color: Colors.red,
                                                            ),
                                                            iconSize: 24,
                                                            onPressed: () =>
                                                                _permanentlyDeleteClass(
                                                                    classItem),
                                                          ),
                                                        ),
                                                      ] else if (admin ||
                                                          administration ||
                                                          subadmin) ...[
                                                        // ✅ Edit button
                                                        Tooltip(
                                                          message: 'Edit Class',
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.edit,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                            iconSize: 24,
                                                            onPressed:
                                                                () async {
                                                              final result =
                                                                  await Navigator
                                                                      .push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          UpdateClassScreen(
                                                                    classCode:
                                                                        classItem
                                                                            .classCode!,
                                                                  ),
                                                                ),
                                                              );
                                                              if (result ==
                                                                  true) {
                                                                await _loadClasses();
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                        // ✅ Delete button
                                                        Tooltip(
                                                          message:
                                                              'Delete Class',
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              color: Colors.red,
                                                            ),
                                                            iconSize: 24,
                                                            onPressed: () =>
                                                                _showDeleteConfirmation(
                                                                    classItem),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
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
