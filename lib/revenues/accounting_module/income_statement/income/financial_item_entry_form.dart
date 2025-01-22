import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zitf_system/database/withdrawalshome.dart';

final _formKey = GlobalKey<FormState>();

class FinancialItemEntryForm extends StatefulWidget {
  final VoidCallback navigateToHistory;
  final Map<String, dynamic> initialData;

  const FinancialItemEntryForm({
    super.key,
    required this.navigateToHistory,
    required this.initialData,
  });

  @override
  _FinancialItemEntryFormState createState() => _FinancialItemEntryFormState();
}

class _FinancialItemEntryFormState extends State<FinancialItemEntryForm> {
  late final Box _financialBox;
  late final Box<StudentPayment> _studentPaymentBox;
  late final Box<TeacherPayment> _staffPaymentBox;
  late final Box<Withdrawal> _withdrawalBox;

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  DateTime startDate2 = DateTime.now();
  DateTime endDate2 = DateTime.now();

  DateTime startDate3 = DateTime.now();
  DateTime endDate3 = DateTime.now();

  final Map<String, List<String>> categories = {
    'INCOME': [
      'Department of Education and Science',
      'School Generated Income',
      'Other Income'
    ],
    'EXPENDITURE': [
      'Education – Teachers\' / Supervisors Salaries',
      'Education – Other Expenses',
      'Repairs, Maintenance and Establishment (RME)',
      'Administration',
      'Finance',
      'Depreciation'
    ],
  };

  final Map<String, Map<String, List<Map<String, dynamic>>>> _items = {
    'INCOME': {},
    'EXPENDITURE': {},
  };

  double totalIncome = 0.0;
  double totalExpenditure = 0.0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _financialBox = Hive.box('financial_box');
    _studentPaymentBox = Hive.box<StudentPayment>('student_payments');
    _staffPaymentBox = Hive.box<TeacherPayment>('teacher_payments');
    _withdrawalBox = Hive.box<Withdrawal>('withdrawals');

    for (var category in categories.keys) {
      for (var subcategory in categories[category]!) {
        _items[category]![subcategory] = [];
      }
    }

    // Populate form with initial data if available
    if (widget.initialData.isNotEmpty) {
      _populateInitialData(widget.initialData);
    }

