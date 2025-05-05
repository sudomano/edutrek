import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/revenues/expenditures/expenditures.dart';

class WithdrawalScreen extends StatefulWidget {
  @override
  _WithdrawalScreenState createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  Future<int> getNextId() async {
    final box = await Hive.openBox<Withdrawal>('withdrawals');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  void _makeWithdrawal(BuildContext context) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final purpose = _purposeController.text.trim();

    if (amount <= 0 || purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount and purpose'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (globalTermId != null) {
      final box = await Hive.openBox<Withdrawal>('withdrawals');

      // Check for duplicates
      bool purposeExists =
          box.values.any((w) => w.withdrawalPurpose == purpose);

      /*
 if (purposeExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              purposeExists
                  ? 'The withdrawal purpose already exists.'
                  : 'The withdrawal code already exists.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }


     */
      // Proceed with adding a new withdrawal
      int newId = await getNextId();
      final newPkValue = uuid.v4();
      List<String> modifiedFields = [];
      modifiedFields.add('id');
      modifiedFields.add('date');
      modifiedFields.add('amount');
      modifiedFields.add('withdrawalPurpose');
      modifiedFields.add('termId');
      modifiedFields.add('withdrawalCode');

      final withdrawal = Withdrawal(
        withdrawalCode: newPkValue,
        id: newId,
        date: DateTime.now(),
        amount: amount,
        withdrawalPurpose: purpose,
        termId: globalTermId,
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType:
            'create', // Set operationType to 'create' // Set the global term ID
        modifiedFields: modifiedFields,
      );

      await box.add(withdrawal);

      _amountController.clear();
      _purposeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal recorded successfully'),
        ),
      );

      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No Selected Term Was Found. Create A New Term or Switch Terms To AnExisting One.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
            child: Text(
          'Withdrawals',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.list,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ViewWithdrawalsScreen()),
              );
            },
          ),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0, // Optional: Add a subtle shadow
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _purposeController,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _makeWithdrawal(context),
                    child: const Text('Make Withdrawal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
