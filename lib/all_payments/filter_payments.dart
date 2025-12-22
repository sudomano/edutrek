import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/arrears_and_prepayments/arrears_and_prepayments.dart';
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

class ViewByScreen extends StatefulWidget {
  const ViewByScreen({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ViewByScreen> {
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

  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;

  List<StudentPayment>? _cachedFilteredStudents;

  @override
  void initState() {
    super.initState();
    _initializeData();
    fetchTerms();
    horizontalScrollController = ScrollController();
    verticalScrollController = ScrollController();
  }

  List<String> selectedTermIds = [];

  List<String> getCurrentTermIds() {
    return selectedTermIds.isNotEmpty
        ? selectedTermIds
        : (globalTermId != null ? [globalTermId!] : []);
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Details Feedback"),
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
        // Extract unique termIds
        _terms = allTerms.map((t) => t.termId).toSet().toList();

        // Keep only selected IDs that still exist
        selectedTermIds =
            selectedTermIds.where((id) => _terms.contains(id)).toSet().toList();

        // If none selected, default to first term
        if (selectedTermIds.isEmpty && _terms.isNotEmpty) {
          selectedTermIds = [_terms.first];
        }
      } else {
        _terms = [];
        selectedTermIds = [];
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  void selectTerm(String? termId) {
    final fallback = termId ?? globalTermId;

    if (fallback == null || fallback.isEmpty) return;

    setState(() {
      if (!selectedTermIds.contains(fallback)) {
        selectedTermIds.add(fallback);
      }
    });
  }

// Example of using currentTermId in a method
  void filterByTerm() {
    final currentTermId = getCurrentTermIds();

    // Perform filtering logic based on currentTermId
    _filteredPayments = _filteredPayments.where((payment) {
      return currentTermId.contains(payment.termId);
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
      final filteredPayments;
      final filteredPaymentPurposesOnly;
      final currentTermIds = selectedTermIds.isNotEmpty
          ? selectedTermIds
          : (globalTermId != null ? [globalTermId!] : []);

      filteredPayments = allStudentPayments
          .where((payment) => currentTermIds.contains(payment.termId))
          .toList();

      filteredPaymentPurposesOnly = allStudentPaymentPurposes
          .where((payment) => currentTermIds.contains(payment.termId))
          .toList();

      // Fetch unique classes from filtered payments
      // Fetch unique classes from filtered payments
      final classSet = filteredPayments
          .map((student) => student.studentClass.trim().toLowerCase())
          .toSet();

      _classes = ['All'];
      _classes.addAll(classSet.map((c) => _capitalizeEachWord(c)).toList());

      _selectedClasses = ['All']; // Default selection

      // Fetch unique payment purposes from filtered payments
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
      _paymentPurposesOnly.addAll(
        allStudentPaymentPurposes
            .where((p) => selectedTermIds.contains(p.termId))
            .map((p) => p.paymentPurpose)
            .toSet()
            .toList(),
      );

// Fetch payment-purpose amounts (sum or latest per term)
      for (var p in allStudentPaymentPurposes
          .where((p) => selectedTermIds.contains(p.termId))) {
        _paymentPurposeAmounts[p.paymentPurpose] = p.purposeAmount;
      }

      // Sort students by surname
      _filteredPayments.sort((a, b) => _isSortAscending
          ? a.studentSurname.compareTo(b.studentSurname)
          : b.studentSurname.compareTo(a.studentSurname));
      setState(() {});
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
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

      final filteredPayments;
      final filteredStudents;
      final currentTermIds = selectedTermIds.isNotEmpty
          ? selectedTermIds
          : (globalTermId != null ? [globalTermId!] : []);
      filteredPayments = allStudentPayments
          .where((payment) => currentTermIds.contains(payment.termId))
          .toList();

      filteredStudents = allStudents
          .where((payment) => currentTermIds.contains(payment.termId))
          .toList();

      // Get all payment records for the current term
      List<StudentPayment> paymentRecords = allStudentPayments
          .where((payment) => currentTermIds.contains(payment.termId))
          .toList();

      // Get all student records (apply class filter if not 'All')
      List<Student> studentRecords = allStudents
          .where((student) =>
              student.terms!.any((term) => selectedTermIds.contains(term)))
          .toList();

      if (_selectedClasses.isNotEmpty &&
          !_selectedClasses.any((c) => c.toLowerCase() == 'all')) {
        studentRecords = studentRecords.where((student) {
          final normalizedClass = student.class_.trim().toLowerCase();
          return _selectedClasses
              .map((c) => c.toLowerCase())
              .contains(normalizedClass);
        }).toList();
      }

      _filteredPayments = allStudentPayments
          .where((purposeOnly) => currentTermIds.contains(purposeOnly.termId))
          .toList();

      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
        final selectedClassKeys =
            _selectedClasses.map((e) => e.trim().toLowerCase()).toSet();
        _filteredPayments = _filteredPayments.where((payment) {
          return selectedClassKeys
              .contains(payment.studentClass.trim().toLowerCase());
        }).toList();
      }

      // Merge data: for each student, check if they have any payment record.
      List<StudentPayment> combinedRecords = [];

      for (var student in studentRecords) {
        // Option 1: if you have a student ID or unique identifier to join records, use it.
        // Here we assume each payment has a studentId and each student has an id.
        final studentPayments = paymentRecords
            .where((payment) =>
                payment.studentName.toLowerCase() ==
                    student.name.toLowerCase() &&
                payment.studentSurname.toLowerCase() ==
                    student.surname.toLowerCase() &&
                payment.studentClass.toLowerCase().trim() ==
                    student.class_.toLowerCase().trim() &&
                selectedTermIds.contains(payment.termId))
            .toList();

        if (studentPayments.isEmpty) {
          // Create a dummy record for a student with no payments
          int newId = await getNextId();
          String receiptNumber = uuid.v4();
          List<String> modifiedFields = [];
          modifiedFields.add('id');
          modifiedFields.add('receiptNumber');
          modifiedFields.add('studentName');
          modifiedFields.add('studentSurname');
          modifiedFields.add('studentClass');
          modifiedFields.add('phoneNumber');
          modifiedFields.add('paymentPurpose');
          modifiedFields.add('amountToPay');
          modifiedFields.add('paymentDate');
          modifiedFields.add('termId');
          for (final t in currentTermIds) {
            combinedRecords.add(
              StudentPayment(
                id: newId,
                receiptNumber: receiptNumber,
                studentName: student.name,
                studentSurname: student.surname,
                studentClass: student.class_,
                termId: t,
                phoneNumber: student.phoneNumber,
                paymentPurpose: '',
                amountToPay: 0.0,
                paymentDate: DateTime.now(),
                syncStatus: false, // Set syncStatus to false
                lastModified:
                    DateTime.now(), // Set lastModified to current datetime
                operationType: 'create', // Set operationType to 'create'
                modifiedFields: modifiedFields,
              ),
            );
          }
        } else {
          // If there are multiple records per student, you can either combine them
          // or add them all. In many cases, you may want to combine payment purposes.
          combinedRecords.addAll(studentPayments);
        }
      }

      // Now, _filteredPayments contains students even if they have no payment.
      _filteredPayments = combinedRecords;

      if (_selectedStudent != null && _selectedStudent!.trim().isNotEmpty) {
        final query = _selectedStudent!.trim().toLowerCase();

        _filteredPayments = _filteredPayments.where((payment) {
          final fullName = '${payment.studentName} ${payment.studentSurname}'
              .trim()
              .toLowerCase();
          return fullName.contains(query);
        }).toList();
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
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
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

    final cachedPurposes = {
      for (var p in allStudentPaymentPurposes)
        p.paymentPurpose.toLowerCase(): p,
    };

    final allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };
    final studentLookup = {
      for (var s in allStudents)
        '${s.name.toLowerCase()} ${s.surname.toLowerCase()}': s,
    };

    bool _isNewcomerEligible(Student student, PaymentPurpose purpose) {
      if (student.isNewComer != true || student.isNewComerUntil == null)
        return false;
      if (purpose.forNewcomersOnly != true) return true;
      return student.isNewComerUntil!.isAfter(purpose.lastModified!);
    }

    bool _isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      return (student.exceptions ?? []).any((e) =>
          e.exceptionStatus?.toLowerCase() == 'active' &&
          (e.terms?.contains(termId) ?? false));
    }

    double _getAdjustedArrear(
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
      final studentTotalMap = totalPaid[studentKey] ?? {};

      final double totalPaidAmount =
          studentTotalMap.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;
      double totalArrears = 0.0;

      final arrearsCells = normalizedPaymentPurposesOnly.map((purposeName) {
        final purpose = cachedPurposes[purposeName.toLowerCase()];
        if (purpose == null) return 'N/A';

        final isClassFilterAll =
            _selectedClasses.contains("All") || _selectedClasses.isEmpty;
        final isExceptional = (purpose.exceptions?.isNotEmpty ?? false);
        final isNewcomerOnly = purpose.forNewcomersOnly;
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

        if (isNewcomerOnly != false && !_isNewcomerEligible(student, purpose)) {
          arrear = 0.0;
        }

        if (isExceptional) {
          final termsToUse = selectedTermIds.isNotEmpty
              ? selectedTermIds
              : (globalTermId != null ? [globalTermId!.toString()] : []);

          for (final termId in termsToUse) {
            arrear = _getAdjustedArrear(arrear, student, purpose, termId);
          }
        }

        totalArrears += arrear;
        grandTotalArrears += arrear;
        grandTotalPurposeArrears[purposeName] =
            (grandTotalPurposeArrears[purposeName] ?? 0.0) + arrear;

        return arrear.toStringAsFixed(2);
      }).toList();

      final List<String> paidCells =
          normalizedSelectedPaymentPurposes.map((purpose) {
        final paidAmount = studentData[purpose.toLowerCase()] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;

        return paidAmount > 0 ? paidAmount.toStringAsFixed(2) : '0.0';
      }).toList();

      dataRows.add([
        studentKey,
        student.class_,
        ...paidCells,
        totalPaidAmount.toStringAsFixed(2),
      ]);
    }

    final grandTotalPaidRow = [
      'GRAND TOTALS',
      '',
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
          'Detailed Prepayments',
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
              Uint8List pdfBytes = await generateStudentsPDF(
                  _cachedFilteredStudents ?? _filteredPayments);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(
                    context, pdfBytes, 'detailed_payments_report');
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
      body: Center(
        child: SingleChildScrollView(
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
                      child: MultiSelectDialogField<String>(
                        items: _terms
                            .map((t) => MultiSelectItem<String>(t, t))
                            .toList(),
                        title: const Text("Select Terms"),
                        buttonText: const Text("Select Terms"),
                        initialValue: selectedTermIds,
                        onConfirm: (values) async {
                          setState(() {
                            selectedTermIds = values;
                            _selectedClasses = ['All'];
                            _selectedPaymentPurposes = ['All'];
                            _selectedStudent = '';
                            _selectedStartDate = null;
                            _selectedEndDate = null;
                            _filteredPayments = [];
                            _surnameController
                                .clear(); // <-- Clears the field visibly
                          });
                          _role = await getDeviceRole();
                          final prefs = await SharedPreferences.getInstance();
                          _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
                          List<StudentPayment> allStudentPayments = [];
                          List<Student> allStudents = [];

                          if (_role == DeviceRole.host) {
                            final paymentBox =
                                await Hive.openBox<StudentPayment>(
                                    'student_payments');

                            allStudentPayments = paymentBox.values.toList();
                          } else {
                            if (_hostIp!.isEmpty) {
                              _showDialog(
                                  "⚠️ Host IP not set. Please configure connection.");
                              setState(() {});
                              return;
                            }
                            if (_cachedServerStudentPayments == null) {
                              final studentPaymentsResponse = await HttpClient()
                                  .getUrl(Uri.parse(
                                      'http://$_hostIp:8080/api/studentPayments'))
                                  .then((req) => req.close());

                              if (studentPaymentsResponse.statusCode == 200) {
                                final studentPaymentsJsonString =
                                    await studentPaymentsResponse
                                        .transform(utf8.decoder)
                                        .join();

                                final studentPaymentsList =
                                    jsonDecode(studentPaymentsJsonString)
                                        as List;

                                _cachedServerStudentPayments =
                                    studentPaymentsList
                                        .map((json) => studentPaymentsFromJson(
                                            Map<String, dynamic>.from(json)))
                                        .toList();
                              } else {
                                throw Exception(
                                    "Failed to load student Payments data from host.");
                              }
                            }

                            allStudentPayments = _cachedServerStudentPayments!;
                          }

                          final termPayments = allStudentPayments
                              .where((payment) =>
                                  selectedTermIds.contains(payment.termId))
                              .toList();

                          // Rebuild class filter options from this term
                          _classes = ['All'];
                          _classes.addAll(termPayments
                              .map((payment) => payment.studentClass)
                              .toSet()
                              .toList());

                          // Rebuild purpose filter options from this term
                          _purposes = ['All'];
                          _purposes.addAll(termPayments
                              .map((payment) => payment.paymentPurpose)
                              .toSet()
                              .toList());

                          setState(() {});
                        },
                      ),
                    ),
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
                      'Records Found: ${_filteredPayments.map((e) => '${e.studentName} ${e.studentSurname}').toSet().length}',
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
      controller: _surnameController,
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

// Normalize _paymentPurposesOnly
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p; // Preserve first appearance
      }
    }
    final List<String> normalizedPaymentPurposesOnly =
        normalizedPurposesMap.values.toList();

// Same for _selectedPaymentPurposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }
    final List<String> normalizedSelectedPaymentPurposes =
        normalizedSelectedMap.values.toList();

    // Caches
    final paymentPurposeBox = Hive.box<PaymentPurpose>('payment_purposes');
    final Map<String, PaymentPurpose> cachedPurposes = {
      for (var p in paymentPurposeBox.values) p.paymentPurpose.toLowerCase(): p,
    };

    final Map<String, StudentPayment> allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };

    // Precompute all required data
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};

    for (var entry in allStudentsMap.entries) {
      final studentName = entry.key;
      final studentRecord = entry.value;
      final studentClass = studentRecord.studentClass;

      final studentPaymentData = groupedPayments[studentName] ?? {};
      final studentTotalMap = totalPaid[studentName] ?? {};

      final double totalPaidAmount =
          studentTotalMap.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      final List<DataCell> paidCells =
          normalizedSelectedPaymentPurposes.map((purpose) {
        final paidAmount = studentPaymentData[purpose.toLowerCase()] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      dataRows.add(DataRow(
        cells: [
          DataCell(Text(studentName)),
          DataCell(Text(studentClass)),
          ...paidCells,
          DataCell(Text(totalPaidAmount.toStringAsFixed(2))),
        ],
      ));
    }

    // Add grand total row
    dataRows.add(DataRow(
      cells: [
        DataCell(Container(
          color: Colors.blue,
          padding: const EdgeInsets.all(8.0),
          child: const Text('GRAND TOTALS',
              style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const DataCell(SizedBox.shrink()), // Empty cell for class

        ...normalizedSelectedPaymentPurposes
            .map((purpose) => DataCell(Container(
                  color: Colors.greenAccent,
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    (grandTotalPurposePaid[purpose] ?? 0.0).toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ))),
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
                    DataColumn(label: Text('STUDENT NAME')),
                    DataColumn(label: Text('STUDENT CLASS')),
                    ...normalizedSelectedPaymentPurposes
                        .map((p) => DataColumn(label: Text('$p PAID'))),
                    DataColumn(label: Text('TOTAL PAID')),
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
                onPressed: _scrollLeft,
                child: const Icon(Icons.arrow_back),
                mini: true,
                backgroundColor: Colors.blue,
              ),
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

  Future<void> generateAndSaveSpreadsheet() async {
    // Normalize _paymentPurposesOnly
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p; // Preserve first appearance
      }
    }
    final List<String> normalizedPaymentPurposesOnly =
        normalizedPurposesMap.values.toList();

// Same for _selectedPaymentPurposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }
    final List<String> normalizedSelectedPaymentPurposes =
        normalizedSelectedMap.values.toList();

    // Caches
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

    final Map<String, StudentPayment> allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };
    final Map<String, Student> studentLookup = {
      for (var s in allStudents)
        '${s.name.toLowerCase()} ${s.surname.toLowerCase()}': s,
    };

    bool _isNewcomerEligible(Student student, PaymentPurpose purpose) {
      if (student.isNewComer != true || student.isNewComerUntil == null)
        return false;
      if (purpose.forNewcomersOnly != true) return true;

      return student.isNewComerUntil!.isAfter(purpose.lastModified!);
    }

    bool _isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];

      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.contains(termId) ?? false)) continue;
        return true;
      }
      return false;
    }

    double _getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;

      for (var studentException in studentExceptions) {
        // Must be active
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }

        // Must be in same term
        if (!(studentException.terms?.contains(termId) ?? false)) {
          continue;
        }

        // Must be linked to this purpose
        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) {
          continue;
        }

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) {
          continue;
        }

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percentDeduction = arrear * (figure / 100.0);
          totalDeduction += percentDeduction;
        } else {}
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);

      return adjusted;
    }

    // Precompute all required data
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Arrears & Payments'];

    // Add headers for the table
    List<CellValue?> headers = [
      TextCellValue('STUDENT NAME'),
      TextCellValue('STUDENT CLASS'),
      ...normalizedSelectedPaymentPurposes
          .map((p) => TextCellValue('$p (PAID)')),
      TextCellValue('TOTAL PAID'),
    ];
    sheetObject.appendRow(headers);

    for (var entry in allStudentsMap.entries) {
      final studentName = entry.key;
      final studentRecord = entry.value;
      final studentClass = studentRecord.studentClass;

      final studentPaymentData = groupedPayments[studentName] ?? {};
      final studentTotalMap = totalPaid[studentName] ?? {};

      final double totalPaidAmount =
          studentTotalMap.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrears = 0.0;

      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeName) {
        final purpose = cachedPurposes[purposeName.trim().toLowerCase()];
        if (purpose == null) return const DataCell(Text('N/A'));

        final student = studentLookup[studentName.toLowerCase()];
        if (student == null) return const DataCell(Text('N/A'));

        final isClassFilterAll =
            _selectedClasses.contains("All") || _selectedClasses.isEmpty;
        final isExceptional = (purpose.exceptions?.isNotEmpty ?? false);
        final isNewcomerOnly = purpose.forNewcomersOnly;
        final classMatch = purpose.associatedClasses?.any((cls) =>
                cls.trim().toLowerCase() ==
                student.class_.trim().toLowerCase()) ??
            false;

        // Rules for displaying arrears based on class filter
        if (isClassFilterAll) {
          final hasClass = purpose.associatedClasses?.isNotEmpty ?? false;
          if (!hasClass && !isExceptional && (isNewcomerOnly != true)) {
            return const DataCell(Text('0.0'));
          }
        } else {
          if (!classMatch) return const DataCell(Text('0.0'));
        }

        final purposeAmount = _paymentPurposeAmounts[purposeName] ?? 0.0;
        final paid = studentPaymentData[purposeName.toLowerCase()] ?? 0.0;

        double arrears = (purposeAmount - paid).clamp(0.0, purposeAmount);

        // Newcomer check
        if ((isNewcomerOnly != false) &&
            !_isNewcomerEligible(student, purpose)) {
          arrears = 0.0;
        }

        // Exception check
        if (isExceptional) {
          for (var termId in selectedTermIds.isNotEmpty
              ? selectedTermIds
              : [globalTermId]) {
            arrears = _getAdjustedArrear(
                arrears, student, purpose, termId.toString());
          }
        }

        totalArrears += arrears;
        grandTotalArrears += arrears;
        grandTotalPurposeArrears[purposeName] =
            (grandTotalPurposeArrears[purposeName] ?? 0.0) + arrears;

        return DataCell(Text(arrears.toStringAsFixed(2)));
      }).toList();
      final List<CellValue> paidCells =
          normalizedSelectedPaymentPurposes.map((purpose) {
        final paidAmount = studentPaymentData[purpose.toLowerCase()] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;

        final value = paidAmount > 0 ? paidAmount.toStringAsFixed(2) : '0.0';
        return TextCellValue(value);
      }).toList();

      sheetObject.appendRow([
        TextCellValue(studentName),
        TextCellValue(studentClass),
        ...paidCells,
        TextCellValue(totalPaidAmount.toStringAsFixed(2)),
      ]);
    }

    // Add the grand totals row to the spreadsheet
    sheetObject.appendRow([
      TextCellValue('GRAND TOTALS'),
      TextCellValue(''), // Empty cell for student class

      ...normalizedSelectedPaymentPurposes.map((purpose) => TextCellValue(
          (grandTotalPurposePaid[purpose] ?? 0.0).toStringAsFixed(2))),

      TextCellValue(grandTotalPaid.toStringAsFixed(2)), //  for total arrears
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
            '${folder.path}/student_detailed_payments_$timestamp.xlsx';

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
            fileName: 'student_detailed_payments.xlsx',
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
import 'package:zitf_system/arrears_and_prepayments/arrears_and_prepayments.dart';
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

class ViewByScreen extends StatefulWidget {
  const ViewByScreen({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ViewByScreen> {
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

  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;

  List<StudentPayment>? _cachedFilteredStudents;

  @override
  void initState() {
    super.initState();
    _initializeData();
    fetchTerms();
    horizontalScrollController = ScrollController();
    verticalScrollController = ScrollController();
  }

  String? selectedTermId; // This will store the term ID selected by the user.

  String? getCurrentTermId() {
    return selectedTermId ?? globalTermId;
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Payment Details Feedback"),
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
        selectedTermId = _terms.contains(globalTermId)
            ? globalTermId
            : (_terms.isNotEmpty ? _terms.first : null);
      } else {
        _terms = [];
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  void selectTerm(String? termId) {
    final fallback = termId ?? globalTermId;
    if (fallback != null && fallback.isNotEmpty) {
      setState(() {
        selectedTermId = fallback;
      });
    }
  }

// Example of using currentTermId in a method
  void filterByTerm() {
    final currentTermId = getCurrentTermId();

    // Perform filtering logic based on currentTermId
    _filteredPayments = _filteredPayments.where((payment) {
      return payment.termId == currentTermId;
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
      final filteredPayments;
      final filteredPaymentPurposesOnly;
      final currentTermId = selectedTermId ?? globalTermId;

      filteredPayments = allStudentPayments
          .where((payment) => payment.termId == currentTermId)
          .toList();

      filteredPaymentPurposesOnly = allStudentPaymentPurposes
          .where((payment) => payment.termId == currentTermId)
          .toList();

      // Fetch unique classes from filtered payments
      // Fetch unique classes from filtered payments
      final classSet = filteredPayments
          .map((student) => student.studentClass.trim().toLowerCase())
          .toSet();

      _classes = ['All'];
      _classes.addAll(classSet.map((c) => _capitalizeEachWord(c)).toList());

      _selectedClasses = ['All']; // Default selection

      // Fetch unique payment purposes from filtered payments
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
      _paymentPurposesOnly.addAll(allStudentPaymentPurposes
          .where((purposeOnly) => purposeOnly.termId == currentTermId)
          .map((purposeOnly) => purposeOnly.paymentPurpose)
          .toSet()
          .toList());

      // Fetch payment purpose only amounts
      for (var purposeOnly in allStudentPaymentPurposes
          .where((purposeOnly) => purposeOnly.termId == currentTermId)) {
        _paymentPurposeAmounts[purposeOnly.paymentPurpose] =
            purposeOnly.purposeAmount;
      }
      // Sort students by surname
      _filteredPayments.sort((a, b) => _isSortAscending
          ? a.studentSurname.compareTo(b.studentSurname)
          : b.studentSurname.compareTo(a.studentSurname));
      setState(() {});
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
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

      final filteredPayments;
      final filteredStudents;
      final currentTermId = selectedTermId ?? globalTermId;

      filteredPayments = allStudentPayments
          .where((payment) => payment.termId == currentTermId)
          .toList();

      filteredStudents = allStudents
          .where((payment) => payment.termId == currentTermId)
          .toList();

      // Get all payment records for the current term
      List<StudentPayment> paymentRecords = allStudentPayments
          .where((payment) => payment.termId == currentTermId)
          .toList();

      // Get all student records (apply class filter if not 'All')
      List<Student> studentRecords = allStudents
          .where((student) => student.terms!.contains(currentTermId))
          .toList();

      if (_selectedClasses.isNotEmpty &&
          !_selectedClasses.any((c) => c.toLowerCase() == 'all')) {
        studentRecords = studentRecords.where((student) {
          final normalizedClass = student.class_.trim().toLowerCase();
          return _selectedClasses
              .map((c) => c.toLowerCase())
              .contains(normalizedClass);
        }).toList();
      }

      _filteredPayments = allStudentPayments
          .where((purposeOnly) => purposeOnly.termId == currentTermId)
          .toList();

      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
        final selectedClassKeys =
            _selectedClasses.map((e) => e.trim().toLowerCase()).toSet();
        _filteredPayments = _filteredPayments.where((payment) {
          return selectedClassKeys
              .contains(payment.studentClass.trim().toLowerCase());
        }).toList();
      }

      // Merge data: for each student, check if they have any payment record.
      List<StudentPayment> combinedRecords = [];

      for (var student in studentRecords) {
        // Option 1: if you have a student ID or unique identifier to join records, use it.
        // Here we assume each payment has a studentId and each student has an id.
        final studentPayments = paymentRecords
            .where((payment) =>
                payment.studentName.toLowerCase() ==
                    student.name.toLowerCase() &&
                payment.studentSurname.toLowerCase() ==
                    student.surname.toLowerCase() &&
                payment.studentClass.toLowerCase().trim() ==
                    student.class_.toLowerCase().trim() &&
                (payment.termId == currentTermId ||
                    student.terms!.contains(currentTermId)))
            .toList();

        if (studentPayments.isEmpty) {
          // Create a dummy record for a student with no payments
          int newId = await getNextId();
          String receiptNumber = uuid.v4();
          List<String> modifiedFields = [];
          modifiedFields.add('id');
          modifiedFields.add('receiptNumber');
          modifiedFields.add('studentName');
          modifiedFields.add('studentSurname');
          modifiedFields.add('studentClass');
          modifiedFields.add('phoneNumber');
          modifiedFields.add('paymentPurpose');
          modifiedFields.add('amountToPay');
          modifiedFields.add('paymentDate');
          modifiedFields.add('termId');
          combinedRecords.add(
            StudentPayment(
              id: newId,
              receiptNumber: receiptNumber,
              studentName: student.name,
              studentSurname: student.surname,
              studentClass: student.class_,
              termId: currentTermId,
              phoneNumber: student.phoneNumber,
              paymentPurpose: '',
              amountToPay: 0.0,
              paymentDate: DateTime.now(),
              syncStatus: false, // Set syncStatus to false
              lastModified:
                  DateTime.now(), // Set lastModified to current datetime
              operationType: 'create', // Set operationType to 'create'
              modifiedFields: modifiedFields,
              // Set default or empty payment purpose if needed.
            ),
          );
        } else {
          // If there are multiple records per student, you can either combine them
          // or add them all. In many cases, you may want to combine payment purposes.
          combinedRecords.addAll(studentPayments);
        }
      }

      // Now, _filteredPayments contains students even if they have no payment.
      _filteredPayments = combinedRecords;

      if (_selectedStudent != null && _selectedStudent!.trim().isNotEmpty) {
        final query = _selectedStudent!.trim().toLowerCase();

        _filteredPayments = _filteredPayments.where((payment) {
          final fullName = '${payment.studentName} ${payment.studentSurname}'
              .trim()
              .toLowerCase();
          return fullName.contains(query);
        }).toList();
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
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
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

    final cachedPurposes = {
      for (var p in allStudentPaymentPurposes)
        p.paymentPurpose.toLowerCase(): p,
    };

    final allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };
    final studentLookup = {
      for (var s in allStudents)
        '${s.name.toLowerCase()} ${s.surname.toLowerCase()}': s,
    };

    bool _isNewcomerEligible(Student student, PaymentPurpose purpose) {
      if (student.isNewComer != true || student.isNewComerUntil == null)
        return false;
      if (purpose.forNewcomersOnly != true) return true;
      return student.isNewComerUntil!.isAfter(purpose.lastModified!);
    }

    bool _isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      return (student.exceptions ?? []).any((e) =>
          e.exceptionStatus?.toLowerCase() == 'active' &&
          (e.terms?.contains(termId) ?? false));
    }

    double _getAdjustedArrear(
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
      final studentTotalMap = totalPaid[studentKey] ?? {};

      final double totalPaidAmount =
          studentTotalMap.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;
      double totalArrears = 0.0;

      final arrearsCells = normalizedPaymentPurposesOnly.map((purposeName) {
        final purpose = cachedPurposes[purposeName.toLowerCase()];
        if (purpose == null) return 'N/A';

        final isClassFilterAll =
            _selectedClasses.contains("All") || _selectedClasses.isEmpty;
        final isExceptional = (purpose.exceptions?.isNotEmpty ?? false);
        final isNewcomerOnly = purpose.forNewcomersOnly;
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

        if (isNewcomerOnly != false && !_isNewcomerEligible(student, purpose)) {
          arrear = 0.0;
        }

        if (isExceptional) {
          arrear = _getAdjustedArrear(arrear, student, purpose,
              selectedTermId ?? globalTermId.toString());
        }

        totalArrears += arrear;
        grandTotalArrears += arrear;
        grandTotalPurposeArrears[purposeName] =
            (grandTotalPurposeArrears[purposeName] ?? 0.0) + arrear;

        return arrear.toStringAsFixed(2);
      }).toList();

      final List<String> paidCells =
          normalizedSelectedPaymentPurposes.map((purpose) {
        final paidAmount = studentData[purpose.toLowerCase()] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;

        return paidAmount > 0 ? paidAmount.toStringAsFixed(2) : '0.0';
      }).toList();

      dataRows.add([
        studentKey,
        student.class_,
        ...paidCells,
        totalPaidAmount.toStringAsFixed(2),
      ]);
    }

    final grandTotalPaidRow = [
      'GRAND TOTALS',
      '',
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
          'Detailed Prepayments',
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
              Uint8List pdfBytes = await generateStudentsPDF(
                  _cachedFilteredStudents ?? _filteredPayments);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(
                    context, pdfBytes, 'detailed_payments_report');
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCard(
                      title: 'Select Term',
                      child: DropdownButtonFormField<String>(
                        value: selectedTermId,
                        hint: const Text('Select Term'),
                        onChanged: (value) async {
                          if (value == null) return;

                          setState(() {
                            selectedTermId = value;
                            _selectedClasses = ['All'];
                            _selectedPaymentPurposes = ['All'];
                            _selectedStudent = '';
                            _selectedStartDate = null;
                            _selectedEndDate = null;
                            _filteredPayments = [];
                            _surnameController
                                .clear(); // <-- Clears the field visibly
                          });
                          _role = await getDeviceRole();
                          final prefs = await SharedPreferences.getInstance();
                          _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
                          List<StudentPayment> allStudentPayments = [];
                          List<Student> allStudents = [];

                          if (_role == DeviceRole.host) {
                            final paymentBox =
                                await Hive.openBox<StudentPayment>(
                                    'student_payments');

                            allStudentPayments = paymentBox.values.toList();
                          } else {
                            if (_hostIp!.isEmpty) {
                              _showDialog(
                                  "⚠️ Host IP not set. Please configure connection.");
                              setState(() {});
                              return;
                            }
                            if (_cachedServerStudentPayments == null) {
                              final studentPaymentsResponse = await HttpClient()
                                  .getUrl(Uri.parse(
                                      'http://$_hostIp:8080/api/studentPayments'))
                                  .then((req) => req.close());

                              if (studentPaymentsResponse.statusCode == 200) {
                                final studentPaymentsJsonString =
                                    await studentPaymentsResponse
                                        .transform(utf8.decoder)
                                        .join();

                                final studentPaymentsList =
                                    jsonDecode(studentPaymentsJsonString)
                                        as List;

                                _cachedServerStudentPayments =
                                    studentPaymentsList
                                        .map((json) => studentPaymentsFromJson(
                                            Map<String, dynamic>.from(json)))
                                        .toList();
                              } else {
                                throw Exception(
                                    "Failed to load student Payments data from host.");
                              }
                            }

                            allStudentPayments = _cachedServerStudentPayments!;
                          }

                          final termPayments = allStudentPayments
                              .where(
                                  (payment) => payment.termId == selectedTermId)
                              .toList();

                          // Rebuild class filter options from this term
                          _classes = ['All'];
                          _classes.addAll(termPayments
                              .map((payment) => payment.studentClass)
                              .toSet()
                              .toList());

                          // Rebuild purpose filter options from this term
                          _purposes = ['All'];
                          _purposes.addAll(termPayments
                              .map((payment) => payment.paymentPurpose)
                              .toSet()
                              .toList());

                          setState(() {});
                        },
                        items: _terms.map((termId) {
                          return DropdownMenuItem(
                            value: termId,
                            child: Text(termId),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
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
                      'Records Found: ${_filteredPayments.map((e) => '${e.studentName} ${e.studentSurname}').toSet().length}',
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

  Widget _buildTermDropdown() {
    if (_terms.isEmpty) {
      return const Text("Loading terms...");
    }

    return DropdownButton<String>(
      value: selectedTermId,
      isExpanded: true,
      hint: const Text(
        "Select Term", // Placeholder if no term is selected
        style: TextStyle(fontSize: 16),
      ),
      items: _terms.map((term) {
        return DropdownMenuItem<String>(
          value: term,
          child: Text(
            term,
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedTermId = value!;
        });

        // Call _fetchInitialData to reload data based on the selected term
        _fetchInitialData();
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
      controller: _surnameController,
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

// Normalize _paymentPurposesOnly
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p; // Preserve first appearance
      }
    }
    final List<String> normalizedPaymentPurposesOnly =
        normalizedPurposesMap.values.toList();

// Same for _selectedPaymentPurposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }
    final List<String> normalizedSelectedPaymentPurposes =
        normalizedSelectedMap.values.toList();

    // Caches
    final paymentPurposeBox = Hive.box<PaymentPurpose>('payment_purposes');
    final Map<String, PaymentPurpose> cachedPurposes = {
      for (var p in paymentPurposeBox.values) p.paymentPurpose.toLowerCase(): p,
    };

    final Map<String, StudentPayment> allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };

    // Precompute all required data
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};

    for (var entry in allStudentsMap.entries) {
      final studentName = entry.key;
      final studentRecord = entry.value;
      final studentClass = studentRecord.studentClass;

      final studentPaymentData = groupedPayments[studentName] ?? {};
      final studentTotalMap = totalPaid[studentName] ?? {};

      final double totalPaidAmount =
          studentTotalMap.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      final List<DataCell> paidCells =
          normalizedSelectedPaymentPurposes.map((purpose) {
        final paidAmount = studentPaymentData[purpose.toLowerCase()] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;
        return DataCell(Text(paidAmount.toStringAsFixed(2)));
      }).toList();

      dataRows.add(DataRow(
        cells: [
          DataCell(Text(studentName)),
          DataCell(Text(studentClass)),
          ...paidCells,
          DataCell(Text(totalPaidAmount.toStringAsFixed(2))),
        ],
      ));
    }

    // Add grand total row
    dataRows.add(DataRow(
      cells: [
        DataCell(Container(
          color: Colors.blue,
          padding: const EdgeInsets.all(8.0),
          child: const Text('GRAND TOTALS',
              style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const DataCell(SizedBox.shrink()), // Empty cell for class

        ...normalizedSelectedPaymentPurposes
            .map((purpose) => DataCell(Container(
                  color: Colors.greenAccent,
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    (grandTotalPurposePaid[purpose] ?? 0.0).toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ))),
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
                    DataColumn(label: Text('STUDENT NAME')),
                    DataColumn(label: Text('STUDENT CLASS')),
                    ...normalizedSelectedPaymentPurposes
                        .map((p) => DataColumn(label: Text('$p PAID'))),
                    DataColumn(label: Text('TOTAL PAID')),
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
                onPressed: _scrollLeft,
                child: const Icon(Icons.arrow_back),
                mini: true,
                backgroundColor: Colors.blue,
              ),
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

  Future<void> generateAndSaveSpreadsheet() async {
    // Normalize _paymentPurposesOnly
    final Map<String, String> normalizedPurposesMap = {};
    for (var p in _paymentPurposesOnly) {
      final key = p.toLowerCase();
      if (!normalizedPurposesMap.containsKey(key)) {
        normalizedPurposesMap[key] = p; // Preserve first appearance
      }
    }
    final List<String> normalizedPaymentPurposesOnly =
        normalizedPurposesMap.values.toList();

// Same for _selectedPaymentPurposes
    final Map<String, String> normalizedSelectedMap = {};
    for (var p in _selectedPaymentPurposes) {
      final key = p.toLowerCase();
      if (!normalizedSelectedMap.containsKey(key)) {
        normalizedSelectedMap[key] = p;
      }
    }
    final List<String> normalizedSelectedPaymentPurposes =
        normalizedSelectedMap.values.toList();

    // Caches
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

    final Map<String, StudentPayment> allStudentsMap = {
      for (var payment in _filteredPayments)
        '${payment.studentName.toLowerCase()} ${payment.studentSurname.toLowerCase()}':
            payment,
    };
    final Map<String, Student> studentLookup = {
      for (var s in allStudents)
        '${s.name.toLowerCase()} ${s.surname.toLowerCase()}': s,
    };

    bool _isNewcomerEligible(Student student, PaymentPurpose purpose) {
      if (student.isNewComer != true || student.isNewComerUntil == null)
        return false;
      if (purpose.forNewcomersOnly != true) return true;

      return student.isNewComerUntil!.isAfter(purpose.lastModified!);
    }

    bool _isExceptionalApplicable(
        Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];

      for (var exception in studentExceptions) {
        if (exception.exceptionStatus!.toLowerCase() != 'active') continue;
        if (!(exception.terms?.contains(termId) ?? false)) continue;
        return true;
      }
      return false;
    }

    double _getAdjustedArrear(
        double arrear, Student student, PaymentPurpose purpose, String termId) {
      final studentExceptions = student.exceptions ?? [];
      final applicablePurposeExceptions = purpose.exceptions ?? [];

      double totalDeduction = 0.0;

      for (var studentException in studentExceptions) {
        // Must be active
        if (studentException.exceptionStatus!.toLowerCase() != 'active') {
          continue;
        }

        // Must be in same term
        if (!(studentException.terms?.contains(termId) ?? false)) {
          continue;
        }

        // Must be linked to this purpose
        final isLinkedToPurpose = applicablePurposeExceptions
            .any((pEx) => pEx.exceptionId == studentException.exceptionId);

        if (!isLinkedToPurpose) {
          continue;
        }

        final double? figure =
            double.tryParse(studentException.exceptionFigure ?? '');
        if (figure == null) {
          continue;
        }

        if (studentException.exceptionType!.toLowerCase() == 'amount') {
          totalDeduction += figure;
        } else if (studentException.exceptionType!.toLowerCase() ==
            'percentage') {
          final percentDeduction = arrear * (figure / 100.0);
          totalDeduction += percentDeduction;
        } else {}
      }

      final adjusted = (arrear - totalDeduction).clamp(0.0, arrear);

      return adjusted;
    }

    // Precompute all required data
    final List<DataRow> dataRows = [];
    double grandTotalPaid = 0.0;
    double grandTotalArrears = 0.0;
    final Map<String, double> grandTotalPurposePaid = {};
    final Map<String, double> grandTotalPurposeArrears = {};

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Arrears & Payments'];

    // Add headers for the table
    List<CellValue?> headers = [
      TextCellValue('STUDENT NAME'),
      TextCellValue('STUDENT CLASS'),
      ...normalizedSelectedPaymentPurposes
          .map((p) => TextCellValue('$p (PAID)')),
      TextCellValue('TOTAL PAID'),
    ];
    sheetObject.appendRow(headers);

    for (var entry in allStudentsMap.entries) {
      final studentName = entry.key;
      final studentRecord = entry.value;
      final studentClass = studentRecord.studentClass;

      final studentPaymentData = groupedPayments[studentName] ?? {};
      final studentTotalMap = totalPaid[studentName] ?? {};

      final double totalPaidAmount =
          studentTotalMap.values.fold(0.0, (a, b) => a + b);
      grandTotalPaid += totalPaidAmount;

      double totalArrears = 0.0;

      final List<DataCell> arrearsCells =
          normalizedPaymentPurposesOnly.map((purposeName) {
        final purpose = cachedPurposes[purposeName.trim().toLowerCase()];
        if (purpose == null) return const DataCell(Text('N/A'));

        final student = studentLookup[studentName.toLowerCase()];
        if (student == null) return const DataCell(Text('N/A'));

        final isClassFilterAll =
            _selectedClasses.contains("All") || _selectedClasses.isEmpty;
        final isExceptional = (purpose.exceptions?.isNotEmpty ?? false);
        final isNewcomerOnly = purpose.forNewcomersOnly;
        final classMatch = purpose.associatedClasses?.any((cls) =>
                cls.trim().toLowerCase() ==
                student.class_.trim().toLowerCase()) ??
            false;

        // Rules for displaying arrears based on class filter
        if (isClassFilterAll) {
          final hasClass = purpose.associatedClasses?.isNotEmpty ?? false;
          if (!hasClass && !isExceptional && (isNewcomerOnly != true)) {
            return const DataCell(Text('0.0'));
          }
        } else {
          if (!classMatch) return const DataCell(Text('0.0'));
        }

        final purposeAmount = _paymentPurposeAmounts[purposeName] ?? 0.0;
        final paid = studentPaymentData[purposeName.toLowerCase()] ?? 0.0;

        double arrears = (purposeAmount - paid).clamp(0.0, purposeAmount);

        // Newcomer check
        if ((isNewcomerOnly != false) &&
            !_isNewcomerEligible(student, purpose)) {
          arrears = 0.0;
        }

        // Exception check
        if (isExceptional) {
          arrears = _getAdjustedArrear(arrears, student, purpose,
              selectedTermId ?? globalTermId.toString());
        }

        totalArrears += arrears;
        grandTotalArrears += arrears;
        grandTotalPurposeArrears[purposeName] =
            (grandTotalPurposeArrears[purposeName] ?? 0.0) + arrears;

        return DataCell(Text(arrears.toStringAsFixed(2)));
      }).toList();
      final List<CellValue> paidCells =
          normalizedSelectedPaymentPurposes.map((purpose) {
        final paidAmount = studentPaymentData[purpose.toLowerCase()] ?? 0.0;
        grandTotalPurposePaid[purpose] =
            (grandTotalPurposePaid[purpose] ?? 0.0) + paidAmount;

        final value = paidAmount > 0 ? paidAmount.toStringAsFixed(2) : '0.0';
        return TextCellValue(value);
      }).toList();

      sheetObject.appendRow([
        TextCellValue(studentName),
        TextCellValue(studentClass),
        ...paidCells,
        TextCellValue(totalPaidAmount.toStringAsFixed(2)),
      ]);
    }

    // Add the grand totals row to the spreadsheet
    sheetObject.appendRow([
      TextCellValue('GRAND TOTALS'),
      TextCellValue(''), // Empty cell for student class

      ...normalizedSelectedPaymentPurposes.map((purpose) => TextCellValue(
          (grandTotalPurposePaid[purpose] ?? 0.0).toStringAsFixed(2))),

      TextCellValue(grandTotalPaid.toStringAsFixed(2)), //  for total arrears
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
            '${folder.path}/student_detailed_payments_$timestamp.xlsx';

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
            fileName: 'student_detailed_payments.xlsx',
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






