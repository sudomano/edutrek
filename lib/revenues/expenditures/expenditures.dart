import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class ViewWithdrawalsScreen extends StatefulWidget {
  @override
  _ViewWithdrawalsScreenState createState() => _ViewWithdrawalsScreenState();
}

class _ViewWithdrawalsScreenState extends State<ViewWithdrawalsScreen> {
  late Box<Withdrawal> _withdrawalBox;
  List<Withdrawal> _filteredWithdrawals = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _withdrawalBox = Hive.box<Withdrawal>('withdrawals');
    _filterWithdrawals();
  }

  void _filterWithdrawals() {
    String searchText = _searchController.text.toLowerCase();
    _filteredWithdrawals = _withdrawalBox.values
        .where((withdrawal) =>
            withdrawal.withdrawalPurpose
                .toLowerCase()
                .contains(searchText.toLowerCase()) &&
            withdrawal.termId == globalTermId)
        .toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Withdrawals'),
        actions: [
          SizedBox(
            width: 30,
            height: 30,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  _filterWithdrawals();
                },
                decoration: const InputDecoration(
                  hintText: 'Search withdrawals',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _filteredWithdrawals.isEmpty
          ? const Center(
              child: Text('No withdrawals recorded.'),
            )
          : ListView.builder(
              itemCount: _filteredWithdrawals.length,
              itemBuilder: (context, index) {
                final withdrawal = _filteredWithdrawals[index];
                return _buildWithdrawalCard(withdrawal);
              },
            ),
    );
  }

  Widget _buildWithdrawalCard(Withdrawal withdrawal) {
    return Card(
      margin: const EdgeInsets.all(10.0),
      elevation: 5.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat.yMMMd().format(withdrawal.date)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Amount: \$${withdrawal.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Purpose: ${withdrawal.withdrawalPurpose}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'mods: ${withdrawal.modifiedFields.toString()}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    _editWithdrawal(context, withdrawal);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _deleteWithdrawal(withdrawal);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editWithdrawal(BuildContext context, Withdrawal withdrawal) {
    if (withdrawal.termId == globalTermId) {
      final amountController =
          TextEditingController(text: withdrawal.amount.toString());
      final purposeController =
          TextEditingController(text: withdrawal.withdrawalPurpose);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: purposeController,
                decoration: const InputDecoration(labelText: 'Purpose'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                final purpose = purposeController.text;
                final code = withdrawal.withdrawalCode;
                List<String> modifiedFields = withdrawal.modifiedFields ??
                    []; // Initialize with existing modified fields

// Append new modifications without overwriting
                if (withdrawal.amount != amount) {
                  if (!modifiedFields.contains('amount')) {
                    modifiedFields.add('amount');
                  }
                }

                if (withdrawal.withdrawalPurpose.toLowerCase() !=
                    purpose.toLowerCase()) {
                  if (!modifiedFields.contains('withdrawalPurpose')) {
                    modifiedFields.add('withdrawalPurpose');
                  }
                }

                if (amount > 0 && purpose.isNotEmpty) {
                  // Update the withdrawal details
                  withdrawal.withdrawalCode = code;
                  withdrawal.amount = amount;
                  withdrawal.withdrawalPurpose = purpose;
                  withdrawal.syncStatus = false; // Mark as unsynced
                  withdrawal.lastModified = DateTime.now(); // Update timestamp
                  withdrawal.operationType = 'update'; // Mark as an update
                  modifiedFields = modifiedFields;

                  withdrawal.save(); // Save the updated withdrawal

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Withdrawal updated successfully'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount and purpose'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No Selected Term Was Found. Create A New Term or Switch Terms To An Existing One.',
          ),
        ),
      );
    }
  }

  void _deleteWithdrawal(Withdrawal withdrawal) {
    if (withdrawal.termId == globalTermId) {
      _filteredWithdrawals = _withdrawalBox.values
          .where((withdrawal) => withdrawal.termId == globalTermId)
          .toList();
      for (var withd in _filteredWithdrawals) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Withdrawal'),
            content:
                const Text('Are you sure you want to delete this withdrawal?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  withd.delete();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Withdrawal deleted successfully')),
                  );
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No Selected Term Was Found. Create A New Term or Switch Terms To AnExisting One.')),
      );
    }
  }
}
