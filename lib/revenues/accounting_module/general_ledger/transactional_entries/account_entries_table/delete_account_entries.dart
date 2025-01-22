import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({Key? key}) : super(key: key);

  @override
  _DeleteAccountScreenState createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  List<Account> _foundAccounts = []; // List of found accounts for display

  void _searchAccount() async {
    final box = await Hive.openBox<Account>('account'); // Open Account Hive box
    final accounts = box.values.toList(); // Get all accounts from the box
    final searchTerm = _searchController.text.toLowerCase(); // Search term

    // Filter accounts by search term and global term ID if necessary
    final accountsWithName = accounts
        .where((account) =>
            account.accountName!.toLowerCase().startsWith(searchTerm))
        .toList();

    // Sort alphabetically by account name
    accountsWithName.sort((a, b) => a.accountName!.compareTo(b.accountName!));

    setState(() {
      _foundAccounts = accountsWithName;
    });
  }

  void _deleteAccount(Account accountToDelete) async {
    final box = await Hive.openBox<Account>('account');
    if (accountToDelete.operationType != null) {
      await box.delete(accountToDelete.key);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account Deleted Successfully')),
      );

      setState(() {
        _foundAccounts.remove(accountToDelete); // Remove from the UI list
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account cannot be deleted')),
      );
    }
  }

  void _confirmDeleteAllAccounts() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Accounts'),
          content: const Text(
              'Are you sure you want to delete all accounts from the system? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _deleteAllAccounts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAllAccounts() async {
    final box = await Hive.openBox<Account>('account');
    final accountsToDelete = box.values
        .cast<Account>()
        .where((a) => a.operationType != null)
        .toList();

    for (var account in accountsToDelete) {
      await box
          .delete(account.key); // Delete all accounts with the matching term ID
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${accountsToDelete.length} Accounts Deleted Successfully')),
    );

    setState(() {
      _foundAccounts.clear();
      Navigator.pop(context); // Clear the displayed list
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: Colors.red, // Set app bar background color
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _confirmDeleteAllAccounts,
            tooltip: 'Delete All Accounts',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Enter Account Name to Search',
                  filled: true,
                  fillColor:
                      Colors.white.withOpacity(0.3), // Transparent background
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none, // No border
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an Account Name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _searchAccount,
                child: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              if (_foundAccounts.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _foundAccounts.length,
                    itemBuilder: (context, index) {
                      final foundAccount = _foundAccounts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                              'Account Name: ${foundAccount.accountName}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Account Code: ${foundAccount.accountCode}',
                              style: const TextStyle(fontSize: 16)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAccount(foundAccount),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose controller to avoid memory leaks
    super.dispose();
  }
}
