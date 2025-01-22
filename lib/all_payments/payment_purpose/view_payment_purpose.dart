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
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart'; // To handle file name extensions

class ViewPaymentPurposesScreen extends StatefulWidget {
  const ViewPaymentPurposesScreen({super.key});

  @override
  _ViewPaymentPurposesScreenState createState() =>
      _ViewPaymentPurposesScreenState();
}

class _ViewPaymentPurposesScreenState extends State<ViewPaymentPurposesScreen> {
  Future<Uint8List> generatePaymentPurposePDF(
      List<PaymentPurpose> paymentPurposes) async {
    final pdf = pw.Document();

    final headers = ['Payment Purpose', 'Amount', 'Term'];

    final data = paymentPurposes.map((paymentPurpose) {
      return [
        paymentPurpose.paymentPurpose ?? '',
        paymentPurpose.purposeAmount?.toString() ?? '',
        paymentPurpose.termId?.toString() ?? '',
      ];
    }).toList();

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
                pw.Text('Student Payment Purposes Information',
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
          'View Payment Purposes  ',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              final box =
                  await Hive.openBox<PaymentPurpose>('payment_purposes');
              final List<PaymentPurpose> filteredPaymentPurposes = box.values
                  .where(
                      (paymentPurpose) => paymentPurpose.termId == globalTermId)
                  .toList();

              if (filteredPaymentPurposes.isNotEmpty) {
                Uint8List pdfBytes =
                    await generatePaymentPurposePDF(filteredPaymentPurposes);

                await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
              } else {
                print('No payment purposes found for the current term.');
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
        child: FutureBuilder<List<PaymentPurpose>>(
          future: Hive.openBox<PaymentPurpose>('payment_purposes').then((box) {
            var purposes = box.values
                .where((purposeItem) =>
                    purposeItem.termId != null &&
                    purposeItem.termId == globalTermId)
                .toList();

            purposes.sort((a, b) => (a.paymentPurpose ?? '')
                .toLowerCase()
                .compareTo((b.paymentPurpose ?? '').toLowerCase()));

            return purposes;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (snapshot.hasData) {
              final List<PaymentPurpose> purposes = snapshot.data!;
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
                                label: Text('Payment Purpose Name',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Amount',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Term',
                                    style: TextStyle(fontSize: fontSize))),
                            DataColumn(
                                label: Text('Must Be Paid By Classes',
                                    style: TextStyle(fontSize: fontSize))),
                          ],
                          rows: purposes.map((purposeItem) {
                            return DataRow(cells: [
                              DataCell(Text(purposeItem.id.toString() ?? '',
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(Text(
                                  toBeginningOfSentenceCase(
                                      purposeItem.paymentPurpose ?? ''),
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(
                                Text(purposeItem.purposeAmount.toString()),
                              ),
                              DataCell(Text(purposeItem.termId ?? '',
                                  style: TextStyle(fontSize: fontSize))),
                              DataCell(
                                purposeItem.associatedClasses != null &&
                                        purposeItem
                                            .associatedClasses!.isNotEmpty
                                    ? Container(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: purposeItem
                                                .associatedClasses!
                                                .map((className) => Text(
                                                      '- $className',
                                                      style: TextStyle(
                                                          fontSize: fontSize),
                                                    ))
                                                .toList(),
                                          ),
                                        ),
                                      )
                                    : Text('No classes selected',
                                        style: TextStyle(fontSize: fontSize)),
                              ),
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
                child: Text('No Payment Purpose info found.'),
              );
            }
          },
        ),
      ),
    );
  }
}
