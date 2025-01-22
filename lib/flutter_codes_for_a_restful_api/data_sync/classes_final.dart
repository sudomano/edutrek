import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';

import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
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
  bool _isSyncing = false;
  bool _isSyncings = false;
  bool areDomainsActive = false;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
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

    print('All Hive boxes opened successfully.');
  }

  Future<List<Classes>> _fetchClassesForCreate() async {
    print('Fetching classes for creation...');
    List<Classes> createClasses = _classesBox!.values
        .where((cls) => cls.syncStatus == false && cls.classCode != null)
        .toList();
    print('${createClasses.length} classes found for creation.');

    return createClasses;
  }

  Future<List<School>> _fetch_schoolForCreate() async {
    print('Fetching School for creation...');
    List<School> createSchools = _schoolBox!.values
        .where((cls) => cls.syncStatus == false && cls.schoolCode != null)
        .toList();
    print('${createSchools.length} Schools found for creation.');

    return createSchools;
  }

  Future<List<Terms>> _fetch_termsForCreate() async {
    print('Fetching Terms for creation...');
    List<Terms> createTerms = _termsBox!.values
        .where((cls) => cls.syncStatus == false && cls.termId != null)
        .toList();
    print('${createTerms.length} terms found for creation.');

    return createTerms;
  }

  Future<List<Withdrawal>> _fetch_withdrawalsForCreate() async {
    print('Fetching Withdrawal for creation...');
    List<Withdrawal> createWithdrawal = _withdrawalsBox!.values
        .where((cls) => cls.syncStatus == false && cls.withdrawalCode != null)
        .toList();
    print('${createWithdrawal.length} Withdrawal found for creation.');
    return createWithdrawal;
  }

  Future<List<Student>> _fetch_studentsForCreate() async {
    print('Fetching students for creation...');
    List<Student> createStudent = _studentsBox!.values
        .where((cls) => cls.syncStatus == false && cls.studentIdNumber != null)
        .toList();
    print('${createStudent.length} Student found for creation.');
    return createStudent;
  }

  Future<List<User>> _fetch_usersForCreate() async {
    print('Fetching User for creation...');
    List<User> createUser = _usersBox!.values
        .where((cls) => cls.syncStatus == false && cls.userCode != null)
        .toList();
    print('${createUser.length} User found for creation.');
    return createUser;
  }

  Future<List<PaymentPurpose>> _fetch_paymentPurposesForCreate() async {
    print('Fetching PaymentPurpose for creation...');
    List<PaymentPurpose> createPaymentPurpose = _payment_purposesBox!.values
        .where((cls) => cls.syncStatus == false && cls.purposeCode != null)
        .toList();
    print('${createPaymentPurpose.length} PaymentPurpose found for creation.');
    return createPaymentPurpose;
  }

  Future<List<StudentPayment>> _fetch_studentPaymentsForCreate() async {
    print('Fetching StudentPayment for creation...');
    List<StudentPayment> createStudentPayment = _student_paymentsBox!.values
        .where((cls) => cls.syncStatus == false && cls.receiptNumber != null)
        .toList();
    print('${createStudentPayment.length} StudentPayment found for creation.');
    return createStudentPayment;
  }

  Future<List<Teachers>> _fetch_teachersForCreate() async {
    print('Fetching Teachers for creation...');
    List<Teachers> createTeachers = _teachersBox!.values
        .where((cls) => cls.syncStatus == false && cls.IdNumber != null)
        .toList();
    print('${createTeachers.length} Teachers found for creation.');
    return createTeachers;
  }

  Future<List<TeacherPayment>> _fetch_teacher_paymentsForCreate() async {
    print('Fetching TeacherPayment for creation...');
    List<TeacherPayment> createTeacherPayment = _teacher_paymentsBox!.values
        .where((cls) => cls.syncStatus == false && cls.receiptNumber != null)
        .toList();
    print('${createTeacherPayment.length} TeacherPayment found for creation.');
    return createTeacherPayment;
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

      print('All models have been synced.');
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

  //=================== techers payment  sync =========================

  Future<void> _createTeacherPaymentInMySQL(TeacherPayment newClass) async {
    final Map<String, dynamic> jsonData = _teacherPaymentclassToJson(newClass);
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newClass.receiptNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php?receiptNumber=${newClass.receiptNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newClass.purposeCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php?purposeCode=${newClass.purposeCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php?IdNumber=${newClass.IdNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php?IdNumber=${newClass.IdNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newClass.receiptNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?receiptNumber=${newClass.receiptNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newClass.purposeCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?purposeCode=${newClass.purposeCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newClass.userCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php?userCode=${newClass.userCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newClass.studentIdNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?studentIdNumber=${newClass.studentIdNumber}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newClass.withdrawalCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php?withdrawalCode=${newClass.withdrawalCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newClass.termId}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?termId=${newClass.termId}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php?classCode=${newClass.classCode}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'classes_information ${newClass.classCode} created successfully.');
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php?classCode=${updatedClass.classCode}'),
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
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${newClass.schoolCode}'),
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
    print('Updating School in MySQL: ${updatedClass.schoolCode}');
    setState(() {
      _isSyncings = true;
    });
    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php?schoolCode=${updatedClass.schoolCode}'),
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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Synchronization'),
      body: Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sync All Records Button
                  const SizedBox(
                    height: 5,
                  ),
                  buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    'Synchronization',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: const Color.fromARGB(
                          255, 0, 0, 0), // White text on gradient
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
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
                                const Color.fromARGB(255, 255, 255, 255),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (areDomainsActive) {
                              await _syncModels();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                  'All records have been synchronized successfully.',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor:
                                    Color.fromARGB(255, 255, 255, 255),
                              ));
                            } else {
                              _showDomainsInactiveMessage(context);
                            }
                          },
                          icon: const Icon(Icons.cloud_upload, size: 24),
                          label: const Text(
                            'Push Records To The Cloud',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
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
                                const Color.fromARGB(255, 255, 255, 255),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (areDomainsActive) {
                              await _showModelSelectionDialog(context);
                            } else {
                              _showDomainsInactiveMessage(context);
                            }
                          },
                          icon: const Icon(Icons.cloud_download, size: 24),
                          label: const Text(
                            'Pull  Records From The Cloud',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
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

  Future<void> _fetchAndSyncClasses() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php';
    setState(() {
      _isSyncing = true;
    });
    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> classes = jsonDecode(response.body);

        for (var classData in classes) {
          DateTime parsedDate =
              DateTime.tryParse(classData['date']) ?? DateTime.now();

          Classes fetchedClass = Classes(
            id: int.tryParse(classData['fid'] ?? '0') ?? 0,
            classCode: classData['classCode'],
            className: classData['className'],
            date: parsedDate, // Assign the parsed DateTime
            termId: classData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingClassList = _classesBox!.values
              .where(
                (classes) => classes.classCode == fetchedClass.classCode,
              )
              .toList();

          Classes? existingClasses =
              existingClassList.isNotEmpty ? existingClassList.first : null;

          if (existingClasses?.classCode != null) {
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
                ..lastModified = DateTime.now();
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php';
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php';
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php';
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php';
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
                ..lastModified = DateTime.now();

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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php';
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php';
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php';
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
          );

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
                ..lastModified = DateTime.now();
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php';

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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php';
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
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php';
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

  @override
  void dispose() {
    super.dispose();
  }
}
