import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart'; // To handle file name extensions

class ViewWithdrawalsScreen1 extends StatefulWidget {
  @override
  _ViewWithdrawalsScreenState1 createState() => _ViewWithdrawalsScreenState1();
}

class _ViewWithdrawalsScreenState1 extends State<ViewWithdrawalsScreen1> {
  late Box<Withdrawal> _withdrawalBox;
  late Box<StudentPayment> _studentPaymentBox;
  List<Withdrawal> _filteredWithdrawals = [];
  TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _withdrawalBox = Hive.box<Withdrawal>('withdrawals');
    _studentPaymentBox = Hive.box<StudentPayment>('student_payments');
    _filterWithdrawals();
  }

  void _filterWithdrawals() {
    String searchText = _searchController.text.toLowerCase();
    _filteredWithdrawals = _withdrawalBox.values
        .where((withdrawal) =>
            withdrawal.termId == globalTermId && // Term-specific filter
            withdrawal.withdrawalPurpose.toLowerCase().contains(searchText) &&
            (_startDate == null || withdrawal.date.isAfter(_startDate!)) &&
            (_endDate == null || withdrawal.date.isBefore(_endDate!)))
        .toList();
    setState(() {});
  }

  double _calculateTotalWithdrawalAmount() {
    return _filteredWithdrawals.fold<double>(
        0, (previousValue, withdrawal) => previousValue + withdrawal.amount);
  }

  double _calculateTotalIncome() {
    return _studentPaymentBox.values
        .where((payment) =>
            payment.termId == globalTermId && // Term-specific filter
            (_startDate == null || payment.paymentDate.isAfter(_startDate!)) &&
            (_endDate == null || payment.paymentDate.isBefore(_endDate!)))
        .fold<double>(
            0, (previousValue, payment) => previousValue + payment.amountToPay);
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
        } else {
          _endDate = selectedDate;
        }
      });
      _filterWithdrawals();
    }
  }

  // Function to generate PDF
  Future<Uint8List> generateWithdrawalsPDF(List<Withdrawal> withdrawals) async {
    final pdf = pw.Document();

    final headers = ['Date', 'Amount', 'Purpose'];
    final data = withdrawals.map((withdrawal) {
      return [
        DateFormat.yMMMd().format(withdrawal.date),
        '\$${withdrawal.amount.toStringAsFixed(2)}',
        withdrawal.withdrawalPurpose,
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
                pw.Text('Withdrawals Information',
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
        title: Center(child: Text('All Withdrawals')),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () async {
              Uint8List pdfBytes =
                  await generateWithdrawalsPDF(_filteredWithdrawals);
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
              if (confirmSave) {
                await savePDFToFile(context, pdfBytes, 'withdrawals_report');
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildSearchField(),
                SizedBox(height: 8),
                _buildDatePickers(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _buildColumns(),
                    rows: _buildRows(),
                  ),
                ),
              ),
            ),
          ),
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _filterWithdrawals(),
      decoration: InputDecoration(
        hintText: 'Search withdrawals',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildDatePickers() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => _selectDate(isStartDate: true),
          child: Text(
            _startDate == null
                ? 'Start Date'
                : 'From: ${DateFormat.yMMMd().format(_startDate!)}',
          ),
        ),
        TextButton(
          onPressed: () => _selectDate(isStartDate: false),
          child: Text(
            _endDate == null
                ? 'End Date'
                : 'To: ${DateFormat.yMMMd().format(_endDate!)}',
          ),
        ),
      ],
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      DataColumn(label: Text('Id')),
      DataColumn(label: Text('Date')),
      DataColumn(label: Text('Amount')),
      DataColumn(label: Text('Purpose')),
    ];
  }

  List<DataRow> _buildRows() {
    return _filteredWithdrawals.map((withdrawal) {
      return DataRow(
        cells: [
          DataCell(Text(withdrawal.id.toString())),
          DataCell(Text(DateFormat.yMMMd().format(withdrawal.date))),
          DataCell(Text('\$${withdrawal.amount.toStringAsFixed(2)}')),
          DataCell(Text(withdrawal.withdrawalPurpose)),
        ],
      );
    }).toList();
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Total Withdrawal Amount: \$${_calculateTotalWithdrawalAmount().toStringAsFixed(2)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          FutureBuilder<double>(
            future: Future<double>.value(_calculateTotalIncome()),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final totalIncome = snapshot.data!;
                final difference =
                    totalIncome - _calculateTotalWithdrawalAmount();
                final isOverExpenditure = difference < 0;

                return Column(
                  children: [
                    Text(
                      'Total Income: \$${totalIncome.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Under/Over Expenditure: ${isOverExpenditure ? 'Over' : 'Under'} \$${difference.abs().toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isOverExpenditure ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                );
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                return CircularProgressIndicator();
              }
            },
          ),
        ],
      ),
    );
  }
}
