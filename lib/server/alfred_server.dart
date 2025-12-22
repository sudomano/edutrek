import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
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
import 'package:zitf_system/reusable_codes/serializers/class_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/daily_activities_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/domains_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/exceptions_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_log_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/project_items_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/project_student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/projects_serializer.dart';
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
import 'package:zitf_system/terms/term_validator.dart';

import '../database/school_info.dart'; // Your School model

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
late final Box<ProjectStudentPayment> _projectStudentPaymentBox;
late final Box<ExceptionalStudents> _exceptionalStudentsBox;

Future<void> startAlfredServer() async {
  final app = Alfred();

  app.all("*", (req, res) {
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Headers', '*');
    res.headers.set('Access-Control-Allow-Methods',
        'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  });

  app.get("/api/health", (req, res) => {"status": "ok"});

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
  _userBox = await Hive.openBox<User>('users'); // Open the box for users
  _accountBox = await Hive.openBox<Account>('account');
  _assetBox = await Hive.openBox<Asset>('asset');
  _projectBox = await Hive.openBox<Project>('projects');
  _projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
  _dailyActivityBox = await Hive.openBox<DailyActivity>('dailyActivities');
  _projectStudentPaymentBox =
      await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
  _exceptionalStudentsBox =
      await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');

  ////////////////////////////////exceptionalStudents api////////////////////

  //***********************get exceptionalStudents method *********************/
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

  ////////////////////////////////projectStudentPayments api////////////////////

  //***********************get projectStudentPayments method *********************/
  app.get("/api/projectStudentPayments", (req, res) async {
    try {
      final projectStudentPaymentsJsonList = _projectStudentPaymentBox.values
          .where((schoolItem) => schoolItem.projectStudentPaymentCode != null)
          .map(projectStudentPaymentsToJson)
          .toList();

      return projectStudentPaymentsJsonList;
    } catch (e) {
      print("Error serving projectStudentPayments data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch projectStudentPayments info"};
    }
  });

  //************************* POST /api/projectStudentPayments/bulk ************************/

  app.post("/api/projectStudentPayments/bulk", (req, res) async {
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

      if (!body.containsKey('projectstudentpayments') ||
          body['projectstudentpayments'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'projectstudentpayments' key"
        };
      }

      final List<dynamic> projectstudentpaymentsJson =
          body['projectstudentpayments'];

      final List<ProjectStudentPayment> insertedprojectstudentpayments = [];
      for (final item in projectstudentpaymentsJson) {
        try {
          final projectstudentpayment = projectStudentPaymentsFromJson(item);
          await _projectStudentPaymentBox.add(projectstudentpayment);
          insertedprojectstudentpayments.add(projectstudentpayment);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid projectstudentpayment: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedprojectstudentpayments.length,
        "insertedprojectstudentpayments": insertedprojectstudentpayments
            .map(projectStudentPaymentsToJson)
            .toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk projectstudentpayments",
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

  ////////////////////////////////projectItems api////////////////////

  //***********************get projectItems method *********************/
  app.get("/api/projectItems", (req, res) async {
    try {
      final projectItemsJsonList = _projectItemBox.values
          .where((schoolItem) => schoolItem.projectItemCode != null)
          .map(projectItemsToJson)
          .toList();

      return projectItemsJsonList;
    } catch (e) {
      print("Error serving projectItems data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch projectItems info"};
    }
  });

  //************************* POST /api/projectItem/bulk ************************/

  app.post("/api/projectItems/bulk", (req, res) async {
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

      if (!body.containsKey('projectitems') || body['projectitems'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'projectitems' key"
        };
      }

      final List<dynamic> projectitemsJson = body['projectitems'];

      final List<ProjectItem> insertedProjectitems = [];
      for (final item in projectitemsJson) {
        try {
          final projectItem = projectItemsFromJson(item);
          await _projectItemBox.add(projectItem);
          insertedProjectitems.add(projectItem);
        } catch (e) {
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid projectItem: $e");
        }
      }

      return {
        "success": true,
        "insertedCount": insertedProjectitems.length,
        "insertedProjectitems":
            insertedProjectitems.map(projectItemsToJson).toList(),
      };
    } catch (e) {
      res.statusCode = 500;
      return {
        "error": "Failed to process bulk projectitems",
        "details": e.toString(),
      };
    }
  });

  ////////////////////////////////projects api////////////////////

  //***********************get projects method *********************/
  app.get("/api/projects", (req, res) async {
    try {
      final projectsJsonList = _projectBox.values
          .where((schoolItem) => schoolItem.projectCode != null)
          .map(projectsToJson)
          .toList();

      return projectsJsonList;
    } catch (e) {
      print("Error serving projects data: $e");
      res.statusCode = 500;

      return {"error": "Failed to fetch projects info"};
    }
  });

  //************************* POST /api/projects/bulk ************************/

  app.post("/api/projects/bulk", (req, res) async {
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

      if (!body.containsKey('projects') || body['projects'] is! List) {
        res.statusCode = 400;
        return {
          "error": "Invalid request format",
          "details": "Expected a list under the 'projects' key"
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
          // Skip malformed individual entries but log them
          print("❌ Skipping invalid project: $e");
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
  ///////////
  ///
  ///
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
