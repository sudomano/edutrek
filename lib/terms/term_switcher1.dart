import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart'; // Importing the global term id

class TermSwitcher1 extends StatefulWidget {
  @override
  _TermSwitcherState createState() => _TermSwitcherState();
}

class _TermSwitcherState extends State<TermSwitcher1> {
  final TextEditingController _searchController = TextEditingController();
  late Box<Terms> termsBox;
  List<Terms> _termsList = [];
  List<Terms> _filteredTermsList = [];
  String? _selectedTermId;
  Terms? _currentTerm;

  @override
  void initState() {
    super.initState();
    termsBox = Hive.box<Terms>('terms');
    _fetchTerms();
    _loadCurrentTerm();
  }

  void _fetchTerms() {
    setState(() {
      _termsList = termsBox.values.toList();
      _filteredTermsList = _termsList;
      _loadCurrentTerm(); // Call this after the terms are fetched
    });
  }

  void _filterTerms(String searchQuery) {
    setState(() {
      _filteredTermsList = _termsList
          .where((term) =>
              term.termName.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    });
  }

  // Load the current term by checking if any term matches the globalTermId
  void _loadCurrentTerm() {
    print("Loading current term... Global Term ID: $globalTermId");
    if (globalTermId != null) {
      setState(() {
        var matchingTerms =
            _termsList.where((term) => term.termId == globalTermId).toList();
        print("Matching terms found: ${matchingTerms.length}");
        _currentTerm = matchingTerms.isNotEmpty ? matchingTerms.first : null;
      });
    }
  }

  // This is triggered when a term is selected from the list
  void _selectTerm(Terms term) {
    setState(() {
      _selectedTermId = term.termId;

      // Debug line: Showing globalTermId before switching
      print("globalTermId before switching: $globalTermId");

      // Update the global term ID
      globalTermId = _selectedTermId;

      // Debug line: Showing globalTermId after switching
      print("globalTermId after switching: $globalTermId");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text('Switch Terms')),
        backgroundColor: Color.fromARGB(255, 235, 236, 237),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE3F2FD),
              Color.fromARGB(255, 248, 248, 248),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCurrentTermInfo(),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 20),
            Expanded(
              child: _buildTermsList(),
            ),
            const SizedBox(height: 20),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTermInfo() {
    if (_currentTerm == null) {
      return const Text(
        'No current term selected.',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Term:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Term Name: ${_currentTerm!.termName}'),
          Text(
              'Start Date: ${_currentTerm!.startDate.toLocal().toString().split(' ')[0]}'),
          Text(
              'End Date: ${_currentTerm!.endDate?.toLocal().toString().split(' ')[0] ?? 'N/A'}'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search terms...',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onChanged: _filterTerms,
    );
  }

  Widget _buildTermsList() {
    if (_filteredTermsList.isEmpty) {
      return const Center(
        child: Text('No terms found.'),
      );
    }

    return ListView.builder(
      itemCount: _filteredTermsList.length,
      itemBuilder: (context, index) {
        final term = _filteredTermsList[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            title: Text(
              term.termName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Start: ${term.startDate.toLocal().toString().split(' ')[0]}'),
                Text(
                    'End: ${term.endDate?.toLocal().toString().split(' ')[0] ?? 'N/A'}'),
              ],
            ),
            trailing: _selectedTermId == term.termId
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () => _selectTerm(term),
          ),
        );
      },
    );
  }

  Widget _buildConfirmButton() {
    return ElevatedButton(
      onPressed: () {
        if (_selectedTermId != null) {
          // Debug line: Showing globalTermId before confirmation
          print("globalTermId before confirmation: $globalTermId");

          // Update the global term ID
          globalTermId = _selectedTermId;

          // Debug line: Showing globalTermId after confirmation
          print("globalTermId after confirmation: $globalTermId");

          _loadCurrentTerm();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Global Term ID updated to $_selectedTermId')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No term selected')),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: const Color.fromARGB(255, 12, 12, 12),
        backgroundColor: Color.fromARGB(255, 227, 230, 235),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Text('Confirm Term Selection'),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
