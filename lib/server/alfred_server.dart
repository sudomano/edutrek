import 'dart:convert';
import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/id_assignment_log.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';
import 'package:zitf_system/database/settings.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/reusable_codes/serializers/accounts_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/assets_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/batch_sell_unit_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/class_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/daily_activities_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/domains_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/exceptions_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_log_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/product_batch_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/project_items_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/project_sale_transaction_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/projects_serializerr.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/teacher_payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/teacher_payment_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/teachers_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/users_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/withdrawals_serializer.dart';
import 'package:zitf_system/school_info/school_validator.dart';
import 'package:zitf_system/server/routes/independent_alfred_api/id_assignment_api.dart';
import 'package:zitf_system/server/routes/student_factory.dart';
import 'package:zitf_system/terms/term_validator.dart';
import '../database/school_info.dart';

late final Box<School> schoolBox;
late final Box<Terms> _termsBox;
late final Box<Classes> _classesBox;
late final Box<TeacherPaymentsPurposes> _teacherPaymentsPurposesBox;
late final Box<PaymentPurpose> _paymentPurposesBox;
late final Box<StudentPayment> _studentPaymentsBox;
late final Box<TeacherPayment> _teacherPaymentsBox;
late final Box<Student> _studentsBox;
late final Box<Withdrawal> _withdrawalsBox;
late final Box<Teachers> _teachersBox;
late final Box<DomainRecord> _domainRecordBox;
late final Box<User> _userBox;
late final Box<Account> _accountBox;
late final Box<Asset> _assetBox;
late final Box<Project> _projectBox;
late final Box<ProjectItem> _projectItemBox;
late final Box<DailyActivity> _dailyActivityBox;
late final Box<ExceptionalStudents> _exceptionalStudentsBox;
late final Box<ProductBatch> _productBatchBox;
late final Box<BatchSellUnit> _batchSellUnitBox;
late final Box<Settings> _settingsBox;
late final Box<ProjectSaleTransaction> _projectSaleTransactionBox;
late final Box<PaymentLog> _paymentLogBox;

Future<void> initializeSettings() async {
  try {
    // Check if settings already exist
    if (_settingsBox.isEmpty) {
      // Create default settings
      final defaultSettings = Settings(
        id: 'app_settings',
        lastUpdated: DateTime.now(),
        allowAttendanceUpdate: false, // Default: block updates
        allowStudentSync: true,
        allowPaymentSync: true,
        autoSyncEnabled: false,
        syncIntervalMinutes: 5,
        maintenanceMode: false,
        enableBackup: false,
        backupFrequency: 'Daily',
        maxStudentsPerClass: 30,
        allowMultipleTerms: true,
        enableNotifications: true,
        debugMode: false,
        syncStatus: true,
        modifiedFields: [],
        operationType: 'create',
      );

      await _settingsBox.add(defaultSettings);
      debugPrint(
          '✅ Default settings initialized: allowAttendanceUpdate = false');
    } else {
      final settings = _settingsBox.values.first;
      debugPrint(
          '✅ Settings already exist: allowAttendanceUpdate = ${settings.allowAttendanceUpdate}');
    }

    debugPrint('✅ Settings box ready with ${_settingsBox.length} entries');
  } catch (e) {
    debugPrint('❌ Error initializing settings: $e');
    rethrow;
  }
}

