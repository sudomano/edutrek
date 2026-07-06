import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/lan_sync_services/sync_service.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import '../database/terms.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class ViewTermsScreen extends StatefulWidget {
  const ViewTermsScreen({super.key});

  @override
  State<ViewTermsScreen> createState() => _ViewTermsScreenState();
}

class _ViewTermsScreenState extends State<ViewTermsScreen> {
  Future<List<Terms>> _termsFuture = Future.value([]);
  List<Terms> _allTerms = [];
  List<Terms> _activeTerms = [];
  List<Terms> _deletedTerms = [];
  bool _showDeleted = false;
  bool _isLoading = false;

  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    _role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip');

    await _loadTerms();
    setState(() => _isLoading = false);
  }

  Future<void> _loadTerms() async {
    final terms = await _fetchTermsFromLocalStorage();
    _allTerms = terms;
    _activeTerms = terms.where((t) => !(t.isDeleted ?? false)).toList();
    _deletedTerms = terms.where((t) => t.isDeleted ?? false).toList();

    setState(() {
      _termsFuture = Future.value(terms);
    });
  }

  Future<List<Terms>> _fetchTermsFromLocalStorage() async {
    try {
      final box = await Hive.openBox<Terms>('terms');
      final terms = box.values.where((s) => s.termId != null).toList();
      terms.sort((a, b) => (a.termId ?? '')
          .toLowerCase()
          .compareTo((b.termId ?? '').toLowerCase()));
      await box.close();
      return terms;
    } catch (e) {
      print("Error loading terms: $e");
      return [];
    }
  }

  // ✅ SOFT DELETE Term
  Future<void> _softDeleteTerm(Terms term, {String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await getLoggedInUser();

      term.markDeleted(
        deletedBy: currentUser?.username ?? 'system',
        reason: reason,
      );
      await term.save();

      if (_role == DeviceRole.client && _hostIp != null) {
        try {
          final response = await http.delete(
            Uri.parse('http://$_hostIp:8080/api/terms'
                '?termId=${term.termId}'
                '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
                '&reason=${Uri.encodeComponent(reason ?? "")}'),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            term.deletedSyncStatus = true;
            term.syncStatus = true;
            term.operationType = 'none';
            await term.save();
          }
        } catch (e) {
          print('Error syncing deletion to server: $e');
        }
      }

      await _loadTerms();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Term ${term.termName} deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting term: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ RESTORE Term
  Future<void> _restoreTerm(Terms term) async {
    setState(() => _isLoading = true);

    try {
      term.restoreDeleted();
      await term.save();

      if (_role == DeviceRole.client && _hostIp != null) {
        try {
          final response = await http.post(
            Uri.parse('http://$_hostIp:8080/api/terms'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'restore',
              'termId': term.termId,
            }),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            term.syncStatus = true;
            term.deletedSyncStatus = true;
            term.operationType = 'none';
            await term.save();
          }
        } catch (e) {
          print('Error syncing restore to server: $e');
        }
      }

      await _loadTerms();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Term ${term.termName} restored successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error restoring term: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ PERMANENTLY DELETE Term
  Future<void> _permanentlyDeleteTerm(Terms term) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Permanently Delete Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Are you sure you want to permanently delete "${term.termName}"?'),
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
        await term.delete();
        await _loadTerms();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Term ${term.termName} permanently deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error permanently deleting term: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ Show delete confirmation dialog
  void _showDeleteConfirmation(Terms term) {
    String? reason;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${term.termName}"?'),
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
              _softDeleteTerm(term, reason: reason);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _manualSyncTerms() async {
    if (_role != DeviceRole.client) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host mode - using local data')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip');

      if (hostIp == null || hostIp.isEmpty) {
        throw Exception('Host IP not configured');
      }

      setState(() => _isLoading = true);

      final syncService = SyncService();
      final synced = await syncService.syncTermsOnly(hostIp);

      if (synced) {
        await _loadTerms();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Terms refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Sync failed');
      }
    } catch (e) {
      await _loadTerms();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Failed to refresh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> generateTermsPDF(List<Terms> terms) async {
    final pdf = pw.Document();

    final headers = [
      'Term Name',
      'Started On',
      'Ended On',
      'Status',
      'Deleted'
    ];
    final data = terms.map((term) {
      final isDeleted = term.isDeleted ?? false;
      return [
        term.termName,
        term.startDate.toLocal().toString(),
        term.endDate != null
            ? term.endDate!.toLocal().toString()
            : 'Term Still Active',
        term.status,
        isDeleted ? 'DELETED' : 'ACTIVE',
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
                pw.Text('School Terms Information',
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
    final displayList = _showDeleted ? _deletedTerms : _activeTerms;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'View Terms',
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
          // ✅ Toggle deleted terms
          if (_deletedTerms.isNotEmpty)
            IconButton(
              icon: Icon(
                _showDeleted ? Icons.visibility : Icons.visibility_off,
                color: _showDeleted ? Colors.orange : Colors.white,
              ),
              onPressed: () => setState(() => _showDeleted = !_showDeleted),
              tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
            ),
          // ✅ Deleted count badge
          if (_deletedTerms.isNotEmpty && !_showDeleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_deletedTerms.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _manualSyncTerms,
            tooltip: 'Refresh terms from host',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final terms = await _termsFuture;
              Uint8List pdfBytes = await generateTermsPDF(terms);
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
              if (confirmSave) {
                await savePDFToFile(context, pdfBytes, 'terms_report');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 244, 243, 244),
                    Color.fromARGB(255, 253, 252, 252),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: FutureBuilder<List<Terms>>(
                future: _termsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasData) {
                    final List<Terms> allTerms = snapshot.data!;

                    if (displayList.isEmpty) {
                      return Center(
                        child: Text(
                          _showDeleted ? 'No deleted terms' : 'No terms found',
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
                                dataRowHeight: 60,
                                columns: [
                                  DataColumn(
                                      label: Text('Id',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Term Name',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Started On',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Ended On',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Status',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('State',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                  DataColumn(
                                      label: Text('Actions',
                                          style:
                                              TextStyle(fontSize: fontSize))),
                                ],
                                rows: displayList.map((term) {
                                  final isDeleted = term.isDeleted ?? false;

                                  return DataRow(
                                    color: isDeleted
                                        ? WidgetStateProperty.all(
                                            Colors.grey.shade100)
                                        : null,
                                    cells: [
                                      DataCell(Text(
                                        term.id != null
                                            ? term.id.toString()
                                            : 'null',
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDeleted ? Colors.grey : null,
                                        ),
                                      )),
                                      DataCell(Text(
                                        term.termName,
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDeleted ? Colors.grey : null,
                                        ),
                                      )),
                                      DataCell(Text(
                                        term.startDate.toLocal().toString(),
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isDeleted ? Colors.grey : null,
                                        ),
                                      )),
                                      DataCell(Text(
                                        term.endDate != null
                                            ? term.endDate!.toLocal().toString()
                                            : 'Active',
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
                                                : term.status == 'Opened'
                                                    ? Colors.green.shade100
                                                    : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isDeleted ? 'DELETED' : term.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDeleted
                                                  ? Colors.red.shade700
                                                  : term.status == 'Opened'
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDeleted
                                                ? Colors.grey.shade200
                                                : term.isActive
                                                    ? Colors.blue.shade100
                                                    : Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isDeleted
                                                ? 'DELETED'
                                                : term.isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDeleted
                                                  ? Colors.grey.shade700
                                                  : term.isActive
                                                      ? Colors.blue.shade700
                                                      : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isDeleted) ...[
                                              // ✅ Restore button
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.restore,
                                                  color: Colors.green,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _restoreTerm(term),
                                                tooltip: 'Restore',
                                              ),
                                              // ✅ Permanent delete
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_forever,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _permanentlyDeleteTerm(
                                                        term),
                                                tooltip: 'Delete Forever',
                                              ),
                                            ] else ...[
                                              // ✅ Delete button
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _showDeleteConfirmation(
                                                        term),
                                                tooltip: 'Delete',
                                              ),
                                            ],
                                          ],
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
                    return const Center(
                      child: Text('No terms found.'),
                    );
                  }
                },
              ),
            ),
    );
  }
}
