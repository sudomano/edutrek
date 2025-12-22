import 'dart:async';
import 'package:flutter/material.dart';

// Minimal example model shapes — replace with your project models
class Student {
  final String id;
  final String name;
  final String surname;
  final String class_;

  Student({
    required this.id,
    required this.name,
    required this.surname,
    required this.class_,
  });

  @override
  String toString() => '$name $surname';
}

class PaymentPurpose {
  final String id;
  final String paymentPurpose;
  PaymentPurpose({required this.id, required this.paymentPurpose});

  @override
  String toString() => paymentPurpose;
}

// Queued payment item
class QueuedPayment {
  final PaymentPurpose purpose;
  final String termId;
  double amount;

  QueuedPayment({
    required this.purpose,
    required this.termId,
    required this.amount,
  });
}

// -----------------------------------------------------------------
// Replace these placeholders with your actual implementations:
// - fetchPurposesForStudent(student) -> Future<List<Map<String, dynamic>>>
//     each entry may include { 'purpose': PaymentPurpose, 'arrearsPreview': '...' }
// - fetchArrearsForPurpose(student, purpose) -> Future<Map<String,double>>
//     returns map termId -> arrearsAmount
// - submitQueuedPayments(student, List<QueuedPayment>) -> Future<bool>
// - computeTotalArrears(student) -> Future<double>
// -----------------------------------------------------------------

// Example placeholder implementations (synchronous stub). Replace them.
Future<List<Map<String, dynamic>>> fetchPurposesForStudent(
    Student student) async {
  // TODO: call your _fetchUniquePaymentPurposesByStudentWithArrears(student)
  await Future.delayed(const Duration(milliseconds: 200));
  // Example return: list of maps with 'purpose' and 'arrearsPreview'
  return [
    {
      'purpose': PaymentPurpose(id: '1', paymentPurpose: 'School Fees'),
      // 'arrearsPreview': '(Arrears: $120.00)',
    },
    {
      'purpose': PaymentPurpose(id: '2', paymentPurpose: 'Sports Fee'),
      //  'arrearsPreview': '(Arrears: $20.00)',
    },
  ];
}

Future<Map<String, double>> fetchArrearsForPurpose(
    Student student, PaymentPurpose purpose) async {
  // TODO: call your _checkArrears(purpose) or equivalent
  await Future.delayed(const Duration(milliseconds: 200));
  // Example: termId -> arrears
  return {
    '2025T1': 50.0,
    '2025T2': 0.0,
    '2025T3': 70.0,
  };
}

Future<bool> submitQueuedPayments(
    Student student, List<QueuedPayment> queue) async {
  // TODO: call your payment processing function
  await Future.delayed(const Duration(seconds: 1));
  return true;
}

// ===================================================================
// The main page widget
// ===================================================================

class StudentPaymentQueuePage extends StatefulWidget {
  const StudentPaymentQueuePage({super.key});

  @override
  State<StudentPaymentQueuePage> createState() =>
      _StudentPaymentQueuePageState();
}

class _StudentPaymentQueuePageState extends State<StudentPaymentQueuePage> {
  Student? _selectedStudent;
  final TextEditingController _studentSearchController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Payment purpose list loaded once per student selection
  List<Map<String, dynamic>> _availablePurposes = [];

  // When purpose selected -> used to open arrears sheet
  PaymentPurpose? _selectedPaymentPurpose;

  // Queue of selected payments to submit
  List<QueuedPayment> _queuedPayments = [];

  // UI state
  bool _loadingPurposes = false;
  bool _submitting = false;

