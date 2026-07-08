import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';

class ViewPaymentPurposesScreen extends StatefulWidget {
  const ViewPaymentPurposesScreen({super.key});

  @override
  _ViewPaymentPurposesScreenState createState() =>
      _ViewPaymentPurposesScreenState();
}

class _ViewPaymentPurposesScreenState extends State<ViewPaymentPurposesScreen> {
  late String selectedTermId;
  List<String> allTermIds = [];
  Future<List<PaymentPurpose>> _paymentPurposeFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  bool _showDeleted = false; // ✅ Toggle to show deleted purposes

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Purpose Feedback"),
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

  @override
  void initState() {
    super.initState();
    selectedTermId = globalTermId.toString();
    loadAllTermIds();
  }

  Future<void> loadAllTermIds() async {
    _role = await getDeviceRole();

    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (_role == DeviceRole.host) {
      final purposes = await _fetchPaymentPurposeFromHive();
      setState(() {
        _paymentPurposeFuture = Future.value(purposes);
      });
    } else {
      final purposes = await _fetchPaymentPurposesFromServer();
      setState(() {
        _paymentPurposeFuture = Future.value(purposes);
      });
    }
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposeFromHive() async {
    final box = await Hive.openBox<PaymentPurpose>('payment_purposes');

    // ✅ Only load active (non-deleted) purposes
    final purposes = box.values.where((p) => !(p.isDeleted ?? false)).toList();

    final terms = purposes.map((e) => e.termId).whereType<String>().toSet();
    allTermIds = terms.toList()..sort();

    return purposes;
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesFromServer() async {
    if (_hostIp!.isEmpty) {
      debugPrint("Host IP is null, cannot fetch from server");
      if (mounted) {
        _showDialog("⚠️ Host IP not set. Please configure connection.");
      }
      return [];
    }

    try {
      // ✅ Include deleted parameter for sync purposes
      final url = Uri.parse(
          'http://$_hostIp:8080/api/paymentPurposes?include_deleted=true');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;

        // Convert JSON to List<PaymentPurpose>
        final allPurposes = jsonList
            .map((json) =>
                paymentPurposesFromJson(Map<String, dynamic>.from(json)))
            .toList();

        // ✅ Filter out deleted purposes for display
        final activePurposes =
            allPurposes.where((p) => !(p.isDeleted ?? false)).toList();

        // Extract terms from active purposes only
        final terms =
            activePurposes.map((e) => e.termId).whereType<String>().toSet();
        allTermIds = terms.toList()..sort();

        return activePurposes;
      } else {
        throw Exception(
            'Failed to load payment purposes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching payment purposes: $e");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDialog("⚠️ Failed to fetch payment purposes from server.");
        }
      });
      return [];
    }
  }