Future<void> startAlfredServer() async {
  final app = Alfred();

  app.all("*", (req, res) {
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Headers', '*');
    res.headers.set('Access-Control-Allow-Methods',
        'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  });

  app.get("/api/health", (req, res) => {"status": "ok"});

  // ============================================================
// ============================================================
// ID ASSIGNMENT API ENDPOINTS (Fully Fixed)
// ============================================================

  /// *********************** GET last assigned ID *********************/
  app.get('/api/ids/last', (req, res) async {
    try {
      final result = await getLastAssignedId();
      res.json(result);
    } catch (e) {
      print('❌ Error in /api/ids/last: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

  /// *********************** RESERVE IDs (batch) *********************/
  app.post('/api/ids/reserve', (req, res) async {
    try {
      final body = await req.body as String?;
      if (body == null || body.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Request body is required'});
        return;
      }

      final data = jsonDecode(body);
      final count = data['count'] as int? ?? 1;
      final clientId = data['clientId'] as String?;

      // Validate count
      if (count < 1 || count > 1000) {
        res.statusCode = 400;
        res.json(
            {'success': false, 'error': 'Count must be between 1 and 1000'});
        return;
      }

      final result = await reserveIds(count: count, clientId: clientId);
      res.json(result);
    } catch (e) {
      print('❌ Error in /api/ids/reserve: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

  /// *********************** MARK ID as used *********************/
  app.post('/api/ids/mark-used', (req, res) async {
    try {
      final body = await req.body as String?;
      if (body == null || body.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Request body is required'});
        return;
      }

      final data = jsonDecode(body);
      final id = data['id'] as int?;
      final receiptNumber = data['receiptNumber'] as String?;

      // Validate required fields
      if (id == null) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'ID is required'});
        return;
      }

      if (receiptNumber == null || receiptNumber.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Receipt number is required'});
        return;
      }

      final result = await markIdAsUsed(id: id, receiptNumber: receiptNumber);
      res.json(result);
    } catch (e) {
      print('❌ Error in /api/ids/mark-used: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

  /// *********************** CHECK if ID exists *********************/
  app.get('/api/ids/check/:id', (req, res) async {
    try {
      final idParam = req.params['id'];
      if (idParam == null || idParam.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'ID parameter is required'});
        return;
      }

      final id = int.tryParse(idParam);
      if (id == null) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Invalid ID format'});
        return;
      }

      final result = await checkIdExists(id);
      res.json(result);
    } catch (e) {
      print('❌ Error in /api/ids/check/:id: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

  /// *********************** GET pending IDs *********************/
  app.get('/api/ids/pending', (req, res) async {
    try {
      final result = await getPendingIds();
      res.json(result);
    } catch (e) {
      print('❌ Error in /api/ids/pending: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

  /// *********************** GET assignment history *********************/
  app.get('/api/ids/history', (req, res) async {
    try {
      final limitParam = req.uri.queryParameters['limit'] ?? '50';
      final offsetParam = req.uri.queryParameters['offset'] ?? '0';

      final limit = int.tryParse(limitParam) ?? 50;
      final offset = int.tryParse(offsetParam) ?? 0;

      // Validate pagination parameters
      if (limit < 1 || limit > 500) {
        res.statusCode = 400;
        res.json(
            {'success': false, 'error': 'Limit must be between 1 and 500'});
        return;
      }

      if (offset < 0) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Offset must be >= 0'});
        return;
      }

      final result = await getAssignmentHistory(limit: limit, offset: offset);
      res.json(result);
    } catch (e) {
      print('❌ Error in /api/ids/history: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

// ============================================================
// NEW: Get ID by receipt number (Integration endpoint)
// ============================================================

  /// *********************** GET ID by receipt number *********************/
  app.get('/api/ids/by-receipt/:receiptNumber', (req, res) async {
    try {
      final receiptNumber = req.params['receiptNumber'];

      if (receiptNumber == null || receiptNumber.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Receipt number is required'});
        return;
      }

      // Check the local ID assignment logs
      final box = await Hive.openBox<IdAssignmentLog>('id_assignment_log');

      try {
        final log = box.values.firstWhere(
          (log) => log.paymentReceiptNumber == receiptNumber,
        );

        res.json({
          'success': true,
          'id': log.id,
          'receiptNumber': receiptNumber,
          'isUsed': log.isUsed,
          'assignedAt': log.assignedAt.toIso8601String(),
          'usedAt': log.usedAt?.toIso8601String(),
        });
      } catch (e) {
        res.statusCode = 404;
        res.json({
          'success': false,
          'error': 'No ID found for receipt number: $receiptNumber'
        });
      }
    } catch (e) {
      print('❌ Error in /api/ids/by-receipt/:receiptNumber: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

// ============================================================
// NEW: Mark ID as used and link to transaction (Combined endpoint)
// ============================================================

  /// *********************** Mark ID as used and link to transaction *********************/
  app.post('/api/ids/mark-used-with-transaction', (req, res) async {
    try {
      final body = await req.body as String?;
      if (body == null || body.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Request body is required'});
        return;
      }

      final data = jsonDecode(body);
      final id = data['id'] as int?;
      final receiptNumber = data['receiptNumber'] as String?;

      // Validate required fields
      if (id == null) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'ID is required'});
        return;
      }

      if (receiptNumber == null || receiptNumber.isEmpty) {
        res.statusCode = 400;
        res.json({'success': false, 'error': 'Receipt number is required'});
        return;
      }

      // Step 1: Mark the ID as used
      final idResult = await markIdAsUsed(id: id, receiptNumber: receiptNumber);

      if (!idResult['success']) {
        res.statusCode = 400;
        res.json(idResult);
        return;
      }

      // Step 3: Update transaction with the ID
    } catch (e) {
      print('❌ Error in /api/ids/mark-used-with-transaction: $e');
      res.statusCode = 500;
      res.json({'success': false, 'error': e.toString()});
    }
  });

  schoolBox = await Hive.openBox<School>('school');
  _termsBox = await Hive.openBox<Terms>('terms');
  _classesBox = await Hive.openBox<Classes>('classes');
  _teacherPaymentsPurposesBox =
      await Hive.openBox<TeacherPaymentsPurposes>('teacher_payments_purposes');
  _paymentPurposesBox = await Hive.openBox<PaymentPurpose>('payment_purposes');
  _studentPaymentsBox = await Hive.openBox<StudentPayment>('student_payments');
  _teacherPaymentsBox = await Hive.openBox<TeacherPayment>('teacher_payments');
  _studentsBox = await Hive.openBox<Student>('students');
  _withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
  _teachersBox = await Hive.openBox<Teachers>('teachers');
  _domainRecordBox = await Hive.openBox<DomainRecord>('domainBox');
  _settingsBox = await Hive.openBox<Settings>('settings');
  _userBox = await Hive.openBox<User>('users'); // Open the box for users
  _accountBox = await Hive.openBox<Account>('account');
  _assetBox = await Hive.openBox<Asset>('asset');
  _projectBox = await Hive.openBox<Project>('projects');
  _projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
  _dailyActivityBox = await Hive.openBox<DailyActivity>('dailyActivities');
  _exceptionalStudentsBox =
      await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
  _productBatchBox = await Hive.openBox<ProductBatch>('product_batches');
  _batchSellUnitBox = await Hive.openBox<BatchSellUnit>('batch_sell_units');
  _projectSaleTransactionBox =
      await Hive.openBox<ProjectSaleTransaction>('project_sale_transactions');
  _paymentLogBox = await Hive.openBox<PaymentLog>('payment_log');
  await initializeSettings();

// ========================================================================

// PROJECT SALE TRANSACTION API ENDPOINTS
// ========================================================================
  /// *********************** Helper: Deep match for project sale transaction *********************/
  bool deepMatchProjectSaleTransaction(ProjectSaleTransaction t, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final fields = [
      (t.transactionCode).toLowerCase(),
      (t.studentId).toLowerCase(),
      (t.projectCode).toLowerCase(),
      (t.projectItemCode).toLowerCase(),
      (t.batchCode).toLowerCase(),
      (t.paymentMethod).toLowerCase(),
      (t.reference ?? '').toLowerCase(),
      (t.financialType).toLowerCase(),
      (t.parentTransactionCode ?? '').toLowerCase(),
    ];

    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  /// *********************** GET project sale transactions *********************/
  app.get("/api/projectSaleTransactions", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';
      final studentId = req.uri.queryParameters['studentId'];
      final projectCode = req.uri.queryParameters['projectCode'];
      final financialType = req.uri.queryParameters['financialType'];

      print('🔍 /api/projectSaleTransactions called');
      print('📋 search: "$search"');
      print('📋 studentId: "$studentId"');
      print('📋 projectCode: "$projectCode"');
      print('📋 financialType: "$financialType"');

      // Start with all transactions
      var filteredTransactions = _projectSaleTransactionBox.values
          .where((t) => t.transactionCode != null)
          .toList();

      // Filter by studentId if provided
      if (studentId != null && studentId.isNotEmpty) {
        filteredTransactions = filteredTransactions
            .where((t) => t.studentId == studentId)
            .toList();
      }

      // Filter by projectCode if provided
      if (projectCode != null && projectCode.isNotEmpty) {
        filteredTransactions = filteredTransactions
            .where((t) => t.projectCode == projectCode)
            .toList();
      }

      // Filter by financialType if provided
      if (financialType != null && financialType.isNotEmpty) {
        filteredTransactions = filteredTransactions
            .where((t) => t.financialType == financialType)
            .toList();
      }

      // Apply search filter
      if (search.isNotEmpty) {
        filteredTransactions = filteredTransactions
            .where((t) => deepMatchProjectSaleTransaction(t, search))
            .toList();
      }

      const maxResults = 100;
      final transactionJson = filteredTransactions
          .take(maxResults)
          .map(projectSaleTransactionToJson)
          .toList();

      print(
          "✅ Returning ${transactionJson.length} transactions (max $maxResults)");

      return transactionJson;
    } catch (e) {
      print("❌ Error fetching project sale transactions: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch project sale transactions"};
    }
  });

  /// *********************** GET all project sale transactions (unlimited) *********************/
  app.get("/api/projectSaleTransactions/all", (req, res) async {
    try {
      print('📘 /api/projectSaleTransactions/all called');

      // Get ALL transactions without limit
      final allTransactions = _projectSaleTransactionBox.values
          .where((t) => t.transactionCode != null)
          .toList();

      print('✅ Returning ${allTransactions.length} transactions (unlimited)');

      return allTransactions.map(projectSaleTransactionToJson).toList();
    } catch (e) {
      print("❌ Error serving all project sale transactions: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch all project sale transactions"};
    }
  });

  /// *********************** GET project sale transaction by ID *********************/
  app.get("/api/projectSaleTransactions/:id", (req, res) async {
    try {
      final transactionCode = req.params['id'];

      if (transactionCode == null || transactionCode.isEmpty) {
        res.statusCode = 400;
        return {"error": "Transaction code is required"};
      }

      ProjectSaleTransaction? transaction;
      try {
        transaction = _projectSaleTransactionBox.values.firstWhere(
          (t) => t.transactionCode == transactionCode,
        );
      } catch (e) {
        // firstWhere throws if no element matches, treat as not found
        transaction = null;
      }

      if (transaction == null) {
        res.statusCode = 404;
        return {"error": "Transaction not found"};
      }

      return projectSaleTransactionToJson(transaction);
    } catch (e) {
      print("❌ Error fetching transaction: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch transaction"};
    }
  });

  /// *********************** GET transactions by student *********************/
  app.get("/api/projectSaleTransactions/student/:studentId", (req, res) async {
    try {
      final studentId = req.params['studentId'];

      if (studentId == null || studentId.isEmpty) {
        res.statusCode = 400;
        return {"error": "Student ID is required"};
      }

      final transactions = _projectSaleTransactionBox.values
          .where((t) => t.studentId == studentId)
          .map(projectSaleTransactionToJson)
          .toList();

      print(
          '✅ Found ${transactions.length} transactions for student $studentId');

      return transactions;
    } catch (e) {
      print("❌ Error fetching student transactions: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch student transactions"};
    }
  });

  /// *********************** GET transactions by project *********************/
  app.get("/api/projectSaleTransactions/project/:projectCode",
      (req, res) async {
    try {
      final projectCode = req.params['projectCode'];

      if (projectCode == null || projectCode.isEmpty) {
        res.statusCode = 400;
        return {"error": "Project code is required"};
      }

      final transactions = _projectSaleTransactionBox.values
          .where((t) => t.projectCode == projectCode)
          .map(projectSaleTransactionToJson)
          .toList();

      print(
          '✅ Found ${transactions.length} transactions for project $projectCode');

      return transactions;
    } catch (e) {
      print("❌ Error fetching project transactions: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch project transactions"};
    }
  });

  /// *********************** GET obligation transactions for student *********************/
  app.get("/api/projectSaleTransactions/student/:studentId/obligations",
      (req, res) async {
    try {
      final studentId = req.params['studentId'];

      if (studentId == null || studentId.isEmpty) {
        res.statusCode = 400;
        return {"error": "Student ID is required"};
      }

      final obligations = _projectSaleTransactionBox.values
          .where((t) =>
              t.studentId == studentId &&
              t.createsObligation == true &&
              t.isDeleted != true)
          .map(projectSaleTransactionToJson)
          .toList();

      print('✅ Found ${obligations.length} obligations for student $studentId');

      return obligations;
    } catch (e) {
      print("❌ Error fetching student obligations: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch student obligations"};
    }
  });

  /// *********************** POST /api/projectSaleTransactions ************************/
  app.post("/api/projectSaleTransactions", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;
      final transaction = projectSaleTransactionFromJson(body);

      final key = await _projectSaleTransactionBox.add(transaction);

      return {
        "success": true,
        "key": key,
        "transaction": projectSaleTransactionToJson(transaction),
      };
    } catch (e) {
      res.statusCode = 400;
      return {
        "error": "Failed to process project sale transaction",
        "details": e.toString(),
      };
    }
  });

  /// *********************** POST /api/projectSaleTransactions/bulk ************************/
  app.post("/api/projectSaleTransactions/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('transactions') || body['transactions'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'transactions' key"
        };
      }

      final List<dynamic> transactionsJson = body['transactions'];

      final List<ProjectSaleTransaction> insertedTransactions = [];
      for (final item in transactionsJson) {
        try {
          final transaction = projectSaleTransactionFromJson(item);
          await _projectSaleTransactionBox.add(transaction);
          insertedTransactions.add(transaction);
        } catch (e) {
          print("❌ Skipping invalid transaction: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedTransactions.length,
        "insertedTransactions":
            insertedTransactions.map(projectSaleTransactionToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk project sale transactions",
        "details": e.toString(),
      };
    }
  });

  /// *********************** PUT /api/projectSaleTransactions/:id ************************/
  app.put("/api/projectSaleTransactions/:id", (req, res) async {
    try {
      final transactionCode = req.params['id'];

      if (transactionCode == null || transactionCode.isEmpty) {
        res.statusCode = 400;
        return {"error": "Transaction code is required"};
      }

      final contentType = req.headers.contentType?.mimeType;
      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      // Find the transaction by code
      final index = _projectSaleTransactionBox.values.toList().indexWhere(
            (t) => t.transactionCode == transactionCode,
          );

      if (index == -1) {
        res.statusCode = 404;
        return {"error": "Transaction not found"};
      }

      // Get existing transaction
      final existingTransaction = _projectSaleTransactionBox.getAt(index)!;

      // Update with new data (preserve fields not in update)
      final updatedTransaction = ProjectSaleTransaction(
        transactionCode: transactionCode,
        studentId: body['studentId'] ?? existingTransaction.studentId,
        projectCode: body['projectCode'] ?? existingTransaction.projectCode,
        projectItemCode:
            body['projectItemCode'] ?? existingTransaction.projectItemCode,
        batchCode: body['batchCode'] ?? existingTransaction.batchCode,
        sellUnitCode: body['sellUnitCode'] ?? existingTransaction.sellUnitCode,
        sellUnitNameSnapshot: body['sellUnitNameSnapshot'] ??
            existingTransaction.sellUnitNameSnapshot,
        quantitySold: body['quantitySold'] ?? existingTransaction.quantitySold,
        unitSellingPrice:
            body['unitSellingPrice'] ?? existingTransaction.unitSellingPrice,
        totalAmount: body['totalAmount'] ?? existingTransaction.totalAmount,
        baseUnitsPerSellUnit: body['baseUnitsPerSellUnit'] ??
            existingTransaction.baseUnitsPerSellUnit,
        totalBaseUnitsSold: body['totalBaseUnitsSold'] ??
            existingTransaction.totalBaseUnitsSold,
        baseUnit: body['baseUnit'] ?? existingTransaction.baseUnit,
        baseUnitType: body['baseUnitType'] != null
            ? StockUnitType.values.firstWhere(
                (e) => e.name == body['baseUnitType'],
                orElse: () => existingTransaction.baseUnitType,
              )
            : existingTransaction.baseUnitType,
        transactionDate: body['transactionDate'] != null
            ? DateTime.parse(body['transactionDate'])
            : existingTransaction.transactionDate,
        paymentMethod:
            body['paymentMethod'] ?? existingTransaction.paymentMethod,
        reference: body['reference'] ?? existingTransaction.reference,
        syncStatus: body['syncStatus'] ?? existingTransaction.syncStatus,
        lastModified: DateTime.now(),
        operationType: 'update',
        modifiedFields:
            body['modifiedFields'] ?? existingTransaction.modifiedFields,
        isDeleted: body['isDeleted'] ?? existingTransaction.isDeleted,
        deletedAt: existingTransaction.deletedAt,
        restoredAt: existingTransaction.restoredAt,
        deletedByUsers: existingTransaction.deletedByUsers,
        restoredByUsers: existingTransaction.restoredByUsers,
        amountPaid: body['amountPaid'] ?? existingTransaction.amountPaid,
        arrears: body['arrears'] ?? existingTransaction.arrears,
        paymentMethodCode:
            body['paymentMethodCode'] ?? existingTransaction.paymentMethodCode,
        methodType: body['methodType'] ?? existingTransaction.methodType,
        amountPaidInPaymentMethod: body['amountPaidInPaymentMethod'] ??
            existingTransaction.amountPaidInPaymentMethod,
        currency: body['currency'] ?? existingTransaction.currency,
        provider: body['provider'] ?? existingTransaction.provider,
        referenceNumber:
            body['referenceNumber'] ?? existingTransaction.referenceNumber,
        phoneNumber: body['phoneNumber'] ?? existingTransaction.phoneNumber,
        accountNumber:
            body['accountNumber'] ?? existingTransaction.accountNumber,
        accountName: body['accountName'] ?? existingTransaction.accountName,
        paymentDatetransacted: body['paymentDatetransacted'] != null
            ? DateTime.parse(body['paymentDatetransacted'])
            : existingTransaction.paymentDatetransacted,
        isReversed: body['isReversed'] ?? existingTransaction.isReversed,
        lineTransactionCodes: body['lineTransactionCodes'] ??
            existingTransaction.lineTransactionCodes,
        financialType:
            body['financialType'] ?? existingTransaction.financialType,
        parentTransactionCode: body['parentTransactionCode'] ??
            existingTransaction.parentTransactionCode,
        affectsStock: body['affectsStock'] ?? existingTransaction.affectsStock,
        createsObligation:
            body['createsObligation'] ?? existingTransaction.createsObligation,
        settlesObligation:
            body['settlesObligation'] ?? existingTransaction.settlesObligation,
      );

      await _projectSaleTransactionBox.putAt(index, updatedTransaction);

      return {
        "success": true,
        "transaction": projectSaleTransactionToJson(updatedTransaction),
      };
    } catch (e) {
      print("❌ Error updating transaction: $e");
      res.statusCode = 500;
      return {
        "error": "Failed to update transaction",
        "details": e.toString(),
      };
    }
  });

  /// *********************** DELETE /api/projectSaleTransactions/:id ************************/
  app.delete("/api/projectSaleTransactions/:id", (req, res) async {
    try {
      final transactionCode = req.params['id'];

      if (transactionCode == null || transactionCode.isEmpty) {
        res.statusCode = 400;
        return {"error": "Transaction code is required"};
      }

      // Find the transaction by code
      final index = _projectSaleTransactionBox.values.toList().indexWhere(
            (t) => t.transactionCode == transactionCode,
          );

      if (index == -1) {
        res.statusCode = 404;
        return {"error": "Transaction not found"};
      }

      // Soft delete - mark as deleted
      final transaction = _projectSaleTransactionBox.getAt(index)!;
      transaction.isDeleted = true;
      transaction.deletedAt ??= [];
      transaction.deletedAt!.add(DateTime.now());
      transaction.lastModified = DateTime.now();
      transaction.operationType = 'delete';
      await transaction.save();

      return {
        "success": true,
        "message": "Transaction marked as deleted",
        "transactionCode": transactionCode,
      };
    } catch (e) {
      print("❌ Error deleting transaction: $e");
      res.statusCode = 500;
      return {
        "error": "Failed to delete transaction",
        "details": e.toString(),
      };
    }
  });

  /// *********************** PATCH /api/projectSaleTransactions/:id/restore ************************/
  app.patch("/api/projectSaleTransactions/:id/restore", (req, res) async {
    try {
      final transactionCode = req.params['id'];

      if (transactionCode == null || transactionCode.isEmpty) {
        res.statusCode = 400;
        return {"error": "Transaction code is required"};
      }

      // Find the transaction by code
      final index = _projectSaleTransactionBox.values.toList().indexWhere(
            (t) => t.transactionCode == transactionCode,
          );

      if (index == -1) {
        res.statusCode = 404;
        return {"error": "Transaction not found"};
      }

      // Restore - mark as not deleted
      final transaction = _projectSaleTransactionBox.getAt(index)!;
      transaction.isDeleted = false;
      transaction.restoredAt ??= [];
      transaction.restoredAt!.add(DateTime.now());
      transaction.lastModified = DateTime.now();
      transaction.operationType = 'restore';
      await transaction.save();

      return {
        "success": true,
        "message": "Transaction restored successfully",
        "transactionCode": transactionCode,
      };
    } catch (e) {
      print("❌ Error restoring transaction: $e");
      res.statusCode = 500;
      return {
        "error": "Failed to restore transaction",
        "details": e.toString(),
      };
    }
  });

  /// *********************** POST /api/projectSaleTransactions/mark-paid ************************/
  app.post("/api/projectSaleTransactions/mark-paid", (req, res) async {
    try {
      final body = await req.bodyAsJsonMap;
      final transactionCode = body['transactionCode'];
      final amountPaid = body['amountPaid'] as double?;

      if (transactionCode == null || transactionCode.isEmpty) {
        res.statusCode = 400;
        return {"error": "Transaction code is required"};
      }

      if (amountPaid == null || amountPaid <= 0) {
        res.statusCode = 400;
        return {"error": "Valid amount paid is required"};
      }

      // Find the transaction by code
      final index = _projectSaleTransactionBox.values.toList().indexWhere(
            (t) => t.transactionCode == transactionCode,
          );

      if (index == -1) {
        res.statusCode = 404;
        return {"error": "Transaction not found"};
      }

      final transaction = _projectSaleTransactionBox.getAt(index)!;
      transaction.amountPaid = (transaction.amountPaid ?? 0) + amountPaid;
      transaction.arrears = (transaction.totalAmount - transaction.amountPaid)
          .clamp(0, double.infinity);
      transaction.lastModified = DateTime.now();
      transaction.operationType = 'update';
      await transaction.save();

      return {
        "success": true,
        "transaction": projectSaleTransactionToJson(transaction),
      };
    } catch (e) {
      print("❌ Error marking transaction as paid: $e");
      res.statusCode = 500;
      return {
        "error": "Failed to mark transaction as paid",
        "details": e.toString(),
      };
    }
  });

////////////////////////////////batchSellUnit api////////////////////

  //***********************get batchSellUnit method *********************/

  bool deepMatchsellUnit(BatchSellUnit u, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final fields = [
      (u.sellUnitCode).toLowerCase(),
      (u.unitName).toLowerCase(),
      (u.baseUnit ?? '').toLowerCase(),
    ];

    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  app.get("/api/batchSellUnit", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';

      print('🔍 /api/batchSellUnit called with search="$search"');

      final filteredbatchSellUnit = _batchSellUnitBox.values
          .where((u) => deepMatchsellUnit(u, search))
          .toList();

      const maxResults = 100;
      final batchSellUnitJson = filteredbatchSellUnit
          .take(maxResults)
          .map(batchSellUnitToJson)
          .toList();

      print("✅ Returning ${batchSellUnitJson.length} units (max $maxResults)");

      return batchSellUnitJson;
    } catch (e) {
      print("❌ Error fetching sell units: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch sell units"};
    }
  });
  //************************* POST /api/batchSellUnit ************************/

  app.post("/api/batchSellUnit", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      // Parse body safely
      final body = await req.bodyAsJsonMap;

      final batchSellUnits = batchSellUnitFromJson(body);

      // Save to Hive (or any backend storage you use)
      final key = await _batchSellUnitBox.add(batchSellUnits);

      // Return success with serialized data
      return {
        "success": true,
        "key": key,
        "batchSellUnit": batchSellUnitToJson(batchSellUnits),
      };
    } catch (e) {
      res.statusCode = 400;
      return {
        "error": "Failed to process product batch sell unit",
        "details": e.toString(),
      };
    }
  });

  //************************* POST /api/batchSellUnit/bulk ************************/

  app.post("/api/batchSellUnit/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('batchSellUnits') ||
          body['batchSellUnits'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'batchSellUnits' key"
        };
      }

      final List<dynamic> batchSellUnitsJson = body['batchSellUnits'];

      final List<BatchSellUnit> insertedBatches = [];
      for (final item in batchSellUnitsJson) {
        try {
          final batchSellUnit = batchSellUnitFromJson(item);
          await _batchSellUnitBox.add(batchSellUnit);
          insertedBatches.add(batchSellUnit);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid BatchSellUnit: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedBatches.length,
        "insertedBatches": insertedBatches.map(batchSellUnitToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk product batch unit sell",
        "details": e.toString(),
      };
    }
  });

////////////////////////////////ProductBatch api////////////////////

  //***********************get ProductBatch method *********************/
  app.get("/api/productBatches", (req, res) async {
    try {
      final productBatchesJsonList = _productBatchBox.values
          .where((productBatch) => productBatch.batchCode != null)
          .map(productBatchesToJson)
          .toList();

      return productBatchesJsonList;
    } catch (e) {
      print("Error serving productBatches data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch productBatches info"};
    }
  });

  //************************* POST /api/productBatches ************************/

  app.post("/api/productBatches", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      // Parse body safely
      final body = await req.bodyAsJsonMap;

      // Deserialize the incoming JSON into a ProductBatch object
      final productBatches = productBatchesFromJson(body);

      // Save to Hive (or any backend storage you use)
      final key = await _productBatchBox.add(productBatches);

      // Return success with serialized data
      return {
        "success": true,
        "key": key,
        "productBatch": productBatchesToJson(productBatches),
      };
    } catch (e) {
      res.statusCode = 400;
      return {
        "error": "Failed to process product batch",
        "details": e.toString(),
      };
    }
  });

  //************************* POST /api/productBatches/bulk ************************/

  app.post("/api/productBatches/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('batches') || body['batches'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'batches' key"
        };
      }

      final List<dynamic> batchesJson = body['batches'];

      final List<ProductBatch> insertedBatches = [];
      for (final item in batchesJson) {
        try {
          final batch = productBatchesFromJson(item);
          await _productBatchBox.add(batch);
          insertedBatches.add(batch);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid batch: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedBatches.length,
        "insertedBatches": insertedBatches.map(productBatchesToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk product batches",
        "details": e.toString(),
      };
    }
  });

  //************************* POST /api/exceptionalStudents/bulk ************************/

  app.get("/api/exceptionalStudents", (req, res) async {
    try {
      final exceptionalStudentsJsonList = _exceptionalStudentsBox.values
          .where((schoolItem) => schoolItem.exceptionId != null)
          .map(exceptionalStudentsToJson)
          .toList();

      return exceptionalStudentsJsonList;
    } catch (e) {
      print("Error serving exceptionalStudents data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch exceptionalStudents info"};
    }
  });

  //************************* POST /api/exceptionalStudents/bulk ************************/

  app.post("/api/exceptionalStudents/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('exceptions') || body['exceptions'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'exceptions' key"
        };
      }

      final List<dynamic> exceptionsJson = body['exceptions'];

      final List<ExceptionalStudents> insertedExceptions = [];
      for (final item in exceptionsJson) {
        try {
          final exception = exceptionalStudentsFromJson(item);
          await _exceptionalStudentsBox.add(exception);
          insertedExceptions.add(exception);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid exception: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedExceptions.length,
        "insertedExceptions":
            insertedExceptions.map(exceptionalStudentsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk exceptions",
        "details": e.toString(),
      };
    }
  });

  ////////////////////////////////dailyActivities api////////////////////

  //***********************get dailyActivities method *********************/
  app.get("/api/dailyActivities", (req, res) async {
    try {
      final dailyActivitiesJsonList = _dailyActivityBox.values
          .where((schoolItem) => schoolItem.projectDailyActiviyCode != null)
          .map(dailyActivitiesToJson)
          .toList();

      return dailyActivitiesJsonList;
    } catch (e) {
      print("Error serving dailyActivities data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch dailyActivities info"};
    }
  });

  //************************* POST /api/dailyActivity/bulk ************************/

  app.post("/api/dailyActivities/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('dailyactivities') ||
          body['dailyactivities'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'dailyactivities' key"
        };
      }

      final List<dynamic> dailyactivitiesJson = body['dailyactivities'];

      final List<DailyActivity> insertedDailyactivities = [];
      for (final item in dailyactivitiesJson) {
        try {
          final dailyActivity = dailyActivitiesFromJson(item);
          await _dailyActivityBox.add(dailyActivity);
          insertedDailyactivities.add(dailyActivity);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid dailyActivity: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedDailyactivities.length,
        "insertedDailyactivities":
            insertedDailyactivities.map(dailyActivitiesToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk dailyactivities",
        "details": e.toString(),
      };
    }
  });

  ////////////////////////////////asset api////////////////////

  //***********************get asset method *********************/
  app.get("/api/asset", (req, res) async {
    try {
      final assetJsonList = _assetBox.values
          .where((schoolItem) => schoolItem.assetCode != null)
          .map(assetToJson)
          .toList();

      return assetJsonList;
    } catch (e) {
      print("Error serving asset data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch asset info"};
    }
  });

  //************************* POST /api/asset/bulk ************************/

  app.post("/api/asset/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('assets') || body['assets'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'assets' key"
        };
      }

      final List<dynamic> assetsJson = body['assets'];

      final List<Asset> insertedAssets = [];
      for (final item in assetsJson) {
        try {
          final asset = assetFromJson(item);
          await _assetBox.add(asset);
          insertedAssets.add(asset);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid asset: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedAssets.length,
        "insertedAssets": insertedAssets.map(assetToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk assets",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////account api////////////////////

  //***********************get account method *********************/
  app.get("/api/account", (req, res) async {
    try {
      final accountJsonList = _accountBox.values
          .where((schoolItem) => schoolItem.accountCode != null)
          .map(accountToJson)
          .toList();

      return accountJsonList;
    } catch (e) {
      print("Error serving account data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch account info"};
    }
  });

  //************************* POST /api/account/bulk ************************/

  app.post("/api/account/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('accounts') || body['accounts'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'accounts' key"
        };
      }

      final List<dynamic> accountsJson = body['accounts'];

      final List<Account> insertedAccounts = [];
      for (final item in accountsJson) {
        try {
          final account = accountFromJson(item);
          await _accountBox.add(account);
          insertedAccounts.add(account);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid account: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedAccounts.length,
        "insertedAccounts": insertedAccounts.map(accountToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk accounts",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////users api////////////////////
  bool deepMatchUser(User u, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final fields = [
      (u.username).toLowerCase(),
      (u.phone).toLowerCase(),
      (u.email ?? '').toLowerCase(),
      (u.role).toLowerCase(),
    ];

    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  /// ************************ GET all users for client sync ************************
  app.get("/api/users/all", (req, res) async {
    print("📥 /api/users/all called");

    try {
      final box = _userBox;
      print("📦 User box length: ${box.length}");

      final usersJson = <Map<String, dynamic>>[];

      for (var u in box.values) {
        try {
          final json = usersToJson(u);
          usersJson.add(json);
        } catch (e) {
          print("❌ JSON encode failed for user ${u.username}: $e");
        }
      }

      print("✅ Returning ${usersJson.length} users out of ${box.length}");
      return usersJson;
    } catch (e, st) {
      print("❌ SERVER CRASH in /api/users/all: $e");
      print(st);
      res.statusCode = 500;
      return {"error": "$e"};
    }
  });

  /// ************************ GET all users ************************
  app.get("/api/users", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';

      print('🔍 /api/users called with search="$search"');

      final filteredUsers =
          _userBox.values.where((u) => deepMatchUser(u, search)).toList();

      const maxResults = 100;
      final usersJson =
          filteredUsers.take(maxResults).map(usersToJson).toList();

      print("✅ Returning ${usersJson.length} users (max $maxResults)");

      return usersJson;
    } catch (e) {
      print("❌ Error fetching users: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch users"};
    }
  });

  /// *********************** POST /api/users/bulk ************************
  app.post("/api/users/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != "application/json") {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('users') || body['users'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected 'users': [ ... ]"
        };
      }

      final List<dynamic> usersJson = body['users'];

      final List<User> insertedUsers = [];
      for (final item in usersJson) {
        try {
          final user = usersFromJson(item);
          await _userBox.add(user);
          insertedUsers.add(user);
        } catch (e) {
          print("⚠️ Skipping invalid user entry: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedUsers.length,
        "insertedUsers": insertedUsers.map(usersToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk users",
        "details": e.toString(),
      };
    }
  });

  /// ************************ GET /api/users/:id ************************
  app.get("/api/users/:id", (req, res) async {
    try {
      final id = int.tryParse(req.params['id'] ?? "");

      if (id == null) {
        res.statusCode = 400;
        return {"error": "Invalid ID"};
      }

      final user = _userBox.values.firstWhere(
        (u) => u.id == id,
        orElse: () => User(
          id: -1,
          username: '',
          phone: '',
          email: '',
          role: '',
          password: '',
          securityQuestions: const [],
          securityAnswers: const [],
        ),
      );

      if (user.id == -1) {
        res.statusCode = 404;
        return {"error": "User not found"};
      }

      return usersToJson(user);
    } catch (e) {
      res.statusCode = 500;
      return {"error": "Failed to fetch user", "details": e.toString()};
    }
  });
// ***************************projects **********************

////////////////////////////////projects api////////////////////
  bool deepMatchProjects(Project u, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final fields = [
      (u.name).toLowerCase(),
      (u.projectType).toLowerCase(),
      (u.status).toLowerCase(),
    ];

    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  /// ************************ GET all projects for client sync ************************
  app.get("/api/projects/all", (req, res) async {
    print("📥 /api/projects/all called");

    try {
      final box = _projectBox;
      print("📦 Project box length: ${box.length}");

      final projectsJson = <Map<String, dynamic>>[];

      for (var u in box.values) {
        try {
          final json = projectsToJson(u);
          projectsJson.add(json);
        } catch (e) {
          print("❌ JSON encode failed for projects ${u.name}: $e");
        }
      }

      print("✅ Returning ${projectsJson.length} projects out of ${box.length}");
      return projectsJson;
    } catch (e, st) {
      print("❌ SERVER CRASH in /api/projects/all: $e");
      print(st);
      res.statusCode = 500;
      return {"error": "$e"};
    }
  });

  /// ************************ GET all projects ************************
  app.get("/api/projects", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';

      print('🔍 /api/projects called with search="$search"');

      final filteredProjects = _projectBox.values
          .where((u) => deepMatchProjects(u, search))
          .toList();

      const maxResults = 100;
      final projectsJson =
          filteredProjects.take(maxResults).map(projectsToJson).toList();

      print("✅ Returning ${projectsJson.length} projects (max $maxResults)");

      return projectsJson;
    } catch (e) {
      print("❌ Error fetching projects: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch projects"};
    }
  });

  /// *********************** POST /api/projects/bulk ************************
  app.post("/api/projects/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != "application/json") {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('projects') || body['projects'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected 'projects': [ ... ]"
        };
      }

      final List<dynamic> projectsJson = body['projects'];

      final List<Project> insertedProjects = [];
      for (final item in projectsJson) {
        try {
          final project = projectsFromJson(item);
          await _projectBox.add(project);
          insertedProjects.add(project);
        } catch (e) {
          print("⚠️ Skipping invalid project entry: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedProjects.length,
        "insertedProjects": insertedProjects.map(projectsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk projects",
        "details": e.toString(),
      };
    }
  });

  /// ************************ GET /api/projects/:id ************************
  app.get("/api/projects/:id", (req, res) async {
    try {
      final projectCode = int.tryParse(req.params['projectCode'] ?? "");

      if (projectCode == null) {
        res.statusCode = 400;
        return {"error": "Invalid projectCode"};
      }

      final project = _projectBox.values.firstWhere(
        (u) => u.projectCode == projectCode.toString(),
        orElse: () => Project(
          projectCode: '-1',
          name: '',
          status: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          projectType: '',
          participationType: '',
          // Add other required fields with default values if needed
        ),
      );

      if (project.projectCode == '-1') {
        res.statusCode = 404;
        return {"error": "User not found"};
      }

      return projectsToJson(project);
    } catch (e) {
      res.statusCode = 500;
      return {"error": "Failed to fetch project", "details": e.toString()};
    }
  });

  // ***************************project items **********************

////////////////////////////////project Items api////////////////////
  bool deepMatchProjectItems(ProjectItem u, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final fields = [
      (u.name!).toLowerCase(),
      (u.itemType!).toLowerCase(),
      (u.projectItemCode!).toLowerCase(),
    ];

    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  /// ************************ GET all project items for client sync ************************
  app.get("/api/projectItems/all", (req, res) async {
    print("📥 /api/projectItems/all called");

    try {
      final box = _projectItemBox;
      print("📦 Project item box length: ${box.length}");

      final projectItemsJson = <Map<String, dynamic>>[];

      for (var u in box.values) {
        try {
          final json = projectItemsToJson(u);
          projectItemsJson.add(json);
        } catch (e) {
          print("❌ JSON encode failed for project items ${u.name}: $e");
        }
      }

      print(
          "✅ Returning ${projectItemsJson.length} project items out of ${box.length}");
      return projectItemsJson;
    } catch (e, st) {
      print("❌ SERVER CRASH in /api/projectItems/all: $e");
      print(st);
      res.statusCode = 500;
      return {"error": "$e"};
    }
  });

  /// ************************ GET all project items ************************
  app.get("/api/projectItems", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';

      print('🔍 /api/projectItems called with search="$search"');

      final filteredProjectItems = _projectItemBox.values
          .where((u) => deepMatchProjectItems(u, search))
          .toList();

      const maxResults = 100;
      final projectItemsJson = filteredProjectItems
          .take(maxResults)
          .map(projectItemsToJson)
          .toList();

      print(
          "✅ Returning ${projectItemsJson.length} project items (max $maxResults)");

      return projectItemsJson;
    } catch (e) {
      print("❌ Error fetching project items: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch project items"};
    }
  });

  /// *********************** POST /api/projectItems/bulk ************************
  app.post("/api/projectItems/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != "application/json") {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('projectItems') || body['projectItems'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected 'projectItems': [ ... ]"
        };
      }

      final List<dynamic> projectItemsJson = body['projectItems'];

      final List<ProjectItem> insertedProjectItems = [];
      for (final item in projectItemsJson) {
        try {
          final projectItem = projectItemsFromJson(item);
          await _projectItemBox.add(projectItem);
          insertedProjectItems.add(projectItem);
        } catch (e) {
          print("⚠️ Skipping invalid project item entry: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedProjectItems.length,
        "insertedProjectItems":
            insertedProjectItems.map(projectItemsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk project items",
        "details": e.toString(),
      };
    }
  });

  /// ************************ GET /api/projectItems/:id ************************
  app.get("/api/projectItems/:id", (req, res) async {
    try {
      final projectItemCode = int.tryParse(req.params['projectItemCode'] ?? "");

      if (projectItemCode == null) {
        res.statusCode = 400;
        return {"error": "Invalid projectItemCode"};
      }

      final projectItem = _projectItemBox.values.firstWhere(
        (u) => u.projectItemCode.toString() == projectItemCode.toString(),
        orElse: () => ProjectItem(
          projectItemCode: '-1',
          name: '',
          itemType: '',

          // Add other required fields with default values if needed
        ),
      );

      if (projectItem.projectItemCode == '-1') {
        res.statusCode = 404;
        return {"error": "User not found"};
      }

      return projectItemsToJson(projectItem);
    } catch (e) {
      res.statusCode = 500;
      return {"error": "Failed to fetch project", "details": e.toString()};
    }
  });

  /// ************************ LOGIN ************************
  app.post("/api/users/login", (req, res) async {
    try {
      final body = await req.bodyAsJsonMap;
      final username = body['username'];
      final password = body['password'];

      if (username == null || password == null) {
        res.statusCode = 400;
        return {"error": "Missing username or password"};
      }

      final user = _userBox.values.firstWhere(
        (u) => u.username == username && u.password == password,
        orElse: () => User(
          id: -1,
          username: '',
          phone: '',
          email: '',
          role: '',
          password: '',
          securityQuestions: const [],
          securityAnswers: const [],
        ),
      );

      if (user == null) {
        res.statusCode = 401;
        return {"error": "Invalid credentials"};
      }

      return {"success": true, "user": usersToJson(user)};
    } catch (e) {
      res.statusCode = 500;
      return {"error": "Login error", "details": e.toString()};
    }
  });

  /// ************************ UPDATE USER ************************
  app.put("/api/users/update", (req, res) async {
    try {
      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('id')) {
        res.statusCode = 400;
        return {"error": "Missing user ID"};
      }

      final int id = body['id'];

      final index = _userBox.values.toList().indexWhere((u) => u.id == id);
      if (index == -1) {
        res.statusCode = 404;
        return {"error": "User not found"};
      }

      final existing = _userBox.getAt(index)!;
      final updated = usersFromJson(body);

      await _userBox.putAt(index, updated);

      return {"success": true, "updatedUser": usersToJson(updated)};
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to update user",
        "details": e.toString(),
      };
    }
  });

//////////////////////////////// RECEIPT LOG API ////////////////////////////////

  bool deepMatchReceipt(PaymentLog r, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final fields = [
      r.studentName.toLowerCase(),
      r.className.toLowerCase(),
      r.receiptNumber.toString(),
      r.dateTime.toLowerCase(),
    ];

    return parts.every((part) => fields.any((f) => f.contains(part)));
  }

//////////////////////////////////////////////////////////////////////////////////////////

  /// ************************ GET all receipt logs (unlimited) ************************
  app.get("/api/receipt_logs/all", (req, res) async {
    try {
      debugPrint('📘 /api/receipt_logs/all called');

      // Get ALL receipt logs without limit
      final allLogs = _paymentLogBox.values
          .where((log) => log.receiptNumber != null)
          .toList();

      debugPrint('✅ Returning ${allLogs.length} receipt logs (unlimited)');

      return allLogs.map(paymentLogToJson).toList();
    } catch (e) {
      print("❌ Error serving all receipt logs data: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch all receipt logs info"};
    }
  });

  /// ************************ GET receipt logs with search ************************
  app.get("/api/receipt_logs", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';
      final studentName =
          req.uri.queryParameters['studentName']?.toLowerCase().trim() ?? '';
      final className =
          req.uri.queryParameters['className']?.toLowerCase().trim() ?? '';
      final fromDate = req.uri.queryParameters['fromDate'];
      final toDate = req.uri.queryParameters['toDate'];

      debugPrint('📘 /api/receipt_logs called');
      debugPrint('  search: "$search"');
      debugPrint('  studentName: "$studentName"');
      debugPrint('  className: "$className"');

      // Start with all logs
      var filteredLogs = _paymentLogBox.values
          .where((log) => log.receiptNumber != null)
          .toList();

      // Apply filters
      if (search.isNotEmpty) {
        filteredLogs = filteredLogs
            .where((log) =>
                log.studentName.toLowerCase().contains(search) ||
                log.className.toLowerCase().contains(search) ||
                log.receiptNumber.toString().contains(search) ||
                log.dateTime.toLowerCase().contains(search))
            .toList();
      }

      if (studentName.isNotEmpty) {
        filteredLogs = filteredLogs
            .where((log) => log.studentName.toLowerCase().contains(studentName))
            .toList();
      }

      if (className.isNotEmpty) {
        filteredLogs = filteredLogs
            .where((log) => log.className.toLowerCase().contains(className))
            .toList();
      }

      if (fromDate != null) {
        final fromDateTime = DateTime.parse(fromDate);
        filteredLogs = filteredLogs.where((log) {
          final logDate = DateTime.tryParse(log.dateTime);
          return logDate != null && logDate.isAfter(fromDateTime);
        }).toList();
      }

      if (toDate != null) {
        final toDateTime = DateTime.parse(toDate);
        filteredLogs = filteredLogs.where((log) {
          final logDate = DateTime.tryParse(log.dateTime);
          return logDate != null && logDate.isBefore(toDateTime);
        }).toList();
      }

      // Sort by receipt number descending (newest first)
      filteredLogs.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));

      const maxResults = 100;
      final logsJson =
          filteredLogs.take(maxResults).map(paymentLogToJson).toList();

      debugPrint(
          '✅ Returning ${logsJson.length} receipt logs (max $maxResults)');

      return logsJson;
    } catch (e) {
      print("❌ Error serving receipt logs data: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch receipt logs info"};
    }
  });

  /// ************************ POST /api/receipt_logs/bulk ************************/
  app.post("/api/receipt_logs/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('logs') || body['logs'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'logs' key"
        };
      }

      final List<dynamic> logsJson = body['logs'];

      final List<PaymentLog> insertedLogs = [];
      for (final item in logsJson) {
        try {
          final log = paymentLogFromJson(item);
          await _paymentLogBox.add(log);
          insertedLogs.add(log);
        } catch (e) {
          print("❌ Skipping invalid log: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedLogs.length,
        "insertedLogs": insertedLogs.map(paymentLogToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk receipt logs",
        "details": e.toString(),
      };
    }
  });

  /// GET /api/receipt_logs
