import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class SearchClassScreen extends StatefulWidget {
  const SearchClassScreen({super.key});

  String capitalize(String value) {
    var result = value[0].toUpperCase();
    for (int i = 1; i < value.length; i++) {
      if (value[i - 1] == " ") {
        result = result + value[i].toUpperCase();
      } else {
        result = result + value[i];
      }
    }
    return result;
  }

  @override
  _SearchClassScreenState createState() => _SearchClassScreenState();
}

class _SearchClassScreenState extends State<SearchClassScreen> {
  final _searchController = TextEditingController();
  List<Classes> _results = [];

  void _search() {
    final box = Hive.box<Classes>('classes');
    final searchTerm = _searchController.text.toLowerCase();

    // Filter by globalTermId and search term
    _results = box.values
        .where((pp) =>
            pp.className.toLowerCase().contains(searchTerm) &&
            pp.termId != null)
        .toList();
    _results.sort((a, b) => a.className.compareTo(b.className));

    setState(() {}); // Update the UI with the search results
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Search Classes'),
      backgroundColor: const Color.fromARGB(255, 246, 248, 248),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Class',
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
                      final classes = _results[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(classes.className),
                          subtitle: Text('Date: ${classes.date}'),
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
