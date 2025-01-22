import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

// Model class for PaymentPurpose
class PaymentPurpose {
  final int id;
  final String paymentPurpose;
  final double purposeAmount;
  final int? termId;

  PaymentPurpose({
    required this.id,
    required this.paymentPurpose,
    required this.purposeAmount,
    this.termId,
  });

  // Factory method to create a PaymentPurpose object from JSON
  factory PaymentPurpose.fromJson(Map<String, dynamic> json) {
    return PaymentPurpose(
      id: json['id'],
      paymentPurpose: json['paymentPurpose'],
      purposeAmount: json['purposeAmount'],
      termId: json['termId'],
    );
  }

  // Method to convert PaymentPurpose object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentPurpose': paymentPurpose,
      'purposeAmount': purposeAmount,
      'termId': termId,
    };
  }
}

// Function to fetch all payment purposes from the MySQL database via API
Future<List<PaymentPurpose>> fetchPaymentPurposes() async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/payment_purposes'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => PaymentPurpose.fromJson(data)).toList();
  } else {
    throw Exception('Failed to load payment purposes');
  }
}

// Function to fetch a specific payment purpose by ID from the MySQL database via API
Future<PaymentPurpose> fetchPaymentPurposeById(int id) async {
  final response = await http.get(Uri.parse(
      'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/payment_purposes/$id'));

  if (response.statusCode == 200) {
    return PaymentPurpose.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to load payment purpose');
  }
}

// Function to update local Hive database with fetched payment purposes
Future<void> updateHiveWithFetchedPaymentPurposes(
    List<PaymentPurpose> purposes) async {
  var box = await Hive.openBox<PaymentPurpose>('paymentPurposesBox');

  for (var purpose in purposes) {
    await box.put(purpose.id, purpose);
  }

  await box.close();
}

// Function to create a new payment purpose in MySQL
Future<void> createPaymentPurposeInMySQL(PaymentPurpose newPurpose) async {
  final response = await http.post(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/payment_purposes'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(newPurpose.toJson()),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create payment purpose');
  }
}

// Function to update a payment purpose in MySQL
Future<void> updatePaymentPurposeInMySQL(PaymentPurpose updatedPurpose) async {
  final response = await http.put(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/payment_purposes/${updatedPurpose.id}'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(updatedPurpose.toJson()),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update payment purpose');
  }
}

// Function to delete a payment purpose from MySQL
Future<void> deletePaymentPurposeFromMySQL(int id) async {
  final response = await http.delete(
    Uri.parse(
        'http://datapoolsolutions.great-site.net/api_school_management_system/php_codes_for_a_restful_api/payment_purposes/$id'),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete payment purpose');
  }
}

// Example usage: Sync data between MySQL and Hive
Future<void> syncPaymentPurposes() async {
  try {
    // Fetch payment purposes from MySQL
    List<PaymentPurpose> purposes = await fetchPaymentPurposes();

    // Update local Hive database with fetched payment purposes
    await updateHiveWithFetchedPaymentPurposes(purposes);
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Add a new payment purpose and sync with MySQL
Future<void> addNewPaymentPurpose(PaymentPurpose newPurpose) async {
  try {
    // Create a new payment purpose in MySQL
    await createPaymentPurposeInMySQL(newPurpose);

    // Optionally, fetch the updated list of payment purposes
    await syncPaymentPurposes();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Update payment purpose locally and sync with MySQL
Future<void> updatePaymentPurposeLocally(PaymentPurpose updatedPurpose) async {
  try {
    // Open Hive box
    var box = await Hive.openBox<PaymentPurpose>('paymentPurposesBox');

    // Update payment purpose in Hive
    await box.put(updatedPurpose.id, updatedPurpose);

    // Send the updated payment purpose to MySQL
    await updatePaymentPurposeInMySQL(updatedPurpose);

    await box.close();
  } catch (e) {
    print('Error: $e');
  }
}

// Example usage: Delete a payment purpose and sync with MySQL
Future<void> deletePaymentPurpose(int id) async {
  try {
    // Delete the payment purpose from MySQL
    await deletePaymentPurposeFromMySQL(id);

    // Optionally, fetch the updated list of payment purposes
    await syncPaymentPurposes();
  } catch (e) {
    print('Error: $e');
  }
}
