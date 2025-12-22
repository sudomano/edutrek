// Helper function to decode string to List<String>
import 'dart:convert';

List<String> decodeToList(dynamic value) {
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