  // optional totals
  Future<double>? _totalArrearsFuture;

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  // Call this after setting _selectedStudent
  Future<void> _loadPurposesForStudent() async {
    if (_selectedStudent == null) return;
    setState(() {
      _loadingPurposes = true;
      _availablePurposes = [];
      _selectedPaymentPurpose = null;
    });

    try {
      final list = await fetchPurposesForStudent(_selectedStudent!);
      setState(() {
        _availablePurposes = list;
      });
    } catch (e) {
      debugPrint('Error loading purposes: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to load payment purposes.'),
      ));
    } finally {
      setState(() {
        _loadingPurposes = false;
      });
    }
  }

  // Called when user taps a purpose to choose a term/amount
  Future<void> _onPurposeSelected(PaymentPurpose purpose) async {
    if (_selectedStudent == null) return;

    // Fetch arrears for this student-purpose
    Map<String, double> arrears = {};
    try {
      arrears = await fetchArrearsForPurpose(_selectedStudent!, purpose);
    } catch (e) {
      debugPrint('Error fetching arrears: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to fetch arrears for that purpose.'),
      ));
      return;
    }

    // If arrears map is empty -> we still allow user to enter custom payment (optional)
    // Show the bottom sheet UI with the arrears map and allow selection or manual amount
    final chosen = await showModalBottomSheet<_ArrearsSelectionResult?>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: ArrearsSelectorSheet(
            purpose: purpose,
            arrears: arrears,
          ),
        );
      },
    );

    // if user selected a term & amount -> add to queue
    if (chosen != null) {
      setState(() {
        _queuedPayments.add(QueuedPayment(
          purpose: purpose,
          termId: chosen.termId,
          amount: chosen.amount,
        ));
      });
    }
  }

  // Remove item from queued payments
  void _removeQueuedItem(int index) {
    setState(() {
      _queuedPayments.removeAt(index);
    });
  }

  // Edit queued amount in-place (opens a dialog)
  void _editQueuedItemAmount(int index) async {
    final item = _queuedPayments[index];
    final controller =
        TextEditingController(text: item.amount.toStringAsFixed(2));

    final ok = await showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Amount'),
          content: TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text('Save')),
          ],
        );
      },
    );

    if (ok == true) {
      final newAmount = double.tryParse(controller.text) ?? item.amount;
      setState(() {
        _queuedPayments[index].amount = newAmount;
      });
    }
  }

  Future<void> _submitAll() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a student first.')));
      return;
    }
    if (_queuedPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one payment to queue.')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final ok = await submitQueuedPayments(_selectedStudent!, _queuedPayments);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payments submitted successfully.')));
        setState(() {
          _queuedPayments.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit payments.')));
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error submitting payments.')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  // Example student selector. You'll replace this with your own search+dropdown or page
  Future<void> _selectStudent() async {
    // TODO: replace with your student picker (dropdown / dialog / search dropdown)
    // For demo we create a fake student
    final chosen = await showDialog<Student?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Pick Student (demo)'),
          children: [
            SimpleDialogOption(
                onPressed: () => Navigator.pop(
                    context,
                    Student(
                        id: '1',
                        name: 'Brighton',
                        surname: 'Moyo',
                        class_: 'Form 2')),
                child: const Text('Brighton Moyo')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(
                    context,
                    Student(
                        id: '2',
                        name: 'Tinashe',
                        surname: 'Dube',
                        class_: 'Form 1')),
                child: const Text('Tinashe Dube')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel')),
          ],
        );
      },
    );

    if (chosen != null) {
      setState(() {
        _selectedStudent = chosen;
        _queuedPayments.clear();
      });
      await _loadPurposesForStudent();
      // Optionally compute totals:
      _totalArrearsFuture =
          Future.delayed(const Duration(milliseconds: 50), () async {
        // TODO: call your _computeTotalStudentArrears
        return 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Payments Queue'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student selector
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(
                        text: _selectedStudent?.toString() ?? ''),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Selected Student',
                      hintText: 'Tap to choose a student',
                      border: const OutlineInputBorder(),
                    ),
                    onTap: _selectStudent,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: _selectStudent, child: const Text('Choose')),
              ],
            ),
            const SizedBox(height: 12),

            // Show total arrears if computed
            if (_selectedStudent != null)
              FutureBuilder<double>(
                future: _totalArrearsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Calculating total arrears...');
                  } else if (snapshot.hasError) {
                    return const Text('Failed to get total arrears');
                  } else {
                    final total = snapshot.data ?? 0.0;
                    return Text('Total Arrears: \$${total.toStringAsFixed(2)}');
                  }
                },
              ),

            const SizedBox(height: 16),

            // Purposes dropdown (loaded once)
            if (_selectedStudent != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Payment Purpose',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _loadingPurposes
                          ? const Center(child: CircularProgressIndicator())
                          : _availablePurposes.isEmpty
                              ? const Text(
                                  'No payment purposes found for this student.')
                              : DropdownButtonFormField<PaymentPurpose>(
                                  value: _selectedPaymentPurpose,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder()),
                                  isExpanded: true,
                                  items: _availablePurposes.map((entry) {
                                    final p =
                                        entry['purpose'] as PaymentPurpose;
                                    final preview =
                                        entry['arrearsPreview'] as String? ??
                                            '';
                                    return DropdownMenuItem<PaymentPurpose>(
                                      value: p,
                                      child: Text(
                                          '${p.paymentPurpose} ${preview}'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    _onPurposeSelected(value);
                                  },
                                ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 18),

            // Queued payments list
            Text('Queued Payments (${_queuedPayments.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_queuedPayments.isEmpty)
              const Text(
                  'No payments queued. Choose a purpose and add it to the queue.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _queuedPayments.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final qp = _queuedPayments[index];
                  return ListTile(
                    title: Text(qp.purpose.paymentPurpose),
                    subtitle: Text(
                        'Term: ${qp.termId} • Amount: \$${qp.amount.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            onPressed: () => _editQueuedItemAmount(index),
                            icon: const Icon(Icons.edit)),
                        IconButton(
                            onPressed: () => _removeQueuedItem(index),
                            icon: const Icon(Icons.delete, color: Colors.red)),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 22),

            // Submit row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submitAll,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(
                        _submitting ? 'Submitting...' : 'Submit All Payments'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _queuedPayments.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _queuedPayments.clear();
                          });
                        },
                  child: const Text('Clear Queue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Bottom-sheet arrears selector widget and result
// ===================================================================

class _ArrearsSelectionResult {
  final String termId;
  final double amount;

  _ArrearsSelectionResult(this.termId, this.amount);
}

class ArrearsSelectorSheet extends StatefulWidget {
  final PaymentPurpose purpose;
  final Map<String, double> arrears; // termId -> amount

  const ArrearsSelectorSheet({
    super.key,
    required this.purpose,
    required this.arrears,
  });

  @override
  State<ArrearsSelectorSheet> createState() => _ArrearsSelectorSheetState();
}

class _ArrearsSelectorSheetState extends State<ArrearsSelectorSheet> {
  String? _selectedTerm;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If there is exactly one term with arrears > 0, preselect it
    final positives = widget.arrears.entries.where((e) => e.value > 0).toList();
    if (positives.length == 1) {
      _selectedTerm = positives.first.key;
      _amountController.text = positives.first.value.toStringAsFixed(2);
    } else {
      _selectedTerm = null;
      _amountController.text = '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double _selectedArrearsAmount() {
    if (_selectedTerm == null) return 0.0;
    return widget.arrears[_selectedTerm] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final terms = widget.arrears.keys.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        children: [
          Text('Select term for: ${widget.purpose.paymentPurpose}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (terms.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'No arrears found for this purpose. You may enter an amount to pay (prepayment).'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (ZWL)'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(_amountController.text) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter an amount > 0')));
                      return;
                    }
                    Navigator.pop(
                        context, _ArrearsSelectionResult('PREPAYMENT', amt));
                  },
                  child: const Text('Add Payment'),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                // Show each term as a selectable tile
                ...terms.map((termId) {
                  final amt = widget.arrears[termId] ?? 0.0;
                  final label = amt > 0
                      ? 'Arrears: \$${amt.toStringAsFixed(2)}'
                      : 'No arrears';
                  return ListTile(
                    title: Text('Term: $termId'),
                    subtitle: Text(label),
                    trailing: _selectedTerm == termId
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedTerm = termId;
                        _amountController.text = amt.toStringAsFixed(2);
                      });
                    },
                  );
                }).toList(),

                const SizedBox(height: 8),

                // Amount field (editable)
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount',
                    helperText: 'You can edit the pre-filled amount',
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final amt =
                            double.tryParse(_amountController.text) ?? 0.0;
                        if (amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Amount must be greater than zero.')));
                          return;
                        }

                        final termToReturn = _selectedTerm ?? 'PREPAYMENT';
                        Navigator.pop(context,
                            _ArrearsSelectionResult(termToReturn, amt));
                      },
                      child: const Text('Add to Queue'),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
