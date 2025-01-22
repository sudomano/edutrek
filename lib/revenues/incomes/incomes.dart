import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';

class ViewAllRevenuesFilters extends StatefulWidget {
  const ViewAllRevenuesFilters({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<ViewAllRevenuesFilters> {
  String? _selectedClass;
  String? _selectedPaymentPurpose;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedSortOption = 'Alphabetical'; // Default sort option

  List<StudentPayment> _filteredPayments = [];
  List<String> _classes = ['All'];
  List<String> _paymentPurposes = ['All'];
  Map<String, Map<String, double>> _classPaymentPurposeTotals = {};
  Map<String, double> _classArrearsTotals = {};
  double _grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final paymentBox = await Hive.openBox<StudentPayment>('student_payments');
    final paymentPurposeBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');

    // Fetch unique classes
    _classes.addAll(paymentBox.values
        .map((payment) => payment.studentClass)
        .toSet()
        .toList());

    // Fetch unique payment purposes
    _paymentPurposes.addAll(paymentPurposeBox.values
        .map((purpose) => purpose.paymentPurpose)
        .toSet()
        .toList());

    setState(() {});
  }

  void _filterPayments() {
    final paymentBox = Hive.box<StudentPayment>('student_payments');
    _filteredPayments = paymentBox.values.toList();

    if (_selectedClass != null && _selectedClass != "All") {
      _filteredPayments = _filteredPayments
          .where((payment) => payment.studentClass == _selectedClass)
          .toList();
    }

    if (_selectedPaymentPurpose != null && _selectedPaymentPurpose != "All") {
      _filteredPayments = _filteredPayments
          .where((payment) => payment.paymentPurpose == _selectedPaymentPurpose)
          .toList();
    }

    if (_selectedStartDate != null || _selectedEndDate != null) {
      _filteredPayments = _filteredPayments.where((payment) {
        final paymentDate = payment.paymentDate;
        if (_selectedStartDate != null && _selectedEndDate != null) {
          return paymentDate.isAfter(_selectedStartDate!) &&
              paymentDate.isBefore(_selectedEndDate!);
        } else if (_selectedStartDate != null) {
          return paymentDate.isAfter(_selectedStartDate!);
        } else if (_selectedEndDate != null) {
          return paymentDate.isBefore(_selectedEndDate!);
        }
        return true;
      }).toList();
    }

    // Sort the filtered classes based on the selected sorting option
    if (_selectedSortOption == 'Alphabetical') {
      _filteredPayments
          .sort((a, b) => a.studentClass.compareTo(b.studentClass));
    } else if (_selectedSortOption == 'Reverse Alphabetical') {
      _filteredPayments
          .sort((a, b) => b.studentClass.compareTo(a.studentClass));
    }

    // Calculate totals for each class by payment purpose
    _calculateClassTotals();

    setState(() {});
  }

  void _calculateClassTotals() {
    _classPaymentPurposeTotals.clear();
    _classArrearsTotals.clear();
    _grandTotal = 0.0;

    final paymentPurposeBox = Hive.box<PaymentPurpose>('payment_purposes');

    for (var payment in _filteredPayments) {
      final studentClass = payment.studentClass;
      final paymentPurpose = payment.paymentPurpose;
      final amountPaid = payment.amountToPay.toDouble();

      if (!_classPaymentPurposeTotals.containsKey(studentClass)) {
        _classPaymentPurposeTotals[studentClass] = {};
      }
      if (!_classPaymentPurposeTotals[studentClass]!
          .containsKey(paymentPurpose)) {
        _classPaymentPurposeTotals[studentClass]![paymentPurpose] = 0.0;
      }

      _classPaymentPurposeTotals[studentClass]![paymentPurpose] =
          _classPaymentPurposeTotals[studentClass]![paymentPurpose]! +
              amountPaid;

      // Calculate arrears
      final paymentPurposeObj = paymentPurposeBox.values
          .firstWhere((purpose) => purpose.paymentPurpose == paymentPurpose,
              orElse: () => PaymentPurpose(
                  id: 0, // Default or placeholder ID
                  paymentPurpose: 'Unknown', // Default or placeholder purpose
                  purposeAmount: 0.0)); // Default purpose amount
      final purposeAmount = paymentPurposeObj.purposeAmount ?? 0.0;
      final arrears = purposeAmount - amountPaid;
      if (!_classArrearsTotals.containsKey(studentClass)) {
        _classArrearsTotals[studentClass] = 0.0;
      }

      _classArrearsTotals[studentClass] =
          _classArrearsTotals[studentClass]! + arrears;
    }

    _grandTotal = _classPaymentPurposeTotals.values
        .map((purposeTotals) => purposeTotals.values.reduce((a, b) => a + b))
        .reduce((a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Class Revenues')),
        backgroundColor: const Color.fromARGB(255, 247, 248, 248),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              title: 'Filter by Class',
              child: _buildSearchClassDropdown(),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: 'Filter by Payment Purpose',
              child: _buildSearchPaymentPurposeDropdown(),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: 'Filter by Payment Period',
              child: _buildSearchPaymentPeriod(),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: 'Sort by',
              child: _buildSortDropdown(),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _filterPayments,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: const Color.fromARGB(255, 238, 246, 248),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
            const SizedBox(height: 20),
            _classPaymentPurposeTotals.isEmpty
                ? const Center(
                    child: Text(
                      'No payments found.',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : _buildClassPaymentsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSearchClassDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedClass,
      hint: const Text('Select Class'),
      onChanged: (value) {
        setState(() {
          _selectedClass = value;
          _filteredPayments = [];
        });
      },
      items: _classes.map((class_) {
        return DropdownMenuItem(
          value: class_,
          child: Text(class_),
        );
      }).toList(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchPaymentPurposeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPaymentPurpose,
      hint: const Text('Select Payment Purpose'),
      onChanged: (value) {
        setState(() {
          _selectedPaymentPurpose = value;
        });
      },
      items: _paymentPurposes.map((purpose) {
        return DropdownMenuItem(
          value: purpose,
          child: Text(purpose),
        );
      }).toList(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSearchPaymentPeriod() {
    return Row(
      children: [
        Expanded(
          child: _buildDatePickerField(
            context: context,
            label: 'Start Date',
            selectedDate: _selectedStartDate,
            onDateChanged: (newDate) {
              setState(() {
                _selectedStartDate = newDate;
              });
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildDatePickerField(
            context: context,
            label: 'End Date',
            selectedDate: _selectedEndDate,
            onDateChanged: (newDate) {
              setState(() {
                _selectedEndDate = newDate;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onDateChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        onDateChanged(pickedDate);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
              : 'Select Date',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSortOption,
      hint: const Text('Sort by'),
      onChanged: (value) {
        setState(() {
          _selectedSortOption = value!;
        });
      },
      items: ['Alphabetical', 'Reverse Alphabetical'].map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(option),
        );
      }).toList(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildClassPaymentsTable() {
    return DataTable(
      columns: [
        const DataColumn(label: Text('Class')),
        ..._paymentPurposes
            .map((purpose) => DataColumn(label: Text(purpose)))
            .toList(),
        const DataColumn(label: Text('Arrears')),
        const DataColumn(label: Text('Total')),
      ],
      rows: _classPaymentPurposeTotals.entries.map((entry) {
        final studentClass = entry.key;
        final purposeTotals = entry.value;
        final total = purposeTotals.values.reduce((a, b) => a + b);
        final arrears = _classArrearsTotals[studentClass] ?? 0.0;

        return DataRow(cells: [
          DataCell(Text(studentClass)),
          ..._paymentPurposes.map((purpose) {
            final amount = purposeTotals.containsKey(purpose)
                ? purposeTotals[purpose]
                : 0.0;
            return DataCell(Text(amount!.toStringAsFixed(2)));
          }).toList(),
          DataCell(Text(arrears.toStringAsFixed(2))),
          DataCell(Text(total.toStringAsFixed(2))),
        ]);
      }).toList(),
    );
  }
}
