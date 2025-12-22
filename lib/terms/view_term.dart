import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // For PDF preview
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import '../database/terms.dart'; // Import the Terms model
import 'package:path/path.dart' as path; // To handle file name extensions

class ViewTermsScreen extends StatefulWidget {
  const ViewTermsScreen({super.key});

  @override
  State<ViewTermsScreen> createState() => _ViewTermsScreenState();
}

class _ViewTermsScreenState extends State<ViewTermsScreen> {
  Future<List<Terms>> _termsFuture = Future.value([]);

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

    // Decide which future to load based on role
    setState(() {
      _termsFuture = (_role == DeviceRole.host)
          ? _fetchTermsFromHive()
          : _fetchTermsFromServer();
    });
  }

  Future<List<Terms>> _fetchTermsFromHive() async {
    final box = await Hive.openBox<Terms>('terms');
    final terms = box.values.where((s) => s.termId != null).toList();
    terms.sort((a, b) => (a.termId ?? '')
        .toLowerCase()
        .compareTo((b.termId ?? '').toLowerCase()));
    return terms;
  }

  Future<List<Terms>> _fetchTermsFromServer() async {
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
      final url = Uri.parse('http://$_hostIp:8080/api/terms');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;
        return jsonList
            .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        throw Exception('Failed to load terms data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching terms data: $e");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching from host: $e")),
        );
      });
      return [];
    }
  }

  // Function to generate the PDF
  Future<Uint8List> generateTermsPDF(List<Terms> terms) async {
    final pdf = pw.Document();

    final headers = ['Term Name', 'Started On', 'Ended On', 'Status'];
    final data = terms.map((term) {
      return [
        term.termName,
        term.startDate.toLocal().toString(),
        term.endDate != null
            ? term.endDate!.toLocal().toString()
            : 'Term Still Active',
        term.status,
      ];
    }).toList();

    // Create a PDF page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32), // Add margins for layout
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title of the page
                pw.Text('School Terms Information',
                    style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
            // The table should now automatically split across multiple pages
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
                0: pw.FlexColumnWidth(), // Class Name column
                1: pw.FlexColumnWidth(), // Created On column
                2: pw.FlexColumnWidth(), // Current Term column
                3: pw.FlexColumnWidth(), // Current Term column
              },
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Function to save the PDF file
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
                SnackBar(content: Text("Download directory created.")));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error: External storage directory not found.")));
        }
      } else {
        // Show permission denied notification
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Permission denied for storage access.")));
      }
    } catch (e) {
      // Show error notification
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
          'View Terms',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0, // Subtle shadow
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              // Generate the PDF
              final terms = await _termsFuture;
              Uint8List pdfBytes = await generateTermsPDF(terms);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(context, pdfBytes, 'terms_report');
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
              Color.fromARGB(255, 244, 243, 244),
              Color.fromARGB(255, 253, 252, 252),
            ], // Gradient background colors
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
              final List<Terms> terms = snapshot.data!;
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
                                label: Text('Id',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Term Name',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Started On',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Ended On',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Status',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('mods',
                                    style: TextStyle(fontSize: fontSize))),
                          ],
                          rows: terms.map((term) {
                            return DataRow(cells: [
                              DataCell(Text(
                                  term.id != null ? term.id.toString() : 'null',
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(term.termName,
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(term.startDate.toLocal().toString(),
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(
                                Text(
                                  term.endDate != null
                                      ? term.endDate!.toLocal().toString()
                                      : 'Term Still Active',
                                  style: TextStyle(fontSize: fontSize),
                                ),
                              ),
                              DataCell(Text(term.status,
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(term.modifiedFields.toString(),
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
                child: Text('No terms found.'),
              );
            }
          },
        ),
      ),
    );
  }
}
