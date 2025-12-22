// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:async';
import 'package:background_sms/background_sms.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/services.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/rng.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:http/http.dart' as http;

class _CachedStudents {
  final List<Student> students;
  final DateTime expiresAt;
  _CachedStudents(this.students, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class MakePaymentScreen extends StatefulWidget {
  const MakePaymentScreen({Key? key}) : super(key: key);

  @override
  _MakePaymentScreenState createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends State<MakePaymentScreen> {
// bluetooth helper
  late BluetoothHelper bluetoothHelper;
  List<String> _arrearsTerms = [];
  String? _selectedArrearsTerm;

  final _formKey = GlobalKey<FormState>();
  final _studentSearchController = TextEditingController();
  final TextEditingController _paymentAmountController =
      TextEditingController();

  final List<Map<String, dynamic>> _paymentPurposes = [];
  PaymentPurpose? _selectedPaymentPurpose;
  double? _paymentAmount;
  Student? _selectedStudent;
  DateTime _paymentDate = DateTime.now();
  String? _paymentInfo;
  String? _paymentInfo11;

  String? _paymentInfo1;
  String? _paymentInfo2;

  String? _phoneNumber;

  String? selectedTermId;
  String? selectedSchool;

  List<String> _terms = []; // Declare without 'final'
  List<String> _schools = []; // Declare without 'final'

  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;

  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;
  List<School>? _cachedServerSchoolInfo;
  Map<String, Terms> _termsMap = {};

  List<StudentPayment>? _cachedFilteredStudents;

  Future<void>? _arrearsFuture;
  bool _isProcessingPayment = false;

  Future<double>? _totalArrearsFuture;

  Timer? _searchDebounce;
  final Duration _searchDebounceDuration = const Duration(milliseconds: 350);

// Simple in-memory cache for server search results
  final Map<String, _CachedStudents> _studentsCache = {};

  List<Student>?
      _cachedServerStudentsForSearch; // used only for immediate parse

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

  BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

  bool _connected = false;
  BluetoothDevice? _device;
  String tips = 'connect receipt priter';
  int? BluetoothStates;

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Make Payment Submission Feedback"),
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
  @override
  void initState() {
    super.initState();
    fetchTerms();
    fetchSchools();
    fetchStudentsMetadata();
    fetchPaymentPurposes();
    fetchStudentPayments();

    // Create a BluetoothHelper instance
    bluetoothHelper = BluetoothHelper();

    // Set up the connection state change callback
    bluetoothHelper.onConnectionStateChanged = (isConnected, message) {
      debugPrint('Connection Statuses: $isConnected, Message: $message');
      setState(() {
        _connected = isConnected; // Update UI state
        tips = message; // Update message dynamically
      });
    };

    // Initialize Bluetooth
    bluetoothHelper.initBluetooth();

    // Verify the connection status periodically or based on user action
    Future.delayed(const Duration(seconds: 5), () {
      bluetoothHelper.verifyConnection();
    });

    BluetoothHelper().bluetoothPrint.state.listen((state) {
      BluetoothStates = state;
    });
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
        _termsMap = {for (var t in allTerms) t.termId: t}; // for quick lookup
        selectedTermId = _terms.contains(globalTermId)
            ? globalTermId
            : (_terms.isNotEmpty ? _terms.first : null);
      } else {
        _terms = [];
        _termsMap = {};
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  Future<void> fetchSchools() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<School> allSchools = [];

      if (_role == DeviceRole.host) {
        final box = await Hive.openBox<School>('school');
        allSchools = box.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerSchoolInfo == null) {
          final schooResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/school'))
              .then((req) => req.close());

          if (schooResponse.statusCode == 200) {
            final schoolsJsonString =
                await schooResponse.transform(utf8.decoder).join();

            final schoolsList = jsonDecode(schoolsJsonString) as List;

            _cachedServerSchoolInfo = schoolsList
                .map((json) => schoolFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load school data from host.");
          }
        }
        allSchools = _cachedServerSchoolInfo!;
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  Future<void> fetchStudentsMetadata() async {
    // Keep lightweight startup tasks here (e.g., counts, last sync timestamp)
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      // Optionally fetch small metadata endpoint like /api/students/summary
    } catch (e) {
      debugPrint('❌ fetchStudentsMetadata error: $e');
    }
  }

  Future<void> fetchPaymentPurposes() async {
    try {
      debugPrint("🟨 Starting _fetchInitialData");

      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<PaymentPurpose> allStudentPaymentPurposes = [];

      if (_role == DeviceRole.host) {
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
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<void> fetchStudentPayments() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();
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

        allStudentPayments = _cachedServerStudentPayments!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
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

  Future<void> sendSms(String allPaymentsInfoadminnew, String recipient) async {
    if (Platform.isAndroid) {
      var status = await Permission.sms.status;
      debugPrint('🔒 SMS Permission status: ${status.isGranted}');

      if (!status.isGranted) {
        var result = await Permission.sms.request();
        debugPrint('📛 Permission request result: ${result.isGranted}');

        if (!result.isGranted) {
          _showDialog('SMS permission is not granted. Cannot send SMS.');
          return;
        }
      }
    }

    try {
      if (Platform.isAndroid) {
        const int smsChunkLimit = 153; // Use 153 to allow concatenation headers

        List<String> messageParts = [];
        for (int i = 0;
            i < allPaymentsInfoadminnew.length;
            i += smsChunkLimit) {
          int end = (i + smsChunkLimit < allPaymentsInfoadminnew.length)
              ? i + smsChunkLimit
              : allPaymentsInfoadminnew.length;
          messageParts.add(allPaymentsInfoadminnew.substring(i, end));
        }

        for (int i = 0; i < messageParts.length; i++) {
          String part = messageParts[i];
          SmsStatus result = await BackgroundSms.sendMessage(
            phoneNumber: recipient,
            message: part,
          );

          if (result != SmsStatus.sent) {
            debugPrint('❌ Failed to send part ${i + 1}');
          } else {
            debugPrint('✅ Part ${i + 1} sent successfully.');
          }

          await Future.delayed(
              const Duration(milliseconds: 500)); // Delay to avoid issues
        }
      }
    } catch (e) {
      debugPrint('🔥 Exception during SMS send: $e');
      _showDialog('Error sending SMS: $e');
    }
  }

  double _calculateArrearsForTerm({
    required PaymentPurpose purpose,
    required String termId,
    required String purposeName,
  }) {
    // Use appropriate data source depending on role
    final allPayments = _role == DeviceRole.host
        ? Hive.box<StudentPayment>('student_payments').values
        : (_cachedServerStudentPayments ?? []);

    final allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values
        : (_cachedServerTerms ?? []);

    // Total paid from Hive
    final hivePaid = allPayments
        .where((payment) =>
            payment.studentName.toLowerCase() ==
                _selectedStudent!.name.toLowerCase() &&
            payment.studentSurname.toLowerCase() ==
                _selectedStudent!.surname.toLowerCase() &&
            payment.termId == termId &&
            payment.paymentPurpose.toLowerCase() == purposeName.toLowerCase())
        .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));

    // Total paid in current session
    final sessionPaid = _paymentPurposes
        .where((p) =>
            p['termId'] == termId &&
            p['purpose'].paymentPurpose.toLowerCase() ==
                purposeName.toLowerCase())
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));

    double totalPaid = hivePaid + sessionPaid;
    double arrears = purpose.purposeAmount - totalPaid;

    // Apply exception adjustment
    arrears = getAdjustedArrear(
      arrears,
      _selectedStudent!,
      purpose,
      termId,
    );

    // Handle newcomer-only rule
    if (purpose.forNewcomersOnly == true) {
      if (_selectedStudent!.isNewComer != true) {
        return 0.0;
      }

      final newcomerUntil = _selectedStudent!.isNewComerUntil;
      final newcomerFrom = _selectedStudent!.isNewComerFrom;

      if (newcomerUntil != null && newcomerFrom != null) {
        try {
          final term = allTerms.firstWhere(
            (t) =>
                (t.termId?.trim().toLowerCase() ?? '') ==
                (purpose.termId?.trim().toLowerCase() ?? ''),
          );
          if (term.endDate != null) {
            if (term.startDate.isAfter(newcomerUntil) ||
                term.endDate!.isBefore(newcomerFrom)) {
              return 0.0;
            }
          }
        } catch (_) {
          return 0.0; // Term not found — skip
        }
      } else if (newcomerUntil != null) {
        try {
          final term = allTerms.firstWhere(
            (t) =>
                (t.termId?.trim().toLowerCase() ?? '') ==
                (purpose.termId?.trim().toLowerCase() ?? ''),
          );
          if (term.startDate.isAfter(newcomerUntil)) {
            return 0.0;
          }
        } catch (_) {
          return 0.0; // Term not found — skip
        }
      } else {
        return 0.0;
      }
    }

    return arrears;
  }

  Future<Map<String, dynamic>> _buildOtherArrearsSummaryWithTotal() async {
    final prefs = await SharedPreferences.getInstance();
    final termAggregation = prefs.getBool('termAggregation') ?? false;

    try {
      final role = await getDeviceRole();

      // ✅ Get payment purposes
      List<PaymentPurpose> allPurposes;
      if (role == DeviceRole.host) {
        final paymentPurposeBox =
            await Hive.openBox<PaymentPurpose>('payment_purposes');
        allPurposes = paymentPurposeBox.values
            .where((p) =>
                p.associatedClasses?.contains(_selectedStudent!.class_) == true)
            .toList();
      } else {
        if (_cachedServerStudentPaymentPurposes == null) {
          await fetchPaymentPurposes();
        }
        allPurposes = _cachedServerStudentPaymentPurposes!
            .where((p) =>
                p.associatedClasses?.contains(_selectedStudent!.class_) == true)
            .toList();
      }

      String summary = '\n';
      String summaryadmin = '';
      double grandTotal = 0.0;

      if (termAggregation) {
        // ✅ CASE 1: Aggregate across terms for same purpose
        final Map<String, double> aggregatedPurposeTotals = {};

        for (final purpose in allPurposes) {
          for (final studentTerm in _selectedStudent!.terms ?? []) {
            if (purpose.termId != studentTerm) continue;

            double arrears = _calculateArrearsForTerm(
              purpose: purpose,
              termId: studentTerm,
              purposeName: purpose.paymentPurpose,
            );
            arrears = arrears.clamp(0.0, double.infinity);

            if (arrears > 0) {
              final cleanPurpose = purpose.paymentPurpose
                  .replaceAll(RegExp(r'\s*\(.*?\)'), '')
                  .trim()
                  .toUpperCase();

              aggregatedPurposeTotals[cleanPurpose] =
                  (aggregatedPurposeTotals[cleanPurpose] ?? 0.0) + arrears;
            }
          }
        }

        // Build summary
        aggregatedPurposeTotals.forEach((purpose, total) {
          summary += '$purpose >> -\$${total.toStringAsFixed(2)}\n';
          grandTotal += total;
        });
      } else {
        // ✅ CASE 2: Keep arrears separate by term (with term headers)
        final Map<String, Map<String, double>> termWiseMap = {};

        for (final purpose in allPurposes) {
          for (final studentTerm in _selectedStudent!.terms ?? []) {
            if (purpose.termId != studentTerm) continue;

            double arrears = _calculateArrearsForTerm(
              purpose: purpose,
              termId: studentTerm,
              purposeName: purpose.paymentPurpose,
            );
            arrears = arrears.clamp(0.0, double.infinity);

            if (arrears > 0) {
              final term = studentTerm.toUpperCase();
              final purposeName = purpose.paymentPurpose.toUpperCase();

              termWiseMap.putIfAbsent(term, () => {});
              termWiseMap[term]![purposeName] =
                  (termWiseMap[term]![purposeName] ?? 0.0) + arrears;
            }
          }
        }

        // ✅ Build summary grouped by term
        for (final termEntry in termWiseMap.entries) {
          final term = termEntry.key;
          final purposeMap = termEntry.value;

          summary += '\n-TERM: $term \n';
          for (final entry in purposeMap.entries) {
            summary += '${entry.key} >> \$${entry.value.toStringAsFixed(2)}\n';
            grandTotal += entry.value;
          }
        }
      }

      // ✅ TOTAL line (only once)
      if (grandTotal > 0) {
        final totalLine = termAggregation
            ? '\nTOTAL ARREARS: -\$${grandTotal.toStringAsFixed(2)}\n'
            : '\nTOTAL ARREARS: \$${grandTotal.toStringAsFixed(2)}\n';
        summary += totalLine;
        summaryadmin += totalLine;
      }

      return {
        'summary': summary.trim().isEmpty ? '' : summary,
        'grandTotalArrears': grandTotal,
        'summaryadmin': summaryadmin.trim().isEmpty ? '' : summaryadmin,
      };
    } catch (e) {
      debugPrint("❌ Error building arrears summary: $e");
      return {
        'summary': '',
        'grandTotalArrears': 0.0,
        'summaryadmin': '',
      };
    }
  }

  Future<School> _fetchSchoolInfo() async {
    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<School>('school');
      if (box.isNotEmpty) {
        return box.values.first;
      }
    } else {
      if (_cachedServerSchoolInfo != null &&
          _cachedServerSchoolInfo!.isNotEmpty) {
        return _cachedServerSchoolInfo!.first;
      }
    }

    // Fallback if no valid data found
    return School(
      schoolName: 'School Receipt',
      schoolAddress: 'P.O.Box....',
      schoolEmail: '@school.co.zw',
      schoolPhoneNumber: '+263.........',
    );
  }

  Future<Box<PaymentPurpose>> _openPaymentPurposeBox() async {
    return await Hive.openBox<PaymentPurpose>('payment_purposes');
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTermId(
      String termId) async {
    if (_role == DeviceRole.host) {
      final box = await _openPaymentPurposeBox();
      return box.values.where((p) => p.termId == termId).toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        await fetchPaymentPurposes(); // Ensure it's loaded
      }
      return _cachedServerStudentPaymentPurposes!
          .where((p) => p.termId == termId)
          .toList();
    }
  }

  Future<List<PaymentPurpose>> _getPaymentPurposesForGlobalTerm() async {
    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      return box.values.where((p) => p.termId == globalTermId).toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        await fetchPaymentPurposes(); // Ensure data is available
      }
      return _cachedServerStudentPaymentPurposes!
          .where((p) => p.termId == globalTermId)
          .toList();
    }
  }