  Future<Uint8List> generatePaymentPurposePDF(
      List<PaymentPurpose> paymentPurposes) async {
    final pdf = pw.Document();

    final headers = [
      'Payment Purpose Name',
      'Amount',
      'Term',
      'Must Be Paid By Classes',
      'Exceptions',
      'For Newcomers Only?',
    ];

    final data = paymentPurposes.map((purpose) {
      final classList = (purpose.associatedClasses != null &&
              purpose.associatedClasses!.isNotEmpty)
          ? purpose.associatedClasses!.map((c) => '- $c').join('\n')
          : 'No classes selected';

      final exceptionsList = (purpose.exceptions != null &&
              purpose.exceptions!.isNotEmpty)
          ? purpose.exceptions!.map((e) => '- ${e.exceptionName}').join('\n')
          : 'None';

      return [
        purpose.paymentPurpose ?? '',
        purpose.purposeAmount?.toString() ?? '',
        purpose.termId ?? '',
        classList,
        exceptionsList,
        purpose.forNewcomersOnly == true ? 'Yes' : 'No',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text(
              'Student Payment Purposes Information',
              style: pw.TextStyle(fontSize: 24),
            ),
            pw.SizedBox(height: 20),
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
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(1),
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
            _showDialog("Download directory created.");
          }

          String filePath = path.join(downloadDir.path, '$fileName.pdf');
          int fileIndex = 1;

          while (await File(filePath).exists()) {
            filePath = path.join(downloadDir.path, '$fileName-$fileIndex.pdf');
            fileIndex++;
          }

          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          _showDialog("PDF saved to $filePath");
        } else {
          _showDialog("Error: External storage directory not found.");
        }
      } else {
        _showDialog("Permission denied for storage access.");
      }
    } catch (e) {
      _showDialog("Error saving PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'View Payment Purposes',
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
          // ✅ Toggle to show deleted purposes
          IconButton(
            icon: Icon(
              _showDeleted ? Icons.visibility : Icons.visibility_off,
              color: _showDeleted ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDeleted = !_showDeleted;
                // Reload data with new filter
                _reloadData();
              });
            },
            tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
          ),
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              try {
                final List<PaymentPurpose> allPurposes =
                    await _paymentPurposeFuture;

                final filtered = allPurposes
                    .where((p) => p.termId == selectedTermId)
                    .toList();

                if (filtered.isNotEmpty) {
                  final Uint8List pdfBytes =
                      await generatePaymentPurposePDF(filtered);
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
                } else {
                  _showDialog('No payment purposes for selected term.');
                }
              } catch (e) {
                debugPrint('❌ PDF generation error: $e');
                _showDialog('Failed to generate PDF.');
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (allTermIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Wrap(
                    spacing: 10.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Select Term: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<String>(
                        value: allTermIds.contains(selectedTermId)
                            ? selectedTermId
                            : null,
                        hint: const Text('Select Term'),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedTermId = newValue;
                            });
                          }
                        },
                        items: allTermIds.map((String termId) {
                          return DropdownMenuItem<String>(
                            value: termId,
                            child: Text(termId),
                          );
                        }).toList(),
                      ),
                      if (_showDeleted)
                        const Chip(
                          label: Text('Showing Deleted'),
                          backgroundColor: Colors.red,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              FutureBuilder<List<PaymentPurpose>>(
                future: _paymentPurposeFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasData) {
                    // ✅ Filter by term and deletion status
                    List<PaymentPurpose> purposes = snapshot.data!
                        .where((p) => p.termId == selectedTermId)
                        .toList();

                    // ✅ If not showing deleted, filter them out
                    if (!_showDeleted) {
                      purposes = purposes
                          .where((p) => !(p.isDeleted ?? false))
                          .toList();
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
                                  const DataColumn(label: Text('Status')),
                                  DataColumn(
                                      label: Text('Payment Purpose Name')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Term')),
                                  DataColumn(label: Text('Classes')),
                                  DataColumn(label: Text('Exceptions')),
                                  DataColumn(label: Text('Newcomers Only?')),
                                ],
                                rows: purposes.map((purposeItem) {
                                  final isDeleted =
                                      purposeItem.isDeleted ?? false;

                                  return DataRow(
                                    color: isDeleted
                                        ? MaterialStateProperty.all(
                                            Colors.grey.shade100)
                                        : null,
                                    cells: [
                                      // ✅ Status indicator
                                      DataCell(
                                        Text(
                                          isDeleted ? '🗑️' : '✅',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          toBeginningOfSentenceCase(
                                              purposeItem.paymentPurpose ?? ''),
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            decoration: isDeleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          purposeItem.purposeAmount.toString(),
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            decoration: isDeleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          purposeItem.termId ?? '',
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            decoration: isDeleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        purposeItem.associatedClasses != null &&
                                                purposeItem.associatedClasses!
                                                    .isNotEmpty
                                            ? Container(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: purposeItem
                                                        .associatedClasses!
                                                        .map((className) =>
                                                            Text(
                                                              '- $className',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSize,
                                                                decoration: isDeleted
                                                                    ? TextDecoration
                                                                        .lineThrough
                                                                    : null,
                                                                color: isDeleted
                                                                    ? Colors
                                                                        .grey
                                                                    : null,
                                                              ),
                                                            ))
                                                        .toList(),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                'No classes selected',
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
                                        purposeItem.exceptions != null &&
                                                purposeItem
                                                    .exceptions!.isNotEmpty
                                            ? Container(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: purposeItem
                                                        .exceptions!
                                                        .map((e) => Text(
                                                              '- ${e.exceptionName}',
                                                              style: TextStyle(
                                                                fontSize:
                                                                    fontSize,
                                                                decoration: isDeleted
                                                                    ? TextDecoration
                                                                        .lineThrough
                                                                    : null,
                                                                color: isDeleted
                                                                    ? Colors
                                                                        .grey
                                                                    : null,
                                                              ),
                                                            ))
                                                        .toList(),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                'None',
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
                                        Text(
                                          purposeItem.forNewcomersOnly == true
                                              ? 'Yes'
                                              : 'No',
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            decoration: isDeleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color:
                                                isDeleted ? Colors.grey : null,
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
                    return const Center(
                      child: Text('No Payment Purpose info found.'),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Helper to reload data
  Future<void> _reloadData() async {
    setState(() {
      _paymentPurposeFuture = Future.value([]);
    });

    if (_role == DeviceRole.host) {
      final purposes = await _fetchPaymentPurposeFromHive();
      setState(() {
        _paymentPurposeFuture = Future.value(purposes);
      });
    } else {
      final purposes = await _fetchPaymentPurposesFromServer();
      setState(() {
        _paymentPurposeFuture = Future.value(purposes);
      });
    }
  }
}
