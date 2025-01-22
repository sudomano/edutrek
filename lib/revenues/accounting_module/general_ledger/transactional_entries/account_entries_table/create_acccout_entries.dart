import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class AddAccountScreen extends StatefulWidget {
  @override
  _AddAccountScreenState createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _accountCodeController = TextEditingController();
  String? _selectedAccountType;
  String? _selectedAccountSubType;
  String? _selectedOperationType = "create";
  bool _syncStatus = false;
  DateTime? _lastUpdated = DateTime.now();
  bool isLiquid = false;

  Map<String, List<String>> accountSubTypes = {
    "Asset": [
      "Current Asset",
      "Non-Current Asset",
      "Intangible Asset",
      "Other Asset"
    ],
    "Expense": [
      "Operating Expense",
      "Cost Of Goods Sold",
      "Depreciation Expense",
      "Interest Expense",
      "Other Expense"
    ],
    "Liability": [
      "Current Liability",
      "Non-Current Liability",
      "Other Liability"
    ],
    "Equity": [
      "Owner's Equity",
      "Retained Earning",
      "Capital Contribution",
      "Dividend / Drawing",
      "Other Equity"
    ],
    "Revenue": [
      "Sales Revenue",
      "Services Revenue",
      "Interest Revenue",
      "Other Revenue"
    ]
  };

  List<String> accountTypes = [
    "Asset",
    "Liability",
    "Equity",
    "Revenue",
    "Expense"
  ];
  List<String> operationTypes = ["create", "update"];

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Account Type',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildDropdownField(
              label: "Account Type",
              value: _selectedAccountType,
              items: accountTypes,
              onChanged: (value) {
                setState(() {
                  _selectedAccountType = value;
                  _selectedAccountSubType = null;
                });
              },
            ),
            _buildDropdownField(
              label: "Account Sub-Type",
              value: _selectedAccountSubType,
              items: accountSubTypes[_selectedAccountType] ?? [],
              onChanged: (value) {
                setState(() {
                  _selectedAccountSubType = value;
                });
              },
            ),
            _buildTextField("Account Name", _accountNameController),
            _buildTextField("Account Code", _accountCodeController),
            _buildCheckboxField(), // Checkbox for "isALiquidAsset"

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: Text("Save Account"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: CheckboxListTile(
        title: Text("Is this a liquid asset?"),
        value: isLiquid,
        onChanged: (value) {
          setState(() {
            isLiquid = value ?? false;
          });
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<Account>('account');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      int newId = await getNextId();

      final newAccount = Account(
        id: newId,
        accountType: _selectedAccountType!,
        accountSubType: _selectedAccountSubType!,
        accountName: _accountNameController.text,
        accountCode: _accountCodeController.text,
        operationType: _selectedOperationType!,
        syncStatus: _syncStatus,
        lastModified: _lastUpdated!,
        isALiquidAccount: isLiquid,
      );

      // Open Hive box and save account
      final box = await Hive.openBox<Account>('account');
      await box.add(newAccount);
      Navigator.pop(context); // Close screen after save
    }
  }
}
