import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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

  @override
  void dispose() {
    _termNameController.dispose();
    super.dispose();
  }

  Future<void> _saveTerm() async {
    try {
      var termsBox = await Hive.openBox<Terms>('terms');

      if (termsBox.isEmpty) {
        // No terms exist, so proceed with creating a new term directly
        await _createNewTerm();
      } else {
        // Check for existing terms with status 'Opened'
        var openedTerms =
            termsBox.values.where((term) => term.status == 'Opened');
        Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

        if (openedTerm != null) {
          // An opened term already exists, notify the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'A term with ID ${openedTerm.termId} is currently opened. Please close it before starting a new term.',
              ),
            ),
          );
        } else {
          // Check for closed and active terms
          var activeTerms = termsBox.values
              .where((term) => term.status == 'Closed' && term.isActive);
          Terms? activeTerm = activeTerms.isNotEmpty ? activeTerms.first : null;

          if (activeTerm != null) {
            // Proceed with copying data and creating a new term\

            await _prepareForNewTerm(activeTerm);
            activeTerm.isActive = false;
            await _createNewTerm();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Cannot create a new term as all terms are totally closed.'),
              ),
            );
          }
        }
      }
    } catch (e) {
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
    DateTime newStartDate = _startDate;
    // Open all required boxes

    var studentsBox = await _getBoxIfNotOpen<Student>('students');
    var classesBox = await _getBoxIfNotOpen<Classes>('classes');
    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');

    // List of model boxes to update
    var modelNames = [
      studentsBox,
      classesBox,
      paymentPurposesBox,
      teacherPaymentsPurposesBox,
      teachersBox,

      // Add more models as needed
    ];

    globalTermId = newTermId;

    // Update the termId for all records in all models
    await _updateTermIdInAllModels(globalTermId!);
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
          if (item is Student) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              // Check if the newKey already exists
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(termId: termId);
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is Classes) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(termId: termId);
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is PaymentPurpose) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(termId: termId);
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is TeacherPaymentsPurposes) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(termId: termId);
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is Teachers) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(termId: termId);
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

  Future<void> _removeRedundantRecord(
      String newTermId, String oldTermId) async {
    // Open all required boxes

    var studentsBox = await _getBoxIfNotOpen<Student>('students');
    var classesBox = await _getBoxIfNotOpen<Classes>('classes');
    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');
    var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');

    // List of model boxes to check for redundancies
    var classesBoxes = [classesBox];
    var studentsBoxes = [studentsBox];
    var paymentPurposesBoxes = [paymentPurposesBox];
    var teacherPaymentsPurposesBoxes = [teacherPaymentsPurposesBox];
    var teachersBoxes = [teachersBox];

    for (var modelBox in studentsBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is Student) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is Student &&
              existingItem.name == item.name &&
              existingItem.termId == item.termId &&
              existingItem.surname == item.surname &&
              existingItem.regNumber == item.regNumber);

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
    for (var modelBox in classesBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is Classes) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is Classes &&
              existingItem.className == item.className &&
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
    for (var modelBox in teachersBoxes) {
      // Iterate over each item in the box
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is Teachers) {
          // Check for items with the same className
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is Teachers &&
              existingItem.name == item.name &&
              existingItem.surname == item.surname &&
              existingItem.IdNumber == item.IdNumber &&
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
      body: Center(
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
    );
  }
}

extension DateTimeExtension on DateTime {
  String toShortDateString() {
    return '${this.day}/${this.month}/${this.year}';
  }
}
