import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';

class FewPost extends StatefulWidget {
  const FewPost({super.key});

  @override
  _SyncClassesPageState createState() => _SyncClassesPageState();
}

class _SyncClassesPageState extends State<FewPost> {
  Box<PaymentPurpose>? _payment_purposesBox;
  Box<StudentPayment>? _student_paymentsBox;
  Box<Student>? _studentsBox;
  Box<Terms>? _termsBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _payment_purposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    _student_paymentsBox =
        await Hive.openBox<StudentPayment>('student_payments');
    _studentsBox = await Hive.openBox<Student>(
        'students'); // Open the box for student data
    _termsBox = await Hive.openBox<Terms>('terms');
    print('All Hive boxes opened successfully.');
  }

  Future<List<PaymentPurpose>> _fetch_payment_purposesClassesForCreate() async {
    print('Fetching PaymentPurpose for creation...');
    List<PaymentPurpose> createPaymentPurpose = _payment_purposesBox!.values
        .where((cls) => cls.syncStatus == false)
        .toList();
    print('${createPaymentPurpose.length} PaymentPurpose found for creation.');

// Print details of each record
    for (var paymentPurpose in createPaymentPurpose) {
      print('PaymentPurpose ID: ${paymentPurpose.id}, '
          'Operation Type: ${paymentPurpose.operationType}, '
          'Sync Status: ${paymentPurpose.syncStatus}');
    }

    return createPaymentPurpose;
  }

  Future<List<StudentPayment>> _fetch_student_paymentsForCreate() async {
    print('Fetching StudentPayment for creation...');
    List<StudentPayment> createStudentPayment = _student_paymentsBox!.values
        .where((cls) => cls.syncStatus == false)
        .toList();
    print('${createStudentPayment.length} StudentPayment found for creation.');

    for (var paymentPurpose in createStudentPayment) {
      print('PaymentPurpose ID: ${paymentPurpose.id}, '
          'Operation Type: ${paymentPurpose.operationType}, '
          'Sync Status: ${paymentPurpose.syncStatus}');
    }

    return createStudentPayment;
  }

  Future<List<Student>> _fetch_studentsForCreate() async {
    print('Fetching students for creation...');
    List<Student> createStudent =
        _studentsBox!.values.where((cls) => cls.syncStatus == false).toList();
    print('${createStudent.length} Student found for creation.');

    for (var paymentPurpose in createStudent) {
      print('PaymentPurpose ID: ${paymentPurpose.id}, '
          'Operation Type: ${paymentPurpose.operationType}, '
          'Sync Status: ${paymentPurpose.syncStatus}');
    }

    return createStudent;
  }

  Future<List<Terms>> _fetch_termsForCreate() async {
    print('Fetching Terms for creation...');
    List<Terms> createTerms =
        _termsBox!.values.where((cls) => cls.syncStatus == false).toList();

    for (var paymentPurpose in createTerms) {
      print('PaymentPurpose ID: ${paymentPurpose.id}, '
          'Operation Type: ${paymentPurpose.operationType}, '
          'Sync Status: ${paymentPurpose.syncStatus}');
    }

    print('${createTerms.length} terms found for creation.');
    return createTerms;
  }

  // Sync models to MySQL
  Future<void> _syncModels() async {
    try {
      // Sync PaymentPurpose records
      List<PaymentPurpose> paymentPurposes = _payment_purposesBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (PaymentPurpose cls in paymentPurposes) {
        if (cls.operationType == 'create') {
          await _createPaymentPurposeInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updatePaymentPurposeInMySQL(cls);
        }
      }

      // Sync StudentPayment records
      List<StudentPayment> studentPayments = _student_paymentsBox!.values
          .where((cls) => cls.syncStatus == false)
          .toList();
      for (StudentPayment cls in studentPayments) {
        if (cls.operationType == 'create') {
          await _createStudentPaymentInMySQL(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentPaymentInMySQL(cls);
        }
      }

      // Sync Student records
      List<Student> students =
          _studentsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Student cls in students) {
        if (cls.operationType == 'create') {
          await _createClassInMySQLStudent(cls);
        } else if (cls.operationType == 'update') {
          await _updateStudentInMySQL(cls);
        }
      }

      // Sync Terms records
      List<Terms> terms =
          _termsBox!.values.where((cls) => cls.syncStatus == false).toList();
      for (Terms cls in terms) {
        if (cls.operationType == 'create') {
          await _createClassInMySQLTerms(cls);
        } else if (cls.operationType == 'update') {
          await _updateTermsInMySQL(cls);
        }
      }

      print('All models have been synced.');
    } catch (e) {
      print('Error syncing models: $e');
    }
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

  Map<String, dynamic> _paymentPurposeToJson(PaymentPurpose cls) {
    return {
      'id': cls.id,
      'paymentPurpose': cls.paymentPurpose,
      'purposeAmount': cls.purposeAmount,
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

  Future<void> _createClassInMySQLStudent(Student newClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(newClass);

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

  Future<void> _updatePaymentPurposeInMySQL(PaymentPurpose updatedClass) async {
    final Map<String, dynamic> jsonData = _paymentPurposeToJson(updatedClass);
    print('Updating PaymentPurpose in MySQL: ${updatedClass.paymentPurpose}');

    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php?pid=${updatedClass.id}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print(
            'PaymentPurpose ${updatedClass.paymentPurpose} updated successfully.');
      } else {
        throw Exception('Failed to update PaymentPurpose.');
      }
    } catch (e) {
      print('Error updating PaymentPurpose: $e');
    }
  }

  Future<void> _updateStudentPaymentInMySQL(StudentPayment updatedClass) async {
    final Map<String, dynamic> jsonData = _studentPaymentToJson(updatedClass);
    print('Updating StudentPayment in MySQL: ${updatedClass.studentSurname}');

    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_api.php?pid=${updatedClass.id}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print(
            'StudentPayment ${updatedClass.studentSurname} updated successfully.');
      } else {
        throw Exception('Failed to update StudentPayment.');
      }
    } catch (e) {
      print('Error updating StudentPayment: $e');
    }
  }

  Future<void> _updateStudentInMySQL(Student updatedClass) async {
    final Map<String, dynamic> jsonData = _studentInfoToJson(updatedClass);
    print('Updating Student in MySQL: ${updatedClass.name}');

    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_information_api.php?pid=${updatedClass.id}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print('Student ${updatedClass.name} updated successfully.');
      } else {
        throw Exception('Failed to update Student.');
      }
    } catch (e) {
      print('Error updating Student: $e');
    }
  }

  Future<void> _updateTermsInMySQL(Terms updatedClass) async {
    final Map<String, dynamic> jsonData = _termsToJson(updatedClass);
    print('Updating Terms in MySQL: ${updatedClass.termName}');

    try {
      final response = await http.put(
        Uri.parse(
            'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php?pid=${updatedClass.id}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print('Terms ${updatedClass.termName} updated successfully.');
      } else {
        throw Exception('Failed to update Terms.');
      }
    } catch (e) {
      print('Error updating Terms: $e');
    }
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
            await _syncModels();
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
    _studentsBox?.close();
    _termsBox?.close();
    _payment_purposesBox?.close();
    _student_paymentsBox?.close();
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