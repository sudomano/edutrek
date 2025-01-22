import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class SearchTeacherPaymentPurposeScreen extends StatefulWidget {
  const SearchTeacherPaymentPurposeScreen({super.key});

  @override
  _SearchTeacherPaymentPurposeScreenState createState() =>
      _SearchTeacherPaymentPurposeScreenState();
}

class _SearchTeacherPaymentPurposeScreenState
    extends State<SearchTeacherPaymentPurposeScreen> {
  final _searchController = TextEditingController();
  List<TeacherPaymentsPurposes> _results = [];

  void _search() {
    final box = Hive.box<TeacherPaymentsPurposes>('teacher_payments_purposes');
    final searchTerm = _searchController.text.toLowerCase();

    _results = box.values
        .where((pp) =>
            pp.paymentPurpose
                .toLowerCase()
                .contains(searchTerm.toLowerCase()) &&
            pp.termId == globalTermId)
        .toList();

    setState(() {}); // Update the UI with the search results
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Search Staff Payment Purposes'),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Staff Payment Purpose',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final purpose = _results[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(purpose.paymentPurpose),
                          subtitle: Text('Amount: ${purpose.purposeAmount}'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
