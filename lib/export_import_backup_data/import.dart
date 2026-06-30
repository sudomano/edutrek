import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart'; // Import the file_picker package
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/packaging_level.dart';
import 'package:zitf_system/database/projects/payment_method_model.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/reprint_project_receipt.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';
import 'package:zitf_system/database/projects/unitbatching.dart';
//import 'package:zitf_system/database/projects/project_student_payment_model.dart';
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
import 'package:zitf_system/reusable_codes/serializers/utilities/parse_string_list.dart';

class ImportClassesPages extends StatefulWidget {
  @override
  _ImportClassesPagesState createState() => _ImportClassesPagesState();
}

class _ImportClassesPagesState extends State<ImportClassesPages> {
  int _selectedIndex = 0;
// Add progress stream controller for import progress
  final StreamController<String> _importProgress =
      StreamController<String>.broadcast();
  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
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
  //Box<ProjectStudentPayment>? _projectStudentPaymentBox;
  Box<ExceptionalStudents>? _exceptionalStudentsBox;

  Box<BatchUnit>? _batchUnitBox;
  Box<ProductBatch>? _productBatchBox;
  Box<ProjectItemPrice>? _projectItemPriceBox;
  Box<ProjectSaleTransaction>? _projectSaleTransactionBox;
  Box<BatchSellUnit>? _batchSellUnitBox;
  Box<PaymentMethod>? _paymentMethodBox;
  Box<ReceiptSnapshot>? _receiptSnapshotBox;
  Box<PaymentLog>? _paymentLogBox;

  bool _isImporting = false; // To track import status

  @override
  void initState() {
    super.initState();
    _openHiveBoxes();
  }

  Future<void> _openHiveBoxes() async {
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
    // _projectStudentPaymentBox =
    //   await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
    _exceptionalStudentsBox =
        await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
    _batchUnitBox = await Hive.openBox<BatchUnit>('batch_units');
    _productBatchBox = await Hive.openBox<ProductBatch>('product_batches');
    _projectItemPriceBox =
        await Hive.openBox<ProjectItemPrice>('project_item_prices');
    _projectSaleTransactionBox =
        await Hive.openBox<ProjectSaleTransaction>('project_sale_transactions');
    _batchSellUnitBox = await Hive.openBox<BatchSellUnit>('batch_sell_units');
    _paymentMethodBox = await Hive.openBox<PaymentMethod>('payment_methods');
    _receiptSnapshotBox =
        await Hive.openBox<ReceiptSnapshot>('receipt_snapshots');
    _paymentLogBox = await Hive.openBox<PaymentLog>('payment_log');
  }

