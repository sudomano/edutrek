import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class SyncWithdrawalsPages extends StatefulWidget {
  const SyncWithdrawalsPages({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<SyncWithdrawalsPages> {
  Box<Withdrawal>? _withdrawalsBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
    print('Hive box opened successfully.');
  }

  Future<void> _fetchAndSyncSchools() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/withdrawals_information.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> withdrawals = jsonDecode(response.body);

        for (var withdrawalData in withdrawals) {
          DateTime date =
              DateTime.tryParse(withdrawalData['date']) ?? DateTime.now();

          Withdrawal fetchedWthdrawals = Withdrawal(
            id: int.tryParse(withdrawalData['fid'] ?? '0'),
            amount: withdrawalData['amount'] != null
                ? double.tryParse(withdrawalData['amount'].toString()) ?? 0.0
                : 0.0,
            date: date,
            withdrawalPurpose: withdrawalData['withdrawalPurpose'],
            withdrawalCode: withdrawalData['withdrawalCode'],
            termId: withdrawalData['termId'],
          );

          // Check if the record exists in Hive using termId
          var existingWithdrawalsList = _withdrawalsBox!.values
              .where(
                (withdrawal) =>
                    withdrawal.withdrawalCode ==
                    fetchedWthdrawals.withdrawalCode,
              )
              .toList();

          Withdrawal? existingWithdrawals = existingWithdrawalsList.isNotEmpty
              ? existingWithdrawalsList.first
              : null;
          if (fetchedWthdrawals.withdrawalCode != null) {
            if (existingWithdrawals != null) {
              // Update existing record
              existingWithdrawals
                ..amount = fetchedWthdrawals.amount
                ..withdrawalPurpose = fetchedWthdrawals.withdrawalPurpose
                ..withdrawalCode = fetchedWthdrawals.withdrawalCode
                ..date = fetchedWthdrawals.date
                ..termId = fetchedWthdrawals.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedWthdrawals.id;

              await existingWithdrawals.save();
              print(
                  'Withdrawal ${fetchedWthdrawals.withdrawalCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _withdrawalsBox!.add(fetchedWthdrawals);
              print(
                  'Withdrawal ${fetchedWthdrawals.withdrawalCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Other Withdrawal  Record Was Found with no Withdrawal Code and was Skipped'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch withdrawals from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing withdrawals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final admin = loggedInUser?.role.toLowerCase() == 'admin';
    final secretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser?.role.toLowerCase() == 'teacher';

    final accountant = loggedInUser?.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser?.role.toLowerCase() == 'sub-admin';
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Fetch and Save Withdrawal')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || secretary || accountant || subadmin)
              await _fetchAndSyncSchools();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Withdrawal data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save Withdrawal'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
