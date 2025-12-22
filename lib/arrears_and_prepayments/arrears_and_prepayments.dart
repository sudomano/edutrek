import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/all_payments/filter_payments.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:path/path.dart' as path;
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart';
import 'package:zitf_system/student_payments/view_all_paid_students.dart'; // To handle file name extensions

class ArrearsAndPrepayments extends StatefulWidget {
  const ArrearsAndPrepayments({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ArrearsAndPrepayments> {
  String? _selectedStudent;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedSortOption = 'Surname'; // Default sort option
  bool _isSortAscending = true;

  List<StudentPayment> _filteredPayments = [];
  List<PaymentPurpose> filteredPaymentPurposesOnly = [];

  Map<String, double> _paymentPurposeAmounts = {};

  List<String> _selectedClasses = [];
  List<String> _selectedPaymentPurposes = [];
  String _selectedArrearFilter = 'All';
  double? _arrearMin;
  double? _arrearMax;

  List<String> _paymentPurposesOnly = [];
  List<String> _selectedPaymentPurposesArrears = [];

  List<String> _classes = [];
  List<String> _purposes = [];
  List<String> _purposesOnly = [];
  List<String> _terms = []; // Declare without 'final'

  // Maps for holding payment data
  Map<String, Map<String, double>> groupedPayments = {};
  Map<String, Map<String, double>> totalPaid = {};
  final TextEditingController _surnameController = TextEditingController();

  final TextEditingController _regNumberController = TextEditingController();
  late final ScrollController horizontalScrollController;
  late final ScrollController verticalScrollController;
  String normalize(String input) => input.trim().toLowerCase();
  Map<String, Terms> _termMap = {};
  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;

  List<StudentPayment>? _cachedFilteredStudents;

  Set<String> processedTerms = {};

  final Map<String, Map<String, double>> termTotalsByPurpose = {};
  final Map<String, double> termTotalsGrand = {};

  bool _showArrears = true;
  bool _showPayments = true;
  List<School>? _cachedServerSchoolInfo;
  Map<String, PaymentPurpose> _paymentPurposeMap = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
    fetchTerms();
    horizontalScrollController = ScrollController();
    verticalScrollController = ScrollController();
  }

  List<String> _selectedTermIds = [];

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Arrears Manipulation Feedback"),
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

  Future<void> fetchTerms() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termBox = await Hive.openBox<Terms>('terms');

        allTerms = termBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerTerms == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
      }

      if (allTerms.isNotEmpty) {
        _terms = allTerms.map((term) => term.termId).toSet().toList();
        _terms.sort();
      } else {
        _terms = [];
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

// Example of using currentTermId in a method
  void filterByTerm() {
    if (_selectedTermIds.isEmpty) return;

    _filteredPayments = _filteredPayments.where((payment) {
      return _selectedTermIds.contains(payment.termId);
    }).toList();

    setState(() {});
  }

  Future<void> _initializeData() async {
    await _fetchInitialData();
  }

  String _capitalizeEachWord(String input) {
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _fetchInitialData() async {
    try {
      debugPrint("🟨 Starting _fetchInitialData");

      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];
      List<PaymentPurpose> allStudentPaymentPurposes = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();

        final paymentPurposeBox =
            await Hive.openBox<PaymentPurpose>('payment_purposes');

        allStudentPaymentPurposes = paymentPurposeBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        debugPrint("🌐 Fetching from server (client) - Host IP: $_hostIp");

        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerStudentPayments == null) {
          final studentPaymentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (studentPaymentsResponse.statusCode == 200) {
            final studentPaymentsJsonString =
                await studentPaymentsResponse.transform(utf8.decoder).join();

            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load student Payments data from host.");
          }
        }
        if (_cachedServerStudentPaymentPurposes == null) {
          final studentPaymentPurposesResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
              .then((req) => req.close());

          if (studentPaymentPurposesResponse.statusCode == 200) {
            final studentPaymentPurposesJsonString =
                await studentPaymentPurposesResponse
                    .transform(utf8.decoder)
                    .join();

            final studentPaymentPurposesList =
                jsonDecode(studentPaymentPurposesJsonString) as List;

            _cachedServerStudentPaymentPurposes = studentPaymentPurposesList
                .map((json) =>
                    paymentPurposesFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load payment Purposes data from host.");
          }
        }
        allStudentPayments = _cachedServerStudentPayments!;
        allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
      }

      final selectedTerms = _selectedTermIds;

      List<StudentPayment> filteredPayments;
      List<PaymentPurpose> filteredPaymentPurposesOnly;

      if (selectedTerms.isEmpty) {
        // ✅ nothing selected → no term filter
        filteredPayments = allStudentPayments;
        filteredPaymentPurposesOnly = allStudentPaymentPurposes;
      } else {
        filteredPayments = allStudentPayments
            .where((p) => selectedTerms.contains(p.termId))
            .toList();

        filteredPaymentPurposesOnly = allStudentPaymentPurposes
            .where((p) => selectedTerms.contains(p.termId))
            .toList();
      }

      final classSet = filteredPayments
          .map((student) => student.studentClass.trim().toLowerCase())
          .toSet();

      _classes = ['All'];
      _classes.addAll(classSet.map((c) => _capitalizeEachWord(c)).toList());

      _selectedClasses = ['All']; // Default selection

      // Fetch unique payment purposes from filtered payments
      _purposes = ['All'];
      try {
        _purposes.addAll(filteredPayments
            .map((student) => student.paymentPurpose)
            .whereType<String>()
            .toSet()
            .toList());
      } catch (e) {
        debugPrint("❌ Error while populating _purposes: $e");
        rethrow;
      }
      _selectedPaymentPurposes = ['All']; // Default selection

      // Fetch unique classes from filtered payments
      _purposesOnly = ['All'];

      try {
        _purposesOnly.addAll(filteredPaymentPurposesOnly
            .map((student) => student.paymentPurpose)
            .whereType<String>()
            .toSet()
            .toList());
      } catch (e) {
        debugPrint("❌ Error while populating _purposesOnly: $e");
        rethrow;
      }
      _selectedPaymentPurposesArrears = ['All']; // Default selection

      // ✅ payment purpose → amount map
      _paymentPurposeAmounts.clear();
      for (var p in filteredPaymentPurposesOnly) {
        _paymentPurposeAmounts[p.paymentPurpose] = p.purposeAmount;
      }

      // Fetch payment purpose only amounts
      _filteredPayments = filteredPayments;
      // Sort students by surname
      _filteredPayments.sort((a, b) => _isSortAscending
          ? a.studentSurname.compareTo(b.studentSurname)
          : b.studentSurname.compareTo(a.studentSurname));

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterPayments(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<StudentPayment>('student_payments');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _filterPayments() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];
      List<Student> allStudents = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();

        final studentBox = await Hive.openBox<Student>('students');

        allStudents = studentBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerStudentPayments == null) {
          final studentPaymentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (studentPaymentsResponse.statusCode == 200) {
            final studentPaymentsJsonString =
                await studentPaymentsResponse.transform(utf8.decoder).join();

            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load student Payments data from host.");
          }
        }
        if (_cachedServerStudents == null) {
          final studentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/students'))
              .then((req) => req.close());

          if (studentsResponse.statusCode == 200) {
            final studentsString =
                await studentsResponse.transform(utf8.decoder).join();

            final studentsList = jsonDecode(studentsString) as List;

            _cachedServerStudents = studentsList
                .map(
                    (json) => studentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load students data from host.");
          }
        }
        allStudentPayments = _cachedServerStudentPayments!;
        allStudents = _cachedServerStudents!;
      }

      final selectedTerms = _selectedTermIds;

      List<StudentPayment> filteredPayments;
      List<Student> filteredStudents;

      if (selectedTerms.isEmpty) {
        // ✅ no selection → do not term filter
        filteredPayments = allStudentPayments;
        filteredStudents = allStudents;
      } else {
        filteredPayments = allStudentPayments
            .where((p) => selectedTerms.contains(p.termId))
            .toList();

        filteredStudents = allStudents
            .where((s) => s.terms!.any((t) => selectedTerms.contains(t)))
            .toList();
      }
      // Build paymentRecords for matching only selectedTerms
      List<StudentPayment> paymentRecords = filteredPayments;

      // Build student list, apply class filter
      List<Student> studentRecords = filteredStudents;

// Build student list, apply class filter

      if (_selectedClasses.isNotEmpty &&
          !_selectedClasses.any((c) => c.toLowerCase() == 'all')) {
        final classKeys = _selectedClasses.map((c) => c.toLowerCase()).toSet();

        studentRecords = studentRecords.where((s) {
          return classKeys.contains(s.class_.trim().toLowerCase());
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ MERGE — ensure every student has at least 1 record
      //-----------------------------------------------------

      List<StudentPayment> combined = [];

      for (var student in studentRecords) {
        final payments = paymentRecords.where((p) =>
            p.studentName.toLowerCase() == student.name.toLowerCase() &&
            p.studentSurname.toLowerCase() == student.surname.toLowerCase() &&
            p.studentClass.trim().toLowerCase() ==
                student.class_.trim().toLowerCase());

        if (payments.isEmpty) {
          // ✅ create virtual record
          int newId = await getNextId();
          String receipt = uuid.v4();

          combined.add(
            StudentPayment(
              id: newId,
              receiptNumber: receipt,
              studentName: student.name,
              studentSurname: student.surname,
              studentClass: student.class_,
              termId: selectedTerms.isNotEmpty ? selectedTerms.first : null,
              phoneNumber: student.phoneNumber,
              paymentPurpose: '',
              amountToPay: 0.0,
              paymentDate: DateTime.now(),
              syncStatus: false,
              lastModified: DateTime.now(),
              operationType: 'create',
              modifiedFields: [
                'id',
                'receiptNumber',
                'studentName',
                'studentSurname',
                'studentClass',
                'phoneNumber',
                'paymentPurpose',
                'amountToPay',
                'paymentDate',
                'termId',
              ],
            ),
          );
        } else {
          combined.addAll(payments);
        }
      }

      // Now, _filteredPayments contains students even if they have no payment.
      _filteredPayments = combined;

      //-----------------------------------------------------
      // ✅ SEARCH FILTER
      //-----------------------------------------------------
      if (_selectedStudent != null && _selectedStudent!.trim().isNotEmpty) {
        final query = _selectedStudent!.trim().toLowerCase();
        _filteredPayments = _filteredPayments.where((p) {
          final full = '${p.studentName} ${p.studentSurname}'.toLowerCase();
          return full.contains(query);
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ PURPOSE FILTER
      //-----------------------------------------------------
      if (_selectedPaymentPurposes.isNotEmpty &&
          !_selectedPaymentPurposes.contains("All")) {
        _filteredPayments = _filteredPayments.where((p) {
          return _selectedPaymentPurposes.contains(p.paymentPurpose);
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ DATE FILTER
      //-----------------------------------------------------
      if (_selectedStartDate != null || _selectedEndDate != null) {
        _filteredPayments = _filteredPayments.where((p) {
          final d = p.paymentDate;
          if (_selectedStartDate != null && _selectedEndDate != null) {
            return d.isAfter(_selectedStartDate!) &&
                d.isBefore(_selectedEndDate!);
          } else if (_selectedStartDate != null) {
            return d.isAfter(_selectedStartDate!);
          } else if (_selectedEndDate != null) {
            return d.isBefore(_selectedEndDate!);
          }
          return true;
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ SORT
      //-----------------------------------------------------
      if (_selectedSortOption == 'Surname') {
        _filteredPayments.sort((a, b) => a.studentSurname
            .toLowerCase()
            .compareTo(b.studentSurname.toLowerCase()));
      } else if (_selectedSortOption == 'First Name') {
        _filteredPayments.sort((a, b) =>
            a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));
      }

      //-----------------------------------------------------
      // ✅ GROUP + TOTALS
      //-----------------------------------------------------
      _calculateGroupedPayments();
      _calculateTotalPaid();
      _calculateTermTotals(); // ✅ add this

      setState(() {});
    } catch (e) {
      debugPrint("❌ Error filtering payments: $e");
      setState(() {});
    }
  }

  void _calculateGroupedPayments() {
    groupedPayments.clear();
    for (var payment in _filteredPayments) {
      final studentName =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final paymentPurposeKey = payment.paymentPurpose.toLowerCase();
      final amountToPay = payment.amountToPay.toDouble();
      groupedPayments.putIfAbsent(studentName, () => {});
      groupedPayments[studentName]!.putIfAbsent(paymentPurposeKey, () => 0.0);

      groupedPayments[studentName]![paymentPurposeKey] =
          (groupedPayments[studentName]![paymentPurposeKey] ?? 0.0) +
              amountToPay;
    }
  }

  void _calculateTotalPaid() {
    totalPaid.clear();
    for (var payment in _filteredPayments) {
      final studentName =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final paymentPurposeKey = payment.paymentPurpose.toLowerCase();
      final amountPaid = payment.amountToPay.toDouble();
      totalPaid.putIfAbsent(studentName, () => {});
      totalPaid[studentName]!.putIfAbsent(paymentPurposeKey, () => 0.0);

      totalPaid[studentName]![paymentPurposeKey] =
          (totalPaid[studentName]![paymentPurposeKey] ?? 0.0) + amountPaid;
    }
  }

  void _calculateTermTotals() {
    termTotalsByPurpose.clear();
    termTotalsGrand.clear();

    for (var p in _filteredPayments) {
      final term = (p.termId ?? "").trim().toLowerCase();
      if (term.isEmpty) continue;

      final purpose = (p.paymentPurpose ?? "").trim().toLowerCase();
      final amount = (p.amountToPay ?? 0.0);

      // Purpose per term
      termTotalsByPurpose.putIfAbsent(term, () => {});
      termTotalsByPurpose[term]!.putIfAbsent(purpose, () => 0.0);
      termTotalsByPurpose[term]![purpose] =
          (termTotalsByPurpose[term]![purpose] ?? 0.0) + amount;

      // Term grand total
      termTotalsGrand[term] = (termTotalsGrand[term] ?? 0.0) + amount;
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

// ----------------------------
// AppBar PDF Button
// ----------------------------
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
          'Arrears And Payments',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          Tooltip(
            message: 'View Payment Receipts',
            child: IconButton(
              icon: const Icon(
                Icons.payment_outlined,
                color: Color.fromARGB(255, 242, 255, 0),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewAllStudentPayments(),
                  ),
                );
              },
            ),
          ),
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
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              try {
                // Generate the payments PDF document
                final pdfDocument = await generatePaymentsPDF();

                // Convert to bytes
                final pdfBytes = await pdfDocument.save();

                // Preview PDF (Uint8List)
                final bool confirmSave =
                    await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

                if (confirmSave) {
                  await savePDFToFile(
                      context, pdfBytes, 'student_payments_report');
                }
              } catch (e) {
                _showDialog("Error generating PDF: $e");
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
                    title: 'Select Term(s)',
                    child: InkWell(
                      onTap: () async {
                        final selected = await showDialog<List<String>>(
                          context: context,
                          builder: (context) {
                            final temp =
                                List<String>.from(_selectedTermIds ?? []);

                            return StatefulBuilder(
                              builder: (context, setStateLocal) {
                                return AlertDialog(
                                  title: const Text("Select Terms"),
                                  content: SizedBox(
                                    width: 300,
                                    height: 400,
                                    child: ListView(
                                      children: _terms.map((term) {
                                        return CheckboxListTile(
                                          title: Text(term),
                                          value: temp.contains(term),
                                          onChanged: (val) {
                                            if (val == true) {
                                              temp.add(term);
                                            } else {
                                              temp.remove(term);
                                            }

                                            // ✅ triggers UI refresh
                                            setStateLocal(() {});
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"),
                                      onPressed: () =>
                                          Navigator.pop(context, null),
                                    ),
                                    ElevatedButton(
                                      child: const Text("OK"),
                                      onPressed: () =>
                                          Navigator.pop(context, temp),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                        String?
                            selectedTermId; // This will store the term ID selected by the user.
                        String? getCurrentTermId() {
                          return selectedTermId ?? globalTermId;
                        }

                        if (selected != null) {
                          setState(() {
                            _selectedTermIds = selected;
                            selectedTermId = null;
                            _selectedClasses = ['All'];
                            _selectedPaymentPurposes = ['All'];
                            _selectedStudent = '';
                            _selectedStartDate = null;
                            _selectedEndDate = null;
                            _surnameController.clear();
                            _filteredPayments = [];
                          });

                          await Future.delayed(Duration.zero);
                          await _fetchInitialData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          //border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (_selectedTermIds == null ||
                                  _selectedTermIds!.isEmpty)
                              ? "Select Terms"
                              : _selectedTermIds!.join(", "),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  _buildCard(
                    title: 'View by Class',
                    child: _buildClassDropdown(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Student Surname',
                    child: _buildSearchStudentField(),
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    value: _selectedArrearFilter,
                    items: const [
                      DropdownMenuItem(
                          value: 'All', child: Text('All Students')),
                      DropdownMenuItem(
                          value: 'Arrears Only', child: Text('Arrears Only')),
                      DropdownMenuItem(
                          value: 'Fully Paid', child: Text('Fully Paid')),
                      DropdownMenuItem(
                          value: 'Overpaid / Credit',
                          child: Text('Overpaid / Credit')),
                      DropdownMenuItem(
                          value: 'Custom Range', child: Text('Custom Range')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedArrearFilter = value!;
                        if (value != 'Custom Range') {
                          _arrearMin = null;
                          _arrearMax = null;
                        }
                      });
                    },
                  ),
                  if (_selectedArrearFilter == 'Custom Range') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            decoration:
                                const InputDecoration(labelText: 'Min Arrear'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _arrearMin = double.tryParse(value);
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            decoration:
                                const InputDecoration(labelText: 'Max Arrear'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _arrearMax = double.tryParse(value);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  Row(
                    children: [
                      Checkbox(
                        value: _showArrears,
                        onChanged: (value) {
                          setState(() => _showArrears = value ?? true);
                        },
                      ),
                      const Text("Show Arrears"),
                      const SizedBox(width: 20),
                      Checkbox(
                        value: _showPayments,
                        onChanged: (value) {
                          setState(() => _showPayments = value ?? true);
                        },
                      ),
                      const Text("Show Payments"),
                    ],
                  ),
                  Text(
                    'Records Found: ${_filteredPayments.map((e) => '${e.studentName} ${e.studentSurname}').toSet().length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_filteredPayments.isEmpty) ...[
              const Center(
                child: Text(
                  'No payments found.',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ] else ...[
              _buildPaymentsTable(),
            ],
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
          if (selectedClasses.contains("All")) {
            _selectedClasses = []; // ✅ treat as ALL
          } else {
            _selectedClasses = selectedClasses;
          }
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
      controller: _surnameController,
      decoration: InputDecoration(
        labelText: 'Search Student by Surname',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {});
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

  bool isNewcomerEligible(
    Student student,
    PaymentPurpose purpose,
    Terms? term,
  ) {
    if (student.isNewComer != true ||
        student.isNewComerUntil == null ||
        student.isNewComerFrom == null) {
      return false;
    }

    if (purpose.forNewcomersOnly != true) {
      return true;
    }

    final newcomerUntil = student.isNewComerUntil!;
    final newcomerFrom = student.isNewComerFrom!;

    if (term != null && term.endDate != null) {
      if (term.startDate.isAfter(newcomerUntil) ||
          term.endDate!.isBefore(newcomerFrom)) {
        return false;
      } else {
        return true;
      }
    } else if (term != null && term.startDate != null) {
      if (term.startDate.isAfter(newcomerUntil)) {
        return false;
      } else {
        return true;
      }
    }

    if (purpose.lastModified != null) {
      if (purpose.lastModified!.isAfter(newcomerUntil)) {
        return false;
      }
    }

    return true;
  }

  Widget _buildPaymentsTable() {
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();
    const double scrollIncrement = 100.0;

    void _scrollLeft() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset - scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    void _scrollRight() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset + scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

// --- FILTERING BY CLASS + SURNAME
    bool surnameMatches(Student s) {
      if (_surnameController.text.trim().isEmpty) return true;

      final query = _surnameController.text.trim().toLowerCase();
      return (s.surname ?? '').toLowerCase().contains(query);
    }

    bool classMatches(Student s) {
      if (_selectedClasses.isEmpty) return true;

      final studentClass = (s.class_ ?? "").trim().toLowerCase();
      return _selectedClasses
          .map((c) => c.trim().toLowerCase())
          .contains(studentClass);
    }

    String normalize(String v) {
      return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final List<PaymentPurpose> allPurposes = (_role == DeviceRole.host)
        ? Hive.box<PaymentPurpose>('payment_purposes').values.toList()
        : _cachedServerStudentPaymentPurposes ?? [];

    // --- Determine selected terms (support single-term fallback)
    final List<String> selectedTermIdsNormalized = (() {
      if ((_selectedTermIds).isNotEmpty) {
        return _selectedTermIds
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList();
      } else {
        final selectedTermIdsNormalized = (_selectedTermIds.isNotEmpty)
            ? _selectedTermIds.map((t) => t.trim().toLowerCase()).toList()
            : allPurposes
                .map((p) => (p.termId ?? '').trim().toLowerCase())
                .toSet()
                .toList();

        return selectedTermIdsNormalized;
      }
    })();

    // Normalize _paymentPurposesOnly (preserve first appearance string)
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p;
      }
    }

    // Normalize selected payment purposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }

    // Caches (all stored objects)
    final List<Student> allStudents = (_role == DeviceRole.host)
        ? Hive.box<Student>('students').values.toList()
        : _cachedServerStudents ?? [];

    // --- Collect purposes that belong to ANY selected term
    final List<PaymentPurpose> purposesInSelectedTerms = allPurposes
        .where((p) => selectedTermIdsNormalized
            .contains((p.termId ?? '').trim().toLowerCase()))
        .toList();
    // Group same-name purposes (case-insensitive). For each normalized name we keep the list of underlying PaymentPurpose objects
    final Map<String, List<PaymentPurpose>> purposeNameToList = {};
    for (var p in purposesInSelectedTerms) {
      final nameKey = normalize(p.paymentPurpose);
      if (nameKey.isEmpty) continue;
      purposeNameToList.putIfAbsent(nameKey, () => []).add(p);
    }

    // aggregated display names & aggregated amounts (sum of amounts across terms for same name)
    // Build full union of payment purposes appearing in ANY selected term
    // Payment purposes that exist across any selected terms
    final List<String> normalizedPaymentPurposesOnly = purposeNameToList.keys
        .map((key) {
          return normalizedPurposesMap[key] ?? key;
        })
        .toSet()
        .toList()
      ..sort();

    // aggregated purpose amount map used for header display: normalizedName -> sum(amount)
    final Map<String, double> aggregatedPurposeAmounts = {};
    purposeNameToList.forEach((nameKey, list) {
      double headerAmount = 0.0;

      bool isNewcomer = list.any((p) => p.forNewcomersOnly == true);

      if (isNewcomer) {
        // ✅ All newcomer entries share same nominal amount
        // Use the smallest (safest)
        headerAmount = list
            .map((p) => p.purposeAmount ?? 0.0)
            .where((v) => v > 0)
            .fold<double>(double.infinity, (a, b) => a < b ? a : b);

        if (headerAmount == double.infinity) {
          headerAmount = 0.0;
        }
      } else {
        // ✅ normal → sum
        headerAmount =
            list.fold<double>(0.0, (acc, p) => acc + (p.purposeAmount ?? 0.0));
      }
      final displayName = normalizedPurposesMap[nameKey] ?? nameKey;

      aggregatedPurposeAmounts[displayName] = headerAmount;
    });

    // --- Filter payments to only those in selected terms
    final List<StudentPayment> filteredPaymentsForSelectedTerms =
        _filteredPayments
            .where((pay) => selectedTermIdsNormalized
                .contains((pay.termId ?? '').trim().toLowerCase()))
            .toList();

    // Build grouped payments per student per purpose+term key:
    // studentKey -> { '${purposeNameKey}:::${termIdKey}': paidAmount }
    final Map<String, Map<String, double>>
        groupedPaymentsByStudentAndPurposeTerm = {};
    for (var payment in filteredPaymentsForSelectedTerms) {
      final studentKey =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final purposeKey = (payment.paymentPurpose ?? '').trim().toLowerCase();
      final termKey = (payment.termId ?? '').trim().toLowerCase();
      final compositeKey =
          '${normalize(payment.paymentPurpose)}:::${normalize(payment.termId ?? '')}';
      final double paid = payment.amountToPay ?? 0.0;

      groupedPaymentsByStudentAndPurposeTerm.putIfAbsent(studentKey, () => {});
      groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] =
          (groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] ??
                  0.0) +
              paid;
    }

    // Also create an aggregated student->purposeName (no-term) paid map for totals display (sum across terms)
    final Map<String, Map<String, double>>
        aggregatedPaidByStudentAndPurposeName = {};
    groupedPaymentsByStudentAndPurposeTerm.forEach((studentKey, map) {
      aggregatedPaidByStudentAndPurposeName.putIfAbsent(studentKey, () => {});
      map.forEach((compositeKey, paid) {
        final parts = compositeKey.split(':::');
        final purposeKey = parts[0];
        final displayName =
            normalizedPurposesMap[normalize(purposeKey)] ?? purposeKey;
// preserve casing if available

        aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] =
            (aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] ??
                    0.0) +
                paid;
      });
    });

    // --- Build student map: union of students from allStudents and those appearing in payments.
    final Set<String> studentKeysSet = {};
    // from payments
    for (var payment in filteredPaymentsForSelectedTerms) {
      studentKeysSet.add(
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}');
    }
    // from allStudents store
    for (var s in allStudents) {
      studentKeysSet.add('${s.name.toLowerCase()} ${s.surname.toLowerCase()}');
    }

    // Build a lookup Student map; prefer the student object from allStudents if present, else build a minimal placeholder from a payment record
    final Map<String, Student> studentLookup = {};
    for (var s in allStudents) {
      final key = '${s.name.toLowerCase()} ${s.surname.toLowerCase()}';
      studentLookup[key] = s;
    }
    // If payment has student that isn't in allStudents, create a light placeholder Student (adjust fields if your Student model differs)
    for (var payment in filteredPaymentsForSelectedTerms) {
      final key =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';

      if (!studentLookup.containsKey(key)) {
        studentLookup[key] = Student(
          studentIdNumber:
              'unknown-${payment.studentName}-${payment.studentSurname}-${payment.termId}',
          name: payment.studentName,
          surname: payment.studentSurname,
          class_: payment.studentClass ?? '',
          regNumber: payment.studentRegNumber ?? 'N/A',
          gender: '',
          age: DateTime(1800),
          phoneNumber: '',
          paymentStatus: '',
          exceptions: [],
        );
      }
    }

    // --- Helper functions (reuse existing logic but per-term)
    bool isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.any(
                (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
            false)) continue;
        return true;
      }
      return false;
    }

    double getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;
      String normalizeTerm(String v) {
        return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      for (var studentException in studentExceptions) {
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }
        if (!(studentException.terms
                ?.any((t) => normalizeTerm(t) == normalizeTerm(termId)) ??
            false)) continue;

        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) continue;

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) continue;

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percent = (figure / 100) * (purpose.purposeAmount ?? 0.0);
          totalDeduction += percent;
        }
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);
      return adjusted;
    }

    // Precompute rows
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    // Iterate over students (union)
    for (var studentKey in studentKeysSet.toList()..sort()) {
      final student = studentLookup[studentKey];

      // Skip if student not found
      if (student == null) continue;

      // ✅ Apply CLASS + SURNAME filters
      if (!surnameMatches(student)) continue;
      if (!classMatches(student)) continue;

      final studentClass = student?.class_ ?? '';

      // aggregated per-student paid amounts across selected terms (by display purpose name)
      final studentAggregatedPaid =
          aggregatedPaidByStudentAndPurposeName[studentKey] ?? {};

      final double totalPaidAmount =
          studentAggregatedPaid.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrearsForStudent = 0.0;

      // Build arrears cells for each aggregated purpose (display order: normalizedPaymentPurposesOnly)
      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        final normalizedKey = purposeDisplayName.trim().toLowerCase();
        final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];

        // No underlying purpose → show 0
        if (underlyingPurposes.isEmpty) {
          return const DataCell(Text('0.0'));
        }

        /*
  ─────────────────────────────────────────────
  HELPERS
  ─────────────────────────────────────────────
  */

        bool isPurposeApplicableForStudent(PaymentPurpose p, Student s) {
          final studentTerms =
              s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
          final purposeTerm = (p.termId ?? '').trim().toLowerCase();
          return studentTerms.contains(purposeTerm);
        }

        bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
          final classes = p.associatedClasses ?? [];
          if (classes.isEmpty) return false;

          final studentClass = s.class_?.trim().toLowerCase();
          return classes
              .map((c) => c.trim().toLowerCase())
              .contains(studentClass);
        }

        bool isPurposeAllowed(PaymentPurpose p, Student s) {
          // Must first be allowed by class
          if (!isPurposeAllowedByClass(p, s)) return false;

          // Newcomer-only – must pass eligibility
          if (p.forNewcomersOnly == true) {
            final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
            return isNewcomerEligible(s, p, termObj);
          }

          return true;
        }

        PaymentPurpose? findFirstUnpaidPurposeForStudent(
          Student student,
          List<PaymentPurpose> purposes,
          Map<String, Map<String, double>> paidMap,
          String termId,
        ) {
          for (var p in purposes) {
            if ((p.termId ?? '').trim().toLowerCase() != termId) continue;

            final compositeKey =
                '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
            final paid = paidMap[studentKey]?[compositeKey] ?? 0.0;
            final amount = p.purposeAmount ?? 0.0;

            if (paid < amount) return p;
          }
          return null;
        }

        bool isPurposeApplicableForStudentByName(
          Student s,
          String purposeDisplayName,
        ) {
          final normalizedKey = purposeDisplayName.trim().toLowerCase();
          final list = purposeNameToList[normalizedKey];
          if (list == null) return false;

          for (var p in list) {
            // Must match student class
            final classes = p.associatedClasses ?? [];
            if (classes.isNotEmpty &&
                classes
                    .map((c) => c.trim().toLowerCase())
                    .contains((s.class_ ?? '').trim().toLowerCase())) {
              // ✅ If newcomer purpose → check eligibility
              if (p.forNewcomersOnly == true) {
                final termKey = (p.termId ?? '').trim().toLowerCase();
                final termObj = _termMap[termKey];
                if (!isNewcomerEligible(s, p, termObj)) {
                  continue;
                }
              }

              // ✅ Must match student term
              final studentTerms =
                  s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
              if (!studentTerms
                  .contains((p.termId ?? '').trim().toLowerCase())) {
                continue;
              }

              return true;
            }
          }
          return false;
        }

        /*
  ─────────────────────────────────────────────
  MAIN ARREARS SUMMATION
  ─────────────────────────────────────────────
  */

        double aggregatedArrearForThisPurpose = 0.0;

        // Precompute first unpaid purpose per term
        Map<String, PaymentPurpose?> firstUnpaidPerTerm = {};
        for (var p in underlyingPurposes) {
          final termNorm = (p.termId ?? '').trim().toLowerCase();
          firstUnpaidPerTerm[termNorm] ??= findFirstUnpaidPurposeForStudent(
            student!,
            underlyingPurposes,
            groupedPaymentsByStudentAndPurposeTerm,
            termNorm,
          );
        }

        for (var up in underlyingPurposes) {
          final termIdNorm = (up.termId ?? '').trim().toLowerCase();

          // Class + newcomer eligibility check
          if (!isPurposeAllowed(up, student!)) continue;

          // Check term association
          if (!isPurposeApplicableForStudent(up, student)) continue;

          // Newcomer-only logic — only first unpaid counts
          if (up.forNewcomersOnly == true) {
            final firstUnpaid = firstUnpaidPerTerm[termIdNorm];
            if (firstUnpaid == null || firstUnpaid != up) {
              continue; // skip any other newcomer purpose
            }
          }

          final compositeKey =
              '${normalize(up.paymentPurpose)}:::${normalize(up.termId ?? '')}';

          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;

          final double purposeAmount = up.purposeAmount ?? 0.0;
          double arrear = (purposeAmount - paid).clamp(0.0, purposeAmount);

          // Re-check newcomer eligibility
          if (up.forNewcomersOnly == true) {
            final termObj = _termMap[termIdNorm];
            if (!isNewcomerEligible(student!, up, termObj)) {
              arrear = 0.0;
            }
          }

          // Apply exceptions if any
          if (up.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(arrear, student!, up, up.termId ?? '');
          }

          if (up.forNewcomersOnly == true) {
            // --- aggregate newcomer total amount for this purpose across terms
            double totalNominalAmount = underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)
                .map((p) => p.purposeAmount ?? 0.0)
                .fold<double>(double.infinity, (a, b) => a < b ? a : b);

            if (totalNominalAmount == double.infinity) {
              totalNominalAmount = 0.0;
            }

            // --- aggregate payments across ALL terms for this newcomer purpose
            double totalPaid = 0.0;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              final ck =
                  '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
              totalPaid += groupedPaymentsByStudentAndPurposeTerm[studentKey]
                      ?[ck] ??
                  0.0;
            }

            double rawArrear = (totalNominalAmount - totalPaid);
            if (rawArrear < 0) rawArrear = 0;

            // ✅ exceptions
            double adjustedArrear = rawArrear;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              adjustedArrear = getAdjustedArrear(
                adjustedArrear,
                student!,
                p,
                p.termId ?? '',
              );
            }
            adjustedArrear = adjustedArrear.clamp(0.0, totalNominalAmount);

            // ✅ Update once only
            aggregatedArrearForThisPurpose = adjustedArrear;

            // ✅ Done → skip sub-iteration of other newcomer entries
            break;
          }

          aggregatedArrearForThisPurpose += arrear;
        }

        /*
  ─────────────────────────────────────────────
  VISIBILITY / TOTAL UPDATES
  ─────────────────────────────────────────────
  */

        // If no underlying purpose is allowed → blank
        final allowed =
            underlyingPurposes.any((p) => isPurposeAllowed(p, student!));
        if (!allowed) {
          return const DataCell(Text(""));
        }

        // Update totals
        totalArrearsForStudent += aggregatedArrearForThisPurpose;
        grandTotalArrears += aggregatedArrearForThisPurpose;
        grandTotalPurposeArrears[purposeDisplayName] =
            (grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) +
                aggregatedArrearForThisPurpose;

        return DataCell(
          Text(aggregatedArrearForThisPurpose.toStringAsFixed(2)),
        );
      }).toList();

      // Paid cells for selected payment purposes (if you still want them)
      final List<DataCell> paidCells = _selectedPaymentPurposes.map((purpose) {
        final paidAmount = studentAggregatedPaid[purpose] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      // Arrear filter logic (same as before)
      bool matchesFilter = true;
      switch (_selectedArrearFilter) {
        case 'Arrears Only':
          matchesFilter = totalArrearsForStudent > 0;
          break;
        case 'Fully Paid':
          matchesFilter = totalArrearsForStudent == 0;
          break;
        case 'Overpaid / Credit':
          matchesFilter = totalArrearsForStudent < 0;
          break;
        case 'Custom Range':
          if (_arrearMin != null && _arrearMax != null) {
            matchesFilter = totalArrearsForStudent >= _arrearMin! &&
                totalArrearsForStudent <= _arrearMax!;
          }
          break;
        default:
          matchesFilter = true;
      }
      if (!matchesFilter) continue;

      // Add the DataRow
      dataRows.add(DataRow(cells: [
        DataCell(Text(studentKey)), // STUDENT NAME (key is "name surname")
        DataCell(Text(studentClass)),
        // arrears per aggregated purpose (note: we display negative like original code if you prefer)
        if (_showArrears)
          ...arrearsCells.map((cell) {
            final textWidget = cell.child;
            if (textWidget is Text) {
              final originalText = textWidget.data ?? '';
              // ✅ keep blank → blank
              if (originalText.trim().isEmpty) {
                return const DataCell(Text(""));
              }
              final parsed = double.tryParse(originalText) ?? 0.0;
              final displayValue =
                  parsed > 0.0 ? (-parsed).toStringAsFixed(2) : '0.0';
              return DataCell(Text(displayValue));
            } else {
              return const DataCell(Text('0.0'));
            }
          }),

        // ✅ NEW — paid-amounts matching same normalizedPaymentPurposesOnly
        if (_showPayments)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            final paidAmount = studentAggregatedPaid[purposeDisplayName] ?? 0.0;

            grandTotalPurposePaid[purposeDisplayName] =
                (grandTotalPurposePaid[purposeDisplayName] ?? 0.0) + paidAmount;

            return DataCell(Text(paidAmount.toStringAsFixed(2)));
          }).toList(),

        DataCell(Text(totalArrearsForStudent > 0.0
            ? '-${totalArrearsForStudent.abs().toStringAsFixed(2)}'
            : '0.0')),
        DataCell(Text(totalPaidAmount.toStringAsFixed(2))),
      ]));
    }

    // Grand totals row (use aggregatedPurposeAmounts keys in same order as normalizedPaymentPurposesOnly)
    dataRows.add(DataRow(
      cells: [
        DataCell(Container(
          color: Colors.blue,
          padding: const EdgeInsets.all(8.0),
          child: const Text('GRAND TOTALS',
              style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const DataCell(SizedBox.shrink()),
        if (_showArrears)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            return DataCell(Container(
              color: const Color.fromARGB(255, 246, 55, 2),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                ((grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) > 0.0)
                    ? '-${(grandTotalPurposeArrears[purposeDisplayName] ?? 0.0).abs().toStringAsFixed(2)}'
                    : '0.0',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ));
          }).toList(),
        // ✅ PAID Columns
        if (_showPayments)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            return DataCell(Container(
              color: const Color.fromARGB(255, 13, 244, 244),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                (grandTotalPurposePaid[purposeDisplayName] ?? 0.0)
                    .toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ));
          }).toList(),
        DataCell(Container(
          color: const Color.fromARGB(255, 248, 151, 4),
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '-${grandTotalArrears.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )),
        DataCell(Container(
          color: const Color.fromARGB(255, 13, 244, 244),
          padding: const EdgeInsets.all(8.0),
          child: Text(
            grandTotalPaid.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )),
      ],
    ));

    // --- Build the table UI (same as before)
    return Stack(
      children: [
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
                    ...(_showArrears
                        ? normalizedPaymentPurposesOnly.map((p) => DataColumn(
                              label: Container(
                                color: const Color.fromARGB(255, 255, 0, 0),
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                    '$p ARREARS (\$${aggregatedPurposeAmounts[p] ?? 0.0})'),
                              ),
                            ))
                        : []),
                    // ✅ NEW — PAID HEADERS
                    ...(_showPayments
                        ? normalizedPaymentPurposesOnly.map(
                            (p) => DataColumn(
                                label: Container(
                                    color:
                                        const Color.fromARGB(120, 0, 255, 60),
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('$p PAID'))),
                          )
                        : []),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 248, 151, 4),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('TOTAL ARREARS'.toUpperCase()),
                      ),
                    ),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 13, 244, 244),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('TOTAL PAID'.toUpperCase()),
                      ),
                    ),
                  ],
                  rows: dataRows,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 50,
          left: 60,
          right: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                heroTag: 'scrollLeftFAB',
                onPressed: _scrollLeft,
                mini: true,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.arrow_back),
              ),
              FloatingActionButton(
                heroTag: 'scrollRightFAB',
                onPressed: _scrollRight,
                mini: true,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<pw.Document> generatePaymentsPDF() async {
    final pdf = pw.Document();

// --- FILTERING BY CLASS + SURNAME
    bool surnameMatches(Student s) {
      if (_surnameController.text.trim().isEmpty) return true;

      final query = _surnameController.text.trim().toLowerCase();
      return (s.surname ?? '').toLowerCase().contains(query);
    }

    bool classMatches(Student s) {
      if (_selectedClasses.isEmpty) return true;

      final studentClass = (s.class_ ?? "").trim().toLowerCase();
      return _selectedClasses
          .map((c) => c.trim().toLowerCase())
          .contains(studentClass);
    }

    String normalize(String v) {
      return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final List<PaymentPurpose> allPurposes = (_role == DeviceRole.host)
        ? Hive.box<PaymentPurpose>('payment_purposes').values.toList()
        : _cachedServerStudentPaymentPurposes ?? [];

    // --- Determine selected terms (support single-term fallback)
    final List<String> selectedTermIdsNormalized = (() {
      if ((_selectedTermIds).isNotEmpty) {
        return _selectedTermIds
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList();
      } else {
        final selectedTermIdsNormalized = (_selectedTermIds.isNotEmpty)
            ? _selectedTermIds.map((t) => t.trim().toLowerCase()).toList()
            : allPurposes
                .map((p) => (p.termId ?? '').trim().toLowerCase())
                .toSet()
                .toList();

        return selectedTermIdsNormalized;
      }
    })();

    // Normalize _paymentPurposesOnly (preserve first appearance string)
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p;
      }
    }

    // Normalize selected payment purposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }

    // Caches (all stored objects)
    final List<Student> allStudents = (_role == DeviceRole.host)
        ? Hive.box<Student>('students').values.toList()
        : _cachedServerStudents ?? [];

    // --- Collect purposes that belong to ANY selected term
    final List<PaymentPurpose> purposesInSelectedTerms = allPurposes
        .where((p) => selectedTermIdsNormalized
            .contains((p.termId ?? '').trim().toLowerCase()))
        .toList();
    // Group same-name purposes (case-insensitive). For each normalized name we keep the list of underlying PaymentPurpose objects
    final Map<String, List<PaymentPurpose>> purposeNameToList = {};
    for (var p in purposesInSelectedTerms) {
      final nameKey = normalize(p.paymentPurpose);
      if (nameKey.isEmpty) continue;
      purposeNameToList.putIfAbsent(nameKey, () => []).add(p);
    }

    // aggregated display names & aggregated amounts (sum of amounts across terms for same name)
    // Build full union of payment purposes appearing in ANY selected term
    // Payment purposes that exist across any selected terms
    final List<String> normalizedPaymentPurposesOnly = purposeNameToList.keys
        .map((key) {
          return normalizedPurposesMap[key] ?? key;
        })
        .toSet()
        .toList()
      ..sort();

    // aggregated purpose amount map used for header display: normalizedName -> sum(amount)
    final Map<String, double> aggregatedPurposeAmounts = {};
    purposeNameToList.forEach((nameKey, list) {
      double headerAmount = 0.0;

      bool isNewcomer = list.any((p) => p.forNewcomersOnly == true);

      if (isNewcomer) {
        // ✅ All newcomer entries share same nominal amount
        // Use the smallest (safest)
        headerAmount = list
            .map((p) => p.purposeAmount ?? 0.0)
            .where((v) => v > 0)
            .fold<double>(double.infinity, (a, b) => a < b ? a : b);

        if (headerAmount == double.infinity) {
          headerAmount = 0.0;
        }
      } else {
        // ✅ normal → sum
        headerAmount =
            list.fold<double>(0.0, (acc, p) => acc + (p.purposeAmount ?? 0.0));
      }
      final displayName = normalizedPurposesMap[nameKey] ?? nameKey;

      aggregatedPurposeAmounts[displayName] = headerAmount;
    });

    // --- Filter payments to only those in selected terms
    final List<StudentPayment> filteredPaymentsForSelectedTerms =
        _filteredPayments
            .where((pay) => selectedTermIdsNormalized
                .contains((pay.termId ?? '').trim().toLowerCase()))
            .toList();

    // Build grouped payments per student per purpose+term key:
    // studentKey -> { '${purposeNameKey}:::${termIdKey}': paidAmount }
    final Map<String, Map<String, double>>
        groupedPaymentsByStudentAndPurposeTerm = {};
    for (var payment in filteredPaymentsForSelectedTerms) {
      final studentKey =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final purposeKey = (payment.paymentPurpose ?? '').trim().toLowerCase();
      final termKey = (payment.termId ?? '').trim().toLowerCase();
      final compositeKey =
          '${normalize(payment.paymentPurpose)}:::${normalize(payment.termId ?? '')}';
      final double paid = payment.amountToPay ?? 0.0;

      groupedPaymentsByStudentAndPurposeTerm.putIfAbsent(studentKey, () => {});
      groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] =
          (groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] ??
                  0.0) +
              paid;
    }

    // Also create an aggregated student->purposeName (no-term) paid map for totals display (sum across terms)
    final Map<String, Map<String, double>>
        aggregatedPaidByStudentAndPurposeName = {};
    groupedPaymentsByStudentAndPurposeTerm.forEach((studentKey, map) {
      aggregatedPaidByStudentAndPurposeName.putIfAbsent(studentKey, () => {});
      map.forEach((compositeKey, paid) {
        final parts = compositeKey.split(':::');
        final purposeKey = parts[0];
        final displayName =
            normalizedPurposesMap[normalize(purposeKey)] ?? purposeKey;
// preserve casing if available

        aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] =
            (aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] ??
                    0.0) +
                paid;
      });
    });

    // --- Build student map: union of students from allStudents and those appearing in payments.
    final Set<String> studentKeysSet = {};
    // from payments
    for (var payment in filteredPaymentsForSelectedTerms) {
      studentKeysSet.add(
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}');
    }
    // from allStudents store
    for (var s in allStudents) {
      studentKeysSet.add('${s.name.toLowerCase()} ${s.surname.toLowerCase()}');
    }

    // Build a lookup Student map; prefer the student object from allStudents if present, else build a minimal placeholder from a payment record
    final Map<String, Student> studentLookup = {};
    for (var s in allStudents) {
      final key = '${s.name.toLowerCase()} ${s.surname.toLowerCase()}';
      studentLookup[key] = s;
    }
    // If payment has student that isn't in allStudents, create a light placeholder Student (adjust fields if your Student model differs)
    for (var payment in filteredPaymentsForSelectedTerms) {
      final key =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';

      if (!studentLookup.containsKey(key)) {
        studentLookup[key] = Student(
          studentIdNumber:
              'unknown-${payment.studentName}-${payment.studentSurname}-${payment.termId}',
          name: payment.studentName,
          surname: payment.studentSurname,
          class_: payment.studentClass ?? '',
          regNumber: payment.studentRegNumber ?? 'N/A',
          gender: '',
          age: DateTime(1800),
          phoneNumber: '',
          paymentStatus: '',
          exceptions: [],
        );
      }
    }

    // --- Helper functions (reuse existing logic but per-term)
    bool isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.any(
                (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
            false)) continue;
        return true;
      }
      return false;
    }

    double getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;
      String normalizeTerm(String v) {
        return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      for (var studentException in studentExceptions) {
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }
        if (!(studentException.terms
                ?.any((t) => normalizeTerm(t) == normalizeTerm(termId)) ??
            false)) continue;

        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) continue;

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) continue;

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percent = (figure / 100) * (purpose.purposeAmount ?? 0.0);
          totalDeduction += percent;
        }
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);
      return adjusted;
    }

    // --- Build PDF table rows
    final List<pw.TableRow> rows = [];

    // Header row
    final List<pw.Widget> headerCells = [];

    if (_showArrears) {
      headerCells.addAll(normalizedPaymentPurposesOnly.map((p) => pw.Text(
          '$p ARREARS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))));
    }

    if (_showPayments) {
      headerCells.addAll(normalizedPaymentPurposesOnly.map((p) => pw.Text(
          '$p PAID',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))));
    }

    headerCells.addAll([
      pw.Text('TOTAL ARREARS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('TOTAL PAID',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]);

    rows.add(pw.TableRow(children: headerCells));

    // Precompute rows
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    // Iterate over students (union)
    for (var studentKey in studentKeysSet.toList()..sort()) {
      final student = studentLookup[studentKey];

      // Skip if student not found
      if (student == null) continue;

      // ✅ Apply CLASS + SURNAME filters
      if (!surnameMatches(student)) continue;
      if (!classMatches(student)) continue;

      final studentClass = student?.class_ ?? '';

      // aggregated per-student paid amounts across selected terms (by display purpose name)
      final studentAggregatedPaid =
          aggregatedPaidByStudentAndPurposeName[studentKey] ?? {};

      final double totalPaidAmount =
          studentAggregatedPaid.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrearsForStudent = 0.0;

      // Build arrears cells for each aggregated purpose (display order: normalizedPaymentPurposesOnly)
      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        final normalizedKey = purposeDisplayName.trim().toLowerCase();
        final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];

        // No underlying purpose → show 0
        if (underlyingPurposes.isEmpty) {
          return const DataCell(Text('0.0'));
        }

        /*
  ─────────────────────────────────────────────
  HELPERS
  ─────────────────────────────────────────────
  */

        bool isPurposeApplicableForStudent(PaymentPurpose p, Student s) {
          final studentTerms =
              s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
          final purposeTerm = (p.termId ?? '').trim().toLowerCase();
          return studentTerms.contains(purposeTerm);
        }

        bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
          final classes = p.associatedClasses ?? [];
          if (classes.isEmpty) return false;

          final studentClass = s.class_?.trim().toLowerCase();
          return classes
              .map((c) => c.trim().toLowerCase())
              .contains(studentClass);
        }

        bool isPurposeAllowed(PaymentPurpose p, Student s) {
          // Must first be allowed by class
          if (!isPurposeAllowedByClass(p, s)) return false;

          // Newcomer-only – must pass eligibility
          if (p.forNewcomersOnly == true) {
            final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
            return isNewcomerEligible(s, p, termObj);
          }

          return true;
        }

        PaymentPurpose? findFirstUnpaidPurposeForStudent(
          Student student,
          List<PaymentPurpose> purposes,
          Map<String, Map<String, double>> paidMap,
          String termId,
        ) {
          for (var p in purposes) {
            if ((p.termId ?? '').trim().toLowerCase() != termId) continue;

            final compositeKey =
                '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
            final paid = paidMap[studentKey]?[compositeKey] ?? 0.0;
            final amount = p.purposeAmount ?? 0.0;

            if (paid < amount) return p;
          }
          return null;
        }

        bool isPurposeApplicableForStudentByName(
          Student s,
          String purposeDisplayName,
        ) {
          final normalizedKey = purposeDisplayName.trim().toLowerCase();
          final list = purposeNameToList[normalizedKey];
          if (list == null) return false;

          for (var p in list) {
            // Must match student class
            final classes = p.associatedClasses ?? [];
            if (classes.isNotEmpty &&
                classes
                    .map((c) => c.trim().toLowerCase())
                    .contains((s.class_ ?? '').trim().toLowerCase())) {
              // ✅ If newcomer purpose → check eligibility
              if (p.forNewcomersOnly == true) {
                final termKey = (p.termId ?? '').trim().toLowerCase();
                final termObj = _termMap[termKey];
                if (!isNewcomerEligible(s, p, termObj)) {
                  continue;
                }
              }

              // ✅ Must match student term
              final studentTerms =
                  s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
              if (!studentTerms
                  .contains((p.termId ?? '').trim().toLowerCase())) {
                continue;
              }

              return true;
            }
          }
          return false;
        }

        /*
  ─────────────────────────────────────────────
  MAIN ARREARS SUMMATION
  ─────────────────────────────────────────────
  */

        double aggregatedArrearForThisPurpose = 0.0;

        // Precompute first unpaid purpose per term
        Map<String, PaymentPurpose?> firstUnpaidPerTerm = {};
        for (var p in underlyingPurposes) {
          final termNorm = (p.termId ?? '').trim().toLowerCase();
          firstUnpaidPerTerm[termNorm] ??= findFirstUnpaidPurposeForStudent(
            student!,
            underlyingPurposes,
            groupedPaymentsByStudentAndPurposeTerm,
            termNorm,
          );
        }

        for (var up in underlyingPurposes) {
          final termIdNorm = (up.termId ?? '').trim().toLowerCase();

          // Class + newcomer eligibility check
          if (!isPurposeAllowed(up, student!)) continue;

          // Check term association
          if (!isPurposeApplicableForStudent(up, student)) continue;

          // Newcomer-only logic — only first unpaid counts
          if (up.forNewcomersOnly == true) {
            final firstUnpaid = firstUnpaidPerTerm[termIdNorm];
            if (firstUnpaid == null || firstUnpaid != up) {
              continue; // skip any other newcomer purpose
            }
          }

          final compositeKey =
              '${normalize(up.paymentPurpose)}:::${normalize(up.termId ?? '')}';

          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;

          final double purposeAmount = up.purposeAmount ?? 0.0;
          double arrear = (purposeAmount - paid).clamp(0.0, purposeAmount);

          // Re-check newcomer eligibility
          if (up.forNewcomersOnly == true) {
            final termObj = _termMap[termIdNorm];
            if (!isNewcomerEligible(student!, up, termObj)) {
              arrear = 0.0;
            }
          }

          // Apply exceptions if any
          if (up.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(arrear, student!, up, up.termId ?? '');
          }

          if (up.forNewcomersOnly == true) {
            // --- aggregate newcomer total amount for this purpose across terms
            double totalNominalAmount = underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)
                .map((p) => p.purposeAmount ?? 0.0)
                .fold<double>(double.infinity, (a, b) => a < b ? a : b);

            if (totalNominalAmount == double.infinity) {
              totalNominalAmount = 0.0;
            }

            // --- aggregate payments across ALL terms for this newcomer purpose
            double totalPaid = 0.0;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              final ck =
                  '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
              totalPaid += groupedPaymentsByStudentAndPurposeTerm[studentKey]
                      ?[ck] ??
                  0.0;
            }

            double rawArrear = (totalNominalAmount - totalPaid);
            if (rawArrear < 0) rawArrear = 0;

            // ✅ exceptions
            double adjustedArrear = rawArrear;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              adjustedArrear = getAdjustedArrear(
                adjustedArrear,
                student!,
                p,
                p.termId ?? '',
              );
            }
            adjustedArrear = adjustedArrear.clamp(0.0, totalNominalAmount);

            // ✅ Update once only
            aggregatedArrearForThisPurpose = adjustedArrear;

            // ✅ Done → skip sub-iteration of other newcomer entries
            break;
          }

          aggregatedArrearForThisPurpose += arrear;
        }

        /*
  ─────────────────────────────────────────────
  VISIBILITY / TOTAL UPDATES
  ─────────────────────────────────────────────
  */

        // If no underlying purpose is allowed → blank
        final allowed =
            underlyingPurposes.any((p) => isPurposeAllowed(p, student!));
        if (!allowed) {
          return const DataCell(Text(""));
        }

        // Update totals
        totalArrearsForStudent += aggregatedArrearForThisPurpose;
        grandTotalArrears += aggregatedArrearForThisPurpose;
        grandTotalPurposeArrears[purposeDisplayName] =
            (grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) +
                aggregatedArrearForThisPurpose;

        return DataCell(
          Text(aggregatedArrearForThisPurpose.toStringAsFixed(2)),
        );
      }).toList();

      // Paid cells for selected payment purposes (if you still want them)
      final List<DataCell> paidCells = _selectedPaymentPurposes.map((purpose) {
        final paidAmount = studentAggregatedPaid[purpose] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      // Arrear filter logic (same as before)
      bool matchesFilter = true;
      switch (_selectedArrearFilter) {
        case 'Arrears Only':
          matchesFilter = totalArrearsForStudent > 0;
          break;
        case 'Fully Paid':
          matchesFilter = totalArrearsForStudent == 0;
          break;
        case 'Overpaid / Credit':
          matchesFilter = totalArrearsForStudent < 0;
          break;
        case 'Custom Range':
          if (_arrearMin != null && _arrearMax != null) {
            matchesFilter = totalArrearsForStudent >= _arrearMin! &&
                totalArrearsForStudent <= _arrearMax!;
          }
          break;
        default:
          matchesFilter = true;
      }
      if (!matchesFilter) continue;

      // Build arrears row
      final List<pw.Widget> arrearsRow = [
        if (_showArrears)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            final idx =
                normalizedPaymentPurposesOnly.indexOf(purposeDisplayName);
            if (idx < arrearsCells.length) {
              final cell = arrearsCells[idx];
              return pw.Text((cell.child as Text).data!);
            } else {
              print('⚠️ Missing arrearsCell for purpose: $purposeDisplayName');
              return pw.Text(''); // Empty cell if missing
            }
          }),
        if (_showPayments)
          ...normalizedPaymentPurposesOnly.map((purpose) {
            final amount = studentAggregatedPaid[purpose] ?? 0.0;
            // Update grand total
            grandTotalPurposePaid[purpose] =
                (grandTotalPurposePaid[purpose] ?? 0.0) + amount;
            return pw.Text(amount.toStringAsFixed(2));
          }),
        if (_showArrears) pw.Text(totalArrearsForStudent.toStringAsFixed(2)),
        if (_showPayments) pw.Text(totalPaidAmount.toStringAsFixed(2)),
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

      final headerRow = pw.TableRow(
        children: [
          pw.Text("PURPOSE",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("ARREARS",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("PAID", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      );
      final List<pw.TableRow> purposeRows = normalizedPaymentPurposesOnly
          .map<pw.TableRow?>((purposeDisplayName) {
            final idx =
                normalizedPaymentPurposesOnly.indexOf(purposeDisplayName);

            // Extract arrears (string)
            String arrearsText = '';
            if (_showArrears && idx < arrearsCells.length) {
              arrearsText = (arrearsCells[idx].child as Text).data ?? '';
            }

            // ✅ skip if arrears blank

            // Extract paid value
            String paidText = '';
            if (_showPayments) {
              final amount = studentAggregatedPaid[purposeDisplayName] ?? 0.0;

              grandTotalPurposePaid[purposeDisplayName] =
                  (grandTotalPurposePaid[purposeDisplayName] ?? 0.0) + amount;

              paidText = amount.toStringAsFixed(2);
            }
            var paidValue = double.tryParse(paidText) ?? 0.0;
            if (arrearsText.trim().isEmpty && (paidValue <= 0.0)) {
              return null;
            }

            // --- Compute total expected amount for this student + purpose across selected terms
            double totalExpectedForStudentPurpose = 0.0;
            final normalizedKey = purposeDisplayName.trim().toLowerCase();
            final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];
            bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
              final classes = p.associatedClasses ?? [];
              if (classes.isEmpty) return false;

              final studentClass = s.class_?.trim().toLowerCase();
              return classes
                  .map((c) => c.trim().toLowerCase())
                  .contains(studentClass);
            }

            bool isPurposeAllowed(PaymentPurpose p, Student s) {
              // Must first be allowed by class
              if (!isPurposeAllowedByClass(p, s)) return false;

              // Newcomer-only – must pass eligibility
              if (p.forNewcomersOnly == true) {
                final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
                return isNewcomerEligible(s, p, termObj);
              }

              return true;
            }

            bool isPurposeApplicableForStudent(PaymentPurpose p, Student s) {
              final studentTerms =
                  s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
              final purposeTerm = (p.termId ?? '').trim().toLowerCase();
              return studentTerms.contains(purposeTerm);
            }

            for (var p in underlyingPurposes) {
              // Only count terms selected and eligible for student
              final termNorm = (p.termId ?? '').trim().toLowerCase();
              if (!selectedTermIdsNormalized.contains(termNorm)) continue;

              // Check eligibility for student

              if (!isPurposeAllowed(p, student!)) continue;
              if (!isPurposeApplicableForStudent(p, student)) continue;

              totalExpectedForStudentPurpose += p.purposeAmount ?? 0.0;
            }

            final List<pw.Widget> columns = [
              pw.Text(
                  '$purposeDisplayName (${totalExpectedForStudentPurpose.toStringAsFixed(2)})'),
            ];

            if (_showArrears) {
              columns.add(pw.Text(arrearsText));
            }

            if (_showPayments) {
              columns.add(pw.Text(paidText));
            }

            return pw.TableRow(children: columns);
          })
          // ✅ Remove all NULL rows
          .whereType<pw.TableRow>()
          // ✅ Force into List<TableRow>
          .toList();

      final totalsRow = pw.TableRow(
        children: [
          pw.Text("TOTALS",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(totalArrearsForStudent.toStringAsFixed(2),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(totalPaidAmount.toStringAsFixed(2),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      );
      final List<String> studentTermsDisplayList = (_termMap != null)
          ? selectedTermIdsNormalized
              .map((t) => _termMap[t]?.termName ?? t)
              .toList()
          : selectedTermIdsNormalized.toList();
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
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => buildHeader(),
          footer: (context) => buildFooter(context),
          build: (context) {
            return [
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  "STUDENT STATEMENT",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: pw.Text(
                        "Generated On",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: pw.Text(
                        pdfCreationDate,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "${student.name.toUpperCase()} "
                      "${student.surname.toUpperCase()}",
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      "Class: ${studentClass.toUpperCase()}",
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

              /// ✅ Student Table
              pw.Table(
                border: pw.TableBorder.all(),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  headerRow,
                  ...purposeRows,
                  totalsRow,
                ],
              ),
            ];
          },
        ),
      );
    }

    // --- Grand total row
    final List<pw.Widget> grandTotalCells = [
      pw.Text('GRAND TOTALS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(),
    ];

    if (_showArrears) {
      grandTotalCells.addAll(normalizedPaymentPurposesOnly.map((p) {
        return pw.Text(
          (grandTotalPurposeArrears[p] ?? 0.0).toStringAsFixed(2),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        );
      }));
    }

    if (_showPayments) {
      grandTotalCells.addAll(normalizedPaymentPurposesOnly.map((p) {
        return pw.Text(
          (grandTotalPurposePaid[p] ?? 0.0).toStringAsFixed(2),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        );
      }));
    }

    grandTotalCells.add(pw.Text(grandTotalArrears.toStringAsFixed(2),
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
    grandTotalCells.add(pw.Text(grandTotalPaid.toStringAsFixed(2),
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));

    rows.add(pw.TableRow(children: grandTotalCells));

    // --- Add table to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, // use landscape for wide tables

        build: (context) => pw.Table(
          border: pw.TableBorder.all(),
          children: rows,
        ),
      ),
    );

    return pdf;
  }

  Future<void> generateAndSaveSpreadsheet() async {
// --- FILTERING BY CLASS + SURNAME
    bool surnameMatches(Student s) {
      if (_surnameController.text.trim().isEmpty) return true;

      final query = _surnameController.text.trim().toLowerCase();
      return (s.surname ?? '').toLowerCase().contains(query);
    }

    bool classMatches(Student s) {
      if (_selectedClasses.isEmpty) return true;

      final studentClass = (s.class_ ?? "").trim().toLowerCase();
      return _selectedClasses
          .map((c) => c.trim().toLowerCase())
          .contains(studentClass);
    }

    String normalize(String v) {
      return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final List<PaymentPurpose> allPurposes = (_role == DeviceRole.host)
        ? Hive.box<PaymentPurpose>('payment_purposes').values.toList()
        : _cachedServerStudentPaymentPurposes ?? [];

    // --- Determine selected terms (support single-term fallback)
    final List<String> selectedTermIdsNormalized = (() {
      if ((_selectedTermIds).isNotEmpty) {
        return _selectedTermIds
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList();
      } else {
        final selectedTermIdsNormalized = (_selectedTermIds.isNotEmpty)
            ? _selectedTermIds.map((t) => t.trim().toLowerCase()).toList()
            : allPurposes
                .map((p) => (p.termId ?? '').trim().toLowerCase())
                .toSet()
                .toList();

        return selectedTermIdsNormalized;
      }
    })();

    // Normalize _paymentPurposesOnly (preserve first appearance string)
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p;
      }
    }

    // Normalize selected payment purposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }

    // Caches (all stored objects)
    final List<Student> allStudents = (_role == DeviceRole.host)
        ? Hive.box<Student>('students').values.toList()
        : _cachedServerStudents ?? [];

    // --- Collect purposes that belong to ANY selected term
    final List<PaymentPurpose> purposesInSelectedTerms = allPurposes
        .where((p) => selectedTermIdsNormalized
            .contains((p.termId ?? '').trim().toLowerCase()))
        .toList();
    // Group same-name purposes (case-insensitive). For each normalized name we keep the list of underlying PaymentPurpose objects
    final Map<String, List<PaymentPurpose>> purposeNameToList = {};
    for (var p in purposesInSelectedTerms) {
      final nameKey = normalize(p.paymentPurpose);
      if (nameKey.isEmpty) continue;
      purposeNameToList.putIfAbsent(nameKey, () => []).add(p);
    }

    // aggregated display names & aggregated amounts (sum of amounts across terms for same name)
    // Build full union of payment purposes appearing in ANY selected term
    // Payment purposes that exist across any selected terms
    final List<String> normalizedPaymentPurposesOnly = purposeNameToList.keys
        .map((key) {
          return normalizedPurposesMap[key] ?? key;
        })
        .toSet()
        .toList()
      ..sort();

    // aggregated purpose amount map used for header display: normalizedName -> sum(amount)
    final Map<String, double> aggregatedPurposeAmounts = {};
    purposeNameToList.forEach((nameKey, list) {
      double headerAmount = 0.0;

      bool isNewcomer = list.any((p) => p.forNewcomersOnly == true);

      if (isNewcomer) {
        // ✅ All newcomer entries share same nominal amount
        // Use the smallest (safest)
        headerAmount = list
            .map((p) => p.purposeAmount ?? 0.0)
            .where((v) => v > 0)
            .fold<double>(double.infinity, (a, b) => a < b ? a : b);

        if (headerAmount == double.infinity) {
          headerAmount = 0.0;
        }
      } else {
        // ✅ normal → sum
        headerAmount =
            list.fold<double>(0.0, (acc, p) => acc + (p.purposeAmount ?? 0.0));
      }
      final displayName = normalizedPurposesMap[nameKey] ?? nameKey;

      aggregatedPurposeAmounts[displayName] = headerAmount;
    });

    // --- Filter payments to only those in selected terms
    final List<StudentPayment> filteredPaymentsForSelectedTerms =
        _filteredPayments
            .where((pay) => selectedTermIdsNormalized
                .contains((pay.termId ?? '').trim().toLowerCase()))
            .toList();

    // Build grouped payments per student per purpose+term key:
    // studentKey -> { '${purposeNameKey}:::${termIdKey}': paidAmount }
    final Map<String, Map<String, double>>
        groupedPaymentsByStudentAndPurposeTerm = {};
    for (var payment in filteredPaymentsForSelectedTerms) {
      final studentKey =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final purposeKey = (payment.paymentPurpose ?? '').trim().toLowerCase();
      final termKey = (payment.termId ?? '').trim().toLowerCase();
      final compositeKey =
          '${normalize(payment.paymentPurpose)}:::${normalize(payment.termId ?? '')}';
      final double paid = payment.amountToPay ?? 0.0;

      groupedPaymentsByStudentAndPurposeTerm.putIfAbsent(studentKey, () => {});
      groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] =
          (groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] ??
                  0.0) +
              paid;
    }

    // Also create an aggregated student->purposeName (no-term) paid map for totals display (sum across terms)
    final Map<String, Map<String, double>>
        aggregatedPaidByStudentAndPurposeName = {};
    groupedPaymentsByStudentAndPurposeTerm.forEach((studentKey, map) {
      aggregatedPaidByStudentAndPurposeName.putIfAbsent(studentKey, () => {});
      map.forEach((compositeKey, paid) {
        final parts = compositeKey.split(':::');
        final purposeKey = parts[0];
        final displayName =
            normalizedPurposesMap[normalize(purposeKey)] ?? purposeKey;
// preserve casing if available

        aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] =
            (aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] ??
                    0.0) +
                paid;
      });
    });

    // --- Build student map: union of students from allStudents and those appearing in payments.
    final Set<String> studentKeysSet = {};
    // from payments
    for (var payment in filteredPaymentsForSelectedTerms) {
      studentKeysSet.add(
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}');
    }
    // from allStudents store
    for (var s in allStudents) {
      studentKeysSet.add('${s.name.toLowerCase()} ${s.surname.toLowerCase()}');
    }

    // Build a lookup Student map; prefer the student object from allStudents if present, else build a minimal placeholder from a payment record
    final Map<String, Student> studentLookup = {};
    for (var s in allStudents) {
      final key = '${s.name.toLowerCase()} ${s.surname.toLowerCase()}';
      studentLookup[key] = s;
    }
    // If payment has student that isn't in allStudents, create a light placeholder Student (adjust fields if your Student model differs)
    for (var payment in filteredPaymentsForSelectedTerms) {
      final key =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';

      if (!studentLookup.containsKey(key)) {
        studentLookup[key] = Student(
          studentIdNumber:
              'unknown-${payment.studentName}-${payment.studentSurname}-${payment.termId}',
          name: payment.studentName,
          surname: payment.studentSurname,
          class_: payment.studentClass ?? '',
          regNumber: payment.studentRegNumber ?? 'N/A',
          gender: '',
          age: DateTime(1800),
          phoneNumber: '',
          paymentStatus: '',
          exceptions: [],
        );
      }
    }
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Arrears & Payments'];

    // Add headers for the table
    List<CellValue?> headers = [
      TextCellValue('STUDENT NAME'),
      TextCellValue('STUDENT CLASS'),
      ...normalizedPaymentPurposesOnly.map(
        (p) => TextCellValue(
            '$p ARREARS (\$${aggregatedPurposeAmounts[p] ?? 0.0})'),
      ),
      // ✅ NEW — paid-amounts matching same normalizedPaymentPurposesOnly
      // ✅ NEW — PAID HEADERS
      ...normalizedPaymentPurposesOnly.map(
        (p) => TextCellValue(('$p PAID')),
      ),

      TextCellValue('TOTAL ARREARS'),
      TextCellValue('TOTAL PAID'),
    ];
    sheetObject.appendRow(headers);

    // --- Helper functions (reuse existing logic but per-term)
    bool isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.any(
                (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
            false)) continue;
        return true;
      }
      return false;
    }

    double getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;
      String normalizeTerm(String v) {
        return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      for (var studentException in studentExceptions) {
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }
        if (!(studentException.terms
                ?.any((t) => normalizeTerm(t) == normalizeTerm(termId)) ??
            false)) continue;

        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) continue;

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) continue;

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percent = (figure / 100) * (purpose.purposeAmount ?? 0.0);
          totalDeduction += percent;
        }
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);
      return adjusted;
    }

    // Precompute rows
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    // Iterate over students (union)
    for (var studentKey in studentKeysSet.toList()..sort()) {
      final student = studentLookup[studentKey];

      // Skip if student not found
      if (student == null) continue;

      // ✅ Apply CLASS + SURNAME filters
      if (!surnameMatches(student)) continue;
      if (!classMatches(student)) continue;

      final studentClass = student?.class_ ?? '';

      // aggregated per-student paid amounts across selected terms (by display purpose name)
      final studentAggregatedPaid =
          aggregatedPaidByStudentAndPurposeName[studentKey] ?? {};

      final double totalPaidAmount =
          studentAggregatedPaid.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrearsForStudent = 0.0;

      // Build arrears cells for each aggregated purpose (display order: normalizedPaymentPurposesOnly)
      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        final normalizedKey = purposeDisplayName.trim().toLowerCase();
        final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];

        // No underlying purpose → show 0
        if (underlyingPurposes.isEmpty) {
          return const DataCell(Text('0.0'));
        }

        /*
  ─────────────────────────────────────────────
  HELPERS
  ─────────────────────────────────────────────
  */

        bool isPurposeApplicableForStudent(PaymentPurpose p, Student s) {
          final studentTerms =
              s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
          final purposeTerm = (p.termId ?? '').trim().toLowerCase();
          return studentTerms.contains(purposeTerm);
        }

        bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
          final classes = p.associatedClasses ?? [];
          if (classes.isEmpty) return false;

          final studentClass = s.class_?.trim().toLowerCase();
          return classes
              .map((c) => c.trim().toLowerCase())
              .contains(studentClass);
        }

        bool isPurposeAllowed(PaymentPurpose p, Student s) {
          // Must first be allowed by class
          if (!isPurposeAllowedByClass(p, s)) return false;

          // Newcomer-only – must pass eligibility
          if (p.forNewcomersOnly == true) {
            final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
            return isNewcomerEligible(s, p, termObj);
          }

          return true;
        }

        PaymentPurpose? findFirstUnpaidPurposeForStudent(
          Student student,
          List<PaymentPurpose> purposes,
          Map<String, Map<String, double>> paidMap,
          String termId,
        ) {
          for (var p in purposes) {
            if ((p.termId ?? '').trim().toLowerCase() != termId) continue;

            final compositeKey =
                '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
            final paid = paidMap[studentKey]?[compositeKey] ?? 0.0;
            final amount = p.purposeAmount ?? 0.0;

            if (paid < amount) return p;
          }
          return null;
        }

        bool isPurposeApplicableForStudentByName(
          Student s,
          String purposeDisplayName,
        ) {
          final normalizedKey = purposeDisplayName.trim().toLowerCase();
          final list = purposeNameToList[normalizedKey];
          if (list == null) return false;

          for (var p in list) {
            // Must match student class
            final classes = p.associatedClasses ?? [];
            if (classes.isNotEmpty &&
                classes
                    .map((c) => c.trim().toLowerCase())
                    .contains((s.class_ ?? '').trim().toLowerCase())) {
              // ✅ If newcomer purpose → check eligibility
              if (p.forNewcomersOnly == true) {
                final termKey = (p.termId ?? '').trim().toLowerCase();
                final termObj = _termMap[termKey];
                if (!isNewcomerEligible(s, p, termObj)) {
                  continue;
                }
              }

              // ✅ Must match student term
              final studentTerms =
                  s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
              if (!studentTerms
                  .contains((p.termId ?? '').trim().toLowerCase())) {
                continue;
              }

              return true;
            }
          }
          return false;
        }

        /*
  ─────────────────────────────────────────────
  MAIN ARREARS SUMMATION
  ─────────────────────────────────────────────
  */

        double aggregatedArrearForThisPurpose = 0.0;

        // Precompute first unpaid purpose per term
        Map<String, PaymentPurpose?> firstUnpaidPerTerm = {};
        for (var p in underlyingPurposes) {
          final termNorm = (p.termId ?? '').trim().toLowerCase();
          firstUnpaidPerTerm[termNorm] ??= findFirstUnpaidPurposeForStudent(
            student!,
            underlyingPurposes,
            groupedPaymentsByStudentAndPurposeTerm,
            termNorm,
          );
        }
        for (var up in underlyingPurposes) {
          final termIdNorm = (up.termId ?? '').trim().toLowerCase();

          // Class + newcomer eligibility check
          if (!isPurposeAllowed(up, student!)) continue;

          // Check term association
          if (!isPurposeApplicableForStudent(up, student)) continue;

          // Newcomer-only logic — only first unpaid counts
          if (up.forNewcomersOnly == true) {
            final firstUnpaid = firstUnpaidPerTerm[termIdNorm];
            if (firstUnpaid == null || firstUnpaid != up) {
              continue; // skip any other newcomer purpose
            }
          }

          final compositeKey =
              '${normalize(up.paymentPurpose)}:::${normalize(up.termId ?? '')}';

          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;

          final double purposeAmount = up.purposeAmount ?? 0.0;
          double arrear = (purposeAmount - paid).clamp(0.0, purposeAmount);

          // Re-check newcomer eligibility
          if (up.forNewcomersOnly == true) {
            final termObj = _termMap[termIdNorm];
            if (!isNewcomerEligible(student!, up, termObj)) {
              arrear = 0.0;
            }
          }

          // Apply exceptions if any
          if (up.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(arrear, student!, up, up.termId ?? '');
          }

          if (up.forNewcomersOnly == true) {
            // --- aggregate newcomer total amount for this purpose across terms
            double totalNominalAmount = underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)
                .map((p) => p.purposeAmount ?? 0.0)
                .fold<double>(double.infinity, (a, b) => a < b ? a : b);

            if (totalNominalAmount == double.infinity) {
              totalNominalAmount = 0.0;
            }

            // --- aggregate payments across ALL terms for this newcomer purpose
            double totalPaid = 0.0;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              final ck =
                  '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
              totalPaid += groupedPaymentsByStudentAndPurposeTerm[studentKey]
                      ?[ck] ??
                  0.0;
            }

            double rawArrear = (totalNominalAmount - totalPaid);
            if (rawArrear < 0) rawArrear = 0;

            // ✅ exceptions
            double adjustedArrear = rawArrear;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              adjustedArrear = getAdjustedArrear(
                adjustedArrear,
                student!,
                p,
                p.termId ?? '',
              );
            }
            adjustedArrear = adjustedArrear.clamp(0.0, totalNominalAmount);

            // ✅ Update once only
            aggregatedArrearForThisPurpose = adjustedArrear;

            // ✅ Done → skip sub-iteration of other newcomer entries
            break;
          }

          aggregatedArrearForThisPurpose += arrear;
        }

        /*
  ─────────────────────────────────────────────
  VISIBILITY / TOTAL UPDATES
  ─────────────────────────────────────────────
  */

        // If no underlying purpose is allowed → blank
        final allowed =
            underlyingPurposes.any((p) => isPurposeAllowed(p, student!));
        if (!allowed) {
          return const DataCell(Text(""));
        }

        // Update totals
        totalArrearsForStudent += aggregatedArrearForThisPurpose;
        grandTotalArrears += aggregatedArrearForThisPurpose;
        grandTotalPurposeArrears[purposeDisplayName] =
            (grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) +
                aggregatedArrearForThisPurpose;

        return DataCell(
          Text(aggregatedArrearForThisPurpose.toStringAsFixed(2)),
        );
      }).toList();
      // Paid cells for selected payment purposes (if you still want them)
      final List<DataCell> paidCells = _selectedPaymentPurposes.map((purpose) {
        final paidAmount = studentAggregatedPaid[purpose] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      // Arrear filter logic (same as before)
      bool matchesFilter = true;
      switch (_selectedArrearFilter) {
        case 'Arrears Only':
          matchesFilter = totalArrearsForStudent > 0;
          break;
        case 'Fully Paid':
          matchesFilter = totalArrearsForStudent == 0;
          break;
        case 'Overpaid / Credit':
          matchesFilter = totalArrearsForStudent < 0;
          break;
        case 'Custom Range':
          if (_arrearMin != null && _arrearMax != null) {
            matchesFilter = totalArrearsForStudent >= _arrearMin! &&
                totalArrearsForStudent <= _arrearMax!;
          }
          break;
        default:
          matchesFilter = true;
      }
      if (!matchesFilter) continue;

      sheetObject.appendRow([
        TextCellValue(studentKey),
        TextCellValue(studentClass),

        ...arrearsCells.map((cell) {
          final textWidget = cell.child;
          if (textWidget is Text) {
            final originalText = textWidget.data ?? '';
            // ✅ keep blank → blank
            if (originalText.trim().isEmpty) {
              return TextCellValue("");
            }
            final parsed = double.tryParse(originalText) ?? 0.0;
            final displayValue =
                parsed > 0.0 ? (-parsed).toStringAsFixed(2) : '0.0';
            return TextCellValue((displayValue));
          } else {
            return TextCellValue(('0.0'));
          }
        }),
        // ✅ NEW — paid-amounts matching same normalizedPaymentPurposesOnly

        ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
          final paidAmount = studentAggregatedPaid[purposeDisplayName] ?? 0.0;

          grandTotalPurposePaid[purposeDisplayName] =
              (grandTotalPurposePaid[purposeDisplayName] ?? 0.0) + paidAmount;

          return TextCellValue((paidAmount.toStringAsFixed(2)));
        }),

        TextCellValue((totalArrearsForStudent > 0.0
            ? '-${totalArrearsForStudent.abs().toStringAsFixed(2)}'
            : '0.0')),
        TextCellValue((totalPaidAmount.toStringAsFixed(2))),
      ]);
    }
    // Add the grand totals row to the spreadsheet
    sheetObject.appendRow([
      TextCellValue('GRAND TOTALS'),
      TextCellValue(''), // Empty cell for student class

      ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        return TextCellValue(
          ((grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) > 0.0)
              ? '-${(grandTotalPurposeArrears[purposeDisplayName] ?? 0.0).abs().toStringAsFixed(2)}'
              : '0.0',
        );
      }),
      // ✅ PAID Columns

      ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        return TextCellValue(
          (grandTotalPurposePaid[purposeDisplayName] ?? 0.0).toStringAsFixed(2),
        );
      }),
      TextCellValue(
        '-${grandTotalArrears.toStringAsFixed(2)}',
      ),
      TextCellValue(
        grandTotalPaid.toStringAsFixed(2),
      ),
    ]);

    // Save the Excel file

    try {
      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception("Excel encoding failed.");

      if (Platform.isAndroid) {
        // Get app's scoped documents directory
        final directory = await getApplicationDocumentsDirectory();
        final folder = Directory(
            '${directory.path}/school_files/student_payments_reports');

        // Create folder if not exists
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        // Generate unique file name with timestamp
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath =
            '${folder.path}/student_payments_reports_$timestamp.xlsx';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        print('✅ Spreadsheet saved to: $filePath');
      } else {
        // Use FilePicker to choose save location

        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel File',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          fileName: 'student_payments_and_arrears.xlsx',
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
      }
    } catch (e) {
      print('Error saving spreadsheet: $e');
    }
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _regNumberController.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();

    super.dispose();
  }
}

