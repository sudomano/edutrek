import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class SummarizedIncomes extends StatefulWidget {
  const SummarizedIncomes({Key? key}) : super(key: key);

  @override
  _ViewByScreenState createState() => _ViewByScreenState();
}

class _ViewByScreenState extends State<SummarizedIncomes> {
  String? _selectedClass;
  String? _selectedStudent;
  String? _selectedPaymentPurpose;
  String? _selectedPaymentPurposeOnly;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedSortOption = 'Surname'; // Default sort option

  List<StudentPayment> _filteredPayments = [];
  List<String> _classes = ['All'];
  List<String> _students = [];
  List<String> _paymentPurposes = ['All'];
  List<String> _paymentPurposesOnly = [];
  Map<String, double> _paymentPurposeAmounts = {};
  Map<String, double> _paymentPurposeAmountsOnly = {};

  // Maps for holding payment data
  Map<String, Map<String, double>> groupedPayments = {};
  Map<String, Map<String, double>> totalPaid = {};

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

    _classes.addAll(paymentBox.values
        .where((payment) => payment.termId == globalTermId) // Filter by termId
        .map((payment) => payment.studentClass)
        .toSet()
        .toList());

    _paymentPurposes.addAll(paymentBox.values
        .where((payment) => payment.termId == globalTermId) // Filter by termId
        .map((payment) => payment.paymentPurpose)
        .toSet()
        .toList());

    _paymentPurposesOnly.addAll(paymentPurposeBox.values
        .where((purposeOnly) =>
            purposeOnly.termId == globalTermId) // Filter by termId
        .map((purposeOnly) => purposeOnly.paymentPurpose)
        .toSet()
        .toList());

    for (var purposeOnly
        in paymentPurposeBox.values.where((p) => p.termId == globalTermId)) {
      _paymentPurposeAmounts[purposeOnly.paymentPurpose] =
          purposeOnly.purposeAmount;
    }

