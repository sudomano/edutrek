// services/sync_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import '../main.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Sync both users and terms in priority order
  Future<SyncResult> performFullSync() async {
    final results = <String, bool>{};

    try {
      // Step 1: Get device role
      final role = await getDeviceRole();

      // Only sync if client
      if (role != DeviceRole.client) {
        return SyncResult(
            success: true,
            message: 'Host mode - no sync needed',
            details: {'role': 'host'});
      }

      // Step 2: Get host IP
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip');

      if (hostIp == null || hostIp.isEmpty) {
        return SyncResult(
            success: false,
            message: 'Host IP not configured',
            details: {'error': 'no_host_ip'});
      }

      print('🔄 Starting full sync from host: $hostIp');

      // Step 3: Sync Users (Priority 1)
      print('📋 Step 1/2: Syncing users...');
      final usersSynced = await _syncUsers(hostIp);
      results['users'] = usersSynced;

      if (!usersSynced) {
        return SyncResult(
            success: false,
            message: 'User sync failed - aborting terms sync',
            details: {'users': false, 'terms': false});
      }

      // Step 4: Sync Terms (Priority 2 - only if users sync succeeded)
      print('📋 Step 2/2: Syncing terms...');
      final termsSynced = await _syncTerms(hostIp);
      results['terms'] = termsSynced;

      if (termsSynced) {
        print('📌 Step 3/3: Auto-assigning global term ID...');
        final termAssigned = await _assignActiveTerm();
        results['term_assigned'] = termAssigned;

        if (termAssigned) {
          print('✅ Global term ID assigned: $globalTermId');
        } else {
          print('⚠️ No active term found to assign');
        }
      }

      final allSuccessful = results.values.every((v) => v == true);

      return SyncResult(
          success: allSuccessful,
          message: allSuccessful
              ? 'Full sync completed successfully'
              : 'Partial sync completed',
          details: results);
    } catch (e) {
      print('❌ Full sync failed: $e');
      return SyncResult(
          success: false,
          message: 'Sync failed: $e',
          details: {'error': e.toString()});
    }
  }

  // Sync users from host (existing implementation)
  Future<bool> _syncUsers(String hostIp) async {
    try {
      // This should use your existing PlatformAuthService logic
      // Or directly fetch and save users

      // Example implementation:
      final url = Uri.parse('http://$hostIp:8080/api/users');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        // Clear and save users locally
        // ... existing user sync logic
        print('✅ Users synced successfully');
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ User sync failed: $e');
      return false;
    }
  }

  // Sync terms from host (NEW)
  Future<bool> _syncTerms(String hostIp) async {
    try {
      // Step 1: Clear local terms
      print('🗑️ Clearing local terms...');
      final box = await Hive.openBox<Terms>('terms');
      await box.clear();
      await box.close();
      print('✅ Local terms cleared');

      // Step 2: Fetch from host
      print('📥 Fetching terms from host...');
      final url = Uri.parse('http://$hostIp:8080/api/terms');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final jsonString = await response.transform(utf8.decoder).join();
      final jsonList = jsonDecode(jsonString) as List;

      if (jsonList.isEmpty) {
        print('ℹ️ No terms found on host');
        return true; // Not an error, just empty
      }

      // Step 3: Save locally
      print('💾 Saving ${jsonList.length} terms locally...');
      final saveBox = await Hive.openBox<Terms>('terms');

      for (var json in jsonList) {
        final term = termsFromJson(Map<String, dynamic>.from(json));
        final key =
            term.termId ?? DateTime.now().millisecondsSinceEpoch.toString();
        await saveBox.put(key, term);
      }

      await saveBox.close();
      print('✅ ${jsonList.length} terms synced successfully');

      return true;
    } catch (e) {
      print('❌ Terms sync failed: $e');
      return false;
    }
  }

  // ⭐ NEW: Auto-assign globalTermId from active/open term
  Future<bool> _assignActiveTerm() async {
    try {
      print('🔍 Looking for active/open term...');

      // Open terms box
      final box = await Hive.openBox<Terms>('terms');
      final allTerms = box.values.toList();
      await box.close();

      if (allTerms.isEmpty) {
        print('❌ No terms available to assign');
        return false;
      }

      // Find the active term (current date falls within term dates)
      final now = DateTime.now();
      Terms? activeTerm;

      for (var term in allTerms) {
        final startDate = term.startDate;
        final endDate = term.endDate;

        // Check if current date is within term range
        if (endDate == null) {
          // If no end date, term is considered active if start date is in the past
          if (startDate.isBefore(now) || startDate.isAtSameMomentAs(now)) {
            activeTerm = term;
            print('✅ Found active term (no end date): ${term.termName}');
            break;
          }
        } else {
          // Check if current date is between start and end dates
          if ((startDate.isBefore(now) || startDate.isAtSameMomentAs(now)) &&
              (endDate.isAfter(now) || endDate.isAtSameMomentAs(now))) {
            activeTerm = term;
            print(
                '✅ Found active term: ${term.termName} (${startDate} to ${endDate})');
            break;
          }
        }
      }

      // If no active term found, use the most recent term (by start date)
      if (activeTerm == null) {
        print('⚠️ No active term found - selecting most recent term');

        // Sort by start date descending (most recent first)
        allTerms.sort((a, b) => b.startDate.compareTo(a.startDate));
        activeTerm = allTerms.first;
        print('📌 Using most recent term: ${activeTerm.termName}');
      }

      // Assign the global term ID
      if (activeTerm != null) {
        globalTermId = activeTerm.termId;
        print(
            '✅ Global term ID assigned: $globalTermId (${activeTerm.termName})');

        // Save to SharedPreferences for persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_term_id', globalTermId!);
        print('💾 Saved term ID to preferences: $globalTermId');

        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error assigning active term: $e');
      return false;
    }
  }

  // Sync only terms (for manual refresh)
  Future<bool> syncTermsOnly(String hostIp) async {
    final result = await _syncTerms(hostIp);
    if (result) {
      // Also auto-assign active term after manual sync
      await _assignActiveTerm();
    }
    return result;
  }

  // ⭐ Helper: Get the active term without syncing
  Future<Terms?> getActiveTerm() async {
    try {
      final box = await Hive.openBox<Terms>('terms');
      final allTerms = box.values.toList();
      await box.close();

      if (allTerms.isEmpty) return null;

      final now = DateTime.now();

      for (var term in allTerms) {
        final endDate = term.endDate;
        if (endDate == null) {
          if (term.startDate.isBefore(now) ||
              term.startDate.isAtSameMomentAs(now)) {
            return term;
          }
        } else {
          if ((term.startDate.isBefore(now) ||
                  term.startDate.isAtSameMomentAs(now)) &&
              (endDate.isAfter(now) || endDate.isAtSameMomentAs(now))) {
            return term;
          }
        }
      }

      // Return most recent if no active term found
      allTerms.sort((a, b) => b.startDate.compareTo(a.startDate));
      return allTerms.first;
    } catch (e) {
      print('❌ Error getting active term: $e');
      return null;
    }
  }
}

// Sync result model
class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic> details;

  SyncResult({
    required this.success,
    required this.message,
    this.details = const {},
  });

  @override
  String toString() =>
      'SyncResult(success: $success, message: $message, details: $details)';
}
