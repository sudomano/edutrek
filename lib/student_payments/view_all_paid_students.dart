import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // For PDF preview
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/all_payments/filter_payments.dart';
import 'package:zitf_system/arrears_and_prepayments/arrears_and_prepayments.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart'; // To handle file name extensions

class ViewAllStudentPayments extends StatefulWidget {
  const ViewAllStudentPayments({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ViewAllStudentPayments> {
  String? _selectedStudent;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSortAscending = true;
  bool _isLoading = false; // Loading state

  List<String> _selectedClasses = [];
  List<String> _selectedPaymentPurposes = [];

  List<String> _classes = [];
  List<String> _purposes = [];

  List<StudentPayment> _filteredPayments = [];
  // ignore: unused_field
  List<String> _students = [];
  List<String> _paymentPurposes = [];
  List<String> _selectedTermIds = [];
  List<String> _termIds = [];

  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;

  List<StudentPayment>? _cachedFilteredStudents;
  final paymentBoxes = Hive.box<StudentPayment>('student_payments');
  List<School>? _cachedServerSchoolInfo;

  @override
  void initState() {
    super.initState();
    if (_termIds.isNotEmpty) {
      _selectedTermIds = List<String>.from(_termIds); // ✅ DEFAULT: ALL
    } else {
      _selectedTermIds = [];
    }
    _fetchInitialData();
    _initialize();
    fetchSchools();
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Manipulation Feedback"),
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

  Future<void> _initialize() async {
    _role = await getDeviceRole();

    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (_role == DeviceRole.host) {
      final payments = await _fetchStudentPaymentFromHive(); // <- Wait for Hive
      setState(() {
        _StudentPaymentFuture = Future.value(payments);
      });
    } else {
      final payments =
          await _fetchStudentPaymentFromServer(); // <- Wait for Hive

      setState(() {
        _StudentPaymentFuture = Future.value(payments); // <- Server method
      });
    }
  }

  Future<List<StudentPayment>> _fetchStudentPaymentFromHive() async {
    final payments = paymentBoxes.values.toList();

    final terms = payments.map((e) => e.termId).whereType<String>().toSet();
    _termIds = terms.toList()..sort();

    return payments;
  }

  Future<List<StudentPayment>> _fetchStudentPaymentFromServer() async {
    if (_hostIp!.isEmpty) {
      debugPrint("Host IP is null, cannot fetch from server");
      if (mounted) {
        _showDialog("⚠️ Host IP not set. Please configure connection.");
      }
      return [];
    }

    try {
      final url = Uri.parse('http://$_hostIp:8080/api/studentPayments');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;

        // Convert JSON to List<PaymentPurpose>
        final payments = jsonList
            .map((json) =>
                studentPaymentsFromJson(Map<String, dynamic>.from(json)))
            .toList();

        // Extract and update _termIds
        final terms = payments.map((e) => e.termId).whereType<String>().toSet();
        _termIds = terms.toList()..sort();

        return payments;
      } else {
        throw Exception('Failed to load  payments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching  payments: $e");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDialog("⚠️ Failed to fetch  payments from server.");
        }
      });
      return [];
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      List<StudentPayment> allStudentPayments = [];
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termBox = await Hive.openBox<Terms>('terms');

        allStudentPayments = paymentBoxes.values.toList();
        allTerms = termBox.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() => _isLoading = false);
          return;
        }
        if (_cachedServerTerms == null ||
            _cachedServerStudentPayments == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());
          final studentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200 &&
              studentsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();
            final studentPaymentsJsonString =
                await studentsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;
            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms or students data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
        allStudentPayments = _cachedServerStudentPayments!;
      }

      _termIds = allTerms.map((e) => e.termId.toString()).toSet().toList();

      if (_termIds.isNotEmpty) {
        // ✅ Default → select ALL terms
        _selectedTermIds = List<String>.from(_termIds);
      }

      // Filter payments by globalTermId
      final filteredPayments = allStudentPayments
          .where((payment) => _selectedTermIds.contains(payment.termId))
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

      // Sort students by surname
      filteredPayments.sort((a, b) => _isSortAscending
          ? a.studentSurname.compareTo(b.studentSurname)
          : b.studentSurname.compareTo(a.studentSurname));

      setState(() {
        _isLoading = false; // Stop loading
      });
    } catch (error) {
      print("Error fetching initial data: $error");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterPayments(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<void> _filterPayments() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    try {
      List<StudentPayment> allStudentPayments;

      if (_role == DeviceRole.host) {
        allStudentPayments = paymentBoxes.values
            .where(
                (s) => s.termId != null && _selectedTermIds.contains(s.termId))
            .toList();
      } else {
        // Use previously fetched server data
        allStudentPayments = await _StudentPaymentFuture;
        allStudentPayments = allStudentPayments
            .where(
                (s) => s.termId != null && _selectedTermIds.contains(s.termId))
            .toList();
      }

      List<StudentPayment> filteredPayments = allStudentPayments;
// If surname is not empty, apply from the list of selected terms filter
      final appiedTermsFilter =
          _selectedStudent != null && _selectedStudent!.trim().isNotEmpty;

      if (!appiedTermsFilter && _selectedTermIds.isEmpty) {
        filteredPayments = filteredPayments
            .where(
                (s) => s.termId != null && _selectedTermIds.contains(s.termId))
            .toList();
      }
      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
        filteredPayments = filteredPayments.where((payment) {
          return _selectedClasses.contains(payment.studentClass);
        }).toList();
      }

      if (_selectedStudent != null && _selectedStudent!.isNotEmpty) {
        filteredPayments = filteredPayments
            .where((payment) => payment.studentSurname
                .toLowerCase()
                .contains(_selectedStudent!.toLowerCase()))
            .toList();
      }

      if (_selectedPaymentPurposes.isNotEmpty &&
          !_selectedPaymentPurposes.contains("All")) {
        filteredPayments = filteredPayments.where((payment) {
          return _selectedPaymentPurposes.contains(payment.paymentPurpose);
        }).toList();
      }

      if (_selectedStartDate != null || _selectedEndDate != null) {
        filteredPayments = filteredPayments.where((payment) {
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
      // Sort by surname first, then by payment date
      _filteredPayments.sort((a, b) {
        final surnameCompare = _isSortAscending
            ? a.studentSurname.compareTo(b.studentSurname)
            : b.studentSurname.compareTo(a.studentSurname);

        if (surnameCompare != 0) return surnameCompare;

        // Within same student, sort by payment date descending
        return b.paymentDate.compareTo(a.paymentDate);
      });

      setState(() {
        _isLoading = false; // Stop loading
        _filteredPayments = filteredPayments;
        _cachedFilteredStudents = filteredPayments;
      });
    } catch (error) {
      debugPrint("Error during filtering: $error");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<School> _getSchoolInfo() async {
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (role == DeviceRole.host) {
      final schoolBox = await Hive.openBox<School>('school');
      if (schoolBox.isNotEmpty) {
        return schoolBox.values.first;
      }
    } else {
      if (_cachedServerSchoolInfo == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/school'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonStr) as List;
          _cachedServerSchoolInfo = jsonList
              .map((e) => schoolFromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          throw Exception("❌ Failed to fetch school data from host.");
        }
      }

      if (_cachedServerSchoolInfo != null &&
          _cachedServerSchoolInfo!.isNotEmpty) {
        return _cachedServerSchoolInfo!.first;
      }
    }

    // Fallback default
    return School(
      schoolName: 'School Receipt',
      schoolAddress: 'P.O.Box...',
      schoolEmail: '@school.co.zw',
      schoolPhoneNumber: '+263...',
    );
  }

  Future<Uint8List> generateStudentsPDF(
    List<StudentPayment> studentPayments,
  ) async {
    final pdf = pw.Document();

    final headers = [
      'Receipt',
      'Payment Purpose',
      'Amount',
      'Payment Date',
      'Term',
      'Made By',
    ];

    // Fetch school info
    final School schoolInfo = await _getSchoolInfo();

    // Prepare logo if exists
    pw.MemoryImage? logoImage;
    if (schoolInfo.schoolLogoPath != null &&
        File(schoolInfo.schoolLogoPath!).existsSync()) {
      logoImage = pw.MemoryImage(
        File(schoolInfo.schoolLogoPath!).readAsBytesSync(),
      );
    }

    // Group payments per student
    final Map<String, List<StudentPayment>> groupedPayments = {};
    for (final p in studentPayments) {
      final key = "${p.studentName}_${p.studentSurname}_${p.studentClass}";
      groupedPayments.putIfAbsent(key, () => []).add(p);
    }

    /// ✅ HEADER builder → Will repeat on EVERY page
    pw.Widget buildHeader() {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoImage != null)
            pw.Container(
              width: 80,
              height: 80,
              child: pw.Image(logoImage!),
            )
          else
            pw.Container(
              width: 80,
              height: 80,
              child: pw.Text("NO LOGO"),
            ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  schoolInfo.schoolName!.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.right,
                ),
                if (schoolInfo.schoolAddress != null)
                  pw.Text(
                    schoolInfo.schoolAddress!.toUpperCase(),
                    textAlign: pw.TextAlign.right,
                  ),
                pw.Text(
                  "Email: ${schoolInfo.schoolEmail ?? ''}",
                  textAlign: pw.TextAlign.right,
                ),
                pw.Text(
                  "Phone: ${schoolInfo.schoolPhoneNumber ?? ''}",
                  textAlign: pw.TextAlign.right,
                ),
              ],
            ),
          )
        ],
      );
    }

