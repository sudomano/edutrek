import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdatePaymentPurposeScreen extends StatefulWidget {
  final PaymentPurpose existingPurpose;

  const UpdatePaymentPurposeScreen({super.key, required this.existingPurpose});

  @override
  _UpdatePaymentPurposeScreenState createState() =>
      _UpdatePaymentPurposeScreenState();
}

class _UpdatePaymentPurposeScreenState
    extends State<UpdatePaymentPurposeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _purposeController;
  late TextEditingController _amountController;
  List<String> _classes = [];
  late List<String> _selectedClasses;

  List<ExceptionalStudents> _exceptionalStudents = [];
  List<ExceptionalStudents> _selectedExceptions = [];
  bool _forNewcomersOnly = false;

  bool applyGlobally = false;
  bool _purposeNameChanged = false;
  List<String> _termsWithSamePurpose = [];
  Set<String> _selectedTermsToOverride = {};

  String normalize(String input) {
    return input.toLowerCase().trim();
  }

  @override
  void initState() {
    super.initState();
    _purposeController =
        TextEditingController(text: widget.existingPurpose.paymentPurpose);
    _amountController = TextEditingController(
        text: widget.existingPurpose.purposeAmount.toString());
    _selectedClasses = widget.existingPurpose.associatedClasses != null
        ? List.from(widget.existingPurpose.associatedClasses as Iterable)
        : <String>[];

    _selectedExceptions = widget.existingPurpose.exceptions ?? [];
    _forNewcomersOnly = widget.existingPurpose.forNewcomersOnly == true;

    _fetchExceptionalStudents();
    _loadTermsWithSamePurpose();
    _fetchClasses();
  }

  void _loadTermsWithSamePurpose() async {
    final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
    final oldName = normalize(widget.existingPurpose.paymentPurpose);
    // ✅ Only load active purposes
    _termsWithSamePurpose = box.values
        .where((p) =>
            normalize(p.paymentPurpose) == oldName &&
            p.termId != widget.existingPurpose.termId &&
            !(p.isDeleted ?? false)) // ✅ Filter out deleted
        .map((p) => p.termId.toString())
        .toSet()
        .toList();
  }

  Future<void> _fetchExceptionalStudents() async {
    final box =
        await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
    // ✅ Only load active (non-deleted) exceptions
    final all = box.values.where((e) => !(e.isDeleted ?? false)).toList();

    print(
        "🧠 Loaded ExceptionalStudents from Hive: ${all.map((e) => e.exceptionName).toList()}");

    setState(() {
      _exceptionalStudents = all
          .where((e) => e.exceptionStatus!.toLowerCase() == 'active')
          .toList();
    });
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    // ✅ Only load active (non-deleted) classes
    final classes = box.values
        .where((purposeItem) =>
            purposeItem.termId != null &&
            purposeItem.terms!.contains(globalTermId) &&
            !(purposeItem.isDeleted ?? false))
        .map((e) => e.className)
        .toList();
    setState(() {
      _classes = classes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Payment Purpose',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _purposeController,
              enabled: _selectedTermsToOverride.isEmpty,
              decoration: const InputDecoration(labelText: 'Payment Purpose'),
              onChanged: (val) {
                setState(() {
                  _purposeNameChanged = normalize(val) !=
                      normalize(widget.existingPurpose.paymentPurpose);
                });
              },
            ),
            const SizedBox(height: 16),
            _buildAmountField('Payment Purpose Amount', _amountController),
            const SizedBox(height: 48),
            _buildExceptionalStudentsSelector(),
            const SizedBox(height: 48),
            _buildForNewcomersSwitch(),
            const SizedBox(height: 48),
            _buildClassesList(),
            const SizedBox(height: 48),
            if (_termsWithSamePurpose.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Override this payment in other terms:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _purposeNameChanged ? Colors.grey : Colors.black,
                    ),
                  ),
                  ..._termsWithSamePurpose.map((term) => CheckboxListTile(
                        title: Text(term),
                        value: _selectedTermsToOverride.contains(term),
                        onChanged: _purposeNameChanged
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedTermsToOverride.add(term);
                                  } else {
                                    _selectedTermsToOverride.remove(term);
                                  }
                                });
                              },
                      )),
                ],
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _update,
              child: const Text('Update Payment Purpose'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionalStudentsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exceptional Students'),
        ..._exceptionalStudents.map((e) {
          final isSelected = _selectedExceptions
              .any((sel) => sel.exceptionId == e.exceptionId);
          return CheckboxListTile(
              title: Text(e.exceptionName!.toLowerCase()),
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    if (!_selectedExceptions
                        .any((sel) => sel.exceptionId == e.exceptionId)) {
                      _selectedExceptions.add(e);
                    }
                  } else {
                    _selectedExceptions
                        .removeWhere((sel) => sel.exceptionId == e.exceptionId);
                  }
                });
              });
        }).toList(),
      ],
    );
  }

  Widget _buildForNewcomersSwitch() {
    return SwitchListTile(
      title: const Text('For Newcomers Only'),
      value: _forNewcomersOnly,
      onChanged: (value) {
        setState(() {
          _forNewcomersOnly = value;
        });
      },
    );
  }

  Widget _buildAmountField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.attach_money),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        final parsed = double.tryParse(value);
        if (parsed == null) {
          return 'Please enter a valid amount';
        }
        if (parsed < 0) {
          return 'Amount must be greater than 0';
        }
        return null;
      },
    );
  }

  Widget _buildClassesList() {
    bool _selectAll =
        _selectedClasses.length == _classes.length && _classes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_classes.isNotEmpty)
            Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: (isChecked) {
                    setState(() {
                      if (isChecked == true) {
                        _selectedClasses = List.from(_classes);
                      } else {
                        _selectedClasses.clear();
                      }
                    });
                  },
                ),
                const Text('Select All'),
              ],
            ),
          ..._classes.map((className) {
            return CheckboxListTile(
              title: Text(className),
              value: _selectedClasses.contains(className),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) {
                    _selectedClasses.add(className);
                  } else {
                    _selectedClasses.remove(className);
                  }
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _update() async {
    if (_formKey.currentState!.validate()) {
      debugPrint('✅ Form validated successfully');

      if (normalize(widget.existingPurpose.paymentPurpose) !=
          normalize(_purposeController.text)) {
        applyGlobally = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Apply Globally?'),
                content: const Text(
                    'You changed the payment purpose name. Do you want to apply this new name to all terms where this purpose exists?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes')),
                ],
              ),
            ) ??
            false;
      }

      final purposeCode = widget.existingPurpose.purposeCode;
      debugPrint('🔎 Looking for purposeCode: $purposeCode');

      List<String> modifiedFields = widget.existingPurpose.modifiedFields ?? [];

      // Track changes
      if (widget.existingPurpose.paymentPurpose.toLowerCase() !=
          _purposeController.text.toLowerCase()) {
        debugPrint(
            '📝 paymentPurpose changed: ${widget.existingPurpose.paymentPurpose} → ${_purposeController.text}');
        if (!modifiedFields.contains('paymentPurpose')) {
          modifiedFields.add('paymentPurpose');
        }
      }

      if (widget.existingPurpose.purposeAmount !=
          double.parse(_amountController.text)) {
        debugPrint(
            '💰 purposeAmount changed: ${widget.existingPurpose.purposeAmount} → ${_amountController.text}');
        if (!modifiedFields.contains('purposeAmount')) {
          modifiedFields.add('purposeAmount');
        }
      }

      if (!const DeepCollectionEquality()
          .equals(widget.existingPurpose.associatedClasses, _selectedClasses)) {
        debugPrint(
            '📚 associatedClasses changed: ${widget.existingPurpose.associatedClasses} → $_selectedClasses');
        if (!modifiedFields.contains('associatedClasses')) {
          modifiedFields.add('associatedClasses');
        }
      }

      if (!const DeepCollectionEquality()
          .equals(widget.existingPurpose.exceptions, _selectedExceptions)) {
        debugPrint('⚠️ exceptions changed');
        if (!modifiedFields.contains('exceptions')) {
          modifiedFields.add('exceptions');
        }
      }

      if (widget.existingPurpose.forNewcomersOnly != _forNewcomersOnly) {
        debugPrint('🧪 forNewcomersOnly changed');
        if (!modifiedFields.contains('forNewcomersOnly')) {
          modifiedFields.add('forNewcomersOnly');
        }
      }

      List<String> filteredSelectedClasses = _selectedClasses
          .where((className) => _classes.contains(className))
          .toList();

      final updatedPurpose = widget.existingPurpose.copyWith(
        paymentPurpose: _purposeController.text,
        purposeAmount: double.parse(_amountController.text),
        associatedClasses: List<String>.from(filteredSelectedClasses),
        exceptions: List<ExceptionalStudents>.from(_selectedExceptions),
        forNewcomersOnly: _forNewcomersOnly,
        syncStatus: false, // ✅ Needs sync
        lastModified: DateTime.now(),
        operationType: 'update',
        purposeCode: purposeCode,
        modifiedFields: modifiedFields,
        // ✅ Preserve deletion status (not deleted if updating)
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        deleteReason: null,
        deletedSyncStatus: true,
      );

      debugPrint('🔧 Updated Purpose Object: $updatedPurpose');

      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');

      // TEMP CLEANUP: Fix duplicates by reassigning new purposeCode to all but one
      final dupes = box.values
          .where((p) => p.purposeCode == purposeCode && !(p.isDeleted ?? false))
          .toList();

      final targetPurpose =
          widget.existingPurpose.paymentPurpose.toLowerCase().trim();
      final targetTermId = widget.existingPurpose.termId;

      // 🔁 Step 1: Reassign purposeCode for true duplicates (same code)
      if (dupes.length > 1) {
        debugPrint('⚠️ Duplicate entries found for purposeCode: $purposeCode');

        for (int i = 1; i < dupes.length; i++) {
          final dupe = dupes[i];
          final key = box.keyAt(box.values.toList().indexOf(dupe));

          final newPurposeCode = const Uuid().v4();
          final updatedDupe = dupe.copyWith(
            purposeCode: newPurposeCode,
            exceptions: List<ExceptionalStudents>.from(_selectedExceptions),
            forNewcomersOnly: _forNewcomersOnly,
            lastModified: DateTime.now(),
            syncStatus: false,
            operationType: 'update',
            modifiedFields: [...(dupe.modifiedFields ?? []), 'purposeCode'],
          );

          debugPrint(
              '🔁 Reassigning purposeCode for key $key → $newPurposeCode');
          await box.put(key, updatedDupe);

          if (applyGlobally) {
            final allPurposes =
                box.values.where((p) => !(p.isDeleted ?? false)).toList();
            final oldPurposeName =
                normalize(widget.existingPurpose.paymentPurpose);
            final newPurposeName = _purposeController.text.trim();

            for (var p in allPurposes) {
              if (normalize(p.paymentPurpose) == oldPurposeName &&
                  p.purposeCode != purposeCode) {
                final key = box.keyAt(allPurposes.indexOf(p));
                final updated = p.copyWith(
                  paymentPurpose: newPurposeName,
                  syncStatus: false,
                  lastModified: DateTime.now(),
                  operationType: 'update',
                  modifiedFields: [
                    ...(p.modifiedFields ?? []),
                    'paymentPurpose'
                  ],
                );
                await box.put(key, updated);
                debugPrint(
                    '🌍 Updated purpose name for purposeCode ${p.purposeCode}');
              }
            }

            final studentPaymentBox =
                await Hive.openBox<StudentPayment>('student_payments');
            final matchingPayments = studentPaymentBox.values.where(
              (payment) => normalize(payment.paymentPurpose) == oldPurposeName,
            );

            for (var payment in matchingPayments) {
              final key = payment.key;
              final updatedPayment = payment.copyWith(
                paymentPurpose: newPurposeName,
                syncStatus: false,
                lastModified: DateTime.now(),
                operationType: 'update',
                modifiedFields: [
                  ...(payment.modifiedFields ?? []),
                  'paymentPurpose'
                ],
              );
              if (key != null) {
                await studentPaymentBox.put(key, updatedPayment);
                debugPrint(
                    '🌍 Updated student payment for purpose ${payment.paymentPurpose}');
              }
            }

            debugPrint(
                '✅ Global update applied: ${matchingPayments.length} student payments updated.');
          }
        }
      }

      if (_selectedTermsToOverride.isNotEmpty && !_purposeNameChanged) {
        final overrideBox = Hive.box<PaymentPurpose>('payment_purposes');
        final allPurposes =
            overrideBox.values.where((p) => !(p.isDeleted ?? false)).toList();

        for (var p in allPurposes) {
          final termMatches = _selectedTermsToOverride.contains(p.termId);
          final nameMatches = normalize(p.paymentPurpose) ==
              normalize(widget.existingPurpose.paymentPurpose);
          final differentCode = p.purposeCode != purposeCode;

          if (termMatches && nameMatches && differentCode) {
            final key = overrideBox.keyAt(allPurposes.indexOf(p));
            final updated = p.copyWith(
              purposeAmount: double.tryParse(_amountController.text.trim()) ??
                  p.purposeAmount,
              forNewcomersOnly: _forNewcomersOnly,
              exceptions: _selectedExceptions,
              syncStatus: false,
              operationType: 'update',
              lastModified: DateTime.now(),
              modifiedFields: [
                ...(p.modifiedFields ?? []),
                'purposeAmount',
                'forNewcomersOnly',
                'exceptions',
              ],
            );
            await overrideBox.put(key, updated);
            debugPrint('🔄 Overridden payment in term ${p.termId} ✅');
          }
        }
      }

      // ❌ Step 2: Delete same-name duplicates (case-insensitive) with different purposeCodes in the same term
      final sameNameDuplicates = box.values
          .where((p) =>
              p.paymentPurpose.toLowerCase().trim() == targetPurpose &&
              p.purposeCode != purposeCode &&
              p.termId == targetTermId &&
              !(p.isDeleted ?? false)) // ✅ Only check active
          .toList();

      for (var dupe in sameNameDuplicates) {
        final key = box.keyAt(box.values.toList().indexOf(dupe));
        debugPrint(
            '🗑 Soft-deleting same-name duplicate with different purposeCode at key: $key');

        // ✅ Soft delete instead of hard delete
        dupe.markDeleted(
          deletedBy: 'System - Duplicate cleanup',
          reason: 'Duplicate purpose found during update',
        );
        await box.put(key, dupe);
      }

      final allPurposes =
          box.values.where((p) => !(p.isDeleted ?? false)).toList();

      debugPrint('📦 Total active purposes in box: ${allPurposes.length}');
      for (var p in allPurposes) {
        debugPrint(
            '→ purposeCode: ${p.purposeCode}, purpose: ${p.paymentPurpose}');
      }

      final match = allPurposes.firstWhere(
        (p) => p.purposeCode == purposeCode,
        orElse: () {
          debugPrint('❌ No matching purposeCode found in box!');
          return null as PaymentPurpose;
        },
      );

      if (match != null) {
        final key = box.keyAt(allPurposes.indexOf(match));
        debugPrint('🗝 Found match with key: $key — updating...');

        await box.put(key, updatedPurpose);

        // 🧠 Update related student payment records if name has changed
        if (widget.existingPurpose.paymentPurpose.toLowerCase().trim() !=
            _purposeController.text.toLowerCase().trim()) {
          final studentPaymentBox =
              await Hive.openBox<StudentPayment>('student_payments');

          final matchingPayments = studentPaymentBox.values.where((payment) =>
              payment.paymentPurpose.toLowerCase().trim() ==
                  widget.existingPurpose.paymentPurpose.toLowerCase().trim() &&
              payment.termId == widget.existingPurpose.termId);

          for (var payment in matchingPayments) {
            final updatedPayment = payment.copyWith(
              paymentPurpose: _purposeController.text.trim(),
              syncStatus: false,
              lastModified: DateTime.now(),
              operationType: 'update',
              modifiedFields: [
                ...(payment.modifiedFields ?? []),
                'paymentPurpose'
              ],
            );

            final key = payment.key;
            if (key != null) {
              await studentPaymentBox.put(key, updatedPayment);

              if (applyGlobally) {
                final allPurposes =
                    box.values.where((p) => !(p.isDeleted ?? false)).toList();
                final oldPurposeName =
                    normalize(widget.existingPurpose.paymentPurpose);
                final newPurposeName = _purposeController.text.trim();

                for (var p in allPurposes) {
                  if (normalize(p.paymentPurpose) == oldPurposeName &&
                      p.purposeCode != purposeCode) {
                    final key = box.keyAt(allPurposes.indexOf(p));
                    final updated = p.copyWith(
                      paymentPurpose: newPurposeName,
                      syncStatus: false,
                      lastModified: DateTime.now(),
                      operationType: 'update',
                      modifiedFields: [
                        ...(p.modifiedFields ?? []),
                        'paymentPurpose'
                      ],
                    );
                    await box.put(key, updated);
                    debugPrint(
                        '🌍 Updated purpose name for purposeCode ${p.purposeCode}');
                  }
                }

                if (_selectedTermsToOverride.isNotEmpty &&
                    !_purposeNameChanged) {
                  final overrideBox =
                      Hive.box<PaymentPurpose>('payment_purposes');
                  final allPurposes = overrideBox.values
                      .where((p) => !(p.isDeleted ?? false))
                      .toList();

                  for (var p in allPurposes) {
                    final termMatches =
                        _selectedTermsToOverride.contains(p.termId);
                    final nameMatches = normalize(p.paymentPurpose) ==
                        normalize(widget.existingPurpose.paymentPurpose);
                    final differentCode = p.purposeCode != purposeCode;

                    if (termMatches && nameMatches && differentCode) {
                      final key = overrideBox.keyAt(allPurposes.indexOf(p));
                      final updated = p.copyWith(
                        purposeAmount:
                            double.tryParse(_amountController.text.trim()) ??
                                p.purposeAmount,
                        forNewcomersOnly: _forNewcomersOnly,
                        exceptions: _selectedExceptions,
                        syncStatus: false,
                        operationType: 'update',
                        lastModified: DateTime.now(),
                        modifiedFields: [
                          ...(p.modifiedFields ?? []),
                          'purposeAmount',
                          'forNewcomersOnly',
                          'exceptions',
                        ],
                      );
                      await overrideBox.put(key, updated);
                      debugPrint('🔄 Overridden payment in term ${p.termId} ✅');
                    }
                  }
                }

                final studentPaymentBox =
                    await Hive.openBox<StudentPayment>('student_payments');
                final matchingPayments = studentPaymentBox.values.where(
                  (payment) =>
                      normalize(payment.paymentPurpose) == oldPurposeName,
                );

                for (var payment in matchingPayments) {
                  final key = payment.key;
                  final updatedPayment = payment.copyWith(
                    paymentPurpose: newPurposeName,
                    syncStatus: false,
                    lastModified: DateTime.now(),
                    operationType: 'update',
                    modifiedFields: [
                      ...(payment.modifiedFields ?? []),
                      'paymentPurpose'
                    ],
                  );
                  if (key != null) {
                    await studentPaymentBox.put(key, updatedPayment);
                    debugPrint(
                        '🌍 Updated student payment for purpose ${payment.paymentPurpose}');
                  }
                }

                debugPrint(
                    '✅ Global update applied: ${matchingPayments.length} student payments updated.');
              }
            }
          }

          debugPrint(
              '✅ ${matchingPayments.length} related student payments updated.');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Purpose Updated Successfully')),
        );

        Navigator.pop(context);
        Navigator.pop(context);
      } else {
        debugPrint('🚫 Failed to find the matching PaymentPurpose by code');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Purpose Not Found')),
        );
      }
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
