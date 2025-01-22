import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateAccountScreen extends StatefulWidget {
  final int index;

  const UpdateAccountScreen({super.key, required this.index});

  @override
  _UpdateAccountScreenState createState() => _UpdateAccountScreenState();
}

class _UpdateAccountScreenState extends State<UpdateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _accountCodeController = TextEditingController();
  String? _selectedAccountType;
  String? _selectedAccountSubType;
  bool? isLiquid = false;
  late Account currentAccount;

  Map<String, List<String>> accountSubTypes = {
    "Asset": [
      "Current Assets",
      "Non-Current Assets",
      "Intangible Assets",
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
      "Retained Earnings",
      "Capital Contributions",
      "Dividends / Drawings",
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

  @override
  void initState() {
    super.initState();
    final Box<Account> box = Hive.box<Account>('account');

    // Load the current account from the Hive box
    currentAccount = box.getAt(widget.index)!;

    // Populate the text fields with the current account information
    _accountNameController.text = currentAccount.accountName ?? '';
    _accountCodeController.text = currentAccount.accountCode ?? '';
    _selectedAccountType = accountTypes.contains(currentAccount.accountType)
        ? currentAccount.accountType
        : null;
    _selectedAccountSubType = accountSubTypes[currentAccount.accountType]!
            .contains(currentAccount.accountSubType)
        ? currentAccount.accountSubType
        : null;
    isLiquid = currentAccount.isALiquidAccount;
  }

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
            // Add a checkbox for 'Is a Liquid Asset?'
            CheckboxListTile(
              title: Text("Is a Liquid Asset?"),
              value: isLiquid,
              onChanged: (value) {
                setState(() {
                  isLiquid = value ?? false;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateAccount,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 15, 15, 15),
                backgroundColor: const Color.fromARGB(255, 251, 252, 254),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Update Account'),
            ),
          ],
        ),
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
        value: items.contains(value) ? value : null, // Ensure value is valid
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

  void _updateAccount() async {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<Account>('account');

      // Get the updated values from the text fields
      final accountName = _accountNameController.text;
      final accountCode = _accountCodeController.text;

      // Ensure the user isn't updating to a duplicate account name
      final existingAccount = box.values.firstWhere(
        (a) =>
            a.accountName != null &&
            a.accountName!.toLowerCase() == accountName.toLowerCase(),
        orElse: () => Account(),
      );

      if (existingAccount.accountName != null &&
          existingAccount.accountName!.isNotEmpty &&
          existingAccount.accountName != currentAccount.accountName) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account with this name already exists')),
        );
        return;
      }
      int? newId = existingAccount.id;

      // Create the updated account object using copyWith to preserve unchanged fields
      final updatedAccount = currentAccount.copyWith(
        accountName: accountName,
        accountCode: accountCode,
        accountType: _selectedAccountType!,
        accountSubType: _selectedAccountSubType!,
        lastModified: DateTime.now(),
        operationType: "update",
        syncStatus: false,
        id: newId,
        isALiquidAccount: isLiquid,
      );

      // Update the account in Hive at the specific index
      box.putAt(widget.index, updatedAccount);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account Updated Successfully')),
      );

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountCodeController.dispose();
    super.dispose();
  }
}
