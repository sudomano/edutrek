import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
import 'package:file_picker/file_picker.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart'; // Import the file_picker package

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
      print('All Hive boxes opened successfully.');
    } catch (e) {
      print('Error opening Hive boxes: $e');
    }
  }

  Future<void> exportHiveData() async {
    setState(() {
      _isExporting = true; // Set exporting status
    });

    try {
      print('Starting data export...');

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
      };

      String jsonData = jsonEncode(exportData);
      print('Data serialized successfully.');

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
          content: Text('Backup file saved successfully at: $selectedPath'),
        ));
      } else {
        print('File saving was canceled by the user.');
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
      print('Data export process completed.');
    }
  }

// Helper function to get a unique file name by appending a number if file exists
  Future<String> _getUniqueFileName(
      String directory, String baseFileName) async {
    String filePath = '$directory/$baseFileName';
    File file = File(filePath);

    int fileCount = 1;
    while (await file.exists()) {
      String newFileName =
          baseFileName.replaceFirst('.json', '($fileCount).json');
      filePath = '$directory/$newFileName';
      file = File(filePath);
      fileCount++;
    }
    return filePath;
  }

  // Helper function to serialize data
  List<Map<String, dynamic>> _serializeBox<T>(
      Box<T>? box, Map<String, dynamic> Function(T) toJson) {
    print('Serializing box: ${box?.name ?? 'Unknown'}');
    return box?.values.map((data) => toJson(data as T)).toList() ?? [];
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
      'paymentDate': cls.paymentDate,
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
    };
  }

  Future<String?> _getExternalFilesDirectory() async {
    try {
      final directory = await getExternalStorageDirectory();
      // For Android, this will point to a directory like /storage/emulated/0/Android/data/[package_name]/files
      if (directory != null) {
        final path = '${directory.path}/backup'; // Create a backup folder
        final backupDir = Directory(path);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        return backupDir.path;
      }
    } catch (e) {
      print('Error getting external files directory: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        MediaQuery.of(context).size.width > 600; // Example threshold

    return Scaffold(
      appBar: const CustomAppBar(title: 'Export Records'),
      body: Column(
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
              color:
                  const Color.fromARGB(255, 0, 0, 0), // White text on gradient
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'All records have been exported successfully.'),
                      ));
                    },
              child: _isExporting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Export All Database Records'),
            ),
          ),
        ],
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
