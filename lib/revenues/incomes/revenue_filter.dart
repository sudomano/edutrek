import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:path/path.dart' as path;
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart'; // To handle file name extensions

class ViewAllRevenuesFilter extends StatefulWidget {
  const ViewAllRevenuesFilter({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ViewAllRevenuesFilter> {
  String? _selectedStudent;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedSortOption = 'Surname'; // Default sort option
  bool _isSortAscending = true;

  List<StudentPayment> _filteredPayments = [];
  List<PaymentPurpose> filteredPaymentPurposesOnly = [];

  List<String> _students = [];
  Map<String, double> _paymentPurposeAmounts = {};

  List<String> _selectedClasses = [];
  List<String> _selectedPaymentPurposes = [];

  List<String> _paymentPurposesOnly = [];
  List<String> _selectedPaymentPurposesArrears = [];

  List<String> _classes = [];
  List<String> _purposes = [];
  List<String> _purposesOnly = [];

  // Maps for holding payment data
  Map<String, Map<String, double>> groupedPayments = {};
  Map<String, Map<String, double>> totalPaid = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final paymentBox = await Hive.openBox<StudentPayment>('student_payments');
    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');

    final filteredPayments = paymentBox.values
        .where((payment) => payment.termId == globalTermId)
        .toList();

    final filteredPaymentPurposesOnly = paymentPurposeBox.values
        .where((payment) => payment.termId == globalTermId)
        .toList();

    // Fetch unique classes from filtered payments
    _classes = ['All'];
    _classes.addAll(filteredPayments
        .map((student) => student.studentClass)
        .toSet()
        .toList());
    _selectedClasses = ['All']; // Default selection

    // Fetch unique payment purposes from filtered payments
    // Fetch unique classes from filtered payments
    _purposes = ['All'];
    _purposes.addAll(filteredPayments
        .map((student) => student.paymentPurpose)
        .toSet()
        .toList());
    _selectedPaymentPurposes = ['All']; // Default selection

    // Fetch unique classes from filtered payments
    _purposesOnly = ['All'];
    _purposesOnly.addAll(filteredPaymentPurposesOnly
        .map((student) => student.paymentPurpose)
        .toSet()
        .toList());
    _selectedPaymentPurposesArrears = ['All']; // Default selection

    // Fetch unique payment purposes only from the purposes db
    _paymentPurposesOnly.addAll(paymentPurposeBox.values
        .where((purposeOnly) => purposeOnly.termId == globalTermId)
        .map((purposeOnly) => purposeOnly.paymentPurpose)
        .toSet()
        .toList());

    // Fetch payment purpose only amounts
    for (var purposeOnly in paymentPurposeBox.values) {
      _paymentPurposeAmounts[purposeOnly.paymentPurpose] =
          purposeOnly.purposeAmount;
    }

    setState(() {});
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterPayments(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<void> _fetchStudentsForClass(String studentClass) async {
    final paymentBox = Hive.box<StudentPayment>('student_payments');

    // Fetch unique students for the selected class
    _students = paymentBox.values
        .where((payment) =>
            payment.studentClass == studentClass &&
            payment.termId == globalTermId)
        .map((payment) => '${payment.studentName} ${payment.studentSurname}')
        .toSet()
        .toList();

    setState(() {});
  }

  void _filterPayments() {
    final paymentBox = Hive.box<StudentPayment>('student_payments');
    _filteredPayments = paymentBox.values
        .where((purposeOnly) => purposeOnly.termId == globalTermId)
        .toList();

    if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
      _filteredPayments = _filteredPayments.where((payment) {
        return _selectedClasses.contains(payment.studentClass);
      }).toList();
    }

    if (_selectedStudent != null && _selectedStudent!.isNotEmpty) {
      _filteredPayments = _filteredPayments
          .where((payment) => ' ${payment.studentSurname}'
              .toLowerCase()
              .contains(_selectedStudent!.toLowerCase()))
          .toList();
    }

    if (_selectedPaymentPurposes.isNotEmpty &&
        !_selectedPaymentPurposes.contains("All")) {
      _filteredPayments = _filteredPayments.where((payment) {
        return _selectedPaymentPurposes.contains(payment.paymentPurpose);
      }).toList();
    }

    if (_selectedPaymentPurposesArrears.isNotEmpty &&
        !_selectedPaymentPurposesArrears.contains("All")) {
      filteredPaymentPurposesOnly =
          filteredPaymentPurposesOnly.where((payment) {
        return _selectedPaymentPurposes.contains(payment.paymentPurpose) &&
            (payment.purposeAmount < 0.0);
      }).toList();
    }

    if (_selectedStartDate != null || _selectedEndDate != null) {
      _filteredPayments = _filteredPayments.where((payment) {
        final paymentDate = payment.paymentDate;
        if (_selectedStartDate != null && _selectedEndDate != null) {
          return paymentDate.isAfter(_selectedStartDate!) &&
              paymentDate.isBefore(_selectedEndDate!);
        } else if (_selectedStartDate != null) {
          return paymentDate.isAfter(_selectedStartDate!);
        } else if (_selectedEndDate != null) {
          return paymentDate.isBefore(_selectedEndDate!);
        }
        return true;
      }).toList();
    }
    // Sort the filtered payments based on the selected sorting option
    if (_selectedSortOption == 'Surname') {
      _filteredPayments.sort((a, b) => a.studentSurname
          .toLowerCase()
          .compareTo(b.studentSurname.toLowerCase()));
    } else if (_selectedSortOption == 'First Name') {
      _filteredPayments.sort((a, b) =>
          a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));
    }
    // Calculate groupedPayments and totalPaid based on filtered payments
    _calculateGroupedPayments();
    _calculateTotalPaid();

    setState(() {});

    _filteredPayments.sort((a, b) => _isSortAscending
        ? a.studentSurname.compareTo(b.studentSurname)
        : b.studentSurname.compareTo(a.studentSurname));

    setState(() {});
  }

  void _calculateGroupedPayments() {
    groupedPayments.clear();
    for (var payment in _filteredPayments) {
      final studentName = '${payment.studentName} ${payment.studentSurname}';
      final paymentPurpose = payment.paymentPurpose;
      final amountToPay = payment.amountToPay.toDouble();
      groupedPayments.putIfAbsent(studentName, () => {});
      groupedPayments[studentName]!.putIfAbsent(paymentPurpose, () => 0.0);

      groupedPayments[studentName]![paymentPurpose] =
          (groupedPayments[studentName]![paymentPurpose] ?? 0.0) + amountToPay;
    }
  }

  void _calculateTotalPaid() {
    totalPaid.clear();
    for (var payment in _filteredPayments) {
      final studentName = '${payment.studentName} ${payment.studentSurname}';
      final paymentPurpose = payment.paymentPurpose;
      final amountPaid = payment.amountToPay.toDouble();
      totalPaid.putIfAbsent(studentName, () => {});
      totalPaid[studentName]!.putIfAbsent(paymentPurpose, () => 0.0);

      totalPaid[studentName]![paymentPurpose] =
          (totalPaid[studentName]![paymentPurpose] ?? 0.0) + amountPaid;
    }
  }

  Future<Uint8List> generateStudentsPDF(
      List<StudentPayment> studentPayments) async {
    final pdf = pw.Document();
    final headerTextStyle = pw.TextStyle(
      fontSize: 6.0,
      fontWeight: pw.FontWeight.bold,
    );

    const cellTextStyle = pw.TextStyle(
      fontSize: 6.0,
    );

    // Calculate totals for each purpose
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    // Initialize totals to zero for each purpose
    for (var purpose in _selectedPaymentPurposes) {
      grandTotalPurposePaid[purpose] = 0.0;
    }

    for (var purposeOnly in _paymentPurposesOnly) {
      grandTotalPurposeArrears[purposeOnly] = 0.0;
    }

    // Calculate data rows and update grand totals
    final dataRows = groupedPayments.entries.map((entry) {
      final studentName = entry.key;
      final studentClass = _filteredPayments
          .firstWhere(
            (payment) =>
                '${payment.studentName} ${payment.studentSurname}' ==
                studentName,
          )
          .studentClass;

      // Total Paid
      final totalPaidAmount =
          totalPaid[studentName]?.values.reduce((a, b) => a + b) ?? 0.0;

      // First Section: Payment Information
      final firstSectionCells = [
        pw.Text(studentName, style: cellTextStyle),
        pw.Text(studentClass, style: cellTextStyle),
        ..._selectedPaymentPurposes.map((purpose) {
          final amount = entry.value[purpose] ?? 0.0;
          // Update grand total for this purpose
          grandTotalPurposePaid[purpose] =
              grandTotalPurposePaid[purpose]! + amount;
          return amount.toStringAsFixed(2);
        }).toList(),
        totalPaidAmount.toStringAsFixed(2),
      ];

      // Second Section: Arrears Information
      final secondSectionCells = _paymentPurposesOnly.map((purposeOnly) {
        final purposeAmount = _paymentPurposeAmounts[purposeOnly] ?? 0.0;
        final matchingAmount = entry.value.entries
                .firstWhere(
                    (e) => e.key.toLowerCase() == purposeOnly.toLowerCase(),
                    orElse: () => const MapEntry('', 0.0))
                .value ??
            0.0;
        final result = matchingAmount - purposeAmount;
        // Update grand total for this purpose
        grandTotalPurposeArrears[purposeOnly] =
            grandTotalPurposeArrears[purposeOnly]! + result;
        return result.toStringAsFixed(2);
      }).toList();

      // Total Arrears
      final totalArrears = secondSectionCells.fold(0.0, (sum, item) {
        return sum + (double.tryParse(item) ?? 0.0);
      });

      return [
        ...firstSectionCells,
        ...secondSectionCells,
        totalArrears.toStringAsFixed(2),
      ];
    }).toList();

    // Calculate grand totals for all purposes
    final grandTotalPaid = grandTotalPurposePaid.values.reduce((a, b) => a + b);
    final grandTotalArrears =
        grandTotalPurposeArrears.values.reduce((a, b) => a + b);

    // Grand total row
    final grandTotalPaidRow = [
      pw.Text('GRAND TOTALS', style: headerTextStyle),
      pw.Text('', style: headerTextStyle), // Empty cell for 'Student Class'
      ..._selectedPaymentPurposes.map((purpose) {
        return pw.Text('${grandTotalPurposePaid[purpose]!.toStringAsFixed(2)}',
            style: headerTextStyle);
      }).toList(),
      pw.Text('$grandTotalPaid', style: headerTextStyle),
      ..._paymentPurposesOnly.map((purposeOnly) {
        return pw.Text(
            '${grandTotalPurposeArrears[purposeOnly]!.toStringAsFixed(2)}',
            style: headerTextStyle);
      }).toList(),
      pw.Text('$grandTotalArrears', style: headerTextStyle),
    ];

    // Add a PDF page with the table
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
                pw.Text('Incomes Information',
                    style: const pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
              ],
            ),
            // The table with headers and data, automatically splitting across multiple pages
            pw.Table.fromTextArray(
              headers: [
                pw.Text('Student Name', style: headerTextStyle),
                pw.Text('Student Class', style: headerTextStyle),
                ..._selectedPaymentPurposes
                    .map((purpose) =>
                        pw.Text('$purpose PAID (\$)', style: headerTextStyle))
                    .toList(),
                pw.Text('TOTAL PAID', style: headerTextStyle),
                ..._paymentPurposesOnly
                    .map((purposeOnly) => pw.Text('$purposeOnly ARREARS (\$)',
                        style: headerTextStyle))
                    .toList(),
                pw.Text('TOTAL ARREARS', style: headerTextStyle),
              ],
              data: [
                ...dataRows,
                grandTotalPaidRow
              ], // Add grand total row here
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
              columnWidths: {
                for (var i = 0;
                    i <
                        _selectedPaymentPurposes.length +
                            _paymentPurposesOnly.length +
                            4;
                    i++)
                  i: const pw.FlexColumnWidth(), // Equal width for all columns
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
          'Detailed Incomes',
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
              Uint8List pdfBytes = await generateStudentsPDF(_filteredPayments);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(context, pdfBytes, 'Incomes_report');
              }
            },
          ),
          IconButton(
              icon: const Icon(
                Icons.edit_document,
                color: Colors.white,
              ),
              onPressed: () async {
                generateAndSaveSpreadsheet();
              }),
        ],
        backgroundColor:
            const Color.fromARGB(255, 38, 140, 191), // AppBar background color
        elevation: 4.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    title: 'View by Class',
                    child: _buildClassDropdown(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Student Name',
                    child: _buildSearchStudentField(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Payment Purpose',
                    child: _buildPaymentPurposeDropdown(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Arrears In',
                    child: _buildPaymentPurposeOnlyDropdown(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'Filter by Payment Period',
                    child: _buildSearchPaymentPeriod(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'Sort by',
                    child: _buildSortDropdown(),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _filterPayments,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        backgroundColor:
                            const Color.fromARGB(255, 238, 246, 248),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Sort by Surname: ',
                          style: TextStyle(fontSize: 16)),
                      IconButton(
                        icon: Icon(_isSortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        onPressed: _toggleSortOrder,
                      ),
                    ],
                  ),
                  Text(
                    'Records Found: ${_filteredPayments.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _filteredPayments.isEmpty
                ? const Center(
                    child: Text(
                      'No payments found.',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : _buildPaymentsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPurposeOnlyDropdown() {
    return MultiSelectChip(
      items: _purposesOnly,
      initialSelectedItems: _selectedPaymentPurposesArrears,
      onSelectionChanged: (selectedPurposesOnly) {
        setState(() {
          _selectedPaymentPurposesArrears = selectedPurposesOnly;
        });
      },
    );
  }

  Widget _buildClassDropdown() {
    return MultiSelectChip(
      items: _classes,
      initialSelectedItems: _selectedClasses,
      onSelectionChanged: (selectedClasses) {
        setState(() {
          _selectedClasses = selectedClasses;
        });
      },
    );
  }

  Widget _buildPaymentPurposeDropdown() {
    return MultiSelectChip(
      items: _purposes,
      initialSelectedItems: _selectedPaymentPurposes,
      onSelectionChanged: (selectedPurposes) {
        setState(() {
          _selectedPaymentPurposes = selectedPurposes;
        });
      },
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSearchStudentField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Student by Name',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedStudent = value;
        });
      },
    );
  }

  Widget _buildSearchPaymentPeriod() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedStartDate = pickedDate;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 238, 246, 248),
                borderRadius: BorderRadius.circular(10),
                //border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _selectedStartDate != null
                            ? 'From: ${_selectedStartDate!.toLocal()}'
                            : 'Start Date',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedEndDate = pickedDate;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 238, 246, 248),
                borderRadius: BorderRadius.circular(10),
                // border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _selectedEndDate != null
                            ? 'To: ${_selectedEndDate!.toLocal()}'
                            : 'End Date',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Widget _buildSortDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSortOption,
      items: ['Surname', 'First Name']
          .map((sortOption) => DropdownMenuItem(
                value: sortOption,
                child: Text(sortOption),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedSortOption = value!;
        });
      },
    );
  }

  Widget _buildPaymentsTable() {
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();

    // Horizontal scroll increment value
    const double scrollIncrement = 100.0; // You can adjust the value as needed

    // Function to scroll horizontally by increment
    void _scrollLeft() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset - scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Function to scroll horizontally by decrement
    void _scrollRight() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset + scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    double grandTotalPaid = 0.0;
    Map<String, double> grandTotalPurposePaid = {};
    double grandTotalArrears = 0.0;
    Map<String, double> grandTotalPurposeArrears = {};

    for (var entry in groupedPayments.entries) {
      final studentName = entry.key;
      final totalPaidAmount =
          totalPaid[studentName]?.values.reduce((a, b) => a + b) ?? 0.0;
      grandTotalPaid += totalPaidAmount;

      for (var purpose in _selectedPaymentPurposes) {
        final amount = entry.value[purpose] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + amount;
      }

      for (var purposeOnly in _paymentPurposesOnly) {
        final purpose = Hive.box<PaymentPurpose>('payment_purposes')
            .values
            .firstWhere(
              (p) =>
                  p.paymentPurpose.toLowerCase() == purposeOnly.toLowerCase(),
              orElse: () => PaymentPurpose(
                paymentPurpose: 'N/A',
                associatedClasses: [], id: 0,
                purposeAmount: 0.0,
                // Add any other required fields for your `PaymentPurpose` model
              ),
            );

        if (purpose.paymentPurpose != 'N/A') {
          for (var entry in groupedPayments.entries) {
            final studentClass = _filteredPayments
                .firstWhere((payment) =>
                    '${payment.studentName} ${payment.studentSurname}' ==
                    entry.key)
                .studentClass;

            if (purpose.associatedClasses?.contains(studentClass) ?? false) {
              final purposeAmount = _paymentPurposeAmounts[purposeOnly] ?? 0.0;
              final matchingAmount = entry.value.entries
                      .firstWhere(
                        (e) => e.key.toLowerCase() == purposeOnly.toLowerCase(),
                        orElse: () => const MapEntry('', 0.0),
                      )
                      .value ??
                  0.0;
              print(studentClass);
              print(purpose.associatedClasses);

              final arrears = matchingAmount - purposeAmount;
              grandTotalArrears += arrears;
              grandTotalPurposeArrears[purposeOnly] =
                  (grandTotalPurposeArrears[purposeOnly] ?? 0.0) + arrears;
            }
          }
        }
      }
    }

    return Stack(
      children: [
        // Main table with vertical and horizontal scrolling
        Scrollbar(
          thumbVisibility: true,
          controller: horizontalScrollController,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              thumbVisibility: true,
              controller: verticalScrollController,
              child: SingleChildScrollView(
                controller: verticalScrollController,
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 170, 244, 208),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('STUDENT NAME'.toUpperCase()),
                      ),
                    ),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 175, 253, 215),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('STUDENT CLASS'.toUpperCase()),
                      ),
                    ),
                    ..._selectedPaymentPurposes.map((purpose) {
                      return DataColumn(
                        label: Container(
                          color: Colors.greenAccent,
                          padding: const EdgeInsets.all(8.0),
                          child: Text('$purpose PAID(\$)'.toUpperCase()),
                        ),
                      );
                    }),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 13, 244, 244),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('TOTAL PAID'.toUpperCase()),
                      ),
                    ),
                    ..._paymentPurposesOnly.map((purposeOnly) {
                      final purposeAmount =
                          _paymentPurposeAmounts[purposeOnly] ?? 0.0;
                      return DataColumn(
                        label: Container(
                          color: const Color.fromARGB(255, 246, 55, 2),
                          padding: const EdgeInsets.all(8.0),
                          child: Text('$purposeOnly ARREARS (\$$purposeAmount)'
                              .toUpperCase()),
                        ),
                      );
                    }),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 248, 151, 4),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('TOTAL ARREARS'.toUpperCase()),
                      ),
                    ),
                  ],
                  rows: [
                    ...groupedPayments.entries.map((entry) {
                      final studentName = entry.key;
                      final totalPaidAmount = totalPaid[studentName]
                              ?.values
                              .reduce((a, b) => a + b) ??
                          0.0;
                      double totalArrears = 0.0;

                      final arrearsCells =
                          _paymentPurposesOnly.map((purposeOnly) {
                        final purpose =
                            Hive.box<PaymentPurpose>('payment_purposes')
                                .values
                                .firstWhere(
                                  (p) =>
                                      p.paymentPurpose.toLowerCase() ==
                                      purposeOnly.toLowerCase(),
                                  orElse: () => PaymentPurpose(
                                    paymentPurpose: 'N/A',
                                    associatedClasses: [], id: 0,
                                    purposeAmount: 0.0,
                                    // Add any other required fields for your `PaymentPurpose` model
                                  ),
                                );
// Handle the default case if necessary
                        if (purpose.paymentPurpose == 'N/A') {
                          return const DataCell(Text('N/A'));
                        }
                        // Get the student's class
                        final studentClass = _filteredPayments
                            .firstWhere((payment) =>
                                '${payment.studentName} ${payment.studentSurname}' ==
                                studentName)
                            .studentClass;

                        // Check if the student's class is associated with the payment purpose
                        if (!(purpose.associatedClasses
                                ?.contains(studentClass) ??
                            false)) {
                          return const DataCell(
                              Text('0.0')); // Default arrear value
                        }

                        // Calculate arrears only if the class is associated
                        final purposeAmount =
                            _paymentPurposeAmounts[purposeOnly] ?? 0.0;
                        final matchingAmount = entry.value.entries
                                .firstWhere(
                                  (e) =>
                                      e.key.toLowerCase() ==
                                      purposeOnly.toLowerCase(),
                                  orElse: () => const MapEntry('', 0.0),
                                )
                                .value ??
                            0.0;

                        final arrears = matchingAmount - purposeAmount;
                        totalArrears += arrears;
                        return DataCell(Text('$arrears'));
                      }).toList();

                      return DataRow(
                        cells: [
                          DataCell(Text(studentName)),
                          DataCell(Text(_filteredPayments
                              .firstWhere((payment) =>
                                  '${payment.studentName} ${payment.studentSurname}' ==
                                  studentName)
                              .studentClass)),
                          ..._selectedPaymentPurposes.map((purpose) {
                            return DataCell(Text(
                              '${entry.value[purpose] ?? 0.0}',
                            ));
                          }),
                          DataCell(Text('$totalPaidAmount')),
                          ...arrearsCells,
                          DataCell(Text('$totalArrears')),
                        ],
                      );
                    }).toList(),

                    // Grand Totals Row
                    DataRow(
                      cells: [
                        DataCell(Container(
                          color: const Color.fromARGB(255, 52, 52, 255),
                          padding: const EdgeInsets.all(8.0),
                          child: const Text(
                            'GRAND TOTALS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )),
                        DataCell(Container()), // Empty cell for student class
                        ..._selectedPaymentPurposes.map((purpose) {
                          return DataCell(Container(
                            color: Colors.greenAccent,
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${grandTotalPurposePaid[purpose] ?? 0.0}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ));
                        }),
                        DataCell(Container(
                          padding: const EdgeInsets.all(8.0),
                          color: const Color.fromARGB(255, 13, 244, 244),
                          child: Text(
                            '$grandTotalPaid',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )),
                        ..._paymentPurposesOnly.map((purposeOnly) {
                          return DataCell(Container(
                            color: const Color.fromARGB(255, 246, 55, 2),
                            padding: const EdgeInsets.all(8.0),
                            child: const Text(
                              '*',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ));
                        }),
                        DataCell(Container(
                          padding: const EdgeInsets.all(8.0),
                          color: const Color.fromARGB(255, 248, 151, 4),
                          child: const Text(
                            '*',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating arrow buttons for scrolling horizontally (Sticky at the bottom)
        Positioned(
          bottom: 50, // Position the arrows at the bottom
          left: 60,
          right: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left arrow button to scroll left
              FloatingActionButton(
                onPressed: _scrollLeft,
                child: const Icon(Icons.arrow_back),
                mini: true,
                backgroundColor: Colors.blue,
              ),
              // Right arrow button to scroll right
              FloatingActionButton(
                onPressed: _scrollRight,
                child: const Icon(Icons.arrow_forward),
                mini: true,
                backgroundColor: Colors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void generateAndSaveSpreadsheet() async {
    // Create an Excel document
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Payments'];

    // Add the headers
    // Add the headers
    List<CellValue?> headers = [
      TextCellValue('STUDENT NAME'),
      TextCellValue('STUDENT CLASS'),
      ..._selectedPaymentPurposes
          .map((purpose) => TextCellValue('$purpose PAID(\$)')),
      TextCellValue('TOTAL PAID'),
      ..._paymentPurposesOnly
          .map((purposeOnly) => TextCellValue('$purposeOnly ARREARS (\$)')),
      TextCellValue('TOTAL ARREARS'),
    ];
    sheetObject.appendRow(headers);

    // Add the data rows
    for (var entry in groupedPayments.entries) {
      final studentName = entry.key;
      final studentClass = _filteredPayments
          .firstWhere((payment) =>
              '${payment.studentName} ${payment.studentSurname}' == studentName)
          .studentClass;
      final totalPaidAmount =
          totalPaid[studentName]?.values.reduce((a, b) => a + b) ?? 0.0;
      double totalArrears = 0.0;

      // Calculate arrears per payment purpose
      final arrearsCells = _paymentPurposesOnly.map((purposeOnly) {
        final purposeAmount = _paymentPurposeAmounts[purposeOnly] ?? 0.0;
        final matchingAmount = entry.value.entries
                .firstWhere(
                  (e) => e.key.toLowerCase() == purposeOnly.toLowerCase(),
                  orElse: () => const MapEntry('', 0.0),
                )
                .value ??
            0.0;
        final arrears = matchingAmount - purposeAmount;
        totalArrears += arrears;
        return arrears.toStringAsFixed(2); // Format as a string
      }).toList();

      // Append the row
      sheetObject.appendRow([
        TextCellValue(studentName),
        TextCellValue(studentClass),
        ..._selectedPaymentPurposes.map((purpose) {
          final amount = entry.value[purpose]?.toStringAsFixed(2) ?? '0.00';
          return TextCellValue(amount);
        }),
        TextCellValue(totalPaidAmount.toStringAsFixed(2)),
        ...arrearsCells.map((arrear) => TextCellValue(arrear)),
        TextCellValue(totalArrears.toStringAsFixed(2)),
      ]);
    }

    // Initialize variables to store totals
    Map<String, double> grandTotalPurposePaid = {};
    double grandTotalPaid = 0.0;

// Calculate totals for each purpose
    for (var purpose in _selectedPaymentPurposes) {
      // Sum up the payments for the current purpose
      double totalForPurpose =
          groupedPayments.values.fold(0.0, (sum, payments) {
        return sum + (payments[purpose] ?? 0.0);
      });

      // Store the total for this purpose
      grandTotalPurposePaid[purpose] = totalForPurpose;

      // Add to the grand total
      grandTotalPaid += totalForPurpose;
    }

    sheetObject.appendRow([
      TextCellValue('GRAND TOTALS'),
      TextCellValue(''), // Empty cell for student class
      ..._selectedPaymentPurposes.map((purpose) {
        // Fetch the total for the current purpose
        final total =
            grandTotalPurposePaid[purpose]?.toStringAsFixed(2) ?? '0.00';
        return TextCellValue(total);
      }),
      // Add the grand total
      TextCellValue(grandTotalPaid.toStringAsFixed(2)),
      ..._paymentPurposesOnly.map((purposeOnly) {
        // Placeholder for arrears
        return TextCellValue('*');
      }),
      // Placeholder for total arrears
      TextCellValue('*'),
    ]);

    // Save the Excel file
    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    // Save the file locally
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/payments_report.xlsx');
    await file.writeAsBytes(fileBytes);

    // Notify the user
    print('Spreadsheet saved: ${file.path}');

    // Use FilePicker to choose save location
    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        fileName: 'Student_Payments.xlsx',
      );

      if (savePath != null) {
        // Write the file
        File(savePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(excel.encode()!);

        print('Spreadsheet saved at: $savePath');
      } else {
        print('File save operation was canceled.');
      }
    } catch (e) {
      print('Error saving spreadsheet: $e');
    }
  }
}
