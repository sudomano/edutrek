// global_files/global_term_id.dart
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/terms.dart';

String? globalTermId;

// Load last used term ID from preferences
Future<void> loadLastTermId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastTermId = prefs.getString('last_term_id');
    if (lastTermId != null) {
      globalTermId = lastTermId;
      print('📌 Loaded last term ID: $globalTermId');
    } else {
      print('ℹ️ No saved term ID found');
    }
  } catch (e) {
    print('⚠️ Failed to load last term ID: $e');
  }
}

// Save current term ID to preferences
Future<void> saveCurrentTermId(String? termId) async {
  if (termId == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_term_id', termId);
    print('💾 Saved term ID: $termId');
  } catch (e) {
    print('⚠️ Failed to save term ID: $e');
  }
}

// Clear current term ID
Future<void> clearCurrentTermId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_term_id');
    globalTermId = null;
    print('🗑️ Cleared term ID');
  } catch (e) {
    print('⚠️ Failed to clear term ID: $e');
  }
}

// Get the current term name (helper)
Future<String?> getCurrentTermName() async {
  if (globalTermId == null) return null;

  try {
    final box = await Hive.openBox<Terms>('terms');
    final term = box.values.firstWhere(
      (t) => t.termId == globalTermId,
      orElse: () => throw Exception('Term not found'),
    );
    await box.close();
    return term.termName;
  } catch (e) {
    print('⚠️ Error getting term name: $e');
    return null;
  }
}
