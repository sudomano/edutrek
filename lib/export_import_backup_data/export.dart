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
  Box<ProjectStudentPayment>? _projectStudentPaymentBox;

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
      _projectStudentPaymentBox =
          await Hive.openBox<ProjectStudentPayment>('projectStudentPayments');
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
        'project_items': _serializeBox(_projectItemBox, _project_itemsToJson),
        'daily_activities':
            _serializeBox(_dailyActivityBox, _daily_activitiesToJson),
        'project_student_payments': _serializeBox(
            _projectStudentPaymentBox, _project_student_paymentsToJson),
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
      'terms': cls.terms != null
          ? jsonEncode(cls.terms) // JSON encode the list
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

  Map<String, dynamic> _domainsToJson(DomainRecord domain) => {
        'domainName': domain.domainName,
        'areDomainsActive': domain.areDomainsActive,
        'syncStatus': domain.syncStatus,
        'operationType': domain.operationType,
        'lastModified': domain.lastModified?.toIso8601String(),
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
        'modifiedFields': user.modifiedFields,
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
    _projectStudentPaymentBox?.close();
  }
}
