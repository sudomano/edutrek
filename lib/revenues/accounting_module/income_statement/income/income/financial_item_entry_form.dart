import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

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
  final _financialBox = Hive.box('financial_box');
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
    for (var category in categories.keys) {
      for (var subcategory in categories[category]!) {
        _items[category]![subcategory] = [];
      }
    }

    // Populate form with initial data if available
    if (widget.initialData.isNotEmpty) {
      _populateInitialData(widget.initialData);
    }
  }

  void _populateInitialData(Map<String, dynamic> data) {
    setState(() {
      selectedDate = DateTime.parse(data['date'] ?? DateTime.now().toString());
      totalIncome = data['totalIncome'] ?? 0.0;
      totalExpenditure = data['totalExpenditure'] ?? 0.0;

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

  void _addField(String category, String subcategory) {
    setState(() {
      _items[category]![subcategory]!.add({'description': '', 'amount': 0.0});
    });
  }

  void _removeField(String category, String subcategory, int index) {
    setState(() {
      _items[category]![subcategory]!.removeAt(index);
      _calculateTotals();
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
      totalIncome = income;
      totalExpenditure = expenditure;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Statement Date: ', style: TextStyle(fontSize: 16)),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    "${selectedDate.toLocal()}".split(' ')[0],
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Total Expenditure: \$${totalExpenditure.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Surplus/Deficit: \$${surplusOrDeficit.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: surplusOrDeficit >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveItems,
              child: const Text('Save All Items'),
            ),
            ElevatedButton(
              onPressed: widget.navigateToHistory,
              child: const Text('Go to Display Screen'),
            ),
          ],
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
                  item['amount'] = double.tryParse(value) ?? 0.0;
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
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