//////////////////////////////////////////////////////////////////////////////////////////

  app.get("/api/receipt_logs", (req, res) async {
    try {
      final query =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';
      print('🔍 /api/receipt_logs called with search="$query"');

      final box = Hive.box<PaymentLog>("payment_log");
      final logs = box.values.toList();

      print("📦 Total logs in box = ${logs.length}");

      final filtered = logs.where((r) => deepMatchReceipt(r, query)).toList();

      const maxResults = 200;
      final limited = filtered.take(maxResults).toList();

      print("✅ Returning ${limited.length} receipt logs (max=$maxResults)");

      return limited.map(paymentLogToJson).toList();
    } catch (e, s) {
      print("❌ Error fetching receipt logs: $e");
      print(s);
      res.statusCode = 500;
      return {"error": "Failed to fetch receipt logs"};
    }
  });

//////////////////////////////////////////////////////////////////////////////////////////
  /// POST /api/receipt_logs/bulk
//////////////////////////////////////////////////////////////////////////////////////////

  app.post("/api/receipt_logs/bulk", (req, res) async {
    try {
      final type = req.headers.contentType?.mimeType;

      if (type != "application/json") {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('logs') || body['logs'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid format",
          "details": "Expected 'logs': [ ... ]"
        };
      }

      final List<dynamic> list = body['logs'];
      final box = Hive.box<PaymentLog>("payment_log");

      final List<PaymentLog> inserted = [];

      for (final item in list) {
        try {
          final log = paymentLogFromJson(item);
          await box.add(log);
          inserted.add(log);
        } catch (e) {
          print("⚠️ Skipping invalid receipt entry: $e");
        }
      }

      print("📥 Inserted ${inserted.length} receipt logs");

      return {
        "success": true,
        "insertedCount": inserted.length,
        "logs": inserted.map(paymentLogToJson).toList(),
      };
    } catch (e, s) {
      print("❌ Bulk insert error: $e");
      print(s);
      res.statusCode = 500;
      return {
        "error": "Failed to insert receipt logs",
        "details": e.toString(),
      };
    }
  });

  ////////////////////////////////domains api////////////////////

  //***********************get domains method *********************/
  app.get("/api/domains", (req, res) async {
    try {
      final domainsJsonList = _domainRecordBox.values
          .where((schoolItem) => schoolItem.domainName != null)
          .map(domainsToJson)
          .toList();

      return domainsJsonList;
    } catch (e) {
      print("Error serving domains data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch domains info"};
    }
  });

  //************************* POST /api/domains/bulk ************************/

  app.post("/api/domains/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('domains') || body['domains'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'domains' key"
        };
      }

      final List<dynamic> domainsJson = body['domains'];

      final List<DomainRecord> insertedDomains = [];
      for (final item in domainsJson) {
        try {
          final domains = domainsFromJson(item);
          await _domainRecordBox.add(domains);
          insertedDomains.add(domains);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid domains: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedDomains.length,
        "insertedDomains": insertedDomains.map(domainsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk domains",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////teachers api////////////////////

  //***********************get teachers method *********************/
  app.get("/api/teachers", (req, res) async {
    try {
      final teachersJsonList = _teachersBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(teachersToJson)
          .toList();

      return teachersJsonList;
    } catch (e) {
      print("Error serving teachers data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch teachers info"};
    }
  });

  //************************* POST /api/teachers/bulk ************************/

  app.post("/api/teachers/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('teachers') || body['teachers'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'teachers' key"
        };
      }

      final List<dynamic> teachersJson = body['teachers'];

      final List<Teachers> insertedTeachers = [];
      for (final item in teachersJson) {
        try {
          final teachers = teachersFromJson(item);
          await _teachersBox.add(teachers);
          insertedTeachers.add(teachers);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid teachers: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedTeachers.length,
        "insertedTeachers": insertedTeachers.map(teachersToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk teachers",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////withdrawals api////////////////////

  //***********************get withdrawals method *********************/
  app.get("/api/withdrawals", (req, res) async {
    try {
      final withdrawalsJsonList = _withdrawalsBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(withdrawalsToJson)
          .toList();

      return withdrawalsJsonList;
    } catch (e) {
      print("Error serving withdrawals data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch withdrawals info"};
    }
  });

  //************************* POST /api/withdrawal/bulk ************************/

  app.post("/api/withdrawals/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('withdrawals') || body['withdrawals'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'withdrawals' key"
        };
      }

      final List<dynamic> withdrawalsJson = body['withdrawals'];

      final List<Withdrawal> insertedWithdrawals = [];
      for (final item in withdrawalsJson) {
        try {
          final withdrawal = withdrawalsFromJson(item);
          await _withdrawalsBox.add(withdrawal);
          insertedWithdrawals.add(withdrawal);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid withdrawal: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedWithdrawals.length,
        "insertedWithdrawals":
            insertedWithdrawals.map(withdrawalsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk withdrawals",
        "details": e.toString(),
      };
    }
  });

  bool isStudentEligibleForRegister(Student s, DateTime registerDate) {
    // Must be enrolled
    if (s.enrollmentStatus != 'active') return false;

    // Must belong to a term
    if (s.termId == null) return false;

    // If new comer, respect allowed range
    if (s.isNewComer == true) {
      if (s.isNewComerFrom != null &&
          registerDate.isBefore(s.isNewComerFrom!)) {
        return false;
      }

      if (s.isNewComerUntil != null &&
          registerDate.isAfter(s.isNewComerUntil!)) {
        return false;
      }
    }

    return true;
  }

  Map<String, bool> resolveAttendanceState(Student s, DateTime registerDate) {
    final dayKey = DateTime(
      registerDate.year,
      registerDate.month,
      registerDate.day,
    );

    final isPresent = s.presentDates.any((d) =>
        d.year == dayKey.year &&
        d.month == dayKey.month &&
        d.day == dayKey.day);

    final isAbsent = s.absentDates.any((d) =>
        d.year == dayKey.year &&
        d.month == dayKey.month &&
        d.day == dayKey.day);

    return {
      'isPresent': isPresent,
      'isAbsent': isAbsent,
    };
  }

  ///////////

  ///************************ GET all students ************************
  bool deepMatchStudent(Student s, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+')); // split by spaces

    // Collect all searchable fields
    final fields = [
      (s.name ?? '').toLowerCase(),
      (s.surname ?? '').toLowerCase(),
      ('${s.name ?? ''} ${s.surname ?? ''}').toLowerCase(),
      (s.studentIdNumber ?? '').toLowerCase(),
      (s.class_ ?? '').toLowerCase(),
      // Add more fields if needed
    ];

    // Every part of the search query must match **at least one field**
    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  app.get("/api/students/registers", (req, res) async {
    try {
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';

      final selectedClass = req.uri.queryParameters['class']?.trim();

      final dateParam = req.uri.queryParameters['date'];
      final registerDate =
          dateParam != null ? DateTime.parse(dateParam) : DateTime.now();

      debugPrint(
          '📘 /api/students | class=$selectedClass | date=$registerDate | search="$search"');

      final students = _studentsBox.values
          .where((s) => s.termId != null)
          .where((s) => selectedClass == null || s.class_ == selectedClass)
          .where((s) => deepMatchStudent(s, search))
          .where((s) => isStudentEligibleForRegister(s, registerDate))
          .toList();

      const maxResults = 100;

      final response = students.take(maxResults).map((s) {
        final attendance = resolveAttendanceState(s, registerDate);

        return {
          ...studentsToJson(s),
          'register': {
            'date': registerDate.toIso8601String(),
            'isPresent': attendance['isPresent'],
            'isAbsent': attendance['isAbsent'],
            'canMark': true,
          }
        };
      }).toList();

      debugPrint('✅ Register-ready students: ${response.length}');

      return response;
    } catch (e) {
      print("❌ Error serving register students: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch register-ready students"};
    }
  });

  DateTime normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  app.put('/api/students/:studentId/register', (req, res) async {
    try {
      final studentId = req.params['studentId'];
      final body = await req.bodyAsJsonMap;

      final dateStr = body['date'];
      final status = body['status'];

      if (dateStr == null || status == null) {
        res.statusCode = 400;
        return {'error': 'date and status are required'};
      }

      final index = _studentsBox.values.toList().indexWhere(
            (s) => s.studentIdNumber == studentId,
          );

      if (index == -1) {
        res.statusCode = 404;
        return {'error': 'Student not found'};
      }

      final student = _studentsBox.getAt(index)!;
      final date = normalizeDate(DateTime.parse(dateStr));

      // Remove existing marks for the day
      student.presentDates.removeWhere((d) => sameDay(d, date));
      student.absentDates.removeWhere((d) => sameDay(d, date));

      // Apply status
      if (status == 'present') {
        student.presentDates.add(date);
        student.isPresent = true;
      } else if (status == 'absent') {
        student.absentDates.add(date);
        student.isPresent = false;
      } else if (status != 'clear') {
        res.statusCode = 400;
        return {'error': 'Invalid status value'};
      }

      // Sync metadata
      student.lastModified = DateTime.now();
      student.syncStatus = false; // dirty
      student.operationType = 'attendance';

      await student.save();

      return {
        'success': true,
        'studentId': student.studentIdNumber,
        'date': date.toIso8601String(),
        'status': status,
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        'error': 'Failed to mark register',
        'details': e.toString(),
      };
    }
  });

  app.post("/api/register/mark/bulk", (req, res) async {
    try {
      final body = await req.bodyAsJsonMap;

      final String className = body['className'];
      final String termId = body['termId'];
      final DateTime date = DateTime.parse(body['date']);
      final List records = body['records'];

      final studentsBox = await Hive.openBox<Student>('students');

      // 🔒 CHECK FOR DOUBLE MARKING
      final alreadyMarked = studentsBox.values.any((s) =>
          s.class_ == className &&
          s.terms!.contains(termId) &&
          (s.presentDates.contains(date) || s.absentDates.contains(date)));

      // ✅ Check if updates are allowed
      final allowUpdate =
          (_settingsBox.get('allowAttendanceUpdate') as bool?) ?? false;

      if (alreadyMarked) {
        if (allowUpdate) {
          // ✅ Updates are allowed - proceed with updating
          print(
              "📝 Attendance already marked but updates are allowed. Updating records...");

          // Clear existing marks for this date for all students in the class
          for (final student in studentsBox.values.where(
              (s) => s.class_ == className && s.terms!.contains(termId))) {
            student.presentDates.remove(date);
            student.absentDates.remove(date);
            await student.save();
          }

          // Now apply the new marks
          for (final record in records) {
            final studentId = record['studentId'];
            final bool isPresent = record['isPresent'];

            final student = studentsBox.values.firstWhere(
              (s) => s.studentIdNumber == studentId,
              orElse: () => throw Exception("Student not found: $studentId"),
            );

            if (isPresent) {
              student.presentDates.add(date);
              student.absentDates.remove(date);
            } else {
              student.absentDates.add(date);
              student.presentDates.remove(date);
            }

            await student.save();
          }

          return {
            "status": "success",
            "marked": records.length,
            "updated": true,
            "message": "Attendance updated successfully"
          };
        } else {
          // ❌ Updates are blocked
          res.statusCode = 409;
          return {
            "error": "Attendance already marked for this class and date",
            "allowUpdate": false,
            "message":
                "Updates are currently blocked by the host. Please contact administrator."
          };
        }
      }

      // ✅ APPLY ATTENDANCE (first time marking)
      for (final record in records) {
        final studentId = record['studentId'];
        final bool isPresent = record['isPresent'];

        final student = studentsBox.values.firstWhere(
          (s) => s.studentIdNumber == studentId,
          orElse: () => throw Exception("Student not found: $studentId"),
        );

        if (isPresent) {
          student.presentDates.add(date);
          student.absentDates.remove(date);
        } else {
          student.absentDates.add(date);
          student.presentDates.remove(date);
        }

        await student.save();
      }

      return {
        "status": "success",
        "marked": records.length,
        "updated": false,
        "message": "Attendance marked successfully"
      };
    } catch (e) {
      print("❌ Bulk register error: $e");
      res.statusCode = 500;
      return {"error": "Failed to mark attendance", "details": e.toString()};
    }
  });

  /// ************************ CHECK if attendance update is allowed ************************
  app.get("/api/register/allow-update", (req, res) async {
    try {
      final allowUpdate =
          (_settingsBox.get('allowAttendanceUpdate') as bool?) ?? false;
      return {
        "allowUpdate": allowUpdate,
        "message":
            allowUpdate ? "Updates are allowed" : "Updates are blocked by host"
      };
    } catch (e) {
      print("❌ Error checking update permission: $e");
      res.statusCode = 500;
      return {"error": "Failed to check update permission"};
    }
  });
  app.get("/api/students", (req, res) async {
    try {
      // Grab search query, normalize it
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';
      debugPrint('🔍 /api/students called with search="$search"');

      // Filter students safely
      final filteredStudents = _studentsBox.values
          .where((s) => s.termId != null)
          .where((s) => deepMatchStudent(s, search))
          .toList();

      // Optional: limit results to avoid sending huge lists to clients
      const maxResults = 100; // adjust as needed
      final studentsJsonList =
          filteredStudents.take(maxResults).map(studentsToJson).toList();

      debugPrint(
          '✅ Returning ${studentsJsonList.length} students (filtered, max $maxResults)');

      return studentsJsonList;
    } catch (e) {
      print("❌ Error serving students data: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch students info"};
    }
  });

  /// ************************ GET all students (unlimited) ************************
  app.get("/api/students/all", (req, res) async {
    try {
      debugPrint('📘 /api/students/all called');

      // Get ALL students without limit
      final allStudents =
          _studentsBox.values.where((s) => s.termId != null).toList();

      debugPrint('✅ Returning ${allStudents.length} students (unlimited)');

      return allStudents.map(studentsToJson).toList();
    } catch (e) {
      print("❌ Error serving all students data: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch all students info"};
    }
  });

// ✅ Check if attendance is already marked for a class on a date
  app.get("/api/students/registers/check", (req, res) async {
    try {
      final className = req.uri.queryParameters['class'];
      final dateParam = req.uri.queryParameters['date'];

      if (className == null || dateParam == null) {
        res.statusCode = 400;
        return {"error": "class and date parameters are required"};
      }

      final date = DateTime.parse(dateParam);
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Check if any student in the class has attendance marked for this date
      final students =
          _studentsBox.values.where((s) => s.class_ == className).toList();

      var isMarked = false;
      for (final student in students) {
        // Check present dates
        for (final presentDate in student.presentDates) {
          final pNormalized =
              DateTime(presentDate.year, presentDate.month, presentDate.day);
          if (pNormalized.compareTo(normalizedDate) == 0) {
            isMarked = true;
            break;
          }
        }
        if (isMarked) break;

        // Check absent dates
        for (final absentDate in student.absentDates) {
          final aNormalized =
              DateTime(absentDate.year, absentDate.month, absentDate.day);
          if (aNormalized.compareTo(normalizedDate) == 0) {
            isMarked = true;
            break;
          }
        }
        if (isMarked) break;
      }

      return {"isMarked": isMarked};
    } catch (e) {
      print("❌ Error checking attendance: $e");
      res.statusCode = 500;
      return {"error": "Failed to check attendance"};
    }
  });

// ✅ Get attendance status for a specific student
  app.get("/api/students/:studentId/attendance", (req, res) async {
    try {
      final studentId = req.params['studentId'];
      final dateParam = req.uri.queryParameters['date'];

      if (dateParam == null) {
        res.statusCode = 400;
        return {"error": "date parameter is required"};
      }

      final date = DateTime.parse(dateParam);
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final matches = _studentsBox.values
          .where((s) => s.studentIdNumber == studentId)
          .toList();
      if (matches.isEmpty) {
        res.statusCode = 404;
        return {"error": "Student not found"};
      }
      final student = matches.first;

      var isMarked = false;
      String? status;

      // Check present dates
      for (final presentDate in student.presentDates) {
        final pNormalized =
            DateTime(presentDate.year, presentDate.month, presentDate.day);
        if (pNormalized.compareTo(normalizedDate) == 0) {
          isMarked = true;
          status = 'present';
          break;
        }
      }

      if (!isMarked) {
        // Check absent dates
        for (final absentDate in student.absentDates) {
          final aNormalized =
              DateTime(absentDate.year, absentDate.month, absentDate.day);
          if (aNormalized.compareTo(normalizedDate) == 0) {
            isMarked = true;
            status = 'absent';
            break;
          }
        }
      }

      return {
        "isMarked": isMarked,
        "status": status,
        "date": normalizedDate.toIso8601String(),
        "studentId": studentId
      };
    } catch (e) {
      print("❌ Error checking student attendance: $e");
      res.statusCode = 500;
      return {"error": "Failed to check student attendance"};
    }
  });

  /// ************************ GET attendance settings ************************
  app.get("/api/settings/attendance", (req, res) async {
    try {
      debugPrint('📋 GET /api/settings/attendance - START');
      debugPrint('📋 Settings box length: ${_settingsBox.length}');
      debugPrint('📋 Settings box keys: ${_settingsBox.keys.toList()}');

      // Get the first settings object
      final settings = _settingsBox.values.firstOrNull;

      if (settings == null) {
        debugPrint('⚠️ No settings found! Creating default...');
        // Create default settings
        final defaultSettings = Settings(
          id: 'app_settings',
          lastUpdated: DateTime.now(),
          allowAttendanceUpdate: false,
          allowStudentSync: true,
          allowPaymentSync: true,
          autoSyncEnabled: false,
          syncIntervalMinutes: 5,
          maintenanceMode: false,
          enableBackup: false,
          backupFrequency: 'Daily',
          maxStudentsPerClass: 30,
          allowMultipleTerms: true,
          enableNotifications: true,
          debugMode: false,
          syncStatus: true,
          modifiedFields: [],
          operationType: 'create',
        );

        await _settingsBox.add(defaultSettings);
        final allowUpdate = defaultSettings.allowAttendanceUpdate ?? false;

        debugPrint(
            '✅ Created default settings: allowAttendanceUpdate = $allowUpdate');

        return {
          "allowUpdate": allowUpdate,
          "message":
              "Default settings created. Attendance updates are blocked by default."
        };
      }

      final allowUpdate = settings.allowAttendanceUpdate ?? false;
      debugPrint('✅ Found settings: allowAttendanceUpdate = $allowUpdate');
      debugPrint('✅ Settings lastUpdated: ${settings.lastUpdated}');
      debugPrint('✅ Settings modifiedFields: ${settings.modifiedFields}');

      return {
        "allowUpdate": allowUpdate,
        "message": allowUpdate
            ? "Attendance updates are allowed"
            : "Attendance updates are blocked"
      };
    } catch (e) {
      debugPrint("❌ Error getting attendance settings: $e");
      res.statusCode = 500;
      return {"error": "Failed to get attendance settings"};
    }
  });

  /// ************************ UPDATE attendance settings ************************
  app.put("/api/settings/attendance", (req, res) async {
    try {
      debugPrint('📋 PUT /api/settings/attendance - START');

      final body = await req.bodyAsJsonMap;
      final allowUpdate = body['allowUpdate'] as bool?;

      debugPrint('📋 Request body: $body');
      debugPrint('📋 allowUpdate value: $allowUpdate');

      if (allowUpdate == null) {
        debugPrint('❌ allowUpdate is null');
        res.statusCode = 400;
        return {"error": "allowUpdate parameter is required"};
      }

      // Get the first settings object
      var settings = _settingsBox.values.firstOrNull;

      if (settings == null) {
        debugPrint('⚠️ No settings found! Creating new...');
        settings = Settings(
          id: 'app_settings',
          lastUpdated: DateTime.now(),
          allowAttendanceUpdate: allowUpdate,
          allowStudentSync: true,
          allowPaymentSync: true,
          autoSyncEnabled: false,
          syncIntervalMinutes: 5,
          maintenanceMode: false,
          enableBackup: false,
          backupFrequency: 'Daily',
          maxStudentsPerClass: 30,
          allowMultipleTerms: true,
          enableNotifications: true,
          debugMode: false,
          syncStatus: true,
          modifiedFields: ['allowAttendanceUpdate'],
          operationType: 'create',
        );

        await _settingsBox.add(settings);
        debugPrint(
            '✅ Created new settings with allowAttendanceUpdate = $allowUpdate');
      } else {
        // Update existing settings
        settings.allowAttendanceUpdate = allowUpdate;
        settings.lastUpdated = DateTime.now();
        settings.markFieldModified('allowAttendanceUpdate');
        await settings.save();
        debugPrint('✅ Updated settings: allowAttendanceUpdate = $allowUpdate');
      }

      // Verify the setting was saved
      final savedSettings = _settingsBox.values.firstOrNull;
      final savedValue = savedSettings?.allowAttendanceUpdate;
      debugPrint('✅ Verified saved value: $savedValue');

      return {
        "success": true,
        "allowUpdate": allowUpdate,
        "verified": savedValue == allowUpdate,
        "message": allowUpdate
            ? "Attendance updates are now allowed"
            : "Attendance updates are now blocked"
      };
    } catch (e) {
      debugPrint("❌ Error updating attendance settings: $e");
      res.statusCode = 500;
      return {"error": "Failed to update attendance settings"};
    }
  });

  /// ************************ CHECK if attendance update is allowed ************************
  app.get("/api/register/allow-update", (req, res) async {
    try {
      debugPrint('📋 GET /api/register/allow-update - START');

      // Get the first settings object
      final settings = _settingsBox.values.firstOrNull;

      if (settings == null) {
        debugPrint('⚠️ No settings found! Creating default...');
        // Create default settings
        final defaultSettings = Settings(
          id: 'app_settings',
          lastUpdated: DateTime.now(),
          allowAttendanceUpdate: false,
          allowStudentSync: true,
          allowPaymentSync: true,
          autoSyncEnabled: false,
          syncIntervalMinutes: 5,
          maintenanceMode: false,
          enableBackup: false,
          backupFrequency: 'Daily',
          maxStudentsPerClass: 30,
          allowMultipleTerms: true,
          enableNotifications: true,
          debugMode: false,
          syncStatus: true,
          modifiedFields: [],
          operationType: 'create',
        );

        await _settingsBox.add(defaultSettings);
        final allowUpdate = defaultSettings.allowAttendanceUpdate ?? false;

        debugPrint(
            '✅ Created default settings: allowAttendanceUpdate = $allowUpdate');

        return {
          "allowUpdate": allowUpdate,
          "message": "Default settings created. Updates are blocked by default."
        };
      }

      final allowUpdate = settings.allowAttendanceUpdate ?? false;
      debugPrint('✅ Found settings: allowUpdate = $allowUpdate');

      return {
        "allowUpdate": allowUpdate,
        "message":
            allowUpdate ? "Updates are allowed" : "Updates are blocked by host"
      };
    } catch (e) {
      debugPrint("❌ Error checking update permission: $e");
      res.statusCode = 500;
      return {"error": "Failed to check update permission"};
    }
  });

  /// ************************ DEBUG: View all settings ************************
  app.get("/api/settings/debug", (req, res) async {
    try {
      final allSettings = _settingsBox.values.toList();
      final settingsMap = allSettings
          .map((s) => {
                'id': s.id,
                'allowAttendanceUpdate': s.allowAttendanceUpdate,
                'lastUpdated': s.lastUpdated?.toIso8601String(),
                'modifiedFields': s.modifiedFields,
                'operationType': s.operationType,
                'syncStatus': s.syncStatus,
              })
          .toList();

      debugPrint('📋 DEBUG: All settings = ${jsonEncode(settingsMap)}');

      return {
        "count": allSettings.length,
        "settings": settingsMap,
        "boxName": _settingsBox.name,
        "boxLength": _settingsBox.length,
        "keys": _settingsBox.keys.toList(),
      };
    } catch (e) {
      debugPrint("❌ Error debugging settings: $e");
      res.statusCode = 500;
      return {"error": "Failed to debug settings"};
    }
  });

  /// ************************ DEBUG: Reset settings ************************
  app.post("/api/settings/reset", (req, res) async {
    try {
      // Clear all settings
      await _settingsBox.clear();

      // Create default settings
      final defaultSettings = Settings(
        id: 'app_settings',
        lastUpdated: DateTime.now(),
        allowAttendanceUpdate: false,
        allowStudentSync: true,
        allowPaymentSync: true,
        autoSyncEnabled: false,
        syncIntervalMinutes: 5,
        maintenanceMode: false,
        enableBackup: false,
        backupFrequency: 'Daily',
        maxStudentsPerClass: 30,
        allowMultipleTerms: true,
        enableNotifications: true,
        debugMode: false,
        syncStatus: true,
        modifiedFields: [],
        operationType: 'create',
      );

      await _settingsBox.add(defaultSettings);
      debugPrint('✅ Settings reset to default: allowAttendanceUpdate = false');

      return {
        "success": true,
        "message": "Settings reset to default",
        "defaultSettings": {
          "allowAttendanceUpdate": defaultSettings.allowAttendanceUpdate,
        }
      };
    } catch (e) {
      debugPrint("❌ Error resetting settings: $e");
      res.statusCode = 500;
      return {"error": "Failed to reset settings"};
    }
  });

  /// ************************ BULK REGISTER ************************
  app.post("/api/register/mark/bulk", (req, res) async {
    try {
      final body = await req.bodyAsJsonMap;

      final String className = body['className'];
      final String termId = body['termId'];
      final DateTime date = DateTime.parse(body['date']);
      final List records = body['records'];

      // 🔒 CHECK FOR DOUBLE MARKING
      final alreadyMarked = _studentsBox.values.any((s) =>
          s.class_ == className &&
          s.terms!.contains(termId) &&
          (s.presentDates.contains(date) || s.absentDates.contains(date)));

      // ✅ Get settings from typed box
      final settings = _settingsBox.values.first;
      final allowUpdate = settings.allowAttendanceUpdate ?? false;

      debugPrint(
          '📋 Bulk register - className: $className, termId: $termId, date: $date');
      debugPrint('📋 alreadyMarked: $alreadyMarked, allowUpdate: $allowUpdate');

      if (alreadyMarked) {
        if (allowUpdate) {
          // ✅ Updates are allowed - proceed with updating
          debugPrint(
              "📝 Attendance already marked but updates are allowed. Updating records...");

          // Clear existing marks for this date for all students in the class
          for (final student in _studentsBox.values.where(
              (s) => s.class_ == className && s.terms!.contains(termId))) {
            student.presentDates.remove(date);
            student.absentDates.remove(date);
            await student.save();
          }

          // Now apply the new marks
          for (final record in records) {
            final studentId = record['studentId'];
            final bool isPresent = record['isPresent'];

            final student = _studentsBox.values.firstWhere(
              (s) => s.studentIdNumber == studentId,
              orElse: () => throw Exception("Student not found: $studentId"),
            );

            if (isPresent) {
              student.presentDates.add(date);
              student.absentDates.remove(date);
            } else {
              student.absentDates.add(date);
              student.presentDates.remove(date);
            }

            await student.save();
          }

          return {
            "status": "success",
            "marked": records.length,
            "updated": true,
            "message": "Attendance updated successfully"
          };
        } else {
          // ❌ Updates are blocked
          debugPrint("❌ Attendance already marked and updates are blocked");
          res.statusCode = 409;
          return {
            "error": "Attendance already marked for this class and date",
            "allowUpdate": false,
            "message":
                "Updates are currently blocked by the host. Please contact administrator."
          };
        }
      }

      // ✅ APPLY ATTENDANCE (first time marking)
      debugPrint("✅ Marking attendance for the first time");
      for (final record in records) {
        final studentId = record['studentId'];
        final bool isPresent = record['isPresent'];

        final student = _studentsBox.values.firstWhere(
          (s) => s.studentIdNumber == studentId,
          orElse: () => throw Exception("Student not found: $studentId"),
        );

        if (isPresent) {
          student.presentDates.add(date);
          student.absentDates.remove(date);
        } else {
          student.absentDates.add(date);
          student.presentDates.remove(date);
        }

        await student.save();
      }

      return {
        "status": "success",
        "marked": records.length,
        "updated": false,
        "message": "Attendance marked successfully"
      };
    } catch (e) {
      debugPrint("❌ Bulk register error: $e");
      res.statusCode = 500;
      return {"error": "Failed to mark attendance", "details": e.toString()};
    }
  });
  //************************* POST /api/student/bulk ************************/

  app.post("/api/students/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('students') || body['students'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'students' key"
        };
      }

      final List<dynamic> studentsJson = body['students'];

      final List<Student> insertedStudents = [];
      for (final item in studentsJson) {
        try {
          final student = studentsFromJson(item);
          await _studentsBox.add(student);
          insertedStudents.add(student);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid student: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedStudents.length,
        "insertedStudents": insertedStudents.map(studentsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk students",
        "details": e.toString(),
      };
    }
  });

  app.post("/api/students/bulk/single", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;
      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (body['students'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'students' key"
        };
      }

      final List inserted = [];
      final List skipped = [];

      for (final item in body['students']) {
        try {
          final student = createStudentFromClientJson(
            json: Map<String, dynamic>.from(item),
            studentsBox: _studentsBox,
          );

          await _studentsBox.add(student);
          inserted.add(studentsToJson(student));
        } catch (e) {
          skipped.add({
            "data": item,
            "reason": e.toString(),
          });
        }
      }

      return {
        "success": true,
        "insertedCount": inserted.length,
        "skippedCount": skipped.length,
        "insertedStudents": inserted,
        "skippedStudents": skipped,
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk students",
        "details": e.toString(),
      };
    }
  });

  app.post("/api/students/single", (req, res) async {
    try {
      final payload = await req.bodyAsJsonMap;

      final student = createStudentFromClientJson(
        json: payload,
        studentsBox: _studentsBox,
      );

      await _studentsBox.add(student);

      return {
        "success": true,
        "student": studentsToJson(student),
      };
    } catch (e) {
      res.statusCode = 409;
      return {
        "error": e.toString(),
      };
    }
  });

  //******************** PUT /api/students/:studentId ********************
  app.put('/api/students/:studentId', (req, res) async {
    try {
      final studentId = req.params['studentId'];

      final body = await req.bodyAsJsonMap;

      final index = _studentsBox.values.toList().indexWhere(
            (s) => s.studentIdNumber == studentId,
          );

      if (index == -1) {
        res.statusCode = 404;
        return {'error': 'Student not found'};
      }

      // FULL DESERIALIZATION
      final incomingStudent = studentsFromJson(body);

      final updatedStudent = incomingStudent.copyWith(
        syncStatus: true,
        operationType: null,
        lastModified: DateTime.now(),
      );

      await _studentsBox.putAt(index, updatedStudent);

      return {
        'success': true,
        'student': studentsToJson(updatedStudent),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        'error': 'Failed to update student',
        'details': e.toString(),
      };
    }
  });