    // Calculate initial total income from student payments
    _calculateInitialIncome();
    _calculateInitialExpense();
    _calculateInitialWithdrawal();
  }

  void _populateInitialData(Map<String, dynamic> data) {
    setState(() {
      selectedDate = DateTime.parse(data['date'] ?? DateTime.now().toString());
      totalIncome = data['totalIncome'] ?? 0.0;
      totalExpenditure = data['totalExpenditure'] ?? 0.0;

      selectedDate = DateTime.parse(data['date'] ?? DateTime.now().toString());

      // Initialize _items with correct types and structure
      Map<String, dynamic> itemsData = data['items'] ?? {};
      itemsData.forEach((category, subcategories) {
        subcategories.forEach((subcategory, itemList) {
          if (_items[category]?[subcategory] != null) {
            _items[category]![subcategory] =
                List<Map<String, dynamic>>.from(itemList);
          }
        });
      });
    });
  }

  void _calculateInitialIncome() {
    double initialIncome = _studentPaymentBox.values
        .where((payment) => payment.termId != null)
        .fold(0.0, (sum, payment) => sum + payment.amountToPay);

    setState(() {
      totalIncome = initialIncome; // Set it only once at initialization.
    });
  }

  void _calculateInitialExpense() {
    double initialExpense = _staffPaymentBox.values
        .where((payment) => payment.termId != null)
        .fold(0.0, (sum, payment) => sum + payment.amountToPay);

    setState(() {
      totalExpenditure = initialExpense; // Set it only once at initialization.
    });
  }

  void _calculateInitialWithdrawal() {
    double initialWithdrawal = _withdrawalBox.values
        .where((payment) => payment.termId != null)
        .fold(0.0, (sum, payment) => sum + payment.amount);

    setState(() {
      totalExpenditure =
          initialWithdrawal; // Set it only once at initialization.
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != startDate) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != endDate) {
      setState(() {
        endDate = picked;
      });
    }
  }

  Future<void> _selectStartDate2(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate2,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != startDate2) {
      setState(() {
        startDate2 = picked;
      });
    }
  }

  Future<void> _selectEndDate2(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate2,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != endDate2) {
      setState(() {
        endDate2 = picked;
      });
    }
  }

  Future<void> _selectStartDate3(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate3,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != startDate2) {
      setState(() {
        startDate3 = picked;
      });
    }
  }

  Future<void> _selectEndDate3(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate3,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != endDate2) {
      setState(() {
        endDate3 = picked;
      });
    }
  }

  void _addField(String category, String subcategory) {
    setState(() {
      _items[category]![subcategory]!.add({'description': '', 'amount': 0.0});
    });
  }

  void _removeField(String category, String subcategory, int index) {
    setState(() {
      _items[category]![subcategory]!.removeAt(index);
      _calculateTotals(); // Recalculate totals after item removal
    });
  }

  void _calculateTotals() {
    double income = 0.0;
    double expenditure = 0.0;

    for (var category in _items.keys) {
      for (var subcategory in _items[category]!.keys) {
        for (var item in _items[category]![subcategory]!) {
          if (category == 'INCOME') {
            income += item['amount'] ?? 0.0;
          } else if (category == 'EXPENDITURE') {
            expenditure += item['amount'] ?? 0.0;
          }
        }
      }
    }

    setState(() {
      totalIncome = income; // Reset total income
      totalExpenditure = expenditure; // Reset total expenditure
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _saveItems() {
    List<Map<String, dynamic>> savedEntries = [];

    for (var category in _items.keys) {
      for (var subcategory in _items[category]!.keys) {
        for (var item in _items[category]![subcategory]!) {
          if (item['description'].isNotEmpty && item['amount'] > 0) {
            savedEntries.add({
              'category': category,
              'subcategory': subcategory,
              'description': item['description'],
              'amount': item['amount'],
              'timestamp': selectedDate.toIso8601String(),
            });
          }
        }
      }
    }

    if (savedEntries.isNotEmpty) {
      _financialBox.add(savedEntries);
    }

    widget.navigateToHistory(); // Navigate to history screen after saving
  }

  void _editSubcategory(
      String category, String subcategory, String newSubcategory) {
    setState(() {
      categories[category]!.remove(subcategory);
      categories[category]!.add(newSubcategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    double surplusOrDeficit = totalIncome - totalExpenditure;

    return Center(
        child: Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Row(
                    children: [
                      const SizedBox(height: 16),
                      Center(
                          child: Center(
                              child: Text(
                        'Students Payment Incomes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, // Makes the text bold
                        ),
                      ))),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Center(child: Text('Students Payment Income')),
                    const Text('Start Date:'),
                    TextButton(
                      onPressed: () => _selectStartDate(context),
                      child: Text("${startDate.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('End Date:'),
                    TextButton(
                      onPressed: () => _selectEndDate(context),
                      child: Text("${endDate.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _fetchPaymentsBetweenDates,
                  child: const Text('Fetch Payments for Selected Period'),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                const Center(
                  child: Row(
                    children: [
                      Center(
                          child: Center(
                              child: Text(
                        'School Withdrawal Expenditures',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, // Makes the text bold
                        ),
                      ))),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Center(child: Text('School Withdrawal Expenditures')),
                    const Text('Start Date:'),
                    TextButton(
                      onPressed: () => _selectStartDate3(context),
                      child: Text("${startDate3.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('End Date:'),
                    TextButton(
                      onPressed: () => _selectEndDate3(context),
                      child: Text("${endDate3.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _fetchPaymentsBetweenDates3,
                  child: const Text('Fetch Withdrawals for Selected Period'),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                const Center(
                  child: Row(
                    children: [
                      Center(
                          child: Center(
                              child: Text(
                        'Staff Payment Expenditures',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, // Makes the text bold
                        ),
                      ))),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Center(child: Text('Staff Payment Expenditures')),
                    const Text('Start Date:'),
                    TextButton(
                      onPressed: () => _selectStartDate2(context),
                      child: Text("${startDate2.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('End Date:'),
                    TextButton(
                      onPressed: () => _selectEndDate2(context),
                      child: Text("${endDate2.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _fetchPaymentsBetweenDates2,
                  child: const Text('Fetch Staff Expenses for Selected Period'),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                ...categories.entries.map((categoryEntry) {
                  String category = categoryEntry.key;
                  List<String> subcategories = categoryEntry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...subcategories.map((subcategory) =>
                          _buildSubcategoryTable(category, subcategory)),
                      const SizedBox(height: 24),
                    ],
                  );
                }),
                Text(
                  'Total Income: \$${totalIncome.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total Expenditure: \$${totalExpenditure.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Center(
                  child: Text(
                    'Surplus/Deficit: \$${surplusOrDeficit.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: surplusOrDeficit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _generatePdf,
                    child: const Text('Generate PDF'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  void _fetchPaymentsBetweenDates() {
    double importedIncome = _studentPaymentBox.values
        .where((payment) =>
            payment.termId != null &&
            payment.paymentDate.isAfter(startDate) &&
            payment.paymentDate.isBefore(endDate))
        .fold(0.0, (sum, payment) => sum + payment.amountToPay);

    String defaultSubcategory =
        categories['INCOME']!.first; // Use the first subcategory

    setState(() {
      _items['INCOME']![defaultSubcategory]!.add({
        'description':
            'Income from ${startDate.toLocal()} to ${endDate.toLocal()}',
        'amount': importedIncome,
      });

      // Update the total income
      totalIncome += importedIncome;

      // Recalculate totals to ensure surplus/deficit is updated
      _calculateTotals();
    });

    // Optional: Show a message indicating success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Incomes of \$${importedIncome.toStringAsFixed(2)} imported successfully!',
        ),
      ),
    );
  }

  void _fetchPaymentsBetweenDates2() {
    // Debug: Filtering payments and printing filtered results
    List<TeacherPayment> filteredExpenses =
        _staffPaymentBox.values.where((payment) {
      return payment.termId != null &&
          payment.paymentDate.isAfter(startDate2) &&
          payment.paymentDate.isBefore(endDate2);
    }).toList();

    // Summing the amounts from filtered expenses
    double importedExpenses = filteredExpenses.fold(
      0.0,
      (sum, payment) => sum + payment.amountToPay,
    );

    // Adding to the respective category
    String defaultSubcategory =
        categories['EXPENDITURE']!.first; // Use the first subcategory

    setState(() {
      _items['EXPENDITURE']![defaultSubcategory]!.add({
        'description':
            'Expenses from ${startDate2.toLocal()} to ${endDate2.toLocal()}',
        'amount': importedExpenses,
      });

      // Update the total expenditure
      totalExpenditure += importedExpenses;
    });
    // Optional: Show a message indicating success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Expenses of \$${importedExpenses.toStringAsFixed(2)} imported successfully!',
        ),
      ),
    );
  }

  void _fetchPaymentsBetweenDates3() {
    // Debug: Filtering payments and printing filtered results
    List<Withdrawal> filteredWithdrawal =
        _withdrawalBox.values.where((payment) {
      return payment.termId != null &&
          payment.date.isAfter(startDate3) &&
          payment.date.isBefore(endDate3);
    }).toList();

    // Summing the amounts from filtered expenses
    double importedWithdrawals = filteredWithdrawal.fold(
      0.0,
      (sum, payment) => sum + payment.amount,
    );

    // Adding to the respective category
    String defaultSubcategory =
        categories['EXPENDITURE']!.first; // Use the first subcategory

    setState(() {
      _items['EXPENDITURE']![defaultSubcategory]!.add({
        'description':
            'Withdrawals from ${startDate3.toLocal()} to ${endDate3.toLocal()}',
        'amount': importedWithdrawals,
      });

      // Update the total expenditure
      totalExpenditure += importedWithdrawals;
    });

    // Optional: Show a message indicating success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Withdrawals of \$${importedWithdrawals.toStringAsFixed(2)} imported successfully!',
        ),
      ),
    );
  }

  Widget _buildSubcategoryTable(String category, String subcategory) {
    TextEditingController subcategoryController =
        TextEditingController(text: subcategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(subcategory,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                String? newSubcategory =
                    await _showEditDialog(context, subcategory);
                if (newSubcategory != null && newSubcategory.isNotEmpty) {
                  _editSubcategory(category, subcategory, newSubcategory);
                }
              },
            ),
          ],
        ),
        DataTable(
          columns: const [
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _items[category]![subcategory]!.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;
            return DataRow(cells: [
              DataCell(TextField(
                controller: TextEditingController(text: item['description']),
                decoration: const InputDecoration(labelText: 'Description'),
                onChanged: (value) {
                  item['description'] = value;
                },
              )),
              DataCell(TextField(
                controller:
                    TextEditingController(text: item['amount'].toString()),
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  // Parse the new and old amounts
                  double newAmount = double.tryParse(value) ?? 0.0;
                  double oldAmount = item['amount'] ?? 0.0;

                  // Update the item's amount
                  item['amount'] = newAmount;

                  // Adjust the correct total dynamically
                  setState(() {
                    if (category == 'INCOME') {
                      totalIncome +=
                          (newAmount - oldAmount); // Update income only
                    } else if (category == 'EXPENDITURE') {
                      totalExpenditure +=
                          (newAmount - oldAmount); // Update expenditure only
                    }
                  });

                  // Recalculate surplus/deficit after updates
                  _calculateTotals();
                },
              )),
              DataCell(IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _removeField(category, subcategory, index);
                },
              )),
            ]);
          }).toList(),
        ),
        ElevatedButton(
          onPressed: () => _addField(category, subcategory),
          child: const Text('Add Item'),
        ),
      ],
    );
  }

  Future<String?> _showEditDialog(
      BuildContext context, String subcategory) async {
    TextEditingController controller = TextEditingController(text: subcategory);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subcategory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Subcategory Name'),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    // Build the PDF structure
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Financial Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                  'Start Date: ${startDate.toLocal().toString().split(' ')[0]}'),
              pw.Text(
                  'End Date: ${endDate.toLocal().toString().split(' ')[0]}'),
              pw.SizedBox(height: 16),
              pw.Text('Income and Expenditures',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              // Income Table
              pw.Text('INCOME',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              _buildCategoryTable('INCOME'),

              // Expenditure Table
              pw.SizedBox(height: 16),
              pw.Text('EXPENDITURE',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              _buildCategoryTable('EXPENDITURE'),

              // Totals
              pw.SizedBox(height: 16),
              pw.Text(
                'Total Income: \$${totalIncome.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Total Expenditure: \$${totalExpenditure.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Surplus/Deficit: \$${(totalIncome - totalExpenditure).toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: totalIncome >= totalExpenditure
                      ? PdfColors.green
                      : PdfColors.red,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save the PDF to a file using File Picker
    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF File',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        fileName: 'Financial_Report.pdf',
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsBytes(await pdf.save());
        print('PDF saved successfully at: $savePath');
      } else {
        print('File save operation was canceled.');
      }
    } catch (e) {
      print('Error saving PDF: $e');
    }
  }

// Helper to create tables for each category
  pw.Widget _buildCategoryTable(String category) {
    final rows = <pw.TableRow>[];

    for (final subcategory in _items[category]!.keys) {
      final subcategoryItems = _items[category]![subcategory]!;

      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(subcategory,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(), // Empty column for spacing
          ],
        ),
      );

      for (final item in subcategoryItems) {
        rows.add(
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item['description'] ?? ''),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('\$${(item['amount'] ?? 0).toStringAsFixed(2)}'),
              ),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      children: rows,
    );
  }
}
