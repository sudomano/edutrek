// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
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
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/rng.dart';

class DuplicatedPaymentWithReceipt extends StatefulWidget {
  const DuplicatedPaymentWithReceipt({Key? key}) : super(key: key);

  @override
  _MakePaymentScreenState createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends State<DuplicatedPaymentWithReceipt> {
// bluetooth helper
  late BluetoothHelper bluetoothHelper;

  final _formKey = GlobalKey<FormState>();
  final _studentSearchController = TextEditingController();
  final TextEditingController _paymentAmountController =
      TextEditingController();
  String? _selectedItemId;
  String? _selectedStudentId;
  String? _selectedStudentName;
  String? _selectedStudentSurname;
  String? _selectedStudentClass;
  String? _selectedStudentPhone;
  String? _selectedStudentParent;

  String? _selectedProjectCode;
  double? _paymentAmount;
  Student? _selectedStudent;
  DateTime _paymentDate = DateTime.now();
  String? _paymentInfo;
  String? _phoneNumber;
  List<Student> _students = [];
  List<Student> _searchResults = [];
  List<Project> _projects = [];
  List<ProjectItem> _projectItems = [];

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

  @override
  void initState() {
    super.initState();
    _loadDropdownData();

    // Create a BluetoothHelper instance
    final bluetoothHelper = BluetoothHelper();

    // Set up the connection state change callback
    bluetoothHelper.onConnectionStateChanged = (isConnected, message) {
      debugPrint('Connection Status: $isConnected, Message: $message');
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

  Future<void> sendSms(String message, String recipient) async {
    // Check SMS permission
    if (Platform.isAndroid) {
      var status = await Permission.sms.status;
      if (!status.isGranted) {
        // Request permission
        var result = await Permission.sms.request();
        if (result.isDenied) {
          _showSnackBar('SMS permission is not granted. Cannot send SMS.');
          return; // Exit if permission is denied
        }
      }

      try {
        await BackgroundSms.sendMessage(
          phoneNumber: recipient,
          message: message,
        );
      } catch (e) {
        _showSnackBar('Failed to send SMS: $e');
      }
    } else {
      _showSnackBar('');
    }
  }

  Future<School> _fetchSchoolInfo() async {
    final schoolBox = await Hive.openBox<School>('school');

    // Check if the box is not empty and fetch the first school entry
    if (schoolBox.isNotEmpty) {
      // Assuming there's only one entry, fetch the first entry
      return schoolBox.values.first;
    } else {
      // Return a default instance if the box is empty
      return School(
        schoolName: 'School Receipt',
        schoolAddress: 'P.O.Box....',
        schoolEmail: '@school.co.zw',
        schoolPhoneNumber: '+263.........',
      );
    }
  }

  Future<void> _loadDropdownData() async {
    final studentBox = Hive.box<Student>('students');
    final projectBox = Hive.box<Project>('projects');
    final projectItemBox = Hive.box<ProjectItem>('projectItems');

    setState(() {
      _students = studentBox.values.toList();
      _projects = projectBox.values.toList();
      _projectItems = projectItemBox.values.toList();
      _searchResults = _students; // Initialize search results.
    });
  }

  void _searchStudent() {
    final query = _studentSearchController.text.trim();

    if (query.isEmpty) {
      _showSnackBar('Please enter a surname to search');
      return;
    }

    final studentBox = Hive.box<Student>('students');
    final matchingStudents = studentBox.values
        .where((student) =>
            student.surname.toLowerCase().contains(query.toLowerCase()) &&
            student.termId == globalTermId)
        .toList();

    if (matchingStudents.isEmpty) {
      _showSnackBar(
          'No matching students found for this Term: ($globalTermId)');
    } else {
      _displayStudentSelectionDialog(matchingStudents);
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

  Future<void> _confirmPayment() async {
    final Box<ProjectItem> box =
        await Hive.openBox<ProjectItem>('projectItems');

    final List<ProjectItem> filteredPaymentPurposes = box.values
        .where((paymentPurpose) =>
            paymentPurpose.projectItemCode == _selectedItemId)
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Center(child: Text('Confirm Payment')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(capitalize(
                    'Student: ${_searchResults.first.name} ${_searchResults.first.surname} ${_searchResults.first.class_}')),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Purpose')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: filteredPaymentPurposes.map((payment) {
                    return DataRow(
                      cells: [
                        DataCell(Text(capitalize(payment.name))),
                        DataCell(Text(
                            double.parse(_paymentAmountController.text)
                                .toString())),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
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
              onPressed: BluetoothHelper().isConnected ||
                      (_connected && BluetoothStates != 0)
                  ? () async {
                      Map<String, dynamic> config = {};
                      try {
                        final School schoolInfo = await _fetchSchoolInfo();
                        List<LineText> list = [];

                        // Add school logo (if available)
                        if (schoolInfo.schoolLogoPath != null &&
                            schoolInfo.schoolLogoPath!.isNotEmpty) {
                          list.add(LineText(
                            type: LineText.TYPE_IMAGE,
                            content: schoolInfo
                                .schoolLogoPath, // Path to the logo image
                            align: LineText.ALIGN_CENTER,
                            linefeed: 1,
                          ));
                        }
                        int newId = await getNextId();

                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: '${schoolInfo.schoolName?.toUpperCase()}',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          fontZoom: 2,
                          weight: 1,
                        ));
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: '${schoolInfo.schoolAddress}',
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
                        final studentName = _selectedStudentName?.toUpperCase();
                        final studentSurname =
                            _selectedStudentSurname?.toUpperCase();
                        final studentClass =
                            _selectedStudentClass?.toUpperCase();
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: 'Name: $studentName  $studentSurname',
                          align: LineText.ALIGN_LEFT,
                          linefeed: 1,
                          fontZoom: 1,
                        ));
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: 'Class: $studentClass',
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
                        for (var payment in filteredPaymentPurposes) {
                          final amountPaid =
                              double.parse(_paymentAmountController.text);

                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content:
                                '${payment.name.toString().toUpperCase()} :    \$ ${amountPaid} ',
                            align: LineText.ALIGN_LEFT,
                            linefeed: 1,
                            fontZoom: 1,
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
                          content: 'TOTALS',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          weight: 1,
                          fontZoom: 1,
                        ));

                        double totalAmount = filteredPaymentPurposes.fold(
                            0,
                            (sum, payment) =>
                                sum +
                                double.parse(_paymentAmountController.text));
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: 'GRAND TOTAL: \$ $totalAmount',
                          align: LineText.ALIGN_LEFT,
                          linefeed: 1,
                          fontZoom: 1,
                          weight: 1,
                        ));

                        final itemAmount = filteredPaymentPurposes.first.amount;
                        final balance = itemAmount - totalAmount;
                        if (balance < 0) {
                          final newBalance = balance - balance - balance;
                          print(newBalance);
                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content: 'PRE-PAYED: \$ $newBalance',
                            align: LineText.ALIGN_LEFT,
                            linefeed: 1,
                            fontZoom: 1,
                            weight: 1,
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
                          align: LineText.ALIGN_LEFT,
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

                        // Send the data to the printer
                        await BluetoothHelper()
                            .bluetoothPrint
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
        );
      },
    );
  }

  Future<void> _makePayment() async {
    final paymentBox =
        Hive.box<ProjectStudentPayment>('projectStudentPayments');
    final studentName = _selectedStudentName?.toUpperCase();
    final studentSurname = _selectedStudentSurname?.toUpperCase();
    final phone = _selectedStudentPhone;
    final parentName = _selectedStudentParent?.toUpperCase();
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(_paymentDate);
    final allPaymentsInfo = _generatePaymentSummary(studentName.toString(),
        studentSurname.toString(), formattedDate, phone, parentName);
    final amountPaid = double.parse(_paymentAmountController.text);

    final adminBox = Hive.box<User>('users');
    final _results = adminBox.values
        .where((term) => term.role.toLowerCase() == "admin")
        .toList();
    final uname = _results.first.username;
    final uphone = _results.first.phone;
    final allAdminPaymentsInfo = _generateAdminPaymentSummary(
        studentName.toString(),
        studentSurname.toString(),
        formattedDate,
        uphone,
        uname);

    final uuid = const Uuid();

    // Search for an existing payment record.
    final existingPaymentss =
        paymentBox.values.cast<ProjectStudentPayment>().where(
              (payment) =>
                  payment.studentId == _selectedStudentId &&
                  payment.projectCode == _selectedProjectCode &&
                  payment.itemId == _selectedItemId,
            );
    ProjectStudentPayment? existingPayment =
        existingPaymentss.isNotEmpty ? existingPaymentss.first : null;

    if (existingPayment != null) {
      // Update existing record.
      debugPrint('Existing payment found. Updating record...');
      existingPayment
        ..amountPaid += amountPaid
        ..balance -= amountPaid // Assuming balance decreases with payment.
        ..lastModified = DateTime.now()
        ..syncStatus = false // Mark as unsynced.
        ..operationType = 'update';
      existingPayment.save();

      debugPrint(
          'Updated Payment: ${existingPayment.amountPaid}, New Balance: ${existingPayment.balance}');
    } else {
      // Create new record.
      debugPrint('No existing payment found. Creating new record...');
      final Box<ProjectItem> box =
          await Hive.openBox<ProjectItem>('projectItems');

      // Filter payment purposes based on termId == globalTermId
      final List<ProjectItem> filteredPaymentPurposes = box.values
          .where((paymentPurpose) =>
              paymentPurpose.projectItemCode == _selectedItemId)
          .toList();

      final itemAmount = filteredPaymentPurposes.first.amount;
      debugPrint('Item Amount: $itemAmount');

      final newPayment = ProjectStudentPayment(
        projectStudentPaymentCode:
            DateTime.now().toIso8601String(), // Unique code.
        studentId: _selectedStudentId!,
        projectCode: _selectedProjectCode!,
        itemId: _selectedItemId!,
        amountPaid: amountPaid,
        balance: itemAmount - amountPaid, // Example balance logic.
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'create',
      );

      paymentBox.add(newPayment);

      debugPrint('New Payment Created: $newPayment');
    }
    sendSms(allAdminPaymentsInfo.toString(), uphone);
    _showSnackBar('Student Payment Made SUCCESSFULLY.');

    _resetForm();
    _sendSmsNotification(allPaymentsInfo.toString(), phone);

    Navigator.pop(context);
    Navigator.pop(context);
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<StudentPayment>('student_payments');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  String _generatePaymentSummary(String studentName, String studentSurname,
      String formattedDate, String? phone, String? parentName) {
    String summary = '';
    final Box<ProjectItem> box = Hive.box<ProjectItem>('projectItems');

    // Filter payment purposes based on termId == globalTermId
    final List<ProjectItem> filteredPaymentPurposes = box.values
        .where((paymentPurpose) =>
            paymentPurpose.projectItemCode == _selectedItemId)
        .toList();

    for (var payment in filteredPaymentPurposes) {
      final paymentPurpose = payment.name.toUpperCase();
      final paymentAmount = payment.amount;
      final amountPaid = double.parse(_paymentAmountController.text);

      final schoolBox = Hive.box<School>('school');
      if (schoolBox.isEmpty) {
        return 'School information not found';
      }

      final schoolInfo = schoolBox.values.first;

      final schoolName = schoolInfo.schoolName?.toUpperCase() ?? '';
      summary +=
          ' $schoolName  \n \n Dear $parentName, you are being notified that $studentName $studentSurname has paid an AMOUNT OF \$ $amountPaid for the PURPOSE OF $paymentPurpose on the DATE: $formattedDate.\n ';
    }

    _paymentInfo = summary;
    _phoneNumber = phone.toString();
    return summary;
  }

  Future<String> _generateAdminPaymentSummary(
      String studentName,
      String studentSurname,
      String formattedDate,
      String? uphone,
      String? uname) async {
    String summary = '';
    final Box<ProjectItem> box =
        await Hive.openBox<ProjectItem>('projectItems');

    // Filter payment purposes based on termId == globalTermId
    final List<ProjectItem> filteredPaymentPurposes = box.values
        .where((paymentPurpose) =>
            paymentPurpose.projectItemCode == _selectedItemId)
        .toList();
    for (var payment in filteredPaymentPurposes) {
      final paymentPurpose = payment.name.toUpperCase();
      final paymentAmount = payment.amount;

      summary +=
          'Student $studentName $studentSurname has paid an AMOUNT OF \$ $paymentAmount for the PURPOSE OF $paymentPurpose on the DATE: $formattedDate.\n';
    }

    _paymentInfo = summary;
    _phoneNumber = uphone.toString();
    return summary;
  }

  void _sendSmsNotification(String allPaymentsInfo, String? phone) {
    if (Platform.isAndroid == true) {
      if (allPaymentsInfo.isEmpty) {
        _showSnackBar('No payment made yet');
        return;
      }
      launcher.launchUrl(Uri.parse(
          'sms:$phone${Platform.isAndroid ? '?' : '&'}body=$allPaymentsInfo'));
    } else {
      _showSnackBar('');
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
      _paymentDate = DateTime.now();
    });
  }

  void _showStudentSearchModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search Student',
                              suffixIcon: Icon(Icons.search),
                            ),
                            onChanged: (query) {
                              setState(() {
                                _searchResults = _students
                                    .where((student) =>
                                        (student.name.toLowerCase().contains(
                                                query.toLowerCase()) ||
                                            student.surname
                                                .toLowerCase()
                                                .contains(
                                                    query.toLowerCase())) &&
                                        student.termId == globalTermId)
                                    .toList();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _searchResults.isEmpty
                                ? const Center(
                                    child: Text("No students found."))
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final student = _searchResults[index];

                                      return ListTile(
                                        title: Text(
                                            '${student.name} ${student.surname}'),
                                        onTap: () {
                                          setState(() {
                                            _selectedStudentId =
                                                student.studentIdNumber;
                                            _selectedStudentName =
                                                student.name.toString();
                                            _selectedStudentSurname =
                                                student.surname.toString();
                                            _selectedStudentClass =
                                                student.class_.toString();
                                            _selectedStudentPhone =
                                                student.phoneNumber.toString();
                                            _selectedStudentParent = student
                                                .paymentStatus
                                                .toString();
                                          });
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ProjectItem> _filteredProjectItems = _projectItems.where((item) {
      return item.projectCode == _selectedProjectCode;
    }).toList();
    if (globalTermId != null) {
      return Scaffold(
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
                    timeout: const Duration(seconds: 4)),
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
                    onRefresh: () => BluetoothHelper().bluetoothPrint.startScan(
                          timeout: const Duration(seconds: 4),
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
                                BluetoothHelper().bluetoothPrint.scanResults,
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
                                                _device!.address == d.address
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
                            padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    OutlinedButton(
                                      onPressed: BluetoothHelper().isConnected
                                          ? null
                                          : () async {
                                              if (_device != null &&
                                                  _device!.address != null) {
                                                setState(() {
                                                  tips = 'Connecting...';
                                                });
                                                try {
                                                  await BluetoothHelper()
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
                                      onPressed: BluetoothHelper().isConnected
                                          ? () async {
                                              setState(() {
                                                tips = 'Disconnecting...';
                                              });
                                              try {
                                                await BluetoothHelper()
                                                    .bluetoothPrint
                                                    .disconnect();
                                                setState(() {
                                                  tips = 'Disconnected';
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(
                            _selectedStudentId == null
                                ? 'Select Student'
                                : 'Selected: $_selectedStudentId  - $_selectedStudentName  $_selectedStudentSurname  $_selectedStudentClass ',
                          ),
                          trailing: const Icon(Icons.search),
                          onTap: _showStudentSearchModal,
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedProjectCode,
                          items: _projects
                              .map((project) => DropdownMenuItem(
                                    value: project.projectCode,
                                    child: Text(project.name),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                              labelText: 'Select Project'),
                          onChanged: (value) {
                            setState(() {
                              _selectedProjectCode = value;
                              // Filter items based on the selected project code
                              _filteredProjectItems = _projectItems
                                  .where((item) =>
                                      item.projectCode == _selectedProjectCode)
                                  .toList();
                              // Reset the selected item when project changes
                              _selectedItemId = null;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a project' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedItemId,
                          items: _filteredProjectItems
                              .map((item) => DropdownMenuItem(
                                    value: item.projectItemCode,
                                    child: Text('  ${item.name}'),
                                  ))
                              .toList(),
                          decoration:
                              const InputDecoration(labelText: 'Select Item'),
                          onChanged: (value) {
                            setState(() {
                              _selectedItemId = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select an item' : null,
                        ),
                        TextFormField(
                          controller: _paymentAmountController,
                          decoration:
                              const InputDecoration(labelText: 'Amount'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter amount'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _confirmPayment,
                            child: const Text('Submit Payment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
