import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for Term
class Term {
  final String termId;
  final String termName;
  final String startDate;
  final String? endDate;
  final bool isActive;
  final String status;

  Term({
    required this.termId,
    required this.termName,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.status,
  });

  // Factory method to create a Term object from JSON
  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      termId: json['termId'],
      termName: json['termName'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      isActive: json['isActive'] == 1,
      status: json['status'],
    );
  }

  // Method to convert Term object to JSON
  Map<String, dynamic> toJson() {
    return {
      'termId': termId,
      'termName': termName,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive ? 1 : 0,
      'status': status,
    };
  }
}

// Function to fetch terms from the MySQL database via API
Future<List<Term>> fetchTerms() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/terms'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Term.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load terms');
  }
}

// Function to update local Hive database with fetched terms
Future<void> updateHiveWithFetchedTerms(List<Term> terms) async {
  var box = await Hive.openBox<Term>('termsBox');

  for (var term in terms) {
    await box.put(term.termId, term);
  }

  await box.close();
}

// Function to create a new term in MySQL
Future<void> createTermInMySQL(Term newTerm) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/terms'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newTerm.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create term');
  }
}

// Function to update a term in MySQL
Future<void> updateTermInMySQL(Term updatedTerm) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/terms/${updatedTerm.termId}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedTerm.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update term');
  }
}

// Function to delete a term from MySQL
Future<void> deleteTermFromMySQL(String termId) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/terms/$termId'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete term');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncTerms() async {
  try {
    // Fetch terms from MySQL
    List<Term> terms = await fetchTerms();

    // Update local Hive database with fetched terms
    await updateHiveWithFetchedTerms(terms);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new term and sync with MySQL
Future<void> addNewTerm(Term newTerm) async {
  try {
    // Create a new term in MySQL
    await createTermInMySQL(newTerm);

    // Optionally, fetch the updated list of terms
    await syncTerms();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update term locally and sync with MySQL
Future<void> updateTermLocally(Term updatedTerm) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<Term>('termsBox');

    // Update term in Hive
    await box.put(updatedTerm.termId, updatedTerm);

    // Send the updated term to MySQL
    await updateTermInMySQL(updatedTerm);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a term and sync with MySQL
Future<void> deleteTerm(String termId) async {
  try {
    // Delete the term from MySQL
    await deleteTermFromMySQL(termId);

    // Optionally, fetch the updated list of terms
    await syncTerms();
  } catch (e) {
    print('Error: $e');
  }
}