  Future<void> importHiveData() async {
    setState(() {
      _isImporting = true; // Set importing status
    });

    try {
      // Pick a JSON file
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null) {
        String filePath = result.files.single.path!;
        String jsonData;
        _importProgress.add('Reading JSON file...');
        jsonData = await File(filePath).readAsString();
        Map<String, dynamic> importData = jsonDecode(jsonData);

        // Clear existing data (optional)

        _importProgress.add('Clearing existing data...');

        // Clear existing data (optional - ask user first)
        bool? shouldClear = await _showClearDataDialog();
        if (shouldClear == true) {
          await _clearHiveData();
          _importProgress.add('Existing data cleared.');
        } else if (shouldClear == null) {
          // User cancelled
          if (mounted) Navigator.pop(context);
          return;
        }

        _importProgress.add('Importing data...');

        // Deserialize and save data
        await _deserializeAndSave(
            importData['classes'], _classFromJson, _classesBox);
        await _deserializeAndSave(importData['teacher_payments_purposes'],
            _teacherPaymentsPurposeFromJson, _teacherPaymentsPurposesBox);
        await _deserializeAndSave(importData['payment_purposes'],
            _paymentPurposeFromJson, _paymentPurposesBox);
        await _deserializeAndSave(importData['student_payments'],
            _studentPaymentFromJson, _studentPaymentsBox);
        await _deserializeAndSave(importData['teacher_payments'],
            _teacherPaymentFromJson, _teacherPaymentsBox);
        await _deserializeAndSave(
            importData['students'], _studentInfoFromJson, _studentsBox);
        await _deserializeAndSave(
            importData['withdrawals'], _withdrawalFromJson, _withdrawalsBox);
        await _deserializeAndSave(
            importData['teachers'], _teacherFromJson, _teachersBox);
        await _deserializeAndSave(
            importData['school'], _schoolFromJson, _schoolBox);
        await _deserializeAndSave(
            importData['terms'], _termsFromJson, _termsBox);

        await _deserializeAndSave(
            importData['domains'], _domainsFromJson, _domainRecordBox);
        await _deserializeAndSave(
            importData['users'], _usersFromJson, _userBox);
        await _deserializeAndSave(
            importData['accounts'], _accountsFromJson, _accountBox);
        await _deserializeAndSave(
            importData['assets'], _assetsFromJson, _assetBox);
        await _deserializeAndSave(
            importData['projects'], _projectsFromJson, _projectBox);
        await _deserializeAndSave(importData['project_items'],
            _projectItemsFromJson, _projectItemBox);
        await _deserializeAndSave(importData['daily_activities'],
            _daily_activitiesFromJson, _dailyActivityBox);

        await _deserializeAndSave(importData['exceptions'], _exceptionsFromJson,
            _exceptionalStudentsBox);

        await _deserializeAndSave(
            importData['batch_units'], _batchUnitFromJson, _batchUnitBox);
        await _deserializeAndSave(importData['product_batches'],
            _productBatchFromJson, _productBatchBox);
        await _deserializeAndSave(importData['project_item_prices'],
            _projectItemPriceFromJson, _projectItemPriceBox);
        await _deserializeAndSave(importData['project_sale_transactions'],
            _projectSaleTransactionFromJson, _projectSaleTransactionBox);
        await _deserializeAndSave(importData['batch_sell_units'],
            _batchSellUnitFromJson, _batchSellUnitBox);
        await _deserializeAndSave(importData['payment_methods'],
            _paymentMethodFromJson, _paymentMethodBox);
        await _deserializeAndSave(importData['receipt_snapshots'],
            _receiptSnapshotFromJson, _receiptSnapshotBox);
        await _deserializeAndSave(
            importData['payment_log'], _paymentLogFromJson, _paymentLogBox);

        _importProgress.add('Import completed successfully!');

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data imported successfully.'),
          backgroundColor: Colors.green,
        ));
      } else {
        print('File selection canceled.');
      }
    } catch (e, stackTrace) {
      debugPrint('Error importing data: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isImporting = false; // Reset importing status
      });
    }
  }

  // Show dialog to ask if user wants to clear existing data
  Future<bool?> _showClearDataDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Clear Existing Data?'),
        content: const Text(
          'Do you want to clear all existing data before importing?\n\n'
          '• Yes: Clear existing data and import new data\n'
          '• No: Merge with existing data (may cause duplicates)\n'
          '• Cancel: Cancel import',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes (Clear All)'),
          ),
        ],
      ),
    );
  }

// Update the build method to show progress dialog during import
  Future<void> _importWithProgress() async {
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
              stream: _importProgress.stream,
              builder: (context, snapshot) {
                return Text(snapshot.data ?? 'Preparing import...');
              },
            ),
          ],
        ),
      ),
    );

    await importHiveData();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _clearHiveData() async {
    await _classesBox?.clear();
    await _teacherPaymentsPurposesBox?.clear();
    await _paymentPurposesBox?.clear();
    await _studentPaymentsBox?.clear();
    await _teacherPaymentsBox?.clear();
    await _studentsBox?.clear();
    await _withdrawalsBox?.clear();
    await _teachersBox?.clear();
    await _schoolBox?.clear();
    await _termsBox?.clear();
    await _domainRecordBox?.clear();
    await _userBox?.clear();
    await _accountBox?.clear();
    await _assetBox?.clear();
    await _projectBox?.clear();
    await _projectItemBox?.clear();
    await _dailyActivityBox?.clear();
    await _exceptionalStudentsBox?.clear();
    await _batchUnitBox?.clear();
    await _productBatchBox?.clear();
    await _projectItemPriceBox?.clear();
    await _projectSaleTransactionBox?.clear();
    await _batchSellUnitBox?.clear();
    await _paymentMethodBox?.clear();
    await _receiptSnapshotBox?.clear();
    await _paymentLogBox?.clear();
  }

  Future<void> _deserializeAndSave<T>(List<dynamic>? data,
      T Function(Map<String, dynamic>) fromJson, Box<T>? box) async {
    if (data != null) {
      for (var item in data) {
        T obj = fromJson(item);
        await box?.add(obj);
      }
    }
  }

  // Helper function to decode string to List<String>
  List<String> _decodeToList(dynamic value) {
    if (value is String) {
      // If it's a string, try to decode it as JSON
      try {
        return List<String>.from(jsonDecode(value));
      } catch (e) {
        print('Error decoding string to List: $e');
        return [];
      }
    } else if (value is List) {
      // If it's already a list, return it directly
      return List<String>.from(value);
    }
    return [];
  }

