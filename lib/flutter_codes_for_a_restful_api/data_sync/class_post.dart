import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';

class SyncClassesPages extends StatefulWidget {
  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

class _SyncClassesPageState extends State<SyncClassesPages> {
  Box<Classes>? _classesBox;
  Box<TeacherPaymentsPurposes>? _teacher_payments_purposesBox;
  Box<PaymentPurpose>? _payment_purposesBox;
  Box<StudentPayment>? _student_paymentsBox;
  Box<TeacherPayment>? _teacher_paymentsBox;
  Box<Student>? _studentsBox;
  Box<Withdrawal>? _withdrawalsBox;
  Box<User>? _usersBox;
  Box<Teachers>? _teachersBox;
  Box<School>? _schoolBox;
  Box<Terms>? _termsBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _classesBox = await Hive.openBox<Classes>('classes');
    _teacher_payments_purposesBox = await Hive.openBox<TeacherPaymentsPurposes>(
        'teacher_payments_purposes');
    _payment_purposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    _student_paymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    _teacher_paymentsBox =
        await Hive.openBox<TeacherPayment>('teacher_payments');
    _studentsBox = await Hive.openBox<Student>(
        'students'); // Open the box for student data
    _withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
    _usersBox = await Hive.openBox<User>('users'); // Open the box for users
    _teachersBox = await Hive.openBox<Teachers>('teachers');
    _schoolBox = await Hive.openBox<School>('school');
    _termsBox = await Hive.openBox<Terms>('terms');
    print('All Hive boxes opened successfully.');
  }

  Future<List<TeacherPaymentsPurposes>>
      _fetch_teacher_payments_purposesForCreate() async {
    print('Fetching TeacherPaymentsPurposes for creation...');
    List<TeacherPaymentsPurposes> createTeacherPaymentsPurposes =
        _teacher_payments_purposesBox!.values
            .where((cls) =>
                cls.syncStatus == false && cls.operationType == 'create')
            .toList();
    print(
        '${createTeacherPaymentsPurposes.length} teacherPaymentsPurposes found for creation.');
    return createTeacherPaymentsPurposes;
  }

