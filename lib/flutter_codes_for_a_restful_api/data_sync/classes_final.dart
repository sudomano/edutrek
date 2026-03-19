import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';

import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
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
import 'package:zitf_system/database/projects/unitbatching.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';

import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

class ClassesFinal extends StatefulWidget {
  const ClassesFinal({super.key});

  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

typedef SyncFunction<T> = Future<void> Function(T model);

class _SyncClassesPageState extends State<ClassesFinal> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }

  Box<Classes>? _classesBox;
  Box<School>? _schoolBox;
  Box<Terms>? _termsBox;
  Box<Withdrawal>? _withdrawalsBox;
  Box<Student>? _studentsBox;
  Box<User>? _usersBox;
  Box<PaymentPurpose>? _payment_purposesBox;
  Box<StudentPayment>? _student_paymentsBox;
  Box<Teachers>? _teachersBox;
  Box<TeacherPaymentsPurposes>? _teacher_payments_purposesBox;
  Box<TeacherPayment>? _teacher_paymentsBox;

  Box<DomainRecord>? _domainRecordBox;
  Box<Account>? _accountBox;
  Box<Asset>? _assetBox;
  Box<Project>? _projectBox;
  Box<ProjectItem>? _projectItemBox;
  Box<DailyActivity>? _dailyActivityBox;
  Box<ExceptionalStudents>? _exceptionalStudentsBox;

  Box<BatchUnit>? _batchUnitBox;
  Box<ProductBatch>? _productBatchBox;
  Box<ProjectItemPrice>? _projectItemPriceBox;
  Box<ProjectSaleTransaction>? _projectSaleTransactionBox;
  Box<BatchSellUnit>? _batchSellUnitBox;
  Box<PaymentMethod>? _paymentMethodBox;
  Box<ReceiptSnapshot>? _receiptSnapshotBox;

  bool _isSyncing = false;
  bool _isSyncings = false;
  bool areDomainsActive = false;
  String _domainName = ""; // Local variable to store domain name

  @override
  void initState() {
    super.initState();
    _openHiveBox();
    _loadExistingConfig(); // Load domain name from Hive
    final queue = SyncQueueManager();

    queue.registerCreateHandler<Classes>(_createClassInMySQL);
    queue.registerUpdateHandler<Classes>(_createClassInMySQL);

    // Add as needed for other types
  }

  Future<void> _openHiveBox() async {
    _classesBox = await Hive.openBox<Classes>('classes');
    _schoolBox = await Hive.openBox<School>('school');
    _termsBox = await Hive.openBox<Terms>('terms');
    _withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
    _studentsBox = await Hive.openBox<Student>('students');
    _usersBox = await Hive.openBox<User>('users');
    _payment_purposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    _student_paymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    _teachersBox = await Hive.openBox<Teachers>('teachers');
    _teacher_payments_purposesBox = await Hive.openBox<TeacherPaymentsPurposes>(
        'teacher_payments_purposes');
    _teacher_paymentsBox =
        await Hive.openBox<TeacherPayment>('teacher_payments');

    _domainRecordBox = await Hive.openBox<DomainRecord>('domainBox');
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
    _projectSaleTransactionBox =
        await Hive.openBox<ProjectSaleTransaction>('project_sale_transactions');
    _batchSellUnitBox = await Hive.openBox<BatchSellUnit>('batch_sell_units');
    _paymentMethodBox = await Hive.openBox<PaymentMethod>('payment_methods');
    _receiptSnapshotBox =
        await Hive.openBox<ReceiptSnapshot>('receipt_snapshots');
  }

  Future<void> _loadExistingConfig() async {
    final box = await Hive.openBox<DomainRecord>('domainBox');
    if (box.isNotEmpty) {
      final record = box.getAt(0);
      if (record != null) {
        setState(() {
          _domainName = record.domainName ?? "null"; // Default value
          if (_domainName != "null") {
            areDomainsActive = record.areDomainsActive ?? false;
          } else {
            areDomainsActive = false;
          }
          debugPrint(_domainName);
          debugPrint(areDomainsActive.toString());
        });
      }
    }
  }

  // Sync models to MySQL
  Future<void> _syncModels() async {
    try {
      // Sync PaymentPurpose records
      List<ExceptionalStudents> createExceptions = _exceptionalStudentsBox!
          .values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (ExceptionalStudents cls in createExceptions) {
        if (cls.operationType == 'create') {
          await _createExceptionInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateExceptionInMySQL(cls);
        }
      }

      List<BatchUnit> createBatchUnits = _batchUnitBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();

      for (BatchUnit cls in createBatchUnits) {
        if (cls.operationType == 'create') {
          await _createBatchUnitInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateBatchUnitInMySQL(cls);
        }
      }

      List<ProductBatch> createProductBatches = _productBatchBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (ProductBatch cls in createProductBatches) {
        if (cls.operationType == 'create') {
          await _createProductBatchInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateProductBatchInMySQL(cls);
        }
      }

      List<ProjectItemPrice> createProjectItemPrices = _projectItemPriceBox!
          .values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (ProjectItemPrice cls in createProjectItemPrices) {
        if (cls.operationType == 'create') {
          await _createProjectItemPriceInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateProjectItemPriceInMySQL(cls);
        }
      }

      List<ProjectSaleTransaction> createProjectSaleTransactions =
          _projectSaleTransactionBox!.values
              .where((cls) => cls.syncStatus == false)
              .toList();
      for (ProjectSaleTransaction cls in createProjectSaleTransactions) {
        if (cls.operationType == 'create') {
          await _createProjectSaleTransactionInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateProjectSaleTransactionInMySQL(cls);
        }
      }

      List<BatchSellUnit> createBatchSellUnits = _batchSellUnitBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (BatchSellUnit cls in createBatchSellUnits) {
        if (cls.operationType == 'create') {
          await _createBatchSellUnitInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateBatchSellUnitInMySQL(cls);
        }
      }

      List<PaymentMethod> createPaymentMethods = _paymentMethodBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (PaymentMethod cls in createPaymentMethods) {
        if (cls.operationType == 'create') {
          await _createPaymentMethodInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updatePaymentMethodInMySQL(cls);
        }
      }

      List<ReceiptSnapshot> createReceiptSnapshots = _receiptSnapshotBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (ReceiptSnapshot cls in createReceiptSnapshots) {
        if (cls.operationType == 'create') {
          await _createReceiptSnapshotInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateReceiptSnapshotInMySQL(cls);
        }
      }

      List<Classes> createClasses =
          _classesBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Classes cls in createClasses) {
        if (cls.operationType == 'create') {
          await _createClassInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateClassesInMySQL(cls);
        }
      }

      List<School> createSchool =
          _schoolBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (School cls in createSchool) {
        if (cls.operationType == 'create') {
          await _createSchoolInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateSchoolInMySQL(cls);
        }
      }

      List<Terms> createTerms =
          _termsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Terms cls in createTerms) {
        if (cls.operationType == 'create') {
          await _createTermsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTermsInMySQL(cls);
        }
      }

      List<Withdrawal> createWithdrawal = _withdrawalsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (Withdrawal cls in createWithdrawal) {
        if (cls.operationType == 'create') {
          await _createWithdrawalsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateWithdrawalsInMySQL(cls);
        }
      }
      List<Student> createStudent =
          _studentsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Student cls in createStudent) {
        if (cls.operationType == 'create') {
          await _createStudentsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentsInMySQL(cls);
        }
      }

      List<User> createUser =
          _usersBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (User cls in createUser) {
        if (cls.operationType == 'create') {
          await _createUserInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateUserInMySQL(cls);
        }
      }

      List<PaymentPurpose> createPaymentPurpose = _payment_purposesBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (PaymentPurpose cls in createPaymentPurpose) {
        if (cls.operationType == 'create') {
          await _createPaymentPurposeInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updatePaymentPurposeInMySQL(cls);
        }
      }
      List<StudentPayment> createStudentPayment = _student_paymentsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (StudentPayment cls in createStudentPayment) {
        if (cls.operationType == 'create') {
          await _createStudentPaymentInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentPaymentInMySQL(cls);
        }
      }

      List<Teachers> createTeacher =
          _teachersBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Teachers cls in createTeacher) {
        if (cls.operationType == 'create') {
          await _createTeacherInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTeacherInMySQL(cls);
        }
      }

      List<TeacherPaymentsPurposes> createTeacherPaymentsPurposes =
          _teacher_payments_purposesBox!.values
              .where((cls) => cls.syncStatus == false)
              .toList();
      for (TeacherPaymentsPurposes cls in createTeacherPaymentsPurposes) {
        if (cls.operationType == 'create') {
          await _createTeacherPaymentPurposeInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTeacherPaymentPurposeInMySQL(cls);
        }
      }

      List<TeacherPayment> createTeacherPayments = _teacher_paymentsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (TeacherPayment cls in createTeacherPayments) {
        if (cls.operationType == 'create') {
          await _createTeacherPaymentInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTeacherPaymentInMySQL(cls);
        }
      }
      // Sync DomainRecords
      List<DomainRecord> createDomains = _domainRecordBox!.values
          .where((dom) => dom.syncStatus == false)
          .toList();
      for (DomainRecord dom in createDomains) {
        if (dom.operationType == 'create') {
          await _createDomainInMySQL(dom);
        } else if (dom.operationType == 'update') {
          await _updateDomainInMySQL(dom);
        }
      }

      // Sync Accounts
      List<Account> createAccounts =
          _accountBox!.values.where((acc) => acc.syncStatus == false).toList();
      for (Account acc in createAccounts) {
        if (acc.operationType == 'create') {
          await _createAccountInMySQL(acc);
        } else if (acc.operationType == 'update') {
          await _updateAccountInMySQL(acc);
        }
      }

      // Sync Assets
      List<Asset> createAssets =
          _assetBox!.values.where((a) => a.syncStatus == false).toList();
      for (Asset a in createAssets) {
        if (a.operationType == 'create') {
          await _createAssetInMySQL(a);
        } else if (a.operationType == 'update') {
          await _updateAssetInMySQL(a);
        }
      }

      // Sync Projects
      List<Project> createProjects =
          _projectBox!.values.where((p) => p.syncStatus == false).toList();
      for (Project p in createProjects) {
        if (p.operationType == 'create') {
          await _createProjectInMySQL(p);
        } else if (p.operationType == 'update') {
          await _updateProjectInMySQL(p);
        }
      }

      // Sync ProjectItems
      List<ProjectItem> createProjectItems = _projectItemBox!.values
          .where((pi) => pi.syncStatus == false)
          .toList();
      for (ProjectItem pi in createProjectItems) {
        if (pi.operationType == 'create') {
          await _createProjectItemInMySQL(pi);
        } else if (pi.operationType == 'update') {
          await _updateProjectItemInMySQL(pi);
        }
      }

      // Sync DailyActivities
      List<DailyActivity> createDailyActivities = _dailyActivityBox!.values
          .where((d) => d.syncStatus == false)
          .toList();
      for (DailyActivity d in createDailyActivities) {
        if (d.operationType == 'create') {
          await _createDailyActivityInMySQL(d);
        } else if (d.operationType == 'update') {
          await _updateDailyActivityInMySQL(d);
        }
      }

      // Sync ProjectStudentPayments
    } catch (e) {
      print('Error syncing models: $e');
    }
  }

// JSON Serialization method for ExceptionalStudents

  Map<String, dynamic> _productBatchToJsonLocal(ProductBatch b) => {
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
        'units': b.units?.map((u) => _batchUnitToJson(u)).toList(),
      };

// ============================================================
// 🔷 BATCH UNIT JSON HELPERS
// ============================================================

  Map<String, dynamic> _batchUnitToJson(BatchUnit u) => {
        'level': u.level.name,
        'unitsPerPackage': u.unitsPerPackage,
        'quantity': u.quantity,
        'buyingPrice': u.buyingPrice,
        'unitBatchCode': u.unitBatchCode,
      };

  Map<String, dynamic> _projectItemPriceToJsonLocal(ProjectItemPrice p) => {
        'priceCode': p.priceCode,
        'projectItemCode': p.projectItemCode,
        'amount': p.amount,
        'pricingType': p.pricingType,
        'appliesTo': p.appliesTo,
        'effectiveFrom': p.effectiveFrom.toIso8601String(),
        'effectiveTo': p.effectiveTo?.toIso8601String(),
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
      };

  Map<String, dynamic> _batchSellUnitToJson(BatchSellUnit u) {
    return {
      "sellUnitCode": u.sellUnitCode,
      "batchCode": u.batchCode,
      "unitName": u.unitName,
      "quantityMultiplier": u.quantityMultiplier,
      "sellingPrice": u.sellingPrice,
      "active": u.active,
      "deletedAt": u.deletedAt?.toIso8601String(),
      "packagingLevel": u.packagingLevel?.name,
      "baseUnitsPerSellUnit": u.baseUnitsPerSellUnit,
      "baseUnit": u.baseUnit,
      "baseUnitType": u.baseUnitType?.name,
    };
  }

  Map<String, dynamic> _paymentMethodToJson(PaymentMethod pm) {
    return {
      "payment_method_code": pm.paymentMethodCode,
      "method_type": pm.methodType,
      "amount": pm.amount,
      "currency": pm.currency,
      "provider": pm.provider,
      "reference": pm.reference,
      "phone_number": pm.phoneNumber,
      "account_number": pm.accountNumber,
      "account_name": pm.accountName,
      "payment_date": pm.paymentDate?.toIso8601String(),
      "is_reversed": pm.isReversed,
    };
  }

  Map<String, dynamic> _receiptSnapshotToJson(ReceiptSnapshot r) {
    return {
      "receiptCode": r.receiptCode,
      "receiptDate": r.receiptDate.toIso8601String(),
      "cashier": r.cashier,
      "totalExpected": r.totalExpected,
      "totalPaid": r.totalPaid,
      "amountReceived": r.amountReceived,
      "change": r.change,
      "currency": r.currency,
      "receiptLinesJson": r.receiptLinesJson,
      "isReprint": r.isReprint,
      "studentName": r.studentName,
      "studentClass": r.studentClass,
    };
  }

  Map<String, dynamic> _exceptionsToJson(ExceptionalStudents exc) {
    return {
      'id': exc.id,
      'exceptionId': exc.exceptionId,
      'exceptionName': exc.exceptionName,
      'exceptionStatus': exc.exceptionStatus,
      'exceptionType': exc.exceptionType,
      'exceptionFigure': exc.exceptionFigure,
      'terms': exc.terms != null
          ? jsonEncode(exc.terms) // JSON encode the list
          : null,
    };
  }

  Map<String, dynamic> _classToJson(Classes cls) {
    return {
      'id': cls.id,
      'classCode': cls.classCode,
      'className': cls.className,
      'date': cls.date.toIso8601String(),
      'termId': cls.termId,
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
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
    };
  }

  Map<String, dynamic> _studentInfoToJson(Student cls) {
    return {
      'name': cls.name,
      'surname': cls.surname,
      'regNumber': cls.regNumber,
      'class': cls.class_,
      'gender': cls.gender,
      'age': cls.age.toIso8601String(),
      'phoneNumber': cls.phoneNumber,
      'paymentStatus': cls.paymentStatus,
      'isPresent': cls.isPresent,
      'presentDates': jsonEncode(
          cls.presentDates.map((date) => date.toIso8601String()).toList()),
      'absentDates': jsonEncode(
          cls.absentDates.map((date) => date.toIso8601String()).toList()),
      'termId': cls.termId,
      'id': cls.id,
      'physicalAddress': cls.physicalAddress,
      'formerSchool': cls.formerSchool,
      'religion': cls.religion,
      'denomination': cls.denomination,
      'studentIdNumber': cls.studentIdNumber,
      'nationalIdNumber': cls.nationalIdNumber,
      'nationality': cls.nationality,
      'district': cls.district,
      'previousSchoolPerformanceResults': cls.previousSchoolPerformanceResults,
      'enrollmentStatus': cls.enrollmentStatus,
      'emergencyContactName': cls.emergencyContactName,
      'emergencyContactNumber': cls.emergencyContactNumber,
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
    };
  }

  Map<String, dynamic> _userToJson(User cls) {
    return {
      'id': cls.id,
      'username': cls.username,
      'password': cls.password,
      'role': cls.role,
      'securityQuestions': jsonEncode(cls.securityQuestions),
      'securityAnswers': jsonEncode(cls.securityAnswers),
      'phone': cls.phone,
      'termId': cls.termId,
      'userCode': cls.userCode,
    };
  }

  Map<String, dynamic> _paymentPurposeToJson(PaymentPurpose cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
      'associatedClasses':
          jsonEncode(cls.associatedClasses), // Convert list to JSON
      'purposeCode': cls.purposeCode,
      'exceptions': cls.exceptions != null
          ? jsonEncode(
              cls.exceptions!.map((e) => _exceptionsToJson(e)).toList())
          : null,
      'forNewcomersOnly': cls.forNewcomersOnly,
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
      'username': cls.username,
      'role': cls.role,
    };
  }

  Map<String, dynamic> _teacherToJson(Teachers cls) {
    return {
      'id': cls.id,
      'name': cls.name,
      'surname': cls.surname,
      'IdNumber': cls.IdNumber,
      'assignedClass': cls.assignedClass,
      'assignedClasses': cls.assignedClasses != null
          ? jsonEncode(cls.assignedClasses) // JSON encode the list
          : null,
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
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
          : null,
    };
  }

  Map<String, dynamic> _teacherPaymentsPurposeToJson(
      TeacherPaymentsPurposes cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeCode': cls.purposeCode,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'associatedStaff': cls.associatedStaff != null
          ? jsonEncode(
              cls.associatedStaff) // Explicit JSON encode for associatedStaff
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
    };
  }

  Map<String, dynamic> _domainsToJson(DomainRecord domain) => {
        'domainName': domain.domainName,
        'areDomainsActive': domain.areDomainsActive,
        'syncStatus': domain.syncStatus,
        'operationType': domain.operationType,
        'lastModified': domain.lastModified?.toIso8601String(),
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
        'modifiedFields': acc.modifiedFields,
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
      'modifiedFields': asset.modifiedFields,
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
        'modifiedFields': p.modifiedFields,

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
        'modifiedFields': i.modifiedFields,
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
        'modifiedFields': a.modifiedFields,
      };

//==================== BatchUnit sync ======================
  Future<void> _createBatchUnitInMySQL(BatchUnit unit) async {
    final Map<String, dynamic> jsonData = _batchUnitToJson(unit);
    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_unit_api.php?unitBatchCode=${unit.unitBatchCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((unit.modifiedFields?.isNotEmpty ?? false) &&
            unit.operationType != null &&
            unit.operationType != 'none') {
          SyncQueueManager().enqueue(unit);
        }
        unit.syncStatus = true;
        unit.operationType = 'none';
        unit.modifiedFields = [];

        await unit.save();
      } else {
        throw Exception('Failed to create BatchUnit');
      }
    } catch (e) {
      print('BatchUnit create error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateBatchUnitInMySQL(BatchUnit unit) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in unit.modifiedFields ?? []) {
      switch (field) {
        case 'name':
          modifiedFieldsJson['name'] = unit.level.name;
          break;
        case 'unitsPerPackage':
          modifiedFieldsJson['unitsPerPackage'] = unit.unitsPerPackage;
          break;
        case 'quantity':
          modifiedFieldsJson['quantity'] = unit.quantity;
          break;
        case 'buyingPrice':
          modifiedFieldsJson['buyingPrice'] = unit.buyingPrice;
          break;
        case 'unitBatchCode':
          modifiedFieldsJson['unitBatchCode'] = unit.unitBatchCode;
          break;
      }
    }
    modifiedFieldsJson['unitBatchCode'] = unit.unitBatchCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_unit_api.php?unitBatchCode=${unit.unitBatchCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Students ${unit.unitBatchCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((unit.modifiedFields?.isNotEmpty ?? false) &&
            unit.operationType != null &&
            unit.operationType != 'none') {
          SyncQueueManager().enqueue(unit);
        }
        unit.syncStatus = true;
        unit.operationType = 'none';
        unit.modifiedFields = [];
        await unit.save();
      } else {
        throw Exception('Failed to update students.');
      }
    } catch (e) {
      print('Error updating students: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//==================== _productBatch sync ======================

  Future<void> _createProductBatchInMySQL(ProductBatch batch) async {
    final Map<String, dynamic> jsonData = _productBatchToJsonLocal(batch);
    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/product_batch_api.php?batchCode=${batch.batchCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((batch.modifiedFields?.isNotEmpty ?? false) &&
            batch.operationType != null &&
            batch.operationType != 'none') {
          SyncQueueManager().enqueue(batch);
        }

        batch.syncStatus = true;
        batch.operationType = 'none';
        batch.modifiedFields = [];
        await batch.save();
      } else {
        throw Exception('Failed to create ProductBatch');
      }
    } catch (e) {
      print('ProductBatch create error: $e');
    } finally {
      setState(() => _isSyncings = false);
    }
  }

  Future<void> _updateProductBatchInMySQL(ProductBatch batch) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in batch.modifiedFields ?? []) {
      switch (field) {
        case 'batchCode':
          modifiedFieldsJson['batchCode'] = batch.batchCode;
          break;

        case 'productCode':
          modifiedFieldsJson['productCode'] = batch.productCode;
          break;

        case 'reference':
          modifiedFieldsJson['reference'] = batch.reference;
          break;

        case 'baseUnitType':
          modifiedFieldsJson['baseUnitType'] = batch.baseUnitType?.name;
          break;

        case 'baseUnit':
          modifiedFieldsJson['baseUnit'] = batch.baseUnit;
          break;

        case 'baseUnitSize':
          modifiedFieldsJson['baseUnitSize'] = batch.baseUnitSize;
          break;

        case 'totalBaseUnits':
          modifiedFieldsJson['totalBaseUnits'] = batch.totalBaseUnits;
          break;

        case 'remainingBaseUnits':
          modifiedFieldsJson['remainingBaseUnits'] = batch.remainingBaseUnits;
          break;

        case 'totalBuyingCost':
          modifiedFieldsJson['totalBuyingCost'] = batch.totalBuyingCost;
          break;

        case 'purchaseDate':
          modifiedFieldsJson['purchaseDate'] =
              batch.purchaseDate?.toIso8601String();
          break;

        case 'createdAt':
          modifiedFieldsJson['createdAt'] = batch.createdAt?.toIso8601String();
          break;

        case 'units':
          modifiedFieldsJson['units'] =
              batch.units?.map((u) => _batchUnitToJson(u)).toList();
          break;
      }
    }

    // always include identifier
    modifiedFieldsJson['batchCode'] = batch.batchCode;

    setState(() => _isSyncings = true);

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/product_batch_api.php?batchCode=${batch.batchCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((batch.modifiedFields?.isNotEmpty ?? false) &&
            batch.operationType != null &&
            batch.operationType != 'none') {
          SyncQueueManager().enqueue(batch);
        }

        batch.syncStatus = true;
        batch.operationType = 'none';
        batch.modifiedFields = [];
        await batch.save();
      } else {
        throw Exception('Failed to update ProductBatch');
      }
    } catch (e) {
      print('ProductBatch update error: $e');
    } finally {
      setState(() => _isSyncings = false);
    }
  }