// Create PaymentLog from JSON
  /// Convert JSON to PaymentLog with ALL fields including sync fields
  PaymentLog _paymentLogFromJson(Map<String, dynamic> json) => PaymentLog(
        // Core fields
        receiptNumber: json['receiptNumber'] as int? ?? 0,
        studentName: json['studentName'] as String? ?? '',
        className: json['className'] as String? ?? '',
        dateTime:
            json['dateTime'] as String? ?? DateTime.now().toIso8601String(),
        receiptLines: (json['receiptLines'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        parentName: json['parentName'] as String?,
        parentPhone: json['parentPhone'] as String?,

        // ✅ Reprint tracking fields
        isReprint: json['isReprint'] as bool? ?? false,
        originalReceiptNumber: json['originalReceiptNumber'] as String?,
        reprintCount: json['reprintCount'] as int? ?? 0,

        // ✅ Sync fields
        logId: json['logId'] as String?,
        syncStatus: json['syncStatus'] as bool? ?? false,
        lastModified: json['lastModified'] != null
            ? DateTime.tryParse(json['lastModified'] as String)
            : null,
        operationType: json['operationType'] as String? ?? 'none',
        modifiedFields: (json['modifiedFields'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  ProductBatch _productBatchFromJson(Map<String, dynamic> json) => ProductBatch(
        batchCode: json['batchCode'],
        productCode: json['productCode'],
        reference: json['reference'],
        baseUnitType: json['baseUnitType'] != null
            ? StockUnitType.values
                .firstWhere((e) => e.name == json['baseUnitType'])
            : null,
        baseUnit: json['baseUnit'],
        baseUnitSize: (json['baseUnitSize'] as num?)?.toDouble(),
        totalBaseUnits: (json['totalBaseUnits'] as num?)?.toDouble(),
        remainingBaseUnits: (json['remainingBaseUnits'] as num?)?.toDouble(),
        totalBuyingCost: (json['totalBuyingCost'] as num?)?.toDouble(),
        purchaseDate: json['purchaseDate'] != null
            ? DateTime.parse(json['purchaseDate'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        //modifiedFields: json['modifiedFields'],
        units: (json['units'] as List?)
            ?.map((e) => _batchUnitFromJson(e))
            .toList(),
      );

  BatchUnit _batchUnitFromJson(Map<String, dynamic> json) => BatchUnit(
        level: PackagingLevel.values.firstWhere((e) => e.name == json['level']),
        unitsPerPackage: (json['unitsPerPackage'] as num).toDouble(),
        quantity: json['quantity'],
        buyingPrice: (json['buyingPrice'] as num).toDouble(),
      );

  ProjectItemPrice _projectItemPriceFromJson(Map<String, dynamic> json) =>
      ProjectItemPrice(
        priceCode: json['priceCode'],
        projectItemCode: json['projectItemCode'],
        amount: (json['amount'] as num).toDouble(),
        pricingType: json['pricingType'],
        appliesTo: json['appliesTo'],
        effectiveFrom: DateTime.parse(json['effectiveFrom']),
        effectiveTo: json['effectiveTo'] != null
            ? DateTime.parse(json['effectiveTo'])
            : null,
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        //modifiedFields: json['modifiedFields'],
      );

  ProjectSaleTransaction _projectSaleTransactionFromJson(
      Map<String, dynamic> json) {
    return ProjectSaleTransaction(
      transactionCode: json['transactionCode'],
      studentId: json['studentId'],
      projectCode: json['projectCode'],
      projectItemCode: json['projectItemCode'],
      batchCode: json['batchCode'],
      sellUnitCode: json['sellUnitCode'],
      sellUnitNameSnapshot: json['sellUnitNameSnapshot'],
      quantitySold: json['quantitySold'],
      unitSellingPrice: (json['unitSellingPrice'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      baseUnitsPerSellUnit: (json['baseUnitsPerSellUnit'] as num).toDouble(),
      totalBaseUnitsSold: (json['totalBaseUnitsSold'] as num).toDouble(),
      baseUnit: json['baseUnit'],
      baseUnitType: StockUnitType.values
          .firstWhere((e) => e.name == json['baseUnitType']),
      transactionDate: DateTime.parse(json['transactionDate']),
      paymentMethod: json['paymentMethod'],
      reference: json['reference'],
      amountPaid: (json['amountPaid'] as num).toDouble(),
      arrears: (json['arrears'] as num).toDouble(),
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: (json['deletedAt'] as List?)
              ?.map((e) => DateTime.parse(e))
              .toList() ??
          [],
      restoredAt: (json['restoredAt'] as List?)
              ?.map((e) => DateTime.parse(e))
              .toList() ??
          [],
      deletedByUsers: (json['deletedByUsers'] as List?)?.cast<String>() ?? [],
      restoredByUsers: (json['restoredByUsers'] as List?)?.cast<String>() ?? [],
      paymentMethodCode: json['paymentMethodCode'],
      methodType: json['methodType'],
      amountPaidInPaymentMethod:
          (json['amountPaidInPaymentMethod'] as num?)?.toDouble(),
      currency: json['currency'],
      provider: json['provider'],
      referenceNumber: json['referenceNumber'],
      phoneNumber: json['phoneNumber'],
      accountNumber: json['accountNumber'],
      accountName: json['accountName'],
      paymentDatetransacted: json['paymentDatetransacted'] != null
          ? DateTime.parse(json['paymentDatetransacted'])
          : null,
      isReversed: json['isReversed'],
      lineTransactionCodes:
          (json['lineTransactionCodes'] as List?)?.cast<String>(),
      financialType: json['financialType'] ?? 'sale',
      parentTransactionCode: json['parentTransactionCode'],
      affectsStock: json['affectsStock'] ?? true,
      createsObligation: json['createsObligation'] ?? false,
      settlesObligation: json['settlesObligation'] ?? false,
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      //modifiedFields: json['modifiedFields'],
    );
  }

  BatchSellUnit _batchSellUnitFromJson(Map<String, dynamic> json) {
    return BatchSellUnit(
      sellUnitCode: json["sell_unit_code"],
      batchCode: json["batch_code"],
      unitName: json["unit_name"],
      quantityMultiplier: json["quantity_multiplier"] ?? 1,
      sellingPrice: (json["selling_price"] as num).toDouble(),
      active: json["active"] ?? true,
      deletedAt: json["deleted_at"] != null
          ? DateTime.tryParse(json["deleted_at"])
          : null,
      lastModified: json["last_modified"] != null
          ? DateTime.tryParse(json["last_modified"])
          : null,
      operationType: json["operation_type"],
      //modifiedFields:
      // (json["modified_fields"] as List?)?.map((e) => e.toString()).toList(),
      baseUnitsPerSellUnit:
          (json["base_units_per_sell_unit"] as num?)?.toDouble(),
      baseUnit: json["base_unit"],
    );
  }

  PaymentMethod _paymentMethodFromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      paymentMethodCode: json["payment_method_code"],
      methodType: json["method_type"],
      amount: (json["amount"] as num?)?.toDouble(),
      currency: json["currency"],
      provider: json["provider"],
      reference: json["reference"],
      phoneNumber: json["phone_number"],
      accountNumber: json["account_number"],
      accountName: json["account_name"],
      paymentDate: json["payment_date"] != null
          ? DateTime.tryParse(json["payment_date"])
          : null,
      isReversed: json["is_reversed"],
      lastModified: json["last_modified"] != null
          ? DateTime.tryParse(json["last_modified"])
          : null,
      operationType: json["operation_type"],
    );
  }

  ReceiptSnapshot _receiptSnapshotFromJson(Map<String, dynamic> json) {
    return ReceiptSnapshot(
      receiptCode: json["receipt_code"],
      receiptDate: DateTime.parse(json["receipt_date"]),
      cashier: json["cashier"],
      totalExpected: (json["total_expected"] as num).toDouble(),
      totalPaid: (json["total_paid"] as num).toDouble(),
      amountReceived: (json["amount_received"] as num).toDouble(),
      change: (json["change_amount"] as num).toDouble(),
      currency: json["currency"],
      receiptLinesJson: List<Map<String, dynamic>>.from(json["receipt_lines"]),
      isReprint: json["is_reprint"] ?? false,
      studentName: json["student_name"],
      studentClass: json["student_class"],
    );
  }

// JSON Deserialization method for ExceptionalStudents
  ExceptionalStudents _exceptionsFromJson(Map<String, dynamic> json) {
    return ExceptionalStudents(
      id: json['id'],
      exceptionId: json['exceptionId'],
      exceptionName: json['exceptionName'],
      exceptionStatus: json['exceptionStatus'],
      exceptionType: json['exceptionType'],
      exceptionFigure: json['exceptionFigure'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      //modifiedFields: json['modifiedFields'],
      terms: json['terms'] != null
          ? (json['terms'] is String
              ? List<String>.from(jsonDecode(json['terms']))
              : List<String>.from(json['terms']))
          : null,
      priorityFlag: json['priorityFlag'] ?? 0,
    );
  }

  // JSON Deserialization methods
  Classes _classFromJson(Map<String, dynamic> json) {
    return Classes(
      id: json['id'],
      className: json['className'],
      classCode: json['classCode'],
      date: DateTime.parse(json['date']),
      termId: json['termId'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      terms: json['terms'] != null
          ? (json['terms'] is String
              ? List<String>.from(jsonDecode(json['terms']))
              : List<String>.from(json['terms']))
          : null,
      //modifiedFields: json['modifiedFields'],
    );
  }

  School _schoolFromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'],
      schoolName: json['schoolName'],
      schoolCode: json['schoolCode'],
      schoolAddress: json['schoolAddress'],
      schoolPhoneNumber: json['schoolPhoneNumber'],
      schoolEmail: json['schoolEmail'],
      termId: json['termId'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      modifiedFields: json['modifiedFields'],
    );
  }

  Student _studentInfoFromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      class_: json['class'],
      gender: json['gender'],
      age: DateTime.parse(json['age']),
      nationality: json['nationality'],
      district: json['district'],
      nationalIdNumber: json['nationalIdNumber'],
      studentIdNumber: json['studentIdNumber'],
      regNumber: json['regNumber'],
      physicalAddress: json['physicalAddress'], // Parsing age to DateTime
      paymentStatus: json['paymentStatus'],
      phoneNumber: json['phoneNumber'],
      religion: json['religion'],
      denomination: json['denomination'],
      formerSchool: json['formerSchool'],
      previousSchoolPerformanceResults:
          json['previousSchoolPerformanceResults'],
      emergencyContactName: json['emergencyContactName'],
      emergencyContactNumber: json['emergencyContactNumber'],

      isPresent: json['isPresent'],
      enrollmentStatus: json['enrollmentStatus'],

      // Correctly parsing presentDates and absentDates as lists of DateTime
      presentDates: (json['presentDates'] as List<dynamic>)
          .map((date) => DateTime.parse(date as String))
          .toList(),
      absentDates: (json['absentDates'] as List<dynamic>)
          .map((date) => DateTime.parse(date as String))
          .toList(),

      termId: json['termId'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      terms: json['terms'] != null
          ? (json['terms'] is String
              ? List<String>.from(jsonDecode(json['terms']))
              : List<String>.from(json['terms']))
          : null,
      exceptions: json['exceptions'] != null
          ? (jsonDecode(json['exceptions']) as List<dynamic>)
              .map((e) => _exceptionsFromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      isNewComer: json['isNewComer'],
      isNewComerFrom: json['isNewComerFrom'] != null
          ? DateTime.parse(json['isNewComerFrom'])
          : null,
      isNewComerUntil: json['isNewComerUntil'] != null
          ? DateTime.parse(json['isNewComerUntil'])
          : null,
      //modifiedFields: json['modifiedFields'],
    );
  }

  StudentPayment _studentPaymentFromJson(Map<String, dynamic> json) {
    return StudentPayment(
      id: json['id'],
      studentName: json['studentName'],
      studentSurname: json['studentSurname'],
      studentClass: json['studentClass'],
      phoneNumber: json['phoneNumber'],
      paymentPurpose: json['paymentPurpose'],
      amountToPay: json['amountToPay'],
      paymentDate: DateTime.parse(json['paymentDate']),
      termId: json['termId'],
      receiptNumber: json['receiptNumber'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      username: json['username'],
      role: json['role'],
      //modifiedFields: json['modifiedFields'],
    );
  }

  TeacherPayment _teacherPaymentFromJson(Map<String, dynamic> json) {
    return TeacherPayment(
      studentName: json['studentName'],
      id: json['id'],
      studentSurname: json['studentSurname'],
      studentClass: json['studentClass'],
      phoneNumber: json['phoneNumber'],
      paymentPurpose: json['paymentPurpose'],
      amountToPay: json['amountToPay'],
      paymentDate: DateTime.parse(json['paymentDate']),
      termId: json['termId'],
      receiptNumber: json['receiptNumber'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      //modifiedFields: json['modifiedFields'],
    );
  }

  PaymentPurpose _paymentPurposeFromJson(Map<String, dynamic> json) {
    return PaymentPurpose(
      id: json['id'],
      paymentPurpose: json['paymentPurpose'],
      purposeAmount: json['purposeAmount'],
      termId: json['termId'],
      syncStatus: json['syncStatus'],
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      purposeCode: json['purposeCode'],
      associatedClasses: _decodeToList(json['associatedClasses']),
      exceptions: json['exceptions'] != null
          ? (jsonDecode(json['exceptions']) as List<dynamic>)
              .map((e) => _exceptionsFromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      forNewcomersOnly: json['forNewcomersOnly'],
      //modifiedFields: json['modifiedFields'],
    );
  }

  TeacherPaymentsPurposes _teacherPaymentsPurposeFromJson(
      Map<String, dynamic> json) {
    return TeacherPaymentsPurposes(
      id: json['id'] ?? '', // Provide a default empty string if null
      paymentPurpose: json['purpose'] ?? '',
      purposeCode: json['purposeCode'] ?? '', // Default empty string
      purposeAmount:
          json['purposeAmount'] ?? 0.0, // Default value for numeric fields
      termId: json['termId'], // Allow nullable if the field itself is nullable
      syncStatus:
          json['syncStatus'], // Allow nullable if the field itself is nullable
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null, // Handle nullable dates
      operationType: json['operationType'] ?? '',
      associatedStaff: _decodeToList(json['associatedStaff']),
      //modifiedFields: json['modifiedFields'],

// Default empty string
    );
  }

  Teachers _teacherFromJson(Map<String, dynamic> json) {
    return Teachers(
      id: json['id'],

      name: json['name'],
      surname: json['surname'],
      IdNumber: json['IdNumber'],
      assignedClass: json['assignedClass'],
      gender: json['gender'],

      // Parsing dateOfBirth as DateTime
      dateOfBirth: DateTime.parse(json['dateOfBirth']),

      phoneNumber: json['phoneNumber'],
      paymentPurpose: json['paymentPurpose'],
      isPaid: json['isPaid'],
      paymentAmount: json['paymentAmount'],

      // paymentDate could be nullable, so we handle it safely
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'])
          : null,

      email: json['email'],
      address: json['address'],

      // Parsing hireDate as DateTime
      hireDate: DateTime.parse(json['hireDate']),

      qualifications: json['qualifications'],
      employmentStatus: json['employmentStatus'],
      termId: json['termId'],
      syncStatus: json['syncStatus'],

      // Handling nullable lastModified
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,

      operationType: json['operationType'],
      assignedClasses: _decodeToList(json['assignedClasses']),
      terms: json['terms'] != null
          ? (json['terms'] is String
              ? List<String>.from(jsonDecode(json['terms']))
              : List<String>.from(json['terms']))
          : null,
      //modifiedFields: json['modifiedFields'],
    );
  }

  Withdrawal _withdrawalFromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: json['id'], // Matches 'amount' in the toJson

      amount: json['amount'], // Matches 'amount' in the toJson
      withdrawalPurpose:
          json['withdrawalPurpose'], // Added to match withdrawalPurpose
      termId: json['termId'], // Matches 'termId' in the toJson
      withdrawalCode: json['withdrawalCode'],
      // Parsing 'date' as DateTime
      date: DateTime.parse(json['date']), // Fixed 'withdrawalDate' to 'date'

      syncStatus: json['syncStatus'], // Matches 'syncStatus'

      // Handling nullable lastModified
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,

      operationType: json['operationType'],
      //modifiedFields: json['modifiedFields'],
      // Matches 'operationType'
    );
  }

  Terms _termsFromJson(Map<String, dynamic> json) {
    return Terms(
      id: json['id'],
      termId: json['termId'], // Adjusted to match termId
      termName: json['termName'],

      // Parsing startDate as DateTime
      startDate: DateTime.parse(json['startDate']),

      // endDate could be nullable, so we handle it safely
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,

      // Adjusted to match isActive field
      isActive: json['isActive'],

      // Adjusted to match status field
      status: json['status'],

      syncStatus: json['syncStatus'],

      // Handling nullable lastModified
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,

      operationType: json['operationType'],
      //modifiedFields: json['modifiedFields'],
    );
  }

  DomainRecord _domainsFromJson(Map<String, dynamic> json) => DomainRecord(
        domainName: json['domainName'],
        areDomainsActive: json['areDomainsActive'],
        syncStatus: json['syncStatus'],
        operationType: json['operationType'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        //modifiedFields: json['modifiedFields'],
      );

  User _usersFromJson(Map<String, dynamic> json) => User(
        username: json['username'],
        password: json['password'],
        role: json['role'],
        securityQuestions: List<String>.from(json['securityQuestions']),
        securityAnswers: List<String>.from(json['securityAnswers']),
        phone: json['phone'],
        termId: json['termId'],
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        id: json['id'],
        isLogged: json['isLogged'],
        userCode: json['userCode'],
        email: json['email'],
        assignedClasses: json['assignedClasses'] != null
            ? List<String>.from(json['assignedClasses'])
            : [],
        isActive: json['isActive'] ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        modifiedFields: json['modifiedFields'],
      );

  Account _accountsFromJson(Map<String, dynamic> json) => Account(
        id: json['id'],
        accountType: json['accountType'],
        accountSubType: json['accountSubType'],
        accountName: json['accountName'],
        accountCode: json['accountCode'],
        operationType: json['operationType'],
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        isALiquidAccount: json['isALiquidAccount'],
        //modifiedFields: json['modifiedFields'],
      );

  Asset _assetsFromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      assetName: json['assetName'],
      assetType: json['assetType'],
      assetSubType: json['assetSubType'],
      assetCode: json['assetCode'],
      assetSerialNo: json['assetSerialNo'],
      acquisitionDate: json['acquisitionDate'] != null
          ? DateTime.parse(json['acquisitionDate'])
          : null,
      acquisitionCost: (json['acquisitionCost'] as num?)?.toDouble(),
      acquisitionMethod: json['acquisitionMethod'],
      department: json['department'],
      location: json['location'],
      depreciationRate: (json['depreciationRate'] as num?)?.toDouble(),
      depreciationMethod: json['depreciationMethod'],
      lastDepreciationDate: json['lastDepreciationDate'] != null
          ? DateTime.parse(json['lastDepreciationDate'])
          : null,
      accumulatedDepreciation:
          (json['accumulatedDepreciation'] as num?)?.toDouble(),
      bookValue: (json['bookValue'] as num?)?.toDouble(),
      isImpaired: json['isImpaired'],
      impairmentLoss: (json['impairmentLoss'] as num?)?.toDouble(),
      revaluationDate: json['revaluationDate'] != null
          ? DateTime.parse(json['revaluationDate'])
          : null,
      revaluationAmount: (json['revaluationAmount'] as num?)?.toDouble(),
      lastMaintenanceDate: json['lastMaintenanceDate'] != null
          ? DateTime.parse(json['lastMaintenanceDate'])
          : null,
      maintenanceCost: (json['maintenanceCost'] as num?)?.toDouble(),
      maintenanceDescription: json['maintenanceDescription'],
      capitalImprovementCost:
          (json['capitalImprovementCost'] as num?)?.toDouble(),
      capitalImprovementDescription: json['capitalImprovementDescription'],
      disposalDate: json['disposalDate'] != null
          ? DateTime.parse(json['disposalDate'])
          : null,
      disposalProceeds: (json['disposalProceeds'] as num?)?.toDouble(),
      disposalReason: json['disposalReason'],
      gainOrLossOnDisposal: (json['gainOrLossOnDisposal'] as num?)?.toDouble(),
      isLeased: json['isLeased'],
      leaseType: json['leaseType'],
      leaseStartDate: json['leaseStartDate'] != null
          ? DateTime.parse(json['leaseStartDate'])
          : null,
      leaseEndDate: json['leaseEndDate'] != null
          ? DateTime.parse(json['leaseEndDate'])
          : null,
      leasePaymentAmount: (json['leasePaymentAmount'] as num?)?.toDouble(),
      lastAuditDate: json['lastAuditDate'] != null
          ? DateTime.parse(json['lastAuditDate'])
          : null,
      syncStatus: json['syncStatus'],
      notes: json['notes'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'],
      usefulLife: json['usefulLife'],
      hasDebitBalance: json['hasDebitBalance'],
      hasCreditBalance: json['hasCreditBalance'],
      option: json['option'],
      //modifiedFields: json['modifiedFields'],
    );
  }

  Project _projectsFromJson(Map<String, dynamic> json) => Project(
        projectCode: json['projectCode'],
        name: json['name'],
        description: json['description'],
        status: json['status'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        //modifiedFields: json['modifiedFields'],

        // ✅ NEW REQUIRED FIELDS
        projectType: json['projectType'] ?? 'sales',
        participationType: json['participationType'] ?? 'optional',
        studentPayable: json['studentPayable'],
      );
  ProjectItem _projectItemsFromJson(Map<String, dynamic> json) => ProjectItem(
        projectItemCode: json['projectItemCode'],
        projectCode: json['projectCode'],
        name: json['name'],

        // ✅ NEW FIELDS
        itemType: json['itemType'],
        active: json['active'],
        trackStock: json['trackStock'],

        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        //modifiedFields: json['modifiedFields'],
      );

  DailyActivity _daily_activitiesFromJson(Map<String, dynamic> json) =>
      DailyActivity(
        projectDailyActiviyCode: json['projectDailyActiviyCode'],
        projectCode: json['projectCode'],
        date: DateTime.parse(json['date']),
        type: json['type'],
        description: json['description'],
        amount: json['amount'],
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        //modifiedFields: json['modifiedFields'],
      );

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Import Records'),
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
                color: const Color.fromARGB(
                    255, 0, 0, 0), // White text on gradient
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 40,
            ),
            Center(
              child: ElevatedButton(
                onPressed: _isImporting
                    ? null
                    : () async {
                        print('import button clicked.');
                        await _importWithProgress();
                      },
                child: _isImporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Text('Import All Database Records'),
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