  Future<List<Classes>> _fetchClassesForCreate() async {
    print('Fetching classes for creation...');
    List<Classes> createClasses = _classesBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createClasses.length} classes found for creation.');
    return createClasses;
  }

  Future<List<PaymentPurpose>> _fetch_payment_purposesClassesForCreate() async {
    print('Fetching PaymentPurpose for creation...');
    List<PaymentPurpose> createPaymentPurpose = _payment_purposesBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createPaymentPurpose.length} PaymentPurpose found for creation.');
    return createPaymentPurpose;
  }

  Future<List<StudentPayment>> _fetch_student_paymentsForCreate() async {
    print('Fetching StudentPayment for creation...');
    List<StudentPayment> createStudentPayment = _student_paymentsBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createStudentPayment.length} StudentPayment found for creation.');
    return createStudentPayment;
  }

  Future<List<TeacherPayment>> _fetch_teacher_paymentsForCreate() async {
    print('Fetching TeacherPayment for creation...');
    List<TeacherPayment> createTeacherPayment = _teacher_paymentsBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createTeacherPayment.length} TeacherPayment found for creation.');
    return createTeacherPayment;
  }

  Future<List<Student>> _fetch_studentsForCreate() async {
    print('Fetching students for creation...');
    List<Student> createStudent = _studentsBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createStudent.length} Student found for creation.');
    return createStudent;
  }

  Future<List<Withdrawal>> _fetch_withdrawalsForCreate() async {
    print('Fetching Withdrawal for creation...');
    List<Withdrawal> createWithdrawal = _withdrawalsBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createWithdrawal.length} Withdrawal found for creation.');
    return createWithdrawal;
  }

  Future<List<User>> _fetch_usersForCreate() async {
    print('Fetching User for creation...');
    List<User> createUser = _usersBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createUser.length} User found for creation.');
    return createUser;
  }

  Future<List<Teachers>> _fetch_teachersForCreate() async {
    print('Fetching Teachers for creation...');
    List<Teachers> createTeachers = _teachersBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createTeachers.length} Teachers found for creation.');
    return createTeachers;
  }

  Future<List<School>> _fetch_schoolForCreate() async {
    print('Fetching School for creation...');
    List<School> createSchool = _schoolBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createSchool.length} School found for creation.');
    return createSchool;
  }

  Future<List<Terms>> _fetch_termsForCreate() async {
    print('Fetching Terms for creation...');
    List<Terms> createTerms = _termsBox!.values
        .where(
            (cls) => cls.syncStatus == false && cls.operationType == 'create')
        .toList();
    print('${createTerms.length} classes found for creation.');
    return createTerms;
  }

  // Sync classes to MySQL
  Future<void> _syncClasses() async {
    try {
      List<TeacherPaymentsPurposes> createTeacherPaymentsPurposes =
          await _fetch_teacher_payments_purposesForCreate();
      for (TeacherPaymentsPurposes cls in createTeacherPaymentsPurposes) {
        await _createTeacherPaymentsPurposesInMySQL(cls);
        //await _updateSyncStatusTeacherPaymentsPurposes(
        //    cls); // Mark class as synced
      }
      // Sync classes with create operation
      List<Classes> createClasses = await _fetchClassesForCreate();
      for (Classes cls in createClasses) {
        await _createClassInMySQL(cls);
        // await _updateSyncStatus(cls); // Mark class as synced
      }

      List<PaymentPurpose> createPaymentPurpose =
          await _fetch_payment_purposesClassesForCreate();
      for (PaymentPurpose cls in createPaymentPurpose) {
        await _createPaymentPurposeInMySQL(cls);
        // await _updateSyncStatusPaymentPurpose(cls); // Mark class as synced
      }
      List<StudentPayment> createStudentPayment =
          await _fetch_student_paymentsForCreate();
      for (StudentPayment cls in createStudentPayment) {
        await _createStudentPaymentInMySQL(cls);
        // await _updateSyncStatusStudentPayment(cls); // Mark class as synced
      }
      List<TeacherPayment> createTeacherPayment =
          await _fetch_teacher_paymentsForCreate();
      for (TeacherPayment cls in createTeacherPayment) {
        await _createTeacherPaymentInMySQL(cls);
        // await _updateSyncStatusTeacherPayment(cls); // Mark class as synced
      }
      List<Student> createStudent = await _fetch_studentsForCreate();
      for (Student cls in createStudent) {
        await _createClassInMySQLStudent(cls);
        // await _updateSyncStatusStudent(cls); // Mark class as synced
      }
      List<Withdrawal> createWithdrawal = await _fetch_withdrawalsForCreate();
      for (Withdrawal cls in createWithdrawal) {
        await _createClassInMySQLWithdrawal(cls);
        //await _updateSyncStatusStudentWithdrawal(cls); // Mark class as synced
      }
      List<User> createUser = await _fetch_usersForCreate();
      for (User cls in createUser) {
        await _createClassInMySQLUser(cls);
        // await _updateSyncStatusUser(cls); // Mark class as synced
      }
      List<Teachers> createTeachers = await _fetch_teachersForCreate();
      for (Teachers cls in createTeachers) {
        await _createClassInMySQLTeachers(cls);
        //  await _updateSyncStatusTeachers(cls); // Mark class as synced
      }
      List<School> createSchool = await _fetch_schoolForCreate();
      for (School cls in createSchool) {
        await _createClassInMySQLSchool(cls);
        //  await _updateSyncStatusSchool(cls); // Mark class as synced
      }
      List<Terms> createTerms = await _fetch_termsForCreate();
      for (Terms cls in createTerms) {
        await _createClassInMySQLTerms(cls);
        //  await _updateSyncStatusTerms(cls); // Mark class as synced
      }

      // Sync classes with update operation
      /* List<Classes> updateClasses = await _fetchClassesForUpdate();
      for (Classes cls in updateClasses) {
        await _updateClassInMySQL(cls);
        // await _updateSyncStatus(cls); // Mark class as synced
      }
*/
      print('All models have been synced.');
    } catch (e) {
      print('Error syncing classes: $e');
    }
  }

  // Convert Classes object to JSON
  Map<String, dynamic> _classToJson(Classes cls) {
    return {
      'id': cls.id,
      'className': cls.className,
      'date': cls.date.toIso8601String(),
      'termId': cls.termId,
    };
  }

  Map<String, dynamic> _schoolToJson(School cls) {
    return {
      'id': cls.id,
      'schoolName': cls.schoolName,
      'schoolAddress': cls.schoolAddress,
      'schoolPhoneNumber': cls.schoolPhoneNumber,
      'schoolEmail': cls.schoolEmail,
      'termId': cls.termId,
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
      'presentDates':
          cls.presentDates.map((date) => date.toIso8601String()).toList(),
      'absentDates':
          cls.absentDates.map((date) => date.toIso8601String()).toList(),
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
    };
  }

  Map<String, dynamic> _paymentPurposeToJson(PaymentPurpose cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
    };
  }

  Map<String, dynamic> _teacherPaymentsPurposeToJson(
      TeacherPaymentsPurposes cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
      'termId': cls.termId,
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
    };
  }

  Map<String, dynamic> _withdrawalToJson(Withdrawal cls) {
    return {
      'id': cls.id,
      'amount': cls.amount,
      'withdrawalPurpose': cls.withdrawalPurpose,
      'termId': cls.termId,
      'date': cls.date.toIso8601String(),
    };
  }

  Future<void> _createTeacherPaymentsPurposesInMySQL(
      TeacherPaymentsPurposes newClass) async {
    final Map<String, dynamic> jsonData =
        _teacherPaymentsPurposeToJson(newClass);
    print(
        'Creating _teacherPaymentsPurposeToJson in MySQL: ${newClass.paymentPurpose}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_purposes_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'teacher_payment_purpose ${newClass.paymentPurpose} created successfully.');
      } else {
        throw Exception('Failed to create teacher_payment_purposes.');
      }
    } catch (e) {
      print('Error creating teacher_payment_purposes: $e');
    }
  }

  // Create class in MySQL
  Future<void> _createClassInMySQL(Classes newClass) async {
    final Map<String, dynamic> jsonData = _classToJson(newClass);
    print('Creating class in MySQL: ${newClass.className}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Class ${newClass.className} created successfully.');
      } else {
        throw Exception('Failed to create class.');
      }
    } catch (e) {
      print('Error creating class: $e');
    }
  }

  Future<void> _createPaymentPurposeInMySQL(PaymentPurpose newClass) async {
    final Map<String, dynamic> jsonData = _paymentPurposeToJson(newClass);
    print('Creating PaymentPurpose in MySQL: ${newClass.paymentPurpose}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'student_payment_purpose ${newClass.paymentPurpose} created successfully.');
      } else {
        throw Exception('Failed to create student_payment_purpose.');
      }
    } catch (e) {
      print('Error creating student_payment_purpose: $e');
    }
  }

  Future<void> _createStudentPaymentInMySQL(StudentPayment newClass) async {
    final Map<String, dynamic> jsonData = _studentPaymentToJson(newClass);
    print('Creating StudentPayment in MySQL: ${newClass.studentSurname}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            'student_payment ${newClass.studentSurname} created successfully.');
      } else {
        throw Exception('Failed to create student_payment.');
      }
    } catch (e) {
      print('Error creating student_payment: $e');
    }
  }

  Future<void> _createTeacherPaymentInMySQL(TeacherPayment newClass) async {
    final Map<String, dynamic> jsonData = _teacherPaymentclassToJson(newClass);
    print('Creating _teacherPayment in MySQL: ${newClass.studentSurname}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teacher_payment_information_ipi.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('teacherPayment ${newClass.studentName} created successfully.');
      } else {
        throw Exception('Failed to create teacherPayment.');
      }
    } catch (e) {
      print('Error creating teacherPayment: $e');
    }
  }

  Future<void> _createClassInMySQLStudent(Student newClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(newClass);
    print('Creating studentInfo in MySQL: ${newClass.surname}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('student_information ${newClass.name} created successfully.');
      } else {
        throw Exception('Failed to create student_information.');
      }
    } catch (e) {
      print('Error creating student_information: $e');
    }
  }

  Future<void> _createClassInMySQLWithdrawal(Withdrawal newClass) async {
    final Map<String, dynamic> jsonData = _withdrawalToJson(newClass);
    print('Creating Withdrawal in MySQL: ${newClass.withdrawalPurpose}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Withdrawal ${newClass.withdrawalPurpose} created successfully.');
      } else {
        throw Exception('Failed to create Withdrawal.');
      }
    } catch (e) {
      print('Error creating Withdrawal: $e');
    }
  }

  Future<void> _createClassInMySQLUser(User newClass) async {
    final Map<String, dynamic> jsonData = _userToJson(newClass);
    print('Creating User in MySQL: ${newClass.username}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/user_information_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('User ${newClass.username} created successfully.');
      } else {
        throw Exception('Failed to create User.');
      }
    } catch (e) {
      print('Error creating User: $e');
    }
  }

  Future<void> _createClassInMySQLTeachers(Teachers newClass) async {
    final Map<String, dynamic> jsonData = _teacherToJson(newClass);
    print('Creating Teachers in MySQL: ${newClass.surname}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/teachers_information_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Teachers ${newClass.surname} created successfully.');
      } else {
        throw Exception('Failed to create Teachers.');
      }
    } catch (e) {
      print('Error creating Teachers: $e');
    }
  }

  Future<void> _createClassInMySQLSchool(School newClass) async {
    final Map<String, dynamic> jsonData = _schoolToJson(newClass);
    print('Creating School in MySQL: ${newClass.schoolName}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/school_info_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('School ${newClass.schoolName} created successfully.');
      } else {
        throw Exception('Failed to create School.');
      }
    } catch (e) {
      print('Error creating School: $e');
    }
  }

  Future<void> _createClassInMySQLTerms(Terms newClass) async {
    final Map<String, dynamic> jsonData = _termsToJson(newClass);
    print('Creating Terms in MySQL: ${newClass.termName}');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Terms ${newClass.termName} created successfully.');
      } else {
        throw Exception('Failed to create Terms.');
      }
    } catch (e) {
      print('Error creating Terms: $e');
    }
  }

  // Update class in MySQL
  Future<void> _updateClassInMySQL(Classes updatedClass) async {
    final Map<String, dynamic> jsonData = _classToJson(updatedClass);
    print('Updating class in MySQL: ${updatedClass.className}');

    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print('Class ${updatedClass.className} updated successfully.');
      } else {
        throw Exception('Failed to update class.');
      }
    } catch (e) {
      print('Error updating class: $e');
    }
  }

  // Update syncStatus and operationType in Hive
  Future<void> _updateSyncStatus(Classes cls) async {
    await _classesBox!.put(
      cls.id,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('Class ${cls.className} marked as synced.');
  }

  Future<void> _updateSyncStatusTeacherPaymentsPurposes(
      TeacherPaymentsPurposes cls) async {
    await _teacher_payments_purposesBox!.put(
      cls.id,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('teacher_payments_purposes ${cls.paymentPurpose} marked as synced.');
  }

  Future<void> _updateSyncStatusPaymentPurpose(PaymentPurpose cls) async {
    await _payment_purposesBox!.put(
      cls.id,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('paymentPurpose ${cls.paymentPurpose} marked as synced.');
  }

  Future<void> _updateSyncStatusStudentPayment(StudentPayment cls) async {
    await _student_paymentsBox!.put(
      cls.studentSurname,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('student_payments ${cls.studentSurname} marked as synced.');
  }

  Future<void> _updateSyncStatusTeacherPayment(TeacherPayment cls) async {
    await _teacher_paymentsBox!.put(
      cls.studentSurname,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('teacher_payments ${cls.studentSurname} marked as synced.');
  }

  Future<void> _updateSyncStatusStudent(Student cls) async {
    await _studentsBox!.put(
      cls.surname,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('Student ${cls.surname} marked as synced.');
  }

  Future<void> _updateSyncStatusStudentWithdrawal(Withdrawal cls) async {
    await _withdrawalsBox!.put(
      cls.withdrawalPurpose,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('Withdrawal ${cls.withdrawalPurpose} marked as synced.');
  }

  Future<void> _updateSyncStatusUser(User cls) async {
    await _usersBox!.put(
      cls.username,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('User ${cls.username} marked as synced.');
  }

  Future<void> _updateSyncStatusTeachers(Teachers cls) async {
    await _teachersBox!.put(
      cls.surname,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('Teachers ${cls.surname} marked as synced.');
  }

  Future<void> _updateSyncStatusSchool(School cls) async {
    await _schoolBox!.put(
      cls.schoolName,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('School ${cls.schoolName} marked as synced.');
  }

  Future<void> _updateSyncStatusTerms(Terms cls) async {
    await _termsBox!.put(
      cls.termName,
      cls.copyWith(syncStatus: true, operationType: 'none'),
    );
    print('Terms ${cls.termName} marked as synced.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Synchronization')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _syncClasses();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('all records have been synchronized Successfully.'),
            ));
          },
          child: Text('Sync All New Records'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classesBox?.close();
    super.dispose();
  }
}
/*import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';

class SyncClassesPage extends StatefulWidget {
  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

class _SyncClassesPageState extends State<SyncClassesPage> {
  Box<Classes>? _classesBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _classesBox = await Hive.openBox<Classes>('classes');
    print('Hive box opened successfully.');
    // Debug: Print all data in the classesBox
    print('All classes in the box:');
    _classesBox!.values.forEach((cls) => print(cls.className));
  }

  // Fetch all classes from Hive for testing purposes (ignoring syncStatus)
  Future<List<Classes>> _fetchClassesToSync() async {
    print('Fetching all classes (ignoring syncStatus)');
    List<Classes> allClasses = _classesBox!.values.toList();
    print('${allClasses.length} classes found.');
    return allClasses;
  }

  // Function to sync classes to MySQL
  Future<void> _syncClasses() async {
    try {
      List<Classes> classesToSync = await _fetchClassesToSync();

      if (classesToSync.isEmpty) {
        print('No classes found to sync.');
        return;
      }

      for (Classes cls in classesToSync) {
        print('Syncing class: ${cls.className}');
        await _createClassInMySQL(cls);

        // Mark the class as synced by updating the syncStatus
        await _classesBox!.put(
          cls.id,
          cls.copyWith(syncStatus: true),
        );
        print('Class ${cls.className} synced successfully.');
      }

      print('All classes have been synced.');
    } catch (e) {
      print('Error syncing classes: $e');
    }
  }

  // Convert Classes object to JSON format
  Map<String, dynamic> _classToJson(Classes newClass) {
    return {
      'className': newClass.className,
      'date': newClass.date.toIso8601String(),
      'termId': newClass.termId,
    };
  }

  // Function to create a new class in MySQL
  Future<void> _createClassInMySQL(Classes newClass) async {
    final Map<String, dynamic> jsonData = _classToJson(newClass);

    print('Attempting to create class in MySQL: ${newClass.className}');
    print('Data being sent: $jsonData');

    try {
      final response = await http.post(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/classes.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(jsonData),
      );

      print('HTTP response code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Class ${newClass.className} created successfully in MySQL.');
      } else {
        print(
            'Failed to create class ${newClass.className}. Status code: ${response.statusCode}, Response: ${response.body}');
        throw Exception('Failed to create class.');
      }
    } catch (e) {
      print('Error creating class in MySQL: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Classes'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _syncClasses();
          },
          child: Text('Sync All Classes'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classesBox?.close();
    super.dispose();
  }
}
*/