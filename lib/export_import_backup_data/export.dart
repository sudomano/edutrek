import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/payment_method_model.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/reprint_project_receipt.dart';
import 'package:zitf_system/database/projects/unitbatching.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ExportClassesPages extends StatefulWidget {
  @override
  _ExportClassesPagesState createState() => _ExportClassesPagesState();
}

class _ExportClassesPagesState extends State<ExportClassesPages> {
  int _selectedIndex = 0;
  bool _isExporting = false;

  // Add this StreamController declaration
  final StreamController<String> _exportProgress =
      StreamController<String>.broadcast();
  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use your navigation logic
  }

  Box<Classes>? _classesBox;
  Box<TeacherPaymentsPurposes>? _teacherPaymentsPurposesBox;
  Box<PaymentPurpose>? _paymentPurposesBox;
  Box<StudentPayment>? _studentPaymentsBox;
  Box<TeacherPayment>? _teacherPaymentsBox;
  Box<Student>? _studentsBox;
  Box<Withdrawal>? _withdrawalsBox;
  Box<Teachers>? _teachersBox;
  Box<School>? _schoolBox;
  Box<Terms>? _termsBox;

  Box<DomainRecord>? _domainRecordBox;
  Box<User>? _userBox;
  Box<Account>? _accountBox;
  Box<Asset>? _assetBox;
  Box<Project>? _projectBox;
  Box<ProjectItem>? _projectItemBox;
  Box<DailyActivity>? _dailyActivityBox;

  Box<BatchUnit>? _batchUnitBox;
  Box<ProductBatch>? _productBatchBox;
  Box<ProjectItemPrice>? _projectItemPriceBox;
  Box<ProjectSaleTransaction>? _projectSaleTransactionBox;
  Box<BatchSellUnit>? _batchSellUnitBox;
  Box<PaymentMethod>? _paymentMethodBox;
  Box<ReceiptSnapshot>? _receiptSnapshotBox;

  Box<ExceptionalStudents>? _exceptionalStudentsBox;
  Box<PaymentLog>? _paymentLogBox;

  @override
  void initState() {
    super.initState();
    _openHiveBoxes();
  }

  Future<void> _openHiveBoxes() async {
    try {
      _classesBox = await Hive.openBox<Classes>('classes');
      _teacherPaymentsPurposesBox = await Hive.openBox<TeacherPaymentsPurposes>(
          'teacher_payments_purposes');
      _paymentPurposesBox =
          await Hive.openBox<PaymentPurpose>('payment_purposes');
      _studentPaymentsBox =
          await Hive.openBox<StudentPayment>('student_payments');
      _teacherPaymentsBox =
          await Hive.openBox<TeacherPayment>('teacher_payments');
      _studentsBox = await Hive.openBox<Student>('students');
      _withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
      _teachersBox = await Hive.openBox<Teachers>('teachers');
      _schoolBox = await Hive.openBox<School>('school');
      _termsBox = await Hive.openBox<Terms>('terms');

      _domainRecordBox = await Hive.openBox<DomainRecord>('domainBox');
      _userBox = await Hive.openBox<User>('users'); // Open the box for users
      _accountBox = await Hive.openBox<Account>('account');
      _assetBox = await Hive.openBox<Asset>('asset');
      _projectBox = await Hive.openBox<Project>('projects');
      _projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
      _dailyActivityBox = await Hive.openBox<DailyActivity>('dailyActivities');

      _exceptionalStudentsBox =
          await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');

      _batchUnitBox = await Hive.openBox<BatchUnit>('batch_units');
      _productBatchBox = await Hive.openBox<ProductBatch>('product_batches');
      _projectItemPriceBox =
          await Hive.openBox<ProjectItemPrice>('project_item_prices');
      _projectSaleTransactionBox = await Hive.openBox<ProjectSaleTransaction>(
          'project_sale_transactions');
      _batchSellUnitBox = await Hive.openBox<BatchSellUnit>('batch_sell_units');
      _paymentMethodBox = await Hive.openBox<PaymentMethod>('payment_methods');
      _receiptSnapshotBox =
          await Hive.openBox<ReceiptSnapshot>('receipt_snapshots');
      _paymentLogBox = await Hive.openBox<PaymentLog>('payment_log');
    } catch (e) {
      print('Error opening Hive boxes: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error opening Hive boxes: $e'),
      ));
    }
  }

  // Classes Box
  Future<void> _serializeClassesBox(IOSink sink) async {
    if (_classesBox == null || _classesBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _classesBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_classToJson(values[i])));
      } catch (e) {
        print('Error serializing class item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

  // Teacher Payments Purposes Box
  Future<void> _serializePaymentLogBox(IOSink sink) async {
    if (_paymentLogBox == null || _paymentLogBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _paymentLogBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_paymentLogToJson(values[i])));
      } catch (e) {
        print('Error serializing payment log item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Teacher Payments Purposes Box
  Future<void> _serializeTeacherPaymentsPurposesBox(IOSink sink) async {
    if (_teacherPaymentsPurposesBox == null ||
        _teacherPaymentsPurposesBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _teacherPaymentsPurposesBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_teacherPaymentsPurposeToJson(values[i])));
      } catch (e) {
        print('Error serializing teacher payment purpose item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Payment Purposes Box
  Future<void> _serializePaymentPurposesBox(IOSink sink) async {
    if (_paymentPurposesBox == null || _paymentPurposesBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _paymentPurposesBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_paymentPurposeToJson(values[i])));
      } catch (e) {
        print('Error serializing payment purpose item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Student Payments Box
  Future<void> _serializeStudentPaymentsBox(IOSink sink) async {
    if (_studentPaymentsBox == null || _studentPaymentsBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _studentPaymentsBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_studentPaymentToJson(values[i])));
      } catch (e) {
        print('Error serializing student payment item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Teacher Payments Box
  Future<void> _serializeTeacherPaymentsBox(IOSink sink) async {
    if (_teacherPaymentsBox == null || _teacherPaymentsBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _teacherPaymentsBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_teacherPaymentclassToJson(values[i])));
      } catch (e) {
        print('Error serializing teacher payment item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Students Box
  Future<void> _serializeStudentsBox(IOSink sink) async {
    if (_studentsBox == null || _studentsBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _studentsBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_studentInfoToJson(values[i])));
      } catch (e) {
        print('Error serializing student item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Withdrawals Box
  Future<void> _serializeWithdrawalsBox(IOSink sink) async {
    if (_withdrawalsBox == null || _withdrawalsBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _withdrawalsBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_withdrawalToJson(values[i])));
      } catch (e) {
        print('Error serializing withdrawal item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Teachers Box
  Future<void> _serializeTeachersBox(IOSink sink) async {
    if (_teachersBox == null || _teachersBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _teachersBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_teacherToJson(values[i])));
      } catch (e) {
        print('Error serializing teacher item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// School Box
  Future<void> _serializeSchoolBox(IOSink sink) async {
    if (_schoolBox == null || _schoolBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _schoolBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_schoolToJson(values[i])));
      } catch (e) {
        print('Error serializing school item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Terms Box
  Future<void> _serializeTermsBox(IOSink sink) async {
    if (_termsBox == null || _termsBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _termsBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_termsToJson(values[i])));
      } catch (e) {
        print('Error serializing term item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Domains Box
  Future<void> _serializeDomainsBox(IOSink sink) async {
    if (_domainRecordBox == null || _domainRecordBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _domainRecordBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_domainsToJson(values[i])));
      } catch (e) {
        print('Error serializing domain item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Users Box
  Future<void> _serializeUsersBox(IOSink sink) async {
    if (_userBox == null || _userBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _userBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_usersToJson(values[i])));
      } catch (e) {
        print('Error serializing user item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Accounts Box
  Future<void> _serializeAccountsBox(IOSink sink) async {
    if (_accountBox == null || _accountBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _accountBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_accountsToJson(values[i])));
      } catch (e) {
        print('Error serializing account item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Assets Box
  Future<void> _serializeAssetsBox(IOSink sink) async {
    if (_assetBox == null || _assetBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _assetBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_assetsToJson(values[i])));
      } catch (e) {
        print('Error serializing asset item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Projects Box
  Future<void> _serializeProjectsBox(IOSink sink) async {
    if (_projectBox == null || _projectBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _projectBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_projectsToJson(values[i])));
      } catch (e) {
        print('Error serializing project item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Project Items Box
  Future<void> _serializeProjectItemsBox(IOSink sink) async {
    if (_projectItemBox == null || _projectItemBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _projectItemBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_projectItemsToJson(values[i])));
      } catch (e) {
        print('Error serializing project item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Daily Activities Box
  Future<void> _serializeDailyActivitiesBox(IOSink sink) async {
    if (_dailyActivityBox == null || _dailyActivityBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _dailyActivityBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_daily_activitiesToJson(values[i])));
      } catch (e) {
        print('Error serializing daily activity item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Exceptions Box
  Future<void> _serializeExceptionsBox(IOSink sink) async {
    if (_exceptionalStudentsBox == null || _exceptionalStudentsBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _exceptionalStudentsBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_exceptionsToJson(values[i])));
      } catch (e) {
        print('Error serializing exception item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Batch Units Box
  Future<void> _serializeBatchUnitsBox(IOSink sink) async {
    if (_batchUnitBox == null || _batchUnitBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _batchUnitBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_batchUnitToJson(values[i])));
      } catch (e) {
        print('Error serializing batch unit item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Product Batches Box
  Future<void> _serializeProductBatchesBox(IOSink sink) async {
    if (_productBatchBox == null || _productBatchBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _productBatchBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_productBatchToJson(values[i])));
      } catch (e) {
        print('Error serializing product batch item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Project Item Prices Box
  Future<void> _serializeProjectItemPricesBox(IOSink sink) async {
    if (_projectItemPriceBox == null || _projectItemPriceBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _projectItemPriceBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_projectItemPriceToJson(values[i])));
      } catch (e) {
        print('Error serializing project item price item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Project Sale Transactions Box
  Future<void> _serializeProjectSaleTransactionsBox(IOSink sink) async {
    if (_projectSaleTransactionBox == null ||
        _projectSaleTransactionBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _projectSaleTransactionBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_projectSaleTransactionToJson(values[i])));
      } catch (e) {
        print('Error serializing project sale transaction item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Batch Sell Units Box
  Future<void> _serializeBatchSellUnitsBox(IOSink sink) async {
    if (_batchSellUnitBox == null || _batchSellUnitBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _batchSellUnitBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_batchSellUnitToJson(values[i])));
      } catch (e) {
        print('Error serializing batch sell unit item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Payment Methods Box
  Future<void> _serializePaymentMethodsBox(IOSink sink) async {
    if (_paymentMethodBox == null || _paymentMethodBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _paymentMethodBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_paymentMethodToJson(values[i])));
      } catch (e) {
        print('Error serializing payment method item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

// Receipt Snapshots Box
  Future<void> _serializeReceiptSnapshotsBox(IOSink sink) async {
    if (_receiptSnapshotBox == null || _receiptSnapshotBox!.isEmpty) {
      sink.write('[]');
      return;
    }
    sink.write('[');
    final values = _receiptSnapshotBox!.values.toList();
    for (var i = 0; i < values.length; i++) {
      if (i > 0) sink.write(',');
      try {
        sink.write(jsonEncode(_receiptSnapshotToJson(values[i])));
      } catch (e) {
        print('Error serializing receipt snapshot item $i: $e');
        sink.write('null');
      }
      if ((i + 1) % 100 == 0) await Future.delayed(Duration.zero);
    }
    sink.write(']');
  }

  Future<void> exportHiveData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              StreamBuilder<String>(
                stream: _exportProgress.stream,
                builder: (context, snapshot) {
                  return Text(snapshot.data ?? 'Preparing export...');
                },
              ),
            ],
          ),
        ),
      );

      if (Platform.isAndroid) {
        await _saveToAndroidDirect();
      } else if (Platform.isWindows) {
        final tempFile = await _createTempFile();
        final IOSink sink = tempFile.openWrite();

        sink.write('{');

        // Classes
        _exportProgress.add('Exporting classes...');
        sink.write('"classes":');
        await _serializeClassesBox(sink);

        //  Payment Logs
        _exportProgress.add('Exporting teacher_payments_purposes...');
        sink.write(',"teacher_payments_purposes":');
        await _serializeTeacherPaymentsPurposesBox(sink);

        // Teacher Payments Purposes
        _exportProgress.add('Exporting payment_log...');
        sink.write(',"payment_log":');
        await _serializePaymentLogBox(sink);

        // Payment Purposes
        _exportProgress.add('Exporting payment_purposes...');
        sink.write(',"payment_purposes":');
        await _serializePaymentPurposesBox(sink);

        // Student Payments
        _exportProgress.add('Exporting student_payments...');
        sink.write(',"student_payments":');
        await _serializeStudentPaymentsBox(sink);

        // Teacher Payments
        _exportProgress.add('Exporting teacher_payments...');
        sink.write(',"teacher_payments":');
        await _serializeTeacherPaymentsBox(sink);

        // Students
        _exportProgress.add('Exporting students...');
        sink.write(',"students":');
        await _serializeStudentsBox(sink);

        // Withdrawals
        _exportProgress.add('Exporting withdrawals...');
        sink.write(',"withdrawals":');
        await _serializeWithdrawalsBox(sink);

        // Teachers
        _exportProgress.add('Exporting teachers...');
        sink.write(',"teachers":');
        await _serializeTeachersBox(sink);

        // School
        _exportProgress.add('Exporting school...');
        sink.write(',"school":');
        await _serializeSchoolBox(sink);

        // Terms
        _exportProgress.add('Exporting terms...');
        sink.write(',"terms":');
        await _serializeTermsBox(sink);

        // Domains
        _exportProgress.add('Exporting domains...');
        sink.write(',"domains":');
        await _serializeDomainsBox(sink);

        // Users
        _exportProgress.add('Exporting users...');
        sink.write(',"users":');
        await _serializeUsersBox(sink);

        // Accounts
        _exportProgress.add('Exporting accounts...');
        sink.write(',"accounts":');
        await _serializeAccountsBox(sink);

        // Assets
        _exportProgress.add('Exporting assets...');
        sink.write(',"assets":');
        await _serializeAssetsBox(sink);

        // Projects
        _exportProgress.add('Exporting projects...');
        sink.write(',"projects":');
        await _serializeProjectsBox(sink);

        // Project Items
        _exportProgress.add('Exporting project_items...');
        sink.write(',"project_items":');
        await _serializeProjectItemsBox(sink);

        // Daily Activities
        _exportProgress.add('Exporting daily_activities...');
        sink.write(',"daily_activities":');
        await _serializeDailyActivitiesBox(sink);

        // Exceptions
        _exportProgress.add('Exporting exceptions...');
        sink.write(',"exceptions":');
        await _serializeExceptionsBox(sink);

        // Batch Units
        _exportProgress.add('Exporting batch_units...');
        sink.write(',"batch_units":');
        await _serializeBatchUnitsBox(sink);

        // Product Batches
        _exportProgress.add('Exporting product_batches...');
        sink.write(',"product_batches":');
        await _serializeProductBatchesBox(sink);

        // Project Item Prices
        _exportProgress.add('Exporting project_item_prices...');
        sink.write(',"project_item_prices":');
        await _serializeProjectItemPricesBox(sink);

        // Project Sale Transactions
        _exportProgress.add('Exporting project_sale_transactions...');
        sink.write(',"project_sale_transactions":');
        await _serializeProjectSaleTransactionsBox(sink);

        // Batch Sell Units
        _exportProgress.add('Exporting batch_sell_units...');
        sink.write(',"batch_sell_units":');
        await _serializeBatchSellUnitsBox(sink);

        // Payment Methods
        _exportProgress.add('Exporting payment_methods...');
        sink.write(',"payment_methods":');
        await _serializePaymentMethodsBox(sink);

        // Receipt Snapshots
        _exportProgress.add('Exporting receipt_snapshots...');
        sink.write(',"receipt_snapshots":');
        await _serializeReceiptSnapshotsBox(sink);

        sink.write('}');
        await sink.flush();
        await sink.close();

        _exportProgress.add('Saving file...');
        await _saveToWindows(tempFile);

        // Delete temp file after saving
        await tempFile.delete();
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully!')),
        );
      }
    } catch (e) {
      print('Error exporting data: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _saveToAndroidDirect() async {
    try {
      // Create filename with timestamp
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final fileName =
          'hive_data_backup_${dateFormat.format(DateTime.now())}.json';

      // Save to Downloads folder - this works on Android 11+ without permission
      String downloadsPath = '/storage/emulated/0/Download';
      String savePath = '$downloadsPath/$fileName';

      // Ensure Downloads directory exists
      final Directory downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        // If Downloads doesn't exist, use app's external storage
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir == null) {
          throw Exception('Unable to access external storage');
        }
        String backupDirPath = '${externalDir.path}/backup';
        Directory backupDir = Directory(backupDirPath);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        savePath = '$backupDirPath/$fileName';
        print('Downloads folder not found, saving to: $savePath');
      }

      final File outputFile = File(savePath);

      // Write directly to the file with buffered writing for large files
      final IOSink sink = outputFile.openWrite(mode: FileMode.write);

      _exportProgress.add('Writing JSON data...');

      // Write JSON start
      sink.write('{');

      // Write all boxes directly to the file
      _exportProgress.add('Exporting classes...');
      sink.write('"classes":');
      await _serializeClassesBox(sink);

      _exportProgress.add('Exporting payment logs...');
      sink.write(',"payment_log":');
      await _serializePaymentLogBox(sink);

      _exportProgress.add('Exporting teacher payments purposes...');
      sink.write(',"teacher_payments_purposes":');
      await _serializeTeacherPaymentsPurposesBox(sink);

      _exportProgress.add('Exporting payment purposes...');
      sink.write(',"payment_purposes":');
      await _serializePaymentPurposesBox(sink);

      _exportProgress.add('Exporting student payments...');
      sink.write(',"student_payments":');
      await _serializeStudentPaymentsBox(sink);

      _exportProgress.add('Exporting teacher payments...');
      sink.write(',"teacher_payments":');
      await _serializeTeacherPaymentsBox(sink);

      _exportProgress.add('Exporting students...');
      sink.write(',"students":');
      await _serializeStudentsBox(sink);

      _exportProgress.add('Exporting withdrawals...');
      sink.write(',"withdrawals":');
      await _serializeWithdrawalsBox(sink);

      _exportProgress.add('Exporting teachers...');
      sink.write(',"teachers":');
      await _serializeTeachersBox(sink);

      _exportProgress.add('Exporting school...');
      sink.write(',"school":');
      await _serializeSchoolBox(sink);

      _exportProgress.add('Exporting terms...');
      sink.write(',"terms":');
      await _serializeTermsBox(sink);

      _exportProgress.add('Exporting domains...');
      sink.write(',"domains":');
      await _serializeDomainsBox(sink);

      _exportProgress.add('Exporting users...');
      sink.write(',"users":');
      await _serializeUsersBox(sink);

      _exportProgress.add('Exporting accounts...');
      sink.write(',"accounts":');
      await _serializeAccountsBox(sink);

      _exportProgress.add('Exporting assets...');
      sink.write(',"assets":');
      await _serializeAssetsBox(sink);

      _exportProgress.add('Exporting projects...');
      sink.write(',"projects":');
      await _serializeProjectsBox(sink);

      _exportProgress.add('Exporting project items...');
      sink.write(',"project_items":');
      await _serializeProjectItemsBox(sink);

      _exportProgress.add('Exporting daily activities...');
      sink.write(',"daily_activities":');
      await _serializeDailyActivitiesBox(sink);

      _exportProgress.add('Exporting exceptions...');
      sink.write(',"exceptions":');
      await _serializeExceptionsBox(sink);

      _exportProgress.add('Exporting batch units...');
      sink.write(',"batch_units":');
      await _serializeBatchUnitsBox(sink);

      _exportProgress.add('Exporting product batches...');
      sink.write(',"product_batches":');
      await _serializeProductBatchesBox(sink);

      _exportProgress.add('Exporting project item prices...');
      sink.write(',"project_item_prices":');
      await _serializeProjectItemPricesBox(sink);

      _exportProgress.add('Exporting project sale transactions...');
      sink.write(',"project_sale_transactions":');
      await _serializeProjectSaleTransactionsBox(sink);

      _exportProgress.add('Exporting batch sell units...');
      sink.write(',"batch_sell_units":');
      await _serializeBatchSellUnitsBox(sink);

      _exportProgress.add('Exporting payment methods...');
      sink.write(',"payment_methods":');
      await _serializePaymentMethodsBox(sink);

      _exportProgress.add('Exporting receipt snapshots...');
      sink.write(',"receipt_snapshots":');
      await _serializeReceiptSnapshotsBox(sink);

      sink.write('}');
      await sink.flush();
      await sink.close();

      // Verify file was created and has content
      final File savedFile = File(savePath);
      if (await savedFile.exists()) {
        final fileSize = await savedFile.length();
        final fileSizeInKB = (fileSize / 1024).toStringAsFixed(2);
        final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

        String sizeText = fileSizeInKB;
        if (fileSize > 1024 * 1024) {
          sizeText = '$fileSizeInMB MB';
        } else {
          sizeText = '$fileSizeInKB KB';
        }

        print('Backup saved successfully! File size: $sizeText at: $savePath');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✓ Backup saved to Downloads/$fileName ($sizeText)'),
            duration: const Duration(seconds: 5),
          ));
        }
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      print('Error saving backup to Android: $e');
      throw Exception('Failed to save backup: $e');
    }
  }

// Permission handling for Android
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 11+, we don't need storage permission for Downloads folder
      if (await _isAndroid11OrAbove()) {
        print('Android 11+: Using scoped storage, no permission needed');
        return true;
      }

      // For older Android versions, request permission
      bool permissionGranted = await Permission.storage.request().isGranted;
      if (!permissionGranted) {
        print('Storage permission denied');
        return false;
      }
    }
    return true;
  }

  Future<bool> _isAndroid11OrAbove() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 30; // Android 11 = API 30
    }
    return false;
  }

  Future<void> _saveToWindows(File sourceFile) async {
    String? selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Hive Data Backup',
      fileName: 'hive_data_backup_${DateTime.now().format()}.json',
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (selectedPath != null) {
      await sourceFile.copy(selectedPath);
      print('Backup saved to: $selectedPath');
    }
  }

// Helper methods
  Future<File> _createTempFile() async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${directory.path}/temp_export_$timestamp.json');
  }

  // Helper function to serialize data
  List<Map<String, dynamic>> _serializeBox<T>(
      Box<T>? box, Map<String, dynamic> Function(T) toJson) {
    print('Serializing box: ${box?.name ?? 'Unknown'}');
    return box?.values.map((data) => toJson(data as T)).toList() ?? [];
  }

// Convert PaymentLog to JSON
  /// Convert PaymentLog to JSON with ALL fields including sync fields
  Map<String, dynamic> _paymentLogToJson(PaymentLog log) => {
        // Core fields
        'receiptNumber': log.receiptNumber,
        'studentName': log.studentName,
        'className': log.className,
        'dateTime': log.dateTime,
        'receiptLines': log.receiptLines,
        'parentName': log.parentName,
        'parentPhone': log.parentPhone,

        // Reprint tracking fields
        'isReprint': log.isReprint ?? false,
        'originalReceiptNumber': log.originalReceiptNumber,
        'reprintCount': log.reprintCount ?? 0,

        // Sync fields
        'logId': log.logId,
        'syncStatus': log.syncStatus ?? false,
        'lastModified': log.lastModified?.toIso8601String(),
        'operationType': log.operationType ?? 'none',
        'modifiedFields': log.modifiedFields ?? [],

        // ✅ NEW DELETION FIELDS
        'isDeleted': log.isDeleted ?? false,
        'deletedAt': log.deletedAt?.toIso8601String(),
        'deletedBy': log.deletedBy,
        'deleteReason': log.deleteReason,
        'deletedSyncStatus': log.deletedSyncStatus ?? false,
      };

  Map<String, dynamic> _productBatchToJson(ProductBatch b) => {
        'batchCode': b.batchCode,
        'productCode': b.productCode,
        'reference': b.reference,
        'baseUnitType': b.baseUnitType?.name,
        'baseUnit': b.baseUnit,
        'baseUnitSize': b.baseUnitSize,
        'totalBaseUnits': b.totalBaseUnits,
        'remainingBaseUnits': b.remainingBaseUnits,
        'totalBuyingCost': b.totalBuyingCost,
        'purchaseDate': b.purchaseDate?.toIso8601String(),
        'createdAt': b.createdAt?.toIso8601String(),
        'syncStatus': b.syncStatus,
        'lastModified': b.lastModified?.toIso8601String(),
        'operationType': b.operationType,
        'units': b.units?.map((u) => _batchUnitToJson(u)).toList(),
        //'modifiedFields': b.modifiedFields,
      };

  Map<String, dynamic> _batchUnitToJson(BatchUnit u) => {
        'level': u.level.name,
        'unitsPerPackage': u.unitsPerPackage,
        'quantity': u.quantity,
        'buyingPrice': u.buyingPrice,
        'unitBatchCode': u.unitBatchCode,
      };

  Map<String, dynamic> _projectItemPriceToJson(ProjectItemPrice p) => {
        'priceCode': p.priceCode,
        'projectItemCode': p.projectItemCode,
        'amount': p.amount,
        'pricingType': p.pricingType,
        'appliesTo': p.appliesTo,
        'effectiveFrom': p.effectiveFrom.toIso8601String(),
        'effectiveTo': p.effectiveTo?.toIso8601String(),
        'syncStatus': p.syncStatus,
        'lastModified': p.lastModified?.toIso8601String(),
        'operationType': p.operationType,
        //'modifiedFields': p.modifiedFields,
      };
  Map<String, dynamic> _projectSaleTransactionToJson(
          ProjectSaleTransaction t) =>
      {
        'transactionCode': t.transactionCode,
        'studentId': t.studentId,
        'projectCode': t.projectCode,
        'projectItemCode': t.projectItemCode,
        'batchCode': t.batchCode,
        'sellUnitCode': t.sellUnitCode,
        'sellUnitNameSnapshot': t.sellUnitNameSnapshot,
        'quantitySold': t.quantitySold,
        'unitSellingPrice': t.unitSellingPrice,
        'totalAmount': t.totalAmount,
        'baseUnitsPerSellUnit': t.baseUnitsPerSellUnit,
        'totalBaseUnitsSold': t.totalBaseUnitsSold,
        'baseUnit': t.baseUnit,
        'baseUnitType': t.baseUnitType.name,
        'transactionDate': t.transactionDate.toIso8601String(),
        'paymentMethod': t.paymentMethod,
        'reference': t.reference,
        'amountPaid': t.amountPaid,
        'arrears': t.arrears,

        // 🔴 Soft delete
        'isDeleted': t.isDeleted,
        'deletedAt': t.deletedAt?.map((e) => e.toIso8601String()).toList(),
        'restoredAt': t.restoredAt?.map((e) => e.toIso8601String()).toList(),
        'deletedByUsers': t.deletedByUsers,
        'restoredByUsers': t.restoredByUsers,

        // 💳 Payment breakdown
        'paymentMethodCode': t.paymentMethodCode,
        'methodType': t.methodType,
        'amountPaidInPaymentMethod': t.amountPaidInPaymentMethod,
        'currency': t.currency,
        'provider': t.provider,
        'referenceNumber': t.referenceNumber,
        'phoneNumber': t.phoneNumber,
        'accountNumber': t.accountNumber,
        'accountName': t.accountName,
        'paymentDatetransacted': t.paymentDatetransacted?.toIso8601String(),

        // 🔁 Audit
        'isReversed': t.isReversed,
        'lineTransactionCodes': t.lineTransactionCodes,
        'financialType': t.financialType,
        'parentTransactionCode': t.parentTransactionCode,
        'affectsStock': t.affectsStock,
        'createsObligation': t.createsObligation,
        'settlesObligation': t.settlesObligation,

        // Sync
        'syncStatus': t.syncStatus,
        'lastModified': t.lastModified?.toIso8601String(),
        'operationType': t.operationType,
        //'modifiedFields': t.modifiedFields,
      };

  Map<String, dynamic> _batchSellUnitToJson(BatchSellUnit u) {
    return {
      "sell_unit_code": u.sellUnitCode,
      "batch_code": u.batchCode,
      "unit_name": u.unitName,
      "quantity_multiplier": u.quantityMultiplier,
      "selling_price": u.sellingPrice,
      "active": u.active,
      "deleted_at": u.deletedAt?.toIso8601String(),
      "last_modified": u.lastModified?.toIso8601String(),
      "operation_type": u.operationType,
      "modified_fields": u.modifiedFields,
      "packaging_level": u.packagingLevel?.name,
      "base_units_per_sell_unit": u.baseUnitsPerSellUnit,
      "base_unit": u.baseUnit,
      "base_unit_type": u.baseUnitType?.name,
    };
  }

  Map<String, dynamic> _paymentMethodToJson(PaymentMethod paymentMethod) {
    return {
      "payment_method_code": paymentMethod.paymentMethodCode,
      "method_type": paymentMethod.methodType,
      "amount": paymentMethod.amount,
      "currency": paymentMethod.currency,
      "provider": paymentMethod.provider,
      "reference": paymentMethod.reference,
      "phone_number": paymentMethod.phoneNumber,
      "account_number": paymentMethod.accountNumber,
      "account_name": paymentMethod.accountName,
      "payment_date": paymentMethod.paymentDate?.toIso8601String(),
      "is_reversed": paymentMethod.isReversed,
      "last_modified": paymentMethod.lastModified?.toIso8601String(),
      "operation_type": paymentMethod.operationType,
    };
  }

  Map<String, dynamic> _receiptSnapshotToJson(ReceiptSnapshot snapshot) {
    return {
      "receipt_code": snapshot.receiptCode,
      "receipt_date": snapshot.receiptDate.toIso8601String(),
      "cashier": snapshot.cashier,
      "total_expected": snapshot.totalExpected,
      "total_paid": snapshot.totalPaid,
      "amount_received": snapshot.amountReceived,
      "change_amount": snapshot.change,
      "currency": snapshot.currency,
      "receipt_lines": snapshot.receiptLinesJson,
      "is_reprint": snapshot.isReprint,
      "student_name": snapshot.studentName,
      "student_class": snapshot.studentClass,
    };
  }

// JSON Serialization method for ExceptionalStudents

  Map<String, dynamic> _exceptionsToJson(ExceptionalStudents exc) {
    return {
      'id': exc.id,
      'exceptionId': exc.exceptionId,
      'exceptionName': exc.exceptionName,
      'exceptionStatus': exc.exceptionStatus,
      'exceptionType': exc.exceptionType,
      'exceptionFigure': exc.exceptionFigure,
      'syncStatus': exc.syncStatus,
      'lastModified': exc.lastModified?.toIso8601String(),
      'operationType': exc.operationType,
      'priorityFlag': exc.priorityFlag ?? 0,
      'terms': exc.terms,
      // ✅ NEW DELETION FIELDS
      'isDeleted': exc.isDeleted ?? false,
      'deletedAt': exc.deletedAt?.toIso8601String(),
      'deletedBy': exc.deletedBy,
      'deleteReason': exc.deleteReason,
      'deletedSyncStatus': exc.deletedSyncStatus ?? false,
    };
  }

  // JSON Serialization methods
  Map<String, dynamic> _classToJson(Classes cls) {
    return {
      'id': cls.id,
      'className': cls.className,
      'classCode': cls.classCode,
      'date': cls.date.toIso8601String(),
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
          : null, //'modifiedFields': cls.modifiedFields,
      // ✅ NEW DELETION FIELDS
      'isDeleted': cls.isDeleted ?? false,
      'deletedAt': cls.deletedAt?.toIso8601String(),
      'deletedBy': cls.deletedBy,
      'deleteReason': cls.deleteReason,
      'deletedSyncStatus': cls.deletedSyncStatus ?? false,
    };
  }

  Map<String, dynamic> _schoolToJson(School cls) {
    return {
      'id': cls.id,
      'schoolName': cls.schoolName,
      'schoolCode': cls.schoolCode,
      'schoolAddress': cls.schoolAddress,
      'schoolPhoneNumber': cls.schoolPhoneNumber,
      'schoolEmail': cls.schoolEmail,
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'modifiedFields': cls.modifiedFields,
      // ✅ NEW DELETION FIELDS
      'isDeleted': cls.isDeleted ?? false,
      'deletedAt': cls.deletedAt?.toIso8601String(),
      'deletedBy': cls.deletedBy,
      'deleteReason': cls.deleteReason,
      'deletedSyncStatus': cls.deletedSyncStatus ?? false,
    };
  }

  Map<String, dynamic> _studentInfoToJson(Student cls) {
    return {
      'id': cls.id,
      'name': cls.name,
      'surname': cls.surname,
      'class': cls.class_,
      'gender': cls.gender,
      'age': cls.age.toIso8601String(),
      'nationality': cls.nationality,
      'district': cls.district,
      'nationalIdNumber': cls.nationalIdNumber,
      'studentIdNumber': cls.studentIdNumber,
      'regNumber': cls.regNumber,
      'physicalAddress': cls.physicalAddress,
      'paymentStatus': cls.paymentStatus,
      'phoneNumber': cls.phoneNumber,
      'religion': cls.religion,
      'denomination': cls.denomination,
      'formerSchool': cls.formerSchool,
      'previousSchoolPerformanceResults': cls.previousSchoolPerformanceResults,
      'emergencyContactName': cls.emergencyContactName,
      'emergencyContactNumber': cls.emergencyContactNumber,
      'enrollmentStatus': cls.enrollmentStatus,
      'isPresent': cls.isPresent,
      'presentDates': cls.presentDates
          .map((date) => date.toIso8601String())
          .toList(), // Convert each DateTime to ISO 8601 string
      'absentDates': cls.absentDates
          .map((date) => date.toIso8601String())
          .toList(), // Convert each DateTime to ISO 8601 string
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'terms': cls.terms,
      'exceptions': cls.exceptions != null
          ? jsonEncode(
              cls.exceptions!.map((e) => _exceptionsToJson(e)).toList())
          : null,
      'isNewComer': cls.isNewComer,
      'isNewComerFrom': cls.isNewComerFrom?.toIso8601String(),
      'isNewComerUntil': cls.isNewComerUntil?.toIso8601String(),
      //'modifiedFields': cls.modifiedFields,
      // ✅ NEW DELETION FIELDS
      'isDeleted': cls.isDeleted ?? false,
      'deletedAt': cls.deletedAt?.toIso8601String(),
      'deletedBy': cls.deletedBy,
      'deleteReason': cls.deleteReason,
      'deletedSyncStatus': cls.deletedSyncStatus ?? false,
    };
  }

  Map<String, dynamic> _studentPaymentToJson(StudentPayment cls) {
    return {
      'id': cls.id,
      'studentName': cls.studentName,
      'studentSurname': cls.studentSurname,
      'studentClass': cls.studentClass,
      'phoneNumber': cls.phoneNumber,
      'paymentPurpose': cls.paymentPurpose,
      'amountToPay': cls.amountToPay,
      'paymentDate': cls.paymentDate.toIso8601String(),
      'termId': cls.termId,
      'receiptNumber': cls.receiptNumber,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'username': cls.username,
      'role': cls.role,

      // ✅ Payment method fields
      'paymentMethodType': cls.paymentMethodType,
      'paymentMethodAmount': cls.paymentMethodAmount,
      'paymentReference': cls.paymentReference,
      'mobileMoneyProvider': cls.mobileMoneyProvider,
      'bankAccountNumber': cls.bankAccountNumber,
      'bankAccountName': cls.bankAccountName,
      'changeGiven': cls.changeGiven,

      // ✅ NEW DELETION FIELDS
      'isDeleted': cls.isDeleted ?? false,
      'deletedAt': cls.deletedAt?.toIso8601String(),
      'deletedBy': cls.deletedBy,
      'deleteReason': cls.deleteReason,
      'deletedSyncStatus': cls.deletedSyncStatus ?? false,

      // 'modifiedFields': cls.modifiedFields,
    };
  }

  Map<String, dynamic> _teacherPaymentclassToJson(TeacherPayment cls) {
    return {
      'id': cls.id,
      'studentName': cls.studentName,
      'studentSurname': cls.studentSurname,
      'studentClass': cls.studentClass,
      'phoneNumber': cls.phoneNumber,
      'paymentPurpose': cls.paymentPurpose,
      'amountToPay': cls.amountToPay,
      'paymentDate': cls.paymentDate.toIso8601String(),
      'termId': cls.termId,
      'receiptNumber': cls.receiptNumber,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      //'modifiedFields': cls.modifiedFields,
    };
  }

  Map<String, dynamic> _paymentPurposeToJson(PaymentPurpose cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'associatedClasses':
          jsonEncode(cls.associatedClasses), // Convert list to JSON
      'purposeCode': cls.purposeCode,
      'exceptions': cls.exceptions != null
          ? jsonEncode(
              cls.exceptions!.map((e) => _exceptionsToJson(e)).toList())
          : null,
      'forNewcomersOnly': cls.forNewcomersOnly,
      //'modifiedFields': cls.modifiedFields,

      // ✅ NEW DELETION FIELDS
      'isDeleted': cls.isDeleted ?? false,
      'deletedAt': cls.deletedAt?.toIso8601String(),
      'deletedBy': cls.deletedBy,
      'deleteReason': cls.deleteReason,
      'deletedSyncStatus': cls.deletedSyncStatus ?? false,
    };
  }

  Map<String, dynamic> _teacherPaymentsPurposeToJson(
      TeacherPaymentsPurposes cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
      'purposeCode': cls.purposeCode,
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'associatedStaff': cls.associatedStaff != null
          ? jsonEncode(
              cls.associatedStaff) // Explicit JSON encode for associatedStaff
          : null,
      //'modifiedFields': cls.modifiedFields,
    };
  }

  Map<String, dynamic> _teacherToJson(Teachers cls) {
    return {
      'id': cls.id,
      'name': cls.name,
      'surname': cls.surname,
      'IdNumber': cls.IdNumber,
      'assignedClass': cls.assignedClass,
      'gender': cls.gender,
      'dateOfBirth': cls.dateOfBirth.toIso8601String(),
      'phoneNumber': cls.phoneNumber,
      'paymentPurpose': cls.paymentPurpose,
      'isPaid': cls.isPaid,
      'paymentAmount': cls.paymentAmount,
      'paymentDate': cls.paymentDate?.toIso8601String(),
      'email': cls.email,
      'address': cls.address,
      'hireDate': cls.hireDate.toIso8601String(),
      'qualifications': cls.qualifications,
      'employmentStatus': cls.employmentStatus,
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'assignedClasses': cls.assignedClasses != null
          ? jsonEncode(cls.assignedClasses) // JSON encode the list
          : null,
      'terms': cls.terms,
      //'modifiedFields': cls.modifiedFields,
    };
  }

  Map<String, dynamic> _termsToJson(Terms cls) {
    return {
      'id': cls.id,
      'termId': cls.termId,
      'termName': cls.termName,
      'startDate': cls.startDate.toIso8601String(),
      'endDate': cls.endDate?.toIso8601String(),
      'isActive': cls.isActive,
      'status': cls.status,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      //'modifiedFields': cls.modifiedFields,
      // ✅ NEW DELETION FIELDS
      'isDeleted': cls.isDeleted ?? false,
      'deletedAt': cls.deletedAt?.toIso8601String(),
      'deletedBy': cls.deletedBy,
      'deleteReason': cls.deleteReason,
      'deletedSyncStatus': cls.deletedSyncStatus ?? false,
    };
  }

  Map<String, dynamic> _withdrawalToJson(Withdrawal cls) {
    return {
      'id': cls.id,
      'amount': cls.amount,
      'withdrawalPurpose': cls.withdrawalPurpose,
      'withdrawalCode': cls.withdrawalCode,
      'termId': cls.termId,
      'date': cls.date.toIso8601String(),
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      //'modifiedFields': cls.modifiedFields,
    };
  }

  Map<String, dynamic> _domainsToJson(DomainRecord domain) => {
        'domainName': domain.domainName,
        'areDomainsActive': domain.areDomainsActive,
        'syncStatus': domain.syncStatus,
        'operationType': domain.operationType,
        'lastModified': domain.lastModified?.toIso8601String(),
        //'modifiedFields': domain.modifiedFields,
      };
  Map<String, dynamic> _usersToJson(User user) => {
        'username': user.username,
        'password': user.password,
        'role': user.role,
        'securityQuestions': user.securityQuestions,
        'securityAnswers': user.securityAnswers,
        'phone': user.phone,
        'termId': user.termId,
        'syncStatus': user.syncStatus,
        'lastModified': user.lastModified?.toIso8601String(),
        'operationType': user.operationType,
        'id': user.id,
        'isLogged': user.isLogged,
        'userCode': user.userCode,
        'email': user.email,
        'assignedClasses': user.assignedClasses ?? [],
        'isActive': user.isActive ?? true,
        'createdAt': user.createdAt?.toIso8601String(),
        'modifiedFields': user.modifiedFields,
        'isDeleted': user.isDeleted ?? false,
        'deletedAt': user.deletedAt?.toIso8601String(),
        'deletedBy': user.deletedBy,
        'deleteReason': user.deleteReason,
        'deletedSyncStatus': user.deletedSyncStatus ?? false,
      };

  Map<String, dynamic> _accountsToJson(Account acc) => {
        'id': acc.id,
        'accountType': acc.accountType,
        'accountSubType': acc.accountSubType,
        'accountName': acc.accountName,
        'accountCode': acc.accountCode,
        'operationType': acc.operationType,
        'syncStatus': acc.syncStatus,
        'lastModified': acc.lastModified?.toIso8601String(),
        'isALiquidAccount': acc.isALiquidAccount,
        //'modifiedFields': acc.modifiedFields,
      };

  Map<String, dynamic> _assetsToJson(Asset asset) {
    return {
      'id': asset.id,
      'assetName': asset.assetName,
      'assetType': asset.assetType,
      'assetSubType': asset.assetSubType,
      'assetCode': asset.assetCode,
      'assetSerialNo': asset.assetSerialNo,
      'acquisitionDate': asset.acquisitionDate?.toIso8601String(),
      'acquisitionCost': asset.acquisitionCost,
      'acquisitionMethod': asset.acquisitionMethod,
      'department': asset.department,
      'location': asset.location,
      'depreciationRate': asset.depreciationRate,
      'depreciationMethod': asset.depreciationMethod,
      'lastDepreciationDate': asset.lastDepreciationDate?.toIso8601String(),
      'accumulatedDepreciation': asset.accumulatedDepreciation,
      'bookValue': asset.bookValue,
      'isImpaired': asset.isImpaired,
      'impairmentLoss': asset.impairmentLoss,
      'revaluationDate': asset.revaluationDate?.toIso8601String(),
      'revaluationAmount': asset.revaluationAmount,
      'lastMaintenanceDate': asset.lastMaintenanceDate?.toIso8601String(),
      'maintenanceCost': asset.maintenanceCost,
      'maintenanceDescription': asset.maintenanceDescription,
      'capitalImprovementCost': asset.capitalImprovementCost,
      'capitalImprovementDescription': asset.capitalImprovementDescription,
      'disposalDate': asset.disposalDate?.toIso8601String(),
      'disposalProceeds': asset.disposalProceeds,
      'disposalReason': asset.disposalReason,
      'gainOrLossOnDisposal': asset.gainOrLossOnDisposal,
      'isLeased': asset.isLeased,
      'leaseType': asset.leaseType,
      'leaseStartDate': asset.leaseStartDate?.toIso8601String(),
      'leaseEndDate': asset.leaseEndDate?.toIso8601String(),
      'leasePaymentAmount': asset.leasePaymentAmount,
      'lastAuditDate': asset.lastAuditDate?.toIso8601String(),
      'syncStatus': asset.syncStatus,
      'notes': asset.notes,
      'createdAt': asset.createdAt?.toIso8601String(),
      'lastModified': asset.lastModified?.toIso8601String(),
      'operationType': asset.operationType,
      'usefulLife': asset.usefulLife,
      'hasDebitBalance': asset.hasDebitBalance,
      'hasCreditBalance': asset.hasCreditBalance,
      'option': asset.option,
      //'modifiedFields': asset.modifiedFields,
    };
  }

  Map<String, dynamic> _projectsToJson(Project p) => {
        'projectCode': p.projectCode,
        'name': p.name,
        'description': p.description,
        'status': p.status,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
        'syncStatus': p.syncStatus,
        'lastModified': p.lastModified?.toIso8601String(),
        'operationType': p.operationType,
        //'modifiedFields': p.modifiedFields,
        'projectType': p.projectType,
        'participationType': p.participationType,
        'studentPayable': p.studentPayable,
      };
  Map<String, dynamic> _projectItemsToJson(ProjectItem i) => {
        'projectItemCode': i.projectItemCode,
        'projectCode': i.projectCode,
        'name': i.name,

        // ✅ NEW FIELDS
        'itemType': i.itemType,
        'active': i.active,
        'trackStock': i.trackStock,

        'syncStatus': i.syncStatus,
        'lastModified': i.lastModified?.toIso8601String(),
        'operationType': i.operationType,
        //'modifiedFields': i.modifiedFields,
      };

  Map<String, dynamic> _daily_activitiesToJson(DailyActivity a) => {
        'projectDailyActiviyCode': a.projectDailyActiviyCode,
        'projectCode': a.projectCode,
        'date': a.date.toIso8601String(),
        'type': a.type,
        'description': a.description,
        'amount': a.amount,
        'syncStatus': a.syncStatus,
        'lastModified': a.lastModified?.toIso8601String(),
        'operationType': a.operationType,
        //'modifiedFields': a.modifiedFields,
      };

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Export Records'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 15,
            ),
            buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
            const SizedBox(
              height: 10,
            ),
            Text(
              'Local Data Backup',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.normal,
                color: const Color.fromARGB(255, 0, 0, 0), // Black text color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 40,
            ),
            Center(
              child: ElevatedButton(
                onPressed: _isExporting
                    ? null
                    : () async {
                        print('Export button clicked.');
                        await exportHiveData();
                        // The success SnackBar is already handled in exportHiveData
                      },
                child: _isExporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Text('Export All Database Records'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Extension for date formatting
extension DateTimeFormat on DateTime {
  String format() {
    return '${year}_${month.toString().padLeft(2, '0')}_${day.toString().padLeft(2, '0')}_${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}${second.toString().padLeft(2, '0')}';
  }
}

class BoxExportInfo<T> {
  final String name;
  final Box<T>? box;
  final Map<String, dynamic> Function(T) toJson;

  BoxExportInfo({
    required this.name,
    required this.box,
    required this.toJson,
  });
}
