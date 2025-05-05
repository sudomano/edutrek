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
import 'package:zitf_system/database/terms.dart';
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

  Future<void> sendSms(String allAdminPaymentsInfo, String recipient) async {
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
    }

    try {
      await BackgroundSms.sendMessage(
        phoneNumber: recipient,
        message: allAdminPaymentsInfo,
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
            student.surname.toLowerCase().contains(query.toLowerCase()))
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
      _showSnackBar('Please select a valid payment purpose and amount.');
      return;
    }

    if (_arrearsTerms.isNotEmpty && _selectedArrearsTerm == null) {
      _showSnackBar('Please select a term to pay arrears.');
      return;
    }

    setState(() {
      _paymentPurposes.add({
        'purpose': _selectedPaymentPurpose!,
        'amount': _paymentAmount!,
        'termId': _selectedArrearsTerm ??
            globalTermId, // Use selected arrears term or current term
      });
      _paymentAmountController.clear();
      _paymentAmount = null;
      _selectedPaymentPurpose = null;
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
              onPressed: _connected
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
                        double totalPaid = 0.0;

                        for (var payment in _paymentPurposes) {
                          double amountPaid = payment['amount'];
                          totalPaid += amountPaid;
                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content:
                                '${payment['purpose'].paymentPurpose.toString().toUpperCase()} :    \$ ${payment['amount']} ',
                            align: LineText.ALIGN_LEFT,
                            linefeed: 1,
                            fontZoom: 1,
                          ));
                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content:
                                'TERM OF :  ${payment['termId']} ', // Consider selected arrears term
                            align: LineText.ALIGN_LEFT,
                            linefeed: 1,
                            fontZoom: 1,
                          ));
                        }
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: '------------------------',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          fontZoom: 1,
                        ));
                        if (_selectedPaymentPurpose != null) {
                          await _checkArrears(_selectedPaymentPurpose!);
                        }

                        // ✅ Initialize arrears summary
                        double totalArrearsBefore = _arrearsDetails.values
                            .fold(0.0, (sum, amount) => sum + (amount ?? 0.0));
                        // ✅ Deduct the payment from the corresponding term
                        if (_selectedArrearsTerm != null &&
                            _arrearsDetails.containsKey(_selectedArrearsTerm)) {
                          _arrearsDetails[_selectedArrearsTerm.toString()] =
                              (_arrearsDetails[_selectedArrearsTerm]! -
                                      totalPaid)
                                  .clamp(0.0, double.infinity);
                        }

                        double totalArrearsAfter = _arrearsDetails.values
                            .fold(0.0, (sum, amount) => sum + (amount ?? 0.0));
                        // ✅ Add Arrears Details to Receipt
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: 'ARREARS SUMMARY (BEFORE PAYMENT)',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          fontZoom: 1,
                          weight: 1,
                        ));

                        if (_arrearsDetails.isNotEmpty) {
                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content:
                                'TOTAL ARREARS BEFORE PAYMENT: \$${totalArrearsBefore.toStringAsFixed(2)}',
                            align: LineText.ALIGN_LEFT,
                            linefeed: 1,
                            fontZoom: 1,
                            weight: 1,
                          ));
                        }

                        // ✅ Show updated arrears after payment
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
                          content: 'UPDATED ARREARS AFTER PAYMENT',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          fontZoom: 1,
                          weight: 1,
                        ));
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: '------------------------',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          fontZoom: 1,
                        ));
                        _arrearsDetails.forEach((termId, arrearsAmount) {
                          list.add(LineText(
                            type: LineText.TYPE_TEXT,
                            content:
                                'Term: $termId - Updated Arrears: \$${arrearsAmount.toStringAsFixed(2)}',
                            align: LineText.ALIGN_LEFT,
                            linefeed: 1,
                            fontZoom: 1,
                          ));
                        });
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content: '------------------------',
                          align: LineText.ALIGN_CENTER,
                          linefeed: 1,
                          fontZoom: 1,
                        ));
                        list.add(LineText(
                          type: LineText.TYPE_TEXT,
                          content:
                              'TOTAL ARREARS AFTER PAYMENT: \$${totalArrearsAfter.toStringAsFixed(2)}',
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
                          content: 'GRAND TOTAL PAID: \$ $totalAmount',
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

    final uuid = const Uuid();

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
        termId: payment['termId'], // Consider selected arrears term
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

    // ✅ Compute arrears before payment
    double totalArrearsBefore = _arrearsDetails.values
        .fold(0.0, (sum, amount) => sum + (amount ?? 0.0));
    // ✅ Compute the total amount paid in this transaction
    double totalPaid = 0.0;
    for (var payment in _paymentPurposes) {
      double amountPaid = payment['amount'];
      totalPaid += amountPaid;
      final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
      final paymentAmount = payment['amount'];
      final schoolBox = Hive.box<School>('school');
      final term = payment['termId'];
      if (schoolBox.isEmpty) {
        return 'School information not found';
      }

      final schoolInfo = schoolBox.values.first;

      final schoolName = schoolInfo.schoolName?.toUpperCase() ?? '';
      summary +=
          ' $schoolName \n Dear $parentName, you are being notified that $studentName $studentSurname has paid an AMOUNT OF \$ $paymentAmount for the PURPOSE OF $paymentPurpose for the TERM of - $term on the DATE: $formattedDate. ';

      // ✅ Deduct payment from arrears for the selected term
      if (_selectedArrearsTerm != null &&
          _arrearsDetails.containsKey(_selectedArrearsTerm)) {
        _arrearsDetails[_selectedArrearsTerm.toString()] =
            (_arrearsDetails[_selectedArrearsTerm]! - totalPaid)
                .clamp(0.0, double.infinity);
      }

      // ✅ Compute arrears after payment
      double totalArrearsAfter = _arrearsDetails.values
          .fold(0.0, (sum, amount) => sum + (amount ?? 0.0));

      /* // ✅ Append Arrears Summary Before Payment
    summary += '**Arrears Summary (Before Payment)**';
    _arrearsDetails.forEach((termId, arrearsAmount) {
      summary +=
          'Term: $termId - Arrears: \$${arrearsAmount.toStringAsFixed(2)}';
    });
    summary +=
        'Total Arrears Before Payment: \$${totalArrearsBefore.toStringAsFixed(2)}';
*/
      // ✅ Append Updated Arrears Summary After Payment
      summary += ' ** $paymentPurpose Arrears After Payment ** - ';
      _arrearsDetails.forEach((termId, arrearsAmount) {
        summary +=
            'Term: $termId - $paymentPurpose Arrears: \$${arrearsAmount.toStringAsFixed(2)} - ';
      });
      summary +=
          '** Total $paymentPurpose Arrears After Payment ** : \$${totalArrearsAfter.toStringAsFixed(2)} - ';
    }
    _paymentInfo = summary;
    _phoneNumber = phone.toString();

    return summary;
  }

  String _generateAdminPaymentSummary(String studentName, String studentSurname,
      String formattedDate, String? uphone, String? uname) {
    String summary = '';
// ✅ Compute arrears before payment
    double totalArrearsBefore = _arrearsDetails.values
        .fold(0.0, (sum, amount) => sum + (amount ?? 0.0));
    // ✅ Compute the total amount paid in this transaction
    double totalPaid = 0.0;

    for (var payment in _paymentPurposes) {
      double amountPaid = payment['amount'];
      totalPaid += amountPaid;
      final paymentPurpose = payment['purpose'].paymentPurpose.toUpperCase();
      final paymentAmount = payment['amount'];
      final term = payment['termId'];

      summary +=
          'Student $studentName $studentSurname has paid an AMOUNT OF \$ $paymentAmount for the PURPOSE OF $paymentPurpose for the TERM of $term on the DATE: $formattedDate.  - ';
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
                    onRefresh: () => bluetoothHelper.bluetoothPrint.startScan(
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
                            stream: bluetoothHelper.bluetoothPrint.scanResults,
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
                                      onPressed: _connected
                                          ? null
                                          : () async {
                                              if (_device != null &&
                                                  _device!.address != null) {
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
                            _selectedStudent != null) ...[
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
                                  FutureBuilder(
                                    future:
                                        _checkArrears(_selectedPaymentPurpose!),
                                    builder: (context, snapshot) {
                                      if (_arrearsTerms.isNotEmpty) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Arrears Were Found. Select a term to pay:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            // Display arrears details (term and amount)
                                            ..._arrearsDetails.entries
                                                .map((entry) {
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
                                              hint: const Text('Select Term'),
                                              isExpanded: true,
                                              items:
                                                  _arrearsTerms.map((termId) {
                                                return DropdownMenuItem<String>(
                                                  value: termId,
                                                  child: Text(
                                                      'Term: $termId - Arrears: \$${_arrearsDetails[termId]?.toStringAsFixed(2) ?? '0.00'}'),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedArrearsTerm = value!;
                                                  _paymentAmountController
                                                      .clear(); // Clear amount when term changes
                                                });
                                              },
                                            ),
                                            // Add the message right below the dropdown
                                            if (_selectedArrearsTerm != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Text(
                                                  _selectedArrearsTerm ==
                                                          globalTermId
                                                      ? 'You can make prepayments for this term.'
                                                      : 'Payment for previous term arrears cannot exceed the due amount.',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontStyle: FontStyle.italic,
                                                    color:
                                                        _selectedArrearsTerm ==
                                                                globalTermId
                                                            ? Colors.green
                                                            : Colors.red,
                                                  ),
                                                ),
                                              ),
                                            // "Cancel" button to reset term selection
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
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors
                                                      .red, // Button color
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                                ),
                                                child: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: const Text(
                                                    'Cancel Selection',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )),
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
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blue, // Button color
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                              _paymentAmount = double.tryParse(value) ?? 0.0;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }

                            final enteredAmount = double.tryParse(value) ?? 0.0;

                            if (_selectedArrearsTerm.toString() != null) {
                              // Check against arrears amount if selected term is not the current term
                              final maxArrearsAmount =
                                  _arrearsDetails[_selectedArrearsTerm] ?? 0.0;

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

  bool _isCheckingArrears = false; // Prevent duplicate execution
  Map<String, double> _arrearsDetails = {}; // Store term and arrears amount

  Future<void> _checkArrears(PaymentPurpose selectedPurpose) async {
    if (_isCheckingArrears) {
      return;
    }

    setState(() {
      _isCheckingArrears = true;
    });

    final termsBox = await Hive.openBox<Terms>('terms');
    final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

    List<String> overdueTerms = [];
    _arrearsDetails.clear(); // Clear previous arrears

    for (var term in termsBox.values) {
      // ✅ Step 1: Ensure the student is associated with the term
      if (!_selectedStudent!.terms!.contains(term.termId)) {
        continue; // Skip terms where the student is not enrolled
      }
      // Fetch all payment purposes for the current term
      final termPaymentPurposes =
          await _fetchPaymentPurposesByTerm(term.termId);

      // Check if the selected purpose exists in this term
      final matchingPurpose = termPaymentPurposes.firstWhere(
        (p) =>
            p.paymentPurpose.toLowerCase() ==
            selectedPurpose.paymentPurpose.toLowerCase(),
        orElse: () => PaymentPurpose(
          paymentPurpose: 'N/A',
          associatedClasses: [], // Ensure this is always initialized
          id: 0,
          purposeAmount: 0.0,
        ),
      );

      if (matchingPurpose.paymentPurpose != 'N/A') {
        // Check if student's class is associated with this payment purpose
        if (matchingPurpose.associatedClasses
                ?.contains(_selectedStudent!.class_) ??
            false) {
          // Summing up all payments safely
          double totalPaid = paymentBox.values
              .where((payment) =>
                  payment.studentName.toLowerCase() ==
                      _selectedStudent!.name.toLowerCase() &&
                  payment.studentSurname.toLowerCase() ==
                      _selectedStudent!.surname.toLowerCase() &&
                  payment.termId == term.termId &&
                  payment.paymentPurpose.toLowerCase() ==
                      selectedPurpose.paymentPurpose.toLowerCase())
              .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));

          // Determine if arrears exist
          double arrears = selectedPurpose.purposeAmount - totalPaid;
          if (arrears > 0) {
            overdueTerms.add(term.termId);

            _arrearsDetails[term.termId] =
                arrears; // Store term and arrears amount
          } else {}
        } else {}
      } else {}
    }

    if (overdueTerms.isNotEmpty) {
      setState(() {
        _arrearsTerms = overdueTerms;
      });
    } else {
      setState(() {
        _arrearsTerms = [];
      });
    }
    setState(() {
      _isCheckingArrears = false;
    });
  }

// Fetch payment purposes by termId
  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTerm(
      String termId) async {
    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    return paymentPurposeBox.values
        .where((purpose) => purpose.termId == termId)
        .toList();
  }

  @override
  void dispose() {
    bluetoothHelper.dispose(); // Properly dispose of BluetoothHelper

    _paymentAmountController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