    /// ✅ FOOTER builder: page numbers + footer text
    pw.Widget buildFooter(pw.Context context) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "${schoolInfo.schoolName!.toLowerCase()} computer-generated document.",
            style: pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            "Page ${context.pageNumber} / ${context.pagesCount}",
            style: pw.TextStyle(fontSize: 8),
          ),
        ],
      );
    }

    final monthMap = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

// Sort terms by year → term → month
    final termRegex =
        RegExp(r'(\d{4})\s+Term\s+(\d+)\s*\((\w+)\)', caseSensitive: false);

    // For SUMMARIES
    double globalTotal = 0.0;
    final List<Map<String, dynamic>> miniSummary = [];

    for (final entry in groupedPayments.entries) {
      final studentItems = entry.value;

      /// Compute subtotal
      final studentSubtotal = studentItems.fold<double>(
          0.0, (sum, p) => sum + (p.amountToPay ?? 0));

      globalTotal += studentSubtotal;

      miniSummary.add({
        "name":
            "${studentItems.first.studentName} ${studentItems.first.studentSurname}",
        "subtotal": studentSubtotal,
      });

      final List<List<String>> tableData = studentItems.map((p) {
        return [
          p.id.toString(),
          p.paymentPurpose,
          (p.amountToPay ?? 0).toStringAsFixed(2),
          DateFormat("yyyy-MM-dd").format(p.paymentDate),
          p.termId ?? "",
          p.username ?? "",
        ];
      }).toList();

      /// Add subtotal row
      tableData.add([
        "",
        "Subtotal",
        studentSubtotal.toStringAsFixed(2),
        "",
        "",
        "",
      ]);

      // --- Selected terms display
      final List<String> studentTermsDisplayList = _selectedTermIds.toList();

      studentTermsDisplayList.sort((a, b) {
        final matchA = termRegex.firstMatch(a);
        final matchB = termRegex.firstMatch(b);
        if (matchA == null || matchB == null) return a.compareTo(b);

        final yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
        final yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
        final termA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
        final termB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
        final monthA = monthMap[(matchA.group(3) ?? '').toLowerCase()] ?? 0;
        final monthB = monthMap[(matchB.group(3) ?? '').toLowerCase()] ?? 0;

        if (yearA != yearB) return yearA.compareTo(yearB);
        if (termA != termB) return termA.compareTo(termB);
        return monthA.compareTo(monthB);
      });

      final String selectedTermsDisplay = studentTermsDisplayList.join(', ');
      final String pdfCreationDate =
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => buildHeader(),
          footer: (context) => buildFooter(context),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  "STUDENT STATEMENT",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: pw.Text(
                  "Generated On",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: pw.Text(
                  pdfCreationDate,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),

              /// STUDENT INFO
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      "${studentItems.first.studentName.toUpperCase()} "
                      "${studentItems.first.studentSurname.toUpperCase()}",
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      "Class: ${studentItems.first.studentClass.toUpperCase()}",
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: pw.Text(
                        "COMPILED FOR TERMS:",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: pw.Text(
                        selectedTermsDisplay.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              /// PAYMENT TABLE
              pw.Table.fromTextArray(
                headers: headers,
                data: tableData,
                border: pw.TableBorder.all(color: PdfColors.black),
                cellStyle: pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1),
                },
              ),

              pw.SizedBox(height: 24),

              /// SIGNATURE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Container(height: 1, width: 120, color: PdfColors.black),
                    pw.Text("Accounts Clerk"),
                  ]),
                  pw.Column(children: [
                    pw.Container(height: 1, width: 120, color: PdfColors.black),
                    pw.Text("Headmaster"),
                  ]),
                ],
              )
            ];
          },
        ),
      );
    }

    // ✅ FINAL SUMMARY PAGE
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (ctx) => buildHeader(),
        footer: (ctx) => buildFooter(ctx),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                "SUMMARY REPORT",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ["Student", "Subtotal"],
              data: miniSummary.map((e) {
                return [
                  e["name"],
                  e["subtotal"].toStringAsFixed(2),
                ];
              }).toList(),
              cellStyle: pw.TextStyle(fontSize: 10),
              headerStyle:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "GRAND TOTAL: \$${globalTotal.toStringAsFixed(2)}",
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Add a page per student

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
            _showDialog("Download directory created.");
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
          _showDialog("PDF saved to $filePath");
        } else {
          // Show error notification
          _showDialog("Error: External storage directory not found.");
        }
      } else {
        // Show permission denied notification
        _showDialog("Permission denied for storage access.");
      }
    } catch (e) {
      // Show error notification
      _showDialog("Error saving PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'View Student Payments By',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          Tooltip(
            message: 'View detailed payments',
            child: IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color.fromARGB(255, 0, 255, 81),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewByScreen(),
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: 'View detailed arrear',
            child: IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color.fromARGB(255, 255, 0, 0),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ArrearsAndPrepayments(),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              final studentsToExport =
                  _cachedFilteredStudents ?? _filteredPayments;

              Uint8List pdfBytes = await generateStudentsPDF(studentsToExport);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(
                    context, pdfBytes, 'student_payment_receipts_report');
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCard(
                          title: 'Select Term',
                          child: _buildTermMultiSelect(),
                        ),
                        _buildCard(
                          title: 'View by Class',
                          child: _buildClassDropdown(),
                        ),
                        const SizedBox(height: 20),
                        _buildCard(
                          title: 'Search by Student Name',
                          child: _buildSearchStudentField(),
                        ),
                        const SizedBox(height: 20),
                        _buildCard(
                          title: 'Filter by Payment Purpose',
                          child: _buildPaymentPurposeDropdown(),
                        ),
                        const SizedBox(height: 20),
                        _buildCard(
                          title: 'Filter by Payment Period',
                          child: _buildSearchPaymentPeriod(),
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
                              textStyle: const TextStyle(
                                  fontSize: 18), // Button background color
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
                  Container(
                    child: _filteredPayments.isEmpty
                        ? const Center(
                            child: Text(
                              'No payments found.',
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                          )
                        : _buildPaymentsTable(),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildTermMultiSelect() {
    return MultiSelectChip(
      items: _termIds,
      initialSelectedItems: _selectedTermIds,
      onSelectionChanged: (selected) async {
        await _onTermChanged(selected);
      },
    );
  }

  Future<void> _onTermChanged(List<String> newSelected) async {
    if (newSelected.isEmpty) {
      // Optional: prevent empty state → auto reselect all
      newSelected = List<String>.from(_termIds);
    }

    setState(() {
      _isLoading = true;
      _selectedTermIds = newSelected;

      // ✅ EXACT RESET BEHAVIOR FROM OLD CODE
      _selectedClasses = ['All'];
      _selectedPaymentPurposes = ['All'];
      _selectedStudent = '';
      _selectedStartDate = null;
      _selectedEndDate = null;
      _filteredPayments = [];
    });

    try {
      List<StudentPayment> allStudentPayments = [];

      // ✅ SAME HOST / CLIENT LOGIC FROM OLD CODE
      if (_role == DeviceRole.host) {
        allStudentPayments = paymentBoxes.values
            .where(
              (s) => s.termId != null && newSelected.contains(s.termId),
            )
            .toList();
      } else {
        // Previously loaded server Future
        allStudentPayments = await _StudentPaymentFuture;
        allStudentPayments = allStudentPayments
            .where(
              (s) => s.termId != null && newSelected.contains(s.termId),
            )
            .toList();
      }

      final termPayments = allStudentPayments;

      // ✅ Rebuild classes
      _classes = ['All'];
      _classes.addAll(
        termPayments.map((p) => p.studentClass).toSet().toList(),
      );

      // ✅ Rebuild purposes
      _purposes = ['All'];
      _purposes.addAll(
        termPayments.map((p) => p.paymentPurpose).toSet().toList(),
      );
    } catch (e) {
      debugPrint("Error during term filter: $e");
    }

    setState(() {
      _isLoading = false;
    });
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
        labelText: 'Search Student by Surame',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Payment Period:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context, true),
                child: Text(_selectedStartDate != null
                    ? 'From: ${_selectedStartDate!.toLocal()}'.split(' ')[0]
                    : 'From: Select Start Date'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context, false),
                child: Text(_selectedEndDate != null
                    ? 'To: ${_selectedEndDate!.toLocal()}'.split(' ')[0]
                    : 'To: Select End Date'),
              ),
            ),
          ],
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
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Widget _buildPaymentsTable() {
    // Group payments by unique student key
    final Map<String, List<StudentPayment>> groupedPayments = {};

    for (final payment in _filteredPayments) {
      final key =
          '${payment.studentName.toLowerCase()}_${payment.studentSurname.toLowerCase()}_${payment.studentClass.toLowerCase()}';
      groupedPayments.putIfAbsent(key, () => []).add(payment);
    }

    // Compute grand total
    final grandTotal = _filteredPayments.fold<double>(
      0.0,
      (sum, payment) => sum + (payment.amountToPay ?? 0),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: DataTable(
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Id')),
            DataColumn(label: Text('Student Name')),
            DataColumn(label: Text('Surname')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Payment Purpose')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Payment Date')),
            DataColumn(label: Text('Term')),
            DataColumn(label: Text('Made By')),
          ],
          rows: [
            for (final entry in groupedPayments.entries) ...[
              // Student Header
              DataRow(
                color: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) => Colors.blueGrey[50],
                ),
                cells: [
                  const DataCell(Text('')),
                  DataCell(Text(
                    entry.value.first.studentName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(Text(
                    entry.value.first.studentSurname.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(Text(
                    entry.value.first.studentClass.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ],
              ),

              // Student payment rows
              for (final payment in entry.value)
                DataRow(
                  cells: [
                    DataCell(Text(payment.id.toString())),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text(payment.paymentPurpose)),
                    DataCell(
                      Text(
                        payment.amountToPay?.toStringAsFixed(2) ?? '0.00',
                      ),
                    ),
                    DataCell(Text(payment.paymentDate.toString())),
                    DataCell(Text(payment.termId.toString())),
                    DataCell(Text(payment.role ?? '')),
                  ],
                ),

              // ✅ Subtotal Row for this student
              DataRow(
                color: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) => Colors.grey[200],
                ),
                cells: [
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(
                    Text(
                      'Subtotal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      entry.value
                          .fold<double>(
                            0.0,
                            (sum, p) => sum + (p.amountToPay ?? 0),
                          )
                          .toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ],
              )
            ],

            // ✅ Grand Total Row
            DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) => Colors.grey[300],
              ),
              cells: [
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(
                  Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    grandTotal.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void generateAndSaveSpreadsheet() async {
    // Create an Excel document
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Student Payment Receipts'];

    // Add the headers
    sheetObject.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Surname'),
      TextCellValue('Class'),
      TextCellValue('Payment Purpose'),
      TextCellValue('Amount'),
      TextCellValue('Payment Date'),
      TextCellValue('Term'),
      TextCellValue('Made By'),
    ]);

    // Add the data rows (wrap each value accordingly)
    for (var payment_info in _filteredPayments) {
      sheetObject.appendRow([
        IntCellValue(
            payment_info.id ?? 0), // Assuming payment_info.id is a number
        TextCellValue(payment_info.studentName),
        TextCellValue(payment_info.studentSurname),
        TextCellValue(payment_info.studentClass),
        TextCellValue(payment_info.paymentPurpose),
        TextCellValue(payment_info.amountToPay.toString()),

        TextCellValue(payment_info.paymentDate.toString()),
        TextCellValue(payment_info.termId ?? ''),
        TextCellValue(payment_info.username ?? ''),
      ]);
    }
    // Add total row
    sheetObject.appendRow([
      TextCellValue(''), // Id
      TextCellValue(''), // Name
      TextCellValue(''), // Surname
      TextCellValue(''), // Class
      TextCellValue('TOTAL'), // Purpose
      TextCellValue(_filteredPayments
          .fold<double>(
            0.0,
            (sum, p) => sum + (p.amountToPay ?? 0),
          )
          .toStringAsFixed(2)), // Total Amount
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    try {
      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception("Excel encoding failed.");

      if (Platform.isAndroid) {
        // Get app's scoped documents directory
        final directory = await getApplicationDocumentsDirectory();
        final folder = Directory(
            '${directory.path}/school_files/student_payment_receipts');

        // Create folder if not exists
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        // Generate unique file name with timestamp
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath =
            '${folder.path}/student_payment_receipts_$timestamp.xlsx';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        print('✅ Spreadsheet saved to: $filePath');
      } else {
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
    } catch (e) {
      print('Error saving spreadsheet: $e');
    }
  }
}