//******************** PUT /api/students/bulk ********************
  app.put('/api/students/bulk', (req, res) async {
    try {
      final body = await req.bodyAsJsonMap;

      final List<dynamic> students = body['students'];

      final List<Student> updatedStudents = [];

      for (final item in students) {
        try {
          final incoming = studentsFromJson(item);

          final index = _studentsBox.values.toList().indexWhere(
                (s) => s.studentIdNumber == incoming.studentIdNumber,
              );

          if (index == -1) continue;

          final serverStudent = incoming.copyWith(
            syncStatus: true,
            operationType: null,
            lastModified: DateTime.now(),
          );

          await _studentsBox.putAt(index, serverStudent);
          updatedStudents.add(serverStudent);
        } catch (e) {
          print('❌ Skipped malformed update: $e');
        }
      }

      return {
        'success': true,
        'updatedCount': updatedStudents.length,
        'students': updatedStudents.map(studentsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {'error': e.toString()};
    }
  });

  ////////////////////////////////teacherPayments api////////////////////

  //***********************get teacherPayments method *********************/
  app.get("/api/teacherPayments", (req, res) async {
    try {
      final teacherPaymentsJsonList = _teacherPaymentsBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(teacherPaymentsToJson)
          .toList();

      return teacherPaymentsJsonList;
    } catch (e) {
      print("Error serving teacherPayments data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch teacherPayments info"};
    }
  });

  //************************* POST /api/teacherPayment/bulk ************************/

  app.post("/api/teacherPayments/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('teacherPayments') ||
          body['teacherPayments'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'teacherPayments' key"
        };
      }

      final List<dynamic> teacherPaymentJson = body['teacherPayments'];

      final List<TeacherPayment> insertedTeacherPayment = [];
      for (final item in teacherPaymentJson) {
        try {
          final teacherPayment = teacherPaymentsFromJson(item);
          await _teacherPaymentsBox.add(teacherPayment);
          insertedTeacherPayment.add(teacherPayment);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid teacherPayment: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedTeacherPayment.length,
        "insertedTeacherPayments":
            insertedTeacherPayment.map(teacherPaymentsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk teacherPayments",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////studentPayments api////////////////////

  //***********************get studentPayments method *********************/
  app.get("/api/studentPayments", (req, res) async {
    try {
      final studentPaymentsJsonList = _studentPaymentsBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(studentPaymentsToJson)
          .toList();

      return studentPaymentsJsonList;
    } catch (e) {
      print("Error serving studentPayments data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch studentPayments info"};
    }
  });

  //************************* POST /api/studentPayments ************************/

  app.post("/api/studentPayments", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      // Parse body safely
      final body = await req.bodyAsJsonMap;

      // Deserialize the incoming JSON into a StudentPayment object
      final studentPayment = studentPaymentsFromJson(body);

      // Save to Hive (or any backend storage you use)
      final key = await _studentPaymentsBox.add(studentPayment);

      // Return success with serialized data
      return {
        "success": true,
        "key": key,
        "studentPayment": studentPaymentsToJson(studentPayment),
      };
    } catch (e) {
      res.statusCode = 400;
      return {
        "error": "Failed to process student payment",
        "details": e.toString(),
      };
    }
  });

  //************************* POST /api/studentPayments/bulk ************************/

  app.post("/api/studentPayments/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('payments') || body['payments'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'payments' key"
        };
      }

      final List<dynamic> paymentsJson = body['payments'];

      final List<StudentPayment> insertedPayments = [];
      for (final item in paymentsJson) {
        try {
          final payment = studentPaymentsFromJson(item);
          await _studentPaymentsBox.add(payment);
          insertedPayments.add(payment);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid payment: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedPayments.length,
        "insertedPayments":
            insertedPayments.map(studentPaymentsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk payments",
        "details": e.toString(),
      };
    }
  });

  ////////////////////////////////paymentPurposes api////////////////////

  //***********************get paymentPurposes method *********************/
  app.get("/api/paymentPurposes", (req, res) async {
    try {
      final paymentPurposesJsonList = _paymentPurposesBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(paymentPurposesToJson)
          .toList();

      return paymentPurposesJsonList;
    } catch (e) {
      print("Error serving paymentPurposes data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch paymentPurposes info"};
    }
  });

  //************************* POST /api/paymentPurpose/bulk ************************/

  app.post("/api/paymentPurposes/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('paymentPurposes') ||
          body['paymentPurposes'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'paymentPurposes' key"
        };
      }

      final List<dynamic> paymentPurposesJson = body['paymentPurposes'];

      final List<PaymentPurpose> insertedPaymentPurposes = [];
      for (final item in paymentPurposesJson) {
        try {
          final paymentPurpose = paymentPurposesFromJson(item);
          await _paymentPurposesBox.add(paymentPurpose);
          insertedPaymentPurposes.add(paymentPurpose);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid paymentPurpose: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedPaymentPurposes.length,
        "insertedPaymentPurposes":
            insertedPaymentPurposes.map(paymentPurposesToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk paymentPurposes",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////teacherPaymentPurposes api////////////////////

  //***********************get teacherPaymentPurposes method *********************/
  app.get("/api/teacherPaymentPurposes", (req, res) async {
    try {
      final teacherPaymentPurposesJsonList = _teacherPaymentsPurposesBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(teacherPaymentPurposesToJsonList)
          .toList();

      return teacherPaymentPurposesJsonList;
    } catch (e) {
      print("Error serving teacherPaymentPurposes data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch teacherPaymentPurposes info"};
    }
  });

  //************************* POST /api/teacherPaymentPurpose/bulk ************************/

  app.post("/api/teacherPaymentPurposes/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('teacherPaymentPurposes') ||
          body['teacherPaymentPurposes'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'teacherPaymentPurposes' key"
        };
      }

      final List<dynamic> teacherPaymentPurposesJson =
          body['teacherPaymentPurposes'];

      final List<TeacherPaymentsPurposes> insertedTeacherPaymentPurposes = [];
      for (final item in teacherPaymentPurposesJson) {
        try {
          final teacherPaymentPurpose =
              teacherPaymentPurposesFromJsonList(item);
          await _teacherPaymentsPurposesBox.add(teacherPaymentPurpose);
          insertedTeacherPaymentPurposes.add(teacherPaymentPurpose);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid teacherPaymentPurpose: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedTeacherPaymentPurposes.length,
        "teacherPaymentPurposes": insertedTeacherPaymentPurposes
            .map(teacherPaymentPurposesToJsonList)
            .toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk teacherPaymentPurposes",
        "details": e.toString(),
      };
    }
  });
  ////////////////////////////////classes api////////////////////
  /// ************************ GET all classes (unlimited) ************************
  app.get("/api/classes/all", (req, res) async {
    try {
      debugPrint('📘 /api/classes/all called');

      // Get ALL classes without limit
      final allClasses =
          _classesBox.values.where((c) => c.className != null).toList();

      debugPrint('✅ Returning ${allClasses.length} classes (unlimited)');

      return allClasses.map(classesToJson).toList();
    } catch (e) {
      print("❌ Error serving all classes data: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch all classes info"};
    }
  });

  /// ************************ GET classes with filters ************************
  app.get("/api/classes", (req, res) async {
    try {
      final termId = req.uri.queryParameters['termId'];
      final search =
          req.uri.queryParameters['search']?.toLowerCase().trim() ?? '';

      debugPrint('📘 /api/classes called');
      debugPrint('  termId: "$termId"');
      debugPrint('  search: "$search"');

      // Start with all classes
      var filteredClasses =
          _classesBox.values.where((c) => c.className != null).toList();

      // Filter by term if provided
      if (termId != null && termId.isNotEmpty) {
        filteredClasses = filteredClasses
            .where((c) => c.terms != null && c.terms!.contains(termId))
            .toList();
      }

      // Apply search filter
      if (search.isNotEmpty) {
        filteredClasses = filteredClasses
            .where((c) => c.className.toLowerCase().contains(search))
            .toList();
      }

      // Sort alphabetically
      filteredClasses.sort((a, b) => a.className.compareTo(b.className));

      const maxResults = 100;
      final classesJson =
          filteredClasses.take(maxResults).map(classesToJson).toList();

      debugPrint('✅ Returning ${classesJson.length} classes (max $maxResults)');

      return classesJson;
    } catch (e) {
      print("❌ Error serving classes data: $e");
      res.statusCode = 500;
      return {"error": "Failed to fetch classes info"};
    }
  });
  //***********************get classes method *********************/
  app.get("/api/classes", (req, res) async {
    try {
      final classesJsonList = _classesBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(classesToJson)
          .toList();

      return classesJsonList;
    } catch (e) {
      print("Error serving class data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch class info"};
    }
  });

  //************************* POST /api/classe/bulk ************************/

  app.post("/api/classes/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('classes') || body['classes'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'classes' key"
        };
      }

      final List<dynamic> classesJson = body['classes'];
      final List<Map<String, dynamic>> feedback = [];

      final List<Classes> insertedClasses = [];
      for (final item in classesJson) {
        try {
          final classe = classesFromJson(item);
          await _classesBox.add(classe);
          insertedClasses.add(classe);
          feedback.add({
            "classCode": classe.classCode,
            "status": "success",
            "message": "Inserted successfully"
          });
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid classe: $e");
          feedback.add({
            "classCode": item['classCode'] ?? 'unknown',
            "status": "failed",
            "message": e.toString()
          });
        }
      }

      return {
        "success": true,
        "insertedCount": insertedClasses.length,
        "insertedClasses": insertedClasses.map(classesToJson).toList(),
        "feedback": feedback,
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk classes",
        "details": e.toString(),
      };
    }
  });
