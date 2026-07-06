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

      // ✅ Filter out deleted terms when checking
      var activeTerms =
          termsBox.values.where((term) => !(term.isDeleted ?? false)).toList();

      if (activeTerms.isEmpty) {
        _updateProgress('No existing term found. Creating new term...');
        await _createNewTerm();
      } else {
        // Check for existing terms with status 'Opened' (excluding deleted)
        var openedTerms = activeTerms.where((term) => term.status == 'Opened');
        Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

        if (openedTerm != null) {
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
          // Check for closed and active terms (excluding deleted)
          var closedActiveTerms = activeTerms
              .where((term) => term.status == 'Closed' && term.isActive);
          Terms? activeTerm =
              closedActiveTerms.isNotEmpty ? closedActiveTerms.first : null;

          if (activeTerm != null) {
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
      String termName = _termNameController.text.trim();

      var termsBox = await Hive.openBox<Terms>('terms');

      // ✅ Check for duplicate terms (excluding deleted)
      bool isDuplicate = false;

      for (var activeTerm in termsBox.values) {
        if (!(activeTerm.isDeleted ?? false)) {
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
            break;
          }
        }
      }

      Future<int> getNextId() async {
        final box = await Hive.openBox<Terms>('terms');
        // ✅ Only count non-deleted terms for ID generation
        final activeTerms =
            box.values.where((t) => !(t.isDeleted ?? false)).toList();
        if (activeTerms.isEmpty) return 1;

        int currentMaxId = activeTerms
            .map((e) => e.id ?? 0)
            .reduce((curr, next) => curr > next ? curr : next);
        return currentMaxId + 1;
      }

      int newId = await getNextId();

      if (!isDuplicate) {
        globalTermId = termName;

        List<String> modifiedFields = [
          'id',
          'termId',
          'termName',
          'startDate',
          'isActive',
          'status'
        ];

        // ✅ Create new term with deletion fields
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
          // ✅ Deletion fields - new term is not deleted
          isDeleted: false,
          deletedSyncStatus: true,
        );

        await termsBox.put(newTerm.termId, newTerm);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New term created successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
    }
  }

  Future<void> _prepareForNewTerm(Terms activeTerm) async {
    String newTermId = _termNameController.text.trim();
    String newTermName = _termNameController.text.trim();
    String oldTermId = activeTerm.termId;

    DateTime newStartDate = _startDate;

    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');

    var modelNames = [
      paymentPurposesBox,
      teacherPaymentsPurposesBox,
    ];
    print("previous term global: $globalTermId");

    globalTermId = newTermId;
    _updateProgress('Updating term IDs in all models...');

    await _updateTermIdInAllModels(globalTermId!);
    await _updateTermsInAllModels(newTermId, oldTermId);
  }

  Future<void> _copyRecords(Box box, String termId) async {
    for (var key in box.keys) {
      var item = box.get(key);

      if (item != null && item.termId != termId && !(item.isDeleted ?? false)) {
        var newItem = item.copyWith(termId: termId);
        var newKey = '${item.key}_$termId';
        await box.put(newKey, newItem);
        await _removeRedundantRecord(
            item.termId.toString(), item.termId.toString());
      }
    }
  }

  Future<void> _clearModelData(List modelNamess) async {
    for (var modelNam in modelNamess) {
      // ✅ Only clear non-deleted items
      for (var key in modelNam.keys) {
        var item = modelNam.get(key);
        if (item != null && !(item.isDeleted ?? false)) {
          await modelNam.delete(key);
        }
      }
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

        if (item != null) {
          // ✅ Skip deleted items
          if (item is PaymentPurpose && !(item.isDeleted ?? false)) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(
                  termId: termId,
                  purposeCode: const Uuid().v4(),
                );
                await modelsName.put(newKey, newItem);
                await _removeRedundantRecord(
                    item.termId.toString(), item.termId.toString());
              }
            }
          } else if (item is TeacherPaymentsPurposes &&
              !(item.isDeleted ?? false)) {
            if (item.termId != termId) {
              var newKey = '${key}_$termId';
              if (!modelsName.containsKey(newKey)) {
                var newItem = item.copyWith(
                  termId: termId,
                  purposeCode: const Uuid().v4(),
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

        if (item != null) {
          // ✅ Skip deleted items
          if (item is Student && !(item.isDeleted ?? false)) {
            if (item.terms != null &&
                item.terms!.contains(oldTermId) &&
                !item.terms!.contains(termId)) {
              item.terms!.add(termId);
              print(
                  'Adding termId: $termId to student with globalTermId: $globalTermId');
              await modelBox.put(key, item);
            }
          } else if (item is Classes && !(item.isDeleted ?? false)) {
            if (!item.terms!.contains(termId)) {
              item.terms?.add(termId);
              await modelBox.put(key, item);
            }
          } else if (item is Teachers && !(item.isDeleted ?? false)) {
            if (!item.terms!.contains(termId)) {
              item.terms?.add(termId);
              await modelBox.put(key, item);
            }
          }
        }
      }
    }
  }

  Future<void> _removeRedundantRecord(
      String newTermId, String oldTermId) async {
    var paymentPurposesBox =
        await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
    var teacherPaymentsPurposesBox =
        await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
            'teacher_payments_purposes');

    var paymentPurposesBoxes = [paymentPurposesBox];
    var teacherPaymentsPurposesBoxes = [teacherPaymentsPurposesBox];

    for (var modelBox in paymentPurposesBoxes) {
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is PaymentPurpose && !(item.isDeleted ?? false)) {
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is PaymentPurpose &&
              existingItem.paymentPurpose == item.paymentPurpose &&
              existingItem.termId == item.termId &&
              !(existingItem.isDeleted ?? false));

          if (duplicates.length > 1) {
            var sortedDuplicates = duplicates.toList()
              ..sort((a, b) => a.termId == newTermId ? 1 : -1);

            int redundanciesToRemove = sortedDuplicates.length - 1;

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
      for (var key in modelBox.keys) {
        var item = modelBox.get(key);

        if (item is TeacherPaymentsPurposes && !(item.isDeleted ?? false)) {
          var duplicates = modelBox.values.where((existingItem) =>
              existingItem is TeacherPaymentsPurposes &&
              existingItem.paymentPurpose == item.paymentPurpose &&
              existingItem.termId == item.termId &&
              !(existingItem.isDeleted ?? false));

          if (duplicates.length > 1) {
            var sortedDuplicates = duplicates.toList()
              ..sort((a, b) => a.termId == newTermId ? 1 : -1);

            int redundanciesToRemove = sortedDuplicates.length - 1;

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
