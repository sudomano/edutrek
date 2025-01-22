import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class SearchPaymentPurposeScreen extends StatefulWidget {
  const SearchPaymentPurposeScreen({super.key});

  @override
  _SearchPaymentPurposeScreenState createState() =>
      _SearchPaymentPurposeScreenState();
}

class _SearchPaymentPurposeScreenState
    extends State<SearchPaymentPurposeScreen> {
  final _searchController = TextEditingController();
  List<PaymentPurpose> _results = [];

  void _search() {
    final box = Hive.box<PaymentPurpose>('payment_purposes');
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
      appBar: AppBar(
        title: Center(child: const Text('Search Payment Purpose')),
        backgroundColor: const Color.fromARGB(
            255, 240, 252, 240), // Set app bar background color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Payment Purpose',
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
                      subtitle: Text(
                          'Amount: ${purpose.purposeAmount}\n School Term: ${purpose.termId}'),
                    ),
                  );
                },
              ),
            ),
          ],
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