//==================== _projectItemPrice sync ======================

  Future<void> _createProjectItemPriceInMySQL(ProjectItemPrice price) async {
    final Map<String, dynamic> jsonData = _projectItemPriceToJsonLocal(price);

    setState(() => _isSyncings = true);

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_price_api.php?priceCode=${price.priceCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((price.modifiedFields?.isNotEmpty ?? false) &&
            price.operationType != null &&
            price.operationType != 'none') {
          SyncQueueManager().enqueue(price);
        }
        price.syncStatus = true;
        price.operationType = 'none';
        price.modifiedFields = [];
        await price.save();
      } else {
        throw Exception('Failed to create BatchUnit');
      }
    } catch (e) {
      print('ProjectItemPrice create error: $e');
    } finally {
      setState(() => _isSyncings = false);
    }
  }

  Future<void> _updateProjectItemPriceInMySQL(ProjectItemPrice price) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in price.modifiedFields ?? []) {
      switch (field) {
        case 'projectItemCode':
          modifiedFieldsJson['projectItemCode'] = price.projectItemCode;
          break;

        case 'amount':
          modifiedFieldsJson['amount'] = price.amount;
          break;

        case 'pricingType':
          modifiedFieldsJson['pricingType'] = price.pricingType;
          break;

        case 'appliesTo':
          modifiedFieldsJson['appliesTo'] = price.appliesTo;
          break;

        case 'effectiveFrom':
          modifiedFieldsJson['effectiveFrom'] =
              price.effectiveFrom.toIso8601String();
          break;

        case 'effectiveTo':
          modifiedFieldsJson['effectiveTo'] =
              price.effectiveTo?.toIso8601String();
          break;
      }
    }

    // Identifier (always required)
    modifiedFieldsJson['priceCode'] = price.priceCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_price_api.php?priceCode=${price.priceCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((price.modifiedFields?.isNotEmpty ?? false) &&
            price.operationType != null &&
            price.operationType != 'none') {
          SyncQueueManager().enqueue(price);
        }
        price.syncStatus = true;
        price.operationType = 'none';
        price.modifiedFields = [];
        await price.save();
      } else {
        throw Exception('Failed to update students.');
      }
    } catch (e) {
      print('Error updating students: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _createProjectSaleTransactionInMySQL(
      ProjectSaleTransaction tx) async {
    final Map<String, dynamic> jsonData = _projectSaleTransactionToJson(tx);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_sale_transaction_api.php?transactionCode=${tx.transactionCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((tx.modifiedFields?.isNotEmpty ?? false) &&
            tx.operationType != null &&
            tx.operationType != 'none') {
          SyncQueueManager().enqueue(tx);
        }
        tx.syncStatus = true;
        tx.operationType = 'none';
        tx.modifiedFields = [];
        await tx.save();
      } else {
        throw Exception('Failed to create BatchUnit');
      }
    } catch (e) {
      print('BatchUnit create error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateProjectSaleTransactionInMySQL(
      ProjectSaleTransaction tx) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in tx.modifiedFields ?? []) {
      switch (field) {
        // 🔹 Core transaction fields
        case 'studentId':
          modifiedFieldsJson['studentId'] = tx.studentId;
          break;

        case 'projectCode':
          modifiedFieldsJson['projectCode'] = tx.projectCode;
          break;

        case 'projectItemCode':
          modifiedFieldsJson['projectItemCode'] = tx.projectItemCode;
          break;

        case 'batchCode':
          modifiedFieldsJson['batchCode'] = tx.batchCode;
          break;

        case 'sellUnitCode':
          modifiedFieldsJson['sellUnitCode'] = tx.sellUnitCode;
          break;

        case 'sellUnitNameSnapshot':
          modifiedFieldsJson['sellUnitNameSnapshot'] = tx.sellUnitNameSnapshot;
          break;

        case 'quantitySold':
          modifiedFieldsJson['quantitySold'] = tx.quantitySold;
          break;

        case 'unitSellingPrice':
          modifiedFieldsJson['unitSellingPrice'] = tx.unitSellingPrice;
          break;

        case 'totalAmount':
          modifiedFieldsJson['totalAmount'] = tx.totalAmount;
          break;

        case 'baseUnitsPerSellUnit':
          modifiedFieldsJson['baseUnitsPerSellUnit'] = tx.baseUnitsPerSellUnit;
          break;

        case 'totalBaseUnitsSold':
          modifiedFieldsJson['totalBaseUnitsSold'] = tx.totalBaseUnitsSold;
          break;

        case 'baseUnit':
          modifiedFieldsJson['baseUnit'] = tx.baseUnit;
          break;

        case 'baseUnitType':
          modifiedFieldsJson['baseUnitType'] = tx.baseUnitType.name;
          break;

        case 'transactionDate':
          modifiedFieldsJson['transactionDate'] =
              tx.transactionDate.toIso8601String();
          break;

        case 'paymentMethod':
          modifiedFieldsJson['paymentMethod'] = tx.paymentMethod;
          break;

        case 'reference':
          modifiedFieldsJson['reference'] = tx.reference;
          break;

        case 'amountPaid':
          modifiedFieldsJson['amountPaid'] = tx.amountPaid;
          break;

        case 'arrears':
          modifiedFieldsJson['arrears'] = tx.arrears;
          break;

        // 🔴 Soft delete
        case 'isDeleted':
          modifiedFieldsJson['isDeleted'] = tx.isDeleted;
          break;

        case 'deletedAt':
          modifiedFieldsJson['deletedAt'] =
              tx.deletedAt?.map((e) => e.toIso8601String()).toList();
          break;

        case 'restoredAt':
          modifiedFieldsJson['restoredAt'] =
              tx.restoredAt?.map((e) => e.toIso8601String()).toList();
          break;

        case 'deletedByUsers':
          modifiedFieldsJson['deletedByUsers'] = tx.deletedByUsers;
          break;

        case 'restoredByUsers':
          modifiedFieldsJson['restoredByUsers'] = tx.restoredByUsers;
          break;

        // 💳 Payment breakdown
        case 'paymentMethodCode':
          modifiedFieldsJson['paymentMethodCode'] = tx.paymentMethodCode;
          break;

        case 'methodType':
          modifiedFieldsJson['methodType'] = tx.methodType;
          break;

        case 'amountPaidInPaymentMethod':
          modifiedFieldsJson['amountPaidInPaymentMethod'] =
              tx.amountPaidInPaymentMethod;
          break;

        case 'currency':
          modifiedFieldsJson['currency'] = tx.currency;
          break;

        case 'provider':
          modifiedFieldsJson['provider'] = tx.provider;
          break;

        case 'referenceNumber':
          modifiedFieldsJson['referenceNumber'] = tx.referenceNumber;
          break;

        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = tx.phoneNumber;
          break;

        case 'accountNumber':
          modifiedFieldsJson['accountNumber'] = tx.accountNumber;
          break;

        case 'accountName':
          modifiedFieldsJson['accountName'] = tx.accountName;
          break;

        case 'paymentDatetransacted':
          modifiedFieldsJson['paymentDatetransacted'] =
              tx.paymentDatetransacted?.toIso8601String();
          break;

        // 🔁 Audit / financial logic
        case 'isReversed':
          modifiedFieldsJson['isReversed'] = tx.isReversed;
          break;

        case 'lineTransactionCodes':
          modifiedFieldsJson['lineTransactionCodes'] = tx.lineTransactionCodes;
          break;

        case 'financialType':
          modifiedFieldsJson['financialType'] = tx.financialType;
          break;

        case 'parentTransactionCode':
          modifiedFieldsJson['parentTransactionCode'] =
              tx.parentTransactionCode;
          break;

        case 'affectsStock':
          modifiedFieldsJson['affectsStock'] = tx.affectsStock;
          break;

        case 'createsObligation':
          modifiedFieldsJson['createsObligation'] = tx.createsObligation;
          break;

        case 'settlesObligation':
          modifiedFieldsJson['settlesObligation'] = tx.settlesObligation;
          break;
      }
    }

    // ✅ Always include identifier
    modifiedFieldsJson['transactionCode'] = tx.transactionCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_sale_transaction_api.php?transactionCode=${tx.transactionCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((tx.modifiedFields?.isNotEmpty ?? false) &&
            tx.operationType != null &&
            tx.operationType != 'none') {
          SyncQueueManager().enqueue(tx);
        }
        tx.syncStatus = true;
        tx.operationType = 'none';
        tx.modifiedFields = [];
        await tx.save();
      } else {
        throw Exception('Failed to update ProjectSaleTransaction');
      }
    } catch (e) {
      print('ProjectSaleTransaction update error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _createBatchSellUnitInMySQL(BatchSellUnit unit) async {
    final Map<String, dynamic> jsonData = _batchSellUnitToJson(unit);
    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_sell_unit_api.php?sellUnitCode=${unit.sellUnitCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((unit.modifiedFields?.isNotEmpty ?? false) &&
            unit.operationType != null &&
            unit.operationType != 'none') {
          SyncQueueManager().enqueue(unit);
        }
        unit.syncStatus = true;
        unit.operationType = 'none';
        unit.modifiedFields = [];
        await unit.save();
      } else {
        throw Exception('Failed to create BatchUnit');
      }
    } catch (e) {
      print('BatchUnit create error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateBatchSellUnitInMySQL(BatchSellUnit unit) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in unit.modifiedFields ?? []) {
      switch (field) {
        case 'batchCode':
          modifiedFieldsJson['batchCode'] = unit.batchCode;
          break;

        case 'unitName':
          modifiedFieldsJson['unitName'] = unit.unitName;
          break;

        case 'quantityMultiplier':
          modifiedFieldsJson['quantityMultiplier'] = unit.quantityMultiplier;
          break;

        case 'sellingPrice':
          modifiedFieldsJson['sellingPrice'] = unit.sellingPrice;
          break;

        case 'active':
          modifiedFieldsJson['active'] = unit.active;
          break;

        case 'deletedAt':
          modifiedFieldsJson['deletedAt'] = unit.deletedAt?.toIso8601String();
          break;

        case 'packagingLevel':
          modifiedFieldsJson['packagingLevel'] = unit.packagingLevel?.name;
          break;

        case 'baseUnitsPerSellUnit':
          modifiedFieldsJson['baseUnitsPerSellUnit'] =
              unit.baseUnitsPerSellUnit;
          break;

        case 'baseUnit':
          modifiedFieldsJson['baseUnit'] = unit.baseUnit;
          break;

        case 'baseUnitType':
          modifiedFieldsJson['baseUnitType'] = unit.baseUnitType?.name;
          break;
      }
    }

    // ✅ Always include identifier
    modifiedFieldsJson['sellUnitCode'] = unit.sellUnitCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_sell_unit_api.php?sellUnitCode=${unit.sellUnitCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((unit.modifiedFields?.isNotEmpty ?? false) &&
            unit.operationType != null &&
            unit.operationType != 'none') {
          SyncQueueManager().enqueue(unit);
        }
        unit.syncStatus = true;
        unit.operationType = 'none';
        unit.modifiedFields = [];
        await unit.save();
      } else {
        throw Exception('Failed to update BatchSellUnit');
      }
    } catch (e) {
      print('BatchSellUnit update error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _createPaymentMethodInMySQL(PaymentMethod pm) async {
    final Map<String, dynamic> jsonData = _paymentMethodToJson(pm);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/payment_method_api.php?paymentMethodCode=${pm.paymentMethodCode}'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((pm.modifiedFields?.isNotEmpty ?? false) &&
            pm.operationType != null &&
            pm.operationType != 'none') {
          SyncQueueManager().enqueue(pm);
        }
        pm.syncStatus = true;
        pm.operationType = 'none';
        pm.modifiedFields = [];
        await pm.save();
      } else {
        throw Exception('Failed to create BatchUnit');
      }
    } catch (e) {
      print('BatchUnit create error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updatePaymentMethodInMySQL(PaymentMethod pm) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in pm.modifiedFields ?? []) {
      switch (field) {
        case 'paymentMethodCode':
          modifiedFieldsJson['payment_method_code'] = pm.paymentMethodCode;
          break;

        case 'methodType':
          modifiedFieldsJson['method_type'] = pm.methodType;
          break;

        case 'amount':
          modifiedFieldsJson['amount'] = pm.amount;
          break;

        case 'currency':
          modifiedFieldsJson['currency'] = pm.currency;
          break;

        case 'provider':
          modifiedFieldsJson['provider'] = pm.provider;
          break;

        case 'reference':
          modifiedFieldsJson['reference'] = pm.reference;
          break;

        case 'phoneNumber':
          modifiedFieldsJson['phone_number'] = pm.phoneNumber;
          break;

        case 'accountNumber':
          modifiedFieldsJson['account_number'] = pm.accountNumber;
          break;

        case 'accountName':
          modifiedFieldsJson['account_name'] = pm.accountName;
          break;

        case 'paymentDate':
          modifiedFieldsJson['payment_date'] =
              pm.paymentDate?.toIso8601String();
          break;

        case 'isReversed':
          modifiedFieldsJson['is_reversed'] = pm.isReversed;
          break;
      }
    }

    // ✅ Always include identifier (use API expected format)
    modifiedFieldsJson['payment_method_code'] = pm.paymentMethodCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/payment_method_api.php?paymentMethodCode=${pm.paymentMethodCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((pm.modifiedFields?.isNotEmpty ?? false) &&
            pm.operationType != null &&
            pm.operationType != 'none') {
          SyncQueueManager().enqueue(pm);
        }
        pm.syncStatus = true;
        pm.operationType = 'none';
        pm.modifiedFields = [];
        await pm.save();
      } else {
        throw Exception('Failed to update PaymentMethod');
      }
    } catch (e) {
      print('PaymentMethod update error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _createReceiptSnapshotInMySQL(ReceiptSnapshot r) async {
    final Map<String, dynamic> jsonData = _receiptSnapshotToJson(r);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/receipt_snapshot_api.php?receiptCode=${r.receiptCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((r.modifiedFields?.isNotEmpty ?? false) &&
            r.operationType != null &&
            r.operationType != 'none') {
          SyncQueueManager().enqueue(r);
        }
        r.syncStatus = true;
        r.operationType = 'none';
        r.modifiedFields = [];

        await r.save();
      } else {
        throw Exception('Failed to create ReceiptSnapshot');
      }
    } catch (e) {
      print('ReceiptSnapshot create error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateReceiptSnapshotInMySQL(ReceiptSnapshot receipt) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in receipt.modifiedFields ?? []) {
      switch (field) {
        case 'receiptDate':
          modifiedFieldsJson['receiptDate'] =
              receipt.receiptDate.toIso8601String();
          break;

        case 'cashier':
          modifiedFieldsJson['cashier'] = receipt.cashier;
          break;

        case 'totalExpected':
          modifiedFieldsJson['totalExpected'] = receipt.totalExpected;
          break;

        case 'totalPaid':
          modifiedFieldsJson['totalPaid'] = receipt.totalPaid;
          break;

        case 'amountReceived':
          modifiedFieldsJson['amountReceived'] = receipt.amountReceived;
          break;

        case 'change':
          modifiedFieldsJson['change'] = receipt.change;
          break;

        case 'currency':
          modifiedFieldsJson['currency'] = receipt.currency;
          break;

        case 'receiptLinesJson':
          modifiedFieldsJson['receiptLinesJson'] = receipt.receiptLinesJson;
          break;

        case 'isReprint':
          modifiedFieldsJson['isReprint'] = receipt.isReprint;
          break;

        case 'studentName':
          modifiedFieldsJson['studentName'] = receipt.studentName;
          break;

        case 'studentClass':
          modifiedFieldsJson['studentClass'] = receipt.studentClass;
          break;
      }
    }

    // ✅ Always include identifier
    modifiedFieldsJson['receiptCode'] = receipt.receiptCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/receipt_snapshot_api.php?receiptCode=${receipt.receiptCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((receipt.modifiedFields?.isNotEmpty ?? false) &&
            receipt.operationType != null &&
            receipt.operationType != 'none') {
          SyncQueueManager().enqueue(receipt);
        }
        receipt.syncStatus = true;
        receipt.operationType = 'none';
        receipt.modifiedFields = [];
        await receipt.save();
      } else {
        throw Exception('Failed to update ReceiptSnapshot');
      }
    } catch (e) {
      print('ReceiptSnapshot update error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
  //=================== Exceptions  sync =========================

  Future<void> _createExceptionInMySQL(ExceptionalStudents newClass) async {
    final Map<String, dynamic> jsonData = _exceptionsToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/exceptions_api.php?exceptionId=${newClass.exceptionId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('exceptionId ${newClass.exceptionId} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
// Log status and body for better debugging
        print(
            'Exception: Failed to create exceptionId. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to create exceptionId. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating exceptionId: $e');
      print('Stack Trace: $stackTrace');
      print('exceptionId Details:');
      print('exceptionId: ${newClass.exceptionId}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateExceptionInMySQL(ExceptionalStudents newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'exceptionId':
          modifiedFieldsJson['exceptionId'] = newClass.exceptionId;
          break;
        case 'exceptionName':
          modifiedFieldsJson['exceptionName'] = newClass.exceptionName;
          break;
        case 'exceptionStatus':
          modifiedFieldsJson['exceptionStatus'] = newClass.exceptionStatus;
          break;
        case 'exceptionType':
          modifiedFieldsJson['exceptionType'] = newClass.exceptionType;
          break;

        case 'exceptionFigure':
          modifiedFieldsJson['exceptionFigure'] = newClass.exceptionFigure;
          break;

        case 'terms':
          modifiedFieldsJson['terms'] = newClass.terms != null
              ? jsonEncode(newClass.terms) // Encode List<String> to JSON
              : null;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['receiptNumber'] = newClass.exceptionId;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/exceptions_api.php?exceptionId=${newClass.exceptionId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('exceptionId ${newClass.exceptionId} updated successfully.');
        // Update syncStatus and operationType in Hive

        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.exceptionId}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  //=================== teachers payment  sync =========================

  Future<void> _createTeacherPaymentInMySQL(TeacherPayment newClass) async {
    final Map<String, dynamic> jsonData = _teacherPaymentclassToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTeacherPaymentInMySQL(TeacherPayment newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'studentName':
          modifiedFieldsJson['studentName'] = newClass.studentName;
          break;
        case 'studentSurname':
          modifiedFieldsJson['studentSurname'] = newClass.studentSurname;
          break;
        case 'studentClass':
          modifiedFieldsJson['studentClass'] = newClass.studentClass;
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;

        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;

        case 'amountToPay':
          modifiedFieldsJson['amountToPay'] = newClass.amountToPay;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              newClass.paymentDate.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'receiptNumber':
          modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} updated successfully.');
        // Update syncStatus and operationType in Hive

        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== techers payment purpose sync =========================

  Future<void> _createTeacherPaymentPurposeInMySQL(
      TeacherPaymentsPurposes newClass) async {
    final Map<String, dynamic> jsonData =
        _teacherPaymentsPurposeToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create IdNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTeacherPaymentPurposeInMySQL(
      TeacherPaymentsPurposes newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;
        case 'purposeCode':
          modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
          break;
        case 'purposeAmount':
          modifiedFieldsJson['purposeAmount'] = newClass.purposeAmount;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;

        case 'associatedStaff':
          modifiedFieldsJson['associatedStaff'] = newClass.associatedStaff !=
                  null
              ? jsonEncode(newClass
                  .associatedStaff) // Explicit JSON encode for associatedStaff
              : null;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update purposeCode.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== techers  sync =========================

  Future<void> _createTeacherInMySQL(Teachers newClass) async {
    final Map<String, dynamic> jsonData = _teacherToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php?IdNumber=${newClass.IdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('IdNumber ${newClass.IdNumber} created successfully.');
        // Update syncStatus and operationType in Hive

        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create IdNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating IdNumber: $e');
      print('Stack Trace: $stackTrace');
      print('IdNumber Details:');
      print('IdNumber: ${newClass.IdNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTeacherInMySQL(Teachers newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'name':
          modifiedFieldsJson['name'] = newClass.name;
          break;
        case 'surname':
          modifiedFieldsJson['surname'] = newClass.surname;
          break;
        case 'IdNumber':
          modifiedFieldsJson['IdNumber'] = newClass.IdNumber;
          break;
        case 'assignedClass':
          modifiedFieldsJson['assignedClass'] = newClass.assignedClass;
          break;
        case 'assignedClasses':
          modifiedFieldsJson['assignedClasses'] =
              newClass.assignedClasses != null
                  ? jsonEncode(newClass.assignedClasses) // JSON encode the list
                  : null;
          break;
        case 'gender':
          modifiedFieldsJson['gender'] = newClass.gender;
          break;
        case 'dateOfBirth':
          modifiedFieldsJson['dateOfBirth'] =
              newClass.dateOfBirth.toIso8601String();
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;
        case 'isPaid':
          modifiedFieldsJson['isPaid'] = newClass.isPaid;
          break;
        case 'paymentAmount':
          modifiedFieldsJson['paymentAmount'] = newClass.paymentAmount;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              newClass.paymentDate?.toIso8601String();
          break;
        case 'email':
          modifiedFieldsJson['email'] = newClass.email;
          break;
        case 'address':
          modifiedFieldsJson['address'] = newClass.address;
          break;
        case 'hireDate':
          modifiedFieldsJson['hireDate'] = newClass.hireDate.toIso8601String();
          break;
        case 'qualifications':
          modifiedFieldsJson['qualifications'] = newClass.qualifications;
          break;
        case 'employmentStatus':
          modifiedFieldsJson['employmentStatus'] = newClass.employmentStatus;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'terms':
          modifiedFieldsJson['terms'] = newClass.terms != null
              ? jsonEncode(newClass.terms) // Encode List<String> to JSON
              : null;
          break;

        // Add other fields as needed in this format
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['IdNumber'] = newClass.IdNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php?IdNumber=${newClass.IdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('IdNumber ${newClass.IdNumber} updated successfully.');
        // Update syncStatus and operationType in Hive

        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update IdNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating IdNumber: $e');
      print('Stack Trace: $stackTrace');
      print('IdNumber Details:');
      print('IdNumber: ${newClass.IdNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== student payment sync =========================

  Future<void> _createStudentPaymentInMySQL(StudentPayment newClass) async {
    final Map<String, dynamic> jsonData = _studentPaymentToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} created successfully.');
        // Update syncStatus and operationType in Hive

        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateStudentPaymentInMySQL(StudentPayment newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'studentName':
          modifiedFieldsJson['studentName'] = newClass.studentName;
          break;
        case 'studentSurname':
          modifiedFieldsJson['studentSurname'] = newClass.studentSurname;
          break;
        case 'studentClass':
          modifiedFieldsJson['studentClass'] = newClass.studentClass;
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;

        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;

        case 'amountToPay':
          modifiedFieldsJson['amountToPay'] = newClass.amountToPay;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              newClass.paymentDate.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'receiptNumber':
          modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
          break;
        case 'username':
          modifiedFieldsJson['username'] = newClass.username;
          break;
        case 'role':
          modifiedFieldsJson['role'] = newClass.role;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} updated successfully.');
        // Update syncStatus and operationType in Hive

        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
  //=================== purpose sync =========================

  Future<void> _createPaymentPurposeInMySQL(PaymentPurpose newClass) async {
    final Map<String, dynamic> jsonData = _paymentPurposeToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create purposeCode.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updatePaymentPurposeInMySQL(PaymentPurpose newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;
        case 'purposeAmount':
          modifiedFieldsJson['purposeAmount'] = newClass.purposeAmount;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'associatedClasses':
          modifiedFieldsJson['associatedClasses'] =
              jsonEncode(newClass.associatedClasses);
          break;

        case 'purposeCode':
          modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
          break;
        case 'exceptions':
          modifiedFieldsJson['exceptions'] = newClass.exceptions != null
              ? jsonEncode(newClass.exceptions!
                  .map((e) => _exceptionsToJson(e))
                  .toList())
              : null;
          break;
        case 'forNewcomersOnly':
          modifiedFieldsJson['forNewcomersOnly'] = newClass.forNewcomersOnly;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update purposeCode.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== users sync =========================

  Future<void> _createUserInMySQL(User newClass) async {
    final Map<String, dynamic> jsonData = _userToJson(newClass);

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newClass.userCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Users ${newClass.userCode} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create Users.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating Users: $e');
      print('Stack Trace: $stackTrace');
      print('User Details:');
      print('UserCode: ${newClass.userCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateUserInMySQL(User newClass) async {
    // final Map<String, dynamic> jsonData = _userToJson(newClass);

    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'username':
          modifiedFieldsJson['username'] = newClass.username;
          break;
        case 'password':
          modifiedFieldsJson['password'] = newClass.password;
          break;
        case 'role':
          modifiedFieldsJson['role'] = newClass.role;
          break;
        case 'securityQuestions':
          modifiedFieldsJson['securityQuestions'] =
              jsonEncode(newClass.securityQuestions);
          break;
        case 'securityAnswers':
          modifiedFieldsJson['securityAnswers'] =
              jsonEncode(newClass.securityAnswers);
          break;
        case 'phone':
          modifiedFieldsJson['phone'] = newClass.phone;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'userCode':
          modifiedFieldsJson['userCode'] = newClass.userCode;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['userCode'] = newClass.userCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newClass.userCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Users ${newClass.userCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update users.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating Users: $e');
      print('Stack Trace: $stackTrace');
      print('User Details:');
      print('UserCode: ${newClass.userCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== students sync =========================

  Future<void> _createStudentsInMySQL(Student newClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newClass.studentIdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Students ${newClass.studentIdNumber} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create students.');
      }
    } catch (e) {
      print('Error creating students: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateStudentsInMySQL(Student newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'name':
          modifiedFieldsJson['name'] = newClass.name;
          break;
        case 'surname':
          modifiedFieldsJson['surname'] = newClass.surname;
          break;
        case 'regNumber':
          modifiedFieldsJson['regNumber'] = newClass.regNumber;
          break;
        case 'class_':
          modifiedFieldsJson['class'] = newClass.class_;
          break;
        case 'gender':
          modifiedFieldsJson['gender'] = newClass.gender;
          break;
        case 'age':
          modifiedFieldsJson['age'] = newClass.age.toIso8601String();
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;
        case 'paymentStatus':
          modifiedFieldsJson['paymentStatus'] = newClass.paymentStatus;
          break;
        case 'isPresent':
          modifiedFieldsJson['isPresent'] = newClass.isPresent;
          break;
        case 'presentDates':
          modifiedFieldsJson['presentDates'] = jsonEncode(newClass.presentDates
              .map((date) => date.toIso8601String())
              .toList());
          break;
        case 'absentDates':
          modifiedFieldsJson['absentDates'] = jsonEncode(newClass.absentDates
              .map((date) => date.toIso8601String())
              .toList());
          break;
        case 'id':
          modifiedFieldsJson['id'] = newClass.id;
          break;
        case 'physicalAddress':
          modifiedFieldsJson['physicalAddress'] = newClass.physicalAddress;
          break;
        case 'formerSchool':
          modifiedFieldsJson['formerSchool'] = newClass.formerSchool;
          break;
        case 'religion':
          modifiedFieldsJson['religion'] = newClass.religion;
          break;
        case 'denomination':
          modifiedFieldsJson['denomination'] = newClass.denomination;
          break;
        case 'studentIdNumber':
          modifiedFieldsJson['studentIdNumber'] = newClass.studentIdNumber;
          break;
        case 'nationalIdNumber':
          modifiedFieldsJson['nationalIdNumber'] = newClass.nationalIdNumber;
          break;
        case 'nationality':
          modifiedFieldsJson['nationality'] = newClass.nationality;
          break;
        case 'district':
          modifiedFieldsJson['district'] = newClass.district;
          break;
        case 'previousSchoolPerformanceResults':
          modifiedFieldsJson['previousSchoolPerformanceResults'] =
              newClass.previousSchoolPerformanceResults;
          break;
        case 'enrollmentStatus':
          modifiedFieldsJson['enrollmentStatus'] = newClass.enrollmentStatus;
          break;
        case 'emergencyContactName':
          modifiedFieldsJson['emergencyContactName'] =
              newClass.emergencyContactName;
          break;
        case 'emergencyContactNumber':
          modifiedFieldsJson['emergencyContactNumber'] =
              newClass.emergencyContactNumber;
          break;
        case 'exceptions':
          // ✅ Convert List<ExceptionalStudents> to JSON
          modifiedFieldsJson['exceptions'] = newClass.exceptions != null
              ? jsonEncode(newClass.exceptions!
                  .map((e) => _exceptionsToJson(e))
                  .toList())
              : null;
          break;
        case 'isNewComer':
          modifiedFieldsJson['isNewComer'] = newClass.isNewComer;
          break;

        case 'isNewComerFrom':
          modifiedFieldsJson['isNewComerFrom'] =
              newClass.isNewComerFrom?.toIso8601String();
          break;

        case 'isNewComerUntil':
          modifiedFieldsJson['isNewComerUntil'] =
              newClass.isNewComerUntil?.toIso8601String();
          break;
        case 'terms':
          modifiedFieldsJson['terms'] = newClass.terms != null
              ? jsonEncode(newClass.terms) // Encode List<String> to JSON
              : null;
          break;
        // Add other fields as needed in this format
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['studentIdNumber'] = newClass.studentIdNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newClass.studentIdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Students ${newClass.studentIdNumber} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update students.');
      }
    } catch (e) {
      print('Error updating students: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//==================== withdrawal sync ======================

  Future<void> _createWithdrawalsInMySQL(Withdrawal newClass) async {
    final Map<String, dynamic> jsonData = _withdrawalToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newClass.withdrawalCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Withdrawals ${newClass.withdrawalCode} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create withdrawals_information.');
      }
    } catch (e) {
      print('Error creating Withdrawal: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateWithdrawalsInMySQL(Withdrawal newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'amount':
          modifiedFieldsJson['amount'] = newClass.amount;
          break;
        case 'withdrawalPurpose':
          modifiedFieldsJson['withdrawalPurpose'] = newClass.withdrawalPurpose;
          break;
        case 'withdrawalCode':
          modifiedFieldsJson['withdrawalCode'] = newClass.withdrawalCode;
          break;
        case 'date':
          modifiedFieldsJson['date'] = newClass.date.toIso8601String();
          break;

        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['withdrawalCode'] = newClass.withdrawalCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newClass.withdrawalCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Withdrawals ${newClass.withdrawalCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        await newClass.save();
        newClass.modifiedFields = [];
      } else {
        throw Exception('Failed to update withdrawals_information.');
      }
    } catch (e) {
      print('Error updating Withdrawal: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//====================== terms sync ==========================
  Future<void> _createTermsInMySQL(Terms newClass) async {
    final Map<String, dynamic> jsonData = _termsToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newClass.termId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Terms ${newClass.termId} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create terms_information.');
      }
    } catch (e) {
      print('Error creating Terms: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTermsInMySQL(Terms newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'termName':
          modifiedFieldsJson['termName'] = newClass.termName;
          break;
        case 'startDate':
          modifiedFieldsJson['startDate'] =
              newClass.startDate.toIso8601String();
          break;
        case 'endDate':
          modifiedFieldsJson['endDate'] = newClass.endDate?.toIso8601String();
          break;
        case 'isActive':
          modifiedFieldsJson['isActive'] = newClass.isActive;
          break;
        case 'status':
          modifiedFieldsJson['status'] = newClass.status;
          break;

        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['termId'] = newClass.termId;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newClass.termId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Terms ${newClass.termId} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to update terms_information.');
      }
    } catch (e) {
      print('Error updating Terms: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//============== classes sync ==============================
  Future<void> _createClassInMySQL(Classes newClass) async {
    final Map<String, dynamic> jsonData = _classToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php?classCode=${newClass.classCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to create classes_information.');
      }
    } catch (e) {
      print('Error creating classes_information: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateClassesInMySQL(Classes updatedClass) async {
    // Extract the modified fields and their values
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in updatedClass.modifiedFields ?? []) {
      switch (field) {
        case 'className':
          modifiedFieldsJson['className'] = updatedClass.className;
          break;
        case 'date':
          modifiedFieldsJson['date'] = updatedClass.date.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedClass.termId;
          break;
        case 'terms':
          modifiedFieldsJson['terms'] = updatedClass.terms != null
              ? jsonEncode(updatedClass.terms) // Encode List<String> to JSON
              : null;
          break;
        // Add cases for other fields as needed
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['classCode'] = updatedClass.classCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php?classCode=${updatedClass.classCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Classes ${updatedClass.classCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((updatedClass.modifiedFields?.isNotEmpty ?? false) &&
            updatedClass.operationType != null &&
            updatedClass.operationType != 'none') {
          SyncQueueManager().enqueue(updatedClass);
        }
        updatedClass.syncStatus = true;
        updatedClass.operationType = 'none';
        updatedClass.modifiedFields = [];

        await updatedClass.save();
      } else {
        throw Exception('Failed to update Class.');
      }
    } catch (e) {
      print('Error updating Class: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//================= schools sync ===========================

  Future<void> _createSchoolInMySQL(School newClass) async {
    final Map<String, dynamic> jsonData = _schoolToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${newClass.schoolCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'school_information ${newClass.schoolCode} created successfully.');
        // Update syncStatus and operationType in Hive
        if ((newClass.modifiedFields?.isNotEmpty ?? false) &&
            newClass.operationType != null &&
            newClass.operationType != 'none') {
          SyncQueueManager().enqueue(newClass);
        }
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create school_information.');
      }
    } catch (e) {
      print('Error creating school_information: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateSchoolInMySQL(School updatedClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in updatedClass.modifiedFields ?? []) {
      switch (field) {
        case 'schoolName':
          modifiedFieldsJson['schoolName'] = updatedClass.schoolName;
          break;
        case 'schoolAddress':
          modifiedFieldsJson['schoolAddress'] = updatedClass.schoolAddress;
          break;
        case 'schoolPhoneNumber':
          modifiedFieldsJson['schoolPhoneNumber'] =
              updatedClass.schoolPhoneNumber;
          break;
        case 'schoolEmail':
          modifiedFieldsJson['schoolEmail'] = updatedClass.schoolEmail;
          break;

        case 'termId':
          modifiedFieldsJson['termId'] = updatedClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['schoolCode'] = updatedClass.schoolCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${updatedClass.schoolCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Schools ${updatedClass.schoolCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        if ((updatedClass.modifiedFields?.isNotEmpty ?? false) &&
            updatedClass.operationType != null &&
            updatedClass.operationType != 'none') {
          SyncQueueManager().enqueue(updatedClass);
        }
        updatedClass.syncStatus = true;
        updatedClass.operationType = 'none';
        updatedClass.modifiedFields = [];

        await updatedClass.save();
      } else {
        throw Exception('Failed to update school.');
      }
    } catch (e) {
      print('Error updating school: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  //============================== domains ==========================

  Future<void> _createDomainInMySQL(DomainRecord domain) async {
    final Map<String, dynamic> jsonData = _domainsToJson(domain);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/domain_api.php?domainName=${domain.domainName}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((domain.modifiedFields?.isNotEmpty ?? false) &&
            domain.operationType != null &&
            domain.operationType != 'none') {
          SyncQueueManager().enqueue(domain);
        }
        domain.syncStatus = true;
        domain.operationType = 'none';
        domain.modifiedFields = [];
        await domain.save();
      } else {
        throw Exception('Failed to create domain.');
      }
    } catch (e) {
      print('Error creating domain: \$e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateDomainInMySQL(DomainRecord domain) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in domain.modifiedFields ?? []) {
      switch (field) {
        case 'areDomainsActive':
          modifiedFieldsJson['areDomainsActive'] = domain.areDomainsActive;
          break;
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['domainName'] = domain.domainName;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/domain_api.php?domainName=${domain.domainName}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((domain.modifiedFields?.isNotEmpty ?? false) &&
            domain.operationType != null &&
            domain.operationType != 'none') {
          SyncQueueManager().enqueue(domain);
        }
        domain.syncStatus = true;
        domain.operationType = 'none';
        domain.modifiedFields = [];
        await domain.save();
      } else {
        throw Exception('Failed to update domain.');
      }
    } catch (e) {
      print('Error updating domain: \$e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
  //============================== accounts type ==========================

  Future<void> _createAccountInMySQL(Account acc) async {
    final Map<String, dynamic> jsonData = _accountsToJson(acc);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php?accountCode=${acc.accountCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((acc.modifiedFields?.isNotEmpty ?? false) &&
            acc.operationType != null &&
            acc.operationType != 'none') {
          SyncQueueManager().enqueue(acc);
        }
        acc.syncStatus = true;
        acc.operationType = 'none';
        acc.modifiedFields = [];
        await acc.save();
      } else {
        throw Exception('Failed to create account.');
      }
    } catch (e) {
      print('Error creating account: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateAccountInMySQL(Account acc) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in acc.modifiedFields ?? []) {
      switch (field) {
        case 'accountType':
          modifiedFieldsJson['accountType'] = acc.accountType;
          break;
        case 'accountSubType':
          modifiedFieldsJson['accountSubType'] = acc.accountSubType;
          break;
        case 'accountName':
          modifiedFieldsJson['accountName'] = acc.accountName;
          break;

        case 'lastModified':
          modifiedFieldsJson['lastModified'] =
              acc.lastModified?.toIso8601String();
          break;
        case 'isALiquidAccount':
          modifiedFieldsJson['isALiquidAccount'] = acc.isALiquidAccount;
          break;
      }
    }

    // Always include the unique identifier
    modifiedFieldsJson['accountCode'] = acc.accountCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php?accountCode=${acc.accountCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((acc.modifiedFields?.isNotEmpty ?? false) &&
            acc.operationType != null &&
            acc.operationType != 'none') {
          SyncQueueManager().enqueue(acc);
        }
        acc.syncStatus = true;
        acc.operationType = 'none';
        acc.modifiedFields = [];
        await acc.save();
      } else {
        throw Exception('Failed to update account.');
      }
    } catch (e) {
      print('Error updating account: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//============================== assets ==========================

  Future<void> _createAssetInMySQL(Asset asset) async {
    final Map<String, dynamic> jsonData = _assetsToJson(asset);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/asset_api.php?assetCode=${asset.assetCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((asset.modifiedFields?.isNotEmpty ?? false) &&
            asset.operationType != null &&
            asset.operationType != 'none') {
          SyncQueueManager().enqueue(asset);
        }
        asset.syncStatus = true;
        asset.operationType = 'none';
        asset.modifiedFields = [];
        await asset.save();
      } else {
        throw Exception('Failed to create asset.');
      }
    } catch (e) {
      print('Error creating asset: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateAssetInMySQL(Asset asset) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in asset.modifiedFields ?? []) {
      switch (field) {
        case 'assetName':
          modifiedFieldsJson['assetName'] = asset.assetName;
          break;
        case 'assetType':
          modifiedFieldsJson['assetType'] = asset.assetType;
          break;
        case 'assetSubType':
          modifiedFieldsJson['assetSubType'] = asset.assetSubType;
          break;

        case 'assetSerialNo':
          modifiedFieldsJson['assetSerialNo'] = asset.assetSerialNo;
          break;
        case 'acquisitionDate':
          modifiedFieldsJson['acquisitionDate'] =
              asset.acquisitionDate?.toIso8601String();
          break;
        case 'acquisitionCost':
          modifiedFieldsJson['acquisitionCost'] = asset.acquisitionCost;
          break;
        case 'acquisitionMethod':
          modifiedFieldsJson['acquisitionMethod'] = asset.acquisitionMethod;
          break;
        case 'department':
          modifiedFieldsJson['department'] = asset.department;
          break;
        case 'location':
          modifiedFieldsJson['location'] = asset.location;
          break;
        case 'depreciationRate':
          modifiedFieldsJson['depreciationRate'] = asset.depreciationRate;
          break;
        case 'depreciationMethod':
          modifiedFieldsJson['depreciationMethod'] = asset.depreciationMethod;
          break;
        case 'lastDepreciationDate':
          modifiedFieldsJson['lastDepreciationDate'] =
              asset.lastDepreciationDate?.toIso8601String();
          break;
        case 'accumulatedDepreciation':
          modifiedFieldsJson['accumulatedDepreciation'] =
              asset.accumulatedDepreciation;
          break;
        case 'bookValue':
          modifiedFieldsJson['bookValue'] = asset.bookValue;
          break;
        case 'isImpaired':
          modifiedFieldsJson['isImpaired'] = asset.isImpaired;
          break;
        case 'impairmentLoss':
          modifiedFieldsJson['impairmentLoss'] = asset.impairmentLoss;
          break;
        case 'revaluationDate':
          modifiedFieldsJson['revaluationDate'] =
              asset.revaluationDate?.toIso8601String();
          break;
        case 'revaluationAmount':
          modifiedFieldsJson['revaluationAmount'] = asset.revaluationAmount;
          break;
        case 'lastMaintenanceDate':
          modifiedFieldsJson['lastMaintenanceDate'] =
              asset.lastMaintenanceDate?.toIso8601String();
          break;
        case 'maintenanceCost':
          modifiedFieldsJson['maintenanceCost'] = asset.maintenanceCost;
          break;
        case 'maintenanceDescription':
          modifiedFieldsJson['maintenanceDescription'] =
              asset.maintenanceDescription;
          break;
        case 'capitalImprovementCost':
          modifiedFieldsJson['capitalImprovementCost'] =
              asset.capitalImprovementCost;
          break;
        case 'capitalImprovementDescription':
          modifiedFieldsJson['capitalImprovementDescription'] =
              asset.capitalImprovementDescription;
          break;
        case 'disposalDate':
          modifiedFieldsJson['disposalDate'] =
              asset.disposalDate?.toIso8601String();
          break;
        case 'disposalProceeds':
          modifiedFieldsJson['disposalProceeds'] = asset.disposalProceeds;
          break;
        case 'disposalReason':
          modifiedFieldsJson['disposalReason'] = asset.disposalReason;
          break;
        case 'gainOrLossOnDisposal':
          modifiedFieldsJson['gainOrLossOnDisposal'] =
              asset.gainOrLossOnDisposal;
          break;
        case 'isLeased':
          modifiedFieldsJson['isLeased'] = asset.isLeased;
          break;
        case 'leaseType':
          modifiedFieldsJson['leaseType'] = asset.leaseType;
          break;
        case 'leaseStartDate':
          modifiedFieldsJson['leaseStartDate'] =
              asset.leaseStartDate?.toIso8601String();
          break;
        case 'leaseEndDate':
          modifiedFieldsJson['leaseEndDate'] =
              asset.leaseEndDate?.toIso8601String();
          break;
        case 'leasePaymentAmount':
          modifiedFieldsJson['leasePaymentAmount'] = asset.leasePaymentAmount;
          break;
        case 'lastAuditDate':
          modifiedFieldsJson['lastAuditDate'] =
              asset.lastAuditDate?.toIso8601String();
          break;
        case 'notes':
          modifiedFieldsJson['notes'] = asset.notes;
          break;
        case 'lastModified':
          modifiedFieldsJson['lastModified'] =
              asset.lastModified?.toIso8601String();
          break;
        case 'usefulLife':
          modifiedFieldsJson['usefulLife'] = asset.usefulLife;
          break;
        case 'hasDebitBalance':
          modifiedFieldsJson['hasDebitBalance'] = asset.hasDebitBalance;
          break;
        case 'hasCreditBalance':
          modifiedFieldsJson['hasCreditBalance'] = asset.hasCreditBalance;
          break;
        case 'option':
          modifiedFieldsJson['option'] = asset.option;
          break;
      }
    }

    modifiedFieldsJson['assetCode'] = asset.assetCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/asset_api.php?assetCode=${asset.assetCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((asset.modifiedFields?.isNotEmpty ?? false) &&
            asset.operationType != null &&
            asset.operationType != 'none') {
          SyncQueueManager().enqueue(asset);
        }
        asset.syncStatus = true;
        asset.operationType = 'none';
        asset.modifiedFields = [];
        await asset.save();
      } else {
        throw Exception('Failed to update asset.');
      }
    } catch (e) {
      print('Error updating asset: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//============================== projects ==========================

  Future<void> _createProjectInMySQL(Project p) async {
    final Map<String, dynamic> jsonData = _projectsToJson(p);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php?projectCode=${p.projectCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((p.modifiedFields?.isNotEmpty ?? false) &&
            p.operationType != null &&
            p.operationType != 'none') {
          SyncQueueManager().enqueue(p);
        }
        p.syncStatus = true;
        p.operationType = 'none';
        p.modifiedFields = [];
        await p.save();
      } else {
        throw Exception('Failed to create project.');
      }
    } catch (e) {
      print('Error creating project: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateProjectInMySQL(Project p) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in p.modifiedFields ?? []) {
      switch (field) {
        case 'name':
          modifiedFieldsJson['name'] = p.name;
          break;

        case 'description':
          modifiedFieldsJson['description'] = p.description;
          break;

        case 'status':
          modifiedFieldsJson['status'] = p.status;
          break;

        case 'updatedAt':
          modifiedFieldsJson['updatedAt'] = p.updatedAt.toIso8601String();
          break;

        case 'lastModified':
          modifiedFieldsJson['lastModified'] =
              p.lastModified?.toIso8601String();
          break;

        // ✅ NEW FIELDS
        case 'projectType':
          modifiedFieldsJson['projectType'] = p.projectType;
          break;

        case 'participationType':
          modifiedFieldsJson['participationType'] = p.participationType;
          break;

        case 'studentPayable':
          modifiedFieldsJson['studentPayable'] = p.studentPayable;
          break;
      }
    }

    // ✅ Always include identifier
    modifiedFieldsJson['projectCode'] = p.projectCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php?projectCode=${p.projectCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((p.modifiedFields?.isNotEmpty ?? false) &&
            p.operationType != null &&
            p.operationType != 'none') {
          SyncQueueManager().enqueue(p);
        }

        p.syncStatus = true;
        p.operationType = 'none';
        p.modifiedFields = [];
        await p.save();
      } else {
        throw Exception('Failed to update project.');
      }
    } catch (e) {
      print('Error updating project: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//============================== dailyActivities ==========================

  Future<void> _createDailyActivityInMySQL(DailyActivity a) async {
    final Map<String, dynamic> jsonData = _daily_activitiesToJson(a);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_daily_activity_api.php?projectDailyActiviyCode=${a.projectDailyActiviyCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((a.modifiedFields?.isNotEmpty ?? false) &&
            a.operationType != null &&
            a.operationType != 'none') {
          SyncQueueManager().enqueue(a);
        }
        a.syncStatus = true;
        a.operationType = 'none';
        a.modifiedFields = [];
        await a.save();
      } else {
        throw Exception('Failed to create daily activity.');
      }
    } catch (e) {
      print('Error creating daily activity: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateDailyActivityInMySQL(DailyActivity a) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in a.modifiedFields ?? []) {
      switch (field) {
        case 'projectCode':
          modifiedFieldsJson['projectCode'] = a.projectCode;
          break;
        case 'date':
          modifiedFieldsJson['date'] = a.date.toIso8601String();
          break;
        case 'type':
          modifiedFieldsJson['type'] = a.type;
          break;
        case 'description':
          modifiedFieldsJson['description'] = a.description;
          break;
        case 'amount':
          modifiedFieldsJson['amount'] = a.amount;
          break;
      }
    }

    modifiedFieldsJson['projectDailyActiviyCode'] = a.projectDailyActiviyCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_daily_activity_api.php?projectDailyActiviyCode=${a.projectDailyActiviyCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((a.modifiedFields?.isNotEmpty ?? false) &&
            a.operationType != null &&
            a.operationType != 'none') {
          SyncQueueManager().enqueue(a);
        }
        a.syncStatus = true;
        a.operationType = 'none';
        a.modifiedFields = [];
        await a.save();
      } else {
        throw Exception('Failed to update daily activity.');
      }
    } catch (e) {
      print('Error updating daily activity: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//============================== projectStudentPayments ==========================

//============================== projectItems ==========================

  Future<void> _createProjectItemInMySQL(ProjectItem i) async {
    final Map<String, dynamic> jsonData = _projectItemsToJson(i);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php?projectItemCode=${i.projectItemCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if ((i.modifiedFields?.isNotEmpty ?? false) &&
            i.operationType != null &&
            i.operationType != 'none') {
          SyncQueueManager().enqueue(i);
        }
        i.syncStatus = true;
        i.operationType = 'none';
        i.modifiedFields = [];
        await i.save();
      } else {
        throw Exception('Failed to create project item.');
      }
    } catch (e) {
      print('Error creating project item: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateProjectItemInMySQL(ProjectItem i) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in i.modifiedFields ?? []) {
      switch (field) {
        case 'projectCode':
          modifiedFieldsJson['projectCode'] = i.projectCode;
          break;

        case 'name':
          modifiedFieldsJson['name'] = i.name;
          break;

        // ✅ NEW FIELDS
        case 'itemType':
          modifiedFieldsJson['itemType'] = i.itemType;
          break;

        case 'active':
          modifiedFieldsJson['active'] = i.active;
          break;

        case 'trackStock':
          modifiedFieldsJson['trackStock'] = i.trackStock;
          break;

        case 'lastModified':
          modifiedFieldsJson['lastModified'] =
              i.lastModified?.toIso8601String();
          break;
      }
    }

    // ✅ Always include identifier
    modifiedFieldsJson['projectItemCode'] = i.projectItemCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php?projectItemCode=${i.projectItemCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if ((i.modifiedFields?.isNotEmpty ?? false) &&
            i.operationType != null &&
            i.operationType != 'none') {
          SyncQueueManager().enqueue(i);
        }

        i.syncStatus = true;
        i.operationType = 'none';
        i.modifiedFields = [];
        await i.save();
      } else {
        throw Exception('Failed to update project item.');
      }
    } catch (e) {
      print('Error updating project item: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();

    final isLargeScreen =
        MediaQuery.of(context).size.width > 800; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Synchronization'),
      body: LayoutBuilder(builder: (context, constraints) {
        return Row(
          children: [
            if (constraints.maxWidth >= 540)
              SizedBox(
                width: 250,
                child: CustomDrawerAdmin(loggedInUser: loggedInUser),
              ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.fromRGBO(0, 233, 254, 1),
                              Color.fromARGB(0, 233, 254, 1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 600),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Sync All Records Button

                                    buildFutureSchoolsWidget(
                                        isLargeScreen: isLargeScreen),

                                    _isSyncings
                                        ? const Center(
                                            child: SizedBox(
                                              height:
                                                  50, // Specify the size of the CircularProgressIndicator
                                              width: 50,
                                              child: CircularProgressIndicator(
                                                strokeWidth:
                                                    5, // Adjust the thickness of the progress indicator
                                              ),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 255, 255, 255),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (areDomainsActive) {
                                                await _syncModels();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                  content: Text(
                                                    'All records have been synchronized successfully.',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      Color.fromARGB(
                                                          255, 255, 255, 255),
                                                ));
                                              } else {
                                                _showDomainsInactiveMessage(
                                                    context);
                                              }
                                            },
                                            icon: const Icon(Icons.cloud_upload,
                                                size: 24),
                                            label: const Text(
                                              'Push To  Cloud',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),

                                    const SizedBox(height: 20),

                                    _isSyncing
                                        ? const Center(
                                            child: SizedBox(
                                              height:
                                                  50, // Specify the size of the CircularProgressIndicator
                                              width: 50,
                                              child: CircularProgressIndicator(
                                                strokeWidth:
                                                    5, // Adjust the thickness of the progress indicator
                                              ),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 255, 255, 255),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (areDomainsActive) {
                                                await _showModelSelectionDialog(
                                                    context);
                                              } else {
                                                _showDomainsInactiveMessage(
                                                    context);
                                              }
                                            },
                                            icon: const Icon(
                                                Icons.cloud_download,
                                                size: 24),
                                            label: const Text(
                                              'Pull From Cloud',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                    const SizedBox(height: 20),

                                    // Retrieve and Save Records Button
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }

  void _showDomainsInactiveMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Domains Not Active',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your domains are currently not active.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please contact the Edutrek Service Provider for assistance.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showModelSelectionDialog(BuildContext context) async {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser?.role.toLowerCase() ?? '';

    // Define models accessible to specific roles
    final roleBasedModels = {
      'admin': [
        'Teacher Payments',
        'Withdrawals',
        'Users',
        'Terms',
        'Teachers',
        'Teacher Purposes',
        'Students',
        'Student Payments',
        'Schools',
        'Student Payment Purposes',
        'Classes',
        'DomainRecord',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'Student Exceptions',
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
      ],
      'administration': [
        'Teacher Payments',
        'Withdrawals',
        'Users',
        'Terms',
        'Teachers',
        'Teacher Purposes',
        'Students',
        'Student Payments',
        'Schools',
        'Student Payment Purposes',
        'Classes',
        'DomainRecord',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'Student Exceptions',
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
      ],
      'secretary': [
        'Students',
        'Schools',
        'Classes',
        'Withdrawals',
        'Terms',
        'Teachers',
        'Student Payments',
        'Student Payment Purposes',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'Student Exceptions',
        'Users',
        'DomainRecord',
        'Student Exceptions',
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
      ],
      'teacher': [
        'Students',
        'Classes',
        'Terms',
        'Users',
        'Teachers',
        'Student Payments',
        'Schools',
        'DomainRecord',
        'Student Exceptions',
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
      ],
      'accountant': [
        'Teacher Payments',
        'Withdrawals',
        'Student Payments',
        'Terms',
        'Teachers',
        'Students',
        'Schools',
        'Classes',
        'Student Payment Purposes',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'Users',
        'Teacher Purposes',
        'DomainRecord',
        'Student Exceptions',
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
      ],
      'sub-admin': [
        'Teacher Payments',
        'Withdrawals',
        'Users',
        'Terms',
        'Teachers',
        'Teacher Purposes',
        'Students',
        'Student Payments',
        'Schools',
        'Student Payment Purposes',
        'Classes',
        'DomainRecord',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'Student Exceptions',
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
      ],
    };

    // Determine which models the user can access
    final models = roleBasedModels[role] ?? [];

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have access to any models.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Map<String, bool> selectedModels = {
      for (var model in models) model: false,
    };

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Models to Pull'),
              content: SingleChildScrollView(
                child: Column(
                  children: models.map((model) {
                    return CheckboxListTile(
                      title: Text(model),
                      value: selectedModels[model],
                      onChanged: (value) {
                        setState(() {
                          selectedModels[model] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchSelectedModels(selectedModels);
                  },
                  child: const Text('Sync Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchSelectedModels(Map<String, bool> selectedModels) async {
    setState(() {
      _isSyncing = true;
    });

    final fetchFunctions = {
      'Teacher Payments': _fetchAndSyncTeacherPayments,
      'Withdrawals': _fetchAndSyncwithdrawals,
      'Users': _fetchAndSyncUsers,
      'Terms': _fetchAndSyncTerms,
      'Teachers': _fetchAndSyncTeachers,
      'Teacher Purposes': _fetchAndSyncTeacherPurposes,
      'Students': _fetchAndSyncStudents,
      'Student Payments': _fetchAndSyncStudentPayments,
      'Schools': _fetchAndSyncSchools,
      'Student Payment Purposes': _fetchAndSyncPurposes,
      'Classes': _fetchAndSyncClasses,
      'DomainRecord': _fetchAndSyncDomainRecord,
      'Account': _fetchAndSyncAccount,
      'Asset': _fetchAndSyncAsset,
      'Project': _fetchAndSyncProject,
      'ProjectItem': _fetchAndSyncProjectItem,
      'DailyActivity': _fetchAndSyncDailyActivity,
      'Student Exceptions': _fetchAndSyncStudentExceptions,
      'Project Batches': _fetchAndSyncProjectBatches,
      'Batch Units': _fetchAndSyncBatchUnits,
      'Project Item Pricing': _fetchAndSyncProjectItemPricing,
      'Project Sale Transactions': _fetchAndSyncProjectSaleTransactions,
      'Batch Unit Sales': _fetchAndSyncBatchUnitSales,
      'Project Payment Method': _fetchAndSyncProjectPaymentMethod,
      'Project Receipt Snapshot': _fetchAndSyncProjectReceiptSnapshot,
    };

    try {
      for (var entry in selectedModels.entries) {
        if (entry.value) {
          final func = fetchFunctions[entry.key];
          if (func != null) {
            await func();
          } else {
            debugPrint(
                'Warning: No fetch function found for key "${entry.key}"');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selected records have been retrieved and saved successfully.',
            style: TextStyle(
                fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
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

  List<ExceptionalStudents> _decodeExceptions(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      final decodedList = jsonDecode(data) as List;
      return decodedList.map((e) => _exceptionFromJson(e)).toList();
    } else if (data is List) {
      return data.map((e) => _exceptionFromJson(e)).toList();
    }
    return [];
  }

//================================decode _exceptionFromJson =======================================================================//

  ExceptionalStudents _exceptionFromJson(Map<String, dynamic> json) {
    return ExceptionalStudents(
      id: json['id'] ?? 0,
      exceptionId: json['exceptionId'],
      exceptionName: json['exceptionName'],
      exceptionStatus: json['exceptionStatus'],
      exceptionType: json['exceptionType'],
      exceptionFigure: json['exceptionFigure'],
      syncStatus: json['syncStatus'] ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      operationType: json['operationType'] ?? 'none',
      modifiedFields: (json['modifiedFields'] != null)
          ? List<String>.from(jsonDecode(json['modifiedFields']))
          : [],
      terms: _decodeToList(json['terms']),
    );
  }

//================================decode _batchUnitFromJson =======================================================================//

  BatchUnit _batchUnitFromJson(Map<String, dynamic> json) {
    return BatchUnit(
      level: PackagingLevel.values.firstWhere(
        (e) => e.name == json['level'],
      ),
      unitsPerPackage: (json['unitsPerPackage'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      buyingPrice: (json['buyingPrice'] ?? 0).toDouble(),
      syncStatus: true,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'])
          : null,
      operationType: 'none',
      modifiedFields: [],
      unitBatchCode: json['unitBatchCode'],
    );
  }

  List<String> _decodeClassToList(dynamic value) {
    try {
      if (value == null) return [];
      if (value is List) return List<String>.from(value);
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) return List<String>.from(decoded);
      }
    } catch (e) {
      print('Error decoding string to List: $e');
    }
    return [];
  }

//================================pull _fetchAndSyncStudentExceptions =======================================================================//

  Future<void> _fetchAndSyncStudentExceptions() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/exceptions_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> classes = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded response: $decoded');

        for (var classData in classes) {
          ExceptionalStudents fetchedClass = ExceptionalStudents(
            exceptionId: classData['exceptionId'],
            exceptionName: classData['exceptionName'],
            exceptionStatus: classData['exceptionStatus'],
            exceptionType: classData['exceptionType'],
            exceptionFigure: classData['exceptionFigure'],
            terms: _decodeClassToList(classData['terms']),
          );

          // Check if the record exists in Hive using schoolCode
          var existingClassList = _exceptionalStudentsBox!.values
              .where(
                (classes) => classes.exceptionId == fetchedClass.exceptionId,
              )
              .toList();

          ExceptionalStudents? existingClasses =
              existingClassList.isNotEmpty ? existingClassList.first : null;

          if (fetchedClass.exceptionId != null) {
            if (existingClasses != null) {
              // Update existing record
              existingClasses
                ..id = fetchedClass.id
                ..exceptionId = fetchedClass.exceptionId
                ..exceptionName = fetchedClass.exceptionName
                ..exceptionStatus = fetchedClass.exceptionStatus
                ..exceptionType = fetchedClass.exceptionType
                ..exceptionFigure = fetchedClass.exceptionFigure
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..terms = fetchedClass.terms;

              await existingClasses.save();
              print(
                  'exceptionId ${fetchedClass.exceptionId} updated successfully in Hive.');
            } else {
              // Create a new record
              await _exceptionalStudentsBox!.add(fetchedClass);
              print(
                  'exceptionId ${fetchedClass.exceptionId} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another exception record was Found with no exceptionId Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch exceptions from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing exceptions: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  //================================pull _fetchAndSyncProjectBatches=======================================================================//
  StockUnitType? _parseStockUnitType(dynamic value) {
    if (value == null) return null;

    try {
      return StockUnitType.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toString().toLowerCase(),
      );
    } catch (_) {
      return StockUnitType.piece; // safe fallback
    }
  }

  List<BatchUnit> _decodeBatchUnits(dynamic value) {
    try {
      if (value == null) return [];

      if (value is List) {
        return value
            .map((e) => _batchUnitFromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => _batchUnitFromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      print('Error decoding BatchUnits: $e');
    }
    return [];
  }

  Future<void> _fetchAndSyncProjectBatches() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/product_batch_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        final List<dynamic> batches = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded ProductBatch response: $decoded');

        for (var batchData in batches) {
          // 🔹 Parse dates safely
          DateTime? purchaseDate =
              DateTime.tryParse(batchData['purchaseDate'] ?? '');

          DateTime? createdAt = DateTime.tryParse(batchData['createdAt'] ?? '');

          // 🔹 Build object
          ProductBatch fetchedBatch = ProductBatch(
            batchCode: batchData['batchCode'],
            productCode: batchData['productCode'],
            reference: batchData['reference'],
            baseUnitType: _parseStockUnitType(batchData['baseUnitType']),
            baseUnit: batchData['baseUnit'],
            baseUnitSize: batchData['baseUnitSize'],
            totalBaseUnits: batchData['totalBaseUnits'],
            remainingBaseUnits: batchData['remainingBaseUnits'],
            totalBuyingCost: batchData['totalBuyingCost'],
            purchaseDate: purchaseDate,
            createdAt: createdAt,
            units: _decodeBatchUnits(batchData['units']),
          );

          // 🔍 Check existing in Hive
          var existingList = _productBatchBox!.values
              .where((b) => b.batchCode == fetchedBatch.batchCode)
              .toList();

          ProductBatch? existing =
              existingList.isNotEmpty ? existingList.first : null;

          if (fetchedBatch.batchCode != null) {
            if (existing != null) {
              // 🔄 UPDATE
              existing
                ..productCode = fetchedBatch.productCode
                ..reference = fetchedBatch.reference
                ..baseUnitType = fetchedBatch.baseUnitType
                ..baseUnit = fetchedBatch.baseUnit
                ..baseUnitSize = fetchedBatch.baseUnitSize
                ..totalBaseUnits = fetchedBatch.totalBaseUnits
                ..remainingBaseUnits = fetchedBatch.remainingBaseUnits
                ..totalBuyingCost = fetchedBatch.totalBuyingCost
                ..purchaseDate = fetchedBatch.purchaseDate
                ..createdAt = fetchedBatch.createdAt
                ..units = fetchedBatch.units
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existing.save();

              print(
                  'ProductBatch ${fetchedBatch.batchCode} updated successfully.');
            } else {
              // ➕ CREATE
              await _productBatchBox!.add(fetchedBatch);

              print(
                  'ProductBatch ${fetchedBatch.batchCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('A ProductBatch record with no batchCode was skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch ProductBatch. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching/syncing ProductBatch: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
//================================pull _fetchAndSyncClasses =======================================================================//

  Future<void> _fetchAndSyncClasses() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> classes = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded response: $decoded');

        for (var classData in classes) {
          DateTime parsedDate =
              DateTime.tryParse(classData['date']) ?? DateTime.now();

          Classes fetchedClass = Classes(
            id: int.tryParse(classData['fid'] ?? '0') ?? 0,
            classCode: classData['classCode'],
            className: classData['className'],
            date: parsedDate, // Assign the parsed DateTime
            termId: classData['termId'],
            terms: _decodeClassToList(classData['terms']),
          );

          // Check if the record exists in Hive using schoolCode
          var existingClassList = _classesBox!.values
              .where(
                (classes) => classes.classCode == fetchedClass.classCode,
              )
              .toList();

          Classes? existingClasses =
              existingClassList.isNotEmpty ? existingClassList.first : null;

          if (fetchedClass.classCode != null) {
            if (existingClasses != null) {
              // Update existing record
              existingClasses
                ..id = fetchedClass.id
                ..classCode = fetchedClass.classCode
                ..className = fetchedClass.className
                ..date = fetchedClass.date
                ..termId = fetchedClass.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..terms = fetchedClass.terms;

              await existingClasses.save();
              print(
                  'Classes ${fetchedClass.classCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _classesBox!.add(fetchedClass);
              print(
                  'Classes ${fetchedClass.classCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another Class record was Found with no Class Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Classes from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing Classes: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncPurposes =======================================================================//

  Future<void> _fetchAndSyncPurposes() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> purposes = jsonDecode(response.body);

        for (var purposeData in purposes) {
          PaymentPurpose fetchedPurpose = PaymentPurpose(
            id: int.tryParse(purposeData['fid'] ?? '0') ?? 0,
            paymentPurpose: purposeData['paymentPurpose'] ?? '',
            purposeAmount: purposeData['purposeAmount'] != null
                ? double.tryParse(purposeData['purposeAmount'].toString()) ??
                    0.0
                : 0.0,
            purposeCode: purposeData['purposeCode'],
            associatedClasses: _decodeToList(purposeData['associatedClasses']),
            termId: purposeData['termId'],
            exceptions: purposeData['exceptions'] != null
                ? _decodeExceptions(purposeData['exceptions'])
                : null,
            forNewcomersOnly: purposeData['forNewcomersOnly'] ?? false,
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _payment_purposesBox!.values
              .where(
                (purposes) =>
                    purposes.purposeCode == fetchedPurpose.purposeCode,
              )
              .toList();

          PaymentPurpose? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;
          if (fetchedPurpose.purposeCode != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPurpose.id
                ..purposeCode = fetchedPurpose.purposeCode
                ..paymentPurpose = fetchedPurpose.paymentPurpose
                ..purposeAmount = fetchedPurpose.purposeAmount
                ..associatedClasses = fetchedPurpose.associatedClasses
                ..termId = fetchedPurpose.termId
                ..exceptions = fetchedPurpose.exceptions
                ..forNewcomersOnly = fetchedPurpose.forNewcomersOnly
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = existingPurposes.lastModified;
              await existingPurposes.save();
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _payment_purposesBox!.add(fetchedPurpose);
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another Student PaymentPurpose record was Found with no Purpose Code  and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch PaymentPurpose from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing PaymentPurpose: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncSchools =======================================================================//

  Future<void> _fetchAndSyncSchools() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> schools = jsonDecode(response.body);

        for (var schoolData in schools) {
          School fetchedSchool = School(
            id: int.tryParse(schoolData['fid'] ?? '0'),
            schoolName: schoolData['schoolName'],
            schoolCode: schoolData['schoolCode'],
            schoolAddress: schoolData['schoolAddress'],
            schoolPhoneNumber: schoolData['schoolPhoneNumber'],
            schoolEmail: schoolData['schoolEmail'],
            termId: schoolData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingSchoolList = _schoolBox!.values
              .where(
                (school) => school.schoolCode == fetchedSchool.schoolCode,
              )
              .toList();

          School? existingSchool =
              existingSchoolList.isNotEmpty ? existingSchoolList.first : null;
          if (fetchedSchool.schoolCode != null) {
            if (existingSchool != null) {
              // Update existing record
              existingSchool
                ..schoolName = fetchedSchool.schoolName
                ..schoolAddress = fetchedSchool.schoolAddress
                ..schoolPhoneNumber = fetchedSchool.schoolPhoneNumber
                ..schoolEmail = fetchedSchool.schoolEmail
                ..termId = fetchedSchool.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedSchool.id;

              await existingSchool.save();
              print(
                  'School ${fetchedSchool.schoolCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _schoolBox!.add(fetchedSchool);
              print(
                  'School ${fetchedSchool.schoolCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another School record was Found with no School Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch schools from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing schools: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncStudentPayments =======================================================================//

  Future<void> _fetchAndSyncStudentPayments() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> studentPayments = jsonDecode(response.body);
        for (var paymentsData in studentPayments) {
          debugPrint(
              'Raw paymentDate received: ${paymentsData['paymentDate']}');
        }

        for (var paymentsData in studentPayments) {
          StudentPayment fetchedPayments = StudentPayment(
            id: int.tryParse(paymentsData['fid'] ?? '0') ?? 0,
            studentName: paymentsData['studentName'] ?? '',
            studentSurname: paymentsData['studentSurname'] ?? '',
            studentClass: paymentsData['studentClass'] ?? '',
            phoneNumber: paymentsData['phoneNumber'] ?? '',
            paymentPurpose: paymentsData['paymentPurpose'] ?? '',
            amountToPay: paymentsData['amountToPay'] != null
                ? double.tryParse(paymentsData['amountToPay'].toString()) ?? 0.0
                : 0.0,
            paymentDate: DateTime.tryParse(paymentsData['paymentDate']) ??
                DateTime.now(),
            receiptNumber: paymentsData['receiptNumber'],
            termId: paymentsData['termId'],
            username: paymentsData['username'] ?? '',
            role: paymentsData['role'] ?? '',
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _student_paymentsBox!.values
              .where(
                (studentPayments) =>
                    studentPayments.receiptNumber ==
                    fetchedPayments.receiptNumber,
              )
              .toList();

          StudentPayment? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;

          if (fetchedPayments.receiptNumber != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPayments.id
                ..studentName = fetchedPayments.studentName
                ..studentSurname = fetchedPayments.studentSurname
                ..studentClass = fetchedPayments.studentClass
                ..phoneNumber = fetchedPayments.phoneNumber
                ..paymentPurpose = fetchedPayments.paymentPurpose
                ..amountToPay = fetchedPayments.amountToPay
                ..paymentDate = fetchedPayments.paymentDate
                ..receiptNumber = fetchedPayments.receiptNumber
                ..termId = fetchedPayments.termId
                ..username = fetchedPayments.username
                ..role = fetchedPayments.role
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              print(
                  'StudentPayment ${fetchedPayments.receiptNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _student_paymentsBox!.add(fetchedPayments);
              print(
                  'StudentPayment ${fetchedPayments.receiptNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other StudentPayment Record Was Found with no Receipt Numbers and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch StudentPayment from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing StudentPayment: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncStudents =======================================================================//
  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  Future<void> _fetchAndSyncStudents() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> students = jsonDecode(response.body);

        for (var studentsData in students) {
          try {
            Student fetchedStudents = Student(
              id: int.tryParse(studentsData['fid']?.toString() ?? '0'),
              name: studentsData['name'] ?? '', // fallback
              surname: studentsData['surname'] ?? '', // fallback
              regNumber: studentsData['regNumber'] ?? '', // fallback
              class_: studentsData['class'] ?? '', // fallback
              gender: studentsData['gender'] ?? '',

              age: DateTime.tryParse(studentsData['age']?.toString() ?? '') ??
                  DateTime(1900),
              phoneNumber: studentsData['phoneNumber'] ?? '',
              paymentStatus: studentsData['paymentStatus'] ?? '',

              isPresent: studentsData['isPresent'] ?? false,
              presentDates: _parseDateList(studentsData['presentDates']),
              absentDates: _parseDateList(studentsData['absentDates']),
              termId: studentsData['termId'] ?? '',

              physicalAddress: studentsData['physicalAddress'] ?? '',
              formerSchool: studentsData['formerSchool'] ?? '',
              religion: studentsData['religion'] ?? '',
              denomination: studentsData['denomination'] ?? '',

              studentIdNumber: studentsData['studentIdNumber'] ?? '',
              nationalIdNumber: studentsData['nationalIdNumber'] ?? '',
              nationality: studentsData['nationality'] ?? '',
              district: studentsData['district'] ?? '',
              previousSchoolPerformanceResults:
                  studentsData['previousSchoolPerformanceResults'] ?? '',
              enrollmentStatus: studentsData['enrollmentStatus'] ?? '',
              emergencyContactName: studentsData['emergencyContactName'] ?? '',
              emergencyContactNumber:
                  studentsData['emergencyContactNumber'] ?? '',
              terms: _decodeToList(studentsData['terms']),
              isNewComer: _parseBool(studentsData['isNewComer']),
              isNewComerFrom:
                  DateTime.tryParse(studentsData['isNewComerFrom'] ?? '') ??
                      null,
              isNewComerUntil:
                  DateTime.tryParse(studentsData['isNewComerUntil'] ?? '') ??
                      null,
              exceptions: studentsData['exceptions'] != null
                  ? _decodeExceptions(studentsData['exceptions'])
                  : null,
            );

            // Proceed with save/update...
            var existingStudentsList = _studentsBox!.values
                .where((students) =>
                    students.studentIdNumber == fetchedStudents.studentIdNumber)
                .toList();

            Student? existingStudents = existingStudentsList.isNotEmpty
                ? existingStudentsList.first
                : null;

            if (fetchedStudents.studentIdNumber != null &&
                fetchedStudents.studentIdNumber!.isNotEmpty) {
              if (existingStudents != null) {
                existingStudents
                  ..name = fetchedStudents.name
                  ..surname = fetchedStudents.surname
                  ..regNumber = fetchedStudents.regNumber
                  ..class_ = fetchedStudents.class_
                  ..gender = fetchedStudents.gender
                  ..termId = fetchedStudents.termId
                  ..age = fetchedStudents.age
                  ..phoneNumber = fetchedStudents.phoneNumber
                  ..paymentStatus = fetchedStudents.paymentStatus
                  ..isPresent = fetchedStudents.isPresent
                  ..presentDates = fetchedStudents.presentDates
                  ..absentDates = fetchedStudents.absentDates
                  ..id = fetchedStudents.id
                  ..physicalAddress = fetchedStudents.physicalAddress
                  ..formerSchool = fetchedStudents.formerSchool
                  ..religion = fetchedStudents.religion
                  ..denomination = fetchedStudents.denomination
                  ..studentIdNumber = fetchedStudents.studentIdNumber
                  ..nationalIdNumber = fetchedStudents.nationalIdNumber
                  ..nationality = fetchedStudents.nationality
                  ..district = fetchedStudents.district
                  ..previousSchoolPerformanceResults =
                      fetchedStudents.previousSchoolPerformanceResults
                  ..enrollmentStatus = fetchedStudents.enrollmentStatus
                  ..emergencyContactName = fetchedStudents.emergencyContactName
                  ..emergencyContactNumber =
                      fetchedStudents.emergencyContactNumber
                  ..syncStatus = true
                  ..operationType = 'none'
                  ..lastModified = DateTime.now()
                  ..terms = fetchedStudents.terms
                  ..isNewComer = fetchedStudents.isNewComer
                  ..isNewComerFrom = fetchedStudents.isNewComerFrom
                  ..isNewComerUntil = fetchedStudents.isNewComerUntil
                  ..exceptions = fetchedStudents.exceptions;

                await existingStudents.save();
                print(
                    'Student ${fetchedStudents.studentIdNumber} updated successfully in Hive.');
              } else {
                await _studentsBox!.add(fetchedStudents);
                print(
                    'Student ${fetchedStudents.studentIdNumber} added successfully to Hive.');
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Other Student Record was Found with no Student Reg Number and was Skipped.'),
              ));
            }
          } catch (error, stack) {
            // Here we pinpoint the error:
            debugPrint(
              '❌ Error processing student record:\n'
              'Data: ${studentsData.toString()}\n'
              'Error: $error\n'
              'Stack Trace: $stack',
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch students from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing students: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  List<DateTime> _parseDateList(dynamic jsonList) {
    if (jsonList == null || jsonList is! List) return [];
    return jsonList
        .map<DateTime>(
            (dateStr) => DateTime.tryParse(dateStr) ?? DateTime(1900))
        .toList();
  }

//================================pull teacherPayments =======================================================================//

  Future<void> _fetchAndSyncTeacherPayments() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          debugPrint(
              'Warning: TeacherPayments API returned an empty response.');
          return;
        }

        List<dynamic> teacherPayments;
        try {
          teacherPayments = jsonDecode(responseBody);
        } catch (e) {
          debugPrint('Error decoding TeacherPayments JSON: $e');
          return;
        }

        for (var paymentsData in teacherPayments) {
          TeacherPayment fetchedPayments = TeacherPayment(
            id: int.tryParse(paymentsData['fid'] ?? '0') ?? 0,
            studentName: paymentsData['studentName'] ?? '',
            studentSurname: paymentsData['studentSurname'] ?? '',
            studentClass: paymentsData['studentClass'] ?? '',
            phoneNumber: paymentsData['phoneNumber'] ?? '',
            paymentPurpose: paymentsData['paymentPurpose'] ?? '',
            amountToPay: paymentsData['amountToPay'] != null
                ? double.tryParse(paymentsData['amountToPay'].toString()) ?? 0.0
                : 0.0,
            paymentDate: DateTime.tryParse(paymentsData['paymentDate']) ??
                DateTime.now(),
            receiptNumber: paymentsData['receiptNumber'],
            termId: paymentsData['termId'],
          );

          var existingPurposeList = _teacher_paymentsBox!.values
              .where(
                (teacherPayments) =>
                    teacherPayments.receiptNumber ==
                    fetchedPayments.receiptNumber,
              )
              .toList();

          TeacherPayment? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;

          if (fetchedPayments.receiptNumber != null) {
            if (existingPurposes != null) {
              existingPurposes
                ..id = fetchedPayments.id
                ..studentName = fetchedPayments.studentName
                ..studentSurname = fetchedPayments.studentSurname
                ..studentClass = fetchedPayments.studentClass
                ..phoneNumber = fetchedPayments.phoneNumber
                ..paymentPurpose = fetchedPayments.paymentPurpose
                ..amountToPay = fetchedPayments.amountToPay
                ..paymentDate = fetchedPayments.paymentDate
                ..receiptNumber = fetchedPayments.receiptNumber
                ..termId = fetchedPayments.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              debugPrint(
                  'TeacherPayment ${fetchedPayments.receiptNumber} updated successfully in Hive.');
            } else {
              await _teacher_paymentsBox!.add(fetchedPayments);
              debugPrint(
                  'TeacherPayment ${fetchedPayments.receiptNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Payment Record was found with no Receipt Number and was skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch TeacherPayment from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching or syncing TeacherPayment: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncTeacherPurposes =======================================================================//

  Future<void> _fetchAndSyncTeacherPurposes() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          debugPrint(
              'Warning: TeacherPaymentPurposes API returned an empty response.');
          return;
        }

        List<dynamic> teacherPurposes;
        try {
          teacherPurposes = jsonDecode(responseBody);
        } catch (e) {
          debugPrint('Error decoding TeacherPaymentPurposes JSON: $e');
          return;
        }

        for (var teacherPurposeData in teacherPurposes) {
          TeacherPaymentsPurposes fetchedTeacherPurpose =
              TeacherPaymentsPurposes(
            id: int.tryParse(teacherPurposeData['fid'] ?? '0') ?? 0,
            paymentPurpose: teacherPurposeData['paymentPurpose'] ?? '',
            purposeAmount: teacherPurposeData['purposeAmount'] != null
                ? double.tryParse(
                        teacherPurposeData['purposeAmount'].toString()) ??
                    0.0
                : 0.0,
            purposeCode: teacherPurposeData['purposeCode'],
            associatedStaff:
                _decodeToList(teacherPurposeData['associatedStaff']),
            termId: teacherPurposeData['termId'],
          );

          var existingTeacherPurposeList = _teacher_payments_purposesBox!.values
              .where(
                (teacherPurposes) =>
                    teacherPurposes.purposeCode ==
                    fetchedTeacherPurpose.purposeCode,
              )
              .toList();

          TeacherPaymentsPurposes? existingTeacherPurposes =
              existingTeacherPurposeList.isNotEmpty
                  ? existingTeacherPurposeList.first
                  : null;

          if (fetchedTeacherPurpose.purposeCode != null) {
            if (existingTeacherPurposes != null) {
              existingTeacherPurposes
                ..id = fetchedTeacherPurpose.id
                ..purposeCode = fetchedTeacherPurpose.purposeCode
                ..paymentPurpose = fetchedTeacherPurpose.paymentPurpose
                ..purposeAmount = fetchedTeacherPurpose.purposeAmount
                ..associatedStaff = fetchedTeacherPurpose.associatedStaff
                ..termId = fetchedTeacherPurpose.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingTeacherPurposes.save();
              debugPrint(
                  'TeacherPaymentsPurposes ${fetchedTeacherPurpose.purposeCode} updated successfully in Hive.');
            } else {
              await _teacher_payments_purposesBox!.add(fetchedTeacherPurpose);
              debugPrint(
                  'TeacherPaymentsPurposes ${fetchedTeacherPurpose.purposeCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Payment Purpose Record Was Found with no purposeCode and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
          'Failed to fetch TeacherPaymentsPurposes from the server. Status Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching or syncing TeacherPaymentsPurposes: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncTeachers =======================================================================//

  Future<void> _fetchAndSyncTeachers() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          debugPrint('Warning: Teachers API returned an empty response.');
          return;
        }

        // Try decoding the JSON
        List<dynamic> teachers;
        try {
          teachers = jsonDecode(responseBody);
        } catch (e) {
          debugPrint('Error decoding Teachers JSON: $e');
          return;
        }

        for (var teachersData in teachers) {
          Teachers fetchedTeachers = Teachers(
              id: int.tryParse(teachersData['fid'] ?? '0') ?? 0,
              name: teachersData['name'] ?? '',
              surname: teachersData['surname'] ?? '',
              IdNumber: teachersData['IdNumber'],
              assignedClass: teachersData['assignedClass'] ?? '',
              assignedClasses: _decodeToList(teachersData['assignedClasses']),
              gender: teachersData['gender'] ?? '',
              dateOfBirth: DateTime.tryParse(teachersData['dateOfBirth']) ??
                  DateTime.now(),
              phoneNumber: teachersData['phoneNumber'] ?? '',
              paymentPurpose: teachersData['paymentPurpose'] ?? '',
              isPaid: teachersData['isPaid'],
              paymentAmount: teachersData['paymentAmount'] != null
                  ? double.tryParse(teachersData['paymentAmount'].toString()) ??
                      0.0
                  : 0.0,
              paymentDate: teachersData['paymentDate'] != null
                  ? DateTime.tryParse(teachersData['paymentDate'])
                  : null,
              email: teachersData['email'] ?? '',
              address: teachersData['address'] ?? '',
              hireDate:
                  DateTime.tryParse(teachersData['hireDate']) ?? DateTime(1900),
              qualifications: teachersData['qualifications'] ?? '',
              employmentStatus: teachersData['employmentStatus'] ?? '',
              termId: teachersData['termId'],
              terms: _decodeToList(teachersData['terms']));

          // Check if the record exists in Hive using IdNumber
          var existingTeachersList = _teachersBox!.values
              .where(
                  (teachers) => teachers.IdNumber == fetchedTeachers.IdNumber)
              .toList();

          Teachers? existingTeachers = existingTeachersList.isNotEmpty
              ? existingTeachersList.first
              : null;

          if (fetchedTeachers.IdNumber != null) {
            if (existingTeachers != null) {
              // Update existing record
              existingTeachers
                ..id = fetchedTeachers.id
                ..name = fetchedTeachers.name
                ..surname = fetchedTeachers.surname
                ..IdNumber = fetchedTeachers.IdNumber
                ..assignedClass = fetchedTeachers.assignedClass
                ..assignedClass = fetchedTeachers.assignedClass
                ..gender = fetchedTeachers.gender
                ..dateOfBirth = fetchedTeachers.dateOfBirth
                ..phoneNumber = fetchedTeachers.phoneNumber
                ..paymentPurpose = fetchedTeachers.paymentPurpose
                ..isPaid = fetchedTeachers.isPaid
                ..paymentAmount = fetchedTeachers.paymentAmount
                ..paymentDate = fetchedTeachers.paymentDate
                ..email = fetchedTeachers.email
                ..address = fetchedTeachers.address
                ..hireDate = fetchedTeachers.hireDate
                ..employmentStatus = fetchedTeachers.employmentStatus
                ..termId = fetchedTeachers.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..terms = fetchedTeachers.terms;

              await existingTeachers.save();
              debugPrint(
                  'Teachers ${fetchedTeachers.IdNumber} updated successfully in Hive.');
            } else {
              await _teachersBox!.add(fetchedTeachers);
              debugPrint(
                  'Teachers ${fetchedTeachers.IdNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff record was found with no IdNumber and was skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Teachers. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching or syncing Teachers: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncTerms =======================================================================//

  Future<void> _fetchAndSyncTerms() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> terms = jsonDecode(response.body);

        for (var termsData in terms) {
          DateTime parsedStartDate =
              DateTime.tryParse(termsData['startDate'] ?? '') ?? DateTime.now();
          DateTime? parsedEndDate = termsData['endDate'] != null
              ? DateTime.tryParse(termsData['endDate'])
              : null;
          String statuses;
          bool isactive = termsData['isActive'];

          if (isactive == false) {
            statuses = 'Closed';
          } else {
            statuses = 'Opened';
          }
          Terms fetchedTerms = Terms(
            id: int.tryParse(termsData['fid'] ?? '0'),
            termName: termsData['termName'],
            startDate: parsedStartDate,
            endDate: parsedEndDate,
            isActive: termsData['isActive'] == true,
            status: statuses,
            termId: termsData['termId'],
          );

          var existingTermsList = _termsBox!.values
              .where(
                (school) => school.termId == fetchedTerms.termId,
              )
              .toList();

          Terms? existingTerms =
              existingTermsList.isNotEmpty ? existingTermsList.first : null;

          if (fetchedTerms.termId != null) {
            if (existingTerms != null) {
              // Update existing record
              existingTerms
                ..termName = fetchedTerms.termName
                ..startDate = fetchedTerms.startDate
                ..endDate = fetchedTerms.endDate
                ..isActive = fetchedTerms.isActive
                ..status = fetchedTerms.status
                ..termId = fetchedTerms.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedTerms.id;

              await existingTerms.save();
              debugPrint(
                  'Terms ${fetchedTerms.termId} updated successfully in Hive.');
            } else {
              // Create a new record
              await _termsBox!.add(fetchedTerms);
              debugPrint(
                  'Terms ${fetchedTerms.termId} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Skipped a term record without a term ID.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch terms. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing terms: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching terms: $e'),
      ));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
//================================pull _fetchAndSyncUsers =======================================================================//

  Future<void> _fetchAndSyncUsers() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> users = jsonDecode(response.body);

        for (var userData in users) {
          User fetchedUser = User(
            id: int.tryParse(userData['fid'] ?? '0'),
            username: userData['username'] ?? '',
            password: userData['password'] ?? '',
            role: userData['role'] ?? '',
            securityQuestions: _decodeToList(userData['securityQuestions']),
            securityAnswers: _decodeToList(userData['securityAnswers']),
            phone: userData['phone'] ?? '',
            userCode: userData['userCode'],
            termId: userData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingUserList = _usersBox!.values
              .where(
                (users) => users.userCode == fetchedUser.userCode,
              )
              .toList();

          User? existingUsers =
              existingUserList.isNotEmpty ? existingUserList.first : null;
          if (fetchedUser.userCode != null) {
            if (existingUsers != null) {
              // Update existing record
              existingUsers
                ..id = fetchedUser.id
                ..userCode = fetchedUser.userCode
                ..username = fetchedUser.username
                ..password = fetchedUser.password
                ..role = fetchedUser.role
                ..securityQuestions = fetchedUser.securityQuestions
                ..securityAnswers = fetchedUser.securityAnswers
                ..phone = fetchedUser.phone
                ..termId = fetchedUser.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingUsers.save();
              print(
                  'User ${fetchedUser.userCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _usersBox!.add(fetchedUser);
              print('User ${fetchedUser.userCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other User  Record Was Found with no User Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch User from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing User: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncwithdrawals =======================================================================//

  Future<void> _fetchAndSyncwithdrawals() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> withdrawals = jsonDecode(response.body);

        for (var withdrawalData in withdrawals) {
          DateTime date =
              DateTime.tryParse(withdrawalData['date']) ?? DateTime.now();

          Withdrawal fetchedWthdrawals = Withdrawal(
            id: int.tryParse(withdrawalData['fid'] ?? '0'),
            amount: withdrawalData['amount'] != null
                ? double.tryParse(withdrawalData['amount'].toString()) ?? 0.0
                : 0.0,
            date: date,
            withdrawalPurpose: withdrawalData['withdrawalPurpose'],
            withdrawalCode: withdrawalData['withdrawalCode'],
            termId: withdrawalData['termId'],
          );

          // Check if the record exists in Hive using termId
          var existingWithdrawalsList = _withdrawalsBox!.values
              .where(
                (withdrawal) =>
                    withdrawal.withdrawalCode ==
                    fetchedWthdrawals.withdrawalCode,
              )
              .toList();

          Withdrawal? existingWithdrawals = existingWithdrawalsList.isNotEmpty
              ? existingWithdrawalsList.first
              : null;
          if (fetchedWthdrawals.withdrawalCode != null) {
            if (existingWithdrawals != null) {
              // Update existing record
              existingWithdrawals
                ..amount = fetchedWthdrawals.amount
                ..withdrawalPurpose = fetchedWthdrawals.withdrawalPurpose
                ..withdrawalCode = fetchedWthdrawals.withdrawalCode
                ..date = fetchedWthdrawals.date
                ..termId = fetchedWthdrawals.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedWthdrawals.id;

              await existingWithdrawals.save();
              print(
                  'Withdrawal ${fetchedWthdrawals.withdrawalCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _withdrawalsBox!.add(fetchedWthdrawals);
              print(
                  'Withdrawal ${fetchedWthdrawals.withdrawalCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other Withdrawal  Record Was Found with no Withdrawal Code and was Skipped'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch withdrawals from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing withdrawals: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncDomainRecord =======================================================================//

  Future<void> _fetchAndSyncDomainRecord() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/domain_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> domainList = jsonDecode(response.body);
        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var domainData in domainList) {
          DomainRecord fetchedDomain = DomainRecord(
            domainName: domainData['domainName'] ?? '',
            areDomainsActive: _intToBool(domainData['areDomainsActive']),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(domainData['lastModified'] ?? ''),
          );

          var existingDomainList = _domainRecordBox!.values
              .where((d) => d.domainName == fetchedDomain.domainName)
              .toList();

          DomainRecord? existingDomain =
              existingDomainList.isNotEmpty ? existingDomainList.first : null;

          if (fetchedDomain.domainName!.isNotEmpty) {
            if (existingDomain != null) {
              existingDomain
                ..areDomainsActive = fetchedDomain.areDomainsActive
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingDomain.save();
              print(
                  'DomainRecord ${fetchedDomain.domainName} updated successfully in Hive.');
            } else {
              await _domainRecordBox!.add(fetchedDomain);
              print(
                  'DomainRecord ${fetchedDomain.domainName} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'A Domain record was found with no domain name and was skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch DomainRecords from server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing DomainRecords: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncAccount =======================================================================//

  Future<void> _fetchAndSyncAccount() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> accounts = jsonDecode(response.body);
        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var accData in accounts) {
          Account fetchedAcc = Account(
            id: accData['id'],
            accountType: accData['accountType'],
            accountSubType: accData['accountSubType'],
            accountName: accData['accountName'],
            accountCode: accData['accountCode'],
            isALiquidAccount: _intToBool(accData['isALiquidAccount']),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(accData['lastModified'] ?? ''),
          );

          var existingList =
              _accountBox!.values.where((a) => a.id == fetchedAcc.id).toList();

          Account? existing =
              existingList.isNotEmpty ? existingList.first : null;

          if (fetchedAcc.id != null) {
            if (existing != null) {
              existing
                ..accountType = fetchedAcc.accountType
                ..accountSubType = fetchedAcc.accountSubType
                ..accountName = fetchedAcc.accountName
                ..accountCode = fetchedAcc.accountCode
                ..isALiquidAccount = fetchedAcc.isALiquidAccount
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existing.save();
              print('Account ${fetchedAcc.id} updated successfully.');
            } else {
              await _accountBox!.add(fetchedAcc);
              print('Account ${fetchedAcc.id} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account with no ID was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Accounts. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing Accounts: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncAsset =======================================================================//

  Future<void> _fetchAndSyncAsset() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/asset_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> assets = jsonDecode(response.body);
        double? _toDouble(dynamic value) {
          if (value == null) return null;
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        }

        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var assetData in assets) {
          Asset fetchedAsset = Asset(
            id: assetData['id'],
            assetName: assetData['assetName'],
            assetType: assetData['assetType'],
            assetSubType: assetData['assetSubType'],
            assetCode: assetData['assetCode'],
            assetSerialNo: assetData['assetSerialNo'],
            acquisitionDate:
                DateTime.tryParse(assetData['acquisitionDate'] ?? ''),
            acquisitionCost: _toDouble(assetData['acquisitionCost']),
            acquisitionMethod: assetData['acquisitionMethod'],
            department: assetData['department'],
            location: assetData['location'],
            depreciationRate: _toDouble(assetData['depreciationRate']),
            depreciationMethod: assetData['depreciationMethod'],
            lastDepreciationDate:
                DateTime.tryParse(assetData['lastDepreciationDate'] ?? ''),
            accumulatedDepreciation:
                _toDouble(assetData['accumulatedDepreciation']),
            bookValue: _toDouble(assetData['bookValue']),
            isImpaired: _intToBool(assetData['isImpaired']),
            impairmentLoss: _toDouble(assetData['impairmentLoss']),
            revaluationDate:
                DateTime.tryParse(assetData['revaluationDate'] ?? ''),
            revaluationAmount: _toDouble(assetData['revaluationAmount']),
            lastMaintenanceDate:
                DateTime.tryParse(assetData['lastMaintenanceDate'] ?? ''),
            maintenanceCost: _toDouble(assetData['maintenanceCost']),
            maintenanceDescription: assetData['maintenanceDescription'],
            capitalImprovementCost:
                _toDouble(assetData['capitalImprovementCost']),
            capitalImprovementDescription:
                assetData['capitalImprovementDescription'],
            disposalDate: DateTime.tryParse(assetData['disposalDate'] ?? ''),
            disposalProceeds: _toDouble(assetData['disposalProceeds']),
            disposalReason: assetData['disposalReason'],
            gainOrLossOnDisposal: _toDouble(assetData['gainOrLossOnDisposal']),
            isLeased: _intToBool(assetData['isLeased']),
            leaseType: assetData['leaseType'],
            leaseStartDate:
                DateTime.tryParse(assetData['leaseStartDate'] ?? ''),
            leaseEndDate: DateTime.tryParse(assetData['leaseEndDate'] ?? ''),
            leasePaymentAmount: _toDouble(assetData['leasePaymentAmount']),
            lastAuditDate: DateTime.tryParse(assetData['lastAuditDate'] ?? ''),
            notes: assetData['notes'],
            createdAt: DateTime.tryParse(assetData['createdAt'] ?? ''),
            lastModified: DateTime.tryParse(assetData['lastModified'] ?? ''),
            operationType: 'none',
            syncStatus: true,
            usefulLife: assetData['usefulLife'],
            hasDebitBalance: _intToBool(assetData['hasDebitBalance']),
            hasCreditBalance: _intToBool(assetData['hasCreditBalance']),
            option: assetData['option'],
          );

          var existingAssetList =
              _assetBox!.values.where((a) => a.id == fetchedAsset.id).toList();

          Asset? existingAsset =
              existingAssetList.isNotEmpty ? existingAssetList.first : null;

          if (fetchedAsset.id != null) {
            if (existingAsset != null) {
              existingAsset
                ..assetName = fetchedAsset.assetName
                ..assetType = fetchedAsset.assetType
                ..assetSubType = fetchedAsset.assetSubType
                ..assetCode = fetchedAsset.assetCode
                ..assetSerialNo = fetchedAsset.assetSerialNo
                ..acquisitionDate = fetchedAsset.acquisitionDate
                ..acquisitionCost = fetchedAsset.acquisitionCost
                ..acquisitionMethod = fetchedAsset.acquisitionMethod
                ..department = fetchedAsset.department
                ..location = fetchedAsset.location
                ..depreciationRate = fetchedAsset.depreciationRate
                ..depreciationMethod = fetchedAsset.depreciationMethod
                ..lastDepreciationDate = fetchedAsset.lastDepreciationDate
                ..accumulatedDepreciation = fetchedAsset.accumulatedDepreciation
                ..bookValue = fetchedAsset.bookValue
                ..isImpaired = fetchedAsset.isImpaired
                ..impairmentLoss = fetchedAsset.impairmentLoss
                ..revaluationDate = fetchedAsset.revaluationDate
                ..revaluationAmount = fetchedAsset.revaluationAmount
                ..lastMaintenanceDate = fetchedAsset.lastMaintenanceDate
                ..maintenanceCost = fetchedAsset.maintenanceCost
                ..maintenanceDescription = fetchedAsset.maintenanceDescription
                ..capitalImprovementCost = fetchedAsset.capitalImprovementCost
                ..capitalImprovementDescription =
                    fetchedAsset.capitalImprovementDescription
                ..disposalDate = fetchedAsset.disposalDate
                ..disposalProceeds = fetchedAsset.disposalProceeds
                ..disposalReason = fetchedAsset.disposalReason
                ..gainOrLossOnDisposal = fetchedAsset.gainOrLossOnDisposal
                ..isLeased = fetchedAsset.isLeased
                ..leaseType = fetchedAsset.leaseType
                ..leaseStartDate = fetchedAsset.leaseStartDate
                ..leaseEndDate = fetchedAsset.leaseEndDate
                ..leasePaymentAmount = fetchedAsset.leasePaymentAmount
                ..lastAuditDate = fetchedAsset.lastAuditDate
                ..notes = fetchedAsset.notes
                ..createdAt = fetchedAsset.createdAt
                ..lastModified = DateTime.now()
                ..syncStatus = true
                ..operationType = 'none'
                ..usefulLife = fetchedAsset.usefulLife
                ..hasDebitBalance = fetchedAsset.hasDebitBalance
                ..hasCreditBalance = fetchedAsset.hasCreditBalance
                ..option = fetchedAsset.option;
              await existingAsset.save();
              print('Asset ${fetchedAsset.id} updated successfully.');
            } else {
              await _assetBox!.add(fetchedAsset);
              print('Asset ${fetchedAsset.id} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Asset with no ID was skipped.')),
            );
          }
        }
      } else {
        throw Exception('Failed to fetch Assets. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing Assets: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncProject =======================================================================//

  Future<void> _fetchAndSyncProject() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> projects = jsonDecode(response.body);

        for (var projectData in projects) {
          Project fetchedProject = Project(
            projectCode: projectData['projectCode'],
            name: projectData['name'],
            description: projectData['description'],
            status: projectData['status'],
            createdAt: DateTime.tryParse(projectData['createdAt'] ?? '') ??
                DateTime.now(),
            updatedAt: DateTime.tryParse(projectData['updatedAt'] ?? '') ??
                DateTime.now(),

            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(projectData['lastModified'] ?? ''),

            // ✅ NEW REQUIRED FIELDS
            projectType: projectData['projectType'] ?? 'sales',
            participationType: projectData['participationType'] ?? 'optional',
            studentPayable: projectData['studentPayable'],
          );

          var existingProjectList = _projectBox!.values
              .where((p) => p.projectCode == fetchedProject.projectCode)
              .toList();

          Project? existingProject =
              existingProjectList.isNotEmpty ? existingProjectList.first : null;

          if (fetchedProject.projectCode.isNotEmpty) {
            if (existingProject != null) {
              existingProject
                ..name = fetchedProject.name
                ..description = fetchedProject.description
                ..status = fetchedProject.status
                ..createdAt = fetchedProject.createdAt
                ..updatedAt = fetchedProject.updatedAt
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()

                // ✅ UPDATE NEW FIELDS
                ..projectType = fetchedProject.projectType
                ..participationType = fetchedProject.participationType
                ..studentPayable = fetchedProject.studentPayable;

              await existingProject.save();

              print(
                  'Project ${fetchedProject.projectCode} updated successfully.');
            } else {
              await _projectBox!.add(fetchedProject);

              print(
                  'Project ${fetchedProject.projectCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project with no code was skipped.'),
              ),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Projects. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing Projects: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
//================================pull _fetchAndSyncProjectItem =======================================================================//

  Future<void> _fetchAndSyncProjectItem() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> items = jsonDecode(response.body);
        double? _toDouble(dynamic value) {
          if (value == null) return null;
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        }

        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var itemData in items) {
          ProjectItem fetchedItem = ProjectItem(
            projectItemCode: itemData['projectItemCode'],
            projectCode: itemData['projectCode'],
            name: itemData['name'],

            // ✅ NEW FIELDS
            itemType: itemData['itemType'],
            active: _intToBool(itemData['active']),
            trackStock: _intToBool(itemData['trackStock']),

            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(itemData['lastModified'] ?? ''),
          );

          var existingItemList = _projectItemBox!.values
              .where((i) => i.projectItemCode == fetchedItem.projectItemCode)
              .toList();

          ProjectItem? existingItem =
              existingItemList.isNotEmpty ? existingItemList.first : null;

          if ((fetchedItem.projectItemCode ?? '').isNotEmpty) {
            if (existingItem != null) {
              existingItem
                ..projectCode = fetchedItem.projectCode
                ..name = fetchedItem.name
                ..itemType = fetchedItem.itemType
                ..active = fetchedItem.active
                ..trackStock = fetchedItem.trackStock
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingItem.save();

              print(
                  'ProjectItem ${fetchedItem.projectItemCode} updated successfully.');
            } else {
              await _projectItemBox!.add(fetchedItem);

              print(
                  'ProjectItem ${fetchedItem.projectItemCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ProjectItem with no code was skipped.'),
              ),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch ProjectItems. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing ProjectItems: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncDailyActivity =======================================================================//

  Future<void> _fetchAndSyncDailyActivity() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_daily_activity_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> activities = jsonDecode(response.body);

        for (var activityData in activities) {
          DailyActivity fetchedActivity = DailyActivity(
            projectDailyActiviyCode: activityData['projectDailyActiviyCode'],
            projectCode: activityData['projectCode'],
            date:
                DateTime.tryParse(activityData['date'] ?? '') ?? DateTime.now(),
            type: activityData['type'],
            description: activityData['description'],
            amount: activityData['amount'],
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(activityData['lastModified'] ?? ''),
          );

          var existingActivityList = _dailyActivityBox!.values
              .where((d) =>
                  d.projectDailyActiviyCode ==
                  fetchedActivity.projectDailyActiviyCode)
              .toList();

          DailyActivity? existingActivity = existingActivityList.isNotEmpty
              ? existingActivityList.first
              : null;

          if (fetchedActivity.projectDailyActiviyCode.isNotEmpty) {
            if (existingActivity != null) {
              existingActivity
                ..projectCode = fetchedActivity.projectCode
                ..date = fetchedActivity.date
                ..type = fetchedActivity.type
                ..description = fetchedActivity.description
                ..amount = fetchedActivity.amount
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingActivity.save();
              print(
                  'DailyActivity ${fetchedActivity.projectDailyActiviyCode} updated successfully.');
            } else {
              await _dailyActivityBox!.add(fetchedActivity);
              print(
                  'DailyActivity ${fetchedActivity.projectDailyActiviyCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('DailyActivity with no code was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch DailyActivities. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing DailyActivities: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncProjectStudentPayment =======================================================================//

  @override
  void dispose() {
    super.dispose();
  }
}

class SyncQueueManager {
  static final SyncQueueManager _instance = SyncQueueManager._internal();
  factory SyncQueueManager() => _instance;
  SyncQueueManager._internal();

  final List<dynamic> _syncQueue = [];
  bool _isSyncing = false;
  bool _hasInternet = false;

  final Map<Type, SyncFunction<dynamic>> _createHandlers = {};
  final Map<Type, SyncFunction<dynamic>> _updateHandlers = {};

  void registerCreateHandler<T>(SyncFunction<T> handler) {
    _createHandlers[T] = (model) => handler(model as T);
  }

  void registerUpdateHandler<T>(SyncFunction<T> handler) {
    _updateHandlers[T] = (model) => handler(model as T);
  }

  void setInternetStatus(bool status) {
    print('[SyncQueueManager] Internet status changed: $status');

    _hasInternet = status;
    if (_hasInternet && !_isSyncing) _processQueue();
  }

  void enqueue(dynamic model) {
    print(
        '[SyncQueueManager] Enqueuing model: ${model.runtimeType}, key: ${model.key}');

    if (!_syncQueue.contains(model)) {
      _syncQueue.add(model);
      if (_hasInternet && !_isSyncing) {
        _processQueue();
      }
    } else {
      print('[SyncQueueManager] Model already in queue: ${model.runtimeType}');
    }
  }

  Future<void> _processQueue() async {
    print('[SyncQueueManager] Starting sync process...');

    _isSyncing = true;
    while (_syncQueue.isNotEmpty && _hasInternet) {
      final model = _syncQueue.first;
      print(
          '[SyncQueueManager] Processing model: ${model.runtimeType}, key: ${model.key}');

      try {
        bool success = await _syncModel(model);
        if (success) {
          print(
              '[SyncQueueManager] Sync successful: ${model.runtimeType}, key: ${model.key}');

          _syncQueue.removeAt(0);
        } else {
          print(
              '[SyncQueueManager] Sync failed, retrying later: ${model.runtimeType}');

          await Future.delayed(const Duration(seconds: 5)); // retry delay
        }
      } catch (e) {
        print('[SyncQueueManager] Exception syncing ${model.runtimeType}: $e');

        _logFailure(model, e.toString());
        await Future.delayed(const Duration(seconds: 10));
      }
    }
    print('[SyncQueueManager] Finished sync process.');

    _isSyncing = false;
  }

  Future<bool> _syncModel(dynamic model) async {
    print(
        '[SyncQueueManager] Determining sync action for: ${model.runtimeType}, operation: ${model.operationType}');

    if (model.operationType == 'create') {
      return await _pushCreate(model);
    } else if (model.operationType == 'update') {
      return await _pushUpdate(model);
    }
    return true;
  }

  Future<bool> _pushCreate(dynamic model) async {
    print('[SyncQueueManager] Pushing create for: ${model.runtimeType}');

    try {
      final handler = _createHandlers[model.runtimeType];
      if (handler != null) {
        await handler(model);
        return model.syncStatus == true && model.operationType == 'none';
      } else {
        print(
            '[SyncQueueManager] No create handler found for: ${model.runtimeType}');
      }
      return false;
    } catch (e) {
      print('[SyncQueueManager] Exception during create: $e');

      return false;
    }
  }

  Future<bool> _pushUpdate(dynamic model) async {
    print('[SyncQueueManager] Pushing update for: ${model.runtimeType}');

    try {
      final handler = _updateHandlers[model.runtimeType];
      if (handler != null) {
        await handler(model);
        return model.syncStatus == true && model.operationType == 'none';
      } else {
        print(
            '[SyncQueueManager] No update handler found for: ${model.runtimeType}');
      }
      return false;
    } catch (e) {
      print('[SyncQueueManager] Exception during update: $e');

      return false;
    }
  }

  void _logFailure(dynamic model, String error) async {
    final logBox = await Hive.openBox('sync_logs');
    logBox.add({
      'timestamp': DateTime.now().toIso8601String(),
      'model': model.runtimeType.toString(),
      'id': model.key.toString(),
      'error': error,
    });
  }
}







/*
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';

import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';

import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';

class ClassesFinal extends StatefulWidget {
  const ClassesFinal({super.key});

  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

class _SyncClassesPageState extends State<ClassesFinal> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }

  Box<Classes>? _classesBox;
  Box<School>? _schoolBox;
  Box<Terms>? _termsBox;
  Box<Withdrawal>? _withdrawalsBox;
  Box<Student>? _studentsBox;
  Box<User>? _usersBox;
  Box<PaymentPurpose>? _payment_purposesBox;
  Box<StudentPayment>? _student_paymentsBox;
  Box<Teachers>? _teachersBox;
  Box<TeacherPaymentsPurposes>? _teacher_payments_purposesBox;
  Box<TeacherPayment>? _teacher_paymentsBox;

  Box<DomainRecord>? _domainRecordBox;
  Box<Account>? _accountBox;
  Box<Asset>? _assetBox;
  Box<Project>? _projectBox;
  Box<ProjectItem>? _projectItemBox;
  Box<DailyActivity>? _dailyActivityBox;
  Box<ProjectStudentPayment>? _projectStudentPaymentBox;

  bool _isSyncing = false;
  bool _isSyncings = false;
  bool areDomainsActive = false;
  String _domainName = ""; // Local variable to store domain name

  @override
  void initState() {
    super.initState();
    _openHiveBox();
    _loadExistingConfig(); // Load domain name from Hive
  }

  Future<void> _openHiveBox() async {
    _classesBox = await Hive.openBox<Classes>('classes');
    _schoolBox = await Hive.openBox<School>('school');
    _termsBox = await Hive.openBox<Terms>('terms');
    _withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
    _studentsBox = await Hive.openBox<Student>('students');
    _usersBox = await Hive.openBox<User>('users');
    _payment_purposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    _student_paymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    _teachersBox = await Hive.openBox<Teachers>('teachers');
    _teacher_payments_purposesBox = await Hive.openBox<TeacherPaymentsPurposes>(
        'teacher_payments_purposes');
    _teacher_paymentsBox =
        await Hive.openBox<TeacherPayment>('teacher_payments');

    _domainRecordBox = await Hive.openBox<DomainRecord>('domainBox');
    _accountBox = await Hive.openBox<Account>('account');
    _assetBox = await Hive.openBox<Asset>('asset');
    _projectBox = await Hive.openBox<Project>('projects');
    _projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
    _dailyActivityBox = await Hive.openBox<DailyActivity>('dailyActivities');
    _projectStudentPaymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
  }

  Future<void> _loadExistingConfig() async {
    final box = await Hive.openBox<DomainRecord>('domainBox');
    if (box.isNotEmpty) {
      final record = box.getAt(0);
      if (record != null) {
        setState(() {
          _domainName = record.domainName ?? "null"; // Default value
          if (_domainName != "null") {
            areDomainsActive = record.areDomainsActive ?? false;
          } else {
            areDomainsActive = false;
          }
          debugPrint(_domainName);
          debugPrint(areDomainsActive.toString());
        });
      }
    }
  }

  Future<List<Classes>> _fetchClassesForCreate() async {
    List<Classes> createClasses = _classesBox!.values
        .where((cls) => cls.syncStatus == false && cls.classCode != null)
        .toList();

    return createClasses;
  }

  Future<List<School>> _fetch_schoolForCreate() async {
    List<School> createSchools = _schoolBox!.values
        .where((cls) => cls.syncStatus == false && cls.schoolCode != null)
        .toList();

    return createSchools;
  }

  Future<List<Terms>> _fetch_termsForCreate() async {
    List<Terms> createTerms = _termsBox!.values
        .where((cls) => cls.syncStatus == false && cls.termId != null)
        .toList();

    return createTerms;
  }

  Future<List<Withdrawal>> _fetch_withdrawalsForCreate() async {
    List<Withdrawal> createWithdrawal = _withdrawalsBox!.values
        .where((cls) => cls.syncStatus == false && cls.withdrawalCode != null)
        .toList();
    return createWithdrawal;
  }

  Future<List<Student>> _fetch_studentsForCreate() async {
    List<Student> createStudent = _studentsBox!.values
        .where((cls) => cls.syncStatus == false && cls.studentIdNumber != null)
        .toList();
    return createStudent;
  }

  Future<List<User>> _fetch_usersForCreate() async {
    List<User> createUser = _usersBox!.values
        .where((cls) => cls.syncStatus == false && cls.userCode != null)
        .toList();
    return createUser;
  }

  Future<List<PaymentPurpose>> _fetch_paymentPurposesForCreate() async {
    List<PaymentPurpose> createPaymentPurpose = _payment_purposesBox!.values
        .where((cls) => cls.syncStatus == false && cls.purposeCode != null)
        .toList();
    return createPaymentPurpose;
  }

  Future<List<StudentPayment>> _fetch_studentPaymentsForCreate() async {
    List<StudentPayment> createStudentPayment = _student_paymentsBox!.values
        .where((cls) => cls.syncStatus == false && cls.receiptNumber != null)
        .toList();
    return createStudentPayment;
  }

  Future<List<Teachers>> _fetch_teachersForCreate() async {
    List<Teachers> createTeachers = _teachersBox!.values
        .where((cls) => cls.syncStatus == false && cls.IdNumber != null)
        .toList();
    return createTeachers;
  }

  // Sync models to MySQL
  Future<void> _syncModels() async {
    try {
      // Sync PaymentPurpose records

      List<Classes> createClasses =
          _classesBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Classes cls in createClasses) {
        if (cls.operationType == 'create') {
          await _createClassInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateClassesInMySQL(cls);
        }
      }

      List<School> createSchool =
          _schoolBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (School cls in createSchool) {
        if (cls.operationType == 'create') {
          await _createSchoolInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateSchoolInMySQL(cls);
        }
      }

      List<Terms> createTerms =
          _termsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Terms cls in createTerms) {
        if (cls.operationType == 'create') {
          await _createTermsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTermsInMySQL(cls);
        }
      }

      List<Withdrawal> createWithdrawal = _withdrawalsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (Withdrawal cls in createWithdrawal) {
        if (cls.operationType == 'create') {
          await _createWithdrawalsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateWithdrawalsInMySQL(cls);
        }
      }
      List<Student> createStudent =
          _studentsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Student cls in createStudent) {
        if (cls.operationType == 'create') {
          await _createStudentsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentsInMySQL(cls);
        }
      }

      List<User> createUser =
          _usersBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (User cls in createUser) {
        if (cls.operationType == 'create') {
          await _createUserInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateUserInMySQL(cls);
        }
      }

      List<PaymentPurpose> createPaymentPurpose = _payment_purposesBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (PaymentPurpose cls in createPaymentPurpose) {
        if (cls.operationType == 'create') {
          await _createPaymentPurposeInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updatePaymentPurposeInMySQL(cls);
        }
      }
      List<StudentPayment> createStudentPayment = _student_paymentsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (StudentPayment cls in createStudentPayment) {
        if (cls.operationType == 'create') {
          await _createStudentPaymentInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentPaymentInMySQL(cls);
        }
      }

      List<Teachers> createTeacher =
          _teachersBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Teachers cls in createTeacher) {
        if (cls.operationType == 'create') {
          await _createTeacherInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTeacherInMySQL(cls);
        }
      }

      List<TeacherPaymentsPurposes> createTeacherPaymentsPurposes =
          _teacher_payments_purposesBox!.values
              .where((cls) => cls.syncStatus == false)
              .toList();
      for (TeacherPaymentsPurposes cls in createTeacherPaymentsPurposes) {
        if (cls.operationType == 'create') {
          await _createTeacherPaymentPurposeInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTeacherPaymentPurposeInMySQL(cls);
        }
      }

      List<TeacherPayment> createTeacherPayments = _teacher_paymentsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (TeacherPayment cls in createTeacherPayments) {
        if (cls.operationType == 'create') {
          await _createTeacherPaymentInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTeacherPaymentInMySQL(cls);
        }
      }
      // Sync DomainRecords
      List<DomainRecord> createDomains = _domainRecordBox!.values
          .where((dom) => dom.syncStatus == false)
          .toList();
      for (DomainRecord dom in createDomains) {
        if (dom.operationType == 'create') {
          await _createDomainInMySQL(dom);
        } else if (dom.operationType == 'update') {
          await _updateDomainInMySQL(dom);
        }
      }

      // Sync Accounts
      List<Account> createAccounts =
          _accountBox!.values.where((acc) => acc.syncStatus == false).toList();
      for (Account acc in createAccounts) {
        if (acc.operationType == 'create') {
          await _createAccountInMySQL(acc);
        } else if (acc.operationType == 'update') {
          await _updateAccountInMySQL(acc);
        }
      }

      // Sync Assets
      List<Asset> createAssets =
          _assetBox!.values.where((a) => a.syncStatus == false).toList();
      for (Asset a in createAssets) {
        if (a.operationType == 'create') {
          await _createAssetInMySQL(a);
        } else if (a.operationType == 'update') {
          await _updateAssetInMySQL(a);
        }
      }

      // Sync Projects
      List<Project> createProjects =
          _projectBox!.values.where((p) => p.syncStatus == false).toList();
      for (Project p in createProjects) {
        if (p.operationType == 'create') {
          await _createProjectInMySQL(p);
        } else if (p.operationType == 'update') {
          await _updateProjectInMySQL(p);
        }
      }

      // Sync ProjectItems
      List<ProjectItem> createProjectItems = _projectItemBox!.values
          .where((pi) => pi.syncStatus == false)
          .toList();
      for (ProjectItem pi in createProjectItems) {
        if (pi.operationType == 'create') {
          await _createProjectItemInMySQL(pi);
        } else if (pi.operationType == 'update') {
          await _updateProjectItemInMySQL(pi);
        }
      }

      // Sync DailyActivities
      List<DailyActivity> createDailyActivities = _dailyActivityBox!.values
          .where((d) => d.syncStatus == false)
          .toList();
      for (DailyActivity d in createDailyActivities) {
        if (d.operationType == 'create') {
          await _createDailyActivityInMySQL(d);
        } else if (d.operationType == 'update') {
          await _updateDailyActivityInMySQL(d);
        }
      }

      // Sync ProjectStudentPayments
      List<ProjectStudentPayment> createProjectPayments =
          _projectStudentPaymentBox!.values
              .where((p) => p.syncStatus == false)
              .toList();
      for (ProjectStudentPayment p in createProjectPayments) {
        if (p.operationType == 'create') {
          await _createProjectStudentPaymentInMySQL(p);
        } else if (p.operationType == 'update') {
          await _updateProjectStudentPaymentInMySQL(p);
        }
      }
    } catch (e) {
      print('Error syncing models: $e');
    }
  }

  Map<String, dynamic> _classToJson(Classes cls) {
    return {
      'id': cls.id,
      'classCode': cls.classCode,
      'className': cls.className,
      'date': cls.date.toIso8601String(),
      'termId': cls.termId,
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
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
    };
  }

  Map<String, dynamic> _studentInfoToJson(Student cls) {
    return {
      'name': cls.name,
      'surname': cls.surname,
      'regNumber': cls.regNumber,
      'class': cls.class_,
      'gender': cls.gender,
      'age': cls.age.toIso8601String(),
      'phoneNumber': cls.phoneNumber,
      'paymentStatus': cls.paymentStatus,
      'isPresent': cls.isPresent,
      'presentDates': jsonEncode(
          cls.presentDates.map((date) => date.toIso8601String()).toList()),
      'absentDates': jsonEncode(
          cls.absentDates.map((date) => date.toIso8601String()).toList()),
      'termId': cls.termId,
      'id': cls.id,
      'physicalAddress': cls.physicalAddress,
      'formerSchool': cls.formerSchool,
      'religion': cls.religion,
      'denomination': cls.denomination,
      'studentIdNumber': cls.studentIdNumber,
      'nationalIdNumber': cls.nationalIdNumber,
      'nationality': cls.nationality,
      'district': cls.district,
      'previousSchoolPerformanceResults': cls.previousSchoolPerformanceResults,
      'enrollmentStatus': cls.enrollmentStatus,
      'emergencyContactName': cls.emergencyContactName,
      'emergencyContactNumber': cls.emergencyContactNumber,
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
          : null,
    };
  }

  Map<String, dynamic> _userToJson(User cls) {
    return {
      'id': cls.id,
      'username': cls.username,
      'password': cls.password,
      'role': cls.role,
      'securityQuestions': jsonEncode(cls.securityQuestions),
      'securityAnswers': jsonEncode(cls.securityAnswers),
      'phone': cls.phone,
      'termId': cls.termId,
      'userCode': cls.userCode,
    };
  }

  Map<String, dynamic> _paymentPurposeToJson(PaymentPurpose cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
      'associatedClasses':
          jsonEncode(cls.associatedClasses), // Convert list to JSON
      'purposeCode': cls.purposeCode,
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
    };
  }

  Map<String, dynamic> _teacherToJson(Teachers cls) {
    return {
      'id': cls.id,
      'name': cls.name,
      'surname': cls.surname,
      'IdNumber': cls.IdNumber,
      'assignedClass': cls.assignedClass,
      'assignedClasses': cls.assignedClasses != null
          ? jsonEncode(cls.assignedClasses) // JSON encode the list
          : null,
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
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
          : null,
    };
  }

  Map<String, dynamic> _teacherPaymentsPurposeToJson(
      TeacherPaymentsPurposes cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeCode': cls.purposeCode,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
      'syncStatus': cls.syncStatus,
      'lastModified': cls.lastModified?.toIso8601String(),
      'operationType': cls.operationType,
      'associatedStaff': cls.associatedStaff != null
          ? jsonEncode(
              cls.associatedStaff) // Explicit JSON encode for associatedStaff
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
    };
  }

  Map<String, dynamic> _domainsToJson(DomainRecord domain) => {
        'domainName': domain.domainName,
        'areDomainsActive': domain.areDomainsActive,
        'syncStatus': domain.syncStatus,
        'operationType': domain.operationType,
        'lastModified': domain.lastModified?.toIso8601String(),
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
        'modifiedFields': acc.modifiedFields,
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
      'modifiedFields': asset.modifiedFields,
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
        'modifiedFields': p.modifiedFields,
      };
  Map<String, dynamic> _project_itemsToJson(ProjectItem i) => {
        'projectItemCode': i.projectItemCode,
        'projectCode': i.projectCode,
        'name': i.name,
        'amount': i.amount,
        'isStudentFee': i.isStudentFee,
        'syncStatus': i.syncStatus,
        'lastModified': i.lastModified?.toIso8601String(),
        'operationType': i.operationType,
        'modifiedFields': i.modifiedFields,
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
        'modifiedFields': a.modifiedFields,
      };
  Map<String, dynamic> _project_student_paymentsToJson(
          ProjectStudentPayment p) =>
      {
        'projectStudentPaymentCode': p.projectStudentPaymentCode,
        'studentId': p.studentId,
        'projectCode': p.projectCode,
        'itemId': p.itemId,
        'amountPaid': p.amountPaid,
        'balance': p.balance,
        'syncStatus': p.syncStatus,
        'lastModified': p.lastModified?.toIso8601String(),
        'operationType': p.operationType,
        'modifiedFields': p.modifiedFields,
      };
  //=================== techers payment  sync =========================

  Future<void> _createTeacherPaymentInMySQL(TeacherPayment newClass) async {
    final Map<String, dynamic> jsonData = _teacherPaymentclassToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTeacherPaymentInMySQL(TeacherPayment newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'studentName':
          modifiedFieldsJson['studentName'] = newClass.studentName;
          break;
        case 'studentSurname':
          modifiedFieldsJson['studentSurname'] = newClass.studentSurname;
          break;
        case 'studentClass':
          modifiedFieldsJson['studentClass'] = newClass.studentClass;
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;

        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;

        case 'amountToPay':
          modifiedFieldsJson['amountToPay'] = newClass.amountToPay;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              newClass.paymentDate.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'receiptNumber':
          modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== techers payment purpose sync =========================

  Future<void> _createTeacherPaymentPurposeInMySQL(
      TeacherPaymentsPurposes newClass) async {
    final Map<String, dynamic> jsonData =
        _teacherPaymentsPurposeToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create IdNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTeacherPaymentPurposeInMySQL(
      TeacherPaymentsPurposes newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;
        case 'purposeCode':
          modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
          break;
        case 'purposeAmount':
          modifiedFieldsJson['purposeAmount'] = newClass.purposeAmount;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;

        case 'associatedStaff':
          modifiedFieldsJson['associatedStaff'] = newClass.associatedStaff !=
                  null
              ? jsonEncode(newClass
                  .associatedStaff) // Explicit JSON encode for associatedStaff
              : null;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update purposeCode.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== techers  sync =========================

  Future<void> _createTeacherInMySQL(Teachers newClass) async {
    final Map<String, dynamic> jsonData = _teacherToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php?IdNumber=${newClass.IdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('IdNumber ${newClass.IdNumber} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create IdNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating IdNumber: $e');
      print('Stack Trace: $stackTrace');
      print('IdNumber Details:');
      print('IdNumber: ${newClass.IdNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTeacherInMySQL(Teachers newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'name':
          modifiedFieldsJson['name'] = newClass.name;
          break;
        case 'surname':
          modifiedFieldsJson['surname'] = newClass.surname;
          break;
        case 'IdNumber':
          modifiedFieldsJson['IdNumber'] = newClass.IdNumber;
          break;
        case 'assignedClass':
          modifiedFieldsJson['assignedClass'] = newClass.assignedClass;
          break;
        case 'assignedClasses':
          modifiedFieldsJson['assignedClasses'] =
              newClass.assignedClasses != null
                  ? jsonEncode(newClass.assignedClasses) // JSON encode the list
                  : null;
          break;
        case 'gender':
          modifiedFieldsJson['gender'] = newClass.gender;
          break;
        case 'dateOfBirth':
          modifiedFieldsJson['dateOfBirth'] =
              newClass.dateOfBirth.toIso8601String();
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;
        case 'isPaid':
          modifiedFieldsJson['isPaid'] = newClass.isPaid;
          break;
        case 'paymentAmount':
          modifiedFieldsJson['paymentAmount'] = newClass.paymentAmount;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              newClass.paymentDate?.toIso8601String();
          break;
        case 'email':
          modifiedFieldsJson['email'] = newClass.email;
          break;
        case 'address':
          modifiedFieldsJson['address'] = newClass.address;
          break;
        case 'hireDate':
          modifiedFieldsJson['hireDate'] = newClass.hireDate.toIso8601String();
          break;
        case 'qualifications':
          modifiedFieldsJson['qualifications'] = newClass.qualifications;
          break;
        case 'employmentStatus':
          modifiedFieldsJson['employmentStatus'] = newClass.employmentStatus;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;

        // Add other fields as needed in this format
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['IdNumber'] = newClass.IdNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php?IdNumber=${newClass.IdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('IdNumber ${newClass.IdNumber} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update IdNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating IdNumber: $e');
      print('Stack Trace: $stackTrace');
      print('IdNumber Details:');
      print('IdNumber: ${newClass.IdNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== student payment sync =========================

  Future<void> _createStudentPaymentInMySQL(StudentPayment newClass) async {
    final Map<String, dynamic> jsonData = _studentPaymentToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateStudentPaymentInMySQL(StudentPayment newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'studentName':
          modifiedFieldsJson['studentName'] = newClass.studentName;
          break;
        case 'studentSurname':
          modifiedFieldsJson['studentSurname'] = newClass.studentSurname;
          break;
        case 'studentClass':
          modifiedFieldsJson['studentClass'] = newClass.studentClass;
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;

        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;

        case 'amountToPay':
          modifiedFieldsJson['amountToPay'] = newClass.amountToPay;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              newClass.paymentDate.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'receiptNumber':
          modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['receiptNumber'] = newClass.receiptNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newClass.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('receiptNumber ${newClass.receiptNumber} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update receiptNumber.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating receiptNumber: $e');
      print('Stack Trace: $stackTrace');
      print('receiptNumber Details:');
      print('receiptNumber: ${newClass.receiptNumber}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
  //=================== purpose sync =========================

  Future<void> _createPaymentPurposeInMySQL(PaymentPurpose newClass) async {
    final Map<String, dynamic> jsonData = _paymentPurposeToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create purposeCode.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updatePaymentPurposeInMySQL(PaymentPurpose newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = newClass.paymentPurpose;
          break;
        case 'purposeAmount':
          modifiedFieldsJson['purposeAmount'] = newClass.purposeAmount;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'associatedClasses':
          modifiedFieldsJson['associatedClasses'] =
              jsonEncode(newClass.associatedClasses);
          break;

        case 'purposeCode':
          modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['purposeCode'] = newClass.purposeCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newClass.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('purposeCode ${newClass.purposeCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update purposeCode.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating purposeCode: $e');
      print('Stack Trace: $stackTrace');
      print('purposeCode Details:');
      print('purposeCode: ${newClass.purposeCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== users sync =========================

  Future<void> _createUserInMySQL(User newClass) async {
    final Map<String, dynamic> jsonData = _userToJson(newClass);

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newClass.userCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Users ${newClass.userCode} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create Users.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error creating Users: $e');
      print('Stack Trace: $stackTrace');
      print('User Details:');
      print('UserCode: ${newClass.userCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateUserInMySQL(User newClass) async {
    // final Map<String, dynamic> jsonData = _userToJson(newClass);

    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'username':
          modifiedFieldsJson['username'] = newClass.username;
          break;
        case 'password':
          modifiedFieldsJson['password'] = newClass.password;
          break;
        case 'role':
          modifiedFieldsJson['role'] = newClass.role;
          break;
        case 'securityQuestions':
          modifiedFieldsJson['securityQuestions'] =
              jsonEncode(newClass.securityQuestions);
          break;
        case 'securityAnswers':
          modifiedFieldsJson['securityAnswers'] =
              jsonEncode(newClass.securityAnswers);
          break;
        case 'phone':
          modifiedFieldsJson['phone'] = newClass.phone;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'userCode':
          modifiedFieldsJson['userCode'] = newClass.userCode;
          break;
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['userCode'] = newClass.userCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newClass.userCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Users ${newClass.userCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update users.');
      }
    } catch (e, stackTrace) {
      // Print a detailed debug log
      print('--- Exception Details ---');
      print('Error updating Users: $e');
      print('Stack Trace: $stackTrace');
      print('User Details:');
      print('UserCode: ${newClass.userCode}');
      print('OperationType: ${newClass.operationType}');
      print('SyncStatus: ${newClass.syncStatus}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== students sync =========================

  Future<void> _createStudentsInMySQL(Student newClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newClass.studentIdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Students ${newClass.studentIdNumber} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create students.');
      }
    } catch (e) {
      print('Error creating students: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateStudentsInMySQL(Student newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        case 'name':
          modifiedFieldsJson['name'] = newClass.name;
          break;
        case 'surname':
          modifiedFieldsJson['surname'] = newClass.surname;
          break;
        case 'regNumber':
          modifiedFieldsJson['regNumber'] = newClass.regNumber;
          break;
        case 'class_':
          modifiedFieldsJson['class'] = newClass.class_;
          break;
        case 'gender':
          modifiedFieldsJson['gender'] = newClass.gender;
          break;
        case 'age':
          modifiedFieldsJson['age'] = newClass.age.toIso8601String();
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = newClass.phoneNumber;
          break;
        case 'paymentStatus':
          modifiedFieldsJson['paymentStatus'] = newClass.paymentStatus;
          break;
        case 'isPresent':
          modifiedFieldsJson['isPresent'] = newClass.isPresent;
          break;
        case 'presentDates':
          modifiedFieldsJson['presentDates'] = jsonEncode(newClass.presentDates
              .map((date) => date.toIso8601String())
              .toList());
          break;
        case 'absentDates':
          modifiedFieldsJson['absentDates'] = jsonEncode(newClass.absentDates
              .map((date) => date.toIso8601String())
              .toList());
          break;
        case 'id':
          modifiedFieldsJson['id'] = newClass.id;
          break;
        case 'physicalAddress':
          modifiedFieldsJson['physicalAddress'] = newClass.physicalAddress;
          break;
        case 'formerSchool':
          modifiedFieldsJson['formerSchool'] = newClass.formerSchool;
          break;
        case 'religion':
          modifiedFieldsJson['religion'] = newClass.religion;
          break;
        case 'denomination':
          modifiedFieldsJson['denomination'] = newClass.denomination;
          break;
        case 'studentIdNumber':
          modifiedFieldsJson['studentIdNumber'] = newClass.studentIdNumber;
          break;
        case 'nationalIdNumber':
          modifiedFieldsJson['nationalIdNumber'] = newClass.nationalIdNumber;
          break;
        case 'nationality':
          modifiedFieldsJson['nationality'] = newClass.nationality;
          break;
        case 'district':
          modifiedFieldsJson['district'] = newClass.district;
          break;
        case 'previousSchoolPerformanceResults':
          modifiedFieldsJson['previousSchoolPerformanceResults'] =
              newClass.previousSchoolPerformanceResults;
          break;
        case 'enrollmentStatus':
          modifiedFieldsJson['enrollmentStatus'] = newClass.enrollmentStatus;
          break;
        case 'emergencyContactName':
          modifiedFieldsJson['emergencyContactName'] =
              newClass.emergencyContactName;
          break;
        case 'emergencyContactNumber':
          modifiedFieldsJson['emergencyContactNumber'] =
              newClass.emergencyContactNumber;
          break;
        // Add other fields as needed in this format
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['studentIdNumber'] = newClass.studentIdNumber;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newClass.studentIdNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Students ${newClass.studentIdNumber} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to update students.');
      }
    } catch (e) {
      print('Error updating students: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//==================== withdrawal sync ======================

  Future<void> _createWithdrawalsInMySQL(Withdrawal newClass) async {
    final Map<String, dynamic> jsonData = _withdrawalToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newClass.withdrawalCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Withdrawals ${newClass.withdrawalCode} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create withdrawals_information.');
      }
    } catch (e) {
      print('Error creating Withdrawal: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateWithdrawalsInMySQL(Withdrawal newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'amount':
          modifiedFieldsJson['amount'] = newClass.amount;
          break;
        case 'withdrawalPurpose':
          modifiedFieldsJson['withdrawalPurpose'] = newClass.withdrawalPurpose;
          break;
        case 'withdrawalCode':
          modifiedFieldsJson['withdrawalCode'] = newClass.withdrawalCode;
          break;
        case 'date':
          modifiedFieldsJson['date'] = newClass.date.toIso8601String();
          break;

        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['withdrawalCode'] = newClass.withdrawalCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newClass.withdrawalCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Withdrawals ${newClass.withdrawalCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        await newClass.save();
        newClass.modifiedFields = [];
      } else {
        throw Exception('Failed to update withdrawals_information.');
      }
    } catch (e) {
      print('Error updating Withdrawal: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//====================== terms sync ==========================
  Future<void> _createTermsInMySQL(Terms newClass) async {
    final Map<String, dynamic> jsonData = _termsToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newClass.termId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Terms ${newClass.termId} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create terms_information.');
      }
    } catch (e) {
      print('Error creating Terms: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateTermsInMySQL(Terms newClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in newClass.modifiedFields ?? []) {
      switch (field) {
        case 'termName':
          modifiedFieldsJson['termName'] = newClass.termName;
          break;
        case 'startDate':
          modifiedFieldsJson['startDate'] =
              newClass.startDate.toIso8601String();
          break;
        case 'endDate':
          modifiedFieldsJson['endDate'] = newClass.endDate?.toIso8601String();
          break;
        case 'isActive':
          modifiedFieldsJson['isActive'] = newClass.isActive;
          break;
        case 'status':
          modifiedFieldsJson['status'] = newClass.status;
          break;

        case 'termId':
          modifiedFieldsJson['termId'] = newClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['termId'] = newClass.termId;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newClass.termId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Terms ${newClass.termId} updated successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to update terms_information.');
      }
    } catch (e) {
      print('Error updating Terms: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//============== classes sync ==============================
  Future<void> _createClassInMySQL(Classes newClass) async {
    final Map<String, dynamic> jsonData = _classToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php?classCode=${newClass.classCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to create classes_information.');
      }
    } catch (e) {
      print('Error creating classes_information: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateClassesInMySQL(Classes updatedClass) async {
    // Extract the modified fields and their values
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in updatedClass.modifiedFields ?? []) {
      switch (field) {
        case 'className':
          modifiedFieldsJson['className'] = updatedClass.className;
          break;
        case 'date':
          modifiedFieldsJson['date'] = updatedClass.date.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }

    // Add the unique identifier to the payload
    modifiedFieldsJson['classCode'] = updatedClass.classCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php?classCode=${updatedClass.classCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Classes ${updatedClass.classCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        updatedClass.syncStatus = true;
        updatedClass.operationType = 'none';
        updatedClass.modifiedFields = [];

        await updatedClass.save();
      } else {
        throw Exception('Failed to update Class.');
      }
    } catch (e) {
      print('Error updating Class: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//================= schools sync ===========================

  Future<void> _createSchoolInMySQL(School newClass) async {
    final Map<String, dynamic> jsonData = _schoolToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${newClass.schoolCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'school_information ${newClass.schoolCode} created successfully.');
        // Update syncStatus and operationType in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];

        await newClass.save();
      } else {
        throw Exception('Failed to create school_information.');
      }
    } catch (e) {
      print('Error creating school_information: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateSchoolInMySQL(School updatedClass) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in updatedClass.modifiedFields ?? []) {
      switch (field) {
        case 'schoolName':
          modifiedFieldsJson['schoolName'] = updatedClass.schoolName;
          break;
        case 'schoolAddress':
          modifiedFieldsJson['schoolAddress'] = updatedClass.schoolAddress;
          break;
        case 'schoolPhoneNumber':
          modifiedFieldsJson['schoolPhoneNumber'] =
              updatedClass.schoolPhoneNumber;
          break;
        case 'schoolEmail':
          modifiedFieldsJson['schoolEmail'] = updatedClass.schoolEmail;
          break;

        case 'termId':
          modifiedFieldsJson['termId'] = updatedClass.termId;
          break;
        // Add cases for other fields as needed
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['schoolCode'] = updatedClass.schoolCode;
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${updatedClass.schoolCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Schools ${updatedClass.schoolCode} updated successfully.');
        // Update syncStatus and operationType in Hive
        updatedClass.syncStatus = true;
        updatedClass.operationType = 'none';
        updatedClass.modifiedFields = [];

        await updatedClass.save();
      } else {
        throw Exception('Failed to update school.');
      }
    } catch (e) {
      print('Error updating school: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  //============================== domains ==========================

  Future<void> _createDomainInMySQL(DomainRecord domain) async {
    final Map<String, dynamic> jsonData = _domainsToJson(domain);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/domain_api.php?domainName=${domain.domainName}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        domain.syncStatus = true;
        domain.operationType = 'none';
        domain.modifiedFields = [];
        await domain.save();
      } else {
        throw Exception('Failed to create domain.');
      }
    } catch (e) {
      print('Error creating domain: \$e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateDomainInMySQL(DomainRecord domain) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in domain.modifiedFields ?? []) {
      switch (field) {
        case 'areDomainsActive':
          modifiedFieldsJson['areDomainsActive'] = domain.areDomainsActive;
          break;
      }
    }
    // Add the unique identifier to the payload
    modifiedFieldsJson['domainName'] = domain.domainName;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/domain_api.php?domainName=${domain.domainName}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        domain.syncStatus = true;
        domain.operationType = 'none';
        domain.modifiedFields = [];
        await domain.save();
      } else {
        throw Exception('Failed to update domain.');
      }
    } catch (e) {
      print('Error updating domain: \$e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
  //============================== accounts type ==========================

  Future<void> _createAccountInMySQL(Account acc) async {
    final Map<String, dynamic> jsonData = _accountsToJson(acc);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php?accountCode=${acc.accountCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        acc.syncStatus = true;
        acc.operationType = 'none';
        acc.modifiedFields = [];
        await acc.save();
      } else {
        throw Exception('Failed to create account.');
      }
    } catch (e) {
      print('Error creating account: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateAccountInMySQL(Account acc) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in acc.modifiedFields ?? []) {
      switch (field) {
        case 'accountType':
          modifiedFieldsJson['accountType'] = acc.accountType;
          break;
        case 'accountSubType':
          modifiedFieldsJson['accountSubType'] = acc.accountSubType;
          break;
        case 'accountName':
          modifiedFieldsJson['accountName'] = acc.accountName;
          break;

        case 'lastModified':
          modifiedFieldsJson['lastModified'] =
              acc.lastModified?.toIso8601String();
          break;
        case 'isALiquidAccount':
          modifiedFieldsJson['isALiquidAccount'] = acc.isALiquidAccount;
          break;
      }
    }

    // Always include the unique identifier
    modifiedFieldsJson['accountCode'] = acc.accountCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php?accountCode=${acc.accountCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        acc.syncStatus = true;
        acc.operationType = 'none';
        acc.modifiedFields = [];
        await acc.save();
      } else {
        throw Exception('Failed to update account.');
      }
    } catch (e) {
      print('Error updating account: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//============================== assets ==========================

  Future<void> _createAssetInMySQL(Asset asset) async {
    final Map<String, dynamic> jsonData = _assetsToJson(asset);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/asset_api.php?assetCode=${asset.assetCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        asset.syncStatus = true;
        asset.operationType = 'none';
        asset.modifiedFields = [];
        await asset.save();
      } else {
        throw Exception('Failed to create asset.');
      }
    } catch (e) {
      print('Error creating asset: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateAssetInMySQL(Asset asset) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in asset.modifiedFields ?? []) {
      switch (field) {
        case 'assetName':
          modifiedFieldsJson['assetName'] = asset.assetName;
          break;
        case 'assetType':
          modifiedFieldsJson['assetType'] = asset.assetType;
          break;
        case 'assetSubType':
          modifiedFieldsJson['assetSubType'] = asset.assetSubType;
          break;

        case 'assetSerialNo':
          modifiedFieldsJson['assetSerialNo'] = asset.assetSerialNo;
          break;
        case 'acquisitionDate':
          modifiedFieldsJson['acquisitionDate'] =
              asset.acquisitionDate?.toIso8601String();
          break;
        case 'acquisitionCost':
          modifiedFieldsJson['acquisitionCost'] = asset.acquisitionCost;
          break;
        case 'acquisitionMethod':
          modifiedFieldsJson['acquisitionMethod'] = asset.acquisitionMethod;
          break;
        case 'department':
          modifiedFieldsJson['department'] = asset.department;
          break;
        case 'location':
          modifiedFieldsJson['location'] = asset.location;
          break;
        case 'depreciationRate':
          modifiedFieldsJson['depreciationRate'] = asset.depreciationRate;
          break;
        case 'depreciationMethod':
          modifiedFieldsJson['depreciationMethod'] = asset.depreciationMethod;
          break;
        case 'lastDepreciationDate':
          modifiedFieldsJson['lastDepreciationDate'] =
              asset.lastDepreciationDate?.toIso8601String();
          break;
        case 'accumulatedDepreciation':
          modifiedFieldsJson['accumulatedDepreciation'] =
              asset.accumulatedDepreciation;
          break;
        case 'bookValue':
          modifiedFieldsJson['bookValue'] = asset.bookValue;
          break;
        case 'isImpaired':
          modifiedFieldsJson['isImpaired'] = asset.isImpaired;
          break;
        case 'impairmentLoss':
          modifiedFieldsJson['impairmentLoss'] = asset.impairmentLoss;
          break;
        case 'revaluationDate':
          modifiedFieldsJson['revaluationDate'] =
              asset.revaluationDate?.toIso8601String();
          break;
        case 'revaluationAmount':
          modifiedFieldsJson['revaluationAmount'] = asset.revaluationAmount;
          break;
        case 'lastMaintenanceDate':
          modifiedFieldsJson['lastMaintenanceDate'] =
              asset.lastMaintenanceDate?.toIso8601String();
          break;
        case 'maintenanceCost':
          modifiedFieldsJson['maintenanceCost'] = asset.maintenanceCost;
          break;
        case 'maintenanceDescription':
          modifiedFieldsJson['maintenanceDescription'] =
              asset.maintenanceDescription;
          break;
        case 'capitalImprovementCost':
          modifiedFieldsJson['capitalImprovementCost'] =
              asset.capitalImprovementCost;
          break;
        case 'capitalImprovementDescription':
          modifiedFieldsJson['capitalImprovementDescription'] =
              asset.capitalImprovementDescription;
          break;
        case 'disposalDate':
          modifiedFieldsJson['disposalDate'] =
              asset.disposalDate?.toIso8601String();
          break;
        case 'disposalProceeds':
          modifiedFieldsJson['disposalProceeds'] = asset.disposalProceeds;
          break;
        case 'disposalReason':
          modifiedFieldsJson['disposalReason'] = asset.disposalReason;
          break;
        case 'gainOrLossOnDisposal':
          modifiedFieldsJson['gainOrLossOnDisposal'] =
              asset.gainOrLossOnDisposal;
          break;
        case 'isLeased':
          modifiedFieldsJson['isLeased'] = asset.isLeased;
          break;
        case 'leaseType':
          modifiedFieldsJson['leaseType'] = asset.leaseType;
          break;
        case 'leaseStartDate':
          modifiedFieldsJson['leaseStartDate'] =
              asset.leaseStartDate?.toIso8601String();
          break;
        case 'leaseEndDate':
          modifiedFieldsJson['leaseEndDate'] =
              asset.leaseEndDate?.toIso8601String();
          break;
        case 'leasePaymentAmount':
          modifiedFieldsJson['leasePaymentAmount'] = asset.leasePaymentAmount;
          break;
        case 'lastAuditDate':
          modifiedFieldsJson['lastAuditDate'] =
              asset.lastAuditDate?.toIso8601String();
          break;
        case 'notes':
          modifiedFieldsJson['notes'] = asset.notes;
          break;
        case 'lastModified':
          modifiedFieldsJson['lastModified'] =
              asset.lastModified?.toIso8601String();
          break;
        case 'usefulLife':
          modifiedFieldsJson['usefulLife'] = asset.usefulLife;
          break;
        case 'hasDebitBalance':
          modifiedFieldsJson['hasDebitBalance'] = asset.hasDebitBalance;
          break;
        case 'hasCreditBalance':
          modifiedFieldsJson['hasCreditBalance'] = asset.hasCreditBalance;
          break;
        case 'option':
          modifiedFieldsJson['option'] = asset.option;
          break;
      }
    }

    modifiedFieldsJson['assetCode'] = asset.assetCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/asset_api.php?assetCode=${asset.assetCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        asset.syncStatus = true;
        asset.operationType = 'none';
        asset.modifiedFields = [];
        await asset.save();
      } else {
        throw Exception('Failed to update asset.');
      }
    } catch (e) {
      print('Error updating asset: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//============================== projects ==========================

  Future<void> _createProjectInMySQL(Project p) async {
    final Map<String, dynamic> jsonData = _projectsToJson(p);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php?projectCode=${p.projectCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        p.syncStatus = true;
        p.operationType = 'none';
        p.modifiedFields = [];
        await p.save();
      } else {
        throw Exception('Failed to create project.');
      }
    } catch (e) {
      print('Error creating project: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateProjectInMySQL(Project p) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in p.modifiedFields ?? []) {
      switch (field) {
        case 'name':
          modifiedFieldsJson['name'] = p.name;
          break;
        case 'description':
          modifiedFieldsJson['description'] = p.description;
          break;
        case 'status':
          modifiedFieldsJson['status'] = p.status;
          break;
        case 'createdAt':
          modifiedFieldsJson['createdAt'] = p.createdAt.toIso8601String();
          break;
      }
    }

    modifiedFieldsJson['projectCode'] = p.projectCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php?projectCode=${p.projectCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        p.syncStatus = true;
        p.operationType = 'none';
        p.modifiedFields = [];
        await p.save();
      } else {
        throw Exception('Failed to update project.');
      }
    } catch (e) {
      print('Error updating project: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//============================== dailyActivities ==========================

  Future<void> _createDailyActivityInMySQL(DailyActivity a) async {
    final Map<String, dynamic> jsonData = _daily_activitiesToJson(a);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_daily_activity_api.php?projectDailyActiviyCode=${a.projectDailyActiviyCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        a.syncStatus = true;
        a.operationType = 'none';
        a.modifiedFields = [];
        await a.save();
      } else {
        throw Exception('Failed to create daily activity.');
      }
    } catch (e) {
      print('Error creating daily activity: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateDailyActivityInMySQL(DailyActivity a) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in a.modifiedFields ?? []) {
      switch (field) {
        case 'projectCode':
          modifiedFieldsJson['projectCode'] = a.projectCode;
          break;
        case 'date':
          modifiedFieldsJson['date'] = a.date.toIso8601String();
          break;
        case 'type':
          modifiedFieldsJson['type'] = a.type;
          break;
        case 'description':
          modifiedFieldsJson['description'] = a.description;
          break;
        case 'amount':
          modifiedFieldsJson['amount'] = a.amount;
          break;
      }
    }

    modifiedFieldsJson['projectDailyActiviyCode'] = a.projectDailyActiviyCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_daily_activity_api.php?projectDailyActiviyCode=${a.projectDailyActiviyCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        a.syncStatus = true;
        a.operationType = 'none';
        a.modifiedFields = [];
        await a.save();
      } else {
        throw Exception('Failed to update daily activity.');
      }
    } catch (e) {
      print('Error updating daily activity: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//============================== projectStudentPayments ==========================

  Future<void> _createProjectStudentPaymentInMySQL(
      ProjectStudentPayment p) async {
    final Map<String, dynamic> jsonData = _project_student_paymentsToJson(p);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_student_payment_api.php?projectStudentPaymentCode=${p.projectStudentPaymentCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        p.syncStatus = true;
        p.operationType = 'none';
        p.modifiedFields = [];
        await p.save();
      } else {
        throw Exception('Failed to create project student payment.');
      }
    } catch (e) {
      print('Error creating project student payment: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateProjectStudentPaymentInMySQL(
      ProjectStudentPayment p) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in p.modifiedFields ?? []) {
      switch (field) {
        case 'studentId':
          modifiedFieldsJson['studentId'] = p.studentId;
          break;
        case 'projectCode':
          modifiedFieldsJson['projectCode'] = p.projectCode;
          break;
        case 'itemId':
          modifiedFieldsJson['itemId'] = p.itemId;
          break;
        case 'amountPaid':
          modifiedFieldsJson['amountPaid'] = p.amountPaid;
          break;
        case 'balance':
          modifiedFieldsJson['balance'] = p.balance;
          break;
      }
    }

    modifiedFieldsJson['projectStudentPaymentCode'] =
        p.projectStudentPaymentCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_student_payment_api.php?projectStudentPaymentCode=${p.projectStudentPaymentCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        p.syncStatus = true;
        p.operationType = 'none';
        p.modifiedFields = [];
        await p.save();
      } else {
        throw Exception('Failed to update project student payment.');
      }
    } catch (e) {
      print('Error updating project student payment: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//============================== projectItems ==========================

  Future<void> _createProjectItemInMySQL(ProjectItem i) async {
    final Map<String, dynamic> jsonData = _project_itemsToJson(i);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php?projectItemCode=${i.projectItemCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        i.syncStatus = true;
        i.operationType = 'none';
        i.modifiedFields = [];
        await i.save();
      } else {
        throw Exception('Failed to create project item.');
      }
    } catch (e) {
      print('Error creating project item: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  Future<void> _updateProjectItemInMySQL(ProjectItem i) async {
    final Map<String, dynamic> modifiedFieldsJson = {};
    for (String field in i.modifiedFields ?? []) {
      switch (field) {
        case 'projectCode':
          modifiedFieldsJson['projectCode'] = i.projectCode;
          break;
        case 'name':
          modifiedFieldsJson['name'] = i.name;
          break;
        case 'amount':
          modifiedFieldsJson['amount'] = i.amount;
          break;
        case 'isStudentFee':
          modifiedFieldsJson['isStudentFee'] = i.isStudentFee;
          break;
      }
    }

    modifiedFieldsJson['projectItemCode'] = i.projectItemCode;

    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php?projectItemCode=${i.projectItemCode}',
        ),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        i.syncStatus = true;
        i.operationType = 'none';
        i.modifiedFields = [];
        await i.save();
      } else {
        throw Exception('Failed to update project item.');
      }
    } catch (e) {
      print('Error updating project item: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();

    final isLargeScreen =
        MediaQuery.of(context).size.width > 800; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Synchronization'),
      body: LayoutBuilder(builder: (context, constraints) {
        return Row(
          children: [
            if (constraints.maxWidth >= 540)
              SizedBox(
                width: 250,
                child: CustomDrawerAdmin(loggedInUser: loggedInUser),
              ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.fromRGBO(0, 233, 254, 1),
                              Color.fromARGB(0, 233, 254, 1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 600),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Sync All Records Button

                                    buildFutureSchoolsWidget(
                                        isLargeScreen: isLargeScreen),

                                    _isSyncings
                                        ? const Center(
                                            child: SizedBox(
                                              height:
                                                  50, // Specify the size of the CircularProgressIndicator
                                              width: 50,
                                              child: CircularProgressIndicator(
                                                strokeWidth:
                                                    5, // Adjust the thickness of the progress indicator
                                              ),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 255, 255, 255),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (areDomainsActive) {
                                                await _syncModels();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                  content: Text(
                                                    'All records have been synchronized successfully.',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      Color.fromARGB(
                                                          255, 255, 255, 255),
                                                ));
                                              } else {
                                                _showDomainsInactiveMessage(
                                                    context);
                                              }
                                            },
                                            icon: const Icon(Icons.cloud_upload,
                                                size: 24),
                                            label: const Text(
                                              'Push Records To The Cloud',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),

                                    const SizedBox(height: 20),

                                    _isSyncing
                                        ? const Center(
                                            child: SizedBox(
                                              height:
                                                  50, // Specify the size of the CircularProgressIndicator
                                              width: 50,
                                              child: CircularProgressIndicator(
                                                strokeWidth:
                                                    5, // Adjust the thickness of the progress indicator
                                              ),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 255, 255, 255),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (areDomainsActive) {
                                                await _showModelSelectionDialog(
                                                    context);
                                              } else {
                                                _showDomainsInactiveMessage(
                                                    context);
                                              }
                                            },
                                            icon: const Icon(
                                                Icons.cloud_download,
                                                size: 24),
                                            label: const Text(
                                              'Pull  Records From The Cloud',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                    const SizedBox(height: 20),

                                    // Retrieve and Save Records Button
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }

  void _showDomainsInactiveMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Domains Not Active',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your domains are currently not active.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please contact the Edutrek Service Provider for assistance.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showModelSelectionDialog(BuildContext context) async {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser?.role.toLowerCase() ?? '';

    // Define models accessible to specific roles
    final roleBasedModels = {
      'admin': [
        'Teacher Payments',
        'Withdrawals',
        'Users',
        'Terms',
        'Teachers',
        'Teacher Purposes',
        'Students',
        'Student Payments',
        'Schools',
        'Student Payment Purposes',
        'Classes',
        'DomainRecord',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'ProjectStudentPayment',
      ],
      'secretary': [
        'Students',
        'Schools',
        'Classes',
        'Withdrawals',
        'Terms',
        'Teachers',
        'Student Payments',
        'Student Payment Purposes',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'ProjectStudentPayment',
      ],
      'teacher': [
        'Students',
        'Classes',
        'Terms',
      ],
      'accountant': [
        'Teacher Payments',
        'Withdrawals',
        'Student Payments',
        'Terms',
        'Teachers',
        'Students',
        'Schools',
        'Classes',
        'Student Payment Purposes',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'ProjectStudentPayment',
      ],
      'sub-admin': [
        'Teacher Payments',
        'Withdrawals',
        'Users',
        'Terms',
        'Teachers',
        'Teacher Purposes',
        'Students',
        'Student Payments',
        'Schools',
        'Student Payment Purposes',
        'Classes',
        'DomainRecord',
        'Account',
        'Asset',
        'Project',
        'ProjectItem',
        'DailyActivity',
        'ProjectStudentPayment',
      ],
    };

    // Determine which models the user can access
    final models = roleBasedModels[role] ?? [];

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have access to any models.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Map<String, bool> selectedModels = {
      for (var model in models) model: false,
    };

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Models to Pull'),
              content: SingleChildScrollView(
                child: Column(
                  children: models.map((model) {
                    return CheckboxListTile(
                      title: Text(model),
                      value: selectedModels[model],
                      onChanged: (value) {
                        setState(() {
                          selectedModels[model] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchSelectedModels(selectedModels);
                  },
                  child: const Text('Sync Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchSelectedModels(Map<String, bool> selectedModels) async {
    setState(() {
      _isSyncing = true;
    });

    final fetchFunctions = {
      'Teacher Payments': _fetchAndSyncTeacherPayments,
      'Withdrawals': _fetchAndSyncwithdrawals,
      'Users': _fetchAndSyncUsers,
      'Terms': _fetchAndSyncTerms,
      'Teachers': _fetchAndSyncTeachers,
      'Teacher Purposes': _fetchAndSyncTeacherPurposes,
      'Students': _fetchAndSyncStudents,
      'Student Payments': _fetchAndSyncStudentPayments,
      'Schools': _fetchAndSyncSchools,
      'Student Payment Purposes': _fetchAndSyncPurposes,
      'Classes': _fetchAndSyncClasses,
      'DomainRecord': _fetchAndSyncDomainRecord,
      'Account': _fetchAndSyncAccount,
      'Asset': _fetchAndSyncAsset,
      'Project': _fetchAndSyncProject,
      'ProjectItem': _fetchAndSyncProjectItem,
      'DailyActivity': _fetchAndSyncDailyActivity,
      'ProjectStudentPayment': _fetchAndSyncProjectStudentPayment,
    };

    try {
      for (var entry in selectedModels.entries) {
        if (entry.value) {
          await fetchFunctions[entry.key]!();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selected records have been retrieved and saved successfully.',
            style: TextStyle(
                fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
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

//================================pull _fetchAndSyncClasses =======================================================================//
  List<String> _decodeClassToList(dynamic value) {
    try {
      if (value == null) return [];
      if (value is List) return List<String>.from(value);
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) return List<String>.from(decoded);
      }
    } catch (e) {
      print('Error decoding string to List: $e');
    }
    return [];
  }

  Future<void> _fetchAndSyncClasses() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> classes = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded response: $decoded');

        for (var classData in classes) {
          DateTime parsedDate =
              DateTime.tryParse(classData['date']) ?? DateTime.now();

          Classes fetchedClass = Classes(
            id: int.tryParse(classData['fid'] ?? '0') ?? 0,
            classCode: classData['classCode'],
            className: classData['className'],
            date: parsedDate, // Assign the parsed DateTime
            termId: classData['termId'],
            terms: _decodeClassToList(classData['terms']),
          );

          // Check if the record exists in Hive using schoolCode
          var existingClassList = _classesBox!.values
              .where(
                (classes) => classes.classCode == fetchedClass.classCode,
              )
              .toList();

          Classes? existingClasses =
              existingClassList.isNotEmpty ? existingClassList.first : null;

          if (fetchedClass.classCode != null) {
            if (existingClasses != null) {
              // Update existing record
              existingClasses
                ..id = fetchedClass.id
                ..classCode = fetchedClass.classCode
                ..className = fetchedClass.className
                ..date = fetchedClass.date
                ..termId = fetchedClass.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..terms = fetchedClass.terms;

              await existingClasses.save();
              print(
                  'Classes ${fetchedClass.classCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _classesBox!.add(fetchedClass);
              print(
                  'Classes ${fetchedClass.classCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another Class record was Found with no Class Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Classes from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing Classes: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncPurposes =======================================================================//

  Future<void> _fetchAndSyncPurposes() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> purposes = jsonDecode(response.body);

        for (var purposeData in purposes) {
          PaymentPurpose fetchedPurpose = PaymentPurpose(
            id: int.tryParse(purposeData['fid'] ?? '0') ?? 0,
            paymentPurpose: purposeData['paymentPurpose'] ?? '',
            purposeAmount: purposeData['purposeAmount'] != null
                ? double.tryParse(purposeData['purposeAmount'].toString()) ??
                    0.0
                : 0.0,
            purposeCode: purposeData['purposeCode'],
            associatedClasses: _decodeToList(purposeData['associatedClasses']),
            termId: purposeData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _payment_purposesBox!.values
              .where(
                (purposes) =>
                    purposes.purposeCode == fetchedPurpose.purposeCode,
              )
              .toList();

          PaymentPurpose? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;
          if (fetchedPurpose.purposeCode != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPurpose.id
                ..purposeCode = fetchedPurpose.purposeCode
                ..paymentPurpose = fetchedPurpose.paymentPurpose
                ..purposeAmount = fetchedPurpose.purposeAmount
                ..associatedClasses = fetchedPurpose.associatedClasses
                ..termId = fetchedPurpose.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _payment_purposesBox!.add(fetchedPurpose);
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another Student PaymentPurpose record was Found with no Purpose Code  and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch PaymentPurpose from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing PaymentPurpose: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncSchools =======================================================================//

  Future<void> _fetchAndSyncSchools() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> schools = jsonDecode(response.body);

        for (var schoolData in schools) {
          School fetchedSchool = School(
            id: int.tryParse(schoolData['fid'] ?? '0'),
            schoolName: schoolData['schoolName'],
            schoolCode: schoolData['schoolCode'],
            schoolAddress: schoolData['schoolAddress'],
            schoolPhoneNumber: schoolData['schoolPhoneNumber'],
            schoolEmail: schoolData['schoolEmail'],
            termId: schoolData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingSchoolList = _schoolBox!.values
              .where(
                (school) => school.schoolCode == fetchedSchool.schoolCode,
              )
              .toList();

          School? existingSchool =
              existingSchoolList.isNotEmpty ? existingSchoolList.first : null;
          if (fetchedSchool.schoolCode != null) {
            if (existingSchool != null) {
              // Update existing record
              existingSchool
                ..schoolName = fetchedSchool.schoolName
                ..schoolAddress = fetchedSchool.schoolAddress
                ..schoolPhoneNumber = fetchedSchool.schoolPhoneNumber
                ..schoolEmail = fetchedSchool.schoolEmail
                ..termId = fetchedSchool.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedSchool.id;

              await existingSchool.save();
              print(
                  'School ${fetchedSchool.schoolCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _schoolBox!.add(fetchedSchool);
              print(
                  'School ${fetchedSchool.schoolCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another School record was Found with no School Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch schools from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing schools: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncStudentPayments =======================================================================//

  Future<void> _fetchAndSyncStudentPayments() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> studentPayments = jsonDecode(response.body);

        for (var paymentsData in studentPayments) {
          StudentPayment fetchedPayments = StudentPayment(
            id: int.tryParse(paymentsData['fid'] ?? '0') ?? 0,
            studentName: paymentsData['studentName'] ?? '',
            studentSurname: paymentsData['studentSurname'] ?? '',
            studentClass: paymentsData['studentClass'] ?? '',
            phoneNumber: paymentsData['phoneNumber'] ?? '',
            paymentPurpose: paymentsData['paymentPurpose'] ?? '',
            amountToPay: paymentsData['amountToPay'] != null
                ? double.tryParse(paymentsData['amountToPay'].toString()) ?? 0.0
                : 0.0,
            paymentDate: DateTime.tryParse(paymentsData['paymentDate']) ??
                DateTime.now(),
            receiptNumber: paymentsData['receiptNumber'],
            termId: paymentsData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _student_paymentsBox!.values
              .where(
                (studentPayments) =>
                    studentPayments.receiptNumber ==
                    fetchedPayments.receiptNumber,
              )
              .toList();

          StudentPayment? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;

          if (fetchedPayments.receiptNumber != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPayments.id
                ..studentName = fetchedPayments.studentName
                ..studentSurname = fetchedPayments.studentSurname
                ..studentClass = fetchedPayments.studentClass
                ..phoneNumber = fetchedPayments.phoneNumber
                ..paymentPurpose = fetchedPayments.paymentPurpose
                ..amountToPay = fetchedPayments.amountToPay
                ..paymentDate = fetchedPayments.paymentDate
                ..receiptNumber = fetchedPayments.receiptNumber
                ..termId = fetchedPayments.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              print(
                  'StudentPayment ${fetchedPayments.receiptNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _student_paymentsBox!.add(fetchedPayments);
              print(
                  'StudentPayment ${fetchedPayments.receiptNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other StudentPayment Record Was Found with no Receipt Numbers and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch StudentPayment from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing StudentPayment: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncStudents =======================================================================//

  Future<void> _fetchAndSyncStudents() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> students = jsonDecode(response.body);

        for (var studentsData in students) {
          Student fetchedStudents = Student(
            id: int.tryParse(studentsData['fid'] ?? '0'),
            name: studentsData['name'],
            surname: studentsData['surname'],
            regNumber: studentsData['regNumber'],
            class_: studentsData['class'],
            gender: studentsData['gender'] ?? '',
            age: DateTime.tryParse(studentsData['age']) ?? DateTime(1900),
            phoneNumber: studentsData['phoneNumber'] ?? '',
            paymentStatus: studentsData['paymentStatus'] ?? '',
            isPresent: studentsData['isPresent'],
            presentDates: _parseDateList(studentsData['presentDates']),
            absentDates: _parseDateList(studentsData['absentDates']),
            termId: studentsData['termId'] ?? '',
            physicalAddress: studentsData['physicalAddress'] ?? '',
            formerSchool: studentsData['formerSchool'] ?? '',
            religion: studentsData['religion'] ?? '',
            denomination: studentsData['denomination'] ?? '',
            studentIdNumber: studentsData['studentIdNumber'],
            nationalIdNumber: studentsData['nationalIdNumber'] ?? '',
            nationality: studentsData['nationality'] ?? '',
            district: studentsData['district'] ?? '',
            previousSchoolPerformanceResults:
                studentsData['previousSchoolPerformanceResults'] ?? '',
            enrollmentStatus: studentsData['enrollmentStatus'] ?? '',
            emergencyContactName: studentsData['emergencyContactName'] ?? '',
            emergencyContactNumber:
                studentsData['emergencyContactNumber'] ?? '',
            terms: _decodeToList(studentsData['terms']),
          );

          // Check if the record exists in Hive using termId
          var existingStudentsList = _studentsBox!.values
              .where(
                (students) =>
                    students.studentIdNumber == fetchedStudents.studentIdNumber,
              )
              .toList();

          Student? existingStudents = existingStudentsList.isNotEmpty
              ? existingStudentsList.first
              : null;
          if (fetchedStudents.studentIdNumber != null) {
            if (existingStudents != null) {
              // Update existing record
              existingStudents
                ..name = fetchedStudents.name
                ..surname = fetchedStudents.surname
                ..regNumber = fetchedStudents.regNumber
                ..class_ = fetchedStudents.class_
                ..gender = fetchedStudents.gender
                ..termId = fetchedStudents.termId
                ..age = fetchedStudents.age
                ..phoneNumber = fetchedStudents.phoneNumber
                ..paymentStatus = fetchedStudents.paymentStatus
                ..isPresent = fetchedStudents.isPresent
                ..presentDates = fetchedStudents.presentDates
                ..termId = fetchedStudents.termId
                ..absentDates = fetchedStudents.absentDates
                ..termId = fetchedStudents.termId
                ..id = fetchedStudents.id
                ..physicalAddress = fetchedStudents.physicalAddress
                ..formerSchool = fetchedStudents.formerSchool
                ..termId = fetchedStudents.termId
                ..religion = fetchedStudents.religion
                ..denomination = fetchedStudents.denomination
                ..studentIdNumber = fetchedStudents.studentIdNumber
                ..nationalIdNumber = fetchedStudents.nationalIdNumber
                ..nationality = fetchedStudents.nationality
                ..district = fetchedStudents.district
                ..previousSchoolPerformanceResults =
                    fetchedStudents.previousSchoolPerformanceResults
                ..enrollmentStatus = fetchedStudents.enrollmentStatus
                ..emergencyContactName = fetchedStudents.emergencyContactName
                ..emergencyContactNumber =
                    fetchedStudents.emergencyContactNumber
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..terms = fetchedStudents.terms;

              await existingStudents.save();
              print(
                  'Student ${fetchedStudents.studentIdNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _studentsBox!.add(fetchedStudents);
              print(
                  'Student ${fetchedStudents.studentIdNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other Student Record Was Found with no Student Reg Number and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch students from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing students: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  List<DateTime> _parseDateList(dynamic jsonList) {
    if (jsonList == null || jsonList is! List) return [];
    return jsonList
        .map<DateTime>(
            (dateStr) => DateTime.tryParse(dateStr) ?? DateTime(1900))
        .toList();
  }

//================================pull teacherPayments =======================================================================//

  Future<void> _fetchAndSyncTeacherPayments() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> teacherPayments = jsonDecode(response.body);

        for (var paymentsData in teacherPayments) {
          TeacherPayment fetchedPayments = TeacherPayment(
            id: int.tryParse(paymentsData['fid'] ?? '0') ?? 0,
            studentName: paymentsData['studentName'] ?? '',
            studentSurname: paymentsData['studentSurname'] ?? '',
            studentClass: paymentsData['studentClass'] ?? '',
            phoneNumber: paymentsData['phoneNumber'] ?? '',
            paymentPurpose: paymentsData['paymentPurpose'] ?? '',
            amountToPay: paymentsData['amountToPay'] != null
                ? double.tryParse(paymentsData['amountToPay'].toString()) ?? 0.0
                : 0.0,
            paymentDate: DateTime.tryParse(paymentsData['paymentDate']) ??
                DateTime.now(),
            receiptNumber: paymentsData['receiptNumber'],
            termId: paymentsData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _teacher_paymentsBox!.values
              .where(
                (teacherPayments) =>
                    teacherPayments.receiptNumber ==
                    fetchedPayments.receiptNumber,
              )
              .toList();

          TeacherPayment? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;
          if (fetchedPayments.receiptNumber != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPayments.id
                ..studentName = fetchedPayments.studentName
                ..studentSurname = fetchedPayments.studentSurname
                ..studentClass = fetchedPayments.studentClass
                ..phoneNumber = fetchedPayments.phoneNumber
                ..paymentPurpose = fetchedPayments.paymentPurpose
                ..amountToPay = fetchedPayments.amountToPay
                ..paymentDate = fetchedPayments.paymentDate
                ..receiptNumber = fetchedPayments.receiptNumber
                ..termId = fetchedPayments.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              print(
                  'TeacherPayment ${fetchedPayments.receiptNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _teacher_paymentsBox!.add(fetchedPayments);
              print(
                  'TeacherPayment ${fetchedPayments.receiptNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Payment  Record Was Found with no Receipt Number and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch TeacherPayment from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing TeacherPayment: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncTeacherPurposes =======================================================================//

  Future<void> _fetchAndSyncTeacherPurposes() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> teacherPurposes = jsonDecode(response.body);

        for (var teacherPurposeData in teacherPurposes) {
          TeacherPaymentsPurposes fetchedTeacherPurpose =
              TeacherPaymentsPurposes(
            id: int.tryParse(teacherPurposeData['fid'] ?? '0') ?? 0,
            paymentPurpose: teacherPurposeData['paymentPurpose'] ?? '',
            purposeAmount: teacherPurposeData['purposeAmount'] != null
                ? double.tryParse(
                        teacherPurposeData['purposeAmount'].toString()) ??
                    0.0
                : 0.0,
            purposeCode: teacherPurposeData['purposeCode'],
            associatedStaff:
                _decodeToList(teacherPurposeData['associatedStaff']),
            termId: teacherPurposeData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingTeacherPurposeList = _teacher_payments_purposesBox!.values
              .where(
                (teacherPurposes) =>
                    teacherPurposes.purposeCode ==
                    fetchedTeacherPurpose.purposeCode,
              )
              .toList();

          TeacherPaymentsPurposes? existingTeacherPurposes =
              existingTeacherPurposeList.isNotEmpty
                  ? existingTeacherPurposeList.first
                  : null;
          if (fetchedTeacherPurpose.purposeCode != null) {
            if (existingTeacherPurposes != null) {
              // Update existing record
              existingTeacherPurposes
                ..id = fetchedTeacherPurpose.id
                ..purposeCode = fetchedTeacherPurpose.purposeCode
                ..paymentPurpose = fetchedTeacherPurpose.paymentPurpose
                ..purposeAmount = fetchedTeacherPurpose.purposeAmount
                ..associatedStaff = fetchedTeacherPurpose.associatedStaff
                ..termId = fetchedTeacherPurpose.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingTeacherPurposes.save();
              print(
                  'TeacherPaymentsPurposes ${fetchedTeacherPurpose.purposeCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _teacher_payments_purposesBox!.add(fetchedTeacherPurpose);
              print(
                  'TeacherPaymentsPurposes ${fetchedTeacherPurpose.purposeCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Payment Purpose Record Was Found with no purposeCode and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch TeacherPaymentsPurposes from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing TeacherPaymentsPurposes: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncTeachers =======================================================================//

  Future<void> _fetchAndSyncTeachers() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> teachers = jsonDecode(response.body);

        for (var teachersData in teachers) {
          /* teachersData.forEach((key, value) {
            print('Key: $key, Value: $value, Type: ${value?.runtimeType}');
          });*/
          Teachers fetchedTeachers = Teachers(
              id: int.tryParse(teachersData['fid'] ?? '0') ?? 0,
              name: teachersData['name'] ?? '',
              surname: teachersData['surname'] ?? '',
              IdNumber: teachersData['IdNumber'],
              assignedClass: teachersData['assignedClass'] ?? '',
              assignedClasses: _decodeToList(teachersData['assignedClasses']),
              gender: teachersData['gender'] ?? '',
              dateOfBirth: DateTime.tryParse(teachersData['dateOfBirth']) ??
                  DateTime.now(),
              phoneNumber: teachersData['phoneNumber'] ?? '',
              paymentPurpose: teachersData['paymentPurpose'] ?? '',
              isPaid: teachersData['isPaid'],
              paymentAmount: teachersData['paymentAmount'] != null
                  ? double.tryParse(teachersData['paymentAmount'].toString()) ??
                      0.0
                  : 0.0,
              paymentDate: teachersData['paymentDate'] != null
                  ? DateTime.tryParse(teachersData['paymentDate'])
                  : null,
              email: teachersData['email'] ?? '',
              address: teachersData['address'] ?? '',
              hireDate:
                  DateTime.tryParse(teachersData['hireDate']) ?? DateTime(1900),
              qualifications: teachersData['qualifications'] ?? '',
              employmentStatus: teachersData['employmentStatus'] ?? '',
              termId: teachersData['termId'],
              terms: _decodeToList(teachersData['terms']));

          // Check if the record exists in Hive using schoolCode
          var existingTeachersList = _teachersBox!.values
              .where(
                (teachers) => teachers.IdNumber == fetchedTeachers.IdNumber,
              )
              .toList();

          Teachers? existingTeachers = existingTeachersList.isNotEmpty
              ? existingTeachersList.first
              : null;
          if (fetchedTeachers.IdNumber != null) {
            if (existingTeachers != null) {
              // Update existing record
              existingTeachers
                ..id = fetchedTeachers.id
                ..name = fetchedTeachers.name
                ..surname = fetchedTeachers.surname
                ..IdNumber = fetchedTeachers.IdNumber
                ..assignedClass = fetchedTeachers.assignedClass
                ..assignedClass = fetchedTeachers.assignedClass
                ..gender = fetchedTeachers.gender
                ..dateOfBirth = fetchedTeachers.dateOfBirth
                ..phoneNumber = fetchedTeachers.phoneNumber
                ..paymentPurpose = fetchedTeachers.paymentPurpose
                ..isPaid = fetchedTeachers.isPaid
                ..paymentAmount = fetchedTeachers.paymentAmount
                ..paymentDate = fetchedTeachers.paymentDate
                ..email = fetchedTeachers.email
                ..address = fetchedTeachers.address
                ..hireDate = fetchedTeachers.hireDate
                ..employmentStatus = fetchedTeachers.employmentStatus
                ..termId = fetchedTeachers.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..terms = fetchedTeachers.terms;
              await existingTeachers.save();
              print(
                  'Teachers ${fetchedTeachers.IdNumber} updated successfully in Hive.');
            } else {
              // Create a new record
              await _teachersBox!.add(fetchedTeachers);
              print(
                  'Teachers ${fetchedTeachers.IdNumber} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other staff Record Was Found with no Staff ID Number and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Teachers from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing Teachers: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncTerms =======================================================================//

  Future<void> _fetchAndSyncTerms() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> terms = jsonDecode(response.body);

        for (var termsData in terms) {
          DateTime parsedStartDate =
              DateTime.tryParse(termsData['startDate'] ?? '') ?? DateTime.now();
          DateTime? parsedEndDate = termsData['endDate'] != null
              ? DateTime.tryParse(termsData['endDate'])
              : null;
          String statuses;
          bool isactive = termsData['isActive'];

          if (isactive == false) {
            statuses = 'Closed';
          } else {
            statuses = 'Opened';
          }
          Terms fetchedTerms = Terms(
            id: int.tryParse(termsData['fid'] ?? '0'),
            termName: termsData['termName'],
            startDate: parsedStartDate,
            endDate: parsedEndDate,
            isActive: termsData['isActive'] == true,
            status: statuses,
            termId: termsData['termId'],
          );

          var existingTermsList = _termsBox!.values
              .where(
                (school) => school.termId == fetchedTerms.termId,
              )
              .toList();

          Terms? existingTerms =
              existingTermsList.isNotEmpty ? existingTermsList.first : null;

          if (fetchedTerms.termId != null) {
            if (existingTerms != null) {
              // Update existing record
              existingTerms
                ..termName = fetchedTerms.termName
                ..startDate = fetchedTerms.startDate
                ..endDate = fetchedTerms.endDate
                ..isActive = fetchedTerms.isActive
                ..status = fetchedTerms.status
                ..termId = fetchedTerms.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedTerms.id;

              await existingTerms.save();
              debugPrint(
                  'Terms ${fetchedTerms.termId} updated successfully in Hive.');
            } else {
              // Create a new record
              await _termsBox!.add(fetchedTerms);
              debugPrint(
                  'Terms ${fetchedTerms.termId} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Skipped a term record without a term ID.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch terms. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing terms: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching terms: $e'),
      ));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
//================================pull _fetchAndSyncUsers =======================================================================//

  Future<void> _fetchAndSyncUsers() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> users = jsonDecode(response.body);

        for (var userData in users) {
          User fetchedUser = User(
            id: int.tryParse(userData['fid'] ?? '0'),
            username: userData['username'] ?? '',
            password: userData['password'] ?? '',
            role: userData['role'] ?? '',
            securityQuestions: _decodeToList(userData['securityQuestions']),
            securityAnswers: _decodeToList(userData['securityAnswers']),
            phone: userData['phone'] ?? '',
            userCode: userData['userCode'],
            termId: userData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingUserList = _usersBox!.values
              .where(
                (users) => users.userCode == fetchedUser.userCode,
              )
              .toList();

          User? existingUsers =
              existingUserList.isNotEmpty ? existingUserList.first : null;
          if (fetchedUser.userCode != null) {
            if (existingUsers != null) {
              // Update existing record
              existingUsers
                ..id = fetchedUser.id
                ..userCode = fetchedUser.userCode
                ..username = fetchedUser.username
                ..password = fetchedUser.password
                ..role = fetchedUser.role
                ..securityQuestions = fetchedUser.securityQuestions
                ..securityAnswers = fetchedUser.securityAnswers
                ..phone = fetchedUser.phone
                ..termId = fetchedUser.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingUsers.save();
              print(
                  'User ${fetchedUser.userCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _usersBox!.add(fetchedUser);
              print('User ${fetchedUser.userCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other User  Record Was Found with no User Code and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch User from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing User: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncwithdrawals =======================================================================//

  Future<void> _fetchAndSyncwithdrawals() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> withdrawals = jsonDecode(response.body);

        for (var withdrawalData in withdrawals) {
          DateTime date =
              DateTime.tryParse(withdrawalData['date']) ?? DateTime.now();

          Withdrawal fetchedWthdrawals = Withdrawal(
            id: int.tryParse(withdrawalData['fid'] ?? '0'),
            amount: withdrawalData['amount'] != null
                ? double.tryParse(withdrawalData['amount'].toString()) ?? 0.0
                : 0.0,
            date: date,
            withdrawalPurpose: withdrawalData['withdrawalPurpose'],
            withdrawalCode: withdrawalData['withdrawalCode'],
            termId: withdrawalData['termId'],
          );

          // Check if the record exists in Hive using termId
          var existingWithdrawalsList = _withdrawalsBox!.values
              .where(
                (withdrawal) =>
                    withdrawal.withdrawalCode ==
                    fetchedWthdrawals.withdrawalCode,
              )
              .toList();

          Withdrawal? existingWithdrawals = existingWithdrawalsList.isNotEmpty
              ? existingWithdrawalsList.first
              : null;
          if (fetchedWthdrawals.withdrawalCode != null) {
            if (existingWithdrawals != null) {
              // Update existing record
              existingWithdrawals
                ..amount = fetchedWthdrawals.amount
                ..withdrawalPurpose = fetchedWthdrawals.withdrawalPurpose
                ..withdrawalCode = fetchedWthdrawals.withdrawalCode
                ..date = fetchedWthdrawals.date
                ..termId = fetchedWthdrawals.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedWthdrawals.id;

              await existingWithdrawals.save();
              print(
                  'Withdrawal ${fetchedWthdrawals.withdrawalCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _withdrawalsBox!.add(fetchedWthdrawals);
              print(
                  'Withdrawal ${fetchedWthdrawals.withdrawalCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other Withdrawal  Record Was Found with no Withdrawal Code and was Skipped'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch withdrawals from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing withdrawals: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncDomainRecord =======================================================================//

  Future<void> _fetchAndSyncDomainRecord() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/domain_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> domainList = jsonDecode(response.body);
        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var domainData in domainList) {
          DomainRecord fetchedDomain = DomainRecord(
            domainName: domainData['domainName'] ?? '',
            areDomainsActive: _intToBool(domainData['areDomainsActive']),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(domainData['lastModified'] ?? ''),
          );

          var existingDomainList = _domainRecordBox!.values
              .where((d) => d.domainName == fetchedDomain.domainName)
              .toList();

          DomainRecord? existingDomain =
              existingDomainList.isNotEmpty ? existingDomainList.first : null;

          if (fetchedDomain.domainName!.isNotEmpty) {
            if (existingDomain != null) {
              existingDomain
                ..areDomainsActive = fetchedDomain.areDomainsActive
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingDomain.save();
              print(
                  'DomainRecord ${fetchedDomain.domainName} updated successfully in Hive.');
            } else {
              await _domainRecordBox!.add(fetchedDomain);
              print(
                  'DomainRecord ${fetchedDomain.domainName} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'A Domain record was found with no domain name and was skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch DomainRecords from server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing DomainRecords: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncAccount =======================================================================//

  Future<void> _fetchAndSyncAccount() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> accounts = jsonDecode(response.body);
        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var accData in accounts) {
          Account fetchedAcc = Account(
            id: accData['id'],
            accountType: accData['accountType'],
            accountSubType: accData['accountSubType'],
            accountName: accData['accountName'],
            accountCode: accData['accountCode'],
            isALiquidAccount: _intToBool(accData['isALiquidAccount']),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(accData['lastModified'] ?? ''),
          );

          var existingList =
              _accountBox!.values.where((a) => a.id == fetchedAcc.id).toList();

          Account? existing =
              existingList.isNotEmpty ? existingList.first : null;

          if (fetchedAcc.id != null) {
            if (existing != null) {
              existing
                ..accountType = fetchedAcc.accountType
                ..accountSubType = fetchedAcc.accountSubType
                ..accountName = fetchedAcc.accountName
                ..accountCode = fetchedAcc.accountCode
                ..isALiquidAccount = fetchedAcc.isALiquidAccount
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existing.save();
              print('Account ${fetchedAcc.id} updated successfully.');
            } else {
              await _accountBox!.add(fetchedAcc);
              print('Account ${fetchedAcc.id} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account with no ID was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Accounts. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing Accounts: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncAsset =======================================================================//

  Future<void> _fetchAndSyncAsset() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/asset_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> assets = jsonDecode(response.body);
        double? _toDouble(dynamic value) {
          if (value == null) return null;
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        }

        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var assetData in assets) {
          Asset fetchedAsset = Asset(
            id: assetData['id'],
            assetName: assetData['assetName'],
            assetType: assetData['assetType'],
            assetSubType: assetData['assetSubType'],
            assetCode: assetData['assetCode'],
            assetSerialNo: assetData['assetSerialNo'],
            acquisitionDate:
                DateTime.tryParse(assetData['acquisitionDate'] ?? ''),
            acquisitionCost: _toDouble(assetData['acquisitionCost']),
            acquisitionMethod: assetData['acquisitionMethod'],
            department: assetData['department'],
            location: assetData['location'],
            depreciationRate: _toDouble(assetData['depreciationRate']),
            depreciationMethod: assetData['depreciationMethod'],
            lastDepreciationDate:
                DateTime.tryParse(assetData['lastDepreciationDate'] ?? ''),
            accumulatedDepreciation:
                _toDouble(assetData['accumulatedDepreciation']),
            bookValue: _toDouble(assetData['bookValue']),
            isImpaired: _intToBool(assetData['isImpaired']),
            impairmentLoss: _toDouble(assetData['impairmentLoss']),
            revaluationDate:
                DateTime.tryParse(assetData['revaluationDate'] ?? ''),
            revaluationAmount: _toDouble(assetData['revaluationAmount']),
            lastMaintenanceDate:
                DateTime.tryParse(assetData['lastMaintenanceDate'] ?? ''),
            maintenanceCost: _toDouble(assetData['maintenanceCost']),
            maintenanceDescription: assetData['maintenanceDescription'],
            capitalImprovementCost:
                _toDouble(assetData['capitalImprovementCost']),
            capitalImprovementDescription:
                assetData['capitalImprovementDescription'],
            disposalDate: DateTime.tryParse(assetData['disposalDate'] ?? ''),
            disposalProceeds: _toDouble(assetData['disposalProceeds']),
            disposalReason: assetData['disposalReason'],
            gainOrLossOnDisposal: _toDouble(assetData['gainOrLossOnDisposal']),
            isLeased: _intToBool(assetData['isLeased']),
            leaseType: assetData['leaseType'],
            leaseStartDate:
                DateTime.tryParse(assetData['leaseStartDate'] ?? ''),
            leaseEndDate: DateTime.tryParse(assetData['leaseEndDate'] ?? ''),
            leasePaymentAmount: _toDouble(assetData['leasePaymentAmount']),
            lastAuditDate: DateTime.tryParse(assetData['lastAuditDate'] ?? ''),
            notes: assetData['notes'],
            createdAt: DateTime.tryParse(assetData['createdAt'] ?? ''),
            lastModified: DateTime.tryParse(assetData['lastModified'] ?? ''),
            operationType: 'none',
            syncStatus: true,
            usefulLife: assetData['usefulLife'],
            hasDebitBalance: _intToBool(assetData['hasDebitBalance']),
            hasCreditBalance: _intToBool(assetData['hasCreditBalance']),
            option: assetData['option'],
          );

          var existingAssetList =
              _assetBox!.values.where((a) => a.id == fetchedAsset.id).toList();

          Asset? existingAsset =
              existingAssetList.isNotEmpty ? existingAssetList.first : null;

          if (fetchedAsset.id != null) {
            if (existingAsset != null) {
              existingAsset
                ..assetName = fetchedAsset.assetName
                ..assetType = fetchedAsset.assetType
                ..assetSubType = fetchedAsset.assetSubType
                ..assetCode = fetchedAsset.assetCode
                ..assetSerialNo = fetchedAsset.assetSerialNo
                ..acquisitionDate = fetchedAsset.acquisitionDate
                ..acquisitionCost = fetchedAsset.acquisitionCost
                ..acquisitionMethod = fetchedAsset.acquisitionMethod
                ..department = fetchedAsset.department
                ..location = fetchedAsset.location
                ..depreciationRate = fetchedAsset.depreciationRate
                ..depreciationMethod = fetchedAsset.depreciationMethod
                ..lastDepreciationDate = fetchedAsset.lastDepreciationDate
                ..accumulatedDepreciation = fetchedAsset.accumulatedDepreciation
                ..bookValue = fetchedAsset.bookValue
                ..isImpaired = fetchedAsset.isImpaired
                ..impairmentLoss = fetchedAsset.impairmentLoss
                ..revaluationDate = fetchedAsset.revaluationDate
                ..revaluationAmount = fetchedAsset.revaluationAmount
                ..lastMaintenanceDate = fetchedAsset.lastMaintenanceDate
                ..maintenanceCost = fetchedAsset.maintenanceCost
                ..maintenanceDescription = fetchedAsset.maintenanceDescription
                ..capitalImprovementCost = fetchedAsset.capitalImprovementCost
                ..capitalImprovementDescription =
                    fetchedAsset.capitalImprovementDescription
                ..disposalDate = fetchedAsset.disposalDate
                ..disposalProceeds = fetchedAsset.disposalProceeds
                ..disposalReason = fetchedAsset.disposalReason
                ..gainOrLossOnDisposal = fetchedAsset.gainOrLossOnDisposal
                ..isLeased = fetchedAsset.isLeased
                ..leaseType = fetchedAsset.leaseType
                ..leaseStartDate = fetchedAsset.leaseStartDate
                ..leaseEndDate = fetchedAsset.leaseEndDate
                ..leasePaymentAmount = fetchedAsset.leasePaymentAmount
                ..lastAuditDate = fetchedAsset.lastAuditDate
                ..notes = fetchedAsset.notes
                ..createdAt = fetchedAsset.createdAt
                ..lastModified = DateTime.now()
                ..syncStatus = true
                ..operationType = 'none'
                ..usefulLife = fetchedAsset.usefulLife
                ..hasDebitBalance = fetchedAsset.hasDebitBalance
                ..hasCreditBalance = fetchedAsset.hasCreditBalance
                ..option = fetchedAsset.option;
              await existingAsset.save();
              print('Asset ${fetchedAsset.id} updated successfully.');
            } else {
              await _assetBox!.add(fetchedAsset);
              print('Asset ${fetchedAsset.id} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Asset with no ID was skipped.')),
            );
          }
        }
      } else {
        throw Exception('Failed to fetch Assets. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing Assets: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncProject =======================================================================//

  Future<void> _fetchAndSyncProject() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> projects = jsonDecode(response.body);

        for (var projectData in projects) {
          Project fetchedProject = Project(
            projectCode: projectData['projectCode'],
            name: projectData['name'],
            description: projectData['description'],
            status: projectData['status'],
            createdAt: DateTime.tryParse(projectData['createdAt'] ?? '') ??
                DateTime.now(),
            updatedAt: DateTime.tryParse(projectData['updatedAt'] ?? '') ??
                DateTime.now(),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(projectData['lastModified'] ?? ''),
          );

          var existingProjectList = _projectBox!.values
              .where((p) => p.projectCode == fetchedProject.projectCode)
              .toList();

          Project? existingProject =
              existingProjectList.isNotEmpty ? existingProjectList.first : null;

          if (fetchedProject.projectCode.isNotEmpty) {
            if (existingProject != null) {
              existingProject
                ..name = fetchedProject.name
                ..description = fetchedProject.description
                ..status = fetchedProject.status
                ..createdAt = fetchedProject.createdAt
                ..updatedAt = fetchedProject.updatedAt
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingProject.save();
              print(
                  'Project ${fetchedProject.projectCode} updated successfully.');
            } else {
              await _projectBox!.add(fetchedProject);
              print(
                  'Project ${fetchedProject.projectCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Project with no code was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch Projects. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing Projects: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
//================================pull _fetchAndSyncProjectItem =======================================================================//

  Future<void> _fetchAndSyncProjectItem() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> items = jsonDecode(response.body);
        double? _toDouble(dynamic value) {
          if (value == null) return null;
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        }

        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var itemData in items) {
          ProjectItem fetchedItem = ProjectItem(
            projectItemCode: itemData['projectItemCode'],
            projectCode: itemData['projectCode'],
            name: itemData['name'],
            amount: _toDouble(itemData['amount'])!.toDouble(),
            isStudentFee: _intToBool(itemData['isStudentFee']),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(itemData['lastModified'] ?? ''),
          );

          var existingItemList = _projectItemBox!.values
              .where((i) => i.projectItemCode == fetchedItem.projectItemCode)
              .toList();

          ProjectItem? existingItem =
              existingItemList.isNotEmpty ? existingItemList.first : null;

          if (fetchedItem.projectItemCode.isNotEmpty) {
            if (existingItem != null) {
              existingItem
                ..projectCode = fetchedItem.projectCode
                ..name = fetchedItem.name
                ..amount = fetchedItem.amount
                ..isStudentFee = fetchedItem.isStudentFee
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingItem.save();
              print(
                  'ProjectItem ${fetchedItem.projectItemCode} updated successfully.');
            } else {
              await _projectItemBox!.add(fetchedItem);
              print(
                  'ProjectItem ${fetchedItem.projectItemCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('ProjectItem with no code was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch ProjectItems. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing ProjectItems: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncDailyActivity =======================================================================//

  Future<void> _fetchAndSyncDailyActivity() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_daily_activity_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> activities = jsonDecode(response.body);

        for (var activityData in activities) {
          DailyActivity fetchedActivity = DailyActivity(
            projectDailyActiviyCode: activityData['projectDailyActiviyCode'],
            projectCode: activityData['projectCode'],
            date:
                DateTime.tryParse(activityData['date'] ?? '') ?? DateTime.now(),
            type: activityData['type'],
            description: activityData['description'],
            amount: activityData['amount'],
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(activityData['lastModified'] ?? ''),
          );

          var existingActivityList = _dailyActivityBox!.values
              .where((d) =>
                  d.projectDailyActiviyCode ==
                  fetchedActivity.projectDailyActiviyCode)
              .toList();

          DailyActivity? existingActivity = existingActivityList.isNotEmpty
              ? existingActivityList.first
              : null;

          if (fetchedActivity.projectDailyActiviyCode.isNotEmpty) {
            if (existingActivity != null) {
              existingActivity
                ..projectCode = fetchedActivity.projectCode
                ..date = fetchedActivity.date
                ..type = fetchedActivity.type
                ..description = fetchedActivity.description
                ..amount = fetchedActivity.amount
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingActivity.save();
              print(
                  'DailyActivity ${fetchedActivity.projectDailyActiviyCode} updated successfully.');
            } else {
              await _dailyActivityBox!.add(fetchedActivity);
              print(
                  'DailyActivity ${fetchedActivity.projectDailyActiviyCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('DailyActivity with no code was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch DailyActivities. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing DailyActivities: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncProjectStudentPayment =======================================================================//

  Future<void> _fetchAndSyncProjectStudentPayment() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_student_payment_api.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> payments = jsonDecode(response.body);
        double? _toDouble(dynamic value) {
          if (value == null) return null;
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is String) return double.tryParse(value);
          return null;
        }

        bool _intToBool(dynamic value) {
          if (value is bool) return value;
          if (value is int) return value == 1;
          return false;
        }

        for (var paymentData in payments) {
          ProjectStudentPayment fetchedPayment = ProjectStudentPayment(
            projectStudentPaymentCode: paymentData['projectStudentPaymentCode'],
            studentId: paymentData['studentId'],
            projectCode: paymentData['projectCode'],
            itemId: paymentData['itemId'],
            amountPaid: _toDouble(paymentData['amountPaid'])!.toDouble(),
            balance: _toDouble(paymentData['balance'])!.toDouble(),
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.tryParse(paymentData['lastModified'] ?? ''),
          );

          var existingPaymentList = _projectStudentPaymentBox!.values
              .where((p) =>
                  p.projectStudentPaymentCode ==
                  fetchedPayment.projectStudentPaymentCode)
              .toList();

          ProjectStudentPayment? existingPayment =
              existingPaymentList.isNotEmpty ? existingPaymentList.first : null;

          if (fetchedPayment.projectStudentPaymentCode.isNotEmpty) {
            if (existingPayment != null) {
              existingPayment
                ..studentId = fetchedPayment.studentId
                ..projectCode = fetchedPayment.projectCode
                ..itemId = fetchedPayment.itemId
                ..amountPaid = fetchedPayment.amountPaid
                ..balance = fetchedPayment.balance
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPayment.save();
              print(
                  'ProjectStudentPayment ${fetchedPayment.projectStudentPaymentCode} updated successfully.');
            } else {
              await _projectStudentPaymentBox!.add(fetchedPayment);
              print(
                  'ProjectStudentPayment ${fetchedPayment.projectStudentPaymentCode} added successfully.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('ProjectStudentPayment with no code was skipped.')),
            );
          }
        }
      } else {
        throw Exception(
            'Failed to fetch ProjectStudentPayments. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing ProjectStudentPayments: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}


*/
 