import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';

import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
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
  Box<PaymentLog>? _paymentLogBox;

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
    _paymentLogBox = await Hive.openBox<PaymentLog>('payment_log');
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

      List<PaymentLog> createPaymentLogs = _paymentLogBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (PaymentLog cls in createPaymentLogs) {
        if (cls.operationType == 'create') {
          await _createPaymentLogInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updatePaymentLogInMySQL(cls);
        }
      }
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

      print('=== _syncBatchUnits START ===');
      print('Checking for unsynced batch units...');

      // Step 1: Push unsynced batch units to server
      List<BatchUnit> unsyncedUnits = _batchUnitBox!.values
          .where((unit) => unit.syncStatus == false)
          .toList();

      print('Found ${unsyncedUnits.length} unsynced batch units');

      for (BatchUnit unit in unsyncedUnits) {
        print('Processing unit: ${unit.unitBatchCode}');
        print('OperationType: ${unit.operationType}');

        if (unit.operationType == 'create') {
          await _createBatchUnitInMySQL(unit);
        } else if (unit.operationType == 'update') {
          await _updateBatchUnitInMySQL(unit);
        } else {
          print('Unknown operationType: ${unit.operationType}');
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
        } else if (cls.operationType == 'delete') {
          try {
            final response = await http.delete(
              Uri.parse(
                  'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php'
                  '?classCode=${cls.classCode}'
                  '&deletedBy=${cls.deletedBy ?? "system"}'),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              cls.deletedSyncStatus = true;
              cls.syncStatus = true;
              cls.operationType = 'none';
              await cls.save();
              print('✅ Deletion synced for class: ${cls.classCode}');
            }
          } catch (e) {
            print('Failed to sync deletion for class: ${cls.classCode}');
          }
        }
      }

      List<School> createSchool =
          _schoolBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (School cls in createSchool) {
        if (cls.operationType == 'create') {
          await _createSchoolInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateSchoolInMySQL(cls);
        } else if (cls.operationType == 'delete') {
          // Handle deletion sync
          try {
            final response = await http.delete(
              Uri.parse(
                  'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php'
                  '?schoolCode=${cls.schoolCode}'
                  '&deletedBy=${cls.deletedBy ?? "system"}'),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              cls.deletedSyncStatus = true;
              cls.syncStatus = true;
              cls.operationType = 'none';
              await cls.save();
              print('✅ Deletion synced for school: ${cls.schoolCode}');
            }
          } catch (e) {
            print('❌ Failed to sync deletion for school: ${cls.schoolCode}');
          }
        }
      }

      List<Terms> createTerms =
          _termsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Terms cls in createTerms) {
        if (cls.operationType == 'create') {
          await _createTermsInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateTermsInMySQL(cls);
        } else if (cls.operationType == 'delete') {
          try {
            final response = await http.delete(
              Uri.parse(
                  'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php'
                  '?termId=${cls.termId}'
                  '&deletedBy=${cls.deletedBy ?? "system"}'),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              cls.deletedSyncStatus = true;
              cls.syncStatus = true;
              cls.operationType = 'none';
              await cls.save();
              print('✅ Deletion synced for term: ${cls.termId}');
            }
          } catch (e) {
            print('Failed to sync deletion for term: ${cls.termId}');
          }
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

      // Step 1: Push unsynced students to server
      List<Student> unsyncedStudents = _studentsBox!.values
          .where((student) => student.syncStatus == false)
          .toList();

      for (Student student in unsyncedStudents) {
        if (student.operationType == 'create') {
          await _createStudentsInMySQL(student);
        } else if (student.operationType == 'update') {
          await _updateStudentsInMySQL(student);
        } else if (student.operationType == 'delete') {
          try {
            final response = await http.delete(
              Uri.parse(
                  'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php'
                  '?studentIdNumber=${student.studentIdNumber}'
                  '&deletedBy=${student.deletedBy ?? "system"}'),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              student.deletedSyncStatus = true;
              student.syncStatus = true;
              student.operationType = 'none';
              await student.save();
              print(
                  '✅ Deletion synced for student: ${student.studentIdNumber}');
            }
          } catch (e) {
            print(
                'Failed to sync deletion for student: ${student.studentIdNumber}');
          }
        }
      }

      List<User> createUser =
          _usersBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (User cls in createUser) {
        if (cls.operationType == 'create') {
          await _createUserInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateUserInMySQL(cls);
        } else if (cls.operationType == 'delete') {
          // ✅ Handle deletion sync
          // The user is already marked deleted locally, just need to sync to server
          // If server already has it deleted, this will be a no-op
          try {
            final response = await http.delete(
              Uri.parse(
                  'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php'
                  '?userCode=${cls.userCode}'
                  '&deletedBy=${cls.deletedBy ?? "system"}'),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              cls.deletedSyncStatus = true;
              cls.syncStatus = true;
              cls.operationType = 'none';
              await cls.save();
              print('✅ Deletion synced for user: ${cls.userCode}');
            }
          } catch (e) {
            print('❌ Failed to sync deletion for user: ${cls.userCode}');
          }
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
// Helper to convert PaymentLog to JSON
  Map<String, dynamic> _paymentLogToJson(PaymentLog log) {
    return {
      'logId': log.logId,
      'receiptNumber': log.receiptNumber,
      'studentName': log.studentName,
      'className': log.className,
      'dateTime': log.dateTime,
      'receiptLines': log.receiptLines,
      'parentName': log.parentName,
      'parentPhone': log.parentPhone,
      'isReprint': log.isReprint ?? false,
      'originalReceiptNumber': log.originalReceiptNumber,
      'reprintCount': log.reprintCount ?? 0,
      'syncStatus': log.syncStatus ?? false,
      'lastModified': log.lastModified?.toIso8601String(),
      'operationType': log.operationType ?? 'create',
      'modifiedFields': log.modifiedFields ?? [],
    };
  }

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

// Helper to convert BatchUnit to JSON
// Helper to convert BatchUnit to JSON
  Map<String, dynamic> _batchUnitToJson(BatchUnit unit) {
    print('=== _batchUnitToJson START ===');
    print('unitBatchCode: ${unit.unitBatchCode}');
    print('level: ${unit.level.name}');
    print('unitsPerPackage: ${unit.unitsPerPackage}');
    print('quantity: ${unit.quantity}');
    print('buyingPrice: ${unit.buyingPrice}');
    print('syncStatus: ${unit.syncStatus}');
    print('operationType: ${unit.operationType}');
    print('modifiedFields: ${unit.modifiedFields}');

    final json = {
      'unitBatchCode': unit.unitBatchCode,
      'level': unit.level.name,
      'unitsPerPackage': unit.unitsPerPackage,
      'quantity': unit.quantity,
      'buyingPrice': unit.buyingPrice,
      'syncStatus': unit.syncStatus ?? false,
      'lastModified': unit.lastModified?.toIso8601String(),
      'operationType': unit.operationType,
      'modifiedFields': unit.modifiedFields ?? [],
    };

    print('JSON to send: ${jsonEncode(json)}');
    print('=== _batchUnitToJson END ===');
    return json;
  }

  Map<String, dynamic> _projectItemPriceToJsonLocal(ProjectItemPrice p) => {
        'priceCode': p.priceCode,
        'projectItemCode': p.projectItemCode,
        'amount': p.amount,
        'pricingType': p.pricingType,
        'appliesTo': p.appliesTo,
        'effectiveFrom': p.effectiveFrom.toIso8601String(),
        'effectiveTo': p.effectiveTo?.toIso8601String(),
      };

// Helper to convert ProjectSaleTransaction to JSON
  Map<String, dynamic> _projectSaleTransactionToJson(
      ProjectSaleTransaction tx) {
    return {
      'transactionCode': tx.transactionCode,
      'studentId': tx.studentId,
      'projectCode': tx.projectCode,
      'projectItemCode': tx.projectItemCode,
      'batchCode': tx.batchCode,
      'sellUnitCode': tx.sellUnitCode,
      'sellUnitNameSnapshot': tx.sellUnitNameSnapshot,
      'quantitySold': tx.quantitySold,
      'unitSellingPrice': tx.unitSellingPrice,
      'totalAmount': tx.totalAmount,
      'baseUnitsPerSellUnit': tx.baseUnitsPerSellUnit,
      'totalBaseUnitsSold': tx.totalBaseUnitsSold,
      'baseUnit': tx.baseUnit,
      'baseUnitType': tx.baseUnitType.name,
      'transactionDate': tx.transactionDate.toIso8601String(),
      'paymentMethod': tx.paymentMethod,
      'reference': tx.reference,
      'amountPaid': tx.amountPaid,
      'arrears': tx.arrears,
      'paymentMethodCode': tx.paymentMethodCode,
      'methodType': tx.methodType,
      'amountPaidInPaymentMethod': tx.amountPaidInPaymentMethod,
      'currency': tx.currency,
      'provider': tx.provider,
      'referenceNumber': tx.referenceNumber,
      'phoneNumber': tx.phoneNumber,
      'accountNumber': tx.accountNumber,
      'accountName': tx.accountName,
      'paymentDatetransacted': tx.paymentDatetransacted?.toIso8601String(),
      'isDeleted': tx.isDeleted ?? false,
      'deletedAt': tx.deletedAt?.map((d) => d.toIso8601String()).toList() ?? [],
      'restoredAt':
          tx.restoredAt?.map((d) => d.toIso8601String()).toList() ?? [],
      'deletedByUsers': tx.deletedByUsers ?? [],
      'restoredByUsers': tx.restoredByUsers ?? [],
      'isReversed': tx.isReversed ?? false,
      'lineTransactionCodes': tx.lineTransactionCodes ?? [],
      'financialType': tx.financialType,
      'parentTransactionCode': tx.parentTransactionCode,
      'affectsStock': tx.affectsStock,
      'createsObligation': tx.createsObligation,
      'settlesObligation': tx.settlesObligation,
      'syncStatus': tx.syncStatus ?? false,
      'lastModified': tx.lastModified?.toIso8601String(),
      'operationType': tx.operationType,
      'modifiedFields': tx.modifiedFields ?? [],
    };
  }

  Map<String, dynamic> _batchSellUnitToJson(BatchSellUnit unit) {
    return {
      'sellUnitCode': unit.sellUnitCode,
      'batchCode': unit.batchCode,
      'unitName': unit.unitName,
      'quantityMultiplier': unit.quantityMultiplier,
      'sellingPrice': unit.sellingPrice,
      'active': unit.active,
      'deletedAt': unit.deletedAt?.toIso8601String(),
      'packagingLevel': unit.packagingLevel?.name,
      'baseUnitsPerSellUnit': unit.baseUnitsPerSellUnit,
      'baseUnit': unit.baseUnit,
      'baseUnitType': unit.baseUnitType?.name,
      'syncStatus': unit.syncStatus ?? false,
      'lastModified': unit.lastModified?.toIso8601String(),
      'operationType': unit.operationType,
      'modifiedFields': unit.modifiedFields ?? [],
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

  // Helper to convert ReceiptSnapshot to JSON
  Map<String, dynamic> _receiptSnapshotToJson(ReceiptSnapshot r) {
    return {
      'receiptCode': r.receiptCode,
      'receiptDate': r.receiptDate.toIso8601String(),
      'cashier': r.cashier,
      'totalExpected': r.totalExpected,
      'totalPaid': r.totalPaid,
      'amountReceived': r.amountReceived,
      'change': r.change,
      'currency': r.currency,
      'receiptLinesJson': r.receiptLinesJson,
      'isReprint': r.isReprint,
      'studentName': r.studentName,
      'studentClass': r.studentClass,
      'syncStatus': r.syncStatus ?? false,
      'lastModified': r.lastModified?.toIso8601String(),
      'operationType': r.operationType,
      'modifiedFields': r.modifiedFields ?? [],
    };
  }

  Map<String, dynamic> _exceptionsToJson(ExceptionalStudents exception) {
    return {
      'id': exception.id,
      'exceptionId': exception.exceptionId,
      'exceptionName': exception.exceptionName,
      'exceptionStatus': exception.exceptionStatus,
      'exceptionType': exception.exceptionType,
      'exceptionFigure': exception.exceptionFigure,
      'priorityFlag': exception.priorityFlag ?? 0,
      'terms': exception.terms ?? [], // ✅ Pass as List
      'syncStatus': exception.syncStatus,
      'lastModified': exception.lastModified?.toIso8601String(),
      'operationType': exception.operationType,
      'modifiedFields': exception.modifiedFields ?? [], // ✅ Pass as List
    };
  }

// Helper to convert Classes to JSON
  Map<String, dynamic> _classToJson(Classes classObj) {
    return {
      'id': classObj.id,
      'classCode': classObj.classCode,
      'className': classObj.className,
      'date': classObj.date.toIso8601String(), //
      'termId': classObj.termId,
      'terms': jsonEncode(classObj.terms ?? []),
      'operationType': classObj.operationType,
      'syncStatus': classObj.syncStatus,
      'lastModified': classObj.lastModified?.toIso8601String(),
      'isDeleted': classObj.isDeleted ?? false,
      'deletedAt': classObj.deletedAt?.toIso8601String(),
      'deletedBy': classObj.deletedBy,
      'deleteReason': classObj.deleteReason,
      'deletedSyncStatus': classObj.deletedSyncStatus ?? false,
    };
  }

  // Helper to convert School to JSON
  Map<String, dynamic> _schoolToJson(School school) {
    return {
      'id': school.id,
      'schoolCode': school.schoolCode,
      'schoolName': school.schoolName,
      'schoolAddress': school.schoolAddress,
      'schoolPhoneNumber': school.schoolPhoneNumber,
      'schoolEmail': school.schoolEmail,
      'schoolLogoPath': school.schoolLogoPath,
      'termId': school.termId,
      'operationType': school.operationType,
      'syncStatus': school.syncStatus,
      'lastModified': school.lastModified?.toIso8601String(),
      // ✅ Deletion fields
      'isDeleted': school.isDeleted ?? false,
      'deletedAt': school.deletedAt?.toIso8601String(),
      'deletedBy': school.deletedBy,
      'deleteReason': school.deleteReason,
      'deletedSyncStatus': school.deletedSyncStatus ?? false,
    };
  }

// Helper to convert Terms to JSON (including deletion fields)
  Map<String, dynamic> _termsToJson(Terms term) {
    return {
      'id': term.id,
      'termId': term.termId,
      'termName': term.termName,
      'startDate': term.startDate.toIso8601String(),
      'endDate': term.endDate?.toIso8601String(),
      'isActive': term.isActive,
      'status': term.status,
      'operationType': term.operationType,
      'syncStatus': term.syncStatus,
      'lastModified': term.lastModified?.toIso8601String(),
      // ✅ Deletion fields
      'isDeleted': term.isDeleted ?? false,
      'deletedAt': term.deletedAt?.toIso8601String(),
      'deletedBy': term.deletedBy,
      'deleteReason': term.deleteReason,
      'deletedSyncStatus': term.deletedSyncStatus ?? false,
    };
  }

// Helper to convert Withdrawal to JSON
  Map<String, dynamic> _withdrawalToJson(Withdrawal withdrawal) {
    return {
      'id': withdrawal.id,
      'withdrawalCode':
          withdrawal.withdrawalCode?.toString() ?? '', // ✅ Ensure String
      'withdrawalPurpose': withdrawal.withdrawalPurpose,
      'amount': withdrawal.amount,
      'date': withdrawal.date.toIso8601String(),
      'termId': withdrawal.termId?.toString(), // ✅ Ensure String or null
      'operationType': withdrawal.operationType,
      'syncStatus': withdrawal.syncStatus,
      'lastModified': withdrawal.lastModified?.toIso8601String(),
    };
  }

// Helper to convert Student to JSON

// Helper to convert Student to JSON with debug
  Map<String, dynamic> _studentInfoToJson(Student student) {
    // 🔴 FIX: Don't use jsonEncode for fields that should be JSON arrays
    // Let the PHP server handle the JSON encoding
    return {
      'id': student.id,
      'studentIdNumber': student.studentIdNumber,
      'name': student.name,
      'surname': student.surname,
      'regNumber': student.regNumber,
      'class': student.class_,
      'gender': student.gender,
      'age': student.age.toIso8601String(),
      'phoneNumber': student.phoneNumber,
      'paymentStatus': student.paymentStatus,
      'isPresent': student.isPresent,
      'presentDates': student.presentDates
          .map((d) => d.toIso8601String())
          .toList(), // ✅ Pass as List
      'absentDates': student.absentDates
          .map((d) => d.toIso8601String())
          .toList(), // ✅ Pass as List
      'termId': student.termId,
      'physicalAddress': student.physicalAddress,
      'formerSchool': student.formerSchool,
      'religion': student.religion,
      'denomination': student.denomination,
      'nationalIdNumber': student.nationalIdNumber,
      'nationality': student.nationality,
      'district': student.district,
      'previousSchoolPerformanceResults':
          student.previousSchoolPerformanceResults,
      'enrollmentStatus': student.enrollmentStatus,
      'emergencyContactName': student.emergencyContactName,
      'emergencyContactNumber': student.emergencyContactNumber,
      'healthStatus': student.healthStauts, // ✅ Map to correct field name
      'healthDetailedInformation': student.healthDetailedInformation,
      'terms': student.terms ?? [], // ✅ Pass as List, NOT jsonEncode
      'exceptions': student.exceptions != null
          ? student.exceptions!
              .map((e) => _exceptionsToJson(e))
              .toList() // ✅ Pass as List
          : [], // ✅ Pass as empty List
      'isNewComer': student.isNewComer ?? false,
      'isNewComerFrom': student.isNewComerFrom?.toIso8601String(),
      'isNewComerUntil': student.isNewComerUntil?.toIso8601String(),
      'operationType': student.operationType,
      'syncStatus': student.syncStatus,
      'lastModified': student.lastModified?.toIso8601String(),

      // ✅ Deletion fields
      'isDeleted': student.isDeleted ?? false,
      'deletedAt': student.deletedAt?.toIso8601String(),
      'deletedBy': student.deletedBy,
      'deleteReason': student.deleteReason,
      'deletedSyncStatus': student.deletedSyncStatus ?? false,
    };
  }

// Helper method to convert User to JSON
  Map<String, dynamic> _userToJson(User user) {
    return {
      'id': user.id,
      'userCode': user.userCode,
      'username': user.username,
      'password': user.password,
      'email': user.email,
      'role': user.role,
      'phone': user.phone,
      'isActive': user.isActive,
      'securityQuestions': jsonEncode(user.securityQuestions),
      'securityAnswers': jsonEncode(user.securityAnswers),
      'assignedClasses': jsonEncode(user.assignedClasses ?? []),
      'termId': user.termId,
      'operationType': user.operationType,
      'syncStatus': user.syncStatus,
      'lastModified': user.lastModified?.toIso8601String(),
      'createdAt': user.createdAt?.toIso8601String(),
      'isDeleted': user.isDeleted ?? false,
      'deletedAt': user.deletedAt?.toIso8601String(),
      'deletedBy': user.deletedBy,
      'deleteReason': user.deleteReason,
      'deletedSyncStatus': user.deletedSyncStatus ?? false,
    };
  }

  // Helper to convert PaymentPurpose to JSON
  Map<String, dynamic> _paymentPurposeToJson(PaymentPurpose purpose) {
    return {
      'id': purpose.id,
      'purposeCode': purpose.purposeCode,
      'paymentPurpose': purpose.paymentPurpose,
      'purposeAmount': purpose.purposeAmount,
      'termId': purpose.termId,
      'associatedClasses': purpose.associatedClasses ?? [], // ✅ Pass as List
      'exceptions': purpose.exceptions != null
          ? purpose.exceptions!
              .map((e) => _exceptionsToJson(e))
              .toList() // ✅ Pass as List
          : [], // ✅ Pass as List
      'forNewcomersOnly': purpose.forNewcomersOnly ?? false,
      'operationType': purpose.operationType,
      'syncStatus': purpose.syncStatus,
      'lastModified': purpose.lastModified?.toIso8601String(),
    };
  }

// Helper to convert StudentPayment to JSON
  Map<String, dynamic> _studentPaymentToJson(StudentPayment payment) {
    return {
      'id': payment.id,
      'receiptNumber': payment.receiptNumber,
      'studentName': payment.studentName,
      'studentSurname': payment.studentSurname,
      'studentClass': payment.studentClass,
      'studentRegNumber': payment.studentRegNumber,
      'phoneNumber': payment.phoneNumber,
      'paymentPurpose': payment.paymentPurpose,
      'amountToPay': payment.amountToPay,
      'paymentDate': payment.paymentDate.toIso8601String(),
      'termId': payment.termId,
      'username': payment.username,
      'role': payment.role,
      'paymentMethodType': payment.paymentMethodType,
      'paymentMethodAmount': payment.paymentMethodAmount,
      'paymentReference': payment.paymentReference,
      'mobileMoneyPhone': payment.mobileMoneyPhone,
      'mobileMoneyProvider': payment.mobileMoneyProvider,
      'bankAccountNumber': payment.bankAccountNumber,
      'bankAccountName': payment.bankAccountName,
      'changeGiven': payment.changeGiven,
      'operationType': payment.operationType,
      'syncStatus': payment.syncStatus,
      'lastModified': payment.lastModified?.toIso8601String(),
    };
  }

// ================== TEACHER SYNC METHODS ==================

// Helper to convert Teachers to JSON
  Map<String, dynamic> _teacherToJson(Teachers teacher) {
    return {
      'id': teacher.id,
      'IdNumber': teacher.IdNumber,
      'name': teacher.name,
      'surname': teacher.surname,
      'gender': teacher.gender,
      'dateOfBirth': teacher.dateOfBirth.toIso8601String().split('T')[0],
      'phoneNumber': teacher.phoneNumber,
      'email': teacher.email,
      'address': teacher.address,
      'hireDate': teacher.hireDate.toIso8601String().split('T')[0],
      'qualifications': teacher.qualifications,
      'employmentStatus': teacher.employmentStatus,
      'assignedClass': teacher.assignedClass,
      'assignedClasses': teacher.assignedClasses ?? [],
      'paymentPurpose': teacher.paymentPurpose,
      'isPaid': teacher.isPaid,
      'paymentAmount': teacher.paymentAmount,
      'paymentDate': teacher.paymentDate?.toIso8601String(),
      'termId': teacher.termId,
      'terms': teacher.terms ?? [],
      'operationType': teacher.operationType,
      'syncStatus': teacher.syncStatus,
      'lastModified': teacher.lastModified?.toIso8601String(),
    };
  }

  // Helper to convert TeacherPaymentsPurposes to JSON
  Map<String, dynamic> _teacherPaymentsPurposeToJson(
      TeacherPaymentsPurposes purpose) {
    return {
      'id': purpose.id,
      'purposeCode': purpose.purposeCode,
      'paymentPurpose': purpose.paymentPurpose,
      'purposeAmount': purpose.purposeAmount,
      'termId': purpose.termId,
      'associatedStaff': purpose.associatedStaff ?? [], // ✅ Pass as List
      'operationType': purpose.operationType,
      'syncStatus': purpose.syncStatus,
      'lastModified': purpose.lastModified?.toIso8601String(),
    };
  }

  // Helper to convert TeacherPayment to JSON
  Map<String, dynamic> _teacherPaymentclassToJson(TeacherPayment payment) {
    return {
      'id': payment.id,
      'receiptNumber': payment.receiptNumber,
      'studentName': payment.studentName,
      'studentSurname': payment.studentSurname,
      'studentClass': payment.studentClass,
      'phoneNumber': payment.phoneNumber,
      'paymentPurpose': payment.paymentPurpose,
      'amountToPay': payment.amountToPay,
      'paymentDate': payment.paymentDate.toIso8601String(),
      'termId': payment.termId,
      'associatedStaff': payment.associatedStaff ?? [], // ✅ Pass as List
      'operationType': payment.operationType,
      'syncStatus': payment.syncStatus,
      'lastModified': payment.lastModified?.toIso8601String(),
    };
  }

  Map<String, dynamic> _domainsToJson(DomainRecord domain) => {
        'domainName': domain.domainName,
        'areDomainsActive': domain.areDomainsActive,
        'syncStatus': domain.syncStatus,
        'operationType': domain.operationType,
        'lastModified': domain.lastModified?.toIso8601String(),
      };
// Helper to convert Account to JSON
  Map<String, dynamic> _accountsToJson(Account account) {
    return {
      'id': account.id,
      'accountCode': account.accountCode,
      'accountType': account.accountType,
      'accountSubType': account.accountSubType,
      'accountName': account.accountName,
      'isALiquidAccount': account.isALiquidAccount ?? false,
      'operationType': account.operationType,
      'syncStatus': account.syncStatus,
      'lastModified': account.lastModified?.toIso8601String(),
      'modifiedFields': account.modifiedFields ?? [],
    };
  }

  // ================== ASSET SYNC METHODS ==================

// Helper to convert Asset to JSON
  Map<String, dynamic> _assetsToJson(Asset asset) {
    return {
      'id': asset.id,
      'assetCode': asset.assetCode,
      'assetName': asset.assetName,
      'assetType': asset.assetType,
      'assetSubType': asset.assetSubType,
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
      'isImpaired': asset.isImpaired ?? false,
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
      'isLeased': asset.isLeased ?? false,
      'leaseType': asset.leaseType,
      'leaseStartDate': asset.leaseStartDate?.toIso8601String(),
      'leaseEndDate': asset.leaseEndDate?.toIso8601String(),
      'leasePaymentAmount': asset.leasePaymentAmount,
      'lastAuditDate': asset.lastAuditDate?.toIso8601String(),
      'syncStatus': asset.syncStatus ?? false,
      'notes': asset.notes,
      'createdAt': asset.createdAt?.toIso8601String(),
      'lastModified': asset.lastModified?.toIso8601String(),
      'operationType': asset.operationType,
      'usefulLife': asset.usefulLife,
      'hasDebitBalance': asset.hasDebitBalance ?? false,
      'hasCreditBalance': asset.hasCreditBalance ?? false,
      'option': asset.option,
      'modifiedFields': asset.modifiedFields ?? [],
    };
  }

  // Helper to convert Project to JSON
  Map<String, dynamic> _projectsToJson(Project project) {
    return {
      'projectCode': project.projectCode,
      'name': project.name,
      'description': project.description,
      'status': project.status,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'syncStatus': project.syncStatus ?? false,
      'lastModified': project.lastModified?.toIso8601String(),
      'operationType': project.operationType,
      'modifiedFields': project.modifiedFields ?? [],
      // ✅ NEW FIELDS
      'projectType': project.projectType,
      'participationType': project.participationType,
      'studentPayable': project.studentPayable ?? false,
    };
  }

  Map<String, dynamic> _projectItemsToJson(ProjectItem item) {
    return {
      'projectItemCode': item.projectItemCode,
      'projectCode': item.projectCode,
      'name': item.name,
      'itemType': item.itemType ?? 'goods',
      'active': item.active ?? true,
      'trackStock': item.trackStock ?? false,
      'syncStatus': item.syncStatus ?? false,
      'lastModified': item.lastModified?.toIso8601String(),
      'operationType': item.operationType,
      'modifiedFields': item.modifiedFields ?? [],
    };
  }

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

// CREATE PaymentLog on server
  Future<void> _createPaymentLogInMySQL(PaymentLog newLog) async {
    final Map<String, dynamic> jsonData = _paymentLogToJson(newLog);

    // ✅ Ensure logId exists
    if (newLog.logId == null || newLog.logId!.isEmpty) {
      newLog.logId =
          'LOG_${newLog.receiptNumber}_${DateTime.now().millisecondsSinceEpoch}';
    }

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/payment_receipts_log_api.php?logId=${newLog.logId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('PaymentLog ${newLog.logId} created/updated successfully.');

        // ✅ Update sync status
        newLog.syncStatus = true;
        newLog.operationType = 'none';
        newLog.modifiedFields = [];
        await newLog.save();
      } else {
        throw Exception(
            'Failed to sync payment log. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating payment log: $e');
      print('Stack Trace: $stackTrace');
      print('Log ID: ${newLog.logId}');
      print('Receipt Number: ${newLog.receiptNumber}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE PaymentLog on server
  Future<void> _updatePaymentLogInMySQL(PaymentLog updatedLog) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    // ✅ Track modified fields
    for (String field in updatedLog.modifiedFields ?? []) {
      switch (field) {
        case 'parentName':
          modifiedFieldsJson['parentName'] = updatedLog.parentName;
          break;
        case 'parentPhone':
          modifiedFieldsJson['parentPhone'] = updatedLog.parentPhone;
          break;
        case 'isReprint':
          modifiedFieldsJson['isReprint'] = updatedLog.isReprint ?? false;
          break;
        case 'originalReceiptNumber':
          modifiedFieldsJson['originalReceiptNumber'] =
              updatedLog.originalReceiptNumber;
          break;
        case 'reprintCount':
          modifiedFieldsJson['reprintCount'] = updatedLog.reprintCount ?? 0;
          break;
      }
    }

    // Always include logId for identification
    modifiedFieldsJson['logId'] = updatedLog.logId;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/payment_receipts_log_api.php?logId=${updatedLog.logId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('PaymentLog ${updatedLog.logId} updated successfully.');

        // ✅ Update sync status
        updatedLog.syncStatus = true;
        updatedLog.operationType = 'none';
        updatedLog.modifiedFields = [];
        await updatedLog.save();
      } else {
        throw Exception('Failed to update payment log.');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating payment log: $e');
      print('Stack Trace: $stackTrace');
      print('Log ID: ${updatedLog.logId}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// CREATE BatchUnit on server

// CREATE BatchUnit on server
  Future<void> _createBatchUnitInMySQL(BatchUnit unit) async {
    print('=== _createBatchUnitInMySQL START ===');
    print('unitBatchCode: ${unit.unitBatchCode}');
    print('domain: $_domainName');

    final Map<String, dynamic> jsonData = _batchUnitToJson(unit);
    final String jsonString = jsonEncode(jsonData);
    print('JSON String: $jsonString');

    setState(() {
      _isSyncings = true;
    });

    try {
      final url =
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_unit_api.php?unitBatchCode=${unit.unitBatchCode}';
      print('POST URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonString,
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(
            '✅ BatchUnit ${unit.unitBatchCode} created/updated successfully.');

        unit.syncStatus = true;
        unit.operationType = 'none';
        unit.modifiedFields = [];
        await unit.save();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('BatchUnit synced successfully')));
      } else {
        print('❌ Failed to create BatchUnit. Status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        throw Exception(
            'Failed to create BatchUnit. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ BatchUnit create error: $e');
      print('Stack Trace: $stackTrace');
      await unit.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
      print('=== _createBatchUnitInMySQL END ===');
    }
  }

// UPDATE BatchUnit on server
  Future<void> _updateBatchUnitInMySQL(BatchUnit unit) async {
    print('=== _updateBatchUnitInMySQL START ===');
    print('unitBatchCode: ${unit.unitBatchCode}');
    print('modifiedFields: ${unit.modifiedFields}');

    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in unit.modifiedFields ?? []) {
      print('Processing field: $field');
      switch (field) {
        case 'level':
          modifiedFieldsJson['level'] = unit.level.name;
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
        default:
          print('Unknown field: $field');
      }
    }

    // Always include unitBatchCode for identification
    modifiedFieldsJson['unitBatchCode'] = unit.unitBatchCode;

    print('Modified fields JSON: ${jsonEncode(modifiedFieldsJson)}');

    setState(() {
      _isSyncings = true;
    });

    try {
      final url =
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_unit_api.php?unitBatchCode=${unit.unitBatchCode}';
      print('PUT URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ BatchUnit ${unit.unitBatchCode} updated successfully.');

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
        print('❌ Failed to update BatchUnit. Status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        throw Exception('Failed to update BatchUnit.');
      }
    } catch (e, stackTrace) {
      print('❌ BatchUnit update error: $e');
      print('Stack Trace: $stackTrace');
    } finally {
      setState(() {
        _isSyncings = false;
      });
      print('=== _updateBatchUnitInMySQL END ===');
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
//==================== _createProjectSaleTransactionInMySQL sync ======================

// CREATE ProjectSaleTransaction on server
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
        print(
            'ProjectSaleTransaction ${tx.transactionCode} created/updated successfully.');

        tx.syncStatus = true;
        tx.operationType = 'none';
        tx.modifiedFields = [];
        await tx.save();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transaction synced successfully')));
      } else {
        throw Exception(
            'Failed to create transaction. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Transaction create error: $e');
      await tx.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE ProjectSaleTransaction on server
  Future<void> _updateProjectSaleTransactionInMySQL(
      ProjectSaleTransaction tx) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in tx.modifiedFields ?? []) {
      switch (field) {
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
        case 'isDeleted':
          modifiedFieldsJson['isDeleted'] = tx.isDeleted ?? false;
          break;
        case 'deletedAt':
          modifiedFieldsJson['deletedAt'] =
              tx.deletedAt?.map((d) => d.toIso8601String()).toList() ?? [];
          break;
        case 'restoredAt':
          modifiedFieldsJson['restoredAt'] =
              tx.restoredAt?.map((d) => d.toIso8601String()).toList() ?? [];
          break;
        case 'deletedByUsers':
          modifiedFieldsJson['deletedByUsers'] = tx.deletedByUsers ?? [];
          break;
        case 'restoredByUsers':
          modifiedFieldsJson['restoredByUsers'] = tx.restoredByUsers ?? [];
          break;
        case 'isReversed':
          modifiedFieldsJson['isReversed'] = tx.isReversed ?? false;
          break;
        case 'lineTransactionCodes':
          modifiedFieldsJson['lineTransactionCodes'] =
              tx.lineTransactionCodes ?? [];
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

    // Always include transactionCode for identification
    modifiedFieldsJson['transactionCode'] = tx.transactionCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_sale_transaction_api.php?transactionCode=${tx.transactionCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(
            'ProjectSaleTransaction ${tx.transactionCode} updated successfully.');

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
        throw Exception('Failed to update transaction.');
      }
    } catch (e) {
      print('Transaction update error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }
//==================== _createBatchSellUnitInMySQL sync ======================

// CREATE BatchSellUnit on server
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
        print(
            'BatchSellUnit ${unit.sellUnitCode} created/updated successfully.');

        unit.syncStatus = true;
        unit.operationType = 'none';
        unit.modifiedFields = [];
        await unit.save();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('BatchSellUnit synced successfully')));
      } else {
        throw Exception(
            'Failed to create BatchSellUnit. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('BatchSellUnit create error: $e');
      await unit.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE BatchSellUnit on server
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

    // Always include sellUnitCode for identification
    modifiedFieldsJson['sellUnitCode'] = unit.sellUnitCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_sell_unit_api.php?sellUnitCode=${unit.sellUnitCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('BatchSellUnit ${unit.sellUnitCode} updated successfully.');

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
        throw Exception('Failed to update BatchSellUnit.');
      }
    } catch (e) {
      print('BatchSellUnit update error: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//==================== _createPaymentMethodInMySQL sync ======================

  Future<void> _createPaymentMethodInMySQL(PaymentMethod pm) async {
    final Map<String, dynamic> jsonData = _paymentMethodToJson(pm);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_payment_method_api.php?paymentMethodCode=${pm.paymentMethodCode}'),
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
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_payment_method_api.php?paymentMethodCode=${pm.paymentMethodCode}',
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
//==================== _createReceiptSnapshotInMySQL sync ======================

// CREATE ReceiptSnapshot on server
  Future<void> _createReceiptSnapshotInMySQL(ReceiptSnapshot r) async {
    final Map<String, dynamic> jsonData = _receiptSnapshotToJson(r);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_receipt_snapshot_api.php?receiptCode=${r.receiptCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('ReceiptSnapshot ${r.receiptCode} created/updated successfully.');

        r.syncStatus = true;
        r.operationType = 'none';
        r.modifiedFields = [];
        await r.save();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Receipt synced successfully')));
      } else {
        throw Exception(
            'Failed to create ReceiptSnapshot. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('ReceiptSnapshot create error: $e');
      await r.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE ReceiptSnapshot on server
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

    // Always include receiptCode for identification
    modifiedFieldsJson['receiptCode'] = receipt.receiptCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_receipt_snapshot_api.php?receiptCode=${receipt.receiptCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('ReceiptSnapshot ${receipt.receiptCode} updated successfully.');

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
        throw Exception('Failed to update ReceiptSnapshot.');
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

  // CREATE Exception on server
  Future<void> _createExceptionInMySQL(ExceptionalStudents newException) async {
    final Map<String, dynamic> jsonData = _exceptionsToJson(newException);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/exceptions_api.php?exceptionId=${newException.exceptionId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'Exception ${newException.exceptionId} created/updated successfully.');

        // Update syncStatus in Hive
        newException.syncStatus = true;
        newException.operationType = 'none';
        newException.modifiedFields = [];
        await newException.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Exception ${newException.exceptionName} synced successfully')));
      } else {
        print('Failed to sync exception. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to sync exception. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating exception: $e');
      print('Stack Trace: $stackTrace');
      print('Exception ID: ${newException.exceptionId}');
      print('Exception Name: ${newException.exceptionName}');
      print('--- End of Exception Details ---');
      await newException.save(); // Keep syncStatus false to retry
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE Exception on server
  Future<void> _updateExceptionInMySQL(
      ExceptionalStudents updatedException) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedException.modifiedFields ?? []) {
      switch (field) {
        case 'exceptionName':
          modifiedFieldsJson['exceptionName'] = updatedException.exceptionName;
          break;
        case 'exceptionStatus':
          modifiedFieldsJson['exceptionStatus'] =
              updatedException.exceptionStatus;
          break;
        case 'exceptionType':
          modifiedFieldsJson['exceptionType'] = updatedException.exceptionType;
          break;
        case 'exceptionFigure':
          modifiedFieldsJson['exceptionFigure'] =
              updatedException.exceptionFigure;
          break;
        case 'priorityFlag':
          modifiedFieldsJson['priorityFlag'] = updatedException.priorityFlag;
          break;
        case 'terms':
          modifiedFieldsJson['terms'] =
              jsonEncode(updatedException.terms ?? []);
          break;
      }
    }

    // Always include exceptionId for identification
    modifiedFieldsJson['exceptionId'] = updatedException.exceptionId;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/exceptions_api.php?exceptionId=${updatedException.exceptionId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'Exception ${updatedException.exceptionId} updated successfully.');

        updatedException.syncStatus = true;
        updatedException.operationType = 'none';
        updatedException.modifiedFields = [];
        await updatedException.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Exception ${updatedException.exceptionName} updated successfully')));
      } else {
        throw Exception(
            'Failed to update exception. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating exception: $e');
      print('Stack Trace: $stackTrace');
      print('Exception ID: ${updatedException.exceptionId}');
      print('--- End of Exception Details ---');
      await updatedException.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  //=================== teachers payment  sync =========================

  // CREATE TeacherPayment on server
  Future<void> _createTeacherPaymentInMySQL(TeacherPayment newPayment) async {
    final Map<String, dynamic> jsonData =
        _teacherPaymentclassToJson(newPayment);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newPayment.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'TeacherPayment ${newPayment.receiptNumber} created/updated successfully.');

        newPayment.syncStatus = true;
        newPayment.operationType = 'none';
        newPayment.modifiedFields = [];
        await newPayment.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Teacher Payment for ${newPayment.studentName} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync teacher payment. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating teacher payment: $e');
      print('Stack Trace: $stackTrace');
      print('Receipt Number: ${newPayment.receiptNumber}');
      print('--- End of Exception Details ---');
      await newPayment.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE TeacherPayment on server
  Future<void> _updateTeacherPaymentInMySQL(
      TeacherPayment updatedPayment) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedPayment.modifiedFields ?? []) {
      switch (field) {
        case 'studentName':
          modifiedFieldsJson['studentName'] = updatedPayment.studentName;
          break;
        case 'studentSurname':
          modifiedFieldsJson['studentSurname'] = updatedPayment.studentSurname;
          break;
        case 'studentClass':
          modifiedFieldsJson['studentClass'] = updatedPayment.studentClass;
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = updatedPayment.phoneNumber;
          break;
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = updatedPayment.paymentPurpose;
          break;
        case 'amountToPay':
          modifiedFieldsJson['amountToPay'] = updatedPayment.amountToPay;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              updatedPayment.paymentDate.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedPayment.termId;
          break;
        case 'receiptNumber':
          modifiedFieldsJson['receiptNumber'] = updatedPayment.receiptNumber;
          break;
        case 'associatedStaff':
          modifiedFieldsJson['associatedStaff'] =
              updatedPayment.associatedStaff ?? [];
          break;
      }
    }

    // Always include receiptNumber for identification
    modifiedFieldsJson['receiptNumber'] = updatedPayment.receiptNumber;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${updatedPayment.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'TeacherPayment ${updatedPayment.receiptNumber} updated successfully.');

        if ((updatedPayment.modifiedFields?.isNotEmpty ?? false) &&
            updatedPayment.operationType != null &&
            updatedPayment.operationType != 'none') {
          SyncQueueManager().enqueue(updatedPayment);
        }
        updatedPayment.syncStatus = true;
        updatedPayment.operationType = 'none';
        updatedPayment.modifiedFields = [];
        await updatedPayment.save();
      } else {
        throw Exception('Failed to update teacher payment.');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating teacher payment: $e');
      print('Stack Trace: $stackTrace');
      print('Receipt Number: ${updatedPayment.receiptNumber}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== techers payment purpose sync =========================

// CREATE TeacherPaymentPurpose on server
  Future<void> _createTeacherPaymentPurposeInMySQL(
      TeacherPaymentsPurposes newPurpose) async {
    final Map<String, dynamic> jsonData =
        _teacherPaymentsPurposeToJson(newPurpose);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newPurpose.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'TeacherPaymentPurpose ${newPurpose.purposeCode} created/updated successfully.');

        newPurpose.syncStatus = true;
        newPurpose.operationType = 'none';
        newPurpose.modifiedFields = [];
        await newPurpose.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Teacher Payment Purpose ${newPurpose.paymentPurpose} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync teacher payment purpose. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating teacher payment purpose: $e');
      print('Stack Trace: $stackTrace');
      print('Purpose Code: ${newPurpose.purposeCode}');
      print('--- End of Exception Details ---');
      await newPurpose.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE TeacherPaymentPurpose on server
  Future<void> _updateTeacherPaymentPurposeInMySQL(
      TeacherPaymentsPurposes updatedPurpose) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedPurpose.modifiedFields ?? []) {
      switch (field) {
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = updatedPurpose.paymentPurpose;
          break;
        case 'purposeAmount':
          modifiedFieldsJson['purposeAmount'] = updatedPurpose.purposeAmount;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedPurpose.termId;
          break;
        case 'associatedStaff':
          modifiedFieldsJson['associatedStaff'] =
              updatedPurpose.associatedStaff ?? [];
          break;
      }
    }

    // Always include purposeCode for identification
    modifiedFieldsJson['purposeCode'] = updatedPurpose.purposeCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${updatedPurpose.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'TeacherPaymentPurpose ${updatedPurpose.purposeCode} updated successfully.');

        if ((updatedPurpose.modifiedFields?.isNotEmpty ?? false) &&
            updatedPurpose.operationType != null &&
            updatedPurpose.operationType != 'none') {
          SyncQueueManager().enqueue(updatedPurpose);
        }
        updatedPurpose.syncStatus = true;
        updatedPurpose.operationType = 'none';
        updatedPurpose.modifiedFields = [];
        await updatedPurpose.save();
      } else {
        throw Exception('Failed to update teacher payment purpose.');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating teacher payment purpose: $e');
      print('Stack Trace: $stackTrace');
      print('Purpose Code: ${updatedPurpose.purposeCode}');
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
// CREATE StudentPayment on server
  Future<void> _createStudentPaymentInMySQL(StudentPayment newPayment) async {
    final Map<String, dynamic> jsonData = _studentPaymentToJson(newPayment);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newPayment.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'StudentPayment ${newPayment.receiptNumber} created/updated successfully.');

        newPayment.syncStatus = true;
        newPayment.operationType = 'none';
        newPayment.modifiedFields = [];
        await newPayment.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Payment for ${newPayment.studentName} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync payment. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating payment: $e');
      print('Stack Trace: $stackTrace');
      print('Receipt Number: ${newPayment.receiptNumber}');
      print('--- End of Exception Details ---');
      await newPayment.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE StudentPayment on server
  Future<void> _updateStudentPaymentInMySQL(
      StudentPayment updatedPayment) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedPayment.modifiedFields ?? []) {
      switch (field) {
        case 'studentName':
          modifiedFieldsJson['studentName'] = updatedPayment.studentName;
          break;
        case 'studentSurname':
          modifiedFieldsJson['studentSurname'] = updatedPayment.studentSurname;
          break;
        case 'studentClass':
          modifiedFieldsJson['studentClass'] = updatedPayment.studentClass;
          break;
        case 'studentRegNumber':
          modifiedFieldsJson['studentRegNumber'] =
              updatedPayment.studentRegNumber;
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = updatedPayment.phoneNumber;
          break;
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = updatedPayment.paymentPurpose;
          break;
        case 'amountToPay':
          modifiedFieldsJson['amountToPay'] = updatedPayment.amountToPay;
          break;
        case 'paymentDate':
          modifiedFieldsJson['paymentDate'] =
              updatedPayment.paymentDate.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedPayment.termId;
          break;
        case 'receiptNumber':
          modifiedFieldsJson['receiptNumber'] = updatedPayment.receiptNumber;
          break;
        case 'username':
          modifiedFieldsJson['username'] = updatedPayment.username;
          break;
        case 'role':
          modifiedFieldsJson['role'] = updatedPayment.role;
          break;
        case 'paymentMethodType':
          modifiedFieldsJson['paymentMethodType'] =
              updatedPayment.paymentMethodType;
          break;
        case 'paymentMethodAmount':
          modifiedFieldsJson['paymentMethodAmount'] =
              updatedPayment.paymentMethodAmount;
          break;
        case 'paymentReference':
          modifiedFieldsJson['paymentReference'] =
              updatedPayment.paymentReference;
          break;
        case 'mobileMoneyPhone':
          modifiedFieldsJson['mobileMoneyPhone'] =
              updatedPayment.mobileMoneyPhone;
          break;
        case 'mobileMoneyProvider':
          modifiedFieldsJson['mobileMoneyProvider'] =
              updatedPayment.mobileMoneyProvider;
          break;
        case 'bankAccountNumber':
          modifiedFieldsJson['bankAccountNumber'] =
              updatedPayment.bankAccountNumber;
          break;
        case 'bankAccountName':
          modifiedFieldsJson['bankAccountName'] =
              updatedPayment.bankAccountName;
          break;
        case 'changeGiven':
          modifiedFieldsJson['changeGiven'] = updatedPayment.changeGiven;
          break;
      }
    }

    // Always include receiptNumber for identification
    modifiedFieldsJson['receiptNumber'] = updatedPayment.receiptNumber;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${updatedPayment.receiptNumber}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'StudentPayment ${updatedPayment.receiptNumber} updated successfully.');

        if ((updatedPayment.modifiedFields?.isNotEmpty ?? false) &&
            updatedPayment.operationType != null &&
            updatedPayment.operationType != 'none') {
          SyncQueueManager().enqueue(updatedPayment);
        }
        updatedPayment.syncStatus = true;
        updatedPayment.operationType = 'none';
        updatedPayment.modifiedFields = [];
        await updatedPayment.save();
      } else {
        throw Exception('Failed to update payment.');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating payment: $e');
      print('Stack Trace: $stackTrace');
      print('Receipt Number: ${updatedPayment.receiptNumber}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  //=================== purpose sync =========================

// CREATE PaymentPurpose on server
  Future<void> _createPaymentPurposeInMySQL(PaymentPurpose newPurpose) async {
    final Map<String, dynamic> jsonData = _paymentPurposeToJson(newPurpose);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newPurpose.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'PaymentPurpose ${newPurpose.purposeCode} created/updated successfully.');

        newPurpose.syncStatus = true;
        newPurpose.operationType = 'none';
        newPurpose.modifiedFields = [];
        await newPurpose.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Payment Purpose ${newPurpose.paymentPurpose} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync payment purpose. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating payment purpose: $e');
      print('Stack Trace: $stackTrace');
      print('Purpose Code: ${newPurpose.purposeCode}');
      print('--- End of Exception Details ---');
      await newPurpose.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE PaymentPurpose on server
  Future<void> _updatePaymentPurposeInMySQL(
      PaymentPurpose updatedPurpose) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedPurpose.modifiedFields ?? []) {
      switch (field) {
        case 'paymentPurpose':
          modifiedFieldsJson['paymentPurpose'] = updatedPurpose.paymentPurpose;
          break;
        case 'purposeAmount':
          modifiedFieldsJson['purposeAmount'] = updatedPurpose.purposeAmount;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedPurpose.termId;
          break;
        case 'associatedClasses':
          modifiedFieldsJson['associatedClasses'] =
              updatedPurpose.associatedClasses ?? [];
          break;
        case 'exceptions':
          modifiedFieldsJson['exceptions'] = updatedPurpose.exceptions != null
              ? updatedPurpose.exceptions!
                  .map((e) => _exceptionsToJson(e))
                  .toList()
              : [];
          break;
        case 'forNewcomersOnly':
          modifiedFieldsJson['forNewcomersOnly'] =
              updatedPurpose.forNewcomersOnly ?? false;
          break;
      }
    }

    // Always include purposeCode for identification
    modifiedFieldsJson['purposeCode'] = updatedPurpose.purposeCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${updatedPurpose.purposeCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'PaymentPurpose ${updatedPurpose.purposeCode} updated successfully.');

        if ((updatedPurpose.modifiedFields?.isNotEmpty ?? false) &&
            updatedPurpose.operationType != null &&
            updatedPurpose.operationType != 'none') {
          SyncQueueManager().enqueue(updatedPurpose);
        }
        updatedPurpose.syncStatus = true;
        updatedPurpose.operationType = 'none';
        updatedPurpose.modifiedFields = [];
        await updatedPurpose.save();
      } else {
        throw Exception('Failed to update payment purpose.');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating payment purpose: $e');
      print('Stack Trace: $stackTrace');
      print('Purpose Code: ${updatedPurpose.purposeCode}');
      print('--- End of Exception Details ---');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== users sync =========================
  Future<void> _createUserInMySQL(User newUser) async {
    final Map<String, dynamic> jsonData = _userToJson(newUser);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newUser.userCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('User ${newUser.userCode} created/updated successfully.');

        // Update syncStatus in Hive
        newUser.syncStatus = true;
        newUser.operationType = 'none';
        newUser.modifiedFields = [];
        await newUser.save();

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('User ${newUser.username} synced successfully')));
      } else {
        throw Exception('Failed to sync user. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error creating user: $e');
      print('Stack Trace: $stackTrace');
      print('User Details:');
      print('UserCode: ${newUser.userCode}');
      print('Username: ${newUser.username}');
      print('--- End of Exception Details ---');

      // Keep syncStatus as false to retry later
      await newUser.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

  // ✅ SOFT DELETE User
  Future<void> _softDeleteUser(User user, {String? reason}) async {
    print('=== _softDeleteUser START ===');
    print('User: ${user.userCode}');
    print('Reason: $reason');

    // ✅ Get current logged in user
    final currentUser = getLoggedInUser();

    // ✅ Mark user as deleted locally
    user.markDeleted(
      deletedBy: currentUser.username ?? 'system',
      reason: reason,
    );
    await user.save();
    print('✅ User marked as deleted locally');

    // ✅ Send delete request to server
    try {
      final response = await http.delete(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php'
            '?userCode=${user.userCode}'
            '&deletedBy=${currentUser.username ?? "system"}'
            '&reason=${Uri.encodeComponent(reason ?? "")}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        print('✅ Server soft delete confirmed: ${result['message']}');

        // ✅ Mark deletion as synced
        user.deletedSyncStatus = true;
        user.syncStatus = true;
        user.operationType = 'none';
        await user.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('User ${user.username} deleted successfully')));
      } else {
        throw Exception(
            'Failed to delete user. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting user: $e');
      // Keep syncStatus as false to retry later
      await user.save();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
    }

    print('=== _softDeleteUser END ===');
  }

// ✅ RESTORE User
  Future<void> _restoreUser(User user) async {
    print('=== _restoreUser START ===');
    print('User: ${user.userCode}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({
          'action': 'restore',
          'userCode': user.userCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        print('✅ Server restore confirmed: ${result['message']}');

        // ✅ Restore locally
        user.restoreDeleted();
        await user.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('User ${user.username} restored successfully')));
      } else {
        throw Exception(
            'Failed to restore user. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error restoring user: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error restoring user: $e')));
    }

    print('=== _restoreUser END ===');
  }

  Future<void> _updateUserInMySQL(User updatedUser) async {
    // Only send modified fields
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedUser.modifiedFields ?? []) {
      switch (field) {
        case 'username':
          modifiedFieldsJson['username'] = updatedUser.username;
          break;
        case 'password':
          modifiedFieldsJson['password'] = updatedUser.password;
          break;
        case 'email':
          modifiedFieldsJson['email'] = updatedUser.email;
          break;
        case 'role':
          modifiedFieldsJson['role'] = updatedUser.role;
          break;
        case 'phone':
          modifiedFieldsJson['phone'] = updatedUser.phone;
          break;
        case 'isActive':
          modifiedFieldsJson['isActive'] = updatedUser.isActive;
          break;
        case 'securityQuestions':
          modifiedFieldsJson['securityQuestions'] =
              jsonEncode(updatedUser.securityQuestions);
          break;
        case 'securityAnswers':
          modifiedFieldsJson['securityAnswers'] =
              jsonEncode(updatedUser.securityAnswers);
          break;
        case 'assignedClasses':
          modifiedFieldsJson['assignedClasses'] =
              jsonEncode(updatedUser.assignedClasses ?? []);
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedUser.termId;
          break;
      }
    }

    // Always include userCode for identification
    modifiedFieldsJson['userCode'] = updatedUser.userCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${updatedUser.userCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('User ${updatedUser.userCode} updated successfully.');

        // Reset sync status
        updatedUser.syncStatus = true;
        updatedUser.operationType = 'none';
        updatedUser.modifiedFields = [];
        await updatedUser.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('User ${updatedUser.username} updated successfully')));
      } else {
        throw Exception(
            'Failed to update user. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('--- Exception Details ---');
      print('Error updating user: $e');
      print('Stack Trace: $stackTrace');
      print('User Code: ${updatedUser.userCode}');
      print('--- End of Exception Details ---');

      // Keep syncStatus as false to retry later
      await updatedUser.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//=================== students sync =========================
// CREATE Student on server with debug
  Future<void> _createStudentsInMySQL(Student newStudent) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(newStudent);

    // Print the JSON string being sent
    final String jsonString = jsonEncode(jsonData);

    setState(() {
      _isSyncings = true;
    });

    try {
      final url =
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newStudent.studentIdNumber}';
      print('POST URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonString,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            '✅ Student ${newStudent.studentIdNumber} created/updated successfully.');

        newStudent.syncStatus = true;
        newStudent.operationType = 'none';
        newStudent.modifiedFields = [];
        await newStudent.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Student ${newStudent.name} ${newStudent.surname} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync student. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error creating student: $e');
      print('Stack Trace: $stackTrace');
      await newStudent.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
      print('=== _createStudentsInMySQL END ===');
    }
  }

// UPDATE Student on server with debug
  Future<void> _updateStudentsInMySQL(Student updatedStudent) async {
    print('=== _updateStudentsInMySQL START ===');
    print('Student to update: ${updatedStudent.studentIdNumber}');
    print('Modified Fields: ${updatedStudent.modifiedFields}');

    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedStudent.modifiedFields ?? []) {
      print('Processing field: $field');
      switch (field) {
        case 'termId':
          modifiedFieldsJson['termId'] = updatedStudent.termId;
          break;
        case 'name':
          modifiedFieldsJson['name'] = updatedStudent.name;
          break;
        case 'surname':
          modifiedFieldsJson['surname'] = updatedStudent.surname;
          break;
        case 'regNumber':
          modifiedFieldsJson['regNumber'] = updatedStudent.regNumber;
          break;
        case 'class_':
          modifiedFieldsJson['class'] = updatedStudent.class_;
          break;
        case 'gender':
          modifiedFieldsJson['gender'] = updatedStudent.gender;
          break;
        case 'age':
          modifiedFieldsJson['age'] = updatedStudent.age.toIso8601String();
          break;
        case 'phoneNumber':
          modifiedFieldsJson['phoneNumber'] = updatedStudent.phoneNumber;
          break;
        case 'paymentStatus':
          modifiedFieldsJson['paymentStatus'] = updatedStudent.paymentStatus;
          break;
        case 'isPresent':
          modifiedFieldsJson['isPresent'] = updatedStudent.isPresent;
          break;
        case 'presentDates':
          // ✅ Pass as List
          modifiedFieldsJson['presentDates'] = updatedStudent.presentDates
              .map((date) => date.toIso8601String())
              .toList();
          break;
        case 'absentDates':
          // ✅ Pass as List
          modifiedFieldsJson['absentDates'] = updatedStudent.absentDates
              .map((date) => date.toIso8601String())
              .toList();
          break;
        case 'physicalAddress':
          modifiedFieldsJson['physicalAddress'] =
              updatedStudent.physicalAddress;
          break;
        case 'formerSchool':
          modifiedFieldsJson['formerSchool'] = updatedStudent.formerSchool;
          break;
        case 'religion':
          modifiedFieldsJson['religion'] = updatedStudent.religion;
          break;
        case 'denomination':
          modifiedFieldsJson['denomination'] = updatedStudent.denomination;
          break;
        case 'nationalIdNumber':
          modifiedFieldsJson['nationalIdNumber'] =
              updatedStudent.nationalIdNumber;
          break;
        case 'nationality':
          modifiedFieldsJson['nationality'] = updatedStudent.nationality;
          break;
        case 'district':
          modifiedFieldsJson['district'] = updatedStudent.district;
          break;
        case 'previousSchoolPerformanceResults':
          modifiedFieldsJson['previousSchoolPerformanceResults'] =
              updatedStudent.previousSchoolPerformanceResults;
          break;
        case 'enrollmentStatus':
          modifiedFieldsJson['enrollmentStatus'] =
              updatedStudent.enrollmentStatus;
          break;
        case 'emergencyContactName':
          modifiedFieldsJson['emergencyContactName'] =
              updatedStudent.emergencyContactName;
          break;
        case 'emergencyContactNumber':
          modifiedFieldsJson['emergencyContactNumber'] =
              updatedStudent.emergencyContactNumber;
          break;
        case 'healthStauts':
          modifiedFieldsJson['healthStatus'] = updatedStudent.healthStauts;
          break;
        case 'healthDetailedInformation':
          modifiedFieldsJson['healthDetailedInformation'] =
              updatedStudent.healthDetailedInformation;
          break;
        case 'exceptions':
          // ✅ Pass as List
          modifiedFieldsJson['exceptions'] = updatedStudent.exceptions != null
              ? updatedStudent.exceptions!
                  .map((e) => _exceptionsToJson(e))
                  .toList()
              : [];
          break;
        case 'isNewComer':
          modifiedFieldsJson['isNewComer'] = updatedStudent.isNewComer ?? false;
          break;
        case 'isNewComerFrom':
          modifiedFieldsJson['isNewComerFrom'] =
              updatedStudent.isNewComerFrom?.toIso8601String();
          break;
        case 'isNewComerUntil':
          modifiedFieldsJson['isNewComerUntil'] =
              updatedStudent.isNewComerUntil?.toIso8601String();
          break;
        case 'terms':
          // ✅ Pass as List
          modifiedFieldsJson['terms'] = updatedStudent.terms ?? [];
          break;
      }
    }

    // Always include studentIdNumber
    modifiedFieldsJson['studentIdNumber'] = updatedStudent.studentIdNumber;

    print('Modified fields JSON to send:');
    print(modifiedFieldsJson);

    setState(() {
      _isSyncings = true;
    });

    try {
      final url =
          'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${updatedStudent.studentIdNumber}';
      print('PUT URL: $url');

      final String jsonString = jsonEncode(modifiedFieldsJson);
      print('PUT Body: $jsonString');

      final response = await http.put(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonString,
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // 🔴 FIX: If no changes, try POST instead
        if (responseData['message'] == 'No changes made to student') {
          print(
              '⚠️ No changes detected. Student may not exist. Trying POST...');
          // Try POST which handles both create and update
          await _createStudentsInMySQL(updatedStudent);
          return;
        }

        print(
            '✅ Student ${updatedStudent.studentIdNumber} updated successfully.');

        if ((updatedStudent.modifiedFields?.isNotEmpty ?? false) &&
            updatedStudent.operationType != null &&
            updatedStudent.operationType != 'none') {
          SyncQueueManager().enqueue(updatedStudent);
        }
        updatedStudent.syncStatus = true;
        updatedStudent.operationType = 'none';
        updatedStudent.modifiedFields = [];
        await updatedStudent.save();
      } else {
        print('❌ Failed to update student. Status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        throw Exception(
            'Failed to update students. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error updating student: $e');
      print('Stack Trace: $stackTrace');
    } finally {
      setState(() {
        _isSyncings = false;
      });
      print('=== _updateStudentsInMySQL END ===');
    }
  }

// ✅ SOFT DELETE Student
  Future<void> _softDeleteStudent(Student student, {String? reason}) async {
    print('=== _softDeleteStudent START ===');
    print('Student: ${student.studentIdNumber}');

    final currentUser = getLoggedInUser();

    student.markDeleted(
      deletedBy: currentUser?.username ?? 'system',
      reason: reason,
    );
    await student.save();

    try {
      final response = await http.delete(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php'
            '?studentIdNumber=${student.studentIdNumber}'
            '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
            '&reason=${Uri.encodeComponent(reason ?? "")}'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        student.deletedSyncStatus = true;
        student.syncStatus = true;
        student.operationType = 'none';
        await student.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Student ${student.name} ${student.surname} deleted successfully')));
      } else {
        throw Exception(
            'Failed to delete student. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting student: $e');
      await student.save();
    }
  }

// ✅ RESTORE Student
  Future<void> _restoreStudent(Student student) async {
    print('=== _restoreStudent START ===');
    print('Student: ${student.studentIdNumber}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'restore',
          'studentIdNumber': student.studentIdNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        student.restoreDeleted();
        await student.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Student ${student.name} ${student.surname} restored successfully')));
      } else {
        throw Exception(
            'Failed to restore student. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restoring student: $e');
    }
  }

//==================== withdrawal sync ======================
// CREATE Withdrawal on server
  Future<void> _createWithdrawalsInMySQL(Withdrawal newWithdrawal) async {
    final Map<String, dynamic> jsonData = _withdrawalToJson(newWithdrawal);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newWithdrawal.withdrawalCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'Withdrawal ${newWithdrawal.withdrawalCode} created/updated successfully.');

        newWithdrawal.syncStatus = true;
        newWithdrawal.operationType = 'none';
        newWithdrawal.modifiedFields = [];
        await newWithdrawal.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Withdrawal ${newWithdrawal.withdrawalPurpose} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync withdrawal. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating withdrawal: $e');
      await newWithdrawal.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE Withdrawal on server
  Future<void> _updateWithdrawalsInMySQL(Withdrawal updatedWithdrawal) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedWithdrawal.modifiedFields ?? []) {
      switch (field) {
        case 'withdrawalPurpose':
          modifiedFieldsJson['withdrawalPurpose'] =
              updatedWithdrawal.withdrawalPurpose;
          break;
        case 'amount':
          modifiedFieldsJson['amount'] = updatedWithdrawal.amount;
          break;
        case 'date':
          // ✅ Send full DateTime with time
          modifiedFieldsJson['date'] = updatedWithdrawal.date.toIso8601String();
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedWithdrawal.termId;
          break;
      }
    }

    // Always include withdrawalCode for identification
    modifiedFieldsJson['withdrawalCode'] = updatedWithdrawal.withdrawalCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${updatedWithdrawal.withdrawalCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'Withdrawal ${updatedWithdrawal.withdrawalCode} updated successfully.');

        if ((updatedWithdrawal.modifiedFields?.isNotEmpty ?? false) &&
            updatedWithdrawal.operationType != null &&
            updatedWithdrawal.operationType != 'none') {
          SyncQueueManager().enqueue(updatedWithdrawal);
        }
        updatedWithdrawal.syncStatus = true;
        updatedWithdrawal.operationType = 'none';
        updatedWithdrawal.modifiedFields = [];
        await updatedWithdrawal.save();
      } else {
        throw Exception('Failed to update withdrawal.');
      }
    } catch (e) {
      print('Error updating withdrawal: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

//====================== terms sync ==========================

// CREATE Term on server
  Future<void> _createTermsInMySQL(Terms newTerm) async {
    final Map<String, dynamic> jsonData = _termsToJson(newTerm);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newTerm.termId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Term ${newTerm.termId} created/updated successfully.');

        newTerm.syncStatus = true;
        newTerm.operationType = 'none';
        newTerm.modifiedFields = [];
        await newTerm.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Term ${newTerm.termName} synced successfully')));
      } else {
        throw Exception('Failed to sync term. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating term: $e');
      await newTerm.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE Term on server
  Future<void> _updateTermsInMySQL(Terms updatedTerm) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedTerm.modifiedFields ?? []) {
      switch (field) {
        case 'termName':
          modifiedFieldsJson['termName'] = updatedTerm.termName;
          break;
        case 'startDate':
          // ✅ Send full DateTime with time
          modifiedFieldsJson['startDate'] =
              updatedTerm.startDate.toIso8601String();
          break;
        case 'endDate':
          // ✅ Send full DateTime with time
          modifiedFieldsJson['endDate'] =
              updatedTerm.endDate?.toIso8601String();
          break;
        case 'isActive':
          modifiedFieldsJson['isActive'] = updatedTerm.isActive;
          break;
        case 'status':
          modifiedFieldsJson['status'] = updatedTerm.status;
          break;
      }
    }

    // Always include termId for identification
    modifiedFieldsJson['termId'] = updatedTerm.termId;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${updatedTerm.termId}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Term ${updatedTerm.termId} updated successfully.');

        if ((updatedTerm.modifiedFields?.isNotEmpty ?? false) &&
            updatedTerm.operationType != null &&
            updatedTerm.operationType != 'none') {
          SyncQueueManager().enqueue(updatedTerm);
        }
        updatedTerm.syncStatus = true;
        updatedTerm.operationType = 'none';
        updatedTerm.modifiedFields = [];
        await updatedTerm.save();
      } else {
        throw Exception('Failed to update term.');
      }
    } catch (e) {
      print('Error updating term: $e');
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// ✅ SOFT DELETE Term
  Future<void> _softDeleteTerm(Terms term, {String? reason}) async {
    print('=== _softDeleteTerm START ===');
    print('Term: ${term.termId}');

    final currentUser = getLoggedInUser();

    term.markDeleted(
      deletedBy: currentUser?.username ?? 'system',
      reason: reason,
    );
    await term.save();

    try {
      final response = await http.delete(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php'
            '?termId=${term.termId}'
            '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
            '&reason=${Uri.encodeComponent(reason ?? "")}'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        term.deletedSyncStatus = true;
        term.syncStatus = true;
        term.operationType = 'none';
        await term.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Term ${term.termName} deleted successfully')));
      } else {
        throw Exception(
            'Failed to delete term. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting term: $e');
      await term.save();
    }
  }

// ✅ RESTORE Term
  Future<void> _restoreTerm(Terms term) async {
    print('=== _restoreTerm START ===');
    print('Term: ${term.termId}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'restore',
          'termId': term.termId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        term.restoreDeleted();
        await term.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Term ${term.termName} restored successfully')));
      } else {
        throw Exception(
            'Failed to restore term. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restoring term: $e');
    }
  }

//============== classes sync ==============================
  // CREATE Class on server
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
        print('Class ${newClass.classCode} created/updated successfully.');

        // Update syncStatus in Hive
        newClass.syncStatus = true;
        newClass.operationType = 'none';
        newClass.modifiedFields = [];
        await newClass.save();
      } else {
        throw Exception('Failed to sync class. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating class: $e');
      await newClass.save(); // Keep syncStatus false to retry
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE Class on server
  Future<void> _updateClassesInMySQL(Classes updatedClass) async {
    // Only send modified fields
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
          modifiedFieldsJson['terms'] = jsonEncode(updatedClass.terms ?? []);
          break;
      }
    }

    // Always include classCode for identification
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
        print('Class ${updatedClass.classCode} updated successfully.');

        updatedClass.syncStatus = true;
        updatedClass.operationType = 'none';
        updatedClass.modifiedFields = [];
        await updatedClass.save();
      } else {
        throw Exception(
            'Failed to update class. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating class: $e');
      await updatedClass.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// ✅ SOFT DELETE Class
  Future<void> _softDeleteClass(Classes classObj, {String? reason}) async {
    print('=== _softDeleteClass START ===');
    print('Class: ${classObj.classCode}');

    final currentUser = getLoggedInUser();

    classObj.markDeleted(
      deletedBy: currentUser?.username ?? 'system',
      reason: reason,
    );
    await classObj.save();

    try {
      final response = await http.delete(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php'
            '?classCode=${classObj.classCode}'
            '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
            '&reason=${Uri.encodeComponent(reason ?? "")}'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        classObj.deletedSyncStatus = true;
        classObj.syncStatus = true;
        classObj.operationType = 'none';
        await classObj.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Class ${classObj.className} deleted successfully')));
      } else {
        throw Exception(
            'Failed to delete class. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting class: $e');
      await classObj.save();
    }
  }

// ✅ RESTORE Class
  Future<void> _restoreClass(Classes classObj) async {
    print('=== _restoreClass START ===');
    print('Class: ${classObj.classCode}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'restore',
          'classCode': classObj.classCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        classObj.restoreDeleted();
        await classObj.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Class ${classObj.className} restored successfully')));
      } else {
        throw Exception(
            'Failed to restore class. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error restoring class: $e');
    }
  }

//================= schools sync ===========================
// CREATE School on server
  Future<void> _createSchoolInMySQL(School newSchool) async {
    final Map<String, dynamic> jsonData = _schoolToJson(newSchool);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${newSchool.schoolCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('School ${newSchool.schoolCode} created/updated successfully.');

        // Update syncStatus in Hive
        newSchool.syncStatus = true;
        newSchool.operationType = 'none';
        newSchool.modifiedFields = [];
        await newSchool.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('School ${newSchool.schoolName} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync school. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating school: $e');
      await newSchool.save(); // Keep syncStatus false to retry
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE School on server
  Future<void> _updateSchoolInMySQL(School updatedSchool) async {
    // Only send modified fields
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedSchool.modifiedFields ?? []) {
      switch (field) {
        case 'schoolName':
          modifiedFieldsJson['schoolName'] = updatedSchool.schoolName;
          break;
        case 'schoolAddress':
          modifiedFieldsJson['schoolAddress'] = updatedSchool.schoolAddress;
          break;
        case 'schoolPhoneNumber':
          modifiedFieldsJson['schoolPhoneNumber'] =
              updatedSchool.schoolPhoneNumber;
          break;
        case 'schoolEmail':
          modifiedFieldsJson['schoolEmail'] = updatedSchool.schoolEmail;
          break;
        case 'schoolLogoPath':
          modifiedFieldsJson['schoolLogoPath'] = updatedSchool.schoolLogoPath;
          break;
        case 'termId':
          modifiedFieldsJson['termId'] = updatedSchool.termId;
          break;
      }
    }

    // Always include schoolCode for identification
    modifiedFieldsJson['schoolCode'] = updatedSchool.schoolCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${updatedSchool.schoolCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('School ${updatedSchool.schoolCode} updated successfully.');

        updatedSchool.syncStatus = true;
        updatedSchool.operationType = 'none';
        updatedSchool.modifiedFields = [];
        await updatedSchool.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'School ${updatedSchool.schoolName} updated successfully')));
      } else {
        throw Exception(
            'Failed to update school. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating school: $e');
      await updatedSchool.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// ✅ SOFT DELETE School
  Future<void> _softDeleteSchool(School school, {String? reason}) async {
    print('=== _softDeleteSchool START ===');
    print('School: ${school.schoolCode}');

    // Get current user
    final currentUser = getLoggedInUser();

    // Mark as deleted locally
    school.markDeleted(
      deletedBy: currentUser?.username ?? 'system',
      reason: reason,
    );
    await school.save();
    print('✅ School marked as deleted locally');

    // Send delete request to server
    try {
      final response = await http.delete(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php'
            '?schoolCode=${school.schoolCode}'
            '&deletedBy=${Uri.encodeComponent(currentUser?.username ?? "system")}'
            '&reason=${Uri.encodeComponent(reason ?? "")}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        print('✅ Server soft delete confirmed: ${result['message']}');

        school.deletedSyncStatus = true;
        school.syncStatus = true;
        school.operationType = 'none';
        await school.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('School ${school.schoolName} deleted successfully')));
      } else {
        throw Exception(
            'Failed to delete school. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting school: $e');
      await school.save();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting school: $e')));
    }
  }

// ✅ RESTORE School
  Future<void> _restoreSchool(School school) async {
    print('=== _restoreSchool START ===');
    print('School: ${school.schoolCode}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode({
          'action': 'restore',
          'schoolCode': school.schoolCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        print('✅ Server restore confirmed: ${result['message']}');

        school.restoreDeleted();
        await school.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('School ${school.schoolName} restored successfully')));
      } else {
        throw Exception(
            'Failed to restore school. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error restoring school: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error restoring school: $e')));
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

// CREATE Account on server
  Future<void> _createAccountInMySQL(Account newAccount) async {
    final Map<String, dynamic> jsonData = _accountsToJson(newAccount);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php?accountCode=${newAccount.accountCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'Account ${newAccount.accountCode} created/updated successfully.');

        newAccount.syncStatus = true;
        newAccount.operationType = 'none';
        newAccount.modifiedFields = [];
        await newAccount.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Account ${newAccount.accountName} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync account. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating account: $e');
      await newAccount.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE Account on server
  Future<void> _updateAccountInMySQL(Account updatedAccount) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in updatedAccount.modifiedFields ?? []) {
      switch (field) {
        case 'accountType':
          modifiedFieldsJson['accountType'] = updatedAccount.accountType;
          break;
        case 'accountSubType':
          modifiedFieldsJson['accountSubType'] = updatedAccount.accountSubType;
          break;
        case 'accountName':
          modifiedFieldsJson['accountName'] = updatedAccount.accountName;
          break;
        case 'isALiquidAccount':
          modifiedFieldsJson['isALiquidAccount'] =
              updatedAccount.isALiquidAccount ?? false;
          break;
      }
    }

    // Always include accountCode for identification
    modifiedFieldsJson['accountCode'] = updatedAccount.accountCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php?accountCode=${updatedAccount.accountCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Account ${updatedAccount.accountCode} updated successfully.');

        if ((updatedAccount.modifiedFields?.isNotEmpty ?? false) &&
            updatedAccount.operationType != null &&
            updatedAccount.operationType != 'none') {
          SyncQueueManager().enqueue(updatedAccount);
        }
        updatedAccount.syncStatus = true;
        updatedAccount.operationType = 'none';
        updatedAccount.modifiedFields = [];
        await updatedAccount.save();
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

// CREATE Project on server
  Future<void> _createProjectInMySQL(Project project) async {
    final Map<String, dynamic> jsonData = _projectsToJson(project);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php?projectCode=${project.projectCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Project ${project.projectCode} created/updated successfully.');

        project.syncStatus = true;
        project.operationType = 'none';
        project.modifiedFields = [];
        await project.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Project ${project.name} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync project. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating project: $e');
      await project.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE Project on server
  Future<void> _updateProjectInMySQL(Project project) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in project.modifiedFields ?? []) {
      switch (field) {
        case 'name':
          modifiedFieldsJson['name'] = project.name;
          break;
        case 'description':
          modifiedFieldsJson['description'] = project.description;
          break;
        case 'status':
          modifiedFieldsJson['status'] = project.status;
          break;
        case 'updatedAt':
          modifiedFieldsJson['updatedAt'] = project.updatedAt.toIso8601String();
          break;
        // ✅ NEW FIELDS
        case 'projectType':
          modifiedFieldsJson['projectType'] = project.projectType;
          break;
        case 'participationType':
          modifiedFieldsJson['participationType'] = project.participationType;
          break;
        case 'studentPayable':
          modifiedFieldsJson['studentPayable'] =
              project.studentPayable ?? false;
          break;
      }
    }

    // Always include projectCode for identification
    modifiedFieldsJson['projectCode'] = project.projectCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php?projectCode=${project.projectCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Project ${project.projectCode} updated successfully.');

        if ((project.modifiedFields?.isNotEmpty ?? false) &&
            project.operationType != null &&
            project.operationType != 'none') {
          SyncQueueManager().enqueue(project);
        }
        project.syncStatus = true;
        project.operationType = 'none';
        project.modifiedFields = [];
        await project.save();
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

// CREATE ProjectItem on server
  Future<void> _createProjectItemInMySQL(ProjectItem item) async {
    final Map<String, dynamic> jsonData = _projectItemsToJson(item);

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php?projectItemCode=${item.projectItemCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'ProjectItem ${item.projectItemCode} created/updated successfully.');

        item.syncStatus = true;
        item.operationType = 'none';
        item.modifiedFields = [];
        await item.save();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('ProjectItem ${item.name} synced successfully')));
      } else {
        throw Exception(
            'Failed to sync project item. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating project item: $e');
      await item.save();
    } finally {
      setState(() {
        _isSyncings = false;
      });
    }
  }

// UPDATE ProjectItem on server
  Future<void> _updateProjectItemInMySQL(ProjectItem item) async {
    final Map<String, dynamic> modifiedFieldsJson = {};

    for (String field in item.modifiedFields ?? []) {
      switch (field) {
        case 'projectCode':
          modifiedFieldsJson['projectCode'] = item.projectCode;
          break;
        case 'name':
          modifiedFieldsJson['name'] = item.name;
          break;
        case 'itemType':
          modifiedFieldsJson['itemType'] = item.itemType;
          break;
        case 'active':
          modifiedFieldsJson['active'] = item.active ?? true;
          break;
        case 'trackStock':
          modifiedFieldsJson['trackStock'] = item.trackStock ?? false;
          break;
      }
    }

    // Always include projectItemCode for identification
    modifiedFieldsJson['projectItemCode'] = item.projectItemCode;

    setState(() {
      _isSyncings = true;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php?projectItemCode=${item.projectItemCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(modifiedFieldsJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('ProjectItem ${item.projectItemCode} updated successfully.');

        if ((item.modifiedFields?.isNotEmpty ?? false) &&
            item.operationType != null &&
            item.operationType != 'none') {
          SyncQueueManager().enqueue(item);
        }
        item.syncStatus = true;
        item.operationType = 'none';
        item.modifiedFields = [];
        await item.save();
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
        'Payment Logs',
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
        'Payment Logs',
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
        'Project Batches',
        'Batch Units',
        'Project Item Pricing',
        'Project Sale Transactions',
        'Batch Unit Sales',
        'Project Payment Method',
        'Project Receipt Snapshot',
        'Payment Logs',
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
        'Payment Logs',
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
        'Payment Logs',
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
        'Payment Logs',
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
      'Withdrawals': _fetchAndSyncWithdrawals,
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
      'Payment Logs': _fetchAndSyncPaymentLogs,
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
    print('=== _decodeToList START ===');
    print('Value type: ${value.runtimeType}');
    print('Value: $value');

    if (value == null) {
      print('Value is null, returning empty list');
      return [];
    }

    // ✅ If it's already a List
    if (value is List) {
      print('Value is a List with ${value.length} items');
      return value.map((e) => e.toString()).toList();
    }

    // ✅ If it's a String
    if (value is String) {
      print('Value is a String');
      if (value.isEmpty) {
        print('String is empty, returning empty list');
        return [];
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          print('Successfully decoded JSON string to List');
          return decoded.map((e) => e.toString()).toList();
        } else if (decoded is Map) {
          print('Decoded to Map, returning empty list');
          return [];
        } else {
          print('Decoded to ${decoded.runtimeType}, treating as single item');
          return [value];
        }
      } catch (e) {
        print('Failed to decode JSON: $e');
        return [];
      }
    }

    // ✅ If it's an int or double, convert to String
    if (value is int || value is double) {
      print('Value is number, converting to String');
      return [value.toString()];
    }

    // ✅ If it's a Map
    if (value is Map) {
      print('Value is a Map, returning empty list');
      return [];
    }

    // ✅ Unknown type
    print('Unknown type: ${value.runtimeType}, returning empty list');
    return [];
  }

// ✅ FIXED: Handle both String and List types
  //================================decode _decodeExceptions =======================================================================//

  List<ExceptionalStudents> _decodeExceptions(dynamic value) {
    print('=== _decodeExceptions START ===');
    print('Value type: ${value.runtimeType}');

    if (value == null) {
      print('Value is null, returning empty list');
      return [];
    }

    List<dynamic> exceptionList = [];

    // ✅ If it's already a List
    if (value is List) {
      print('Value is a List with ${value.length} items');
      exceptionList = value;
    }
    // ✅ If it's a String (JSON string)
    else if (value is String) {
      print('Value is a String, attempting to decode...');
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          print('Successfully decoded JSON string to List');
          exceptionList = decoded;
        } else if (decoded is Map) {
          print('Decoded JSON string to Map, wrapping in List');
          exceptionList = [decoded];
        } else {
          print('Decoded value is neither List nor Map');
          return [];
        }
      } catch (e) {
        print('Failed to decode JSON string: $e');
        return [];
      }
    }
    // ✅ If it's a Map (single exception object)
    else if (value is Map) {
      print('Value is a Map, wrapping in List');
      exceptionList = [value];
    }
    // ✅ Unknown type
    else {
      print('Unknown type: ${value.runtimeType}, returning empty list');
      return [];
    }

    // ✅ Convert each item to ExceptionalStudents
    List<ExceptionalStudents> result = [];
    for (var exceptionData in exceptionList) {
      try {
        print('Processing exception data: $exceptionData');
        print('Exception data type: ${exceptionData.runtimeType}');

        // ✅ CRITICAL FIX: Ensure exceptionData is a Map
        if (exceptionData is Map) {
          // ✅ Pass as Map<String, dynamic>
          final exception =
              _exceptionFromJson(exceptionData.cast<String, dynamic>());
          result.add(exception);
        } else {
          print('❌ Exception data is not a Map: ${exceptionData.runtimeType}');
          print('❌ Value: $exceptionData');
        }
      } catch (e, stack) {
        print('❌ Error converting exception: $e');
        print('Stack: $stack');
        print('Data: $exceptionData');
      }
    }

    print('Returning ${result.length} exceptions');
    print('=== _decodeExceptions END ===');
    return result;
  }

//================================decode _exceptionFromJson =======================================================================//

  ExceptionalStudents _exceptionFromJson(Map<String, dynamic> json) {
    print('=== _exceptionFromJson START ===');
    print('JSON keys: ${json.keys}');

    // ✅ Helper to safely convert to List<String>
    List<String> _toList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        print('_toList: value is List, converting to List<String>');
        return value.map((e) => e.toString()).toList();
      }
      if (value is String) {
        print('_toList: value is String, attempting to decode...');
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (e) {
          print('_toList: Failed to decode: $e');
        }
      }
      return [];
    }

    // ✅ Helper to safely convert to bool
    bool _toBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return false;
    }

    // ✅ Helper to safely convert to int
    int _toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is bool) return value ? 1 : 0;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    // ✅ Helper to safely convert to DateTime
    DateTime? _toDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // ✅ Parse all fields safely
    final exception = ExceptionalStudents(
      id: _toInt(json['id']),
      exceptionId: json['exceptionId']?.toString() ?? '',
      exceptionName: json['exceptionName']?.toString(),
      exceptionStatus: json['exceptionStatus']?.toString(),
      exceptionType: json['exceptionType']?.toString(),
      exceptionFigure: json['exceptionFigure']?.toString(),
      priorityFlag: _toInt(json['priorityFlag']),
      terms: _toList(json['terms']),
      syncStatus: _toBool(json['syncStatus']),
      lastModified: _toDateTime(json['lastModified']),
      operationType: 'none',
      modifiedFields: _toList(json['modifiedFields']),
    );

    print('✅ Created exception: ${exception.exceptionId}');
    print('=== _exceptionFromJson END ===');
    return exception;
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

  // PULL PaymentLogs from server
  Future<void> _fetchAndSyncPaymentLogs() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/payment_receipts_log_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        List<dynamic> logs;
        if (decoded is List) {
          logs = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format');
          return;
        }

        if (logs.isEmpty) {
          print('No payment logs found on server');
          return;
        }

        for (var logData in logs) {
          try {
            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (logData['syncStatus'] != null) {
              if (logData['syncStatus'] is int) {
                syncStatus = logData['syncStatus'] == 1;
              } else if (logData['syncStatus'] is bool) {
                syncStatus = logData['syncStatus'];
              }
            }

            // ✅ Convert isReprint from int to bool
            bool isReprint = false;
            if (logData['isReprint'] != null) {
              if (logData['isReprint'] is int) {
                isReprint = logData['isReprint'] == 1;
              } else if (logData['isReprint'] is bool) {
                isReprint = logData['isReprint'];
              }
            }

            // ✅ Parse receiptLines
            List<Map<String, dynamic>> receiptLines = [];
            if (logData['receiptLines'] != null) {
              if (logData['receiptLines'] is List) {
                receiptLines = (logData['receiptLines'] as List)
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList();
              } else if (logData['receiptLines'] is String) {
                try {
                  final decoded = jsonDecode(logData['receiptLines']);
                  if (decoded is List) {
                    receiptLines = decoded
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList();
                  }
                } catch (e) {
                  print('Error decoding receiptLines: $e');
                }
              }
            }

            // ✅ Parse modifiedFields
            List<String> modifiedFields = [];
            if (logData['modifiedFields'] != null) {
              if (logData['modifiedFields'] is List) {
                modifiedFields = (logData['modifiedFields'] as List)
                    .map((e) => e.toString())
                    .toList();
              } else if (logData['modifiedFields'] is String) {
                try {
                  final decoded = jsonDecode(logData['modifiedFields']);
                  if (decoded is List) {
                    modifiedFields = decoded.map((e) => e.toString()).toList();
                  }
                } catch (e) {
                  modifiedFields = [];
                }
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (logData['lastModified'] != null) {
              try {
                if (logData['lastModified'] is String) {
                  lastModified = DateTime.parse(logData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            PaymentLog fetchedLog = PaymentLog(
              receiptNumber: logData['receiptNumber'] ?? 0,
              studentName: logData['studentName'] ?? '',
              className: logData['className'] ?? '',
              dateTime: logData['dateTime'] ?? DateTime.now().toIso8601String(),
              receiptLines: receiptLines,
              parentName: logData['parentName'],
              parentPhone: logData['parentPhone'],
              isReprint: isReprint,
              originalReceiptNumber: logData['originalReceiptNumber'],
              reprintCount: logData['reprintCount'] ?? 0,
              logId: logData['logId'] ?? 'LOG_${logData['receiptNumber']}',
              syncStatus: syncStatus,
              lastModified: lastModified,
              operationType: 'none',
              modifiedFields: modifiedFields,
            );

            // Check if log exists in Hive
            var existingLogList = _paymentLogBox!.values
                .where((log) => log.logId == fetchedLog.logId)
                .toList();

            if (existingLogList.isNotEmpty) {
              // Update existing log
              var existingLog = existingLogList.first;
              existingLog
                ..receiptNumber = fetchedLog.receiptNumber
                ..studentName = fetchedLog.studentName
                ..className = fetchedLog.className
                ..dateTime = fetchedLog.dateTime
                ..receiptLines = fetchedLog.receiptLines
                ..parentName = fetchedLog.parentName
                ..parentPhone = fetchedLog.parentPhone
                ..isReprint = fetchedLog.isReprint
                ..originalReceiptNumber = fetchedLog.originalReceiptNumber
                ..reprintCount = fetchedLog.reprintCount
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingLog.save();
              print('PaymentLog ${fetchedLog.logId} updated in Hive.');
            } else {
              // Create new log
              await _paymentLogBox!.add(fetchedLog);
              print('PaymentLog ${fetchedLog.logId} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing payment log:');
            print('Data: ${logData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${logs.length} payment logs from server')));
      } else {
        throw Exception(
            'Failed to fetch payment logs. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing payment logs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing payment logs: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncStudentExceptions =======================================================================//

// PULL Exceptions from server
  Future<void> _fetchAndSyncStudentExceptions() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/exceptions_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        // Handle both list and map responses
        List<dynamic> exceptions;
        if (decoded is List) {
          exceptions = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          exceptions = decoded.entries
              .where((e) => e.value is Map)
              .map((e) => e.value)
              .toList();
        }

        if (exceptions.isEmpty) {
          print('No exceptions found on server');
          return;
        }

        for (var exceptionData in exceptions) {
          // ✅ Convert syncStatus from int to bool
          bool syncStatus = true;
          if (exceptionData['syncStatus'] != null) {
            if (exceptionData['syncStatus'] is int) {
              syncStatus = exceptionData['syncStatus'] == 1;
            } else if (exceptionData['syncStatus'] is bool) {
              syncStatus = exceptionData['syncStatus'];
            }
          }

          // ✅ Parse priorityFlag
          int priorityFlag = 0;
          if (exceptionData['priorityFlag'] != null) {
            if (exceptionData['priorityFlag'] is int) {
              priorityFlag = exceptionData['priorityFlag'];
            } else if (exceptionData['priorityFlag'] is bool) {
              priorityFlag = exceptionData['priorityFlag'] ? 1 : 0;
            } else if (exceptionData['priorityFlag'] is String) {
              priorityFlag = int.tryParse(exceptionData['priorityFlag']) ?? 0;
            }
          }
          // ✅ Parse terms - using existing _decodeToList method
          List<String> terms = _decodeToList(exceptionData['terms']);

          // ✅ Parse modifiedFields - using existing _decodeToList method
          List<String> modifiedFields =
              _decodeToList(exceptionData['modifiedFields']);

          // ✅ Handle id
          int? id;
          if (exceptionData['id'] != null) {
            id = exceptionData['id'] is int
                ? exceptionData['id']
                : int.tryParse(exceptionData['id'].toString());
          }

          // ✅ Parse lastModified
          DateTime? lastModified;
          try {
            if (exceptionData['lastModified'] != null) {
              lastModified = DateTime.parse(exceptionData['lastModified']);
            }
          } catch (e) {
            lastModified = DateTime.now();
          }

          ExceptionalStudents fetchedException = ExceptionalStudents(
            id: id,
            exceptionId: exceptionData['exceptionId'] ?? '',
            exceptionName: exceptionData['exceptionName'],
            exceptionStatus: exceptionData['exceptionStatus'],
            exceptionType: exceptionData['exceptionType'],
            exceptionFigure: exceptionData['exceptionFigure'],
            priorityFlag: priorityFlag,
            terms: terms,
            syncStatus: syncStatus,
            operationType: 'none',
            lastModified: lastModified,
            modifiedFields: modifiedFields,
          );

          // Check if exception exists in Hive
          var existingExceptionList = _exceptionalStudentsBox!.values
              .where((exception) =>
                  exception.exceptionId == fetchedException.exceptionId)
              .toList();

          if (existingExceptionList.isNotEmpty) {
            // Update existing exception
            var existingException = existingExceptionList.first;
            existingException
              ..id = fetchedException.id
              ..exceptionId = fetchedException.exceptionId
              ..exceptionName = fetchedException.exceptionName
              ..exceptionStatus = fetchedException.exceptionStatus
              ..exceptionType = fetchedException.exceptionType
              ..exceptionFigure = fetchedException.exceptionFigure
              ..priorityFlag = fetchedException.priorityFlag
              ..terms = fetchedException.terms
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now();

            await existingException.save();
            print('Exception ${fetchedException.exceptionId} updated in Hive.');
          } else {
            // Create new exception
            await _exceptionalStudentsBox!.add(fetchedException);
            print('Exception ${fetchedException.exceptionId} added to Hive.');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Synced ${exceptions.length} exceptions from server')));
      } else {
        throw Exception(
            'Failed to fetch exceptions. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing exceptions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing exceptions: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  //================================pull _fetchAndSyncProjectReceiptSnapshot =======================================================================//
//================================pull _fetchAndSyncProjectReceiptSnapshot =======================================================================//

  Future<void> _fetchAndSyncProjectReceiptSnapshot() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_receipt_snapshot_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        final List<dynamic> receipts = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded ${receipts.length} ReceiptSnapshots');

        for (var item in receipts) {
          if (item is! Map) continue;

          final Map<String, dynamic> json = Map<String, dynamic>.from(item);

          final String? receiptCode = json['receiptCode'];

          if (receiptCode == null) {
            print('Skipped ReceiptSnapshot with no receiptCode');
            continue;
          }

          // ✅ Convert syncStatus from int to bool
          bool syncStatus = true;
          if (json['syncStatus'] != null) {
            if (json['syncStatus'] is int) {
              syncStatus = json['syncStatus'] == 1;
            } else if (json['syncStatus'] is bool) {
              syncStatus = json['syncStatus'];
            }
          }

          // ✅ Convert isReprint from int to bool
          bool isReprint = false;
          if (json['isReprint'] != null) {
            if (json['isReprint'] is int) {
              isReprint = json['isReprint'] == 1;
            } else if (json['isReprint'] is bool) {
              isReprint = json['isReprint'];
            }
          }

          // ✅ Parse receiptDate
          DateTime receiptDate = DateTime.now();
          if (json['receiptDate'] != null) {
            try {
              receiptDate = DateTime.parse(json['receiptDate']);
            } catch (e) {
              receiptDate = DateTime.now();
            }
          }

          // ✅ Parse modifiedFields
          List<String> modifiedFields = _decodeToList(json['modifiedFields']);

          // ✅ FIX: Parse receiptLinesJson - properly cast to List<Map<String, dynamic>>
          List<Map<String, dynamic>> receiptLinesJson = [];
          if (json['receiptLinesJson'] != null) {
            if (json['receiptLinesJson'] is List) {
              // ✅ Cast each item to Map<String, dynamic>
              receiptLinesJson = (json['receiptLinesJson'] as List)
                  .map((item) {
                    if (item is Map) {
                      return Map<String, dynamic>.from(item);
                    }
                    return <String, dynamic>{};
                  })
                  .where((item) => item.isNotEmpty)
                  .toList();
              print('✅ Parsed ${receiptLinesJson.length} receipt lines');
            } else if (json['receiptLinesJson'] is String) {
              try {
                final decoded = jsonDecode(json['receiptLinesJson']);
                if (decoded is List) {
                  receiptLinesJson = decoded
                      .map((item) {
                        if (item is Map) {
                          return Map<String, dynamic>.from(item);
                        }
                        return <String, dynamic>{};
                      })
                      .where((item) => item.isNotEmpty)
                      .toList();
                }
              } catch (e) {
                print('Error decoding receiptLinesJson: $e');
              }
            }
          }

          // ✅ Parse lastModified
          DateTime? lastModified;
          if (json['lastModified'] != null) {
            try {
              lastModified = DateTime.parse(json['lastModified']);
            } catch (e) {
              lastModified = DateTime.now();
            }
          }

          // ✅ Parse amounts safely
          double totalExpected = 0.0;
          if (json['totalExpected'] != null) {
            if (json['totalExpected'] is double) {
              totalExpected = json['totalExpected'];
            } else if (json['totalExpected'] is int) {
              totalExpected = json['totalExpected'].toDouble();
            } else if (json['totalExpected'] is String) {
              totalExpected = double.tryParse(json['totalExpected']) ?? 0.0;
            }
          }

          double totalPaid = 0.0;
          if (json['totalPaid'] != null) {
            if (json['totalPaid'] is double) {
              totalPaid = json['totalPaid'];
            } else if (json['totalPaid'] is int) {
              totalPaid = json['totalPaid'].toDouble();
            } else if (json['totalPaid'] is String) {
              totalPaid = double.tryParse(json['totalPaid']) ?? 0.0;
            }
          }

          double amountReceived = 0.0;
          if (json['amountReceived'] != null) {
            if (json['amountReceived'] is double) {
              amountReceived = json['amountReceived'];
            } else if (json['amountReceived'] is int) {
              amountReceived = json['amountReceived'].toDouble();
            } else if (json['amountReceived'] is String) {
              amountReceived = double.tryParse(json['amountReceived']) ?? 0.0;
            }
          }

          double change = 0.0;
          if (json['change'] != null) {
            if (json['change'] is double) {
              change = json['change'];
            } else if (json['change'] is int) {
              change = json['change'].toDouble();
            } else if (json['change'] is String) {
              change = double.tryParse(json['change']) ?? 0.0;
            }
          }

          final ReceiptSnapshot fetchedReceipt = ReceiptSnapshot(
            receiptCode: receiptCode,
            receiptDate: receiptDate,
            cashier: json['cashier']?.toString() ?? '',
            totalExpected: totalExpected,
            totalPaid: totalPaid,
            amountReceived: amountReceived,
            change: change,
            currency: json['currency']?.toString() ?? 'USD',
            receiptLinesJson: receiptLinesJson, // ✅ Now properly typed
            isReprint: isReprint,
            studentName: json['studentName']?.toString() ?? '',
            studentClass: json['studentClass']?.toString(),
            syncStatus: syncStatus,
            lastModified: lastModified,
            operationType: json['operationType']?.toString() ?? 'none',
            modifiedFields: modifiedFields,
          );

          // Check if receipt exists in Hive
          var existingList = _receiptSnapshotBox!.values
              .where((r) => r.receiptCode == fetchedReceipt.receiptCode)
              .toList();

          ReceiptSnapshot? existing =
              existingList.isNotEmpty ? existingList.first : null;

          if (existing != null) {
            // ✅ Update existing
            existing
              ..receiptDate = fetchedReceipt.receiptDate
              ..cashier = fetchedReceipt.cashier
              ..totalExpected = fetchedReceipt.totalExpected
              ..totalPaid = fetchedReceipt.totalPaid
              ..amountReceived = fetchedReceipt.amountReceived
              ..change = fetchedReceipt.change
              ..currency = fetchedReceipt.currency
              ..receiptLinesJson = fetchedReceipt.receiptLinesJson
              ..isReprint = fetchedReceipt.isReprint
              ..studentName = fetchedReceipt.studentName
              ..studentClass = fetchedReceipt.studentClass
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now()
              ..modifiedFields = [];

            await existing.save();
            print(
                'ReceiptSnapshot ${fetchedReceipt.receiptCode} updated in Hive.');
          } else {
            // ✅ Create new
            await _receiptSnapshotBox!.add(fetchedReceipt);
            print(
                'ReceiptSnapshot ${fetchedReceipt.receiptCode} added to Hive.');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch ReceiptSnapshots. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching/syncing ReceiptSnapshots: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
  //================================pull _fetchAndSyncProjectPaymentMethod =======================================================================//

  Future<void> _fetchAndSyncProjectPaymentMethod() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_payment_method_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        final List<dynamic> paymentMethods = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded PaymentMethod response: $decoded');

        for (var item in paymentMethods) {
          // 🔹 Ensure valid map
          if (item is! Map) continue;

          final Map<String, dynamic> json = Map<String, dynamic>.from(item);

          // 🔹 Primary key
          final String? paymentMethodCode = json['payment_method_code'];

          if (paymentMethodCode == null) {
            print('Skipped PaymentMethod with no code');
            continue;
          }

          // =========================================================
          // 🔹 PARSE DATE (EXPLICIT)
          // =========================================================
          DateTime? paymentDate = DateTime.tryParse(json['payment_date'] ?? '');

          // =========================================================
          // 🔹 BUILD OBJECT (ALL FIELDS EXPLICIT)
          // =========================================================
          final PaymentMethod fetchedMethod = PaymentMethod(
            paymentMethodCode: paymentMethodCode,
            methodType: json['method_type'],
            amount: (json['amount'] ?? 0).toDouble(),
            currency: json['currency'],
            provider: json['provider'],
            reference: json['reference'],
            phoneNumber: json['phone_number'],
            accountNumber: json['account_number'],
            accountName: json['account_name'],
            paymentDate: paymentDate,
            isReversed: json['is_reversed'] ?? false,

            // 🔹 Sync fields (server → local)
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.now(),
            modifiedFields: [],
          );

          // =========================================================
          // 🔍 CHECK EXISTING
          // =========================================================
          final existingList = _paymentMethodBox!.values
              .where((pm) =>
                  pm.paymentMethodCode == fetchedMethod.paymentMethodCode)
              .toList();

          PaymentMethod? existing =
              existingList.isNotEmpty ? existingList.first : null;

          // =========================================================
          // 🔄 UPDATE OR CREATE (EXPLICIT)
          // =========================================================
          if (existing != null) {
            existing
              ..methodType = fetchedMethod.methodType
              ..amount = fetchedMethod.amount
              ..currency = fetchedMethod.currency
              ..provider = fetchedMethod.provider
              ..reference = fetchedMethod.reference
              ..phoneNumber = fetchedMethod.phoneNumber
              ..accountNumber = fetchedMethod.accountNumber
              ..accountName = fetchedMethod.accountName
              ..paymentDate = fetchedMethod.paymentDate
              ..isReversed = fetchedMethod.isReversed

              // 🔹 Sync
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now()
              ..modifiedFields = [];

            await existing.save();

            print(
                'PaymentMethod ${fetchedMethod.paymentMethodCode} updated successfully.');
          } else {
            await _paymentMethodBox!.add(fetchedMethod);

            print(
                'PaymentMethod ${fetchedMethod.paymentMethodCode} added successfully.');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch PaymentMethods. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching/syncing PaymentMethods: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  //================================pull _fetchAndSyncBatchUnitSales =======================================================================//
  PackagingLevel? _parsePackagingLevelNullable(dynamic value) {
    if (value == null) return null;

    try {
      return PackagingLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toString().toLowerCase(),
      );
    } catch (_) {
      return null; // keep nullable as per model
    }
  }

// PULL BatchSellUnits from server
  Future<void> _fetchAndSyncBatchUnitSales() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_sell_unit_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        final List<dynamic> unitsList = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded BatchSellUnit response: $decoded');

        for (var item in unitsList) {
          if (item is! Map) continue;

          final Map<String, dynamic> json = Map<String, dynamic>.from(item);

          final String? sellUnitCode = json['sellUnitCode'];

          if (sellUnitCode == null) {
            print('Skipped BatchSellUnit with no sellUnitCode');
            continue;
          }

          // ✅ Convert syncStatus from int to bool
          bool syncStatus = true;
          if (json['syncStatus'] != null) {
            if (json['syncStatus'] is int) {
              syncStatus = json['syncStatus'] == 1;
            } else if (json['syncStatus'] is bool) {
              syncStatus = json['syncStatus'];
            }
          }

          // ✅ Convert active from int to bool
          bool active = true;
          if (json['active'] != null) {
            if (json['active'] is int) {
              active = json['active'] == 1;
            } else if (json['active'] is bool) {
              active = json['active'];
            }
          }

          // ✅ Parse dates
          DateTime? deletedAt = DateTime.tryParse(json['deletedAt'] ?? '');

          DateTime? lastModified;
          if (json['lastModified'] != null) {
            try {
              lastModified = DateTime.parse(json['lastModified']);
            } catch (e) {
              lastModified = DateTime.now();
            }
          }

          // ✅ Parse modifiedFields
          List<String> modifiedFields = _decodeToList(json['modifiedFields']);

          final BatchSellUnit fetchedUnit = BatchSellUnit(
            sellUnitCode: sellUnitCode,
            batchCode: json['batchCode']?.toString() ?? '',
            unitName: json['unitName']?.toString() ?? '',
            quantityMultiplier: (json['quantityMultiplier'] ?? 0).toInt(),
            sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
            active: active,
            deletedAt: deletedAt,
            packagingLevel:
                _parsePackagingLevelNullable(json['packagingLevel']),
            baseUnitsPerSellUnit:
                (json['baseUnitsPerSellUnit'] ?? 0).toDouble(),
            baseUnit: json['baseUnit']?.toString(),
            baseUnitType: _parseStockUnitType(json['baseUnitType']),
            syncStatus: syncStatus,
            lastModified: lastModified,
            operationType: json['operationType']?.toString() ?? 'none',
            modifiedFields: modifiedFields,
          );

          // Check if unit exists in Hive
          var existingList = _batchSellUnitBox!.values
              .where((u) => u.sellUnitCode == fetchedUnit.sellUnitCode)
              .toList();

          BatchSellUnit? existing =
              existingList.isNotEmpty ? existingList.first : null;

          if (existing != null) {
            // ✅ Update existing
            existing
              ..batchCode = fetchedUnit.batchCode
              ..unitName = fetchedUnit.unitName
              ..quantityMultiplier = fetchedUnit.quantityMultiplier
              ..sellingPrice = fetchedUnit.sellingPrice
              ..active = fetchedUnit.active
              ..deletedAt = fetchedUnit.deletedAt
              ..packagingLevel = fetchedUnit.packagingLevel
              ..baseUnitsPerSellUnit = fetchedUnit.baseUnitsPerSellUnit
              ..baseUnit = fetchedUnit.baseUnit
              ..baseUnitType = fetchedUnit.baseUnitType
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now()
              ..modifiedFields = [];

            await existing.save();
            print('BatchSellUnit ${fetchedUnit.sellUnitCode} updated in Hive.');
          } else {
            // ✅ Create new
            await _batchSellUnitBox!.add(fetchedUnit);
            print('BatchSellUnit ${fetchedUnit.sellUnitCode} added to Hive.');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch BatchSellUnits. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching/syncing BatchSellUnits: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  //================================pull _fetchAndSyncProjectSaleTransactions =======================================================================//

// PULL ProjectSaleTransactions from server
  Future<void> _fetchAndSyncProjectSaleTransactions() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_sale_transaction_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        List<dynamic> transactions;
        if (decoded is List) {
          transactions = decoded;
        } else {
          print('Unexpected response format');
          return;
        }

        print('Decoded ${transactions.length} transactions');

        for (var item in transactions) {
          if (item is! Map) continue;

          final Map<String, dynamic> json = Map<String, dynamic>.from(item);

          final String? transactionCode = json['transactionCode'];

          if (transactionCode == null) {
            print('Skipped transaction with no transactionCode');
            continue;
          }

          // ✅ Convert bool fields from int
          bool syncStatus =
              json['syncStatus'] == true || json['syncStatus'] == 1;
          bool isDeleted = json['isDeleted'] == true || json['isDeleted'] == 1;
          bool isReversed =
              json['isReversed'] == true || json['isReversed'] == 1;
          bool affectsStock =
              json['affectsStock'] == true || json['affectsStock'] == 1;
          bool createsObligation = json['createsObligation'] == true ||
              json['createsObligation'] == 1;
          bool settlesObligation = json['settlesObligation'] == true ||
              json['settlesObligation'] == 1;

          // ✅ Parse dates
          DateTime? transactionDate =
              DateTime.tryParse(json['transactionDate'] ?? '');
          DateTime? lastModified =
              DateTime.tryParse(json['lastModified'] ?? '');
          DateTime? paymentDatetransacted =
              DateTime.tryParse(json['paymentDatetransacted'] ?? '');

          // ✅ Parse Lists from JSON
          List<DateTime> deletedAt = _decodeDateList(json['deletedAt']);
          List<DateTime> restoredAt = _decodeDateList(json['restoredAt']);
          List<String> deletedByUsers = _decodeToList(json['deletedByUsers']);
          List<String> restoredByUsers = _decodeToList(json['restoredByUsers']);
          List<String> lineTransactionCodes =
              _decodeToList(json['lineTransactionCodes']);
          List<String> modifiedFields = _decodeToList(json['modifiedFields']);

          // ✅ Parse StockUnitType
          StockUnitType baseUnitType = StockUnitType.piece;
          if (json['baseUnitType'] != null) {
            try {
              baseUnitType = StockUnitType.values.firstWhere(
                (e) =>
                    e.name.toLowerCase() ==
                    json['baseUnitType'].toString().toLowerCase(),
                orElse: () => StockUnitType.piece,
              );
            } catch (e) {
              baseUnitType = StockUnitType.piece;
            }
          }

          final ProjectSaleTransaction fetchedTx = ProjectSaleTransaction(
            transactionCode: transactionCode,
            studentId: json['studentId']?.toString() ?? '',
            projectCode: json['projectCode']?.toString() ?? '',
            projectItemCode: json['projectItemCode']?.toString() ?? '',
            batchCode: json['batchCode']?.toString() ?? '',
            sellUnitCode: json['sellUnitCode']?.toString() ?? '',
            sellUnitNameSnapshot:
                json['sellUnitNameSnapshot']?.toString() ?? '',
            quantitySold: (json['quantitySold'] ?? 0).toInt(),
            unitSellingPrice: (json['unitSellingPrice'] ?? 0).toDouble(),
            totalAmount: (json['totalAmount'] ?? 0).toDouble(),
            baseUnitsPerSellUnit:
                (json['baseUnitsPerSellUnit'] ?? 0).toDouble(),
            totalBaseUnitsSold: (json['totalBaseUnitsSold'] ?? 0).toDouble(),
            baseUnit: json['baseUnit']?.toString() ?? '',
            baseUnitType: baseUnitType,
            transactionDate: transactionDate ?? DateTime.now(),
            paymentMethod: json['paymentMethod']?.toString() ?? '',
            reference: json['reference']?.toString() ?? '',
            amountPaid: (json['amountPaid'] ?? 0).toDouble(),
            arrears: (json['arrears'] ?? 0).toDouble(),
            paymentMethodCode: json['paymentMethodCode']?.toString(),
            methodType: json['methodType']?.toString(),
            amountPaidInPaymentMethod:
                (json['amountPaidInPaymentMethod'] ?? 0).toDouble(),
            currency: json['currency']?.toString(),
            provider: json['provider']?.toString(),
            referenceNumber: json['referenceNumber']?.toString(),
            phoneNumber: json['phoneNumber']?.toString(),
            accountNumber: json['accountNumber']?.toString(),
            accountName: json['accountName']?.toString(),
            paymentDatetransacted: paymentDatetransacted,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            restoredAt: restoredAt,
            deletedByUsers: deletedByUsers,
            restoredByUsers: restoredByUsers,
            isReversed: isReversed,
            lineTransactionCodes: lineTransactionCodes,
            financialType: json['financialType']?.toString() ?? 'sale',
            parentTransactionCode: json['parentTransactionCode']?.toString(),
            affectsStock: affectsStock,
            createsObligation: createsObligation,
            settlesObligation: settlesObligation,
            syncStatus: syncStatus,
            lastModified: lastModified,
            operationType: json['operationType']?.toString() ?? 'none',
            modifiedFields: modifiedFields,
          );

          // Check if transaction exists in Hive
          var existingList = _projectSaleTransactionBox!.values
              .where((t) => t.transactionCode == fetchedTx.transactionCode)
              .toList();

          ProjectSaleTransaction? existing =
              existingList.isNotEmpty ? existingList.first : null;

          if (existing != null) {
            // ✅ Update existing
            existing
              ..studentId = fetchedTx.studentId
              ..projectCode = fetchedTx.projectCode
              ..projectItemCode = fetchedTx.projectItemCode
              ..batchCode = fetchedTx.batchCode
              ..sellUnitCode = fetchedTx.sellUnitCode
              ..sellUnitNameSnapshot = fetchedTx.sellUnitNameSnapshot
              ..quantitySold = fetchedTx.quantitySold
              ..unitSellingPrice = fetchedTx.unitSellingPrice
              ..totalAmount = fetchedTx.totalAmount
              ..baseUnitsPerSellUnit = fetchedTx.baseUnitsPerSellUnit
              ..totalBaseUnitsSold = fetchedTx.totalBaseUnitsSold
              ..baseUnit = fetchedTx.baseUnit
              ..baseUnitType = fetchedTx.baseUnitType
              ..transactionDate = fetchedTx.transactionDate
              ..paymentMethod = fetchedTx.paymentMethod
              ..reference = fetchedTx.reference
              ..amountPaid = fetchedTx.amountPaid
              ..arrears = fetchedTx.arrears
              ..paymentMethodCode = fetchedTx.paymentMethodCode
              ..methodType = fetchedTx.methodType
              ..amountPaidInPaymentMethod = fetchedTx.amountPaidInPaymentMethod
              ..currency = fetchedTx.currency
              ..provider = fetchedTx.provider
              ..referenceNumber = fetchedTx.referenceNumber
              ..phoneNumber = fetchedTx.phoneNumber
              ..accountNumber = fetchedTx.accountNumber
              ..accountName = fetchedTx.accountName
              ..paymentDatetransacted = fetchedTx.paymentDatetransacted
              ..isDeleted = fetchedTx.isDeleted
              ..deletedAt = fetchedTx.deletedAt
              ..restoredAt = fetchedTx.restoredAt
              ..deletedByUsers = fetchedTx.deletedByUsers
              ..restoredByUsers = fetchedTx.restoredByUsers
              ..isReversed = fetchedTx.isReversed
              ..lineTransactionCodes = fetchedTx.lineTransactionCodes
              ..financialType = fetchedTx.financialType
              ..parentTransactionCode = fetchedTx.parentTransactionCode
              ..affectsStock = fetchedTx.affectsStock
              ..createsObligation = fetchedTx.createsObligation
              ..settlesObligation = fetchedTx.settlesObligation
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now()
              ..modifiedFields = [];

            await existing.save();
            print('Transaction ${fetchedTx.transactionCode} updated in Hive.');
          } else {
            // ✅ Create new
            await _projectSaleTransactionBox!.add(fetchedTx);
            print('Transaction ${fetchedTx.transactionCode} added to Hive.');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch transactions. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching/syncing transactions: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  List<DateTime> _decodeDateList(dynamic value) {
    if (value == null) return [];
    List<DateTime> result = [];
    if (value is List) {
      for (var item in value) {
        try {
          if (item is String) {
            result.add(DateTime.parse(item));
          }
        } catch (e) {
          // Skip invalid dates
        }
      }
    }
    return result;
  }
//================================pull _fetchAndSyncProjectItemPricing =======================================================================//

  Future<void> _fetchAndSyncProjectItemPricing() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_price_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        final List<dynamic> pricingList = decoded is List
            ? decoded
            : decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();

        print('Decoded ProjectItemPricing response: $decoded');

        for (var item in pricingList) {
          // 🔹 Ensure valid map
          if (item is! Map) continue;

          final Map<String, dynamic> json = Map<String, dynamic>.from(item);

          // 🔹 Extract primary key
          final String? priceCode = json['priceCode'];

          if (priceCode == null) {
            print('Skipped ProjectItemPrice with no priceCode');
            continue;
          }

          // =========================================================
          // 🔹 PARSE DATES EXPLICITLY
          // =========================================================
          DateTime? effectiveFrom =
              DateTime.tryParse(json['effectiveFrom'] ?? '');

          DateTime? effectiveTo = DateTime.tryParse(json['effectiveTo'] ?? '');

          // =========================================================
          // 🔹 BUILD OBJECT (EXPLICIT)
          // =========================================================
          final ProjectItemPrice fetchedPrice = ProjectItemPrice(
            priceCode: priceCode,
            projectItemCode: json['projectItemCode'],
            amount: (json['amount'] ?? 0).toDouble(),
            pricingType: json['pricingType'],
            appliesTo: json['appliesTo'],
            effectiveFrom: effectiveFrom ?? DateTime.now(),
            effectiveTo: effectiveTo,

            // 🔹 Sync fields (server → local)
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.now(),
            modifiedFields: [],
          );

          // =========================================================
          // 🔍 CHECK EXISTING IN HIVE
          // =========================================================
          final existingList = _projectItemPriceBox!.values
              .where((p) => p.priceCode == fetchedPrice.priceCode)
              .toList();

          ProjectItemPrice? existing =
              existingList.isNotEmpty ? existingList.first : null;

          // =========================================================
          // 🔄 UPDATE OR CREATE
          // =========================================================
          if (existing != null) {
            // 🔄 UPDATE (explicit field-by-field)
            existing
              ..projectItemCode = fetchedPrice.projectItemCode
              ..amount = fetchedPrice.amount
              ..pricingType = fetchedPrice.pricingType
              ..appliesTo = fetchedPrice.appliesTo
              ..effectiveFrom = fetchedPrice.effectiveFrom
              ..effectiveTo = fetchedPrice.effectiveTo
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now()
              ..modifiedFields = [];

            await existing.save();

            print(
                'ProjectItemPrice ${fetchedPrice.priceCode} updated successfully.');
          } else {
            // ➕ CREATE
            await _projectItemPriceBox!.add(fetchedPrice);

            print(
                'ProjectItemPrice ${fetchedPrice.priceCode} added successfully.');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch ProjectItemPricing. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching/syncing ProjectItemPricing: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncBatchUnits =======================================================================//
  PackagingLevel _parsePackagingLevel(String? value) {
    if (value == null) {
      return PackagingLevel.single;
    }

    try {
      final result = PackagingLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toLowerCase(),
        orElse: () {
          return PackagingLevel.single;
        },
      );
      return result;
    } catch (e) {
      return PackagingLevel.single;
    }
  }

// PULL BatchUnits from server
// ✅ Helper: Find ProductBatch with multiple strategies
  Future<ProductBatch?> _findProductBatch(
      String batchCode, Box<ProductBatch> box) async {
    final allBatches = box.values.toList();

    if (allBatches.isEmpty) {
      return null;
    }

    // Print all available batch codes for debugging
    for (var b in allBatches) {}

    // ✅ Strategy 1: Exact match
    for (var b in allBatches) {
      if (b.batchCode == batchCode) {
        return b;
      }
    }

    // ✅ Strategy 2: Trim match
    for (var b in allBatches) {
      if (b.batchCode!.trim() == batchCode.trim()) {
        return b;
      }
    }

    // ✅ Strategy 3: Case-insensitive match
    for (var b in allBatches) {
      if (b.batchCode!.toLowerCase() == batchCode.toLowerCase()) {
        return b;
      }
    }

    // ✅ Strategy 4: Remove special characters and compare
    String clean(String s) =>
        s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    for (var b in allBatches) {
      if (clean(b.batchCode!) == clean(batchCode)) {
        return b;
      }
    }

    // ✅ Strategy 5: Contains match (if one is substring of the other)
    for (var b in allBatches) {
      if (b.batchCode!.contains(batchCode) ||
          batchCode.contains(b.batchCode!)) {
        return b;
      }
    }

    return null;
  }

// PULL BatchUnits from server
  Future<void> _fetchAndSyncBatchUnits() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/batch_unit_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        // ✅ Handle different response formats
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          if (decoded.containsKey('batchCode') ||
              decoded.containsKey('units')) {
            data = [decoded];
          } else if (decoded.containsKey('message')) {
            return;
          } else {
            data = decoded.entries
                .where((e) => e.value is Map)
                .map((e) => e.value)
                .toList();
          }
        } else {
          return;
        }

        if (data.isEmpty) {
          return;
        }

        final productBatchBox = Hive.box<ProductBatch>('product_batches');
        final batchUnitBox = Hive.box<BatchUnit>('batch_units');

        for (var item in data) {
          if (item is! Map) {
            continue;
          }

          final Map<String, dynamic> json = Map<String, dynamic>.from(item);

          // =========================================================
          // 🔹 CRITICAL FIX: Extract BATCH CODE (not unitBatchCode)
          // =========================================================

          // ✅ The server sends a "batchCode" field, but it's actually the unitBatchCode!
          // We need to find the real batchCode from the response.
          String? realBatchCode;

          // ✅ Option 1: Try to get a real batch code from the first unit
          if (json.containsKey('units') && json['units'] is List) {
            final unitsList = json['units'] as List;
            if (unitsList.isNotEmpty && unitsList[0] is Map) {
              final firstUnit = unitsList[0] as Map;
              // ✅ The unit might have a parent batch reference
              if (firstUnit.containsKey('batchCode')) {
                realBatchCode = firstUnit['batchCode'].toString();
              }
              // ✅ Or the unit might have a unitBatchCode that we can use to find the parent
              else if (firstUnit.containsKey('unitBatchCode')) {
                final unitBatchCode = firstUnit['unitBatchCode'].toString();
                // Search for ProductBatch that contains this unitBatchCode
                for (var batch in productBatchBox.values) {
                  if (batch.units != null) {
                    for (var u in batch.units!) {
                      if (u.unitBatchCode == unitBatchCode) {
                        realBatchCode = batch.batchCode;
                        break;
                      }
                    }
                  }
                  if (realBatchCode != null) break;
                }
              }
            }
          }

          // ✅ Option 2: Check if there's a parent reference in the server data
          if (realBatchCode == null && json.containsKey('parentBatchCode')) {
            realBatchCode = json['parentBatchCode'].toString();
          }

          // ✅ Option 3: If we still don't have a real batchCode, use the server's batchCode
          // but we need to match it properly
          if (realBatchCode == null && json.containsKey('batchCode')) {
            final serverBatchCode = json['batchCode'].toString();

            // ✅ Check if this is actually a unitBatchCode by looking at the pattern
            // UUID pattern: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
            final uuidPattern = RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
            final isUuid = uuidPattern.hasMatch(serverBatchCode);

            if (isUuid) {
              // This is likely a unitBatchCode, search for the parent ProductBatch
              for (var batch in productBatchBox.values) {
                if (batch.units != null) {
                  for (var u in batch.units!) {
                    if (u.unitBatchCode == serverBatchCode) {
                      realBatchCode = batch.batchCode;
                      break;
                    }
                  }
                }
                if (realBatchCode != null) break;
              }
            } else {
              // Not a UUID, use it as the batchCode
              realBatchCode = serverBatchCode;
            }
          }

          // ✅ If we still don't have a batchCode, we need to create or find one
          if (realBatchCode == null) {
            realBatchCode = json['batchCode']?.toString() ?? 'UNKNOWN';
          }

          // =========================================================
          // 🔹 Find or Create ProductBatch using REAL batchCode
          // =========================================================

          // ✅ Find ProductBatch using improved method
          ProductBatch? existing =
              await _findProductBatch(realBatchCode, productBatchBox);

          // ✅ If ProductBatch doesn't exist, CREATE IT
          if (existing == null) {
            final newBatch = ProductBatch(
              batchCode: realBatchCode,
              productCode: json['productCode']?.toString() ?? 'UNKNOWN',
              reference: json['reference']?.toString() ?? 'Synced from server',
              baseUnitType:
                  _parseStockUnitType(json['baseUnitType']?.toString()),
              baseUnit: json['baseUnit']?.toString() ?? 'pcs',
              baseUnitSize: (json['baseUnitSize'] ?? 1).toDouble(),
              purchaseDate: DateTime.tryParse(json['purchaseDate'] ?? '') ??
                  DateTime.now(),
              createdAt: DateTime.now(),
              lastModified: DateTime.now(),
              syncStatus: true,
              operationType: 'none',
              modifiedFields: [],
              units: [],
              totalBaseUnits: 0,
              remainingBaseUnits: 0,
              totalBuyingCost: 0,
            );

            await productBatchBox.add(newBatch);

            existing = await _findProductBatch(realBatchCode, productBatchBox);

            if (existing == null) {
              continue;
            }
          } else {}

          // =========================================================
          // 🔹 BUILD BatchUnits
          // =========================================================

          List<BatchUnit> builtUnits = [];

          // ================================
          // ✅ CASE 1: Nested units array
          // ================================
          if (json.containsKey('units') && json['units'] is List) {
            final List unitsList = json['units'];

            for (var u in unitsList) {
              if (u is! Map) {
                continue;
              }

              final unitJson = Map<String, dynamic>.from(u);

              // ✅ Convert syncStatus from int to bool
              bool syncStatus = true;
              if (unitJson['syncStatus'] != null) {
                if (unitJson['syncStatus'] is int) {
                  syncStatus = unitJson['syncStatus'] == 1;
                } else if (unitJson['syncStatus'] is bool) {
                  syncStatus = unitJson['syncStatus'];
                } else if (unitJson['syncStatus'] is String) {
                  syncStatus = unitJson['syncStatus'] == '1' ||
                      unitJson['syncStatus'].toLowerCase() == 'true';
                }
              }

              // ✅ Parse modifiedFields
              List<String> modifiedFields =
                  _decodeToList(unitJson['modifiedFields']);

              // ✅ Parse lastModified
              DateTime? lastModified;
              if (unitJson['lastModified'] != null) {
                try {
                  if (unitJson['lastModified'] is String) {
                    lastModified = DateTime.parse(unitJson['lastModified']);
                  }
                } catch (e) {
                  lastModified = DateTime.now();
                }
              }

              // ✅ Parse unitBatchCode
              String? unitBatchCode;
              if (unitJson['unitBatchCode'] != null) {
                unitBatchCode = unitJson['unitBatchCode'].toString();
              }

              final BatchUnit unit = BatchUnit(
                level: _parsePackagingLevel(unitJson['level']?.toString()),
                unitsPerPackage: (unitJson['unitsPerPackage'] ?? 0).toDouble(),
                quantity: (unitJson['quantity'] ?? 0).toInt(),
                buyingPrice: (unitJson['buyingPrice'] ?? 0).toDouble(),
                unitBatchCode: unitBatchCode,
                syncStatus: syncStatus,
                lastModified: lastModified,
                operationType: unitJson['operationType']?.toString() ?? 'none',
                modifiedFields: modifiedFields,
              );

              builtUnits.add(unit);

              // ✅ Save each BatchUnit to batch_units box
              try {
                var existingUnit = batchUnitBox.values
                    .where((bu) => bu.unitBatchCode == unit.unitBatchCode)
                    .firstOrNull;

                if (existingUnit != null) {
                  existingUnit
                    ..level = unit.level
                    ..unitsPerPackage = unit.unitsPerPackage
                    ..quantity = unit.quantity
                    ..buyingPrice = unit.buyingPrice
                    ..syncStatus = syncStatus
                    ..lastModified = lastModified ?? DateTime.now()
                    ..operationType = 'none'
                    ..modifiedFields = [];
                  await existingUnit.save();
                } else {
                  await batchUnitBox.add(unit);
                }
              } catch (e) {
                print('❌ Error saving BatchUnit to batch_units box: $e');
              }
            }
          }

          // ================================
          // ✅ CASE 2: Flat single unit
          // ================================
          else {
            print('Processing flat unit');

            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (json['syncStatus'] != null) {
              if (json['syncStatus'] is int) {
                syncStatus = json['syncStatus'] == 1;
              } else if (json['syncStatus'] is bool) {
                syncStatus = json['syncStatus'];
              }
            }

            // ✅ Parse modifiedFields
            List<String> modifiedFields = _decodeToList(json['modifiedFields']);

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (json['lastModified'] != null) {
              try {
                if (json['lastModified'] is String) {
                  lastModified = DateTime.parse(json['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            // ✅ Parse unitBatchCode
            String? unitBatchCode;
            if (json['unitBatchCode'] != null) {
              unitBatchCode = json['unitBatchCode'].toString();
            }

            final BatchUnit unit = BatchUnit(
              level: _parsePackagingLevel(json['level']?.toString()),
              unitsPerPackage: (json['unitsPerPackage'] ?? 0).toDouble(),
              quantity: (json['quantity'] ?? 0).toInt(),
              buyingPrice: (json['buyingPrice'] ?? 0).toDouble(),
              unitBatchCode: unitBatchCode,
              syncStatus: syncStatus,
              lastModified: lastModified,
              operationType: json['operationType']?.toString() ?? 'none',
              modifiedFields: modifiedFields,
            );

            builtUnits.add(unit);
            print('Added flat unit with unitBatchCode: ${unit.unitBatchCode}');

            // ✅ Save each BatchUnit to batch_units box
            try {
              var existingUnit = batchUnitBox.values
                  .where((bu) => bu.unitBatchCode == unit.unitBatchCode)
                  .firstOrNull;

              if (existingUnit != null) {
                existingUnit
                  ..level = unit.level
                  ..unitsPerPackage = unit.unitsPerPackage
                  ..quantity = unit.quantity
                  ..buyingPrice = unit.buyingPrice
                  ..syncStatus = syncStatus
                  ..lastModified = lastModified ?? DateTime.now()
                  ..operationType = 'none'
                  ..modifiedFields = [];
                await existingUnit.save();
                print(
                    '✅ Updated BatchUnit in batch_units box: ${existingUnit.unitBatchCode}');
              } else {
                await batchUnitBox.add(unit);
                print(
                    '✅ Added BatchUnit to batch_units box: ${unit.unitBatchCode}');
              }
            } catch (e) {
              print('❌ Error saving BatchUnit to batch_units box: $e');
            }
          }

          // =========================================================
          // 🔄 UPDATE EXISTING ProductBatch
          // =========================================================

          print(
              'Updating ProductBatch "${existing.batchCode}" with ${builtUnits.length} units');

          // ✅ Update batch properties if provided
          if (json.containsKey('productCode')) {
            existing.productCode = json['productCode']?.toString();
          }
          if (json.containsKey('reference')) {
            existing.reference = json['reference']?.toString();
          }
          if (json.containsKey('baseUnitType')) {
            existing.baseUnitType =
                _parseStockUnitType(json['baseUnitType']?.toString());
          }
          if (json.containsKey('baseUnit')) {
            existing.baseUnit = json['baseUnit']?.toString();
          }
          if (json.containsKey('baseUnitSize')) {
            existing.baseUnitSize = (json['baseUnitSize'] ?? 1).toDouble();
          }
          if (json.containsKey('purchaseDate')) {
            existing.purchaseDate =
                DateTime.tryParse(json['purchaseDate'] ?? '') ?? DateTime.now();
          }

          existing
            ..units = builtUnits
            ..syncStatus = true
            ..operationType = 'none'
            ..lastModified = DateTime.now()
            ..modifiedFields = [];

          // ✅ Calculate totals
          double totalUnits = 0;
          double totalCost = 0;
          for (var u in builtUnits) {
            totalUnits += u.unitsPerPackage * u.quantity;
            totalCost += u.buyingPrice * u.quantity;
          }
          existing.totalBaseUnits = totalUnits;
          existing.remainingBaseUnits = totalUnits;
          existing.totalBuyingCost = totalCost;

          await existing.save();
          print(
              '✅ ProductBatch "${existing.batchCode}" saved with ${existing.units!.length} units');
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('BatchUnits synced successfully')));
      } else {
        print('❌ Failed to fetch BatchUnits. Status: ${response.statusCode}');
        print('❌ Response: ${response.body}');
        throw Exception(
            'Failed to fetch BatchUnits. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching/syncing BatchUnits: $e');
      print('Stack Trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing BatchUnits: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
      print('=== _fetchAndSyncBatchUnits END ===');
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

  // PULL Classes from server (with deletion awareness)
  Future<void> _fetchAndSyncClasses() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/classes.php?include_deleted=true';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> classes = jsonDecode(response.body);

        if (classes.isEmpty) {
          print('No classes found on server');
          return;
        }

        for (var classData in classes) {
          // ✅ Parse isDeleted from server
          bool isDeleted = false;
          if (classData['isDeleted'] != null) {
            if (classData['isDeleted'] is int) {
              isDeleted = classData['isDeleted'] == 1;
            } else if (classData['isDeleted'] is bool) {
              isDeleted = classData['isDeleted'];
            }
          }

          // ✅ Parse deletedSyncStatus
          bool deletedSyncStatus = false;
          if (classData['deletedSyncStatus'] != null) {
            if (classData['deletedSyncStatus'] is int) {
              deletedSyncStatus = classData['deletedSyncStatus'] == 1;
            } else if (classData['deletedSyncStatus'] is bool) {
              deletedSyncStatus = classData['deletedSyncStatus'];
            }
          }

          // ✅ Parse deletedAt
          DateTime? deletedAt;
          if (classData['deletedAt'] != null) {
            try {
              deletedAt = DateTime.parse(classData['deletedAt']);
            } catch (e) {
              deletedAt = null;
            }
          }

          // Parse existing fields
          DateTime parsedDate;
          if (classData['date'] != null) {
            try {
              parsedDate = DateTime.parse(classData['date']);
            } catch (e) {
              parsedDate = DateTime.now();
            }
          } else {
            parsedDate = DateTime.now();
          }

          bool syncStatus = true;
          if (classData['syncStatus'] != null) {
            if (classData['syncStatus'] is int) {
              syncStatus = classData['syncStatus'] == 1;
            } else if (classData['syncStatus'] is bool) {
              syncStatus = classData['syncStatus'];
            }
          }

          List<String> terms = [];
          if (classData['terms'] != null) {
            if (classData['terms'] is List) {
              terms = (classData['terms'] as List)
                  .map((e) => e.toString())
                  .toList();
            } else if (classData['terms'] is String) {
              try {
                final decoded = jsonDecode(classData['terms']);
                if (decoded is List) {
                  terms = decoded.map((e) => e.toString()).toList();
                }
              } catch (e) {
                terms = [];
              }
            }
          }

          int? id;
          if (classData['id'] != null) {
            id = classData['id'] is int
                ? classData['id']
                : int.tryParse(classData['id'].toString());
          } else if (classData['fid'] != null) {
            id = classData['fid'] is int
                ? classData['fid']
                : int.tryParse(classData['fid'].toString());
          }

          DateTime? lastModified;
          try {
            if (classData['lastModified'] != null) {
              lastModified = DateTime.parse(classData['lastModified']);
            }
          } catch (e) {
            lastModified = DateTime.now();
          }

          Classes fetchedClass = Classes(
            id: id ?? 0,
            classCode: classData['classCode'] ?? '',
            className: classData['className'] ?? '',
            date: parsedDate,
            termId: classData['termId'],
            terms: terms,
            syncStatus: syncStatus,
            operationType: 'none',
            lastModified: lastModified,
            modifiedFields: [],
            // ✅ Deletion fields
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            deletedBy: classData['deletedBy'],
            deleteReason: classData['deleteReason'],
            deletedSyncStatus: deletedSyncStatus,
          );

          // Check if class exists in Hive
          var existingClassList = _classesBox!.values
              .where((classObj) => classObj.classCode == fetchedClass.classCode)
              .toList();

          if (existingClassList.isNotEmpty) {
            var existingClass = existingClassList.first;
            existingClass
              ..id = fetchedClass.id
              ..classCode = fetchedClass.classCode
              ..className = fetchedClass.className
              ..date = fetchedClass.date
              ..termId = fetchedClass.termId
              ..terms = fetchedClass.terms
              ..isDeleted = fetchedClass.isDeleted
              ..deletedAt = fetchedClass.deletedAt
              ..deletedBy = fetchedClass.deletedBy
              ..deleteReason = fetchedClass.deleteReason
              ..deletedSyncStatus = fetchedClass.deletedSyncStatus
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now();

            await existingClass.save();
            print('Class ${fetchedClass.classCode} updated in Hive.');
          } else {
            await _classesBox!.add(fetchedClass);
            print('Class ${fetchedClass.classCode} added to Hive.');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch classes. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing classes: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing classes: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
//================================pull _fetchAndSyncPurposes =======================================================================//

  //================================pull _fetchAndSyncPurposes =======================================================================//

  Future<void> _fetchAndSyncPurposes() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        // ✅ Handle both List and Map responses
        List<dynamic> purposes;
        if (decoded is List) {
          purposes = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format: $decoded');
          return;
        }

        if (purposes.isEmpty) {
          print('No payment purposes found on server');
          return;
        }

        for (var purposeData in purposes) {
          try {
            print('Processing purpose data: $purposeData');

            // ✅ FIX: Safely convert all values
            // Handle purposeCode - could be String or int
            String? purposeCode;
            if (purposeData['purposeCode'] != null) {
              if (purposeData['purposeCode'] is String) {
                purposeCode = purposeData['purposeCode'];
              } else if (purposeData['purposeCode'] is int) {
                purposeCode = purposeData['purposeCode'].toString();
              } else if (purposeData['purposeCode'] is double) {
                purposeCode = purposeData['purposeCode'].toString();
              }
            }

            // ✅ If no purposeCode, use id or fid
            if (purposeCode == null || purposeCode.isEmpty) {
              if (purposeData['id'] != null) {
                purposeCode = purposeData['id'].toString();
              } else if (purposeData['fid'] != null) {
                purposeCode = purposeData['fid'].toString();
              }
            }

            // Skip if no purposeCode
            if (purposeCode == null || purposeCode.isEmpty) {
              print('Skipping purpose with no purposeCode');
              continue;
            }

            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (purposeData['syncStatus'] != null) {
              if (purposeData['syncStatus'] is int) {
                syncStatus = purposeData['syncStatus'] == 1;
              } else if (purposeData['syncStatus'] is bool) {
                syncStatus = purposeData['syncStatus'];
              } else if (purposeData['syncStatus'] is String) {
                syncStatus = purposeData['syncStatus'] == '1' ||
                    purposeData['syncStatus'].toLowerCase() == 'true';
              }
            }

            // ✅ Convert forNewcomersOnly from int to bool
            bool forNewcomersOnly = false;
            if (purposeData['forNewcomersOnly'] != null) {
              if (purposeData['forNewcomersOnly'] is int) {
                forNewcomersOnly = purposeData['forNewcomersOnly'] == 1;
              } else if (purposeData['forNewcomersOnly'] is bool) {
                forNewcomersOnly = purposeData['forNewcomersOnly'];
              } else if (purposeData['forNewcomersOnly'] is String) {
                forNewcomersOnly = purposeData['forNewcomersOnly'] == '1' ||
                    purposeData['forNewcomersOnly'].toLowerCase() == 'true';
              }
            }

            // ✅ Parse associatedClasses - handles List or String
            List<String> associatedClasses =
                _decodeToList(purposeData['associatedClasses']);

            // ✅ Parse exceptions - handles List or String
            List<ExceptionalStudents>? exceptions;
            if (purposeData['exceptions'] != null) {
              exceptions = _decodeExceptions(purposeData['exceptions']);
            }

            // ✅ Handle id mapping - safely convert to int
            int? id;
            if (purposeData['id'] != null) {
              if (purposeData['id'] is int) {
                id = purposeData['id'];
              } else if (purposeData['id'] is String) {
                id = int.tryParse(purposeData['id']);
              } else if (purposeData['id'] is double) {
                id = purposeData['id'].toInt();
              }
            }
            if (id == null && purposeData['fid'] != null) {
              if (purposeData['fid'] is int) {
                id = purposeData['fid'];
              } else if (purposeData['fid'] is String) {
                id = int.tryParse(purposeData['fid']);
              } else if (purposeData['fid'] is double) {
                id = purposeData['fid'].toInt();
              }
            }

            // ✅ Parse purposeAmount - safely convert to double
            double purposeAmount = 0.0;
            if (purposeData['purposeAmount'] != null) {
              if (purposeData['purposeAmount'] is double) {
                purposeAmount = purposeData['purposeAmount'];
              } else if (purposeData['purposeAmount'] is int) {
                purposeAmount = purposeData['purposeAmount'].toDouble();
              } else if (purposeData['purposeAmount'] is String) {
                purposeAmount =
                    double.tryParse(purposeData['purposeAmount']) ?? 0.0;
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (purposeData['lastModified'] != null) {
              try {
                if (purposeData['lastModified'] is String) {
                  lastModified = DateTime.parse(purposeData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            PaymentPurpose fetchedPurpose = PaymentPurpose(
              id: id ?? 0,
              purposeCode: purposeCode,
              paymentPurpose: purposeData['paymentPurpose']?.toString() ?? '',
              purposeAmount: purposeAmount,
              termId: purposeData['termId']?.toString(),
              associatedClasses: associatedClasses,
              exceptions: exceptions,
              forNewcomersOnly: forNewcomersOnly,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: [],
            );

            // Check if purpose exists in Hive
            var existingPurposeList = _payment_purposesBox!.values
                .where((purpose) =>
                    purpose.purposeCode == fetchedPurpose.purposeCode)
                .toList();

            if (existingPurposeList.isNotEmpty) {
              // Update existing purpose
              var existingPurpose = existingPurposeList.first;
              existingPurpose
                ..id = fetchedPurpose.id
                ..purposeCode = fetchedPurpose.purposeCode
                ..paymentPurpose = fetchedPurpose.paymentPurpose
                ..purposeAmount = fetchedPurpose.purposeAmount
                ..termId = fetchedPurpose.termId
                ..associatedClasses = fetchedPurpose.associatedClasses
                ..exceptions = fetchedPurpose.exceptions
                ..forNewcomersOnly = fetchedPurpose.forNewcomersOnly
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingPurpose.save();
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} updated in Hive.');
            } else {
              // Create new purpose
              await _payment_purposesBox!.add(fetchedPurpose);
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing purpose record:');
            print('Data: ${purposeData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Synced ${purposes.length} payment purposes from server')));
      } else {
        throw Exception(
            'Failed to fetch payment purposes. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing PaymentPurpose: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing payment purposes: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncSchools =======================================================================//
// ✅ UPDATED: Fetch and sync schools (with deletion awareness)
  Future<void> _fetchAndSyncSchools() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?include_deleted=true';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> schools = jsonDecode(response.body);

        if (schools.isEmpty) {
          print('No schools found on server');
          return;
        }

        for (var schoolData in schools) {
          // ✅ Parse isDeleted from server
          bool isDeleted = false;
          if (schoolData['isDeleted'] != null) {
            if (schoolData['isDeleted'] is int) {
              isDeleted = schoolData['isDeleted'] == 1;
            } else if (schoolData['isDeleted'] is bool) {
              isDeleted = schoolData['isDeleted'];
            }
          }

          // ✅ Parse deletedSyncStatus
          bool deletedSyncStatus = false;
          if (schoolData['deletedSyncStatus'] != null) {
            if (schoolData['deletedSyncStatus'] is int) {
              deletedSyncStatus = schoolData['deletedSyncStatus'] == 1;
            } else if (schoolData['deletedSyncStatus'] is bool) {
              deletedSyncStatus = schoolData['deletedSyncStatus'];
            }
          }

          // ✅ Parse deletedAt
          DateTime? deletedAt;
          if (schoolData['deletedAt'] != null) {
            try {
              deletedAt = DateTime.parse(schoolData['deletedAt']);
            } catch (e) {
              deletedAt = null;
            }
          }

          // Parse other fields...
          int? id = schoolData['id'] ?? int.tryParse(schoolData['fid'] ?? '0');
          bool syncStatus = schoolData['syncStatus'] == 1;

          School fetchedSchool = School(
            id: id,
            schoolCode: schoolData['schoolCode'] ?? '',
            schoolName: schoolData['schoolName'],
            schoolAddress: schoolData['schoolAddress'],
            schoolPhoneNumber: schoolData['schoolPhoneNumber'],
            schoolEmail: schoolData['schoolEmail'],
            schoolLogoPath: schoolData['schoolLogoPath'],
            termId: schoolData['termId'],
            syncStatus: syncStatus,
            operationType: 'none',
            lastModified: DateTime.tryParse(schoolData['lastModified'] ?? ''),
            modifiedFields: [],
            // ✅ Deletion fields
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            deletedBy: schoolData['deletedBy'],
            deleteReason: schoolData['deleteReason'],
            deletedSyncStatus: deletedSyncStatus,
          );

          // Check if school exists in Hive
          var existingSchools = _schoolBox!.values
              .where((school) => school.schoolCode == fetchedSchool.schoolCode)
              .toList();

          if (existingSchools.isNotEmpty) {
            // Update existing school
            var existingSchool = existingSchools.first;
            existingSchool
              ..id = fetchedSchool.id
              ..schoolCode = fetchedSchool.schoolCode
              ..schoolName = fetchedSchool.schoolName
              ..schoolAddress = fetchedSchool.schoolAddress
              ..schoolPhoneNumber = fetchedSchool.schoolPhoneNumber
              ..schoolEmail = fetchedSchool.schoolEmail
              ..schoolLogoPath = fetchedSchool.schoolLogoPath
              ..termId = fetchedSchool.termId
              ..isDeleted = fetchedSchool.isDeleted
              ..deletedAt = fetchedSchool.deletedAt
              ..deletedBy = fetchedSchool.deletedBy
              ..deleteReason = fetchedSchool.deleteReason
              ..deletedSyncStatus = fetchedSchool.deletedSyncStatus
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now()
              ..modifiedFields = [];

            await existingSchool.save();
            print('School ${fetchedSchool.schoolCode} updated in Hive.');
          } else {
            // Create new school
            await _schoolBox!.add(fetchedSchool);
            print('School ${fetchedSchool.schoolCode} added to Hive.');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${schools.length} schools from server')));
      } else {
        throw Exception(
            'Failed to fetch schools. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing schools: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing schools: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncStudentPayments =======================================================================//

// PULL StudentPayments from server
  Future<void> _fetchAndSyncStudentPayments() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        List<dynamic> studentPayments;
        if (decoded is List) {
          studentPayments = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format');
          return;
        }

        if (studentPayments.isEmpty) {
          print('No student payments found on server');
          return;
        }

        for (var paymentsData in studentPayments) {
          try {
            // ✅ Debug paymentDate
            debugPrint(
                'Raw paymentDate received: ${paymentsData['paymentDate']}');

            // ✅ Parse paymentDate safely
            DateTime paymentDate;
            if (paymentsData['paymentDate'] != null) {
              try {
                if (paymentsData['paymentDate'] is String) {
                  paymentDate = DateTime.parse(paymentsData['paymentDate']);
                } else {
                  paymentDate = DateTime.now();
                }
              } catch (e) {
                paymentDate = DateTime.now();
              }
            } else {
              paymentDate = DateTime.now();
            }

            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (paymentsData['syncStatus'] != null) {
              if (paymentsData['syncStatus'] is int) {
                syncStatus = paymentsData['syncStatus'] == 1;
              } else if (paymentsData['syncStatus'] is bool) {
                syncStatus = paymentsData['syncStatus'];
              }
            }

            // ✅ Handle id mapping
            int? id;
            if (paymentsData['id'] != null) {
              if (paymentsData['id'] is int) {
                id = paymentsData['id'];
              } else if (paymentsData['id'] is String) {
                id = int.tryParse(paymentsData['id']);
              }
            }
            if (id == null && paymentsData['fid'] != null) {
              if (paymentsData['fid'] is int) {
                id = paymentsData['fid'];
              } else if (paymentsData['fid'] is String) {
                id = int.tryParse(paymentsData['fid']);
              }
            }

            // ✅ Parse amountToPay safely
            double amountToPay = 0.0;
            if (paymentsData['amountToPay'] != null) {
              if (paymentsData['amountToPay'] is double) {
                amountToPay = paymentsData['amountToPay'];
              } else if (paymentsData['amountToPay'] is int) {
                amountToPay = paymentsData['amountToPay'].toDouble();
              } else if (paymentsData['amountToPay'] is String) {
                amountToPay =
                    double.tryParse(paymentsData['amountToPay']) ?? 0.0;
              }
            }

            // ✅ Parse paymentMethodAmount safely
            double paymentMethodAmount = 0.0;
            if (paymentsData['paymentMethodAmount'] != null) {
              if (paymentsData['paymentMethodAmount'] is double) {
                paymentMethodAmount = paymentsData['paymentMethodAmount'];
              } else if (paymentsData['paymentMethodAmount'] is int) {
                paymentMethodAmount =
                    paymentsData['paymentMethodAmount'].toDouble();
              } else if (paymentsData['paymentMethodAmount'] is String) {
                paymentMethodAmount =
                    double.tryParse(paymentsData['paymentMethodAmount']) ?? 0.0;
              }
            }

            // ✅ Parse changeGiven safely
            double changeGiven = 0.0;
            if (paymentsData['changeGiven'] != null) {
              if (paymentsData['changeGiven'] is double) {
                changeGiven = paymentsData['changeGiven'];
              } else if (paymentsData['changeGiven'] is int) {
                changeGiven = paymentsData['changeGiven'].toDouble();
              } else if (paymentsData['changeGiven'] is String) {
                changeGiven =
                    double.tryParse(paymentsData['changeGiven']) ?? 0.0;
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (paymentsData['lastModified'] != null) {
              try {
                if (paymentsData['lastModified'] is String) {
                  lastModified = DateTime.parse(paymentsData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            StudentPayment fetchedPayment = StudentPayment(
              id: id ?? 0,
              studentName: paymentsData['studentName']?.toString() ?? '',
              studentSurname: paymentsData['studentSurname']?.toString() ?? '',
              studentClass: paymentsData['studentClass']?.toString() ?? '',
              studentRegNumber: paymentsData['studentRegNumber']?.toString(),
              phoneNumber: paymentsData['phoneNumber']?.toString() ?? '',
              paymentPurpose: paymentsData['paymentPurpose']?.toString() ?? '',
              amountToPay: amountToPay,
              paymentDate: paymentDate,
              receiptNumber: paymentsData['receiptNumber']?.toString() ?? '',
              termId: paymentsData['termId']?.toString(),
              username: paymentsData['username']?.toString(),
              role: paymentsData['role']?.toString(),
              paymentMethodType:
                  paymentsData['paymentMethodType']?.toString() ?? 'cash',
              paymentMethodAmount: paymentMethodAmount,
              paymentReference:
                  paymentsData['paymentReference']?.toString() ?? '',
              mobileMoneyPhone:
                  paymentsData['mobileMoneyPhone']?.toString() ?? '',
              mobileMoneyProvider:
                  paymentsData['mobileMoneyProvider']?.toString() ?? '',
              bankAccountNumber:
                  paymentsData['bankAccountNumber']?.toString() ?? '',
              bankAccountName:
                  paymentsData['bankAccountName']?.toString() ?? '',
              changeGiven: changeGiven,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: [],
            );

            // Check if payment exists in Hive
            var existingPaymentList = _student_paymentsBox!.values
                .where((payment) =>
                    payment.receiptNumber == fetchedPayment.receiptNumber)
                .toList();

            if (existingPaymentList.isNotEmpty) {
              // Update existing payment
              var existingPayment = existingPaymentList.first;
              existingPayment
                ..id = fetchedPayment.id
                ..studentName = fetchedPayment.studentName
                ..studentSurname = fetchedPayment.studentSurname
                ..studentClass = fetchedPayment.studentClass
                ..studentRegNumber = fetchedPayment.studentRegNumber
                ..phoneNumber = fetchedPayment.phoneNumber
                ..paymentPurpose = fetchedPayment.paymentPurpose
                ..amountToPay = fetchedPayment.amountToPay
                ..paymentDate = fetchedPayment.paymentDate
                ..receiptNumber = fetchedPayment.receiptNumber
                ..termId = fetchedPayment.termId
                ..username = fetchedPayment.username
                ..role = fetchedPayment.role
                ..paymentMethodType = fetchedPayment.paymentMethodType
                ..paymentMethodAmount = fetchedPayment.paymentMethodAmount
                ..paymentReference = fetchedPayment.paymentReference
                ..mobileMoneyPhone = fetchedPayment.mobileMoneyPhone
                ..mobileMoneyProvider = fetchedPayment.mobileMoneyProvider
                ..bankAccountNumber = fetchedPayment.bankAccountNumber
                ..bankAccountName = fetchedPayment.bankAccountName
                ..changeGiven = fetchedPayment.changeGiven
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingPayment.save();
              print(
                  'StudentPayment ${fetchedPayment.receiptNumber} updated in Hive.');
            } else {
              // Create new payment
              await _student_paymentsBox!.add(fetchedPayment);
              print(
                  'StudentPayment ${fetchedPayment.receiptNumber} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing payment record:');
            print('Data: ${paymentsData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Synced ${studentPayments.length} payments from server')));
      } else {
        throw Exception(
            'Failed to fetch payments. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing StudentPayment: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing payments: $e')));
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

  // PULL Students from server
  // PULL Students from server with deletion awareness
  Future<void> _fetchAndSyncStudents() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?include_deleted=true';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> students = jsonDecode(response.body);

        if (students.isEmpty) {
          print('No students found on server');
          return;
        }

        for (var studentData in students) {
          try {
            // ✅ Parse isDeleted from server
            bool isDeleted = false;
            if (studentData['isDeleted'] != null) {
              if (studentData['isDeleted'] is int) {
                isDeleted = studentData['isDeleted'] == 1;
              } else if (studentData['isDeleted'] is bool) {
                isDeleted = studentData['isDeleted'];
              }
            }

            // ✅ Parse deletedSyncStatus
            bool deletedSyncStatus = false;
            if (studentData['deletedSyncStatus'] != null) {
              if (studentData['deletedSyncStatus'] is int) {
                deletedSyncStatus = studentData['deletedSyncStatus'] == 1;
              } else if (studentData['deletedSyncStatus'] is bool) {
                deletedSyncStatus = studentData['deletedSyncStatus'];
              }
            }

            // ✅ Parse deletedAt
            DateTime? deletedAt;
            if (studentData['deletedAt'] != null) {
              try {
                deletedAt = DateTime.parse(studentData['deletedAt']);
              } catch (e) {
                deletedAt = null;
              }
            }

            // Parse existing fields...
            DateTime age;
            if (studentData['age'] != null) {
              try {
                age = DateTime.parse(studentData['age']);
              } catch (e) {
                age = DateTime.now();
              }
            } else {
              age = DateTime.now();
            }

            bool isPresent = true;
            if (studentData['isPresent'] != null) {
              if (studentData['isPresent'] is int) {
                isPresent = studentData['isPresent'] == 1;
              } else if (studentData['isPresent'] is bool) {
                isPresent = studentData['isPresent'];
              }
            }

            bool syncStatus = true;
            if (studentData['syncStatus'] != null) {
              if (studentData['syncStatus'] is int) {
                syncStatus = studentData['syncStatus'] == 1;
              } else if (studentData['syncStatus'] is bool) {
                syncStatus = studentData['syncStatus'];
              }
            }

            bool isNewComer = false;
            if (studentData['isNewComer'] != null) {
              if (studentData['isNewComer'] is int) {
                isNewComer = studentData['isNewComer'] == 1;
              } else if (studentData['isNewComer'] is bool) {
                isNewComer = studentData['isNewComer'];
              }
            }

            int? id;
            if (studentData['id'] != null) {
              id = studentData['id'] is int
                  ? studentData['id']
                  : int.tryParse(studentData['id'].toString());
            } else if (studentData['fid'] != null) {
              id = studentData['fid'] is int
                  ? studentData['fid']
                  : int.tryParse(studentData['fid'].toString());
            }

            List<DateTime> presentDates =
                _parseDateList(studentData['presentDates']);
            List<DateTime> absentDates =
                _parseDateList(studentData['absentDates']);
            List<String> terms = _decodeToList(studentData['terms']);
            List<ExceptionalStudents>? exceptions;
            if (studentData['exceptions'] != null) {
              exceptions = _decodeExceptions(studentData['exceptions']);
            }

            Student fetchedStudent = Student(
              id: id ?? 0,
              name: studentData['name'] ?? '',
              surname: studentData['surname'] ?? '',
              regNumber: studentData['regNumber'] ?? '',
              class_: studentData['class'] ?? studentData['class_'] ?? '',
              gender: studentData['gender'] ?? '',
              age: age,
              phoneNumber: studentData['phoneNumber'] ?? '',
              paymentStatus: studentData['paymentStatus'] ?? '',
              isPresent: isPresent,
              presentDates: presentDates,
              absentDates: absentDates,
              termId: studentData['termId'],
              physicalAddress: studentData['physicalAddress'],
              formerSchool: studentData['formerSchool'],
              religion: studentData['religion'],
              denomination: studentData['denomination'],
              studentIdNumber: studentData['studentIdNumber'] ?? '',
              nationalIdNumber: studentData['nationalIdNumber'],
              nationality: studentData['nationality'],
              district: studentData['district'],
              previousSchoolPerformanceResults:
                  studentData['previousSchoolPerformanceResults'],
              enrollmentStatus: studentData['enrollmentStatus'],
              emergencyContactName: studentData['emergencyContactName'],
              emergencyContactNumber: studentData['emergencyContactNumber'],
              healthStauts: studentData['healthStatus'],
              healthDetailedInformation:
                  studentData['healthDetailedInformation'],
              terms: terms,
              exceptions: exceptions,
              isNewComer: isNewComer,
              isNewComerFrom: studentData['isNewComerFrom'] != null
                  ? DateTime.tryParse(studentData['isNewComerFrom'])
                  : null,
              isNewComerUntil: studentData['isNewComerUntil'] != null
                  ? DateTime.tryParse(studentData['isNewComerUntil'])
                  : null,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: studentData['lastModified'] != null
                  ? DateTime.tryParse(studentData['lastModified'])
                  : DateTime.now(),
              modifiedFields: [],
              // ✅ Deletion fields
              isDeleted: isDeleted,
              deletedAt: deletedAt,
              deletedBy: studentData['deletedBy'],
              deleteReason: studentData['deleteReason'],
              deletedSyncStatus: deletedSyncStatus,
            );

            // Check if student exists in Hive
            var existingStudentsList = _studentsBox!.values
                .where((student) =>
                    student.studentIdNumber == fetchedStudent.studentIdNumber)
                .toList();

            if (existingStudentsList.isNotEmpty) {
              var existingStudent = existingStudentsList.first;
              existingStudent
                ..id = fetchedStudent.id
                ..name = fetchedStudent.name
                ..surname = fetchedStudent.surname
                ..regNumber = fetchedStudent.regNumber
                ..class_ = fetchedStudent.class_
                ..gender = fetchedStudent.gender
                ..age = fetchedStudent.age
                ..phoneNumber = fetchedStudent.phoneNumber
                ..paymentStatus = fetchedStudent.paymentStatus
                ..isPresent = fetchedStudent.isPresent
                ..presentDates = fetchedStudent.presentDates
                ..absentDates = fetchedStudent.absentDates
                ..termId = fetchedStudent.termId
                ..physicalAddress = fetchedStudent.physicalAddress
                ..formerSchool = fetchedStudent.formerSchool
                ..religion = fetchedStudent.religion
                ..denomination = fetchedStudent.denomination
                ..studentIdNumber = fetchedStudent.studentIdNumber
                ..nationalIdNumber = fetchedStudent.nationalIdNumber
                ..nationality = fetchedStudent.nationality
                ..district = fetchedStudent.district
                ..previousSchoolPerformanceResults =
                    fetchedStudent.previousSchoolPerformanceResults
                ..enrollmentStatus = fetchedStudent.enrollmentStatus
                ..emergencyContactName = fetchedStudent.emergencyContactName
                ..emergencyContactNumber = fetchedStudent.emergencyContactNumber
                ..healthStauts = fetchedStudent.healthStauts
                ..healthDetailedInformation =
                    fetchedStudent.healthDetailedInformation
                ..terms = fetchedStudent.terms
                ..exceptions = fetchedStudent.exceptions
                ..isNewComer = fetchedStudent.isNewComer
                ..isNewComerFrom = fetchedStudent.isNewComerFrom
                ..isNewComerUntil = fetchedStudent.isNewComerUntil
                ..isDeleted = fetchedStudent.isDeleted
                ..deletedAt = fetchedStudent.deletedAt
                ..deletedBy = fetchedStudent.deletedBy
                ..deleteReason = fetchedStudent.deleteReason
                ..deletedSyncStatus = fetchedStudent.deletedSyncStatus
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingStudent.save();
              print(
                  'Student ${fetchedStudent.studentIdNumber} updated in Hive.');
            } else {
              await _studentsBox!.add(fetchedStudent);
              print('Student ${fetchedStudent.studentIdNumber} added to Hive.');
            }
          } catch (error, stack) {
            debugPrint('❌ Error processing student record:\n'
                'Data: ${studentData.toString()}\n'
                'Error: $error\n'
                'Stack Trace: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${students.length} students from server')));
      } else {
        throw Exception(
            'Failed to fetch students. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing students: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing students: $e')));
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

// PULL TeacherPayments from server
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
          try {
            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (paymentsData['syncStatus'] != null) {
              if (paymentsData['syncStatus'] is int) {
                syncStatus = paymentsData['syncStatus'] == 1;
              } else if (paymentsData['syncStatus'] is bool) {
                syncStatus = paymentsData['syncStatus'];
              }
            }

            // ✅ Handle id mapping
            int? id;
            if (paymentsData['id'] != null) {
              if (paymentsData['id'] is int) {
                id = paymentsData['id'];
              } else if (paymentsData['id'] is String) {
                id = int.tryParse(paymentsData['id']);
              }
            }
            if (id == null && paymentsData['fid'] != null) {
              if (paymentsData['fid'] is int) {
                id = paymentsData['fid'];
              } else if (paymentsData['fid'] is String) {
                id = int.tryParse(paymentsData['fid']);
              }
            }

            // ✅ Parse amountToPay
            double amountToPay = 0.0;
            if (paymentsData['amountToPay'] != null) {
              if (paymentsData['amountToPay'] is double) {
                amountToPay = paymentsData['amountToPay'];
              } else if (paymentsData['amountToPay'] is int) {
                amountToPay = paymentsData['amountToPay'].toDouble();
              } else if (paymentsData['amountToPay'] is String) {
                amountToPay =
                    double.tryParse(paymentsData['amountToPay']) ?? 0.0;
              }
            }

            // ✅ Parse paymentDate
            DateTime paymentDate;
            if (paymentsData['paymentDate'] != null) {
              try {
                if (paymentsData['paymentDate'] is String) {
                  paymentDate = DateTime.parse(paymentsData['paymentDate']);
                } else {
                  paymentDate = DateTime.now();
                }
              } catch (e) {
                paymentDate = DateTime.now();
              }
            } else {
              paymentDate = DateTime.now();
            }

            // ✅ Parse receiptNumber - could be int or String
            String? receiptNumber;
            if (paymentsData['receiptNumber'] != null) {
              if (paymentsData['receiptNumber'] is String) {
                receiptNumber = paymentsData['receiptNumber'];
              } else if (paymentsData['receiptNumber'] is int) {
                receiptNumber = paymentsData['receiptNumber'].toString();
              }
            }

            // ✅ Parse associatedStaff
            List<String> associatedStaff =
                _decodeToList(paymentsData['associatedStaff']);

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (paymentsData['lastModified'] != null) {
              try {
                if (paymentsData['lastModified'] is String) {
                  lastModified = DateTime.parse(paymentsData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            TeacherPayment fetchedPayment = TeacherPayment(
              id: id ?? 0,
              receiptNumber: receiptNumber ??
                  'TCH_PAY_${DateTime.now().millisecondsSinceEpoch}',
              studentName: paymentsData['studentName']?.toString() ?? '',
              studentSurname: paymentsData['studentSurname']?.toString() ?? '',
              studentClass: paymentsData['studentClass']?.toString() ?? '',
              phoneNumber: paymentsData['phoneNumber']?.toString() ?? '',
              paymentPurpose: paymentsData['paymentPurpose']?.toString() ?? '',
              amountToPay: amountToPay,
              paymentDate: paymentDate,
              termId: paymentsData['termId']?.toString(),
              associatedStaff: associatedStaff,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: [],
            );

            // Check if payment exists in Hive
            var existingPaymentList = _teacher_paymentsBox!.values
                .where((payment) =>
                    payment.receiptNumber == fetchedPayment.receiptNumber)
                .toList();

            TeacherPayment? existingPayment = existingPaymentList.isNotEmpty
                ? existingPaymentList.first
                : null;

            if (existingPayment != null) {
              // Update existing payment
              existingPayment
                ..id = fetchedPayment.id
                ..receiptNumber = fetchedPayment.receiptNumber
                ..studentName = fetchedPayment.studentName
                ..studentSurname = fetchedPayment.studentSurname
                ..studentClass = fetchedPayment.studentClass
                ..phoneNumber = fetchedPayment.phoneNumber
                ..paymentPurpose = fetchedPayment.paymentPurpose
                ..amountToPay = fetchedPayment.amountToPay
                ..paymentDate = fetchedPayment.paymentDate
                ..termId = fetchedPayment.termId
                ..associatedStaff = fetchedPayment.associatedStaff
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingPayment.save();
              debugPrint(
                  'TeacherPayment ${fetchedPayment.receiptNumber} updated in Hive.');
            } else {
              await _teacher_paymentsBox!.add(fetchedPayment);
              debugPrint(
                  'TeacherPayment ${fetchedPayment.receiptNumber} added to Hive.');
            }
          } catch (error, stack) {
            debugPrint('❌ Error processing teacher payment:');
            debugPrint('Data: ${paymentsData.toString()}');
            debugPrint('Error: $error');
            debugPrint('Stack: $stack');
          }
        }
      } else {
        throw Exception(
            'Failed to fetch teacher payments. Status: ${response.statusCode}');
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
        final decoded = jsonDecode(response.body);

        List<dynamic> purposes;
        if (decoded is List) {
          purposes = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format');
          return;
        }

        if (purposes.isEmpty) {
          print('No teacher payment purposes found on server');
          return;
        }

        for (var purposeData in purposes) {
          try {
            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (purposeData['syncStatus'] != null) {
              if (purposeData['syncStatus'] is int) {
                syncStatus = purposeData['syncStatus'] == 1;
              } else if (purposeData['syncStatus'] is bool) {
                syncStatus = purposeData['syncStatus'];
              }
            }

            // ✅ Parse associatedStaff
            List<String> associatedStaff =
                _decodeToList(purposeData['associatedStaff']);

            // ✅ Handle id mapping
            int? id;
            if (purposeData['id'] != null) {
              if (purposeData['id'] is int) {
                id = purposeData['id'];
              } else if (purposeData['id'] is String) {
                id = int.tryParse(purposeData['id']);
              }
            }
            if (id == null && purposeData['fid'] != null) {
              if (purposeData['fid'] is int) {
                id = purposeData['fid'];
              } else if (purposeData['fid'] is String) {
                id = int.tryParse(purposeData['fid']);
              }
            }

            // ✅ Parse purposeAmount
            double purposeAmount = 0.0;
            if (purposeData['purposeAmount'] != null) {
              if (purposeData['purposeAmount'] is double) {
                purposeAmount = purposeData['purposeAmount'];
              } else if (purposeData['purposeAmount'] is int) {
                purposeAmount = purposeData['purposeAmount'].toDouble();
              } else if (purposeData['purposeAmount'] is String) {
                purposeAmount =
                    double.tryParse(purposeData['purposeAmount']) ?? 0.0;
              }
            }

            // ✅ Parse purposeCode - could be int or String
            String? purposeCode;
            if (purposeData['purposeCode'] != null) {
              if (purposeData['purposeCode'] is String) {
                purposeCode = purposeData['purposeCode'];
              } else if (purposeData['purposeCode'] is int) {
                purposeCode = purposeData['purposeCode'].toString();
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (purposeData['lastModified'] != null) {
              try {
                if (purposeData['lastModified'] is String) {
                  lastModified = DateTime.parse(purposeData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            TeacherPaymentsPurposes fetchedPurpose = TeacherPaymentsPurposes(
              id: id ?? 0,
              purposeCode: purposeCode ??
                  'PURP_${DateTime.now().millisecondsSinceEpoch}',
              paymentPurpose: purposeData['paymentPurpose']?.toString() ?? '',
              purposeAmount: purposeAmount,
              termId: purposeData['termId']?.toString(),
              associatedStaff: associatedStaff,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: [],
            );

            // Check if purpose exists in Hive
            var existingPurposeList = _teacher_payments_purposesBox!.values
                .where((purpose) =>
                    purpose.purposeCode == fetchedPurpose.purposeCode)
                .toList();

            if (existingPurposeList.isNotEmpty) {
              // Update existing purpose
              var existingPurpose = existingPurposeList.first;
              existingPurpose
                ..id = fetchedPurpose.id
                ..purposeCode = fetchedPurpose.purposeCode
                ..paymentPurpose = fetchedPurpose.paymentPurpose
                ..purposeAmount = fetchedPurpose.purposeAmount
                ..termId = fetchedPurpose.termId
                ..associatedStaff = fetchedPurpose.associatedStaff
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingPurpose.save();
              print(
                  'TeacherPaymentPurpose ${fetchedPurpose.purposeCode} updated in Hive.');
            } else {
              // Create new purpose
              await _teacher_payments_purposesBox!.add(fetchedPurpose);
              print(
                  'TeacherPaymentPurpose ${fetchedPurpose.purposeCode} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing teacher payment purpose:');
            print('Data: ${purposeData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Synced ${purposes.length} teacher payment purposes from server')));
      } else {
        throw Exception(
            'Failed to fetch teacher payment purposes. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing TeacherPaymentPurpose: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error syncing teacher payment purposes: $e')));
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
          try {
            // ✅ FIX: Safely convert all values with proper type handling

            // ✅ Handle IdNumber - could be String or int
            String? IdNumber;
            if (teachersData['IdNumber'] != null) {
              if (teachersData['IdNumber'] is String) {
                IdNumber = teachersData['IdNumber'];
              } else if (teachersData['IdNumber'] is int) {
                IdNumber = teachersData['IdNumber'].toString();
              } else if (teachersData['IdNumber'] is double) {
                IdNumber = teachersData['IdNumber'].toString();
              }
            }

            // Skip if no IdNumber
            if (IdNumber == null || IdNumber.isEmpty) {
              debugPrint('Skipping teacher with no IdNumber');
              continue;
            }

            // ✅ Handle id/fid mapping
            int? id;
            if (teachersData['id'] != null) {
              if (teachersData['id'] is int) {
                id = teachersData['id'];
              } else if (teachersData['id'] is String) {
                id = int.tryParse(teachersData['id']);
              }
            }
            if (id == null && teachersData['fid'] != null) {
              if (teachersData['fid'] is int) {
                id = teachersData['fid'];
              } else if (teachersData['fid'] is String) {
                id = int.tryParse(teachersData['fid']);
              }
            }

            // ✅ Convert isPaid from int to bool
            bool isPaid = true;
            if (teachersData['isPaid'] != null) {
              if (teachersData['isPaid'] is int) {
                isPaid = teachersData['isPaid'] == 1;
              } else if (teachersData['isPaid'] is bool) {
                isPaid = teachersData['isPaid'];
              } else if (teachersData['isPaid'] is String) {
                isPaid = teachersData['isPaid'] == '1' ||
                    teachersData['isPaid'].toLowerCase() == 'true';
              }
            }

            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (teachersData['syncStatus'] != null) {
              if (teachersData['syncStatus'] is int) {
                syncStatus = teachersData['syncStatus'] == 1;
              } else if (teachersData['syncStatus'] is bool) {
                syncStatus = teachersData['syncStatus'];
              } else if (teachersData['syncStatus'] is String) {
                syncStatus = teachersData['syncStatus'] == '1' ||
                    teachersData['syncStatus'].toLowerCase() == 'true';
              }
            }

            // ✅ Parse dateOfBirth
            DateTime dateOfBirth;
            if (teachersData['dateOfBirth'] != null) {
              try {
                if (teachersData['dateOfBirth'] is String) {
                  dateOfBirth = DateTime.parse(teachersData['dateOfBirth']);
                } else {
                  dateOfBirth = DateTime.now();
                }
              } catch (e) {
                dateOfBirth = DateTime.now();
              }
            } else {
              dateOfBirth = DateTime.now();
            }

            // ✅ Parse hireDate
            DateTime hireDate;
            if (teachersData['hireDate'] != null) {
              try {
                if (teachersData['hireDate'] is String) {
                  hireDate = DateTime.parse(teachersData['hireDate']);
                } else {
                  hireDate = DateTime.now();
                }
              } catch (e) {
                hireDate = DateTime.now();
              }
            } else {
              hireDate = DateTime.now();
            }

            // ✅ Parse paymentDate
            DateTime? paymentDate;
            if (teachersData['paymentDate'] != null) {
              try {
                if (teachersData['paymentDate'] is String) {
                  paymentDate = DateTime.parse(teachersData['paymentDate']);
                }
              } catch (e) {
                paymentDate = null;
              }
            }

            // ✅ Parse paymentAmount
            double paymentAmount = 0.0;
            if (teachersData['paymentAmount'] != null) {
              if (teachersData['paymentAmount'] is double) {
                paymentAmount = teachersData['paymentAmount'];
              } else if (teachersData['paymentAmount'] is int) {
                paymentAmount = teachersData['paymentAmount'].toDouble();
              } else if (teachersData['paymentAmount'] is String) {
                paymentAmount =
                    double.tryParse(teachersData['paymentAmount']) ?? 0.0;
              }
            }

            // ✅ Parse assignedClasses
            List<String> assignedClasses =
                _decodeToList(teachersData['assignedClasses']);

            // ✅ Parse terms
            List<String> terms = _decodeToList(teachersData['terms']);

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (teachersData['lastModified'] != null) {
              try {
                if (teachersData['lastModified'] is String) {
                  lastModified = DateTime.parse(teachersData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            Teachers fetchedTeachers = Teachers(
              id: id ?? 0,
              IdNumber: IdNumber,
              name: teachersData['name']?.toString() ?? '',
              surname: teachersData['surname']?.toString() ?? '',
              gender: teachersData['gender']?.toString() ?? '',
              dateOfBirth: dateOfBirth,
              phoneNumber: teachersData['phoneNumber']?.toString() ?? '',
              email: teachersData['email']?.toString() ?? '',
              address: teachersData['address']?.toString() ?? '',
              hireDate: hireDate,
              qualifications: teachersData['qualifications']?.toString() ?? '',
              employmentStatus:
                  teachersData['employmentStatus']?.toString() ?? '',
              assignedClass: teachersData['assignedClass']?.toString(),
              assignedClasses: assignedClasses,
              paymentPurpose: teachersData['paymentPurpose']?.toString() ?? '',
              isPaid: isPaid,
              paymentAmount: paymentAmount,
              paymentDate: paymentDate,
              termId: teachersData['termId']?.toString(),
              terms: terms,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: [],
            );

            // Check if the record exists in Hive using IdNumber
            var existingTeachersList = _teachersBox!.values
                .where(
                    (teachers) => teachers.IdNumber == fetchedTeachers.IdNumber)
                .toList();

            Teachers? existingTeachers = existingTeachersList.isNotEmpty
                ? existingTeachersList.first
                : null;

            if (existingTeachers != null) {
              // Update existing record
              existingTeachers
                ..id = fetchedTeachers.id
                ..IdNumber = fetchedTeachers.IdNumber
                ..name = fetchedTeachers.name
                ..surname = fetchedTeachers.surname
                ..gender = fetchedTeachers.gender
                ..dateOfBirth = fetchedTeachers.dateOfBirth
                ..phoneNumber = fetchedTeachers.phoneNumber
                ..email = fetchedTeachers.email
                ..address = fetchedTeachers.address
                ..hireDate = fetchedTeachers.hireDate
                ..qualifications = fetchedTeachers.qualifications
                ..employmentStatus = fetchedTeachers.employmentStatus
                ..assignedClass = fetchedTeachers.assignedClass
                ..assignedClasses = fetchedTeachers.assignedClasses
                ..paymentPurpose = fetchedTeachers.paymentPurpose
                ..isPaid = fetchedTeachers.isPaid
                ..paymentAmount = fetchedTeachers.paymentAmount
                ..paymentDate = fetchedTeachers.paymentDate
                ..termId = fetchedTeachers.termId
                ..terms = fetchedTeachers.terms
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingTeachers.save();
              debugPrint(
                  'Teachers ${fetchedTeachers.IdNumber} updated successfully in Hive.');
            } else {
              await _teachersBox!.add(fetchedTeachers);
              debugPrint(
                  'Teachers ${fetchedTeachers.IdNumber} added successfully to Hive.');
            }
          } catch (error, stack) {
            debugPrint('❌ Error processing teacher record:');
            debugPrint('Data: ${teachersData.toString()}');
            debugPrint('Error: $error');
            debugPrint('Stack: $stack');
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
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?include_deleted=true';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        List<dynamic> terms = decoded is List ? decoded : [];

        if (terms.isEmpty) {
          print('No terms found on server');
          return;
        }

        for (var termData in terms) {
          // ✅ Parse deletion fields
          bool isDeleted = false;
          if (termData['isDeleted'] != null) {
            isDeleted =
                termData['isDeleted'] == 1 || termData['isDeleted'] == true;
          }

          bool deletedSyncStatus = false;
          if (termData['deletedSyncStatus'] != null) {
            deletedSyncStatus = termData['deletedSyncStatus'] == 1 ||
                termData['deletedSyncStatus'] == true;
          }

          DateTime? deletedAt;
          if (termData['deletedAt'] != null) {
            try {
              deletedAt = DateTime.parse(termData['deletedAt']);
            } catch (e) {
              deletedAt = null;
            }
          }

          // Parse other fields...
          DateTime startDate =
              DateTime.tryParse(termData['startDate'] ?? '') ?? DateTime.now();
          DateTime? endDate = termData['endDate'] != null
              ? DateTime.tryParse(termData['endDate'])
              : null;
          bool isActive =
              termData['isActive'] == 1 || termData['isActive'] == true;
          bool syncStatus =
              termData['syncStatus'] == 1 || termData['syncStatus'] == true;
          int? id = termData['id'] ?? int.tryParse(termData['fid'] ?? '0');

          Terms fetchedTerm = Terms(
            id: id ?? 0,
            termId: termData['termId']?.toString() ?? '',
            termName: termData['termName']?.toString() ?? '',
            startDate: startDate,
            endDate: endDate,
            isActive: isActive,
            status: termData['status']?.toString() ??
                (isActive ? 'Opened' : 'Closed'),
            syncStatus: syncStatus,
            operationType: 'none',
            lastModified: DateTime.tryParse(termData['lastModified'] ?? ''),
            modifiedFields: [],
            // ✅ Deletion fields
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            deletedBy: termData['deletedBy'],
            deleteReason: termData['deleteReason'],
            deletedSyncStatus: deletedSyncStatus,
          );

          // Check if term exists in Hive
          var existingTermList = _termsBox!.values
              .where((term) => term.termId == fetchedTerm.termId)
              .toList();

          if (existingTermList.isNotEmpty) {
            var existingTerm = existingTermList.first;
            existingTerm
              ..id = fetchedTerm.id
              ..termId = fetchedTerm.termId
              ..termName = fetchedTerm.termName
              ..startDate = fetchedTerm.startDate
              ..endDate = fetchedTerm.endDate
              ..isActive = fetchedTerm.isActive
              ..status = fetchedTerm.status
              ..isDeleted = fetchedTerm.isDeleted
              ..deletedAt = fetchedTerm.deletedAt
              ..deletedBy = fetchedTerm.deletedBy
              ..deleteReason = fetchedTerm.deleteReason
              ..deletedSyncStatus = fetchedTerm.deletedSyncStatus
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now();

            await existingTerm.save();
            print('Term ${fetchedTerm.termId} updated in Hive.');
          } else {
            await _termsBox!.add(fetchedTerm);
            print('Term ${fetchedTerm.termId} added to Hive.');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${terms.length} terms from server')));
      } else {
        throw Exception(
            'Failed to fetch terms. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing terms: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing terms: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncUsers =======================================================================//
  Future<void> _fetchAndSyncUsers() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?include_deleted=true';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> users = jsonDecode(response.body);

        if (users.isEmpty) {
          print('No users found on server');
          return;
        }

        for (var userData in users) {
          // ✅ Parse isDeleted from server
          bool isDeleted = false;
          if (userData['isDeleted'] != null) {
            if (userData['isDeleted'] is int) {
              isDeleted = userData['isDeleted'] == 1;
            } else if (userData['isDeleted'] is bool) {
              isDeleted = userData['isDeleted'];
            }
          }

          // ✅ Parse deletedSyncStatus
          bool deletedSyncStatus = false;
          if (userData['deletedSyncStatus'] != null) {
            if (userData['deletedSyncStatus'] is int) {
              deletedSyncStatus = userData['deletedSyncStatus'] == 1;
            } else if (userData['deletedSyncStatus'] is bool) {
              deletedSyncStatus = userData['deletedSyncStatus'];
            }
          }

          // ✅ Parse deletedAt
          DateTime? deletedAt;
          if (userData['deletedAt'] != null) {
            try {
              deletedAt = DateTime.parse(userData['deletedAt']);
            } catch (e) {
              deletedAt = null;
            }
          }

          // Parse other fields...
          List<String> securityQuestions =
              _decodeToList(userData['securityQuestions']);
          List<String> securityAnswers =
              _decodeToList(userData['securityAnswers']);
          List<String> assignedClasses =
              _decodeToList(userData['assignedClasses']);

          bool isActive = true;
          if (userData['isActive'] != null) {
            if (userData['isActive'] is int) {
              isActive = userData['isActive'] == 1;
            } else if (userData['isActive'] is bool) {
              isActive = userData['isActive'];
            }
          }

          User fetchedUser = User(
            id: userData['id'] ?? int.tryParse(userData['fid'] ?? '0'),
            userCode: userData['userCode'] ?? '',
            username: userData['username'] ?? '',
            password: userData['password'] ?? '',
            email: userData['email'],
            role: userData['role'] ?? '',
            phone: userData['phone'] ?? '',
            isActive: isActive,
            securityQuestions: securityQuestions,
            securityAnswers: securityAnswers,
            assignedClasses: assignedClasses,
            termId: userData['termId'],
            syncStatus: true,
            operationType: 'none',
            lastModified: DateTime.parse(
                userData['lastModified'] ?? DateTime.now().toIso8601String()),
            createdAt: userData['createdAt'] != null
                ? DateTime.parse(userData['createdAt'])
                : null,
            isLogged: false,
            modifiedFields: [],
            // ✅ Deletion fields
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            deletedBy: userData['deletedBy'],
            deleteReason: userData['deleteReason'],
            deletedSyncStatus: deletedSyncStatus,
          );

          // Check if user exists in Hive
          var existingUsers = _usersBox!.values
              .where((user) => user.userCode == fetchedUser.userCode)
              .toList();

          if (existingUsers.isNotEmpty) {
            // ✅ Update existing user (including deletion state)
            var existingUser = existingUsers.first;
            existingUser
              ..id = fetchedUser.id
              ..userCode = fetchedUser.userCode
              ..username = fetchedUser.username
              ..password = fetchedUser.password
              ..email = fetchedUser.email
              ..role = fetchedUser.role
              ..phone = fetchedUser.phone
              ..isActive = fetchedUser.isActive
              ..securityQuestions = fetchedUser.securityQuestions
              ..securityAnswers = fetchedUser.securityAnswers
              ..assignedClasses = fetchedUser.assignedClasses
              ..termId = fetchedUser.termId
              ..isDeleted = fetchedUser.isDeleted
              ..deletedAt = fetchedUser.deletedAt
              ..deletedBy = fetchedUser.deletedBy
              ..deleteReason = fetchedUser.deleteReason
              ..deletedSyncStatus = fetchedUser.deletedSyncStatus
              ..syncStatus = true
              ..operationType = 'none'
              ..lastModified = DateTime.now();

            await existingUser.save();
            print('User ${fetchedUser.userCode} updated in Hive.');
          } else {
            // ✅ Create new user (including if it's deleted)
            await _usersBox!.add(fetchedUser);
            print('User ${fetchedUser.userCode} added to Hive.');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${users.length} users from server')));
      } else {
        throw Exception(
            'Failed to fetch users. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing users: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing users: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
// PULL Withdrawals from server
  //================================pull _fetchAndSyncWithdrawals =======================================================================//

  Future<void> _fetchAndSyncWithdrawals() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();

        if (responseBody.isEmpty) {
          debugPrint('Warning: Withdrawals API returned an empty response.');
          return;
        }

        List<dynamic> withdrawals;
        try {
          withdrawals = jsonDecode(responseBody);
        } catch (e) {
          debugPrint('Error decoding Withdrawals JSON: $e');
          return;
        }

        for (var withdrawalData in withdrawals) {
          try {
            // ✅ Parse date with time
            DateTime date;
            if (withdrawalData['date'] != null) {
              try {
                if (withdrawalData['date'] is String) {
                  date = DateTime.parse(withdrawalData['date']);
                  print('Parsed date with time: $date');
                } else {
                  date = DateTime.now();
                }
              } catch (e) {
                print('Error parsing date: $e');
                date = DateTime.now();
              }
            } else {
              date = DateTime.now();
            }

            // ✅ Convert syncStatus from int to bool
            bool syncStatus = true;
            if (withdrawalData['syncStatus'] != null) {
              if (withdrawalData['syncStatus'] is int) {
                syncStatus = withdrawalData['syncStatus'] == 1;
              } else if (withdrawalData['syncStatus'] is bool) {
                syncStatus = withdrawalData['syncStatus'];
              } else if (withdrawalData['syncStatus'] is String) {
                syncStatus = withdrawalData['syncStatus'] == '1' ||
                    withdrawalData['syncStatus'].toLowerCase() == 'true';
              }
            }

            // ✅ Handle id mapping
            int? id;
            if (withdrawalData['id'] != null) {
              if (withdrawalData['id'] is int) {
                id = withdrawalData['id'];
              } else if (withdrawalData['id'] is String) {
                id = int.tryParse(withdrawalData['id']);
              }
            }
            if (id == null && withdrawalData['fid'] != null) {
              if (withdrawalData['fid'] is int) {
                id = withdrawalData['fid'];
              } else if (withdrawalData['fid'] is String) {
                id = int.tryParse(withdrawalData['fid']);
              }
            }

            // ✅ Parse amount
            double amount = 0.0;
            if (withdrawalData['amount'] != null) {
              if (withdrawalData['amount'] is double) {
                amount = withdrawalData['amount'];
              } else if (withdrawalData['amount'] is int) {
                amount = withdrawalData['amount'].toDouble();
              } else if (withdrawalData['amount'] is String) {
                amount = double.tryParse(withdrawalData['amount']) ?? 0.0;
              }
            }

            // ✅ FIX: Parse withdrawalCode - could be int or String
            String? withdrawalCode;
            if (withdrawalData['withdrawalCode'] != null) {
              if (withdrawalData['withdrawalCode'] is String) {
                withdrawalCode = withdrawalData['withdrawalCode'];
              } else if (withdrawalData['withdrawalCode'] is int) {
                withdrawalCode = withdrawalData['withdrawalCode'].toString();
              } else if (withdrawalData['withdrawalCode'] is double) {
                withdrawalCode = withdrawalData['withdrawalCode'].toString();
              }
            }

            // ✅ If no withdrawalCode, generate one from id
            if (withdrawalCode == null || withdrawalCode.isEmpty) {
              withdrawalCode =
                  'WTH_${id ?? DateTime.now().millisecondsSinceEpoch}';
            }

            // ✅ Parse withdrawalPurpose - could be int or String
            String withdrawalPurpose;
            if (withdrawalData['withdrawalPurpose'] != null) {
              if (withdrawalData['withdrawalPurpose'] is String) {
                withdrawalPurpose = withdrawalData['withdrawalPurpose'];
              } else if (withdrawalData['withdrawalPurpose'] is int) {
                withdrawalPurpose =
                    withdrawalData['withdrawalPurpose'].toString();
              } else {
                withdrawalPurpose = '';
              }
            } else {
              withdrawalPurpose = '';
            }

            // ✅ Parse termId - could be int or String
            String? termId;
            if (withdrawalData['termId'] != null) {
              if (withdrawalData['termId'] is String) {
                termId = withdrawalData['termId'];
              } else if (withdrawalData['termId'] is int) {
                termId = withdrawalData['termId'].toString();
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (withdrawalData['lastModified'] != null) {
              try {
                if (withdrawalData['lastModified'] is String) {
                  lastModified = DateTime.parse(withdrawalData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            // ✅ Parse operationType
            String operationType;
            if (withdrawalData['operationType'] != null) {
              if (withdrawalData['operationType'] is String) {
                operationType = withdrawalData['operationType'];
              } else if (withdrawalData['operationType'] is int) {
                operationType = withdrawalData['operationType'].toString();
              } else {
                operationType = 'none';
              }
            } else {
              operationType = 'none';
            }

            Withdrawal fetchedWithdrawal = Withdrawal(
              id: id ?? 0,
              withdrawalCode: withdrawalCode,
              withdrawalPurpose: withdrawalPurpose,
              amount: amount,
              date: date,
              termId: termId,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: [],
            );

            // Check if withdrawal exists in Hive
            var existingWithdrawalList = _withdrawalsBox!.values
                .where((withdrawal) =>
                    withdrawal.withdrawalCode ==
                    fetchedWithdrawal.withdrawalCode)
                .toList();

            Withdrawal? existingWithdrawal = existingWithdrawalList.isNotEmpty
                ? existingWithdrawalList.first
                : null;

            if (existingWithdrawal != null) {
              // ✅ Update existing withdrawal
              existingWithdrawal
                ..id = fetchedWithdrawal.id
                ..withdrawalCode = fetchedWithdrawal.withdrawalCode
                ..withdrawalPurpose = fetchedWithdrawal.withdrawalPurpose
                ..amount = fetchedWithdrawal.amount
                ..date = fetchedWithdrawal.date
                ..termId = fetchedWithdrawal.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();

              await existingWithdrawal.save();
              debugPrint(
                  'Withdrawal ${fetchedWithdrawal.withdrawalCode} updated in Hive.');
            } else {
              // ✅ Create new withdrawal
              await _withdrawalsBox!.add(fetchedWithdrawal);
              debugPrint(
                  'Withdrawal ${fetchedWithdrawal.withdrawalCode} added to Hive.');
            }
          } catch (error, stack) {
            debugPrint('❌ Error processing withdrawal record:');
            debugPrint('Data: ${withdrawalData.toString()}');
            debugPrint('Error: $error');
            debugPrint('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Synced ${withdrawals.length} withdrawals from server')));
      } else {
        throw Exception(
            'Failed to fetch withdrawals. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching or syncing withdrawals: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing withdrawals: $e')));
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

// PULL Accounts from server
  Future<void> _fetchAndSyncAccount() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/account_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        List<dynamic> accounts;
        if (decoded is List) {
          accounts = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format');
          return;
        }

        if (accounts.isEmpty) {
          print('No accounts found on server');
          return;
        }

        for (var accData in accounts) {
          try {
            // ✅ Convert syncStatus from int to bool
            bool syncStatus = false;
            if (accData['syncStatus'] != null) {
              if (accData['syncStatus'] is int) {
                syncStatus = accData['syncStatus'] == 1;
              } else if (accData['syncStatus'] is bool) {
                syncStatus = accData['syncStatus'];
              }
            }

            // ✅ Convert isALiquidAccount from int to bool
            bool isALiquidAccount = false;
            if (accData['isALiquidAccount'] != null) {
              if (accData['isALiquidAccount'] is int) {
                isALiquidAccount = accData['isALiquidAccount'] == 1;
              } else if (accData['isALiquidAccount'] is bool) {
                isALiquidAccount = accData['isALiquidAccount'];
              }
            }

            // ✅ Handle id - could be int or String
            int? id;
            if (accData['id'] != null) {
              if (accData['id'] is int) {
                id = accData['id'];
              } else if (accData['id'] is String) {
                id = int.tryParse(accData['id']);
              }
            }

            // ✅ Handle accountCode - could be int or String
            String? accountCode;
            if (accData['accountCode'] != null) {
              if (accData['accountCode'] is String) {
                accountCode = accData['accountCode'];
              } else if (accData['accountCode'] is int) {
                accountCode = accData['accountCode'].toString();
              }
            }

            // ✅ Parse modifiedFields
            List<String> modifiedFields =
                _decodeToList(accData['modifiedFields']);

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (accData['lastModified'] != null) {
              try {
                if (accData['lastModified'] is String) {
                  lastModified = DateTime.parse(accData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            Account fetchedAccount = Account(
              id: id,
              accountCode: accountCode,
              accountType: accData['accountType']?.toString(),
              accountSubType: accData['accountSubType']?.toString(),
              accountName: accData['accountName']?.toString(),
              isALiquidAccount: isALiquidAccount,
              syncStatus: syncStatus,
              operationType: 'none',
              lastModified: lastModified,
              modifiedFields: modifiedFields,
            );

            // Check if account exists in Hive
            var existingList = _accountBox!.values
                .where((a) => a.accountCode == fetchedAccount.accountCode)
                .toList();

            Account? existing =
                existingList.isNotEmpty ? existingList.first : null;

            if (existing != null) {
              // ✅ Update existing account
              existing
                ..id = fetchedAccount.id
                ..accountCode = fetchedAccount.accountCode
                ..accountType = fetchedAccount.accountType
                ..accountSubType = fetchedAccount.accountSubType
                ..accountName = fetchedAccount.accountName
                ..isALiquidAccount = fetchedAccount.isALiquidAccount
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..modifiedFields = [];

              await existing.save();
              print('Account ${fetchedAccount.accountCode} updated in Hive.');
            } else {
              // ✅ Create new account
              await _accountBox!.add(fetchedAccount);
              print('Account ${fetchedAccount.accountCode} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing account:');
            print('Data: ${accData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${accounts.length} accounts from server')));
      } else {
        throw Exception(
            'Failed to fetch accounts. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing accounts: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing accounts: $e')));
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

// PULL Projects from server
  Future<void> _fetchAndSyncProject() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        List<dynamic> projects;
        if (decoded is List) {
          projects = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format');
          return;
        }

        if (projects.isEmpty) {
          print('No projects found on server');
          return;
        }

        for (var projectData in projects) {
          try {
            // ✅ Convert syncStatus from int to bool
            bool syncStatus = false;
            if (projectData['syncStatus'] != null) {
              if (projectData['syncStatus'] is int) {
                syncStatus = projectData['syncStatus'] == 1;
              } else if (projectData['syncStatus'] is bool) {
                syncStatus = projectData['syncStatus'];
              }
            }

            // ✅ Convert studentPayable from int to bool
            bool studentPayable = true;
            if (projectData['studentPayable'] != null) {
              if (projectData['studentPayable'] is int) {
                studentPayable = projectData['studentPayable'] == 1;
              } else if (projectData['studentPayable'] is bool) {
                studentPayable = projectData['studentPayable'];
              }
            }

            // ✅ Parse dates
            DateTime createdAt = DateTime.now();
            if (projectData['createdAt'] != null) {
              try {
                createdAt = DateTime.parse(projectData['createdAt']);
              } catch (e) {
                createdAt = DateTime.now();
              }
            }

            DateTime updatedAt = DateTime.now();
            if (projectData['updatedAt'] != null) {
              try {
                updatedAt = DateTime.parse(projectData['updatedAt']);
              } catch (e) {
                updatedAt = DateTime.now();
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (projectData['lastModified'] != null) {
              try {
                if (projectData['lastModified'] is String) {
                  lastModified = DateTime.parse(projectData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            // ✅ Parse modifiedFields
            List<String> modifiedFields =
                _decodeToList(projectData['modifiedFields']);

            Project fetchedProject = Project(
              projectCode: projectData['projectCode']?.toString() ?? '',
              name: projectData['name']?.toString() ?? '',
              description: projectData['description']?.toString(),
              status: projectData['status']?.toString() ?? 'active',
              createdAt: createdAt,
              updatedAt: updatedAt,
              syncStatus: syncStatus,
              lastModified: lastModified,
              operationType: 'none',
              modifiedFields: modifiedFields,
              // ✅ NEW FIELDS
              projectType: projectData['projectType']?.toString() ?? 'sales',
              participationType:
                  projectData['participationType']?.toString() ?? 'optional',
              studentPayable: studentPayable,
            );

            // Check if project exists in Hive
            var existingProjectList = _projectBox!.values
                .where((p) => p.projectCode == fetchedProject.projectCode)
                .toList();

            Project? existingProject = existingProjectList.isNotEmpty
                ? existingProjectList.first
                : null;

            if (existingProject != null) {
              // ✅ Update existing project
              existingProject
                ..projectCode = fetchedProject.projectCode
                ..name = fetchedProject.name
                ..description = fetchedProject.description
                ..status = fetchedProject.status
                ..createdAt = fetchedProject.createdAt
                ..updatedAt = fetchedProject.updatedAt
                ..projectType = fetchedProject.projectType
                ..participationType = fetchedProject.participationType
                ..studentPayable = fetchedProject.studentPayable
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..modifiedFields = [];

              await existingProject.save();
              print('Project ${fetchedProject.projectCode} updated in Hive.');
            } else {
              // ✅ Create new project
              await _projectBox!.add(fetchedProject);
              print('Project ${fetchedProject.projectCode} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing project:');
            print('Data: ${projectData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${projects.length} projects from server')));
      } else {
        throw Exception(
            'Failed to fetch projects. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing projects: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error syncing projects: $e')));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

//================================pull _fetchAndSyncProjectItem =======================================================================//

// PULL ProjectItems from server
  Future<void> _fetchAndSyncProjectItem() async {
    final String apiUrl =
        'http://$_domainName/api_school_management_system/php_codes_for_a_restful_api/project_item_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        List<dynamic> items;
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded.containsKey('message')) {
          print('Server message: ${decoded['message']}');
          return;
        } else {
          print('Unexpected response format');
          return;
        }

        if (items.isEmpty) {
          print('No project items found on server');
          return;
        }

        for (var itemData in items) {
          try {
            // ✅ Convert syncStatus from int to bool
            bool syncStatus = false;
            if (itemData['syncStatus'] != null) {
              if (itemData['syncStatus'] is int) {
                syncStatus = itemData['syncStatus'] == 1;
              } else if (itemData['syncStatus'] is bool) {
                syncStatus = itemData['syncStatus'];
              }
            }

            // ✅ Convert active from int to bool
            bool active = true;
            if (itemData['active'] != null) {
              if (itemData['active'] is int) {
                active = itemData['active'] == 1;
              } else if (itemData['active'] is bool) {
                active = itemData['active'];
              }
            }

            // ✅ Convert trackStock from int to bool
            bool trackStock = false;
            if (itemData['trackStock'] != null) {
              if (itemData['trackStock'] is int) {
                trackStock = itemData['trackStock'] == 1;
              } else if (itemData['trackStock'] is bool) {
                trackStock = itemData['trackStock'];
              }
            }

            // ✅ Parse lastModified
            DateTime? lastModified;
            if (itemData['lastModified'] != null) {
              try {
                if (itemData['lastModified'] is String) {
                  lastModified = DateTime.parse(itemData['lastModified']);
                }
              } catch (e) {
                lastModified = DateTime.now();
              }
            }

            // ✅ Parse modifiedFields
            List<String> modifiedFields =
                _decodeToList(itemData['modifiedFields']);

            ProjectItem fetchedItem = ProjectItem(
              projectItemCode: itemData['projectItemCode']?.toString() ?? '',
              projectCode: itemData['projectCode']?.toString() ?? '',
              name: itemData['name']?.toString() ?? '',
              itemType: itemData['itemType']?.toString() ?? 'goods',
              active: active,
              trackStock: trackStock,
              syncStatus: syncStatus,
              lastModified: lastModified,
              operationType: 'none',
              modifiedFields: modifiedFields,
            );

            // Check if item exists in Hive
            var existingItemList = _projectItemBox!.values
                .where((i) => i.projectItemCode == fetchedItem.projectItemCode)
                .toList();

            ProjectItem? existingItem =
                existingItemList.isNotEmpty ? existingItemList.first : null;

            if (existingItem != null) {
              // ✅ Update existing item
              existingItem
                ..projectItemCode = fetchedItem.projectItemCode
                ..projectCode = fetchedItem.projectCode
                ..name = fetchedItem.name
                ..itemType = fetchedItem.itemType
                ..active = fetchedItem.active
                ..trackStock = fetchedItem.trackStock
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..modifiedFields = [];

              await existingItem.save();
              print(
                  'ProjectItem ${fetchedItem.projectItemCode} updated in Hive.');
            } else {
              // ✅ Create new item
              await _projectItemBox!.add(fetchedItem);
              print(
                  'ProjectItem ${fetchedItem.projectItemCode} added to Hive.');
            }
          } catch (error, stack) {
            print('❌ Error processing project item:');
            print('Data: ${itemData.toString()}');
            print('Error: $error');
            print('Stack: $stack');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Synced ${items.length} project items from server')));
      } else {
        throw Exception(
            'Failed to fetch project items. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing project items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing project items: $e')));
    } finally {
      setState(() {
        _isSyncings = false;
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
