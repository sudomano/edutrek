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
import 'package:zitf_system/database/projects/project_daily_activity_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_student_payment_model.dart';
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
  Box<ProjectStudentPayment>? _projectStudentPaymentBox;
  Box<ExceptionalStudents>? _exceptionalStudentsBox;

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
    _projectStudentPaymentBox =
        await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
    _exceptionalStudentsBox =
        await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
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
        String jsonData = await File(filePath).readAsString();
        Map<String, dynamic> importData = jsonDecode(jsonData);

        // Clear existing data (optional)
        await _clearHiveData();

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
            _project_itemsFromJson, _projectItemBox);
        await _deserializeAndSave(importData['daily_activities'],
            _daily_activitiesFromJson, _dailyActivityBox);

        await _deserializeAndSave(importData['project_student_payments'],
            _project_student_paymentsFromJson, _projectStudentPaymentBox);
        await _deserializeAndSave(importData['exceptions'], _exceptionsFromJson,
            _exceptionalStudentsBox);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data imported successfully.'),
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
    await _projectStudentPaymentBox?.clear();
    await _exceptionalStudentsBox?.clear();
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
      modifiedFields: parseStringList(json['modifiedFields']),
      terms: json['terms'] != null
          ? List<String>.from(jsonDecode(json['terms']))
          : null,
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
          ? List<String>.from(jsonDecode(json['terms']))
          : null,
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
          ? List<String>.from(jsonDecode(json['terms']))
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),

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
          ? List<String>.from(jsonDecode(json['terms']))
          : null,
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
        modifiedFields: parseStringList(json['modifiedFields']),
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
        modifiedFields: parseStringList(json['modifiedFields']),
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
        modifiedFields: parseStringList(json['modifiedFields']),
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
      modifiedFields: parseStringList(json['modifiedFields']),
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
        modifiedFields: parseStringList(json['modifiedFields']),
      );

  ProjectItem _project_itemsFromJson(Map<String, dynamic> json) => ProjectItem(
        projectItemCode: json['projectItemCode'],
        projectCode: json['projectCode'],
        name: json['name'],
        amount: json['amount'],
        isStudentFee: json['isStudentFee'],
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        modifiedFields: parseStringList(json['modifiedFields']),
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
        modifiedFields: parseStringList(json['modifiedFields']),
      );

  ProjectStudentPayment _project_student_paymentsFromJson(
          Map<String, dynamic> json) =>
      ProjectStudentPayment(
        projectStudentPaymentCode: json['projectStudentPaymentCode'],
        studentId: json['studentId'],
        projectCode: json['projectCode'],
        itemId: json['itemId'],
        amountPaid: json['amountPaid'],
        balance: json['balance'],
        syncStatus: json['syncStatus'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        operationType: json['operationType'],
        modifiedFields: parseStringList(json['modifiedFields']),
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
                        await importHiveData();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              'All records have been imported successfully.'),
                        ));
                      },
                child: _isImporting
                    ? const CircularProgressIndicator(color: Colors.white)
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
