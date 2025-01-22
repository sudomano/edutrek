import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/database/accounting_module_models/assets.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class AssetAcquisitionForm extends StatefulWidget {
  @override
  _AssetAcquisitionFormState createState() => _AssetAcquisitionFormState();
}

class _AssetAcquisitionFormState extends State<AssetAcquisitionForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for acquisition form
  final TextEditingController _acquisitionDateController =
      TextEditingController();
  final TextEditingController _acquisitionCostController =
      TextEditingController();
  final TextEditingController _assetSerialNoController =
      TextEditingController();

  String? _selectedOperationType = "create";
  bool _syncStatus = false;
  DateTime? _lastUpdated = DateTime.now();

  // Data for dropdown and selected account
  List<Account> _filteredAccounts = [];
  Account? _selectedAccount;

  List<Account> _filteredMethods = [];
  Account? _selectedMethod;

  late Box<Account> accountsBox;
  late Box<Asset> assetBox;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    accountsBox = await Hive.openBox<Account>('account');
    assetBox = await Hive.openBox<Asset>('asset');
    _fetchMethods();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() {
      _filteredAccounts = accountsBox.values
          .where((account) =>
              account.accountType!.toLowerCase() == "asset" &&
              account.accountSubType!.toLowerCase() == "non-current asset")
          .toList();
      if (_filteredAccounts.isNotEmpty) {
        _selectedAccount ??= _filteredAccounts.first;
      }
    });
  }

  Future<void> _fetchMethods() async {
    setState(() {
      _filteredMethods = accountsBox.values
          .where((methods) =>
              methods.accountType!.toLowerCase() == "asset" &&
              methods.accountSubType!.toLowerCase() == "current asset" &&
              methods.isALiquidAccount! == true)
          .toList();
      if (_filteredMethods.isNotEmpty) {
        _selectedMethod ??= _filteredMethods.first;
      }
    });
  }

  Future<int> getNextId() async {
    if (assetBox.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = assetBox.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      int newId = await getNextId();
      final acquisitionDate = _acquisitionDateController.text;
      DateTime? acquisitionDates = DateTime.tryParse(acquisitionDate);

      // Handle double parsing for acquisition cost with validation
      double acquisitionCost =
          double.tryParse(_acquisitionCostController.text) ?? 0.0;
      if (acquisitionCost <= 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Please enter a valid acquisition cost greater than 0.")));
        return; // Prevent submission if the cost is invalid
      }

      final acquisitionMethod = _selectedMethod?.accountName ?? "N/A";
      final assetSerialNo = _assetSerialNoController.text;

      final formData1 = Asset(
        id: newId,
        option: "Acquired Asset",
        acquisitionDate: acquisitionDates,
        acquisitionCost: acquisitionCost,
        acquisitionMethod: acquisitionMethod,
        assetSerialNo: assetSerialNo,
        hasDebitBalance: true,
        hasCreditBalance: false,
        assetName: _selectedAccount?.accountName,
        assetType: _selectedAccount?.accountType,
        assetSubType: _selectedAccount?.accountSubType,
        assetCode: _selectedAccount?.accountCode,
        operationType: _selectedOperationType!,
        syncStatus: _syncStatus,
        lastModified: _lastUpdated!,
      );

      final formData2 = Asset(
        id: newId,
        option: "Paid Asset",
        acquisitionDate: acquisitionDates,
        acquisitionCost: acquisitionCost,
        acquisitionMethod: acquisitionMethod,
        assetSerialNo: assetSerialNo,
        hasDebitBalance: false,
        hasCreditBalance: true,
        assetName: _selectedMethod?.accountName,
        assetType: _selectedMethod?.accountType,
        assetSubType: _selectedMethod?.accountSubType,
        assetCode: _selectedMethod?.accountCode,
        operationType: _selectedOperationType!,
        syncStatus: _syncStatus,
        lastModified: _lastUpdated!,
      );
      await assetBox.add(formData1);
      print(formData1);

      await assetBox.add(formData2);
      print(formData2);

      // Clear fields after successful addition
      _acquisitionDateController.clear();
      _acquisitionCostController.clear();
      _assetSerialNoController.clear();
      setState(() {
        _selectedAccount = null;
        _selectedMethod = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Asset successfully acquired.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Assets',
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First Form (Editable)
            Expanded(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Text(
                            '${_selectedAccount?.accountName} a/c ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Acquisition Date with DatePicker
                      GestureDetector(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _acquisitionDateController.text =
                                  pickedDate.toLocal().toString().split(' ')[0];
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _acquisitionDateController,
                            decoration:
                                InputDecoration(labelText: "Acquisition Date"),
                            validator: (value) => value?.isEmpty == true
                                ? "Enter acquisition date"
                                : null,
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _assetSerialNoController,
                        decoration:
                            InputDecoration(labelText: "Asset Serial Number"),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true
                            ? "Enter Asset Serial Number"
                            : null,
                      ),
                      // Acquisition Cost
                      TextFormField(
                        controller: _acquisitionCostController,
                        decoration:
                            InputDecoration(labelText: "Acquisition Amount"),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty == true
                            ? "Enter acquisition amount"
                            : null,
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<Account>(
                        value: _filteredMethods.isNotEmpty
                            ? _selectedMethod
                            : null,
                        items: _filteredMethods
                            .map((account) => DropdownMenuItem(
                                  value: account,
                                  child: Text(account.accountName!),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedMethod = value;
                            });
                          }
                        },
                        decoration:
                            InputDecoration(labelText: "Acquisition Method"),
                        validator: (value) =>
                            value == null ? "Select an method name" : null,
                      ),

                      DropdownButtonFormField<Account>(
                        value: _selectedAccount,
                        items: _filteredAccounts
                            .map((account) => DropdownMenuItem(
                                  value: account,
                                  child: Text(account.accountName!),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedAccount = value;
                            });
                          }
                        },
                        decoration: InputDecoration(labelText: "Account Name"),
                        validator: (value) =>
                            value == null ? "Select an account name" : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Account Details:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                          "Asset Name: ${_selectedAccount?.accountName ?? "N/A"}"),
                      Text(
                          "Asset Type: ${_selectedAccount?.accountType ?? "N/A"}"),
                      Text(
                          "Asset SubType: ${_selectedAccount?.accountSubType ?? "N/A"}"),
                      Text(
                          "Asset Code: ${_selectedAccount?.accountCode ?? "N/A"}"),
                      Text("Asset Balance side: Debit"),

                      const SizedBox(height: 20),
                      // Submit button
                      Center(
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          child: Text("Submit"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Second Form (Read-Only)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: Text(
                          '${_selectedMethod?.accountName} a/c ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Auto-populated acquisition date
                    TextFormField(
                      controller: TextEditingController(
                        text: _acquisitionDateController.text,
                      ),
                      decoration:
                          InputDecoration(labelText: "Acquisition Date"),
                      readOnly: true,
                    ),
                    TextFormField(
                      controller: TextEditingController(
                        text: _assetSerialNoController.text,
                      ),
                      decoration: InputDecoration(labelText: "Asset Serial No"),
                      readOnly: true,
                    ),
                    // Auto-populated acquisition cost
                    TextFormField(
                      controller: TextEditingController(
                        text: _acquisitionCostController.text,
                      ),
                      decoration:
                          InputDecoration(labelText: "Acquisition Amount"),
                      readOnly: true,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: TextEditingController(
                        text: _selectedMethod?.accountName ?? "",
                      ),
                      decoration:
                          InputDecoration(labelText: "Acquisition Method"),
                      readOnly: true,
                    ),
                    TextFormField(
                      controller: TextEditingController(
                        text: _selectedAccount?.accountName ?? "",
                      ),
                      decoration: InputDecoration(labelText: "Account Name"),
                      readOnly: true,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Account Details:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                        "Asset Name: ${_selectedMethod?.accountName ?? "N/A"}"),
                    Text(
                        "Asset Type: ${_selectedMethod?.accountType ?? "N/A"}"),
                    Text(
                        "Asset SubType: ${_selectedMethod?.accountSubType ?? "N/A"}"),
                    Text(
                        "Asset Code: ${_selectedMethod?.accountCode ?? "N/A"}"),
                    Text("Asset Balance side: Credit"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _acquisitionDateController.dispose();
    _acquisitionCostController.dispose();
    _assetSerialNoController.dispose();
    super.dispose();
  }
}
