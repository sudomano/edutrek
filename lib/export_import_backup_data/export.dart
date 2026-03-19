import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
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

class ExportClassesPages extends StatefulWidget {
  @override
  _ExportClassesPagesState createState() => _ExportClassesPagesState();
}

class _ExportClassesPagesState extends State<ExportClassesPages> {
  int _selectedIndex = 0;

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

  bool _isExporting = false; // To track export status

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
    } catch (e) {
      print('Error opening Hive boxes: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error opening Hive boxes: $e'),
      ));
    }
  }

  Future<void> exportHiveData() async {
    setState(() {
      _isExporting = true; // Start exporting
    });

    try {
      // Serialize data
      Map<String, dynamic> exportData = {
        'classes': _serializeBox(_classesBox, _classToJson),
        'teacher_payments_purposes': _serializeBox(
            _teacherPaymentsPurposesBox, _teacherPaymentsPurposeToJson),
        'payment_purposes':
            _serializeBox(_paymentPurposesBox, _paymentPurposeToJson),
        'student_payments':
            _serializeBox(_studentPaymentsBox, _studentPaymentToJson),
        'teacher_payments':
            _serializeBox(_teacherPaymentsBox, _teacherPaymentclassToJson),
        'students': _serializeBox(_studentsBox, _studentInfoToJson),
        'withdrawals': _serializeBox(_withdrawalsBox, _withdrawalToJson),
        'teachers': _serializeBox(_teachersBox, _teacherToJson),
        'school': _serializeBox(_schoolBox, _schoolToJson),
        'terms': _serializeBox(_termsBox, _termsToJson),
        'domains': _serializeBox(_domainRecordBox, _domainsToJson),
        'users': _serializeBox(_userBox, _usersToJson),
        'accounts': _serializeBox(_accountBox, _accountsToJson),
        'assets': _serializeBox(_assetBox, _assetsToJson),
        'projects': _serializeBox(_projectBox, _projectsToJson),
        'project_items': _serializeBox(_projectItemBox, _projectItemsToJson),
        'daily_activities':
            _serializeBox(_dailyActivityBox, _daily_activitiesToJson),
        'exceptions': _serializeBox(_exceptionalStudentsBox, _exceptionsToJson),
        'batch_units': _serializeBox(_batchUnitBox, _batchUnitToJson),
        'product_batches': _serializeBox(_productBatchBox, _productBatchToJson),
        'project_item_prices':
            _serializeBox(_projectItemPriceBox, _projectItemPriceToJson),
        'project_sale_transactions': _serializeBox(
            _projectSaleTransactionBox, _projectSaleTransactionToJson),
        'batch_sell_units':
            _serializeBox(_batchSellUnitBox, _batchSellUnitToJson),
        'payment_methods':
            _serializeBox(_paymentMethodBox, _paymentMethodToJson),
        'receipt_snapshots':
            _serializeBox(_receiptSnapshotBox, _receiptSnapshotToJson),
      };

      String jsonData = jsonEncode(exportData);

      if (Platform.isWindows) {
        // **Windows Platform Handling**

        // Use File Picker to select a save location
        String? selectedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Hive Data Backup',
          fileName: 'hive_data_backup.json',
          allowedExtensions: ['json'],
          type: FileType.custom,
        );

        if (selectedPath != null) {
          File file = File(selectedPath);
          await file.writeAsString(jsonData);
          print('Backup file saved successfully at: $selectedPath');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Backup saved successfully at: $selectedPath'),
          ));
        } else {
          print('File saving was canceled by the user.');
        }
      } else if (Platform.isAndroid) {
        // **Android Platform Handling**
        print('Running on Android. Saving to app-specific directory.');

        // Get the app-specific directory
        Directory? directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception('Unable to access external storage directory.');
        }

        String backupDirPath = '${directory.path}/backup';
        Directory backupDir = Directory(backupDirPath);
        if (!await backupDir.exists()) {
          print('Creating backup directory at: $backupDirPath');
          await backupDir.create(recursive: true);
        }

        String filePath = '$backupDirPath/hive_data_backup.json';
        File file = File(filePath);

        // Write the JSON data to the file
        await file.writeAsString(jsonData);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Backup saved successfully at: $filePath'),
        ));
      } else {
        // **Other Platforms (Optional)**
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export not supported on this platform.'),
        ));
      }
    } catch (e) {
      print('Error exporting data: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error exporting data: $e'),
      ));
    } finally {
      setState(() {
        _isExporting = false; // Reset exporting status
      });
    }
  }

  // Helper function to serialize data
  List<Map<String, dynamic>> _serializeBox<T>(
      Box<T>? box, Map<String, dynamic> Function(T) toJson) {
    print('Serializing box: ${box?.name ?? 'Unknown'}');
    return box?.values.map((data) => toJson(data as T)).toList() ?? [];
  }

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
        'modifiedFields':
            b.modifiedFields != null ? jsonEncode(b.modifiedFields) : null,
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
        'modifiedFields':
            p.modifiedFields != null ? jsonEncode(p.modifiedFields) : null,
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
        'modifiedFields':
            t.modifiedFields != null ? jsonEncode(t.modifiedFields) : null,
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
      'modifiedFields': exc.modifiedFields != null
          ? jsonEncode(exc.modifiedFields) // JSON encode the list
          : null,
      'terms': exc.terms != null
          ? jsonEncode(exc.terms) // JSON encode the list
          : null,
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
          : null,
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
          : null,
      'exceptions': cls.exceptions != null
          ? jsonEncode(
              cls.exceptions!.map((e) => _exceptionsToJson(e)).toList())
          : null,
      'isNewComer': cls.isNewComer,
      'isNewComerFrom': cls.isNewComerFrom?.toIso8601String(),
      'isNewComerUntil': cls.isNewComerUntil?.toIso8601String(),
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
          : null,
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
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
      'modifiedFields': cls.modifiedFields != null
          ? jsonEncode(cls.modifiedFields) // JSON encode the list
          : null,
    };
  }

  Map<String, dynamic> _domainsToJson(DomainRecord domain) => {
        'domainName': domain.domainName,
        'areDomainsActive': domain.areDomainsActive,
        'syncStatus': domain.syncStatus,
        'operationType': domain.operationType,
        'lastModified': domain.lastModified?.toIso8601String(),
        'modifiedFields': domain.modifiedFields != null
            ? jsonEncode(domain.modifiedFields) // JSON encode the list
            : null,
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
        'modifiedFields': user.modifiedFields != null
            ? jsonEncode(user.modifiedFields) // JSON encode the list
            : null,
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
        'modifiedFields': acc.modifiedFields != null
            ? jsonEncode(acc.modifiedFields) // JSON encode the list
            : null,
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
      'modifiedFields': asset.modifiedFields != null
          ? jsonEncode(asset.modifiedFields) // JSON encode the list
          : null,
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
        'modifiedFields':
            p.modifiedFields != null ? jsonEncode(p.modifiedFields) : null,

        // ✅ NEW FIELDS
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
        'modifiedFields':
            i.modifiedFields != null ? jsonEncode(i.modifiedFields) : null,
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
        'modifiedFields': a.modifiedFields != null
            ? jsonEncode(a.modifiedFields) // JSON encode the list
            : null,
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
    // Close Hive boxes if necessary
    _classesBox?.close();
    _teacherPaymentsPurposesBox?.close();
    _paymentPurposesBox?.close();
    _studentPaymentsBox?.close();
    _teacherPaymentsBox?.close();
    _studentsBox?.close();
    _withdrawalsBox?.close();
    _teachersBox?.close();
    _schoolBox?.close();
    _termsBox?.close();
    _domainRecordBox?.close();
    _userBox?.close();
    _accountBox?.close();
    _assetBox?.close();
    _projectBox?.close();
    _projectItemBox?.close();
    _dailyActivityBox?.close();
    _exceptionalStudentsBox?.close();
    _batchUnitBox?.close();
    _productBatchBox?.close();
    _projectItemPriceBox?.close();
    _projectSaleTransactionBox?.close();
    _batchSellUnitBox?.close();
    _paymentMethodBox?.close();
    _receiptSnapshotBox?.close();
  }
}