////////////////////////////////terms api////////////////////

  //***********************get terms method *********************/
  app.get("/api/terms", (req, res) async {
    try {
      final termsJsonList = _termsBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(termsToJson)
          .toList();

      return termsJsonList;
    } catch (e) {
      print("Error serving terms data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch terms info"};
    }
  });

  //************************* POST /api/term/bulk ************************/

  app.post("/api/terms/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('terms') || body['terms'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'terms' key"
        };
      }

      final List<dynamic> termsJson = body['terms'];

      final List<Terms> insertedTerms = [];
      final List<Map<String, dynamic>> feedback = [];

      for (final item in termsJson) {
        final result = await validateAndInsertTerm(item, _termsBox);
        feedback.add(result);

        if (result['status'] == 'success') {
          insertedTerms.add(termsFromJson(item));
        }
      }

      return {
        "success": true,
        "insertedCount": insertedTerms.length,
        "feedback": feedback,
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk terms",
        "details": e.toString(),
      };
    }
  });
////////////////////////////////School api////////////////////

  //***********************get method *********************/
  app.get("/api/school", (req, res) async {
    try {
      final schoolJsonList = schoolBox.values
          .where((schoolItem) => schoolItem.termId != null)
          .map(schoolToJson)
          .toList();

      return schoolJsonList;
    } catch (e) {
      print("Error serving school data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch school info"};
    }
  });

  //***********************post method *********************/

  app.post("/api/school", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;
      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body =
          await req.bodyAsJsonMap; // <-- This throws BodyParserException
      final school = schoolFromJson(body);
      final key = await schoolBox.add(school);

      return {
        "success": true,
        "key": key,
        "school": schoolToJson(school),
      };
    } catch (e) {
      res.statusCode = 400;
      return {
        "error": "Failed to create school entry",
        "details": e.toString(),
      };
    }
  });

  //************************* POST /api/school/bulk ************************/

  app.post("/api/school/bulk", (req, res) async {
    try {
      final contentType = req.headers.contentType?.mimeType;

      if (contentType != 'application/json') {
        res.statusCode = 400;
        return {
          "error": "Invalid content type",
          "details": "Expected application/json, got $contentType"
        };
      }

      final body = await req.bodyAsJsonMap;

      if (!body.containsKey('schools') || body['schools'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'schools' key"
        };
      }

      final List<dynamic> schoolsJson = body['schools'];

      final List<School> insertedSchools = [];
      final List<Map<String, dynamic>> feedback = [];

      print("📥 Received ${schoolsJson.length} schools to process");

      for (final schoolData in schoolsJson) {
        final result = await validateAndInsertSchool(schoolData, schoolBox);
        feedback.add(result);

        if (result['status'] == 'success') {
          insertedSchools.add(schoolFromJson(schoolData));
        }
      }

      return {
        "success": true,
        "insertedCount": insertedSchools.length,
        "feedback": feedback,
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk schools",
        "details": e.toString(),
      };
    }
  });
  //***********************put method *********************/

  /// PUT /api/school/:key - update school at key
  app.put("/api/school/:key", (req, res) async {
    try {
      final key = int.tryParse(req.params['key'] ?? '');
      if (key == null || !schoolBox.containsKey(key)) {
        res.statusCode = 404;
        return {"error": "School entry not found"};
      }

      final body = await req.bodyAsJsonMap;
      final updated = schoolFromJson(body);

      await schoolBox.put(key, updated);
      return {"success": true, "school": schoolToJson(updated)};
    } catch (e) {
      res.statusCode = 400;
      return {"error": "Failed to update school", "details": e.toString()};
    }
  });

  /// PATCH /api/school/:key - partially update school
  app.patch("/api/school/:key", (req, res) async {
    try {
      final key = int.tryParse(req.params['key'] ?? '');
      if (key == null || !schoolBox.containsKey(key)) {
        res.statusCode = 404;
        return {"error": "School entry not found"};
      }

      final existing = schoolBox.get(key);
      final body = await req.bodyAsJsonMap;

      final updated = copyWithFromJson(existing!, body);
      await schoolBox.put(key, updated);

      return {"success": true, "school": schoolToJson(updated)};
    } catch (e) {
      res.statusCode = 400;
      return {"error": "Failed to patch school", "details": e.toString()};
    }
  });

  //***********************delete method *********************/

  /// DELETE /api/school/:key - delete school at key
  app.delete("/api/school/:key", (req, res) async {
    try {
      final key = int.tryParse(req.params['key'] ?? '');
      if (key == null || !schoolBox.containsKey(key)) {
        res.statusCode = 404;
        return {"error": "School entry not found"};
      }

      await schoolBox.delete(key);
      return {"success": true, "deletedKey": key};
    } catch (e) {
      res.statusCode = 400;
      return {"error": "Failed to delete school", "details": e.toString()};
    }
  });

  final server = await app.listen(8080, InternetAddress.anyIPv4);
  print(
      "🚀 Alfred server running on http://${server.address.address}:${server.port}");
}
