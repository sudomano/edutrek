// ignore_for_file: unused_field

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
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
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/rng.dart';

class MakePaymentScreen extends StatefulWidget {
  const MakePaymentScreen({Key? key}) : super(key: key);

  @override
  _MakePaymentScreenState createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends State<MakePaymentScreen> {
// bluetooth helper
  late BluetoothHelper bluetoothHelper;

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
  String? _phoneNumber;

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
  @override
  void initState() {
    super.initState();

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
    } catch (e) {}
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

  Future<Box<PaymentPurpose>> _openPaymentPurposeBox() async {
    return await Hive.openBox<PaymentPurpose>('payment_purposes');
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTermId(
      String globalTermId) async {
    final paymentPurposeBox =
        await _openPaymentPurposeBox(); // Assuming this opens the box
    return paymentPurposeBox.values
        .where((purpose) => purpose.termId == globalTermId)
        .toList();
  }

  Future<List<PaymentPurpose>> _getPaymentPurposesForGlobalTerm() async {
    final Box<PaymentPurpose> box =
        await Hive.openBox<PaymentPurpose>('payment_purposes');

    // Filter payment purposes based on termId == globalTermId
    final List<PaymentPurpose> filteredPaymentPurposes = box.values
        .where((paymentPurpose) => paymentPurpose.termId == globalTermId)
        .toList();

    return filteredPaymentPurposes;
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

  void _addPaymentPurpose() {
    if (_selectedPaymentPurpose == null ||
        _paymentAmount == null ||
        _paymentAmount! <= 0) {
      _showSnackBar('Please select a payment purpose and enter a valid amount');
      return;
    }

    setState(() {
      _paymentPurposes.add({
        'purpose': _selectedPaymentPurpose!,
        'amount': _paymentAmount!,
      });
      _selectedPaymentPurpose = null;
      _paymentAmount = null; // Reset the payment amount
      _paymentAmountController.clear(); // Clear the text field
    });
  }

  void _confirmPayment() {
    if (_selectedStudent == null) {
      _showSnackBar('Please select a student first');
      return;
    }

    if (_paymentPurposes.isEmpty) {
      _showSnackBar('Please add at least one payment purpose');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Center(child: Text('Confirm Payment')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(capitalize(
                  'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}')),
              DataTable(
                columns: const [
                  DataColumn(label: Text('Purpose')),
                  DataColumn(label: Text('Amount')),
                ],
                rows: _paymentPurposes.map((payment) {
                  return DataRow(
                    cells: [
                      DataCell(
                          Text(capitalize(payment['purpose'].paymentPurpose))),
                      DataCell(Text(payment['amount'].toString())),
                    ],
                  );
                }).toList(),
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
                        for (var payment in _paymentPurposes) {
                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content:
                                '${payment['purpose'].paymentPurpose.toString().toUpperCase()} :    \$ ${payment['amount']} ',
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

                        double totalAmount = _paymentPurposes.fold(
                            0, (sum, payment) => sum + payment['amount']);
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: 'GRAND TOTAL: \$ $totalAmount',
                          align: LineText.ALIGN_LEFT,
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
    final paymentBox = Hive.box<StudentPayment>('student_payments');
    final studentName = _selectedStudent!.name.toUpperCase();
    final studentSurname = _selectedStudent!.surname.toUpperCase();
    final phone = _selectedStudent!.phoneNumber;
    final parentName = _selectedStudent!.paymentStatus.toUpperCase();
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(_paymentDate);
    final allPaymentsInfo = _generatePaymentSummary(
        studentName, studentSurname, formattedDate, phone, parentName);

    final adminBox = Hive.box<User>('users');
    final _results = adminBox.values
        .where((term) => term.role.toLowerCase() == "admin")
        .toList();
    final uname = _results.first.username;
    final uphone = _results.first.phone;
    final allAdminPaymentsInfo = _generateAdminPaymentSummary(
        studentName, studentSurname, formattedDate, uphone, uname);

    final uuid = Uuid();

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
        termId: globalTermId,
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType: 'create', // Set operationType to 'create'
        modifiedFields: modifiedFields,
      );

      paymentBox.add(newPayment);
    }
    sendSms(allAdminPaymentsInfo, uphone);
    _showSnackBar('Student Payment Made SUCCESSFULLY.');

    _resetForm();
    _sendSmsNotification(allPaymentsInfo, phone);

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

    for (var payment in _paymentPurposes) {
      final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
      final paymentAmount = payment['amount'];
      final schoolBox = Hive.box<School>('school');
      if (schoolBox.isEmpty) {
        return 'School information not found';
      }

      final schoolInfo = schoolBox.values.first;

      final schoolName = schoolInfo.schoolName?.toUpperCase() ?? '';
      summary +=
          ' $schoolName  \n \n Dear $parentName, you are being notified that $studentName $studentSurname has paid an AMOUNT OF \$ $paymentAmount for the PURPOSE OF $paymentPurpose on the DATE: $formattedDate.\n ';
    }

    _paymentInfo = summary;
    _phoneNumber = phone.toString();
    return summary;
  }

  String _generateAdminPaymentSummary(String studentName, String studentSurname,
      String formattedDate, String? uphone, String? uname) {
    String summary = '';

    for (var payment in _paymentPurposes) {
      final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
      final paymentAmount = payment['amount'];

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

  @override
  Widget build(BuildContext context) {
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
                                onPressed: _searchStudent,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedStudent != null)
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}'),
                                  const SizedBox(height: 10),
                                  Text('Class: ${_selectedStudent!.class_}'),
                                  const SizedBox(height: 10),
                                  Text(
                                      'Phone: ${_selectedStudent!.phoneNumber}'),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (_selectedStudent !=
                            null) // Fetch payment purposes only if a student is selected

                          FutureBuilder<List<PaymentPurpose>>(
                            future: _fetchPaymentPurposesByClass(
                                globalTermId!,
                                _selectedStudent!
                                    .class_), // Pass termId and class_

                            builder: (context,
                                AsyncSnapshot<List<PaymentPurpose>> snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return const Text(
                                    'No payment purposes found for the selected student class.');
                              } else {
                                final paymentPurposes = snapshot.data!;
                                return Container(
                                  color:
                                      const Color.fromARGB(255, 229, 230, 230),
                                  child: Container(
                                    child:
                                        DropdownButtonFormField<PaymentPurpose>(
                                      decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide:
                                                BorderSide.none, // No border
                                          ),
                                          labelText: 'Select Payment Purpose'),
                                      items: paymentPurposes.map((purpose) {
                                        return DropdownMenuItem(
                                          value: purpose,
                                          child: Text(purpose.paymentPurpose),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedPaymentPurpose = value;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        if (_selectedPaymentPurpose != null &&
                            _selectedStudent != null)
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Purpose: ${_selectedPaymentPurpose?.paymentPurpose ?? ''}'),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Container(
                          color: const Color.fromARGB(255, 229, 230, 230),
                          child: TextFormField(
                            controller: _paymentAmountController,
                            decoration: const InputDecoration(
                                labelText: 'Payment Amount'),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _paymentAmount = double.tryParse(
                                  value); // Update _paymentAmount for logic
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _addPaymentPurpose,
                          child: const Text('Add Payment Purpose'),
                        ),
                        const SizedBox(height: 20),
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('Purpose')),
                            DataColumn(label: Text('Amount')),
                          ],
                          rows: _paymentPurposes.map((payment) {
                            return DataRow(
                              cells: [
                                DataCell(
                                    Text(payment['purpose'].paymentPurpose)),
                                DataCell(Text(payment['amount'].toString())),
                              ],
                            );
                          }).toList(),
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

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByClass(
      String termId, String class_) async {
    if (globalTermId == null || class_ == null) {
      return []; // Return an empty list if required fields are null
    }
    final paymentPurposeBox =
        await _openPaymentPurposeBox(); // Assuming this opens the box
    final allPaymentPurposes = paymentPurposeBox.values
        .where((purpose) => purpose.termId == globalTermId)
        .where(
            (purpose) => purpose.associatedClasses?.contains(class_) ?? false)
        .toList();

    return allPaymentPurposes;
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
