import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';

class HostSeed {
  static Future<void> run() async {
    await _seedTerms();
    await _seedAdminUser();
  }

  static Future<void> _seedTerms() async {
    // Get device role
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      // HOST: Use Hive for storage
      final termsBox = Hive.box<Terms>('terms');

      // Check if terms box already has data
      if (termsBox.isNotEmpty) {
        // Search for an open term
        var openedTerms =
            termsBox.values.where((term) => term.status == 'Opened');
        Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

        if (openedTerm != null) {
          globalTermId ??= openedTerm.termId;
        } else {
          print("⚠️ Host: Terms exist but none are 'Opened'");
          globalTermId ??= termsBox.values.last.termId;
        }
        return;
      }

      // Create default term on host
      await _createDefaultTermOnHost(termsBox);
    } else {
      // CLIENT: Completely bypass Hive - just fetch from server
      await _fetchAndAssignGlobalTermIdFromServer();
    }
  }

// Host-only: Creates default term and saves to local Hive
  static Future<void> _createDefaultTermOnHost(Box<Terms> termsBox) async {
    const String defaultTermId = "TERM_DEFAULT_001";
    const String defaultTermName = "Default Term";
    const int id = 1;

    if (termsBox.isNotEmpty) {
      print("⚠️ Host: Terms already exist - skipping default term creation");
      return;
    }

    // Create the default term
    Terms defaultTerm = Terms(
      id: id,
      termId: defaultTermId,
      termName: defaultTermName,
      startDate: DateTime.now(),
      isActive: false,
      status: 'Opened',
      operationType: 'create',
      syncStatus: false,
      lastModified: DateTime.now(),
    );

    // Save to local Hive
    await termsBox.put(defaultTerm.termId, defaultTerm);
    globalTermId ??= defaultTermId;

    print(
        "✅ Host: Default term created and saved locally with ID: $defaultTermId");
  }

// Client-only: Fetch all terms but only extract default term ID, don't save
  static Future<void> _fetchAndAssignGlobalTermIdFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final url = Uri.parse('http://$hostIp:8080/api/terms');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final List<dynamic> termsJson =
            jsonDecode(await response.transform(utf8.decoder).join());

        if (termsJson.isNotEmpty) {
          // SAME LOGIC AS HOST: Search for an open term
          Map<String, dynamic>? openedTerm;

          for (var termData in termsJson) {
            if (termData['status'] == 'Opened') {
              openedTerm = termData;
              break;
            }
          }

          // If found, assign its termId to globalTermId
          if (openedTerm != null) {
            globalTermId = openedTerm['termId'];
            print(
                "✅ Client: Global term ID assigned from server (Opened term): $globalTermId");
          } else {
            // If no opened term found, take the first term (fallback)
            globalTermId = termsJson.last['termId'];
            print(
                "⚠️ Client: No opened term found - using first term: $globalTermId");
          }
        } else {
          print("⚠️ Client: No terms found on server");
          globalTermId = null;
        }
      } else {
        throw Exception('Failed to fetch terms: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Client Error fetching terms: $e");
      globalTermId = null;
    }
  }

  static Future<void> _seedAdminUser() async {
    final userBox = Hive.box<User>('users');

    final adminExists = userBox.values.any((u) => u.role == 'admin');
    if (adminExists) return;

    await userBox.add(
      User(
        id: 1,
        username: 'SUDOMANOadmin',
        password: 'SUDOMANO@codedatapool@admin',
        role: 'admin',
        userCode: 'admin',
        phone: '0773309607',
        termId: 'defaultTermId',
        securityQuestions: ['good day', 'good year', 'good bank'],
        securityAnswers: ['SUDOMANO', '1961', 'STEWARD'],
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'create',
      ),
    );
  }
}
