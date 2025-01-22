import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';

class SyncTermsPages extends StatefulWidget {
  const SyncTermsPages({Key? key}) : super(key: key);

  @override
  _SyncSchoolsPageState createState() => _SyncSchoolsPageState();
}

class _SyncSchoolsPageState extends State<SyncTermsPages> {
  Box<Terms>? _termsBox;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _openHiveBox();
  }

  Future<void> _openHiveBox() async {
    _termsBox = await Hive.openBox<Terms>('terms');
    debugPrint('Hive box opened successfully.');
  }

  Future<void> _fetchAndSyncTerms() async {
    const String apiUrl =
        'http://thando.co.zw/api_school_management_system/php_codes_for_a_restful_api/terms_information_api.php';

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200 || response.statusCode == 201) {
        List<dynamic> terms = jsonDecode(response.body);

        for (var termsData in terms) {
          DateTime parsedStartDate =
              DateTime.tryParse(termsData['startDate'] ?? '') ?? DateTime.now();
          DateTime? parsedEndDate = termsData['endDate'] != null
              ? DateTime.tryParse(termsData['endDate'])
              : null;
          String statuses;
          bool isactive = termsData['isActive'];

          if (isactive == false) {
            statuses = 'Closed';
          } else {
            statuses = 'Opened';
          }
          print(statuses);
          Terms fetchedTerms = Terms(
            id: int.tryParse(termsData['fid'] ?? '0'),
            termName: termsData['termName'],
            startDate: parsedStartDate,
            endDate: parsedEndDate,
            isActive: termsData['isActive'] == true,
            status: statuses,
            termId: termsData['termId'],
          );

          var existingTermsList = _termsBox!.values
              .where(
                (school) => school.termId == fetchedTerms.termId,
              )
              .toList();

          Terms? existingTerms =
              existingTermsList.isNotEmpty ? existingTermsList.first : null;

          if (fetchedTerms.termId != null) {
            if (existingTerms != null) {
              // Update existing record
              existingTerms
                ..termName = fetchedTerms.termName
                ..startDate = fetchedTerms.startDate
                ..endDate = fetchedTerms.endDate
                ..isActive = fetchedTerms.isActive
                ..status = fetchedTerms.status
                ..termId = fetchedTerms.termId
                ..syncStatus = true
                ..operationType = 'none'
                ..lastModified = DateTime.now()
                ..id = fetchedTerms.id;

              await existingTerms.save();
              debugPrint(
                  'Terms ${fetchedTerms.termId} updated successfully in Hive.');
            } else {
              // Create a new record
              await _termsBox!.add(fetchedTerms);
              debugPrint(
                  'Terms ${fetchedTerms.termId} added successfully to Hive.');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Skipped a term record without a term ID.'),
            ));
          }
        }
      } else {
        throw Exception(
            'Failed to fetch terms. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing terms: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching terms: $e'),
      ));
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  bool _hasAccess() {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser?.role.toLowerCase() ?? '';
    return ['admin', 'secretary', 'teacher', 'accountant', 'sub-admin']
        .contains(role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Fetch and Save Terms')),
      ),
      body: Center(
        child: _isSyncing
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: () async {
                  if (_hasAccess()) {
                    await _fetchAndSyncTerms();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Terms data synced successfully.'),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('You do not have permission to sync terms.'),
                    ));
                  }
                },
                child: const Text('Fetch and Save Terms'),
              ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
