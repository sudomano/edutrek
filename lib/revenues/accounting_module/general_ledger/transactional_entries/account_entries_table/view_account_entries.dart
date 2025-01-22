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
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:path/path.dart' as path; // To handle file name extensions

class ViewAccountsScreen extends StatelessWidget {
  const ViewAccountsScreen({super.key});

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

  Future<Uint8List> generateAccountPDF(List<Account> account) async {
    final pdf = pw.Document();

    final headers = [
      'Account Type',
      'Account Sub-Type',
      'Account Name',
      'Account Code',
      'Operation Type'
    ];

    // Filter accounts by syncStatus
    final data =
        account.where((account) => account.syncStatus == false).map((account) {
      return [
        account.accountType ?? '',
        account.accountSubType ?? '',
        account.accountName ?? '',
        account.accountCode ?? '',
      ];
    }).toList();

    // Create a PDF page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32), // Add margins for layout
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title of the page
                pw.Text('Account Information',
                    style: const pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
            // The table should now automatically split across multiple pages
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
                0: const pw.FlexColumnWidth(), // Account Type column
                1: const pw.FlexColumnWidth(), // Account Sub-Type column
                2: const pw.FlexColumnWidth(), // Account Name column
                3: const pw.FlexColumnWidth(), // Account Code column
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
                const SnackBar(content: Text("Download directory created.")));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Error: External storage directory not found.")));
        }
      } else {
        // Show permission denied notification
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Permission denied for storage access.")));
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
          'View Accounts',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              // Generate the PDF
              final box = await Hive.openBox<Account>('account');
              List<Account> accounts = box.values.toList();
              Uint8List pdfBytes = await generateAccountPDF(accounts);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(context, pdfBytes, 'account_report');
              }
            },
          ),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
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
        child: FutureBuilder<List<Account>>(
          future: Hive.openBox<Account>('account').then((box) {
            var accounts = box.values
                .where((schoolItem) => schoolItem.operationType != null)
                .toList();

            // Debug lines to print each account's details
            for (var account in accounts) {
              print(
                  'Account Name: ${account.accountName}, Account Type: ${account.accountType}');
            }

            accounts.sort((a, b) => (a.accountName ?? '')
                .toLowerCase()
                .compareTo((b.accountName ?? '').toLowerCase()));

            return accounts;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.hasData) {
              final List<Account> accounts = snapshot.data!;

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
                                label: Text('Account Code',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Account Name',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Account Type',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Account Sub-type',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('IsALiquidAsset',
                                    style: TextStyle(fontSize: fontSize))),
                          ],
                          rows: accounts.map((schoolItem) {
                            return DataRow(cells: [
                              DataCell(Text(schoolItem.id.toString() ?? '',
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(
                                  toBeginningOfSentenceCase(
                                      schoolItem.accountCode ?? ''),
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(
                                  toBeginningOfSentenceCase(
                                      schoolItem.accountName ?? ''),
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(schoolItem.accountType ?? '',
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(schoolItem.accountSubType ?? '',
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(
                                  schoolItem.isALiquidAccount.toString(),
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
                child: Text('No Accounts Found'),
              );
            }
          },
        ),
      ),
    );
  }
}
