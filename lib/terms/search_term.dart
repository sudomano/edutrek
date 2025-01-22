import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class SearchTermScreen extends StatefulWidget {
  const SearchTermScreen({super.key});

  @override
  _SearchTermScreenState createState() => _SearchTermScreenState();
}

class _SearchTermScreenState extends State<SearchTermScreen> {
  final _searchController = TextEditingController();
  List<Terms> _results = [];

  void _search() {
    final box = Hive.box<Terms>('terms');
    final searchTerm = _searchController.text.toLowerCase();

    _results = box.values
        .where((term) => term.termId.toLowerCase().contains(searchTerm))
        .toList();
    _results.sort((a, b) => a.termId.compareTo(b.termId));

    setState(() {}); // Update the UI with the search results
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Search Terms'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Term',
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
                  final term = _results[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(term.termId),
                      subtitle: Text(
                          'Start Date: ${term.startDate}\nEnd Date: ${term.endDate}'),
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