    setState(() {});
  }

  Future<void> _fetchStudentsForClass(String studentClass) async {
    final paymentBox = Hive.box<StudentPayment>('student_payments');

    _students = paymentBox.values
        .where((payment) =>
            payment.studentClass == studentClass &&
            payment.termId == globalTermId) // Add termId filter
        .map((payment) => '${payment.studentName} ${payment.studentSurname}')
        .toSet()
        .toList();

    setState(() {});
  }

  void _filterPayments() {
    final paymentBox = Hive.box<StudentPayment>('student_payments');

    // Fetch all payments and then filter by termId
    _filteredPayments = paymentBox.values
        .where((payment) => payment.termId == globalTermId) // Filter by termId
        .toList();

    // Apply class filter
    if (_selectedClass != null && _selectedClass != "All") {
      _filteredPayments = _filteredPayments
          .where((payment) => payment.studentClass == _selectedClass)
          .toList();
    }

    // Apply student filter
    if (_selectedStudent != null && _selectedStudent!.isNotEmpty) {
      _filteredPayments = _filteredPayments
          .where((payment) => '${payment.studentName} ${payment.studentSurname}'
              .toLowerCase()
              .contains(_selectedStudent!.toLowerCase()))
          .toList();
    }

    // Apply payment purpose filter
    if (_selectedPaymentPurpose != null && _selectedPaymentPurpose != "All") {
      _filteredPayments = _filteredPayments
          .where((payment) => payment.paymentPurpose == _selectedPaymentPurpose)
          .toList();
    }

    // Apply date filters
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

    // Sort by the selected option
    if (_selectedSortOption == 'Surname') {
      _filteredPayments.sort((a, b) => a.studentSurname
          .toLowerCase()
          .compareTo(b.studentSurname.toLowerCase()));
    } else if (_selectedSortOption == 'First Name') {
      _filteredPayments.sort((a, b) =>
          a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));
    }

    _calculateGroupedPayments();
    _calculateTotalPaid();

    setState(() {});
  }

  void _calculateGroupedPayments() {
    groupedPayments.clear();
    for (var payment in _filteredPayments) {
      final studentName = '${payment.studentName} ${payment.studentSurname}';
      final paymentPurpose = payment.paymentPurpose;
      final amountToPay = payment.amountToPay.toDouble();
      groupedPayments.putIfAbsent(studentName, () => {});
      groupedPayments[studentName]!.putIfAbsent(paymentPurpose, () => 0.0);

      groupedPayments[studentName]![paymentPurpose] =
          (groupedPayments[studentName]![paymentPurpose] ?? 0.0) + amountToPay;
    }
  }

  void _calculateTotalPaid() {
    totalPaid.clear();
    for (var payment in _filteredPayments) {
      final studentName = '${payment.studentName} ${payment.studentSurname}';
      final paymentPurpose = payment.paymentPurpose;
      final amountPaid = payment.amountToPay.toDouble();
      totalPaid.putIfAbsent(studentName, () => {});
      totalPaid[studentName]!.putIfAbsent(paymentPurpose, () => 0.0);

      totalPaid[studentName]![paymentPurpose] =
          (totalPaid[studentName]![paymentPurpose] ?? 0.0) + amountPaid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Payments Summary'),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
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
                  title: 'Search by Student Name',
                  child: _buildSearchStudentField(),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      backgroundColor: Color.fromARGB(255, 238, 246, 248),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
                const SizedBox(height: 20),
                _filteredPayments.isEmpty
                    ? const Center(
                        child: Text(
                          'No payments found.',
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      )
                    : _buildStudentCards(),
              ],
            ),
          ),
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
          _selectedStudent = null;
          _filteredPayments = [];
          if (_selectedClass != "All" && _selectedClass != null) {
            _fetchStudentsForClass(_selectedClass!);
          } else {
            _students = [];
          }
        });
      },
      items: _classes.map((class_) {
        return DropdownMenuItem(
          value: class_,
          child: Text(class_),
        );
      }).toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color.fromARGB(255, 238, 246, 248),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSearchStudentField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search Student by Name',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedStudent = value;
        });
      },
    );
  }

  Widget _buildSearchPaymentPurposeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPaymentPurpose,
      hint: const Text('Select Payment Purpose'),
      onChanged: (value) {
        setState(() {
          _selectedPaymentPurpose = value;
          _filteredPayments = [];
        });
      },
      items: _paymentPurposes.map((paymentPurpose) {
        return DropdownMenuItem(
          value: paymentPurpose,
          child: Text(paymentPurpose),
        );
      }).toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color.fromARGB(255, 238, 246, 248),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSearchPaymentPeriod() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedStartDate = pickedDate;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 238, 246, 248),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _selectedStartDate != null
                            ? 'From: ${_selectedStartDate!.toLocal()}'
                            : 'Start Date',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedEndDate = pickedDate;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 238, 246, 248),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _selectedEndDate != null
                            ? 'To: ${_selectedEndDate!.toLocal()}'
                            : 'End Date',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSortOption,
      onChanged: (value) {
        setState(() {
          _selectedSortOption = value!;
          _filteredPayments = [];
        });
      },
      items: ['Surname', 'First Name'].map((sortOption) {
        return DropdownMenuItem(
          value: sortOption,
          child: Text(sortOption),
        );
      }).toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color.fromARGB(255, 238, 246, 248),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildStudentCards() {
    return Column(
      children: groupedPayments.entries.map((entry) {
        final studentName = entry.key;
        final studentClass = _filteredPayments
            .firstWhere(
              (payment) =>
                  '${payment.studentName} ${payment.studentSurname}' ==
                  studentName,
            )
            .studentClass;
        final totalPaidAmount =
            totalPaid[studentName]?.values.reduce((a, b) => a + b) ?? 0.0;

        // Calculate arrears for the student
        final arrears = _paymentPurposesOnly.map((purposeOnly) {
          final purposeAmount = _paymentPurposeAmounts[purposeOnly] ?? 0.0;
          final matchingAmount = entry.value.entries
                  .firstWhere(
                    (e) => e.key.toLowerCase() == purposeOnly.toLowerCase(),
                    orElse: () => MapEntry('', 0.0),
                  )
                  .value ??
              0.0;

          return matchingAmount - purposeAmount;
        }).reduce((a, b) => a + b);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Class: $studentClass',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildPaymentTable(entry, totalPaidAmount, arrears),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentTable(MapEntry<String, Map<String, double>> entry,
      double totalPaidAmount, double arrears) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      border: TableBorder.all(),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Colors.greenAccent),
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Payment Purpose',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Amount Paid (\$)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        ...entry.value.entries.map((paymentEntry) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(paymentEntry.key),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(paymentEntry.value.toStringAsFixed(2)),
              ),
            ],
          );
        }).toList(),
        TableRow(
          decoration: const BoxDecoration(color: Colors.greenAccent),
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Total Paid',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(totalPaidAmount.toStringAsFixed(2)),
            ),
          ],
        ),
      ],
    );
  }
}