  bool deepMatchStudentWithInverse(Student s, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final name = (s.name ?? '').toLowerCase();
    final surname = (s.surname ?? '').toLowerCase();
    final fullName = ('$name $surname').trim();
    final fullNameInverse = ('$surname $name').trim();
    final idNum = (s.studentIdNumber ?? '').toLowerCase();
    final classe = (s.class_ ?? '').toLowerCase();

    final fields = [
      name,
      surname,
      fullName,
      fullNameInverse,
      idNum,
      classe,
    ];

    // Every search word must match *some* field
    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  Future<void> _searchStudent(String query, {bool showDialog = false}) async {
    try {
      // Ensure we have role and host IP resolved
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? _hostIp;

      List<Student> results = [];

      if (_role == DeviceRole.host) {
        // Host: local Hive query (fast)
        final studentBox = await Hive.openBox<Student>('students');
        results = studentBox.values
            .where((s) => s.termId != null)
            .where((s) => deepMatchStudentWithInverse(s, query))
            .toList();
      } else {
        // Client: check per-query cache first
        final cached = _studentsCache[query];
        if (cached != null && cached.isValid) {
          results = cached.students;
        } else {
          if (_hostIp == null || _hostIp!.isEmpty) {
            _showDialog('⚠️ Host IP not set. Please configure connection.');
            return;
          }

          final uri = Uri.parse(
              'http://$_hostIp:8080/api/students?search=${Uri.encodeQueryComponent(query)}');
          final request = await HttpClient().getUrl(uri);
          final response = await request.close();

          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final parsed = jsonDecode(body) as List<dynamic>;

            results = parsed
                .map(
                    (json) => studentsFromJson(Map<String, dynamic>.from(json)))
                .toList();

            // store in cache for short time (30 seconds)
            _studentsCache[query] = _CachedStudents(
                results, DateTime.now().add(const Duration(seconds: 30)));
          } else {
            _showDialog(
                '⚠️ Failed to fetch students from host (${response.statusCode})');
            return;
          }
        }
      }

      if (results.isEmpty) {
        if (showDialog) _showDialog('No matching students found for: "$query"');
      } else {
        if (showDialog) _displayStudentSelectionDialog(results);
      }
    } catch (e, st) {
      debugPrint('❌ _searchStudent error: $e');
      debugPrint('🪵 Stacktrace: $st');
      _showDialog('⚠️ Error searching students.');
    }
  }