/*





import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/all_payments/filter_payments.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:path/path.dart' as path;
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart';
import 'package:zitf_system/student_payments/view_all_paid_students.dart'; // To handle file name extensions

class ArrearsAndPrepayments extends StatefulWidget {
  const ArrearsAndPrepayments({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ArrearsAndPrepayments> {
  String? _selectedStudent;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedSortOption = 'Surname'; // Default sort option
  bool _isSortAscending = true;

  List<StudentPayment> _filteredPayments = [];
  List<PaymentPurpose> filteredPaymentPurposesOnly = [];

  Map<String, double> _paymentPurposeAmounts = {};

  List<String> _selectedClasses = [];
  List<String> _selectedPaymentPurposes = [];
  String _selectedArrearFilter = 'All';
  double? _arrearMin;
  double? _arrearMax;

  List<String> _paymentPurposesOnly = [];
  List<String> _selectedPaymentPurposesArrears = [];

  List<String> _classes = [];
  List<String> _purposes = [];
  List<String> _purposesOnly = [];
  List<String> _terms = []; // Declare without 'final'

  // Maps for holding payment data
  Map<String, Map<String, double>> groupedPayments = {};
  Map<String, Map<String, double>> totalPaid = {};
  final TextEditingController _surnameController = TextEditingController();

  final TextEditingController _regNumberController = TextEditingController();
  late final ScrollController horizontalScrollController;
  late final ScrollController verticalScrollController;
  String normalize(String input) => input.trim().toLowerCase();
  Map<String, Terms> _termMap = {};
  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;

  List<StudentPayment>? _cachedFilteredStudents;

  Set<String> processedTerms = {};

  final Map<String, Map<String, double>> termTotalsByPurpose = {};
  final Map<String, double> termTotalsGrand = {};

  bool _showArrears = true;
  bool _showPayments = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    fetchTerms();
    horizontalScrollController = ScrollController();
    verticalScrollController = ScrollController();
  }

  List<String> _selectedTermIds = [];

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Arrears Manipulation Feedback"),
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

  Future<void> fetchTerms() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termBox = await Hive.openBox<Terms>('terms');

        allTerms = termBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerTerms == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
      }

      if (allTerms.isNotEmpty) {
        _terms = allTerms.map((term) => term.termId).toSet().toList();
        _terms.sort();
      } else {
        _terms = [];
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

// Example of using currentTermId in a method
  void filterByTerm() {
    if (_selectedTermIds.isEmpty) return;

    _filteredPayments = _filteredPayments.where((payment) {
      return _selectedTermIds.contains(payment.termId);
    }).toList();

    setState(() {});
  }

  Future<void> _initializeData() async {
    await _fetchInitialData();
  }

  String _capitalizeEachWord(String input) {
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _fetchInitialData() async {
    try {
      debugPrint("🟨 Starting _fetchInitialData");

      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];
      List<PaymentPurpose> allStudentPaymentPurposes = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();

        final paymentPurposeBox =
            await Hive.openBox<PaymentPurpose>('payment_purposes');

        allStudentPaymentPurposes = paymentPurposeBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        debugPrint("🌐 Fetching from server (client) - Host IP: $_hostIp");

        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerStudentPayments == null) {
          final studentPaymentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (studentPaymentsResponse.statusCode == 200) {
            final studentPaymentsJsonString =
                await studentPaymentsResponse.transform(utf8.decoder).join();

            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load student Payments data from host.");
          }
        }
        if (_cachedServerStudentPaymentPurposes == null) {
          final studentPaymentPurposesResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
              .then((req) => req.close());

          if (studentPaymentPurposesResponse.statusCode == 200) {
            final studentPaymentPurposesJsonString =
                await studentPaymentPurposesResponse
                    .transform(utf8.decoder)
                    .join();

            final studentPaymentPurposesList =
                jsonDecode(studentPaymentPurposesJsonString) as List;

            _cachedServerStudentPaymentPurposes = studentPaymentPurposesList
                .map((json) =>
                    paymentPurposesFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load payment Purposes data from host.");
          }
        }
        allStudentPayments = _cachedServerStudentPayments!;
        allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
      }

      final selectedTerms = _selectedTermIds;

      List<StudentPayment> filteredPayments;
      List<PaymentPurpose> filteredPaymentPurposesOnly;

      if (selectedTerms.isEmpty) {
        // ✅ nothing selected → no term filter
        filteredPayments = allStudentPayments;
        filteredPaymentPurposesOnly = allStudentPaymentPurposes;
      } else {
        filteredPayments = allStudentPayments
            .where((p) => selectedTerms.contains(p.termId))
            .toList();

        filteredPaymentPurposesOnly = allStudentPaymentPurposes
            .where((p) => selectedTerms.contains(p.termId))
            .toList();
      }

      final classSet = filteredPayments
          .map((student) => student.studentClass.trim().toLowerCase())
          .toSet();

      _classes = ['All'];
      _classes.addAll(classSet.map((c) => _capitalizeEachWord(c)).toList());

      _selectedClasses = ['All']; // Default selection

      // Fetch unique payment purposes from filtered payments
      _purposes = ['All'];
      try {
        _purposes.addAll(filteredPayments
            .map((student) => student.paymentPurpose)
            .whereType<String>()
            .toSet()
            .toList());
      } catch (e) {
        debugPrint("❌ Error while populating _purposes: $e");
        rethrow;
      }
      _selectedPaymentPurposes = ['All']; // Default selection

      // Fetch unique classes from filtered payments
      _purposesOnly = ['All'];

      try {
        _purposesOnly.addAll(filteredPaymentPurposesOnly
            .map((student) => student.paymentPurpose)
            .whereType<String>()
            .toSet()
            .toList());
      } catch (e) {
        debugPrint("❌ Error while populating _purposesOnly: $e");
        rethrow;
      }
      _selectedPaymentPurposesArrears = ['All']; // Default selection

      // ✅ payment purpose → amount map
      _paymentPurposeAmounts.clear();
      for (var p in filteredPaymentPurposesOnly) {
        _paymentPurposeAmounts[p.paymentPurpose] = p.purposeAmount;
      }

      // Fetch payment purpose only amounts
      _filteredPayments = filteredPayments;
      // Sort students by surname
      _filteredPayments.sort((a, b) => _isSortAscending
          ? a.studentSurname.compareTo(b.studentSurname)
          : b.studentSurname.compareTo(a.studentSurname));

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterPayments(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<StudentPayment>('student_payments');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _filterPayments() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];
      List<Student> allStudents = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();

        final studentBox = await Hive.openBox<Student>('students');

        allStudents = studentBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerStudentPayments == null) {
          final studentPaymentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (studentPaymentsResponse.statusCode == 200) {
            final studentPaymentsJsonString =
                await studentPaymentsResponse.transform(utf8.decoder).join();

            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load student Payments data from host.");
          }
        }
        if (_cachedServerStudents == null) {
          final studentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/students'))
              .then((req) => req.close());

          if (studentsResponse.statusCode == 200) {
            final studentsString =
                await studentsResponse.transform(utf8.decoder).join();

            final studentsList = jsonDecode(studentsString) as List;

            _cachedServerStudents = studentsList
                .map(
                    (json) => studentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load students data from host.");
          }
        }
        allStudentPayments = _cachedServerStudentPayments!;
        allStudents = _cachedServerStudents!;
      }

      final selectedTerms = _selectedTermIds;

      List<StudentPayment> filteredPayments;
      List<Student> filteredStudents;

      if (selectedTerms.isEmpty) {
        // ✅ no selection → do not term filter
        filteredPayments = allStudentPayments;
        filteredStudents = allStudents;
      } else {
        filteredPayments = allStudentPayments
            .where((p) => selectedTerms.contains(p.termId))
            .toList();

        filteredStudents = allStudents
            .where((s) => s.terms!.any((t) => selectedTerms.contains(t)))
            .toList();
      }
      // Build paymentRecords for matching only selectedTerms
      List<StudentPayment> paymentRecords = filteredPayments;

      // Build student list, apply class filter
      List<Student> studentRecords = filteredStudents;

// Build student list, apply class filter

      if (_selectedClasses.isNotEmpty &&
          !_selectedClasses.any((c) => c.toLowerCase() == 'all')) {
        final classKeys = _selectedClasses.map((c) => c.toLowerCase()).toSet();

        studentRecords = studentRecords.where((s) {
          return classKeys.contains(s.class_.trim().toLowerCase());
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ MERGE — ensure every student has at least 1 record
      //-----------------------------------------------------

      List<StudentPayment> combined = [];

      for (var student in studentRecords) {
        final payments = paymentRecords.where((p) =>
            p.studentName.toLowerCase() == student.name.toLowerCase() &&
            p.studentSurname.toLowerCase() == student.surname.toLowerCase() &&
            p.studentClass.trim().toLowerCase() ==
                student.class_.trim().toLowerCase());

        if (payments.isEmpty) {
          // ✅ create virtual record
          int newId = await getNextId();
          String receipt = uuid.v4();

          combined.add(
            StudentPayment(
              id: newId,
              receiptNumber: receipt,
              studentName: student.name,
              studentSurname: student.surname,
              studentClass: student.class_,
              termId: selectedTerms.isNotEmpty ? selectedTerms.first : null,
              phoneNumber: student.phoneNumber,
              paymentPurpose: '',
              amountToPay: 0.0,
              paymentDate: DateTime.now(),
              syncStatus: false,
              lastModified: DateTime.now(),
              operationType: 'create',
              modifiedFields: [
                'id',
                'receiptNumber',
                'studentName',
                'studentSurname',
                'studentClass',
                'phoneNumber',
                'paymentPurpose',
                'amountToPay',
                'paymentDate',
                'termId',
              ],
            ),
          );
        } else {
          combined.addAll(payments);
        }
      }

      // Now, _filteredPayments contains students even if they have no payment.
      _filteredPayments = combined;

      //-----------------------------------------------------
      // ✅ SEARCH FILTER
      //-----------------------------------------------------
      if (_selectedStudent != null && _selectedStudent!.trim().isNotEmpty) {
        final query = _selectedStudent!.trim().toLowerCase();
        _filteredPayments = _filteredPayments.where((p) {
          final full = '${p.studentName} ${p.studentSurname}'.toLowerCase();
          return full.contains(query);
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ PURPOSE FILTER
      //-----------------------------------------------------
      if (_selectedPaymentPurposes.isNotEmpty &&
          !_selectedPaymentPurposes.contains("All")) {
        _filteredPayments = _filteredPayments.where((p) {
          return _selectedPaymentPurposes.contains(p.paymentPurpose);
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ DATE FILTER
      //-----------------------------------------------------
      if (_selectedStartDate != null || _selectedEndDate != null) {
        _filteredPayments = _filteredPayments.where((p) {
          final d = p.paymentDate;
          if (_selectedStartDate != null && _selectedEndDate != null) {
            return d.isAfter(_selectedStartDate!) &&
                d.isBefore(_selectedEndDate!);
          } else if (_selectedStartDate != null) {
            return d.isAfter(_selectedStartDate!);
          } else if (_selectedEndDate != null) {
            return d.isBefore(_selectedEndDate!);
          }
          return true;
        }).toList();
      }

      //-----------------------------------------------------
      // ✅ SORT
      //-----------------------------------------------------
      if (_selectedSortOption == 'Surname') {
        _filteredPayments.sort((a, b) => a.studentSurname
            .toLowerCase()
            .compareTo(b.studentSurname.toLowerCase()));
      } else if (_selectedSortOption == 'First Name') {
        _filteredPayments.sort((a, b) =>
            a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));
      }

      //-----------------------------------------------------
      // ✅ GROUP + TOTALS
      //-----------------------------------------------------
      _calculateGroupedPayments();
      _calculateTotalPaid();
      _calculateTermTotals(); // ✅ add this

      setState(() {});
    } catch (e) {
      debugPrint("❌ Error filtering payments: $e");
      setState(() {});
    }
  }

  void _calculateGroupedPayments() {
    groupedPayments.clear();
    for (var payment in _filteredPayments) {
      final studentName =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final paymentPurposeKey = payment.paymentPurpose.toLowerCase();
      final amountToPay = payment.amountToPay.toDouble();
      groupedPayments.putIfAbsent(studentName, () => {});
      groupedPayments[studentName]!.putIfAbsent(paymentPurposeKey, () => 0.0);

      groupedPayments[studentName]![paymentPurposeKey] =
          (groupedPayments[studentName]![paymentPurposeKey] ?? 0.0) +
              amountToPay;
    }
  }

  void _calculateTotalPaid() {
    totalPaid.clear();
    for (var payment in _filteredPayments) {
      final studentName =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final paymentPurposeKey = payment.paymentPurpose.toLowerCase();
      final amountPaid = payment.amountToPay.toDouble();
      totalPaid.putIfAbsent(studentName, () => {});
      totalPaid[studentName]!.putIfAbsent(paymentPurposeKey, () => 0.0);

      totalPaid[studentName]![paymentPurposeKey] =
          (totalPaid[studentName]![paymentPurposeKey] ?? 0.0) + amountPaid;
    }
  }

  void _calculateTermTotals() {
    termTotalsByPurpose.clear();
    termTotalsGrand.clear();

    for (var p in _filteredPayments) {
      final term = (p.termId ?? "").trim().toLowerCase();
      if (term.isEmpty) continue;

      final purpose = (p.paymentPurpose ?? "").trim().toLowerCase();
      final amount = (p.amountToPay ?? 0.0);

      // Purpose per term
      termTotalsByPurpose.putIfAbsent(term, () => {});
      termTotalsByPurpose[term]!.putIfAbsent(purpose, () => 0.0);
      termTotalsByPurpose[term]![purpose] =
          (termTotalsByPurpose[term]![purpose] ?? 0.0) + amount;

      // Term grand total
      termTotalsGrand[term] = (termTotalsGrand[term] ?? 0.0) + amount;
    }
  }

  Future<Uint8List> generateStudentsPDF(
      List<StudentPayment> studentPayments) async {
    final pdf = pw.Document();
    final headerTextStyle =
        pw.TextStyle(fontSize: 6.0, fontWeight: pw.FontWeight.bold);
    const cellTextStyle = pw.TextStyle(fontSize: 6.0);
    const chunkSize = 300;

    final normalizedPurposesMap = {
      for (var p in _paymentPurposesOnly) p.toLowerCase(): p
    };
    final normalizedPaymentPurposesOnly = normalizedPurposesMap.values.toList();

    final normalizedSelectedMap = {
      for (var p in _selectedPaymentPurposes) p.toLowerCase(): p
    };
    final normalizedSelectedPaymentPurposes =
        normalizedSelectedMap.values.toList();

    _role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
    List<StudentPayment> allStudentPayments = [];
    List<Student> allStudents = [];
    List<PaymentPurpose> allStudentPaymentPurposes = [];

    if (_role == DeviceRole.host) {
      final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

      allStudentPayments = paymentBox.values.toList();

      final studentBox = await Hive.openBox<Student>('students');

      allStudents = studentBox.values.toList();

      final paymentPurposeBox =
          await Hive.openBox<PaymentPurpose>('payment_purposes');

      allStudentPaymentPurposes = paymentPurposeBox.values.toList();
    } else {
      if (_cachedServerStudentPayments == null) {
        final studentPaymentsResponse = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
            .then((req) => req.close());

        if (studentPaymentsResponse.statusCode == 200) {
          final studentPaymentsJsonString =
              await studentPaymentsResponse.transform(utf8.decoder).join();

          final studentPaymentsList =
              jsonDecode(studentPaymentsJsonString) as List;

          _cachedServerStudentPayments = studentPaymentsList
              .map((json) =>
                  studentPaymentsFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception("Failed to load student Payments data from host.");
        }
      }
      if (_cachedServerStudents == null) {
        final studentsResponse = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/students'))
            .then((req) => req.close());

        if (studentsResponse.statusCode == 200) {
          final studentsString =
              await studentsResponse.transform(utf8.decoder).join();

          final studentsList = jsonDecode(studentsString) as List;

          _cachedServerStudents = studentsList
              .map((json) => studentsFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception("Failed to load students data from host.");
        }
      }
      if (_cachedServerStudentPaymentPurposes == null) {
        final studentPaymentPurposesResponse = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (studentPaymentPurposesResponse.statusCode == 200) {
          final studentPaymentPurposesJsonString =
              await studentPaymentPurposesResponse
                  .transform(utf8.decoder)
                  .join();

          final studentPaymentPurposesList =
              jsonDecode(studentPaymentPurposesJsonString) as List;

          _cachedServerStudentPaymentPurposes = studentPaymentPurposesList
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception("Failed to load payment Purposes data from host.");
        }
      }
      allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
      allStudentPayments = _cachedServerStudentPayments!;
      allStudents = _cachedServerStudents!;
    }
    final Map<String, PaymentPurpose> cachedPurposes = {
      for (var p in allStudentPaymentPurposes)
        p.paymentPurpose.toLowerCase(): p,
    };

    final allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };
    final studentLookup = {
      for (var s in Hive.box<Student>('students').values)
        '${s.name.toLowerCase()} ${s.surname.toLowerCase()}': s,
    };

    bool isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      return (student.exceptions ?? []).any((e) =>
          e.exceptionStatus?.toLowerCase() == 'active' &&
          (e.terms?.contains(termId) ?? false));
    }

    double getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];
      double totalDeduction = 0.0;

      for (var ex in studentExceptions) {
        if (ex.exceptionStatus?.toLowerCase() != 'active') continue;
        if (!(ex.terms?.contains(termId) ?? false)) continue;
        if (!applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == ex.exceptionId)) continue;

        final figure = double.tryParse(ex.exceptionFigure ?? '');
        if (figure == null) continue;

        totalDeduction += ex.exceptionType?.toLowerCase() == 'amount'
            ? figure
            : arrear * (figure / 100.0);
      }

      return (arrear - totalDeduction).clamp(0.0, arrear);
    }

    final dataRows = <List<dynamic>>[];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    for (var entry in allStudentsMap.entries) {
      final studentKey = entry.key;
      final studentPayment = entry.value;
      final student = studentLookup[studentKey];
      if (student == null) continue;

      final studentData = groupedPayments[studentKey] ?? {};
      final paidTotals = totalPaid[studentKey] ?? {};

      final totalPaidAmount = paidTotals.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;
      double totalArrears = 0.0;

      final arrearsCells = normalizedPaymentPurposesOnly.map((purposeName) {
        final purpose = cachedPurposes[purposeName.toLowerCase()];
        if (purpose == null) return 'N/A';

        final isClassFilterAll = _selectedClasses.isEmpty;

        final isExceptional = (purpose.exceptions?.isNotEmpty ?? false);
        final isNewcomerOnly = purpose.forNewcomersOnly ?? false;
        final classMatch = purpose.associatedClasses?.any((cls) =>
                cls.trim().toLowerCase() ==
                student.class_.trim().toLowerCase()) ??
            false;

        if (isClassFilterAll) {
          final hasClass = purpose.associatedClasses?.isNotEmpty ?? false;
          if (!hasClass && !isExceptional && isNewcomerOnly != true)
            return '0.0';
        } else if (!classMatch) return '0.0';

        final amount = _paymentPurposeAmounts[purposeName] ?? 0.0;
        final paid = studentData[purposeName.toLowerCase()] ?? 0.0;
        double arrear = (amount - paid).clamp(0.0, amount);
        if (purpose.forNewcomersOnly == true) {
          final term = _termMap[purpose.termId?.trim().toLowerCase() ?? ''];
          if (!isNewcomerEligible(student, purpose, term)) {
            arrear = 0.0;
          }
        }
        String?
            selectedTermId; // This will store the term ID selected by the user.
        String? getCurrentTermId() {
          return selectedTermId ?? globalTermId;
        }

        if (isExceptional) {
          arrear = getAdjustedArrear(arrear, student, purpose,
              selectedTermId ?? globalTermId.toString());
        }

        totalArrears += arrear;
        grandTotalArrears += arrear;
        grandTotalPurposeArrears[purposeName] =
            (grandTotalPurposeArrears[purposeName] ?? 0.0) + arrear;

        return arrear.toStringAsFixed(2);
      }).toList();

      final paidCells = normalizedSelectedPaymentPurposes.map((p) {
        final paid = studentData[p] ?? 0.0;
        grandTotalPurposePaid[p] = (grandTotalPurposePaid[p] ?? 0.0) + paid;
        return paid.toStringAsFixed(2);
      }).toList();

      dataRows.add([
        studentKey,
        student.class_,
        ...arrearsCells.map((value) {
          final parsed = double.tryParse(value.toString()) ?? 0.0;
          final displayValue =
              parsed > 0.0 ? (-parsed).toStringAsFixed(2) : '0.0';
          return displayValue;
        }),
        totalArrears > 0.0 ? '-${totalArrears.toStringAsFixed(2)}' : '0.0',
        ...paidCells,
        totalPaidAmount.toStringAsFixed(2),
      ]);
    }

    final grandTotalPaidRow = [
      'GRAND TOTALS',
      '',
      ...normalizedPaymentPurposesOnly
          .map((p) => (grandTotalPurposeArrears[p] ?? 0.0).toStringAsFixed(2)),
      '-${grandTotalArrears.toStringAsFixed(2)}',
      ...normalizedSelectedPaymentPurposes
          .map((p) => (grandTotalPurposePaid[p] ?? 0.0).toStringAsFixed(2)),
      grandTotalPaid.toStringAsFixed(2),
    ];

    for (int i = 0; i < dataRows.length; i += chunkSize) {
      final chunk = dataRows.skip(i).take(chunkSize).toList();
      final fullData = i + chunkSize >= dataRows.length
          ? [...chunk, grandTotalPaidRow]
          : chunk;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            if (i == 0)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Incomes Information',
                      style: const pw.TextStyle(fontSize: 24)),
                  pw.SizedBox(height: 20),
                ],
              ),
            pw.Table.fromTextArray(
              headers: [
                'Student Name',
                'Student Class',
                ...normalizedPaymentPurposesOnly.map((p) => '$p (Arrears)'),
                'TOTAL ARREARS',
                ...normalizedSelectedPaymentPurposes.map((p) => '$p (Paid)'),
                'TOTAL PAID',
              ],
              data: fullData,
              cellStyle: const pw.TextStyle(fontSize: 6),
              headerStyle:
                  pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.black),
              columnWidths: {
                for (var i = 0;
                    i <
                        normalizedPaymentPurposesOnly.length +
                            normalizedSelectedPaymentPurposes.length +
                            4;
                    i++)
                  i: const pw.FlexColumnWidth(),
              },
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  Widget _buildTermPaymentsTable() {
    final normalizedPurposes = _purposesOnly
        .where((p) => p != 'All')
        .map((p) => p.toLowerCase())
        .toList();

    List<DataRow> rows = [];

    termTotalsByPurpose.forEach((term, purposeMap) {
      rows.add(
        DataRow(
          cells: [
            DataCell(Text(term.toUpperCase())),

            // each purpose → value
            ...normalizedPurposes.map((purpose) {
              final amount = purposeMap[purpose] ?? 0.0;
              return DataCell(Text(amount.toStringAsFixed(2)));
            }),

            // total per term
            DataCell(Text((termTotalsGrand[term] ?? 0.0).toStringAsFixed(2))),
          ],
        ),
      );
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text("TERM")),
          ...normalizedPurposes
              .map((p) => DataColumn(label: Text(_capitalizeEachWord(p)))),
          const DataColumn(label: Text("TOTAL")),
        ],
        rows: rows,
      ),
    );
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
          'Arrears And Payments',
          style: TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          Tooltip(
            message: 'View Payment Receipts',
            child: IconButton(
              icon: const Icon(
                Icons.payment_outlined,
                color: Color.fromARGB(255, 242, 255, 0),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewAllStudentPayments(),
                  ),
                );
              },
            ),
          ),
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
          /* IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              Uint8List pdfBytes = await generateStudentsPDF(
                  _cachedFilteredStudents ?? _filteredPayments);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(
                    context, pdfBytes, 'payments_and_arrears_report');
              }
            },
          ),*/
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
                    title: 'Select Term(s)',
                    child: InkWell(
                      onTap: () async {
                        final selected = await showDialog<List<String>>(
                          context: context,
                          builder: (context) {
                            final temp =
                                List<String>.from(_selectedTermIds ?? []);

                            return StatefulBuilder(
                              builder: (context, setStateLocal) {
                                return AlertDialog(
                                  title: const Text("Select Terms"),
                                  content: SizedBox(
                                    width: 300,
                                    height: 400,
                                    child: ListView(
                                      children: _terms.map((term) {
                                        return CheckboxListTile(
                                          title: Text(term),
                                          value: temp.contains(term),
                                          onChanged: (val) {
                                            if (val == true) {
                                              temp.add(term);
                                            } else {
                                              temp.remove(term);
                                            }

                                            // ✅ triggers UI refresh
                                            setStateLocal(() {});
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"),
                                      onPressed: () =>
                                          Navigator.pop(context, null),
                                    ),
                                    ElevatedButton(
                                      child: const Text("OK"),
                                      onPressed: () =>
                                          Navigator.pop(context, temp),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                        String?
                            selectedTermId; // This will store the term ID selected by the user.
                        String? getCurrentTermId() {
                          return selectedTermId ?? globalTermId;
                        }

                        if (selected != null) {
                          setState(() {
                            _selectedTermIds = selected;
                            selectedTermId = null;
                            _selectedClasses = ['All'];
                            _selectedPaymentPurposes = ['All'];
                            _selectedStudent = '';
                            _selectedStartDate = null;
                            _selectedEndDate = null;
                            _surnameController.clear();
                            _filteredPayments = [];
                          });

                          await Future.delayed(Duration.zero);
                          await _fetchInitialData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          //border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (_selectedTermIds == null ||
                                  _selectedTermIds!.isEmpty)
                              ? "Select Terms"
                              : _selectedTermIds!.join(", "),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  _buildCard(
                    title: 'View by Class',
                    child: _buildClassDropdown(),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    title: 'View by Student Surname',
                    child: _buildSearchStudentField(),
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    value: _selectedArrearFilter,
                    items: const [
                      DropdownMenuItem(
                          value: 'All', child: Text('All Students')),
                      DropdownMenuItem(
                          value: 'Arrears Only', child: Text('Arrears Only')),
                      DropdownMenuItem(
                          value: 'Fully Paid', child: Text('Fully Paid')),
                      DropdownMenuItem(
                          value: 'Overpaid / Credit',
                          child: Text('Overpaid / Credit')),
                      DropdownMenuItem(
                          value: 'Custom Range', child: Text('Custom Range')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedArrearFilter = value!;
                        if (value != 'Custom Range') {
                          _arrearMin = null;
                          _arrearMax = null;
                        }
                      });
                    },
                  ),
                  if (_selectedArrearFilter == 'Custom Range') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            decoration:
                                const InputDecoration(labelText: 'Min Arrear'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _arrearMin = double.tryParse(value);
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            decoration:
                                const InputDecoration(labelText: 'Max Arrear'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _arrearMax = double.tryParse(value);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  Row(
                    children: [
                      Checkbox(
                        value: _showArrears,
                        onChanged: (value) {
                          setState(() => _showArrears = value ?? true);
                        },
                      ),
                      const Text("Show Arrears"),
                      const SizedBox(width: 20),
                      Checkbox(
                        value: _showPayments,
                        onChanged: (value) {
                          setState(() => _showPayments = value ?? true);
                        },
                      ),
                      const Text("Show Payments"),
                    ],
                  ),
                  Text(
                    'Records Found: ${_filteredPayments.map((e) => '${e.studentName} ${e.studentSurname}').toSet().length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_filteredPayments.isEmpty) ...[
              const Center(
                child: Text(
                  'No payments found.',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ] else ...[
              _buildPaymentsTable(),
            ],
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
          if (selectedClasses.contains("All")) {
            _selectedClasses = []; // ✅ treat as ALL
          } else {
            _selectedClasses = selectedClasses;
          }
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
      controller: _surnameController,
      decoration: InputDecoration(
        labelText: 'Search Student by Surname',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {});
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

  bool isNewcomerEligible(
    Student student,
    PaymentPurpose purpose,
    Terms? term,
  ) {
    if (student.isNewComer != true ||
        student.isNewComerUntil == null ||
        student.isNewComerFrom == null) {
      return false;
    }

    if (purpose.forNewcomersOnly != true) {
      return true;
    }

    final newcomerUntil = student.isNewComerUntil!;
    final newcomerFrom = student.isNewComerFrom!;

    if (term != null && term.endDate != null) {
      if (term.startDate.isAfter(newcomerUntil) ||
          term.endDate!.isBefore(newcomerFrom)) {
        return false;
      } else {
        return true;
      }
    } else if (term != null && term.startDate != null) {
      if (term.startDate.isAfter(newcomerUntil)) {
        return false;
      } else {
        return true;
      }
    }

    if (purpose.lastModified != null) {
      if (purpose.lastModified!.isAfter(newcomerUntil)) {
        return false;
      }
    }

    return true;
  }

  Widget _buildPaymentsTable() {
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();
    const double scrollIncrement = 100.0;

    void _scrollLeft() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset - scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    void _scrollRight() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset + scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

// --- FILTERING BY CLASS + SURNAME
    bool surnameMatches(Student s) {
      if (_surnameController.text.trim().isEmpty) return true;

      final query = _surnameController.text.trim().toLowerCase();
      return (s.surname ?? '').toLowerCase().contains(query);
    }

    bool classMatches(Student s) {
      if (_selectedClasses.isEmpty) return true;

      final studentClass = (s.class_ ?? "").trim().toLowerCase();
      return _selectedClasses
          .map((c) => c.trim().toLowerCase())
          .contains(studentClass);
    }

    String normalize(String v) {
      return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final List<PaymentPurpose> allPurposes = (_role == DeviceRole.host)
        ? Hive.box<PaymentPurpose>('payment_purposes').values.toList()
        : _cachedServerStudentPaymentPurposes ?? [];

    // --- Determine selected terms (support single-term fallback)
    final List<String> selectedTermIdsNormalized = (() {
      if ((_selectedTermIds).isNotEmpty) {
        return _selectedTermIds
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList();
      } else {
        final selectedTermIdsNormalized = (_selectedTermIds.isNotEmpty)
            ? _selectedTermIds.map((t) => t.trim().toLowerCase()).toList()
            : allPurposes
                .map((p) => (p.termId ?? '').trim().toLowerCase())
                .toSet()
                .toList();

        return selectedTermIdsNormalized;
      }
    })();

    // Normalize _paymentPurposesOnly (preserve first appearance string)
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p;
      }
    }

    // Normalize selected payment purposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }

    // Caches (all stored objects)
    final List<Student> allStudents = (_role == DeviceRole.host)
        ? Hive.box<Student>('students').values.toList()
        : _cachedServerStudents ?? [];

    // --- Collect purposes that belong to ANY selected term
    final List<PaymentPurpose> purposesInSelectedTerms = allPurposes
        .where((p) => selectedTermIdsNormalized
            .contains((p.termId ?? '').trim().toLowerCase()))
        .toList();
    // Group same-name purposes (case-insensitive). For each normalized name we keep the list of underlying PaymentPurpose objects
    final Map<String, List<PaymentPurpose>> purposeNameToList = {};
    for (var p in purposesInSelectedTerms) {
      final nameKey = normalize(p.paymentPurpose);
      if (nameKey.isEmpty) continue;
      purposeNameToList.putIfAbsent(nameKey, () => []).add(p);
    }

    // aggregated display names & aggregated amounts (sum of amounts across terms for same name)
    // Build full union of payment purposes appearing in ANY selected term
    // Payment purposes that exist across any selected terms
    final List<String> normalizedPaymentPurposesOnly = purposeNameToList.keys
        .map((key) {
          return normalizedPurposesMap[key] ?? key;
        })
        .toSet()
        .toList()
      ..sort();

    // aggregated purpose amount map used for header display: normalizedName -> sum(amount)
    final Map<String, double> aggregatedPurposeAmounts = {};
    purposeNameToList.forEach((nameKey, list) {
      double headerAmount = 0.0;

      bool isNewcomer = list.any((p) => p.forNewcomersOnly == true);

      if (isNewcomer) {
        // ✅ All newcomer entries share same nominal amount
        // Use the smallest (safest)
        headerAmount = list
            .map((p) => p.purposeAmount ?? 0.0)
            .where((v) => v > 0)
            .fold<double>(double.infinity, (a, b) => a < b ? a : b);

        if (headerAmount == double.infinity) {
          headerAmount = 0.0;
        }
      } else {
        // ✅ normal → sum
        headerAmount =
            list.fold<double>(0.0, (acc, p) => acc + (p.purposeAmount ?? 0.0));
      }
      final displayName = normalizedPurposesMap[nameKey] ?? nameKey;

      aggregatedPurposeAmounts[displayName] = headerAmount;
    });

    // --- Filter payments to only those in selected terms
    final List<StudentPayment> filteredPaymentsForSelectedTerms =
        _filteredPayments
            .where((pay) => selectedTermIdsNormalized
                .contains((pay.termId ?? '').trim().toLowerCase()))
            .toList();

    // Build grouped payments per student per purpose+term key:
    // studentKey -> { '${purposeNameKey}:::${termIdKey}': paidAmount }
    final Map<String, Map<String, double>>
        groupedPaymentsByStudentAndPurposeTerm = {};
    for (var payment in filteredPaymentsForSelectedTerms) {
      final studentKey =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final purposeKey = (payment.paymentPurpose ?? '').trim().toLowerCase();
      final termKey = (payment.termId ?? '').trim().toLowerCase();
      final compositeKey =
          '${normalize(payment.paymentPurpose)}:::${normalize(payment.termId ?? '')}';
      final double paid = payment.amountToPay ?? 0.0;

      groupedPaymentsByStudentAndPurposeTerm.putIfAbsent(studentKey, () => {});
      groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] =
          (groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] ??
                  0.0) +
              paid;
    }
    // studentKey -> purposeDisplayName -> List<Map<String, double>>
// each entry = { 'termName': ..., 'arrear': ... }

    // Also create an aggregated student->purposeName (no-term) paid map for totals display (sum across terms)
    final Map<String, Map<String, double>>
        aggregatedPaidByStudentAndPurposeName = {};
    groupedPaymentsByStudentAndPurposeTerm.forEach((studentKey, map) {
      aggregatedPaidByStudentAndPurposeName.putIfAbsent(studentKey, () => {});
      map.forEach((compositeKey, paid) {
        final parts = compositeKey.split(':::');
        final purposeKey = parts[0];
        final displayName =
            normalizedPurposesMap[normalize(purposeKey)] ?? purposeKey;
// preserve casing if available

        aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] =
            (aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] ??
                    0.0) +
                paid;
      });
    });

    // --- Build student map: union of students from allStudents and those appearing in payments.
    final Set<String> studentKeysSet = {};
    // from payments
    for (var payment in filteredPaymentsForSelectedTerms) {
      studentKeysSet.add(
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}');
    }
    // from allStudents store
    for (var s in allStudents) {
      studentKeysSet.add('${s.name.toLowerCase()} ${s.surname.toLowerCase()}');
    }

    // Build a lookup Student map; prefer the student object from allStudents if present, else build a minimal placeholder from a payment record
    final Map<String, Student> studentLookup = {};
    for (var s in allStudents) {
      final key = '${s.name.toLowerCase()} ${s.surname.toLowerCase()}';
      studentLookup[key] = s;
    }
    // If payment has student that isn't in allStudents, create a light placeholder Student (adjust fields if your Student model differs)
    for (var payment in filteredPaymentsForSelectedTerms) {
      final key =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';

      if (!studentLookup.containsKey(key)) {
        studentLookup[key] = Student(
          studentIdNumber:
              'unknown-${payment.studentName}-${payment.studentSurname}-${payment.termId}',
          name: payment.studentName,
          surname: payment.studentSurname,
          class_: payment.studentClass ?? '',
          regNumber: payment.studentRegNumber ?? 'N/A',
          gender: '',
          age: DateTime(1800),
          phoneNumber: '',
          paymentStatus: '',
          exceptions: [],
        );
      }
    }

    // --- Helper functions (reuse existing logic but per-term)
    bool isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.any(
                (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
            false)) continue;
        return true;
      }
      return false;
    }

    double getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;
      String normalizeTerm(String v) {
        return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      for (var studentException in studentExceptions) {
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }
        if (!(studentException.terms
                ?.any((t) => normalizeTerm(t) == normalizeTerm(termId)) ??
            false)) continue;

        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) continue;

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) continue;

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percent = (figure / 100) * (purpose.purposeAmount ?? 0.0);
          totalDeduction += percent;
        }
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);
      return adjusted;
    }

    final Map<String, Map<String, List<Map<String, dynamic>>>>
        perTermArrearsByStudentAndPurpose = {};

    for (var studentKey in studentKeysSet) {
      final student = studentLookup[studentKey];
      if (student == null) continue;

      // ✅ Compute max term breakdowns per student
      int maxTermBreakdowns = normalizedPaymentPurposesOnly
          .map((p) =>
              perTermArrearsByStudentAndPurpose[studentKey]?[p]?.length ?? 0)
          .fold(0, (a, b) => a > b ? a : b);
      perTermArrearsByStudentAndPurpose[studentKey] = {};
      for (var purposeDisplayName in normalizedPaymentPurposesOnly) {
        final normalizedKey = purposeDisplayName.trim().toLowerCase();
        final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];

        final List<Map<String, dynamic>> termArrears = [];

        for (var p in underlyingPurposes) {
          final compositeKey =
              '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;
          final amount = p.purposeAmount ?? 0.0;

          double arrear = (amount - paid).clamp(0.0, amount);

          // apply exceptions if needed
          if (p.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(
                arrear, studentLookup[studentKey]!, p, p.termId ?? '');
          }

          if (arrear > 0.0) {
            termArrears.add({
              'termName': _termMap[p.termId ?? '']?.termName ?? p.termId ?? '',
              'arrear': arrear,
            });
          }
        }

        perTermArrearsByStudentAndPurpose[studentKey]![purposeDisplayName] =
            termArrears;
      }
    }

    // Precompute rows
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    // Iterate over students (union)
    for (var studentKey in studentKeysSet.toList()..sort()) {
      final student = studentLookup[studentKey];

      // Skip if student not found
      if (student == null) continue;

      // ✅ Apply CLASS + SURNAME filters
      if (!surnameMatches(student)) continue;
      if (!classMatches(student)) continue;

      final studentClass = student?.class_ ?? '';

      // aggregated per-student paid amounts across selected terms (by display purpose name)
      final studentAggregatedPaid =
          aggregatedPaidByStudentAndPurposeName[studentKey] ?? {};

      final double totalPaidAmount =
          studentAggregatedPaid.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrearsForStudent = 0.0;

      // Build arrears cells for each aggregated purpose (display order: normalizedPaymentPurposesOnly)
      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        final normalizedKey = purposeDisplayName.trim().toLowerCase();
        final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];

        // No underlying purpose → show 0
        if (underlyingPurposes.isEmpty) {
          return const DataCell(Text('0.0'));
        }

        /*
        ─────────────────────────────────────────────
        HELPERS
        ─────────────────────────────────────────────
        */

        bool isPurposeApplicableForStudent(PaymentPurpose p, Student s) {
          final studentTerms =
              s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
          final purposeTerm = (p.termId ?? '').trim().toLowerCase();
          return studentTerms.contains(purposeTerm);
        }

        bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
          final classes = p.associatedClasses ?? [];
          if (classes.isEmpty) return false;

          final studentClass = s.class_?.trim().toLowerCase();
          return classes
              .map((c) => c.trim().toLowerCase())
              .contains(studentClass);
        }

        bool isPurposeAllowed(PaymentPurpose p, Student s) {
          // Must first be allowed by class
          if (!isPurposeAllowedByClass(p, s)) return false;

          // Newcomer-only – must pass eligibility
          if (p.forNewcomersOnly == true) {
            final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
            return isNewcomerEligible(s, p, termObj);
          }

          return true;
        }

        PaymentPurpose? findFirstUnpaidPurposeForStudent(
          Student student,
          List<PaymentPurpose> purposes,
          Map<String, Map<String, double>> paidMap,
          String termId,
        ) {
          for (var p in purposes) {
            if ((p.termId ?? '').trim().toLowerCase() != termId) continue;

            final compositeKey =
                '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
            final paid = paidMap[studentKey]?[compositeKey] ?? 0.0;
            final amount = p.purposeAmount ?? 0.0;

            if (paid < amount) return p;
          }
          return null;
        }

        bool isPurposeApplicableForStudentByName(
          Student s,
          String purposeDisplayName,
        ) {
          final normalizedKey = purposeDisplayName.trim().toLowerCase();
          final list = purposeNameToList[normalizedKey];
          if (list == null) return false;

          for (var p in list) {
            // Must match student class
            final classes = p.associatedClasses ?? [];
            if (classes.isNotEmpty &&
                classes
                    .map((c) => c.trim().toLowerCase())
                    .contains((s.class_ ?? '').trim().toLowerCase())) {
              // ✅ If newcomer purpose → check eligibility
              if (p.forNewcomersOnly == true) {
                final termKey = (p.termId ?? '').trim().toLowerCase();
                final termObj = _termMap[termKey];
                if (!isNewcomerEligible(s, p, termObj)) {
                  continue;
                }
              }

              // ✅ Must match student term
              final studentTerms =
                  s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
              if (!studentTerms
                  .contains((p.termId ?? '').trim().toLowerCase())) {
                continue;
              }

              return true;
            }
          }
          return false;
        }

        /*
            ─────────────────────────────────────────────
            MAIN ARREARS SUMMATION
            ─────────────────────────────────────────────
            */

        double aggregatedArrearForThisPurpose = 0.0;

        // Precompute first unpaid purpose per term
        Map<String, PaymentPurpose?> firstUnpaidPerTerm = {};
        for (var p in underlyingPurposes) {
          final termNorm = (p.termId ?? '').trim().toLowerCase();
          firstUnpaidPerTerm[termNorm] ??= findFirstUnpaidPurposeForStudent(
            student!,
            underlyingPurposes,
            groupedPaymentsByStudentAndPurposeTerm,
            termNorm,
          );
        }

        for (var up in underlyingPurposes) {
          final termIdNorm = (up.termId ?? '').trim().toLowerCase();

          // Class + newcomer eligibility check
          if (!isPurposeAllowed(up, student!)) continue;

          // Check term association
          if (!isPurposeApplicableForStudent(up, student)) continue;

          // Newcomer-only logic — only first unpaid counts
          if (up.forNewcomersOnly == true) {
            final firstUnpaid = firstUnpaidPerTerm[termIdNorm];
            if (firstUnpaid == null || firstUnpaid != up) {
              continue; // skip any other newcomer purpose
            }
          }

          final compositeKey =
              '${normalize(up.paymentPurpose)}:::${normalize(up.termId ?? '')}';

          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;

          final double purposeAmount = up.purposeAmount ?? 0.0;
          double arrear = (purposeAmount - paid).clamp(0.0, purposeAmount);

          // Re-check newcomer eligibility
          if (up.forNewcomersOnly == true) {
            final termObj = _termMap[termIdNorm];
            if (!isNewcomerEligible(student!, up, termObj)) {
              arrear = 0.0;
            }
          }

          // Apply exceptions if any
          if (up.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(arrear, student!, up, up.termId ?? '');
          }

          if (up.forNewcomersOnly == true) {
            // --- aggregate newcomer total amount for this purpose across terms
            double totalNominalAmount = underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)
                .map((p) => p.purposeAmount ?? 0.0)
                .fold<double>(double.infinity, (a, b) => a < b ? a : b);

            if (totalNominalAmount == double.infinity) {
              totalNominalAmount = 0.0;
            }

            // --- aggregate payments across ALL terms for this newcomer purpose
            double totalPaid = 0.0;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              final ck =
                  '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
              totalPaid += groupedPaymentsByStudentAndPurposeTerm[studentKey]
                      ?[ck] ??
                  0.0;
            }

            double rawArrear = (totalNominalAmount - totalPaid);
            if (rawArrear < 0) rawArrear = 0;

            // ✅ exceptions
            double adjustedArrear = rawArrear;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              adjustedArrear = getAdjustedArrear(
                adjustedArrear,
                student!,
                p,
                p.termId ?? '',
              );
            }
            adjustedArrear = adjustedArrear.clamp(0.0, totalNominalAmount);

            // ✅ Update once only
            aggregatedArrearForThisPurpose = adjustedArrear;

            // ✅ Done → skip sub-iteration of other newcomer entries
            break;
          }

          aggregatedArrearForThisPurpose += arrear;
        }

        /*
          ─────────────────────────────────────────────
          VISIBILITY / TOTAL UPDATES
          ─────────────────────────────────────────────
          */

        // If no underlying purpose is allowed → blank
        final allowed =
            underlyingPurposes.any((p) => isPurposeAllowed(p, student!));
        if (!allowed) {
          return const DataCell(Text(""));
        }

        // Update totals
        totalArrearsForStudent += aggregatedArrearForThisPurpose;
        grandTotalArrears += aggregatedArrearForThisPurpose;
        grandTotalPurposeArrears[purposeDisplayName] =
            (grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) +
                aggregatedArrearForThisPurpose;

        return DataCell(
          Text(aggregatedArrearForThisPurpose.toStringAsFixed(2)),
        );
      }).toList();

      // Paid cells for selected payment purposes (if you still want them)
      final List<DataCell> paidCells = _selectedPaymentPurposes.map((purpose) {
        final paidAmount = studentAggregatedPaid[purpose] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      // Arrear filter logic (same as before)
      bool matchesFilter = true;
      switch (_selectedArrearFilter) {
        case 'Arrears Only':
          matchesFilter = totalArrearsForStudent > 0;
          break;
        case 'Fully Paid':
          matchesFilter = totalArrearsForStudent == 0;
          break;
        case 'Overpaid / Credit':
          matchesFilter = totalArrearsForStudent < 0;
          break;
        case 'Custom Range':
          if (_arrearMin != null && _arrearMax != null) {
            matchesFilter = totalArrearsForStudent >= _arrearMin! &&
                totalArrearsForStudent <= _arrearMax!;
          }
          break;
        default:
          matchesFilter = true;
      }
      if (!matchesFilter) continue;

      // Add the DataRow
      dataRows.add(DataRow(cells: [
        DataCell(Text(studentKey)), // STUDENT NAME (key is "name surname")
        DataCell(Text(studentClass)),
        // arrears per aggregated purpose (note: we display negative like original code if you prefer)
        if (_showArrears)
          ...arrearsCells.map((cell) {
            final textWidget = cell.child;
            if (textWidget is Text) {
              final originalText = textWidget.data ?? '';
              // ✅ keep blank → blank
              if (originalText.trim().isEmpty) {
                return const DataCell(Text(""));
              }
              final parsed = double.tryParse(originalText) ?? 0.0;
              final displayValue =
                  parsed > 0.0 ? (-parsed).toStringAsFixed(2) : '0.0';
              return DataCell(Text(displayValue));
            } else {
              return const DataCell(Text('0.0'));
            }
          }),

        // ✅ NEW — paid-amounts matching same normalizedPaymentPurposesOnly
        if (_showPayments)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            final paidAmount = studentAggregatedPaid[purposeDisplayName] ?? 0.0;

            grandTotalPurposePaid[purposeDisplayName] =
                (grandTotalPurposePaid[purposeDisplayName] ?? 0.0) + paidAmount;

            return DataCell(Text(paidAmount.toStringAsFixed(2)));
          }).toList(),

        DataCell(Text(totalArrearsForStudent > 0.0
            ? '-${totalArrearsForStudent.abs().toStringAsFixed(2)}'
            : '0.0')),
        DataCell(Text(totalPaidAmount.toStringAsFixed(2))),
      ]));
    }
    // --- ADD per-term breakdown rows
    for (var studentKey in studentKeysSet.toList()..sort()) {
      final student = studentLookup[studentKey];
      if (student == null) continue;

      // Apply filters
      if (!surnameMatches(student)) continue;
      if (!classMatches(student)) continue;

      final studentClass = student.class_ ?? '';
      final studentAggregatedPaid =
          aggregatedPaidByStudentAndPurposeName[studentKey] ?? {};

      double totalArrearsForStudent = 0.0;
      double totalPaidAmount =
          studentAggregatedPaid.values.fold(0.0, (a, b) => a + b);

      // Build arrears cells
      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        final underlyingPurposes =
            purposeNameToList[purposeDisplayName.trim().toLowerCase()] ?? [];
        double aggregatedArrearForThisPurpose = 0.0;

        for (var p in underlyingPurposes) {
          bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
            final classes = p.associatedClasses ?? [];
            if (classes.isEmpty) return false;

            final studentClass = s.class_?.trim().toLowerCase();
            return classes
                .map((c) => c.trim().toLowerCase())
                .contains(studentClass);
          }

          bool isPurposeAllowed(PaymentPurpose p, Student s) {
            // Must first be allowed by class
            if (!isPurposeAllowedByClass(p, s)) return false;

            // Newcomer-only – must pass eligibility
            if (p.forNewcomersOnly == true) {
              final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
              return isNewcomerEligible(s, p, termObj);
            }

            return true;
          }

          // skip if purpose not allowed
          if (!isPurposeAllowed(p, student)) continue;

          final compositeKey =
              '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;
          double arrear = (p.purposeAmount ?? 0.0) - paid;

          // Apply exceptions
          if (p.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(arrear, student, p, p.termId ?? '');
          }

          aggregatedArrearForThisPurpose +=
              arrear.clamp(0.0, p.purposeAmount ?? 0.0);
        }

        totalArrearsForStudent += aggregatedArrearForThisPurpose;
        grandTotalArrears += aggregatedArrearForThisPurpose;
        grandTotalPurposeArrears[purposeDisplayName] =
            (grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) +
                aggregatedArrearForThisPurpose;

        return DataCell(
            Text(aggregatedArrearForThisPurpose.toStringAsFixed(2)));
      }).toList();

      // --- ADD per-term breakdown rows if _showArrears is true
      if (_showArrears) {
        // Compute max number of per-term entries for this student
        int maxTermBreakdowns = normalizedPaymentPurposesOnly
            .map((p) =>
                perTermArrearsByStudentAndPurpose[studentKey]?[p]?.length ?? 0)
            .fold(0, (a, b) => a > b ? a : b);

        for (int i = 0; i < maxTermBreakdowns; i++) {
          List<DataCell> breakdownCells = [
            const DataCell(SizedBox.shrink()), // student name empty
            const DataCell(SizedBox.shrink()), // student class empty
          ];

          for (var purposeDisplayName in normalizedPaymentPurposesOnly) {
            final termList = perTermArrearsByStudentAndPurpose[studentKey]
                    ?[purposeDisplayName] ??
                [];
            if (i < termList.length) {
              final entry = termList[i];
              breakdownCells.add(
                DataCell(Text(
                    '${entry['termName']} (\$${entry['arrear'].toStringAsFixed(2)})')),
              );
            } else {
              breakdownCells.add(const DataCell(Text(''))); // empty cell
            }
          }
          // PAID columns (empty for breakdown rows)
          if (_showPayments) {
            breakdownCells.addAll(List.generate(
                normalizedPaymentPurposesOnly.length,
                (_) => const DataCell(Text(''))));
          }

          // Empty cells for TOTAL ARREARS and TOTAL PAID columns
          breakdownCells.add(const DataCell(SizedBox.shrink()));
          breakdownCells.add(const DataCell(SizedBox.shrink()));

          dataRows.add(DataRow(cells: breakdownCells));
        }
      }

      // --- Add main DataRow for this student
      dataRows.add(DataRow(cells: [
        DataCell(Text(studentKey)),
        DataCell(Text(studentClass)),
        if (_showArrears) ...arrearsCells,
        if (_showPayments)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            final paidAmount = studentAggregatedPaid[purposeDisplayName] ?? 0.0;
            grandTotalPurposePaid[purposeDisplayName] =
                (grandTotalPurposePaid[purposeDisplayName] ?? 0.0) + paidAmount;
            return DataCell(Text(paidAmount.toStringAsFixed(2)));
          }).toList(),
        DataCell(Text(totalArrearsForStudent > 0
            ? '-${totalArrearsForStudent.toStringAsFixed(2)}'
            : '0.0')),
        DataCell(Text(totalPaidAmount.toStringAsFixed(2))),
      ]));
    }

    // Grand totals row (use aggregatedPurposeAmounts keys in same order as normalizedPaymentPurposesOnly)
    dataRows.add(DataRow(
      cells: [
        DataCell(Container(
          color: Colors.blue,
          padding: const EdgeInsets.all(8.0),
          child: const Text('GRAND TOTALS',
              style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const DataCell(SizedBox.shrink()),
        if (_showArrears)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            return DataCell(Container(
              color: const Color.fromARGB(255, 246, 55, 2),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                ((grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) > 0.0)
                    ? '-${(grandTotalPurposeArrears[purposeDisplayName] ?? 0.0).abs().toStringAsFixed(2)}'
                    : '0.0',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ));
          }).toList(),
        // ✅ PAID Columns
        if (_showPayments)
          ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
            return DataCell(Container(
              color: const Color.fromARGB(255, 13, 244, 244),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                (grandTotalPurposePaid[purposeDisplayName] ?? 0.0)
                    .toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ));
          }).toList(),
        DataCell(Container(
          color: const Color.fromARGB(255, 248, 151, 4),
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '-${grandTotalArrears.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )),
        DataCell(Container(
          color: const Color.fromARGB(255, 13, 244, 244),
          padding: const EdgeInsets.all(8.0),
          child: Text(
            grandTotalPaid.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )),
      ],
    ));

    // --- Build the table UI (same as before)
    return Stack(
      children: [
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
                    ...(_showArrears
                        ? normalizedPaymentPurposesOnly.map((p) => DataColumn(
                              label: Container(
                                color: const Color.fromARGB(255, 255, 0, 0),
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                    '$p ARREARS (\$${aggregatedPurposeAmounts[p] ?? 0.0})'),
                              ),
                            ))
                        : []),
                    // ✅ NEW — PAID HEADERS
                    ...(_showPayments
                        ? normalizedPaymentPurposesOnly.map(
                            (p) => DataColumn(
                                label: Container(
                                    color:
                                        const Color.fromARGB(120, 0, 255, 60),
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('$p PAID'))),
                          )
                        : []),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 248, 151, 4),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('TOTAL ARREARS'.toUpperCase()),
                      ),
                    ),
                    DataColumn(
                      label: Container(
                        color: const Color.fromARGB(255, 13, 244, 244),
                        padding: const EdgeInsets.all(8.0),
                        child: Text('TOTAL PAID'.toUpperCase()),
                      ),
                    ),
                  ],
                  rows: dataRows,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 50,
          left: 60,
          right: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                heroTag: 'scrollLeftFAB',
                onPressed: _scrollLeft,
                mini: true,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.arrow_back),
              ),
              FloatingActionButton(
                heroTag: 'scrollRightFAB',
                onPressed: _scrollRight,
                mini: true,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> generateAndSaveSpreadsheet() async {
// --- FILTERING BY CLASS + SURNAME
    bool surnameMatches(Student s) {
      if (_surnameController.text.trim().isEmpty) return true;

      final query = _surnameController.text.trim().toLowerCase();
      return (s.surname ?? '').toLowerCase().contains(query);
    }

    bool classMatches(Student s) {
      if (_selectedClasses.isEmpty) return true;

      final studentClass = (s.class_ ?? "").trim().toLowerCase();
      return _selectedClasses
          .map((c) => c.trim().toLowerCase())
          .contains(studentClass);
    }

    String normalize(String v) {
      return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final List<PaymentPurpose> allPurposes = (_role == DeviceRole.host)
        ? Hive.box<PaymentPurpose>('payment_purposes').values.toList()
        : _cachedServerStudentPaymentPurposes ?? [];

    // --- Determine selected terms (support single-term fallback)
    final List<String> selectedTermIdsNormalized = (() {
      if ((_selectedTermIds).isNotEmpty) {
        return _selectedTermIds
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList();
      } else {
        final selectedTermIdsNormalized = (_selectedTermIds.isNotEmpty)
            ? _selectedTermIds.map((t) => t.trim().toLowerCase()).toList()
            : allPurposes
                .map((p) => (p.termId ?? '').trim().toLowerCase())
                .toSet()
                .toList();

        return selectedTermIdsNormalized;
      }
    })();

    // Normalize _paymentPurposesOnly (preserve first appearance string)
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p;
      }
    }

    // Normalize selected payment purposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }

    // Caches (all stored objects)
    final List<Student> allStudents = (_role == DeviceRole.host)
        ? Hive.box<Student>('students').values.toList()
        : _cachedServerStudents ?? [];

    // --- Collect purposes that belong to ANY selected term
    final List<PaymentPurpose> purposesInSelectedTerms = allPurposes
        .where((p) => selectedTermIdsNormalized
            .contains((p.termId ?? '').trim().toLowerCase()))
        .toList();
    // Group same-name purposes (case-insensitive). For each normalized name we keep the list of underlying PaymentPurpose objects
    final Map<String, List<PaymentPurpose>> purposeNameToList = {};
    for (var p in purposesInSelectedTerms) {
      final nameKey = normalize(p.paymentPurpose);
      if (nameKey.isEmpty) continue;
      purposeNameToList.putIfAbsent(nameKey, () => []).add(p);
    }

    // aggregated display names & aggregated amounts (sum of amounts across terms for same name)
    // Build full union of payment purposes appearing in ANY selected term
    // Payment purposes that exist across any selected terms
    final List<String> normalizedPaymentPurposesOnly = purposeNameToList.keys
        .map((key) {
          return normalizedPurposesMap[key] ?? key;
        })
        .toSet()
        .toList()
      ..sort();

    // aggregated purpose amount map used for header display: normalizedName -> sum(amount)
    final Map<String, double> aggregatedPurposeAmounts = {};
    purposeNameToList.forEach((nameKey, list) {
      double headerAmount = 0.0;

      bool isNewcomer = list.any((p) => p.forNewcomersOnly == true);

      if (isNewcomer) {
        // ✅ All newcomer entries share same nominal amount
        // Use the smallest (safest)
        headerAmount = list
            .map((p) => p.purposeAmount ?? 0.0)
            .where((v) => v > 0)
            .fold<double>(double.infinity, (a, b) => a < b ? a : b);

        if (headerAmount == double.infinity) {
          headerAmount = 0.0;
        }
      } else {
        // ✅ normal → sum
        headerAmount =
            list.fold<double>(0.0, (acc, p) => acc + (p.purposeAmount ?? 0.0));
      }
      final displayName = normalizedPurposesMap[nameKey] ?? nameKey;

      aggregatedPurposeAmounts[displayName] = headerAmount;
    });

    // --- Filter payments to only those in selected terms
    final List<StudentPayment> filteredPaymentsForSelectedTerms =
        _filteredPayments
            .where((pay) => selectedTermIdsNormalized
                .contains((pay.termId ?? '').trim().toLowerCase()))
            .toList();

    // Build grouped payments per student per purpose+term key:
    // studentKey -> { '${purposeNameKey}:::${termIdKey}': paidAmount }
    final Map<String, Map<String, double>>
        groupedPaymentsByStudentAndPurposeTerm = {};
    for (var payment in filteredPaymentsForSelectedTerms) {
      final studentKey =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';
      final purposeKey = (payment.paymentPurpose ?? '').trim().toLowerCase();
      final termKey = (payment.termId ?? '').trim().toLowerCase();
      final compositeKey =
          '${normalize(payment.paymentPurpose)}:::${normalize(payment.termId ?? '')}';
      final double paid = payment.amountToPay ?? 0.0;

      groupedPaymentsByStudentAndPurposeTerm.putIfAbsent(studentKey, () => {});
      groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] =
          (groupedPaymentsByStudentAndPurposeTerm[studentKey]![compositeKey] ??
                  0.0) +
              paid;
    }

    // Also create an aggregated student->purposeName (no-term) paid map for totals display (sum across terms)
    final Map<String, Map<String, double>>
        aggregatedPaidByStudentAndPurposeName = {};
    groupedPaymentsByStudentAndPurposeTerm.forEach((studentKey, map) {
      aggregatedPaidByStudentAndPurposeName.putIfAbsent(studentKey, () => {});
      map.forEach((compositeKey, paid) {
        final parts = compositeKey.split(':::');
        final purposeKey = parts[0];
        final displayName =
            normalizedPurposesMap[normalize(purposeKey)] ?? purposeKey;
// preserve casing if available

        aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] =
            (aggregatedPaidByStudentAndPurposeName[studentKey]![displayName] ??
                    0.0) +
                paid;
      });
    });

    // --- Build student map: union of students from allStudents and those appearing in payments.
    final Set<String> studentKeysSet = {};
    // from payments
    for (var payment in filteredPaymentsForSelectedTerms) {
      studentKeysSet.add(
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}');
    }
    // from allStudents store
    for (var s in allStudents) {
      studentKeysSet.add('${s.name.toLowerCase()} ${s.surname.toLowerCase()}');
    }

    // Build a lookup Student map; prefer the student object from allStudents if present, else build a minimal placeholder from a payment record
    final Map<String, Student> studentLookup = {};
    for (var s in allStudents) {
      final key = '${s.name.toLowerCase()} ${s.surname.toLowerCase()}';
      studentLookup[key] = s;
    }
    // If payment has student that isn't in allStudents, create a light placeholder Student (adjust fields if your Student model differs)
    for (var payment in filteredPaymentsForSelectedTerms) {
      final key =
          '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}';

      if (!studentLookup.containsKey(key)) {
        studentLookup[key] = Student(
          studentIdNumber:
              'unknown-${payment.studentName}-${payment.studentSurname}-${payment.termId}',
          name: payment.studentName,
          surname: payment.studentSurname,
          class_: payment.studentClass ?? '',
          regNumber: payment.studentRegNumber ?? 'N/A',
          gender: '',
          age: DateTime(1800),
          phoneNumber: '',
          paymentStatus: '',
          exceptions: [],
        );
      }
    }
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Arrears & Payments'];

    // Add headers for the table
    List<CellValue?> headers = [
      TextCellValue('STUDENT NAME'),
      TextCellValue('STUDENT CLASS'),
      ...normalizedPaymentPurposesOnly.map(
        (p) => TextCellValue(
            '$p ARREARS (\$${aggregatedPurposeAmounts[p] ?? 0.0})'),
      ),
      // ✅ NEW — paid-amounts matching same normalizedPaymentPurposesOnly
      // ✅ NEW — PAID HEADERS
      ...normalizedPaymentPurposesOnly.map(
        (p) => TextCellValue(('$p PAID')),
      ),

      TextCellValue('TOTAL ARREARS'),
      TextCellValue('TOTAL PAID'),
    ];
    sheetObject.appendRow(headers);

    // --- Helper functions (reuse existing logic but per-term)
    bool isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.any(
                (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
            false)) continue;
        return true;
      }
      return false;
    }

    double getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;
      String normalizeTerm(String v) {
        return v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      for (var studentException in studentExceptions) {
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }
        if (!(studentException.terms
                ?.any((t) => normalizeTerm(t) == normalizeTerm(termId)) ??
            false)) continue;

        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) continue;

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) continue;

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percent = (figure / 100) * (purpose.purposeAmount ?? 0.0);
          totalDeduction += percent;
        }
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);
      return adjusted;
    }

    // Precompute rows
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    // Iterate over students (union)
    for (var studentKey in studentKeysSet.toList()..sort()) {
      final student = studentLookup[studentKey];

      // Skip if student not found
      if (student == null) continue;

      // ✅ Apply CLASS + SURNAME filters
      if (!surnameMatches(student)) continue;
      if (!classMatches(student)) continue;

      final studentClass = student?.class_ ?? '';

      // aggregated per-student paid amounts across selected terms (by display purpose name)
      final studentAggregatedPaid =
          aggregatedPaidByStudentAndPurposeName[studentKey] ?? {};

      final double totalPaidAmount =
          studentAggregatedPaid.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrearsForStudent = 0.0;

      // Build arrears cells for each aggregated purpose (display order: normalizedPaymentPurposesOnly)
      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        final normalizedKey = purposeDisplayName.trim().toLowerCase();
        final underlyingPurposes = purposeNameToList[normalizedKey] ?? [];

        // No underlying purpose → show 0
        if (underlyingPurposes.isEmpty) {
          return const DataCell(Text('0.0'));
        }

        /*
  ─────────────────────────────────────────────
  HELPERS
  ─────────────────────────────────────────────
  */

        bool isPurposeApplicableForStudent(PaymentPurpose p, Student s) {
          final studentTerms =
              s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
          final purposeTerm = (p.termId ?? '').trim().toLowerCase();
          return studentTerms.contains(purposeTerm);
        }

        bool isPurposeAllowedByClass(PaymentPurpose p, Student s) {
          final classes = p.associatedClasses ?? [];
          if (classes.isEmpty) return false;

          final studentClass = s.class_?.trim().toLowerCase();
          return classes
              .map((c) => c.trim().toLowerCase())
              .contains(studentClass);
        }

        bool isPurposeAllowed(PaymentPurpose p, Student s) {
          // Must first be allowed by class
          if (!isPurposeAllowedByClass(p, s)) return false;

          // Newcomer-only – must pass eligibility
          if (p.forNewcomersOnly == true) {
            final termObj = _termMap[p.termId?.trim().toLowerCase() ?? ''];
            return isNewcomerEligible(s, p, termObj);
          }

          return true;
        }

        PaymentPurpose? findFirstUnpaidPurposeForStudent(
          Student student,
          List<PaymentPurpose> purposes,
          Map<String, Map<String, double>> paidMap,
          String termId,
        ) {
          for (var p in purposes) {
            if ((p.termId ?? '').trim().toLowerCase() != termId) continue;

            final compositeKey =
                '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
            final paid = paidMap[studentKey]?[compositeKey] ?? 0.0;
            final amount = p.purposeAmount ?? 0.0;

            if (paid < amount) return p;
          }
          return null;
        }

        bool isPurposeApplicableForStudentByName(
          Student s,
          String purposeDisplayName,
        ) {
          final normalizedKey = purposeDisplayName.trim().toLowerCase();
          final list = purposeNameToList[normalizedKey];
          if (list == null) return false;

          for (var p in list) {
            // Must match student class
            final classes = p.associatedClasses ?? [];
            if (classes.isNotEmpty &&
                classes
                    .map((c) => c.trim().toLowerCase())
                    .contains((s.class_ ?? '').trim().toLowerCase())) {
              // ✅ If newcomer purpose → check eligibility
              if (p.forNewcomersOnly == true) {
                final termKey = (p.termId ?? '').trim().toLowerCase();
                final termObj = _termMap[termKey];
                if (!isNewcomerEligible(s, p, termObj)) {
                  continue;
                }
              }

              // ✅ Must match student term
              final studentTerms =
                  s.terms?.map((t) => t.trim().toLowerCase()).toList() ?? [];
              if (!studentTerms
                  .contains((p.termId ?? '').trim().toLowerCase())) {
                continue;
              }

              return true;
            }
          }
          return false;
        }

        /*
  ─────────────────────────────────────────────
  MAIN ARREARS SUMMATION
  ─────────────────────────────────────────────
  */

        double aggregatedArrearForThisPurpose = 0.0;

        // Precompute first unpaid purpose per term
        Map<String, PaymentPurpose?> firstUnpaidPerTerm = {};
        for (var p in underlyingPurposes) {
          final termNorm = (p.termId ?? '').trim().toLowerCase();
          firstUnpaidPerTerm[termNorm] ??= findFirstUnpaidPurposeForStudent(
            student!,
            underlyingPurposes,
            groupedPaymentsByStudentAndPurposeTerm,
            termNorm,
          );
        }
        for (var up in underlyingPurposes) {
          final termIdNorm = (up.termId ?? '').trim().toLowerCase();

          // Class + newcomer eligibility check
          if (!isPurposeAllowed(up, student!)) continue;

          // Check term association
          if (!isPurposeApplicableForStudent(up, student)) continue;

          // Newcomer-only logic — only first unpaid counts
          if (up.forNewcomersOnly == true) {
            final firstUnpaid = firstUnpaidPerTerm[termIdNorm];
            if (firstUnpaid == null || firstUnpaid != up) {
              continue; // skip any other newcomer purpose
            }
          }

          final compositeKey =
              '${normalize(up.paymentPurpose)}:::${normalize(up.termId ?? '')}';

          final paid = groupedPaymentsByStudentAndPurposeTerm[studentKey]
                  ?[compositeKey] ??
              0.0;

          final double purposeAmount = up.purposeAmount ?? 0.0;
          double arrear = (purposeAmount - paid).clamp(0.0, purposeAmount);

          // Re-check newcomer eligibility
          if (up.forNewcomersOnly == true) {
            final termObj = _termMap[termIdNorm];
            if (!isNewcomerEligible(student!, up, termObj)) {
              arrear = 0.0;
            }
          }

          // Apply exceptions if any
          if (up.exceptions?.isNotEmpty ?? false) {
            arrear = getAdjustedArrear(arrear, student!, up, up.termId ?? '');
          }

          if (up.forNewcomersOnly == true) {
            // --- aggregate newcomer total amount for this purpose across terms
            double totalNominalAmount = underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)
                .map((p) => p.purposeAmount ?? 0.0)
                .fold<double>(double.infinity, (a, b) => a < b ? a : b);

            if (totalNominalAmount == double.infinity) {
              totalNominalAmount = 0.0;
            }

            // --- aggregate payments across ALL terms for this newcomer purpose
            double totalPaid = 0.0;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              final ck =
                  '${normalize(p.paymentPurpose)}:::${normalize(p.termId ?? '')}';
              totalPaid += groupedPaymentsByStudentAndPurposeTerm[studentKey]
                      ?[ck] ??
                  0.0;
            }

            double rawArrear = (totalNominalAmount - totalPaid);
            if (rawArrear < 0) rawArrear = 0;

            // ✅ exceptions
            double adjustedArrear = rawArrear;
            for (var p in underlyingPurposes
                .where((p) => p.forNewcomersOnly == true)) {
              adjustedArrear = getAdjustedArrear(
                adjustedArrear,
                student!,
                p,
                p.termId ?? '',
              );
            }
            adjustedArrear = adjustedArrear.clamp(0.0, totalNominalAmount);

            // ✅ Update once only
            aggregatedArrearForThisPurpose = adjustedArrear;

            // ✅ Done → skip sub-iteration of other newcomer entries
            break;
          }

          aggregatedArrearForThisPurpose += arrear;
        }

        /*
  ─────────────────────────────────────────────
  VISIBILITY / TOTAL UPDATES
  ─────────────────────────────────────────────
  */

        // If no underlying purpose is allowed → blank
        final allowed =
            underlyingPurposes.any((p) => isPurposeAllowed(p, student!));
        if (!allowed) {
          return const DataCell(Text(""));
        }

        // Update totals
        totalArrearsForStudent += aggregatedArrearForThisPurpose;
        grandTotalArrears += aggregatedArrearForThisPurpose;
        grandTotalPurposeArrears[purposeDisplayName] =
            (grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) +
                aggregatedArrearForThisPurpose;

        return DataCell(
          Text(aggregatedArrearForThisPurpose.toStringAsFixed(2)),
        );
      }).toList();
      // Paid cells for selected payment purposes (if you still want them)
      final List<DataCell> paidCells = _selectedPaymentPurposes.map((purpose) {
        final paidAmount = studentAggregatedPaid[purpose] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      // Arrear filter logic (same as before)
      bool matchesFilter = true;
      switch (_selectedArrearFilter) {
        case 'Arrears Only':
          matchesFilter = totalArrearsForStudent > 0;
          break;
        case 'Fully Paid':
          matchesFilter = totalArrearsForStudent == 0;
          break;
        case 'Overpaid / Credit':
          matchesFilter = totalArrearsForStudent < 0;
          break;
        case 'Custom Range':
          if (_arrearMin != null && _arrearMax != null) {
            matchesFilter = totalArrearsForStudent >= _arrearMin! &&
                totalArrearsForStudent <= _arrearMax!;
          }
          break;
        default:
          matchesFilter = true;
      }
      if (!matchesFilter) continue;

      sheetObject.appendRow([
        TextCellValue(studentKey),
        TextCellValue(studentClass),

        ...arrearsCells.map((cell) {
          final textWidget = cell.child;
          if (textWidget is Text) {
            final originalText = textWidget.data ?? '';
            // ✅ keep blank → blank
            if (originalText.trim().isEmpty) {
              return TextCellValue("");
            }
            final parsed = double.tryParse(originalText) ?? 0.0;
            final displayValue =
                parsed > 0.0 ? (-parsed).toStringAsFixed(2) : '0.0';
            return TextCellValue((displayValue));
          } else {
            return TextCellValue(('0.0'));
          }
        }),
        // ✅ NEW — paid-amounts matching same normalizedPaymentPurposesOnly

        ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
          final paidAmount = studentAggregatedPaid[purposeDisplayName] ?? 0.0;

          grandTotalPurposePaid[purposeDisplayName] =
              (grandTotalPurposePaid[purposeDisplayName] ?? 0.0) + paidAmount;

          return TextCellValue((paidAmount.toStringAsFixed(2)));
        }),

        TextCellValue((totalArrearsForStudent > 0.0
            ? '-${totalArrearsForStudent.abs().toStringAsFixed(2)}'
            : '0.0')),
        TextCellValue((totalPaidAmount.toStringAsFixed(2))),
      ]);
    }
    // Add the grand totals row to the spreadsheet
    sheetObject.appendRow([
      TextCellValue('GRAND TOTALS'),
      TextCellValue(''), // Empty cell for student class

      ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        return TextCellValue(
          ((grandTotalPurposeArrears[purposeDisplayName] ?? 0.0) > 0.0)
              ? '-${(grandTotalPurposeArrears[purposeDisplayName] ?? 0.0).abs().toStringAsFixed(2)}'
              : '0.0',
        );
      }),
      // ✅ PAID Columns

      ...normalizedPaymentPurposesOnly.map((purposeDisplayName) {
        return TextCellValue(
          (grandTotalPurposePaid[purposeDisplayName] ?? 0.0).toStringAsFixed(2),
        );
      }),
      TextCellValue(
        '-${grandTotalArrears.toStringAsFixed(2)}',
      ),
      TextCellValue(
        grandTotalPaid.toStringAsFixed(2),
      ),
    ]);

    // Save the Excel file

    try {
      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception("Excel encoding failed.");

      if (Platform.isAndroid) {
        // Get app's scoped documents directory
        final directory = await getApplicationDocumentsDirectory();
        final folder = Directory(
            '${directory.path}/school_files/student_payments_reports');

        // Create folder if not exists
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        // Generate unique file name with timestamp
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath =
            '${folder.path}/student_payments_reports_$timestamp.xlsx';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        print('✅ Spreadsheet saved to: $filePath');
      } else {
        // Use FilePicker to choose save location

        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel File',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          fileName: 'student_payments_and_arrears.xlsx',
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
      }
    } catch (e) {
      print('Error saving spreadsheet: $e');
    }
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _regNumberController.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();

    super.dispose();
  }
}

 */
