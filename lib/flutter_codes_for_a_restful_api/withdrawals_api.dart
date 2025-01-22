import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for Withdrawal
class Withdrawal {
  final int id;
  final String date;
  final double amount;
  final String withdrawalPurpose;
  final int? termId;

  Withdrawal({
    required this.id,
    required this.date,
    required this.amount,
    required this.withdrawalPurpose,
    this.termId,
  });

  // Factory method to create a Withdrawal object from JSON
  factory Withdrawal.fromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: json['id'],
      date: json['date'],
      amount: json['amount'],
      withdrawalPurpose: json['withdrawalPurpose'],
      termId: json['termId'],
    );
  }

  // Method to convert Withdrawal object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'withdrawalPurpose': withdrawalPurpose,
      'termId': termId,
    };
  }
}

// API URL
const String apiUrl =
    'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/withdrawals';

// Function to fetch withdrawals from the API
Future<List<Withdrawal>> fetchWithdrawals() async {
  final response = await http.get(Uri.parse(apiUrl));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Withdrawal.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load withdrawals');
  }
}

// Function to fetch a specific withdrawal by ID
Future<Withdrawal> fetchWithdrawalById(int id) async {
  final response = await http.get(Uri.parse('$apiUrl/$id'));

  if (response.statusCode == 200) {
    return Withdrawal.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to load withdrawal');
  }
}

// Function to create a new withdrawal in the API
Future<void> createWithdrawal(Withdrawal newWithdrawal) async {
  final response = await http.post(
    Uri.parse(apiUrl),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newWithdrawal.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create withdrawal');
  }
}

// Function to update an existing withdrawal in the API
Future<void> updateWithdrawal(Withdrawal updatedWithdrawal) async {
  final response = await http.put(
    Uri.parse('$apiUrl/${updatedWithdrawal.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedWithdrawal.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update withdrawal');
  }
}

// Function to delete a withdrawal from the API
Future<void> deleteWithdrawal(int id) async {
  final response = await http.delete(
    Uri.parse('$apiUrl/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete withdrawal');
  }
}

// Function to update local Hive database with fetched withdrawals
Future<void> updateHiveWithFetchedWithdrawals(
    List<Withdrawal> withdrawals) async {
  var box = await Hive.openBox<Withdrawal>('withdrawalsBox');

  for (var withdrawal in withdrawals) {
    await box.put(withdrawal.id, withdrawal);
  }

  await box.close();
}

// Example usage: Sync data between API and Hive
Future<void> syncWithdrawals() async {
  try {
    // Fetch withdrawals from API
    List<Withdrawal> withdrawals = await fetchWithdrawals();

    // Update local Hive database with fetched withdrawals
    await updateHiveWithFetchedWithdrawals(withdrawals);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new withdrawal and sync with API
Future<void> addNewWithdrawal(Withdrawal newWithdrawal) async {
  try {
    // Create a new withdrawal in the API
    await createWithdrawal(newWithdrawal);

    // Optionally, fetch the updated list of withdrawals
    await syncWithdrawals();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update withdrawal locally and sync with API
Future<void> updateWithdrawalLocally(Withdrawal updatedWithdrawal) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<Withdrawal>('withdrawalsBox');

    // Update withdrawal in Hive
    await box.put(updatedWithdrawal.id, updatedWithdrawal);

    // Send the updated withdrawal to API
    await updateWithdrawal(updatedWithdrawal);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a withdrawal and sync with API
Future<void> deleteWithdrawalLocally(int id) async {
  try {
    // Delete the withdrawal from API
    await deleteWithdrawal(id);

    // Optionally, fetch the updated list of withdrawals
    await syncWithdrawals();
  } catch (e) {
    print('Error: $e');
  }
}