  void _displayStudentSelectionDialog(List<Student> students) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a Student'),
          content: SizedBox(
            height: 200,
            width: 200,
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  title: Text(capitalize('${student.name} ${student.surname}')),
                  subtitle: Text(capitalize('Class: ${student.class_}')),
                  onTap: () {
                    setState(() {
                      _selectedStudent = student;
                      _totalArrearsFuture = _computeTotalStudentArrears(
                          student); // 👈 trigger arrears computation
                      _selectedPaymentPurpose = null;
                      _selectedArrearsTerm = null;
                      _paymentInfo = '';
                      _paymentInfo11 = '';
                      _paymentInfo1 = '';
                      _paymentInfo2 = '';
                    });
                    Navigator.pop(context); // Close the dialog
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPaymentPurpose() async {
    if (_selectedPaymentPurpose == null ||
        _paymentAmount == null ||
        _paymentAmount! <= 0) {
      _showDialog('Please select a valid payment purpose and amount.');
      return;
    }

    if (_arrearsTerms.isNotEmpty && _selectedArrearsTerm == null) {
      _showDialog('Please select a term to pay arrears.');
      return;
    }

    final double amountPaid = _paymentAmount!;
    final String paymentPurpose =
        _selectedPaymentPurpose!.paymentPurpose.toUpperCase();
    final String term = _selectedArrearsTerm ?? globalTermId.toString();

    Map<String, double> updatedArrears = Map.from(_arrearsDetails);
    if (updatedArrears.containsKey(term)) {
      updatedArrears[term] =
          (updatedArrears[term]! - amountPaid).clamp(0.0, double.infinity);
    }

    final School school = await _getSchoolInfo();
    final String schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(_paymentDate);
    final studentName = _selectedStudent?.name.toUpperCase() ?? '';
    final studentSurname = _selectedStudent?.surname.toUpperCase() ?? '';
    final parentName = _selectedStudent?.paymentStatus.toUpperCase() ?? '';
    final parentName11 =
        _selectedStudent?.emergencyContactName?.toUpperCase() ?? '';
    final parentName1 =
        _selectedStudent!.emergencyContactName?.toUpperCase() ?? 'Guardian';

    final String entry =
        '${_paymentPurposes.isEmpty ? '$schoolName\nDear $parentName: \n$studentName $studentSurname has paid:\n' : 'And'} '
        ' \$${amountPaid.toStringAsFixed(2)} for  $paymentPurpose of  $term.\n\n';
    final String entry11 =
        '${_paymentPurposes.isEmpty ? '$schoolName\nDear $parentName11: \n$studentName $studentSurname has paid:\n' : 'And'} '
        ' \$${amountPaid.toStringAsFixed(2)} for  $paymentPurpose of  $term.\n\n';

    final String entry1 =
        '${_paymentPurposes.isEmpty ? '$schoolName\nDear $parentName1: \n$studentName $studentSurname has paid:\n' : 'And'} '
        ' \$${amountPaid.toStringAsFixed(2)} for  $paymentPurpose of  $term.\n\n';

    _paymentInfo = (_paymentInfo ?? '') + entry;
    _paymentInfo11 = (_paymentInfo11 ?? '') + entry11;
    _paymentInfo2 = (_paymentInfo2 ?? '') + entry1;

    final String adminEntry =
        '${_paymentPurposes.isEmpty ? '$studentName $studentSurname paid:' : 'And'} '
        '\n \$${amountPaid.toStringAsFixed(2)} for $paymentPurpose of  $term .\n';

    _paymentInfo1 = (_paymentInfo1 ?? '') + adminEntry;

    _arrearsDetails = updatedArrears;

    setState(() {
      _paymentPurposes.add({
        'purpose': _selectedPaymentPurpose!,
        'amount': _paymentAmount!,
        'termId': term,
      });

      _paymentAmountController.clear();
      _paymentAmount = null;
      _selectedPaymentPurpose = null;
    });
  }

  void _confirmPayment() {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;

    if (_selectedStudent == null) {
      _showDialog('Please select a student first');
      return;
    }

    if (_paymentPurposes.isEmpty) {
      _showDialog('Please add at least one payment purpose');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Stack(
          children: [
            AlertDialog(
              title: const Center(child: Text('Confirm Payment')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(capitalize(
                      'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}')),
                  Text(capitalize('Class: ${_selectedStudent!.class_} ')),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Purpose')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Term')),
                        DataColumn(
                            label: Text('Action')), // Empty header for X button
                      ],
                      rows: _paymentPurposes.map((payment) {
                        final PaymentPurpose purpose = payment['purpose'];

                        final String termId =
                            payment['termId'] ?? purpose.termId ?? '';
                        final term = _termsMap[termId];
                        final termDisplay =
                            term != null ? '(${term.termName})' : '(Unknown)';

                        return DataRow(
                          cells: [
                            DataCell(Text(payment['purpose'].paymentPurpose)),
                            DataCell(Text(payment['amount'].toString())),
                            DataCell(Text(termDisplay)),
                            DataCell(
                              IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                tooltip: 'Remove this purpose',
                                onPressed: () {
                                  setState(() {
                                    _paymentPurposes.remove(payment);
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Total Amount Entered: \$${totalEntered.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    _makePayment();
                  },
                  child: const Text('Confirm And Do Not Print Receipt?'),
                ),
                TextButton(
                  onPressed: _connected
                      ? () async {
                          Map<String, dynamic> config = {};
                          try {
                            final School schoolInfo = await _fetchSchoolInfo();
                            List<LineText> list = [];

                            // Add school logo (if available)
                            // Add school logo (if available)
                            /*if (schoolInfo.schoolLogoPath != null &&
                                schoolInfo.schoolLogoPath!.isNotEmpty) {
                              final String logoPath =
                                  schoolInfo.schoolLogoPath!;
                              final file = File(logoPath);

                              if (file.existsSync()) {
                                try {
                                  final List<int> bytes =
                                      file.readAsBytesSync();
                                  final String base64Image =
                                      base64Encode(bytes);

                                  print(
                                      "LOGO FOUND → Base64 size: ${base64Image.length}");

                                  list.add(
                                    LineText(
                                      type: LineText.TYPE_IMAGE,
                                      content: base64Image,
                                      align: LineText.ALIGN_CENTER,
                                      linefeed: 1,
                                    ),
                                  );
                                } catch (e) {
                                  print("Error converting logo: $e");
                                }
                              } else {
                                print("Logo file exists? FALSE");
                              }
                            }
*/
                            int newId = await getNextId();

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'RECEIPT',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                              weight: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '${schoolInfo.schoolName?.toUpperCase()}',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 2,
                              weight: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '${schoolInfo.schoolAddress?.toUpperCase()}',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: '${schoolInfo.schoolPhoneNumber}',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: '${schoolInfo.schoolEmail}',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '----------------------------------------------',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'RECEIVED FROM',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  'Name: ${_selectedStudent!.name.toUpperCase()}   ${_selectedStudent!.surname.toUpperCase()} ',
                              align: LineText.ALIGN_LEFT,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  'Class: ${_selectedStudent!.class_.toUpperCase()}',
                              align: LineText.ALIGN_LEFT,
                              linefeed: 1,
                              fontZoom: 1,
                            ));

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '----------------------------------------------',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'PAYMENTS FOR',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                              fontZoom: 1,
                            ));
                            double totalPaid = 0.0;
                            final prefs = await SharedPreferences.getInstance();
                            final termAggregation =
                                prefs.getBool('termAggregation') ?? false;

                            for (var payment in _paymentPurposes) {
                              double amountPaid = payment['amount'];
                              totalPaid += amountPaid;

                              // ✅ Payment Purpose Line
                              list.add(LineText(
                                type: LineText.TYPE_TEXT,
                                content:
                                    '${payment['purpose'].paymentPurpose.toString().toUpperCase().replaceAll(RegExp(r'\s*\\(.*?\\)'), '').trim()} :    \$ ${payment['amount']} ',
                                align: LineText.ALIGN_LEFT,
                                linefeed: 1,
                                fontZoom: 1,
                              ));

                              // ✅ Conditional TERM OF line
                              if (termAggregation) {
                                // Term aggregation enabled → strip extra info (clean term label)
                                list.add(LineText(
                                  type: LineText.TYPE_TEXT,
                                  content:
                                      'TERM OF :  ${payment['termId'].replaceAll(RegExp(r'\\s*\\(.*?\\)'), '').trim()} ',
                                  align: LineText.ALIGN_LEFT,
                                  linefeed: 1,
                                  fontZoom: 1,
                                ));
                              } else {
                                // Normal mode → show full term ID as-is
                                list.add(LineText(
                                  type: LineText.TYPE_TEXT,
                                  content: 'TERM OF :  ${payment['termId']} ',
                                  align: LineText.ALIGN_LEFT,
                                  linefeed: 1,
                                  fontZoom: 1,
                                ));
                              }
                            }

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '----------------------------------------------',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'TOTALS',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                              fontZoom: 1,
                            ));

                            double totalAmount = _paymentPurposes.fold(
                                0, (sum, payment) => sum + payment['amount']);
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'TOTAL PAID: \$ $totalAmount',
                              align: LineText.ALIGN_RIGHT,
                              linefeed: 1,
                              fontZoom: 1,
                              weight: 1,
                            ));

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '----------------------------------------------',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'TERM ARREARS SECTION ',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                              fontZoom: 1,
                            ));
                            final arrearsData =
                                await _buildOtherArrearsSummaryWithTotal();
                            final otherArrearsSummary =
                                arrearsData['summary'] ?? '';
                            final smsLikeReceipt = '\n' +
                                (otherArrearsSummary.isNotEmpty
                                    ? otherArrearsSummary + '\n'
                                    : '');

                            // Break the content into lines and add to receipt
                            for (String line
                                in smsLikeReceipt.trim().split('\n')) {
                              final trimmedLine = line.trim();
                              final isTermHeader = trimmedLine
                                  .toUpperCase()
                                  .startsWith('-TERM:');
                              final isTotalHeader = trimmedLine
                                  .toUpperCase()
                                  .startsWith('TOTAL ARREARS');

                              list.add(LineText(
                                type: LineText.TYPE_TEXT,
                                content: trimmedLine,
                                align: LineText.ALIGN_CENTER,
                                linefeed: 1,
                                fontZoom: 1,
                                weight: isTermHeader || isTotalHeader ? 1 : 0,
                              ));
                            }

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '----------------------------------------------',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'RECEIVED ON',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_paymentDate)}',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                              weight: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '----------------------------------------------',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'PAYMENT CAPTURED BY',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                            ));

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'User: ${user.toUpperCase()}',
                              align: LineText.ALIGN_RIGHT,
                              linefeed: 1,
                              fontZoom: 1,
                            ));

                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '**********************************************',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: 'RECEIPT NO. ',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              weight: 1,
                              fontZoom: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content: '#: $newId',
                              align: LineText.ALIGN_RIGHT,
                              linefeed: 1,
                              fontZoom: 1,
                              weight: 1,
                            ));
                            list.add(LineText(
                              type: LineText.TYPE_TEXT,
                              content:
                                  '**********************************************',
                              align: LineText.ALIGN_CENTER,
                              linefeed: 1,
                              fontZoom: 1,
                            ));
                            if (schoolInfo.schoolName!
                                .trim()
                                .toLowerCase()
                                .contains('_')) {
                              list.add(LineText(
                                type: LineText.TYPE_TEXT,
                                content: 'NO REFUND! ',
                                align: LineText.ALIGN_CENTER,
                                linefeed: 1,
                                weight: 1,
                                fontZoom: 1,
                              ));
                            }

                            // Send the data to the printer
                            await bluetoothHelper.bluetoothPrint
                                .printReceipt(config, list);

                            _makePayment();
                          } catch (e) {
                            debugPrint('Printing failed: $e');
                          }
                        }
                      : null,
                  child: const Text('Confirm And Print Receipt?'),
                ),
              ],
            ),
            if (_isProcessingPayment)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true, // Prevent all taps
                  child: Container(
                    color: Colors.black.withOpacity(0.4), // Greyout overlay
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "Processing payment, please wait...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
      },
    );
  }

  Future<double> _calculateRemainingCurrentPurposeBalances() async {
    await fetchStudentPayments(); // Ensures _cachedServerStudentPayments is populated if needed
    await fetchPaymentPurposes(); // Ensures _cachedServerStudentPaymentPurposes is populated if needed

    final studentName = _selectedStudent!.name.toLowerCase();
    final studentSurname = _selectedStudent!.surname.toLowerCase();
    final studentclass = _selectedStudent!.class_.toLowerCase();

    final List<StudentPayment> allPayments = _role == DeviceRole.host
        ? Hive.box<StudentPayment>('student_payments').values.toList()
        : _cachedServerStudentPayments ?? [];

    final Map<String, Map<String, double>> remainingMap =
        {}; // purpose -> term -> remaining

    for (var sessionPayment in _paymentPurposes) {
      final String purposeName =
          sessionPayment['purpose'].paymentPurpose.toLowerCase();

      final String termId = sessionPayment['termId'];
      final double fullAmount = sessionPayment['purpose'].purposeAmount;

      // Get previous payments from Hive
      final double hivePaid = allPayments
          .where((p) =>
              p.studentName.toLowerCase() == studentName &&
              p.studentSurname.toLowerCase() == studentSurname &&
              p.termId == termId &&
              p.paymentPurpose.toLowerCase() == purposeName)
          .fold(0.0, (sum, p) => sum + (p.amountToPay ?? 0.0));

      // Get session payments
      final double sessionPaid = _paymentPurposes
          .where((p) =>
              p['termId'] == termId &&
              p['purpose'].paymentPurpose.toLowerCase() == purposeName)
          .fold(0.0, (sum, p) => sum + (p['amount'] as double));

      final double totalPaid = hivePaid + sessionPaid;
      final double remaining =
          (fullAmount - totalPaid).clamp(0.0, double.infinity);

      // Avoid double-counting across multiple entries
      remainingMap.putIfAbsent(purposeName, () => {});
      remainingMap[purposeName]![termId] = remaining;
    }

    // Sum all remaining amounts
    double totalRemaining = remainingMap.values
        .expand((termMap) => termMap.values)
        .fold(0.0, (sum, r) => sum + r);

    return totalRemaining;
  }

  Future<double> _calculateAllSchoolFeesBalances() async {
    await fetchStudentPayments();
    await fetchPaymentPurposes();

    final studentName = _selectedStudent!.name.toLowerCase();
    final studentSurname = _selectedStudent!.surname.toLowerCase();
    final studentClass = _selectedStudent!.class_;

    final List<StudentPayment> allPayments = _role == DeviceRole.host
        ? Hive.box<StudentPayment>('student_payments').values.toList()
        : _cachedServerStudentPayments ?? [];

    final List<PaymentPurpose> allPurposes = _role == DeviceRole.host
        ? await Hive.openBox<PaymentPurpose>('payment_purposes')
            .then((box) => box.values.toList())
        : _cachedServerStudentPaymentPurposes ?? [];

    final schoolFeePurposes = allPurposes.where((p) =>
        p.paymentPurpose.toLowerCase() == 'school fees' &&
        p.associatedClasses?.contains(studentClass) == true);
    double totalBalance = 0.0;

    for (var purpose in schoolFeePurposes) {
      final double paid = allPayments
          .where((payment) =>
              payment.studentName.toLowerCase() == studentName &&
              payment.studentSurname.toLowerCase() == studentSurname &&
              payment.termId == purpose.termId &&
              payment.paymentPurpose.toLowerCase() == 'school fees')
          .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));

      final sessionPaid = _paymentPurposes
          .where((p) =>
              p['termId'] == purpose.termId &&
              p['purpose'].paymentPurpose.toLowerCase() == 'school fees')
          .fold(0.0, (sum, p) => sum + (p['amount'] as double));

      double totalPaid = paid + sessionPaid;
      double arrears =
          (purpose.purposeAmount - totalPaid).clamp(0.0, double.infinity);
      totalBalance += arrears;
    }

    return totalBalance;
  }

  Future<void> _makePayment() async {
    final _prefs = await SharedPreferences.getInstance();
    final prefs = await SharedPreferences.getInstance();
    final termAggregation = prefs.getBool('termAggregation') ?? false;
    final studentName = _selectedStudent!.name.toUpperCase();
    final studentSurname = _selectedStudent!.surname.toUpperCase();
    final phone = _selectedStudent!.phoneNumber;
    final phone1 = _selectedStudent!.emergencyContactNumber;

    final parentName = _selectedStudent!.paymentStatus.toUpperCase();
    final parentName1 = _selectedStudent!.emergencyContactName?.toUpperCase();

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(_paymentDate);

    final adminBox = Hive.box<User>('users');
    // ✅ Collect both "admin" and "administration"
    final adminUsers = adminBox.values
        .where((term) =>
            term.role.toLowerCase() == "admin" ||
            term.role.toLowerCase() == "administration")
        .toList();

    final arrearsData = await _buildOtherArrearsSummaryWithTotal();
    final otherArrearsSummary = arrearsData['summary'];
    final otherArrearsSummaryadmin = arrearsData['summaryadmin'];

    final grandTotalArrears = arrearsData['grandTotalArrears'] as double;

    final double remainingSchoolFees = await _calculateAllSchoolFeesBalances();

    final grandGrandTotal = remainingSchoolFees + grandTotalArrears;

    final termsNameMap = _termsMap.map((k, v) => MapEntry(k, v.termName ?? k));

    final arrearsLine =
        otherArrearsSummary.trim().isNotEmpty ? otherArrearsSummary + '\n' : '';
    final arrearsLineadmin = otherArrearsSummaryadmin.trim().isNotEmpty
        ? otherArrearsSummaryadmin + '\n'
        : '';
    final DateFormat formatters = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDates = formatters.format(_paymentDate);

    final allPaymentsInfo = (_paymentInfo ?? '') +
        '\n' +
        arrearsLine +
        'Payment Date:' +
        formattedDates;

    final allPaymentsInfo2 = (_paymentInfo2 ?? '') +
        '\n' +
        arrearsLine +
        '\n' +
        'Payment Date:' +
        formattedDates;

    final allAdminPaymentsInfo = (_paymentInfo1 ?? '') +
        '\n' +
        arrearsLineadmin +
        '\n' +
        'Payment Date:' +
        formattedDates;

    final allPaymentsInfonewag = buildAggregatedPaymentSummary(
      (await _getSchoolInfo()).schoolName?.toUpperCase() ?? 'SCHOOL',
      parentName,
      '$studentName $studentSurname',
      _paymentPurposes,
      termsNameMap,
    );
    final allPaymentsInfonewag1 = buildAggregatedPaymentSummary1(
      (await _getSchoolInfo()).schoolName?.toUpperCase() ?? 'SCHOOL',
      parentName1.toString(),
      '$studentName $studentSurname',
      _paymentPurposes,
      termsNameMap,
    );
    final allPaymentsInfonew = allPaymentsInfonewag +
        '\n' +
        arrearsLine +
        'Payment Date: ' +
        formattedDates;

    final allPaymentsInfonew1 = allPaymentsInfonewag1 +
        '\n' +
        arrearsLine +
        'Payment Date: ' +
        formattedDates;

    final allPaymentsInfoadminnewg = buildAggregatedPaymentSummaryadmin(
      (await _getSchoolInfo()).schoolName?.toUpperCase() ?? 'SCHOOL',
      '$studentName $studentSurname',
      _paymentPurposes,
      termsNameMap,
    );
    final allPaymentsInfoadminnew = allPaymentsInfoadminnewg +
        '\n' +
        arrearsLineadmin +
        'Payment Date: ' +
        formattedDates;

    final uuid = const Uuid();
    int newId = await getNextId();

    final loggedInUser = getLoggedInUser(); // your function
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    if (_role == DeviceRole.client) {
      setState(() => _isProcessingPayment = true);

      final paymentsToSend = <Map<String, dynamic>>[];

      for (var payment in _paymentPurposes) {
        int newId = await getNextId();

        paymentsToSend.add({
          "id": newId,
          "receiptNumber": uuid.v4(),
          "studentName": studentName,
          "studentSurname": studentSurname,
          "studentClass": _selectedStudent!.class_,
          "phoneNumber": phone,
          "paymentPurpose": payment['purpose'].paymentPurpose.toUpperCase(),
          "amountToPay": payment['amount'],
          "paymentDate": _paymentDate.toIso8601String(),
          "termId": payment['termId'],
          "syncStatus": false,
          "lastModified": DateTime.now().toIso8601String(),
          "operationType": "create",
          "modifiedFields": [
            "id",
            "receiptNumber",
            "studentName",
            "studentSurname",
            "studentClass",
            "phoneNumber",
            "paymentPurpose",
            "amountToPay",
            "paymentDate",
            "termId",
            "username",
            "role"
          ],
          "username": user,
          "role": role,
        });
      }

      final hostIp = _prefs.getString('host_ip') ?? '192.168.8.2';
      final uri = Uri.parse('http://$hostIp:8080/api/studentPayments/bulk');

      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body:
              jsonEncode({"payments": paymentsToSend}), // ✅ Aligns with server
        );
        final school = await _getSchoolInfo(); // fetch the actual school data
        final schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

        if (response.statusCode == 200) {
          //  _showDialog("✅ Payment sent to host successfully.");
          await Future.wait(
            adminUsers.map((admin) async {
              try {
                if (termAggregation) {
                  await Future.wait(
                    adminUsers.map((admin) =>
                        sendSms(allPaymentsInfoadminnew, admin.phone)),
                  );

                  // handle aggregated term logic
                } else {
                  await sendSms(allAdminPaymentsInfo, admin.phone);
                }
              } catch (e) {
                print(
                    "⚠️ Failed to send SMS to ${admin.username} (${admin.phone}): $e");
              }
            }),
          );
          if (termAggregation) {
            // Always send to first parent
            if (phone.isNotEmpty) {
              _sendSmsNotification(allPaymentsInfonew, phone);
            }

// Send to second parent if available
            if (phone1 != null && phone1.isNotEmpty) {
              _sendSmsNotification(allPaymentsInfonew1, phone1);
            }
          } else {
            if (phone.isNotEmpty) {
              _sendSmsNotification(allPaymentsInfo, phone);
            }

// Send to second parent if available
            if (phone1 != null && phone1.isNotEmpty) {
              _sendSmsNotification(allPaymentsInfo2, phone1);
            }
          }
          _resetForm();
          _clearAllServerCaches();
          Navigator.pop(context);
          Navigator.pop(context);
        } else {
          _showDialog("❌ Host rejected payment: ${response.body}");
          _clearAllServerCaches();
        }
      } catch (e) {
        _showDialog("❌ Failed to send payment to host.");
        print("Payment send error: $e");
        _clearAllServerCaches();
      } finally {
        if (mounted) setState(() => _isProcessingPayment = false);
      }
    } else {
      final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

      for (var payment in _paymentPurposes) {
        final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
        final paymentAmount = payment['amount'];
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
        modifiedFields.add('username');
        modifiedFields.add('role');

        final newPayment = StudentPayment(
          id: newId,
          receiptNumber: receiptNumber,
          studentName: studentName,
          studentSurname: studentSurname,
          studentClass: _selectedStudent!.class_,
          phoneNumber: phone,
          paymentPurpose: paymentPurpose,
          amountToPay: paymentAmount,
          paymentDate: _paymentDate,
          termId: payment['termId'], // Consider selected arrears term
          syncStatus: false, // Set syncStatus to false
          lastModified: DateTime.now(), // Set lastModified to current datetime
          operationType: 'create', // Set operationType to 'create'
          modifiedFields: modifiedFields,
          username: user, // ✅ added
          role: role, // ✅ added
        );

        paymentBox.add(newPayment);
      }
      await Future.wait(
        adminUsers.map((admin) async {
          final school = await _getSchoolInfo(); // fetch the actual school data
          final schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

          try {
            if (termAggregation) {
              await Future.wait(
                adminUsers.map(
                    (admin) => sendSms(allPaymentsInfoadminnew, admin.phone)),
              );

              // handle aggregated term logic
            } else {
              await sendSms(allAdminPaymentsInfo, admin.phone);
            }
          } catch (e) {
            print(
                "⚠️ Failed to send SMS to ${admin.username} (${admin.phone}): $e");
          }
        }),
      );
      final school = await _getSchoolInfo(); // fetch the actual school data
      final schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

      if (termAggregation) {
        // Always send to first parent
        if (phone.isNotEmpty) {
          _sendSmsNotification(allPaymentsInfonew, phone);
        }

// Send to second parent if available
        if (phone1 != null && phone1.isNotEmpty) {
          _sendSmsNotification(allPaymentsInfonew1, phone1);
        }
      } else {
        if (phone.isNotEmpty) {
          _sendSmsNotification(allPaymentsInfo, phone);
        }

// Send to second parent if available
        if (phone1 != null && phone1.isNotEmpty) {
          _sendSmsNotification(allPaymentsInfo2, phone1);
        }
      }
      _showDialog('Student Payment Made SUCCESSFULLY.');

      _resetForm();
      // ✅ Reset SMS buffers so they don't append old messages

      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  String buildAggregatedPaymentSummary(
    String schoolName,
    String parentName,
    String studentName,
    List<Map<String, dynamic>>
        payments, // {'purpose': PaymentPurpose, 'amount': double, 'termId': String}
    Map<String, String> termsMap, // termId -> termName
  ) {
    // Map of paymentPurpose → Map<cleanTermName, totalAmount>
    final Map<String, Map<String, double>> summary = {};

    for (var payment in payments) {
      final purposeName = payment['purpose'].paymentPurpose ?? 'UNKNOWN';
      final termId = payment['termId'] ?? '';
      final amount = payment['amount'] as double? ?? 0.0;

      // Clean the term name by removing brackets
      final termName = termsMap[termId] ?? termId;
      final cleanTermName =
          termName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      summary.putIfAbsent(purposeName, () => {});
      summary[purposeName]
          ?.update(cleanTermName, (v) => v + amount, ifAbsent: () => amount);
    }

    final buffer = StringBuffer();
    buffer.write('$schoolName\n Dear $parentName,\n $studentName has paid ');

    final parts = <String>[];
    summary.forEach((purpose, termMap) {
      termMap.forEach((cleanTermName, totalAmount) {
        parts.add(
            '\$${totalAmount.toStringAsFixed(2)} for ${purpose.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim()} of $cleanTermName');
      });
    });

    buffer.write(parts.join(' and '));
    buffer.write('.');

    return buffer.toString();
  }

  String buildAggregatedPaymentSummary1(
    String schoolName,
    String parentName1,
    String studentName,
    List<Map<String, dynamic>>
        payments, // {'purpose': PaymentPurpose, 'amount': double, 'termId': String}
    Map<String, String> termsMap, // termId -> termName
  ) {
    // Map of paymentPurpose → Map<cleanTermName, totalAmount>
    final Map<String, Map<String, double>> summary = {};

    for (var payment in payments) {
      final purposeName = payment['purpose'].paymentPurpose ?? 'UNKNOWN';
      final termId = payment['termId'] ?? '';
      final amount = payment['amount'] as double? ?? 0.0;

      // Clean the term name by removing brackets
      final termName = termsMap[termId] ?? termId;
      final cleanTermName =
          termName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      summary.putIfAbsent(purposeName, () => {});
      summary[purposeName]
          ?.update(cleanTermName, (v) => v + amount, ifAbsent: () => amount);
    }

    final buffer = StringBuffer();
    buffer.write('$schoolName\n Dear $parentName1,\n $studentName has paid ');

    final parts = <String>[];
    summary.forEach((purpose, termMap) {
      termMap.forEach((cleanTermName, totalAmount) {
        parts.add(
            '\$${totalAmount.toStringAsFixed(2)} for ${purpose.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim()} of $cleanTermName');
      });
    });

    buffer.write(parts.join(' and '));
    buffer.write('.');

    return buffer.toString();
  }

  String buildAggregatedPaymentSummaryadmin(
    String schoolName,
    String studentName,
    List<Map<String, dynamic>>
        payments, // {'purpose': PaymentPurpose, 'amount': double, 'termId': String}
    Map<String, String> termsMap, // termId -> termName
  ) {
    // Map of paymentPurpose → Map<cleanTermName, totalAmount>
    final Map<String, Map<String, double>> summary = {};

    for (var payment in payments) {
      final purposeName = payment['purpose'].paymentPurpose ?? 'UNKNOWN';
      final termId = payment['termId'] ?? '';
      final amount = payment['amount'] as double? ?? 0.0;

      // Clean the term name by removing brackets
      final termName = termsMap[termId] ?? termId;
      final cleanTermName =
          termName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      summary.putIfAbsent(purposeName, () => {});
      summary[purposeName]
          ?.update(cleanTermName, (v) => v + amount, ifAbsent: () => amount);
    }

    final buffer = StringBuffer();
    buffer.write('$schoolName\n $studentName  paid ');

    final parts = <String>[];
    summary.forEach((purpose, termMap) {
      termMap.forEach((cleanTermName, totalAmount) {
        parts.add(
            '\$${totalAmount.toStringAsFixed(2)} for $purpose of $cleanTermName');
      });
    });

    buffer.write(parts.join(' and '));
    buffer.write('.');

    return buffer.toString();
  }

  Future<int> getNextId() async {
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (role == DeviceRole.host) {
      final box = await Hive.openBox<StudentPayment>('student_payments');
      if (box.isEmpty) return 1;

      int currentMaxId = box.values
          .map((e) => e.id ?? 0)
          .reduce((curr, next) => curr > next ? curr : next);
      return currentMaxId + 1;
    } else {
      try {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/studentPayments'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final responseString = await response.transform(utf8.decoder).join();
          final List<dynamic> jsonList = jsonDecode(responseString);

          if (jsonList.isEmpty) return 1;

          final List<StudentPayment> payments = jsonList
              .map((e) => studentPaymentsFromJson(Map<String, dynamic>.from(e)))
              .toList();

          int currentMaxId = payments
              .map((e) => e.id ?? 0)
              .reduce((curr, next) => curr > next ? curr : next);
          return currentMaxId + 1;
        } else {
          throw Exception("Failed to load studentPayments for ID generation.");
        }
      } catch (e) {
        debugPrint("❌ Error fetching max ID from server: $e");
        return 1; // Fallback to 1 if error
      }
    }
  }

  void _sendSmsNotification(String allPaymentsInfo, String? phone) {
    if (Platform.isAndroid == true) {
      if (allPaymentsInfo.isEmpty) {
        _showDialog('No payment made yet');
        return;
      }
      launcher.launchUrl(Uri.parse(
          'sms:$phone${Platform.isAndroid ? '?' : '&'}body=$allPaymentsInfo'));
    } else {
      return;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetForm() {
    _studentSearchController.clear();
    setState(() {
      _selectedStudent = null;
      _paymentPurposes.clear();
      _paymentDate = DateTime.now();
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.isEmpty) return;

    _searchStudent(query, showDialog: true);
  }

  double get totalEntered =>
      _paymentPurposes.fold(0.0, (sum, p) => sum + (p['amount'] ?? 0.0));

  @override
  Widget build(BuildContext context) {
    if (globalTermId != null) {
      return Stack(
        children: [
          Scaffold(
            floatingActionButton: StreamBuilder<bool>(
              stream: bluetoothPrint.isScanning,
              initialData: false,
              builder: (c, snapshot) {
                if (snapshot.data == true) {
                  return FloatingActionButton(
                    child: const Icon(Icons.stop),
                    onPressed: () => bluetoothPrint.stopScan(),
                    backgroundColor: Colors.red,
                  );
                } else {
                  return FloatingActionButton(
                    child: const Icon(Icons.search),
                    onPressed: () => bluetoothPrint.startScan(
                        timeout: const Duration(seconds: 5)),
                  );
                }
              },
            ),
            appBar: AppBar(
              title: const Center(
                child: Text(
                  'Make Payment',
                  style: TextStyle(
                    fontSize: 14.0, // Adjust font size
                    fontWeight: FontWeight.normal, // Bold font
                    color: Colors.white, // Title color
                    letterSpacing: 1.2, // Slight letter spacing for elegance
                  ),
                ),
              ),
              backgroundColor: const Color.fromARGB(255, 38, 140, 191),
            ),
            body: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromRGBO(255, 255, 255, 1),
                        Color.fromRGBO(255, 255, 255, 1)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      RefreshIndicator(
                        onRefresh: () =>
                            bluetoothHelper.bluetoothPrint.startScan(
                          timeout: const Duration(seconds: 5),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                    child: Text(
                                        tips), // Keep "tips" for dynamic updates
                                  ),
                                ],
                              ),
                              const Divider(),
                              StreamBuilder<List<BluetoothDevice>>(
                                stream:
                                    bluetoothHelper.bluetoothPrint.scanResults,
                                initialData: const [],
                                builder: (c, snapshot) => Column(
                                  children: snapshot.data!
                                      .map((d) => ListTile(
                                            title: Text(d.name ?? ''),
                                            subtitle: Text(d.address ?? ''),
                                            onTap: () async {
                                              setState(() {
                                                _device = d;
                                              });
                                            },
                                            trailing: _device != null &&
                                                    _device!.address ==
                                                        d.address
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.green,
                                                  )
                                                : null,
                                          ))
                                      .toList(),
                                ),
                              ),
                              const Divider(),
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 5, 20, 10),
                                child: Column(
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        OutlinedButton(
                                          onPressed: _connected
                                              ? null
                                              : () async {
                                                  if (_device != null &&
                                                      _device!.address !=
                                                          null) {
                                                    setState(() {
                                                      tips = 'Connecting...';
                                                    });
                                                    try {
                                                      await bluetoothHelper
                                                          .bluetoothPrint
                                                          .connect(_device!);
                                                      setState(() {
                                                        tips =
                                                            'Connected to ${_device!.name}';
                                                        _connected = true;
                                                      });
                                                    } catch (e) {
                                                      setState(() {
                                                        tips =
                                                            'Failed to connect: $e';
                                                      });
                                                    }
                                                  } else {
                                                    setState(() {
                                                      tips =
                                                          'Please select a device';
                                                    });
                                                  }
                                                },
                                          child: const Text('Connect'),
                                        ),
                                        const SizedBox(width: 10.0),
                                        OutlinedButton(
                                          onPressed: _connected
                                              ? () async {
                                                  setState(() {
                                                    tips = 'Disconnecting...';
                                                  });
                                                  try {
                                                    await bluetoothHelper
                                                        .bluetoothPrint
                                                        .disconnect();
                                                    setState(() {
                                                      tips = 'Disconnected';
                                                      _connected = false;
                                                    });
                                                  } catch (e) {
                                                    setState(() {
                                                      tips =
                                                          'Failed to disconnect: $e';
                                                    });
                                                  }
                                                }
                                              : null,
                                          child: const Text('Disconnect'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode
                            .onUserInteraction, // Automatically triggers validation

                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              color: const Color.fromARGB(255, 229, 230, 230),
                              child: TextFormField(
                                controller: _studentSearchController,
                                decoration: InputDecoration(
                                  labelText: 'Search Student by Surname',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () => _onSearchSubmitted(
                                        _studentSearchController.text.trim()),
                                  ),
                                ),
                                onChanged: (value) {
                                  // Debounce to avoid too many network calls
                                  _searchDebounce?.cancel();
                                  _searchDebounce =
                                      Timer(_searchDebounceDuration, () {
                                    _searchStudent(value.trim(),
                                        showDialog: false);
                                  });
                                },
                              ),
                            ),
                            if (_selectedStudent != null)
                              Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}'),
                                      const SizedBox(height: 10),
                                      Text(
                                          'Class: ${_selectedStudent!.class_}'),
                                      const SizedBox(height: 10),
                                      Text(
                                          'Phone1: ${_selectedStudent!.phoneNumber}'),
                                      if (_selectedStudent!
                                                  .emergencyContactNumber !=
                                              null &&
                                          _selectedStudent!
                                              .emergencyContactNumber!
                                              .isNotEmpty)
                                        Text(
                                            'Phone2: ${_selectedStudent!.emergencyContactNumber}'),
                                      const SizedBox(height: 10),
                                      FutureBuilder<double>(
                                        future: _totalArrearsFuture,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Text(
                                              'Calculating total arrears...',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic),
                                            );
                                          } else if (snapshot.hasError) {
                                            return Text(
                                              'Error fetching arrears: ${snapshot.error}',
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            );
                                          } else {
                                            final total = snapshot.data ?? 0.0;
                                            return Text(
                                              'Total Arrears: \$${total.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: total > 0
                                                    ? Colors.redAccent
                                                    : Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            if (_selectedStudent !=
                                null) // Fetch payment purposes only if a student is selected

                              FutureBuilder<List<Map<String, dynamic>>>(
                                future:
                                    _fetchUniquePaymentPurposesByStudentWithArrears(
                                        _selectedStudent!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Text(
                                        'No Arrears found for this student.');
                                  }

                                  final purposeList = snapshot.data!;

                                  return DropdownButtonFormField<
                                      PaymentPurpose>(
                                    value: _selectedPaymentPurpose,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      labelText: 'Select Payment Purpose',
                                    ),
                                    items: purposeList.map((entry) {
                                      final PaymentPurpose purpose =
                                          entry['purpose'];
                                      final String preview =
                                          entry['arrearsPreview'];

                                      return DropdownMenuItem<PaymentPurpose>(
                                        value: purpose,
                                        child: SizedBox(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.3, // 30% of screen width

                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Text(
                                              '${purpose.paymentPurpose ?? ''} $preview',
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPaymentPurpose = value;
                                        _selectedArrearsTerm = null;
                                        _arrearsFuture = _checkArrears(value!);
                                      });
                                    },
                                  );
                                },
                              ),
                            if (_selectedPaymentPurpose != null &&
                                _selectedStudent != null) ...[
                              Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Purpose: ${_selectedPaymentPurpose?.paymentPurpose ?? ''}'),
                                      const SizedBox(height: 10),
                                      FutureBuilder(
                                        future: _arrearsFuture,
                                        builder: (context, snapshot) {
                                          if (_arrearsTerms.isNotEmpty) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Arrears Were Found. Select a term to pay:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                const SizedBox(height: 8),
                                                // Display arrears details (term and amount)
                                                ..._arrearsDetails.entries
                                                    .where((entry) {
                                                  final hasArrears =
                                                      entry.value > 0.0;
                                                  return hasArrears;
                                                }).map((entry) {
                                                  return Text(
                                                    '• Term: ${entry.key} - Arrears: \$${entry.value.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black),
                                                  );
                                                }).toList(),
                                                const SizedBox(height: 8),
                                                DropdownButton<String>(
                                                  value: _arrearsTerms.contains(
                                                          _selectedArrearsTerm)
                                                      ? _selectedArrearsTerm
                                                      : null,
                                                  hint:
                                                      const Text('Select Term'),
                                                  isExpanded: true,
                                                  items: _arrearsTerms
                                                      .map((termId) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: termId,
                                                      child: Text(
                                                          'Term: $termId - Arrears: \$${_arrearsDetails[termId]?.toStringAsFixed(2) ?? '0.00'}'),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedArrearsTerm =
                                                          value!;

                                                      // Auto-fill payment amount based on arrears
                                                      final amount =
                                                          _arrearsDetails[
                                                                  _selectedArrearsTerm] ??
                                                              0.0;

                                                      _paymentAmountController
                                                              .text =
                                                          amount
                                                              .toStringAsFixed(
                                                                  2);
                                                      _paymentAmount = amount;
                                                    });
                                                  },
                                                ),
                                                // Add the message right below the dropdown
                                                if (_selectedArrearsTerm !=
                                                    null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8.0),
                                                    child: Text(
                                                      _selectedArrearsTerm ==
                                                              globalTermId
                                                          ? 'You can make prepayments for this term.'
                                                          : 'Payment for previous term arrears cannot exceed the due amount.',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color:
                                                            _selectedArrearsTerm ==
                                                                    globalTermId
                                                                ? Colors.green
                                                                : Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                // "Cancel" button to reset term selection
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .end, // Push to far right

                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          _selectedArrearsTerm =
                                                              null; // Clear selected term
                                                          _selectedPaymentPurpose =
                                                              null; // Reset purpose selection
                                                          _paymentAmountController
                                                              .clear(); // Clear payment field
                                                        });
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: Colors
                                                            .red, // Button color
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 24,
                                                                vertical: 12),
                                                      ),
                                                      child: const SizedBox(
                                                        // Wraps only the text
                                                        width: null,
                                                        child: Text(
                                                          'Cancel Selection',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: Colors.white,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          } else {
                                            return Column(
                                              children: [
                                                const Text(
                                                  'No arrears found for this payment purpose.',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedPaymentPurpose =
                                                          null; // Reset payment purpose selection
                                                    });
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors
                                                        .blue, // Button color
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24,
                                                        vertical: 12),
                                                  ),
                                                  child: const Text(
                                                    'OK',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _paymentAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Payment Amount',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _paymentAmountController.clear();
                                  },
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _paymentAmount =
                                      double.tryParse(value) ?? 0.0;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an amount';
                                }

                                final enteredAmount =
                                    double.tryParse(value) ?? 0.0;

                                if (_selectedArrearsTerm.toString() != null) {
                                  // Check against arrears amount if selected term is not the current term
                                  final maxArrearsAmount =
                                      _arrearsDetails[_selectedArrearsTerm] ??
                                          0.0;

                                  if (enteredAmount > maxArrearsAmount) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      _paymentAmountController.clear();
                                    });
                                    return 'Amount cannot exceed arrears (\$${maxArrearsAmount.toStringAsFixed(2)})';
                                  }
                                }

                                if (enteredAmount <= 0) {
                                  return 'Amount must be greater than zero';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _addPaymentPurpose();
                                }
                              },
                              child: const Text('Add Payment Purpose'),
                            ),
                            const SizedBox(height: 20),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Purpose')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Term')),
                                  DataColumn(
                                      label: Text(
                                          'Action')), // Empty header for X button
                                ],
                                rows: _paymentPurposes.map((payment) {
                                  final PaymentPurpose purpose =
                                      payment['purpose'];

                                  final String termId =
                                      payment['termId'] ?? purpose.termId ?? '';
                                  final term = _termsMap[termId];
                                  final termDisplay = term != null
                                      ? '(${term.termName})'
                                      : '(Unknown)';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                          payment['purpose'].paymentPurpose)),
                                      DataCell(
                                          Text(payment['amount'].toString())),
                                      DataCell(Text(termDisplay)),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.cancel,
                                              color: Colors.red),
                                          tooltip: 'Remove this purpose',
                                          onPressed: () {
                                            setState(() {
                                              _paymentPurposes.remove(payment);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                'Total Amount Entered: \$${totalEntered.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _confirmPayment,
                              child: const Text('Confirm Payment'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessingPayment)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true, // Prevent all taps
                child: Container(
                  color: Colors.black.withOpacity(0.4), // Greyout overlay
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Processing payment, please wait...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
    } else {
      // If globalTermId is null, show an alternative UI or a message
      return Scaffold(
          appBar: AppBar(
            title: const Text('No Selected Term Found'),
          ),
          body: const Center(
            child: Text(
              'No term is currently active. Either switch to an existing term or create a new term to proceed.',
              style: TextStyle(
                fontSize: 16.0, // Set font size
                fontWeight: FontWeight.bold, // Set font weight
                color: Colors.redAccent, // Set text color
                letterSpacing: 1.2, // Set spacing between letters
                height: 1.5, // Set line height (space between lines)
              ),
              textAlign: TextAlign.center, // Align text to the center
            ),
          ));
    }
  }

  Future<double> _computeTotalStudentArrears(Student student) async {
    double total = 0.0;

    try {
      final arrearPurposes =
          await _fetchUniquePaymentPurposesByStudentWithArrears(student);

      for (final entry in arrearPurposes) {
        if (_role == DeviceRole.host) {
          final purpose = entry['purpose'] as PaymentPurpose;
          final arrearsData = await _computeArrearsForPurpose(purpose);

          for (final amt in arrearsData.values) {
            if (amt > 0) total += amt;
          }
        } else {
          final arrearsData = entry['arrears'] as Map<String, double>? ?? {};

          for (final amt in arrearsData.values) {
            if (amt > 0) total += amt;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to compute total arrears: $e');
    }

    return total;
  }

  Future<List<PaymentPurpose>> _fetchUniquePaymentPurposesByStudent(
      Student student) async {
    final List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }
      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    final Set<String> seenPurposeNames = {};

    final List<PaymentPurpose> filtered = [];

    for (final purpose in allPurposes) {
      final isForClass =
          purpose.associatedClasses?.contains(student.class_) ?? false;

      final isException = purpose.exceptions?.any(
            (e) =>
                student.exceptions
                    ?.any((s) => s.exceptionId == e.exceptionId) ??
                false,
          ) ??
          false;

      bool isNewcomerRelated = purpose.forNewcomersOnly == true;
      // Newcomer-specific exclusion logic
      bool newcomerConditionAllows = true;

      if (isNewcomerRelated) {
        if (student.isNewComer != true) {
          // Not a newcomer at all
          newcomerConditionAllows = false;
        } else {
          if (student.isNewComerUntil != null) {
            final newcomerUntil = student.isNewComerUntil!;
            // Look up the term's start date
            final term = _termsMap[purpose.termId];

            if (term != null) {
              final termStart = term.startDate;

              if (termStart.isAfter(newcomerUntil)) {
                // Term started after newcomer status expired
                newcomerConditionAllows = false;
              }
            }
          }
        }
      }

      final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
          newcomerConditionAllows;

      // Deduplicate by paymentPurpose name
      if (shouldInclude) {
        final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
        if (!seenPurposeNames.contains(nameKey)) {
          seenPurposeNames.add(nameKey);
          filtered.add(purpose);
        }
      }
    }

    // ------------------------------------------------------------
    // Step 2: Pre-compute arrears for each applicable purpose
    // ------------------------------------------------------------
    final List<PaymentPurpose> purposesWithArrears = [];

    for (final purpose in filtered) {
      try {
        final arrearsData = await _computeArrearsForPurpose(purpose);

        final hasAnyArrears = arrearsData.values.any((v) => v > 0);
        if (hasAnyArrears) {
          purposesWithArrears.add(purpose);
        }
      } catch (e) {
        debugPrint('⚠️ Failed arrears check for ${purpose.paymentPurpose}: $e');
      }
    }

    return purposesWithArrears;
  }

  Future<List<Map<String, dynamic>>>
      _fetchUniquePaymentPurposesByStudentWithArrears(Student student) async {
    final List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }
      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    final Set<String> seenPurposeNames = {};
    final List<PaymentPurpose> filtered = [];

    for (final purpose in allPurposes) {
      final isForClass =
          purpose.associatedClasses?.contains(student.class_) ?? false;

      final isException = purpose.exceptions?.any(
            (e) =>
                student.exceptions
                    ?.any((s) => s.exceptionId == e.exceptionId) ??
                false,
          ) ??
          false;

      bool isNewcomerRelated = purpose.forNewcomersOnly == true;
      bool newcomerConditionAllows = true;

      if (isNewcomerRelated) {
        if (student.isNewComer != true) {
          newcomerConditionAllows = false;
        } else if (student.isNewComerUntil != null) {
          final newcomerUntil = student.isNewComerUntil!;
          final term = _termsMap[purpose.termId];
          if (term != null && term.startDate.isAfter(newcomerUntil)) {
            newcomerConditionAllows = false;
          }
        }
      }

      final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
          newcomerConditionAllows;

      if (shouldInclude) {
        final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
        if (!seenPurposeNames.contains(nameKey)) {
          seenPurposeNames.add(nameKey);
          filtered.add(purpose);
        }
      }
    }

    // ------------------------------------------------------------
    // STEP 2: Compute arrears & build preview string
    // ------------------------------------------------------------
    final List<Map<String, dynamic>> resultList = [];

    for (final purpose in filtered) {
      try {
        final arrearsData = await _computeArrearsForPurpose(purpose);

        // Filter only terms with positive arrears
        final nonZeroArrears =
            arrearsData.entries.where((e) => e.value > 0).toList();

        if (nonZeroArrears.isNotEmpty) {
          // Sort alphabetically by term text
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

          nonZeroArrears.sort((a, b) {
            final termRegex = RegExp(r'(\d{4})\s+Term\s+(\d+)\s*\((\w+)\)',
                caseSensitive: false);

            final matchA = termRegex.firstMatch(a.key);
            final matchB = termRegex.firstMatch(b.key);

            if (matchA == null || matchB == null) return a.key.compareTo(b.key);

            final yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
            final yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;

            final termA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
            final termB = int.tryParse(matchB.group(2) ?? '0') ?? 0;

            final monthA = monthMap[(matchA.group(3) ?? '').toLowerCase()] ?? 0;
            final monthB = monthMap[(matchB.group(3) ?? '').toLowerCase()] ?? 0;

            // Compare year first, then term, then month
            if (yearA != yearB) return yearA.compareTo(yearB);
            if (termA != termB) return termA.compareTo(termB);
            return monthA.compareTo(monthB);
          });

// Build preview: show max 3 arrears
          final previewParts = nonZeroArrears.take(3).map((e) {
            final display = e.key; // Already like "2025 Term 1 (February)"
            return '$display (\$${e.value.toStringAsFixed(2)})';
          }).join(', ');

          final hasMore = nonZeroArrears.length > 3 ? ', ...' : '';
          final arrearsPreview = '($previewParts$hasMore)';

          resultList.add({
            'purpose': purpose,
            'arrears': {for (var e in nonZeroArrears) e.key: e.value},
            'arrearsPreview': arrearsPreview,
          });
        }
      } catch (e) {
        debugPrint(
            '⚠️ Failed arrears preview for ${purpose.paymentPurpose}: $e');
      }
    }

    return resultList;
  }

  double getAdjustedArrear(
      double arrear, Student student, PaymentPurpose purpose, String termId) {
    final studentExceptions = student.exceptions ?? [];
    final applicablePurposeExceptions = purpose.exceptions ?? [];

    double totalDeduction = 0.0;

    for (var studentException in studentExceptions) {
      if (studentException.exceptionStatus?.toLowerCase() != 'active') continue;

      if (!(studentException.terms?.any(
              (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
          false)) continue;

      final isLinkedToPurpose = applicablePurposeExceptions
          .any((pEx) => pEx.exceptionId == studentException.exceptionId);
      if (!isLinkedToPurpose) continue;

      final double? figure =
          double.tryParse(studentException.exceptionFigure ?? '');
      if (figure == null) continue;

      if (studentException.exceptionType?.toLowerCase() == 'amount') {
        totalDeduction += figure;
      } else if (studentException.exceptionType?.toLowerCase() ==
          'percentage') {
        final percent = (figure / 100) * purpose.purposeAmount;
        totalDeduction += percent;
      }
    }

    final beforeClamp = arrear - totalDeduction;

    // safer than clamp()
    final adjusted = max(0.0, beforeClamp);
    return adjusted;
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByClass(
      String termId, String class_) async {
    if (termId.isEmpty || class_.isEmpty) {
      return [];
    }

    List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final paymentPurposeBox =
          await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = paymentPurposeBox.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }

      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    // Filter for the given term and class
    final allPaymentPurposes = allPurposes.where((purpose) {
      return purpose.termId == termId &&
          (purpose.associatedClasses?.contains(class_) ?? false);
    }).toList();

    return allPaymentPurposes;
  }

  bool _isCheckingArrears = false; // Prevent duplicate execution
  Map<String, double> _arrearsDetails = {}; // Store term and arrears amount
  double _sumPaymentsFromHive({
    required List<StudentPayment> studentPayments,
    required String termId,
    required String purposeName,
  }) {
    if (_selectedStudent == null) return 0.0;

    return studentPayments
        .where((payment) =>
            payment.termId == termId &&
            payment.paymentPurpose.toLowerCase() == purposeName.toLowerCase() &&
            payment.studentName.toLowerCase() ==
                _selectedStudent!.name.toLowerCase() &&
            payment.studentSurname.toLowerCase() ==
                _selectedStudent!.surname.toLowerCase())
        .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));
  }

  double _sumPaymentsFromSession({
    required String termId,
    required String purposeName,
  }) {
    return _paymentPurposes
        .where((p) =>
            p['termId'] == termId &&
            p['purpose'].paymentPurpose.toLowerCase() ==
                purposeName.toLowerCase())
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  Future<void> _checkArrears(PaymentPurpose selectedPurpose) async {
    if (_isCheckingArrears) return;
    setState(() {
      _isCheckingArrears = true;
      setState(() {
        _arrearsDetails.clear();
        _arrearsTerms.clear();
      });
    });

    final List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    _arrearsDetails.clear();
    List<String> overdueTerms = [];

    for (final term in allTerms) {
      if (!_selectedStudent!.terms!.contains(term.termId)) continue;

      // Fetch purposes specifically for this term
      final termPurposes = await _fetchPaymentPurposesByTerm(term.termId);

// Find matching purpose for this term by name
      final matchingPurpose = termPurposes.firstWhere(
        (p) =>
            p.paymentPurpose.toLowerCase() ==
            selectedPurpose.paymentPurpose.toLowerCase(),
        orElse: () => PaymentPurpose(
          paymentPurpose: 'N/A',
          associatedClasses: [],
          id: 0,
          purposeAmount: 0.0,
        ),
      );

      if (matchingPurpose.paymentPurpose == 'N/A') continue;

      // Validate class association
      final isClassMatch = matchingPurpose.associatedClasses
              ?.contains(_selectedStudent!.class_) ??
          false;
      if (!isClassMatch) continue;

      // Apply newcomer condition check
      final isNewcomer = selectedPurpose.forNewcomersOnly == true;
      final termStartDate = term.startDate;
      final termEndDate = term.endDate;

      bool isNewcomerValid = true;

      if (isNewcomer) {
        if (termEndDate != null) {
          if (_selectedStudent?.isNewComer != true ||
              _selectedStudent?.isNewComerUntil == null ||
              termStartDate.isAfter(_selectedStudent!.isNewComerUntil!) ||
              termEndDate.isBefore(_selectedStudent!.isNewComerFrom!)) {
            isNewcomerValid = false;
          }
        } else if (_selectedStudent?.isNewComer != true ||
            _selectedStudent?.isNewComerUntil == null ||
            termStartDate.isAfter(_selectedStudent!.isNewComerUntil!)) {
          isNewcomerValid = false;
        }
      }

      if (!isNewcomerValid) continue;

      final allStudentPayments = _role == DeviceRole.host
          ? Hive.box<StudentPayment>('student_payments').values.toList()
          : _cachedServerStudentPayments ?? [];
      // Calculate paid amounts
      final double hivePaid = _sumPaymentsFromHive(
        studentPayments: allStudentPayments,
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final double sessionPaid = _sumPaymentsFromSession(
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final totalPaid = hivePaid + sessionPaid;
      double arrears = matchingPurpose.purposeAmount - totalPaid;

      arrears = getAdjustedArrear(
        arrears,
        _selectedStudent!,
        matchingPurpose,
        term.termId,
      );

      if (arrears > 0) {
        overdueTerms.add(term.termId);
        _arrearsDetails[term.termId] = arrears;
      }
    }

    setState(() {
      _arrearsTerms = overdueTerms;
      _isCheckingArrears = false;
    });
  }

  Future<Map<String, double>> _computeArrearsForPurpose(
      PaymentPurpose selectedPurpose) async {
    final List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    final Map<String, double> arrearsDetails = {};

    for (final term in allTerms) {
      if (!_selectedStudent!.terms!.contains(term.termId)) continue;

      final termPurposes = await _fetchPaymentPurposesByTerm(term.termId);

      final matchingPurpose = termPurposes.firstWhere(
        (p) =>
            p.paymentPurpose.toLowerCase() ==
            selectedPurpose.paymentPurpose.toLowerCase(),
        orElse: () => PaymentPurpose(
          paymentPurpose: 'N/A',
          associatedClasses: [],
          id: 0,
          purposeAmount: 0.0,
        ),
      );

      if (matchingPurpose.paymentPurpose == 'N/A') continue;

      final isClassMatch = matchingPurpose.associatedClasses
              ?.contains(_selectedStudent!.class_) ??
          false;
      if (!isClassMatch) continue;

      // Apply newcomer condition check
      final isNewcomer = selectedPurpose.forNewcomersOnly == true;
      final termStartDate = term.startDate;
      final termEndDate = term.endDate;

      bool isNewcomerValid = true;
      if (isNewcomer) {
        if (termEndDate != null) {
          if (_selectedStudent?.isNewComer != true ||
              _selectedStudent?.isNewComerUntil == null ||
              termStartDate.isAfter(_selectedStudent!.isNewComerUntil!) ||
              termEndDate.isBefore(_selectedStudent!.isNewComerFrom!)) {
            isNewcomerValid = false;
          }
        } else if (_selectedStudent?.isNewComer != true ||
            _selectedStudent?.isNewComerUntil == null ||
            termStartDate.isAfter(_selectedStudent!.isNewComerUntil!)) {
          isNewcomerValid = false;
        }
      }

      if (!isNewcomerValid) continue;

      final allStudentPayments = _role == DeviceRole.host
          ? Hive.box<StudentPayment>('student_payments').values.toList()
          : _cachedServerStudentPayments ?? [];

      final double hivePaid = _sumPaymentsFromHive(
        studentPayments: allStudentPayments,
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final double sessionPaid = _sumPaymentsFromSession(
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final totalPaid = hivePaid + sessionPaid;
      double arrears = matchingPurpose.purposeAmount - totalPaid;

      arrears = getAdjustedArrear(
        arrears,
        _selectedStudent!,
        matchingPurpose,
        term.termId,
      );

      if (arrears > 0) {
        arrearsDetails[term.termId] = arrears;
      }
    }

    return arrearsDetails;
  }

// Fetch payment purposes by termId
  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTerm(
      String termId) async {
    List<PaymentPurpose> allPurposes = [];

    if (_role == DeviceRole.host) {
      // Host reads from local Hive box
      final box = Hive.box<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      // Client uses cached server data
      allPurposes = _cachedServerStudentPaymentPurposes ?? [];
    }

    return allPurposes.where((purpose) => purpose.termId == termId).toList();
  }

  void _clearAllServerCaches() {
    _cachedServerStudentPayments = null;
    _cachedServerTerms = null;
    _cachedServerStudentPaymentPurposes = null;
    _cachedServerStudents = null;
    _cachedServerSchoolInfo = null;
    _cachedFilteredStudents = null;
  }

  @override
  void dispose() {
    bluetoothHelper.dispose(); // Properly dispose of BluetoothHelper

    _paymentAmountController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
