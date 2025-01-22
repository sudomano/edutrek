import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class PaymentPuposesSync extends StatefulWidget {
  const PaymentPuposesSync({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<PaymentPuposesSync> {
  Box<PaymentPurpose>? _payment_purposesBox;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _payment_purposesBox =
        await Hive.openBox<PaymentPurpose>('payment_purposes');
    print('Hive box opened successfully.');
  }

  // Helper function to decode string to List<String>
  List<String> _decodeToList(dynamic value) {
    if (value is String) {
      // If it's a string, try to decode it as JSON
      try {
        return List<String>.from(jsonDecode(value));
      } catch (e) {
        print('Error decoding string to List: $e');
        return [];
      }
    } else if (value is List) {
      // If it's already a list, return it directly
      return List<String>.from(value);
    }
    return [];
  }

  Future<void> _fetchAndSyncPurposes() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/student_payment_purpose_api.php';

    try {
      // Fetch data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> purposes = jsonDecode(response.body);

        for (var purposeData in purposes) {
          PaymentPurpose fetchedPurpose = PaymentPurpose(
            id: int.tryParse(purposeData['fid'] ?? '0') ?? 0,
            paymentPurpose: purposeData['paymentPurpose'] ?? '',
            purposeAmount: purposeData['purposeAmount'] != null
                ? double.tryParse(purposeData['purposeAmount'].toString()) ??
                    0.0
                : 0.0,
            purposeCode: purposeData['purposeCode'],
            associatedClasses: _decodeToList(purposeData['associatedClasses']),
            termId: purposeData['termId'],
          );

          // Check if the record exists in Hive using schoolCode
          var existingPurposeList = _payment_purposesBox!.values
              .where(
                (purposes) =>
                    purposes.purposeCode == fetchedPurpose.purposeCode,
              )
              .toList();

          PaymentPurpose? existingPurposes =
              existingPurposeList.isNotEmpty ? existingPurposeList.first : null;
          if (fetchedPurpose.purposeCode != null) {
            if (existingPurposes != null) {
              // Update existing record
              existingPurposes
                ..id = fetchedPurpose.id
                ..purposeCode = fetchedPurpose.purposeCode
                ..paymentPurpose = fetchedPurpose.paymentPurpose
                ..purposeAmount = fetchedPurpose.purposeAmount
                ..associatedClasses = fetchedPurpose.associatedClasses
                ..termId = fetchedPurpose.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now();
              await existingPurposes.save();
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} updated successfully in Hive.');
            } else {
              // Create a new record
              await _payment_purposesBox!.add(fetchedPurpose);
              print(
                  'PaymentPurpose ${fetchedPurpose.purposeCode} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Another Student PaymentPurpose record was Found with no Purpose Code  and was Skipped.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch PaymentPurpose from the server. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching or syncing PaymentPurpose: $e');
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
        title: const Center(child: Text('Fetch and Save PaymentPurpose')),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (admin || secretary || accountant || subadmin)
              await _fetchAndSyncPurposes();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('PaymentPurpose data Saved successfully.'),
            ));
          },
          child: const Text('Fetch and Save PaymentPurpose'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
