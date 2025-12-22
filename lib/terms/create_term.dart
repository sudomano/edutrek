import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teachers.dart';

import 'package:zitf_system/global files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class CreateTermScreen extends StatefulWidget {
  const CreateTermScreen({Key? key}) : super(key: key);

  @override
  _CreateTermScreenState createState() => _CreateTermScreenState();
}

class _CreateTermScreenState extends State<CreateTermScreen> {
  final _termNameController = TextEditingController();
  DateTime _startDate = DateTime.now();

  // Variables for progress indicator
  bool _isProcessing = false;
  String _progressMessage = '';

  @override
  void dispose() {
    _termNameController.dispose();
    super.dispose();
  }

  // Helper to update progress message and force rebuild
  void _updateProgress(String message) {
    setState(() {
      _progressMessage = message;
    });
  }

  Future<void> _saveTerm() async {
    setState(() {
      _isProcessing = true;
      _progressMessage = 'Checking existing terms...';
    });

    try {
      var termsBox = await Hive.openBox<Terms>('terms');

      if (termsBox.isEmpty) {
        // No terms exist, so proceed with creating a new term directly
        _updateProgress('No existing term found. Creating new term...');

        await _createNewTerm();
      } else {
        // Check for existing terms with status 'Opened'
        var openedTerms =
            termsBox.values.where((term) => term.status == 'Opened');
        Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

        if (openedTerm != null) {
          // An opened term already exists, notify the user
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'A term with ID ${openedTerm.termId} is currently opened. Please close it before starting a new term.',
              ),
            ),
          );
          return;
        } else {
          // Check for closed and active terms
          _updateProgress('Looking for active closed term data...');
          var activeTerms = termsBox.values
              .where((term) => term.status == 'Closed' && term.isActive);
          Terms? activeTerm = activeTerms.isNotEmpty ? activeTerms.first : null;

          if (activeTerm != null) {
            // Proceed with copying data and creating a new term\
            // Prepare data for the new term
            _updateProgress('Preparing data for the new term...');
            await _prepareForNewTerm(activeTerm);
            activeTerm.isActive = false;
            _updateProgress('Creating new term...');
            await _createNewTerm();
          } else {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Cannot create a new term as all terms are totally closed.'),
              ),
            );
            return;
          }
        }
      }
      setState(() {
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
        ),
      );
    }
  }

  Future<void> _createNewTerm() async {
    if (_termNameController.text.isNotEmpty) {
      // Store term information temporarily
      String termName = _termNameController.text.trim();

      var termsBox = await Hive.openBox<Terms>('terms');

      // Check for duplicate terms by termId or termName
      bool isDuplicate = false;

      for (var activeTerm in termsBox.values) {
        if (termName.toLowerCase() == activeTerm.termId.toLowerCase() ||
            termName.toLowerCase() == activeTerm.termName.toLowerCase()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'A term with ID ${activeTerm.termId} or Name ${activeTerm.termName} already exists. You can modify it or create a new one.',
              ),
            ),
          );
          isDuplicate = true;
          break; // Stop further checking once a duplicate is found
        }
      }
      Future<int> getNextId() async {
        final box = await Hive.openBox<Terms>('terms');
        if (box.isEmpty) return 1; // Start with ID 1 if no records exist

        int currentMaxId = box.values
            .map((e) => e.id ?? 0)
            .reduce((curr, next) => curr > next ? curr : next);
        return currentMaxId + 1;
      }

      int newId = await getNextId();
      // If no duplicate is found, proceed with creating the new term
      if (!isDuplicate) {
        // Set the global term ID
        globalTermId = termName;

        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('termId');
        modifiedFields.add('termName');
        modifiedFields.add('startDate');
        modifiedFields.add('isActive');
        modifiedFields.add('status');
        // Create the new term
        Terms newTerm = Terms(
          id: newId,
          termId: termName,
          termName: termName,
          startDate: _startDate,
          isActive: false,
          status: 'Opened',
          operationType: 'create',
          syncStatus: false,
          lastModified: DateTime.now(),
          modifiedFields: modifiedFields,
        );

        await termsBox.put(newTerm.termId, newTerm);

        // Show success message or navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New term created successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      // Show error message if required fields are missing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
    }
  }

  Future<void> _prepareForNewTerm(Terms activeTerm) async {
    // Temporary variables for the new term
    String newTermId = _termNameController.text.trim();
    String newTermName = _termNameController.text.trim();
    String oldTermId =
        activeTerm.termId; // ✅ Save old termId before changing global

    DateTime newStartDate = _startDate;
    // Open all required boxes

    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');

    // List of model boxes to update
    var modelNames = [
      paymentPurposesBox,
      teacherPaymentsPurposesBox,

      // Add more models as needed
    ];
    print("previous term global: $globalTermId");

    globalTermId = newTermId;
    _updateProgress('Updating term IDs in all models...');

    // Update the termId for all records in all models
    await _updateTermIdInAllModels(globalTermId!);
    await _updateTermsInAllModels(
        newTermId, oldTermId); // ✅ Pass oldTermId for filtering
  }

  Future<void> _copyRecords(Box box, String termId) async {
    for (var key in box.keys) {
      var item = box.get(key);

      // Only copy if the termId is not already the new termId
      if (item != null && item.termId != termId) {
        // Create a new instance with the new termId
        var newItem = item.copyWith(termId: termId);

        // Generate a new unique key for the new item
        var newKey = '${item.key}_$termId';
        await box.put(newKey, newItem);
        await _removeRedundantRecord(
            item.termId.toString(), item.termId.toString());
      }
    }
  }

  Future<void> _clearModelData(List modelNamess) async {
    for (var modelNam in modelNamess) {
      await modelNam.clear();
    }
  }

  Future<void> _updateTermIdInAllModels(String termId) async {
    var studentsBox = await _getBoxIfNotOpen<Student>('students');
    var classesBox = await _getBoxIfNotOpen<Classes>('classes');
    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');

    var modelsNames = [
      studentsBox,
      classesBox,
      paymentPurposesBox,
      teacherPaymentsPurposesBox,
      teachersBox,
    ];
    for (var modelsName in modelsNames) {
      for (var key in modelsName.keys) {
        var item = modelsName.get(key);

        // Check if item is of the specific type and cast it accordingly
        if (item != null) {
          if (item is PaymentPurpose) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(
                  termId: termId,
                  purposeCode: const Uuid().v4(), // ✅ Generate new purposeCode
                );
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is TeacherPaymentsPurposes) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(
                  termId: termId,
                  purposeCode: const Uuid().v4(), // ✅ Generate new purposeCode
                );
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          }
        }
      }
    }
  }

  Future<void> _updateTermsInAllModels(String termId, String oldTermId) async {
    var studentsBox = await _getBoxIfNotOpen<Student>('students');
    var classesBox = await _getBoxIfNotOpen<Classes>('classes');
    var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');

    var modelBoxes = [
      studentsBox,
      classesBox,
      teachersBox,
    ];

    for (var modelBox in modelBoxes) {
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        // Only proceed if the item is not null
        if (item != null) {
          // For Students
          if (item is Student) {
            // Add termId to the terms list if not already present
            if (item.terms != null &&
                item.terms!.contains(oldTermId) && // Has the previous term
                !item.terms!.contains(termId)) {
              // Not yet added to the new term
              item.terms!.add(termId); // Append the new term ID
              print(
                  'Adding termId: $termId to student with globalTermId: $globalTermId');

              await modelBox.put(key, item); // Save the updated record
            }
          }
          // For Classes
          else if (item is Classes) {
            // Add termId to the terms list if not already present
            if (!item.terms!.contains(termId)) {
              item.terms?.add(termId); // Append the termId
              await modelBox.put(key, item); // Save the updated record
            }
          }
          // For Teachers
          else if (item is Teachers) {
            // Add termId to the terms list if not already present
            if (!item.terms!.contains(termId)) {
              item.terms?.add(termId); // Append the termId
              await modelBox.put(key, item); // Save the updated record
            }
          }
        }
      }
    }
  }

  Future<void> _removeRedundantRecord(
      String newTermId, String oldTermId) async {
    // Open all required boxes

    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');

    // List of model boxes to check for redundancies

    var paymentPurposesBoxes = [paymentPurposesBox];
    var teacherPaymentsPurposesBoxes = [teacherPaymentsPurposesBox];

    for (var modelBox in paymentPurposesBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is PaymentPurpose) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is PaymentPurpose &&
              existingItem.paymentPurpose == item.paymentPurpose &&
              existingItem.termId == item.termId);

          // If more than one redundancy is found
          if (duplicates.length > 1) {
            // Sort duplicates to keep the one with the newTermId and remove others
            var sortedDuplicates = duplicates.toList()
              ..sort((a, b) => a.termId == newTermId ? 1 : -1);

            // Calculate the number of redundancies to remove, preserving one
            int redundanciesToRemove = sortedDuplicates.length - 1;

            // Remove the excess duplicates while preserving one
            for (var i = 0; i < redundanciesToRemove; i++) {
              var duplicateKey = modelBox
                  .keyAt(modelBox.values.toList().indexOf(sortedDuplicates[i]));

              print('Deleting redundant record with key: $duplicateKey');
              await modelBox.delete(duplicateKey);
            }
          }
        }
      }
    }
    for (var modelBox in teacherPaymentsPurposesBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is TeacherPaymentsPurposes) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is TeacherPaymentsPurposes &&
              existingItem.paymentPurpose == item.paymentPurpose &&
              existingItem.termId == item.termId);

          // If more than one redundancy is found
          if (duplicates.length > 1) {
            // Sort duplicates to keep the one with the newTermId and remove others
            var sortedDuplicates = duplicates.toList()
              ..sort((a, b) => a.termId == newTermId ? 1 : -1);

            // Calculate the number of redundancies to remove, preserving one
            int redundanciesToRemove = sortedDuplicates.length - 1;

            // Remove the excess duplicates while preserving one
            for (var i = 0; i < redundanciesToRemove; i++) {
              var duplicateKey = modelBox
                  .keyAt(modelBox.values.toList().indexOf(sortedDuplicates[i]));

              print('Deleting redundant record with key: $duplicateKey');
              await modelBox.delete(duplicateKey);
            }
          }
        }
      }
    }
  }

  Future<Box<T>> _getBoxIfNotOpen<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    } else {
      return await Hive.openBox<T>(boxName);
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Start New term/Month'),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _termNameController,
                      decoration: const InputDecoration(
                        labelText: 'Term Name',
                        hintText: 'E.g., 2025-Term-1',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                          'Start Date: ${_startDate.toLocal().toShortDateString()}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectStartDate(context),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveTerm,
                      child: const Text('Create New Term'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Overlay progress indicator if processing
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _progressMessage,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension DateTimeExtension on DateTime {
  String toShortDateString() {
    return '${this.day}/${this.month}/${this.year}';
  }
}

/*
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teachers.dart';

import 'package:zitf_system/global files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

import 'package:http/http.dart' as http;
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';

class CreateTermScreen extends StatefulWidget {
  const CreateTermScreen({Key? key}) : super(key: key);

  @override
  _CreateTermScreenState createState() => _CreateTermScreenState();
}

class _CreateTermScreenState extends State<CreateTermScreen> {
  final _termNameController = TextEditingController();
  DateTime _startDate = DateTime.now();

  // Variables for progress indicator
  bool _isProcessing = false;
  String _progressMessage = '';
  DeviceRole? _role;
  String? _hostIp;
  List<Terms>? _cachedServerTerms;
  List<String> _terms = []; // Declare without 'final'
  Map<String, Terms> _termsMap = {};

  List<StudentPayment>? _cachedServerStudentPayments;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;
  List<School>? _cachedServerSchoolInfo;

  List<StudentPayment>? _cachedFilteredStudents;

  @override
  void initState() {
    super.initState();
    fetchTerms();
    fetchSchools();
    fetchStudents();
    fetchPaymentPurposes();
    fetchStudentPayments();
  }

  Future<void> fetchTerms() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termBox = await Hive.openBox<Terms>('terms');

        allTerms = termBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          setState(() {});
          return;
        }
        if (_cachedServerTerms == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
      }

      if (allTerms.isNotEmpty) {
        _terms = allTerms.map((term) => term.termId).toSet().toList();
        _termsMap = {for (var t in allTerms) t.termId: t}; // for quick lookup
      } else {
        _terms = [];
        _termsMap = {};
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  // Helper to update progress message and force rebuild
  void _updateProgress(String message) {
    setState(() {
      _progressMessage = message;
    });
  }

  Future<void> fetchSchools() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<School> allSchools = [];

      if (_role == DeviceRole.host) {
        final box = await Hive.openBox<School>('school');
        allSchools = box.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          setState(() {});
          return;
        }
        if (_cachedServerSchoolInfo == null) {
          final schooResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/school'))
              .then((req) => req.close());

          if (schooResponse.statusCode == 200) {
            final schoolsJsonString =
                await schooResponse.transform(utf8.decoder).join();

            final schoolsList = jsonDecode(schoolsJsonString) as List;

            _cachedServerSchoolInfo = schoolsList
                .map((json) => schoolFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load school data from host.");
          }
        }
        allSchools = _cachedServerSchoolInfo!;
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  Future<void> fetchStudents() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Student> allStudents = [];

      if (_role == DeviceRole.host) {
        final studentBox = await Hive.openBox<Student>('students');

        allStudents = studentBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          setState(() {});
          return;
        }

        if (_cachedServerStudents == null) {
          final studentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/students'))
              .then((req) => req.close());

          if (studentsResponse.statusCode == 200) {
            final studentsString =
                await studentsResponse.transform(utf8.decoder).join();

            final studentsList = jsonDecode(studentsString) as List;

            _cachedServerStudents = studentsList
                .map(
                    (json) => studentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load students data from host.");
          }
        }
        allStudents = _cachedServerStudents!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<void> fetchPaymentPurposes() async {
    try {
      debugPrint("🟨 Starting _fetchInitialData");

      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<PaymentPurpose> allStudentPaymentPurposes = [];

      if (_role == DeviceRole.host) {
        final paymentPurposeBox =
            await Hive.openBox<PaymentPurpose>('payment_purposes');

        allStudentPaymentPurposes = paymentPurposeBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        debugPrint("🌐 Fetching from server (client) - Host IP: $_hostIp");

        if (_hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          setState(() {});
          return;
        }

        if (_cachedServerStudentPaymentPurposes == null) {
          final studentPaymentPurposesResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
              .then((req) => req.close());

          if (studentPaymentPurposesResponse.statusCode == 200) {
            final studentPaymentPurposesJsonString =
                await studentPaymentPurposesResponse
                    .transform(utf8.decoder)
                    .join();

            final studentPaymentPurposesList =
                jsonDecode(studentPaymentPurposesJsonString) as List;

            _cachedServerStudentPaymentPurposes = studentPaymentPurposesList
                .map((json) =>
                    paymentPurposesFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load payment Purposes data from host.");
          }
        }
        allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<void> fetchStudentPayments() async {
    try {
      debugPrint("🟨 Starting _fetchInitialData");

      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();
      } else {
        debugPrint("🌐 Fetching from server (client) - Host IP: $_hostIp");

        if (_hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          setState(() {});
          return;
        }
        if (_cachedServerStudentPayments == null) {
          final studentPaymentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (studentPaymentsResponse.statusCode == 200) {
            final studentPaymentsJsonString =
                await studentPaymentsResponse.transform(utf8.decoder).join();

            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load student Payments data from host.");
          }
        }

        allStudentPayments = _cachedServerStudentPayments!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<void> _saveTerm() async {
    _role = await getDeviceRole();

    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    setState(() {
      _isProcessing = true;
      _progressMessage = 'Checking existing terms...';
    });
    if (_role == null) {
      await _showDialog("⚠️ Device role not configured. Cannot proceed.");
      return;
    } else if (_role == DeviceRole.client) {
      try {
        if (_cachedServerTerms == null) {
          _role = await getDeviceRole();
          final prefs = await SharedPreferences.getInstance();
          _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
          List<Terms> allTerms = [];

          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }

          allTerms = _cachedServerTerms!;

          var termsBox = allTerms;

          if (termsBox.isEmpty) {
            // No terms exist, so proceed with creating a new term directly
            _updateProgress('No existing term found. Creating new term...');

            await _createNewTerm();
          } else {
            // Check for existing terms with status 'Opened'
            var openedTerms = termsBox.where((term) => term.status == 'Opened');
            Terms? openedTerm =
                openedTerms.isNotEmpty ? openedTerms.first : null;

            if (openedTerm != null) {
              // An opened term already exists, notify the user
              setState(() {
                _isProcessing = false;
              });
              _showDialog(
                'A term with ID ${openedTerm.termId} and role ${_role}is currently opened. Please close it before starting a new term.',
              );
              return;
            } else {
              // Check for closed and active terms
              _updateProgress('Looking for active closed term data...');
              var activeTerms = termsBox
                  .where((term) => term.status == 'Closed' && term.isActive);
              Terms? activeTerm =
                  activeTerms.isNotEmpty ? activeTerms.first : null;

              if (activeTerm != null) {
                // Proceed with copying data and creating a new term\
                // Prepare data for the new term
                _updateProgress('Preparing data for the new term...');
                await _prepareForNewTerm(activeTerm);
                activeTerm.isActive = false;
                _updateProgress('Creating new term...');
                await _createNewTerm();
              } else {
                setState(() {
                  _isProcessing = false;
                });
                _showDialog(
                    'Cannot create a new term as all terms are totally closed.');
                return;
              }
            }
          }
          setState(() {
            _isProcessing = false;
          });
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
        });
        _showDialog('An error occurred: $e');
      }
    } else if (_role == DeviceRole.host) {
      var termsBox = await Hive.openBox<Terms>('terms');

      if (termsBox.isEmpty) {
        // No terms exist, so proceed with creating a new term directly
        _updateProgress('No existing term found. Creating new term...');

        await _createNewTerm();
      } else {
        // Check for existing terms with status 'Opened'
        var openedTerms =
            termsBox.values.where((term) => term.status == 'Opened');
        Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

        if (openedTerm != null) {
          // An opened term already exists, notify the user
          setState(() {
            _isProcessing = false;
          });
          _showDialog(
            'A term with ID ${openedTerm.termId}  is currently opened. Please close it before starting a new term.',
          );
          return;
        } else {
          // Check for closed and active terms
          _updateProgress('Looking for active closed term data...');
          var activeTerms = termsBox.values
              .where((term) => term.status == 'Closed' && term.isActive);
          Terms? activeTerm = activeTerms.isNotEmpty ? activeTerms.first : null;

          if (activeTerm != null) {
            // Proceed with copying data and creating a new term\
            // Prepare data for the new term
            _updateProgress('Preparing data for the new term...');
            await _prepareForNewTerm(activeTerm);
            activeTerm.isActive = false;
            _updateProgress('Creating new term...');
            await _createNewTerm();
          } else {
            setState(() {
              _isProcessing = false;
            });
            _showDialog(
                'Cannot create a new term as all terms are totally closed.');
            return;
          }
        }
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _createNewTerm() async {
    if (_termNameController.text.isNotEmpty) {
      // Store term information temporarily
      String termName = _termNameController.text.trim();
      int newId = await getNextId();

      // var termsBox = await Hive.openBox<Terms>('terms');

      // Check for duplicate terms by termId or termName
      bool isDuplicate = false;
      _role = await getDeviceRole();

      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      if (_role == null) {
        await _showDialog("⚠️ Device role not configured. Cannot proceed.");
        return;
      }
      if (_role == DeviceRole.client) {
        final termToSend = <Map<String, dynamic>>[];
        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('termId');
        modifiedFields.add('termName');
        modifiedFields.add('startDate');
        modifiedFields.add('isActive');
        modifiedFields.add('status');

        termToSend.add({
          'id': newId,
          'termId': termName,
          'termName': termName,
          'startDate': _startDate,
          'isActive': false,
          'status': 'Opened',
          'operationType': 'create',
          'syncStatus': false,
          'lastModified': DateTime.now(),
          'modifiedFields': modifiedFields,
        });

        final hostIp = _hostIp;
        final uri = Uri.parse('http://$hostIp:8080/api/terms/bulk');

        try {
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"terms": termToSend}), // ✅ Aligns with server
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            final List<dynamic> feedback = responseData['feedback'] ?? [];

            int insertedCount = responseData['insertedCount'] ?? 0;

            if (feedback.isEmpty) {
              await _showDialog("⚠️ No feedback received from host.");
              return;
            }

            // Build feedback UI string
            StringBuffer resultBuffer = StringBuffer();
            for (var entry in feedback) {
              final code = entry['termId'] ?? 'unknown';
              final status = entry['status'] ?? 'unknown';
              final message =
                  entry['message'] ?? entry['reason'] ?? 'No message';

              String icon = switch (status) {
                "success" => "✅",
                "skipped" => "⏭️",
                "failed" => "❌",
                _ => "🔹"
              };

              resultBuffer.writeln("$icon [$code]: $message");
            }

            await showDialog(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text("🧾 Term Submission Feedback"),
                  content: SingleChildScrollView(
                    child: Text(resultBuffer.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("OK"),
                    ),
                  ],
                );
              },
            );

            if (insertedCount > 0) {
              Navigator.pop(context); // Close the form if something was saved
            }
          } else {
            await _showDialog("❌ Host rejected Terms info: ${response.body}");
          }
        } catch (e) {
          await _showDialog("❌ Failed to send terms info to host.");
          print("terms info send error: $e");
        }
      }

      if (_role == DeviceRole.host) {
        final termsBox = await Hive.openBox<Terms>('terms');

        for (var activeTerm in termsBox.values) {
          if (termName.toLowerCase() == activeTerm.termId.toLowerCase() ||
              termName.toLowerCase() == activeTerm.termName.toLowerCase()) {
            _showDialog(
                'A term with ID ${activeTerm.termId} or Name ${activeTerm.termName}  already exists. You can modify it or create a new one.');
            isDuplicate = true;
            break; // Stop further checking once a duplicate is found
          }
        }

        // If no duplicate is found, proceed with creating the new term
        if (!isDuplicate) {
          // Set the global term ID
          globalTermId = termName;

          List<String> modifiedFields = [];
          modifiedFields.add('id');
          modifiedFields.add('termId');
          modifiedFields.add('termName');
          modifiedFields.add('startDate');
          modifiedFields.add('isActive');
          modifiedFields.add('status');
          // Create the new term
          Terms newTerm = Terms(
            id: newId,
            termId: termName,
            termName: termName,
            startDate: _startDate,
            isActive: false,
            status: 'Opened',
            operationType: 'create',
            syncStatus: false,
            lastModified: DateTime.now(),
            modifiedFields: modifiedFields,
          );

          await termsBox.put(newTerm.termId, newTerm);

          // Show success message or navigate back
          _showDialog('A New term was created successfully!');
          Navigator.pop(context);
        }
      } else {
        // Show error message if required fields are missing
        _showDialog('Please fill in all required fields.');
      }
    }
  }

  Future<int> getNextId() async {
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (role == DeviceRole.host) {
      final box = await Hive.openBox<Terms>('terms');
      if (box.isEmpty) return 1;

      int currentMaxId = box.values
          .map((e) => e.id ?? 0)
          .reduce((curr, next) => curr > next ? curr : next);
      return currentMaxId + 1;
    } else {
      try {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/terms'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final responseString = await response.transform(utf8.decoder).join();
          final List<dynamic> jsonList = jsonDecode(responseString);

          if (jsonList.isEmpty) return 1;

          final List<Terms> payments = jsonList
              .map((e) => termsFromJson(Map<String, dynamic>.from(e)))
              .toList();

          int currentMaxId = payments
              .map((e) => e.id ?? 0)
              .reduce((curr, next) => curr > next ? curr : next);
          return currentMaxId + 1;
        } else {
          throw Exception("Failed to load studentPayments for ID generation.");
        }
      } catch (e) {
        debugPrint("❌ Error fetching max ID from server: $e");
        return 1; // Fallback to 1 if error
      }
    }
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Term Submission Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareForNewTerm(Terms activeTerm) async {
    // Temporary variables for the new term
    String newTermId = _termNameController.text.trim();
    String newTermName = _termNameController.text.trim();
    String oldTermId =
        activeTerm.termId; // ✅ Save old termId before changing global

    DateTime newStartDate = _startDate;
    // Open all required boxes

    globalTermId = newTermId;
    _updateProgress('Updating term IDs in all models...');

    // Update the termId for all records in all models
    await _updateTermIdInAllModels(globalTermId!);
    await _updateTermsInAllModels(
        newTermId, oldTermId); // ✅ Pass oldTermId for filtering
  }

  Future<void> _copyRecords(Box box, String termId) async {
    for (var key in box.keys) {
      var item = box.get(key);

      // Only copy if the termId is not already the new termId
      if (item != null && item.termId != termId) {
        // Create a new instance with the new termId
        var newItem = item.copyWith(termId: termId);

        // Generate a new unique key for the new item
        var newKey = '${item.key}_$termId';
        await box.put(newKey, newItem);
        await _removeRedundantRecord(
            item.termId.toString(), item.termId.toString());
      }
    }
  }

  Future<void> _clearModelData(List modelNamess) async {
    for (var modelNam in modelNamess) {
      await modelNam.clear();
    }
  }

  Future<void> _updateTermIdInAllModels(String termId) async {
    var studentsBox = await _getBoxIfNotOpen<Student>('students');
    var classesBox = await _getBoxIfNotOpen<Classes>('classes');
    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');

    var modelsNames = [
      studentsBox,
      classesBox,
      paymentPurposesBox,
      teacherPaymentsPurposesBox,
      teachersBox,
    ];
    for (var modelsName in modelsNames) {
      for (var key in modelsName.keys) {
        var item = modelsName.get(key);

        // Check if item is of the specific type and cast it accordingly
        if (item != null) {
          if (item is PaymentPurpose) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(
                  termId: termId,
                  purposeCode: const Uuid().v4(), // ✅ Generate new purposeCode
                );
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is TeacherPaymentsPurposes) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(
                  termId: termId,
                  purposeCode: const Uuid().v4(), // ✅ Generate new purposeCode
                );
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          }
        }
      }
    }
  }

  Future<void> _updateTermsInAllModels(String termId, String oldTermId) async {
    var studentsBox = await _getBoxIfNotOpen<Student>('students');
    var classesBox = await _getBoxIfNotOpen<Classes>('classes');
    var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');

    var modelBoxes = [
      studentsBox,
      classesBox,
      teachersBox,
    ];

    for (var modelBox in modelBoxes) {
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        // Only proceed if the item is not null
        if (item != null) {
          // For Students
          if (item is Student) {
            // Add termId to the terms list if not already present
            if (item.terms != null &&
                item.terms!.contains(oldTermId) && // Has the previous term
                !item.terms!.contains(termId)) {
              // Not yet added to the new term
              item.terms!.add(termId); // Append the new term ID
              print(
                  'Adding termId: $termId to student with globalTermId: $globalTermId');

              await modelBox.put(key, item); // Save the updated record
            }
          }
          // For Classes
          else if (item is Classes) {
            // Add termId to the terms list if not already present
            if (!item.terms!.contains(termId)) {
              item.terms?.add(termId); // Append the termId
              await modelBox.put(key, item); // Save the updated record
            }
          }
          // For Teachers
          else if (item is Teachers) {
            // Add termId to the terms list if not already present
            if (!item.terms!.contains(termId)) {
              item.terms?.add(termId); // Append the termId
              await modelBox.put(key, item); // Save the updated record
            }
          }
        }
      }
    }
  }

  Future<void> _removeRedundantRecord(
      String newTermId, String oldTermId) async {
    // Open all required boxes

    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');

    // List of model boxes to check for redundancies

    var paymentPurposesBoxes = [paymentPurposesBox];
    var teacherPaymentsPurposesBoxes = [teacherPaymentsPurposesBox];

    for (var modelBox in paymentPurposesBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is PaymentPurpose) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is PaymentPurpose &&
              existingItem.paymentPurpose == item.paymentPurpose &&
              existingItem.termId == item.termId);

          // If more than one redundancy is found
          if (duplicates.length > 1) {
            // Sort duplicates to keep the one with the newTermId and remove others
            var sortedDuplicates = duplicates.toList()
              ..sort((a, b) => a.termId == newTermId ? 1 : -1);

            // Calculate the number of redundancies to remove, preserving one
            int redundanciesToRemove = sortedDuplicates.length - 1;

            // Remove the excess duplicates while preserving one
            for (var i = 0; i < redundanciesToRemove; i++) {
              var duplicateKey = modelBox
                  .keyAt(modelBox.values.toList().indexOf(sortedDuplicates[i]));

              print('Deleting redundant record with key: $duplicateKey');
              await modelBox.delete(duplicateKey);
            }
          }
        }
      }
    }
    for (var modelBox in teacherPaymentsPurposesBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is TeacherPaymentsPurposes) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is TeacherPaymentsPurposes &&
              existingItem.paymentPurpose == item.paymentPurpose &&
              existingItem.termId == item.termId);

          // If more than one redundancy is found
          if (duplicates.length > 1) {
            // Sort duplicates to keep the one with the newTermId and remove others
            var sortedDuplicates = duplicates.toList()
              ..sort((a, b) => a.termId == newTermId ? 1 : -1);

            // Calculate the number of redundancies to remove, preserving one
            int redundanciesToRemove = sortedDuplicates.length - 1;

            // Remove the excess duplicates while preserving one
            for (var i = 0; i < redundanciesToRemove; i++) {
              var duplicateKey = modelBox
                  .keyAt(modelBox.values.toList().indexOf(sortedDuplicates[i]));

              print('Deleting redundant record with key: $duplicateKey');
              await modelBox.delete(duplicateKey);
            }
          }
        }
      }
    }
  }

  Future<Box<T>> _getBoxIfNotOpen<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    } else {
      return await Hive.openBox<T>(boxName);
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Start New term/Month'),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _termNameController,
                      decoration: const InputDecoration(
                        labelText: 'Term Name',
                        hintText: 'E.g., 2025-Term-1',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                          'Start Date: ${_startDate.toLocal().toShortDateString()}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectStartDate(context),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveTerm,
                      child: const Text('Create New Term'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Overlay progress indicator if processing
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _progressMessage,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _termNameController.dispose();
    fetchTerms();
    fetchSchools();
    fetchStudents();
    fetchPaymentPurposes();
    fetchStudentPayments();

    super.dispose();
  }
}

extension DateTimeExtension on DateTime {
  String toShortDateString() {
    return '${this.day}/${this.month}/${this.year}';
  }
}
*/
