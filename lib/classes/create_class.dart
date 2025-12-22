import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart'; // Replace 'your_app_name' with your actual app's name
import 'package:http/http.dart' as http;
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';

class CreateClass extends StatefulWidget {
  const CreateClass({super.key});

  @override
  _AddClass createState() => _AddClass();
}

class _AddClass extends State<CreateClass> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  // --- New: Variables for term selection ---
  List<String> _availableTerms = [];
  List<String> _selectedTerms = []; // Stores user-selected term IDs
  DeviceRole? _role;
  String? _hostIp;

  List<Terms>? _cachedServerTerms;
  Map<String, Terms> _termsMap = {};

  @override
  void initState() {
    super.initState();
    _loadTerms();
    fetchTerms();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = stringToDeviceRole(prefs.getString('device_role') ?? '');
      _hostIp = prefs.getString('host_ip');
    });
  }

  DeviceRole? stringToDeviceRole(String role) {
    switch (role) {
      case 'client':
        return DeviceRole.client;
      case 'host':
        return DeviceRole.host;
      default:
        return null;
    }
  }

  Future<void> _loadTerms() async {
    try {
      // Ensure role and host IP are loaded
      _role ??= await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        // ===== HOST MODE: Read from Hive =====
        final termsBox = await Hive.openBox<Terms>('terms');
        allTerms = termsBox.values.toList();
      } else {
        // ===== CLIENT MODE: Fetch from host =====
        if (_hostIp == null || _hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          return;
        }

        if (_cachedServerTerms == null) {
          final url = Uri.parse('http://$_hostIp:8080/api/terms');
          final response =
              await HttpClient().getUrl(url).then((req) => req.close());

          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final List<dynamic> termsJson = jsonDecode(body);
            _cachedServerTerms = termsJson
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception(
                "Failed to load terms from host (status ${response.statusCode}).");
          }
        }
        allTerms = _cachedServerTerms!;
      }

      // ===== Populate UI lists =====
      setState(() {
        _availableTerms = allTerms.map((term) => term.termId).toSet().toList();
        _selectedTerms = List.from(_availableTerms); // Default to all selected
        _termsMap = {for (var t in allTerms) t.termId: t}; // Quick lookup map
      });
    } catch (e) {
      debugPrint("Error loading terms: $e");
      setState(() {
        _availableTerms = [];
        _selectedTerms = [];
        _termsMap = {};
      });
    }
  }

  Future<void> fetchTerms() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termBox = await Hive.openBox<Terms>('terms');

        allTerms = termBox.values.toList();
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerTerms == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
      }

      if (allTerms.isNotEmpty) {
        _availableTerms = allTerms.map((term) => term.termId).toSet().toList();
        _termsMap = {for (var t in allTerms) t.termId: t}; // for quick lookup
      } else {
        _availableTerms = [];
        _termsMap = {};
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Create Classes',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('Class Name (required)', _classNameController),
            const SizedBox(height: 16),
            const Center(
              child: Text('Select Terms (optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTermSelection(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Create Class'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSelection() {
    return _availableTerms.isEmpty
        ? const Text('No terms available')
        : Column(
            children: _availableTerms.map((term) {
              return CheckboxListTile(
                title: Text(term),
                value: _selectedTerms.contains(term),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTerms.add(term);
                    } else {
                      _selectedTerms.remove(term);
                    }
                  });
                },
              );
            }).toList(),
          );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<Classes>('classes');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (globalTermId == null) {
        await _showDialog(
            'No Selected Term Was Found. Create A New Term or Switch Terms To An Existing One.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      final newPkValue = uuid.v4();
      final className = _classNameController.text;
      final classCode = newPkValue;

      final box = await Hive.openBox<Classes>('classes');
      final existingClass = box.values.cast<Classes>().firstWhere(
            (c) => (c.className.toLowerCase() == className.toLowerCase() ||
                (c.classCode?.toLowerCase() == classCode.toLowerCase())),
            orElse: () => Classes(id: -1, className: '', date: DateTime(1970)),
          );

      if (existingClass.id != -1) {
        _showDialog('Class already exists');
        return;
      }
      int newId = await getNextId();
      List<String> modifiedFields = [
        'id',
        'className',
        'classCode',
        'date',
        'termId',
        'terms'
      ];

      final List<String> termsToSave =
          _selectedTerms.isNotEmpty ? _selectedTerms : [globalTermId!];
      final String termsString = termsToSave.join(','); // ✅ Convert to String

      if (_role == null) {
        await _showDialog("⚠️ Device role not configured. Cannot proceed.");
        return;
      }

      // ================= CLIENT MODE =================
      if (_role == DeviceRole.client) {
        final classToSend = <Map<String, dynamic>>[];

        classToSend.add({
          "id": newId,
          "className": className,
          "classCode": classCode,
          "date": DateTime.now().toIso8601String(),
          "termId": globalTermId,
          "terms": termsToSave, // ✅ send as JSON array

          "syncStatus": false,
          "lastModified": DateTime.now().toIso8601String(),
          "operationType": "create",
          "modifiedFields": modifiedFields,
        });

        final uri = Uri.parse('http://$_hostIp:8080/api/classes/bulk');

        try {
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"classes": classToSend}),
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            final List<dynamic> feedback = responseData['feedback'] ?? [];
            int insertedCount = responseData['insertedCount'] ?? 0;

            if (feedback.isEmpty) {
              await _showDialog("⚠️ No feedback received from host.");
              return;
            }

            // Build feedback UI string
            StringBuffer resultBuffer = StringBuffer();
            for (var entry in feedback) {
              final code = entry['classCode'] ?? 'unknown';
              final status = entry['status'] ?? 'unknown';
              final message =
                  entry['message'] ?? entry['reason'] ?? 'No message';

              String icon = switch (status) {
                "success" => "✅",
                "skipped" => "⏭️",
                "failed" => "❌",
                _ => "🔹"
              };

              resultBuffer.writeln("$icon [$code]: $message");
            }

            await showDialog(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text("🧾 Class Submission Feedback"),
                  content: SingleChildScrollView(
                    child: Text(resultBuffer.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("OK"),
                    ),
                  ],
                );
              },
            );

            if (insertedCount > 0) {
              Navigator.pop(context);
            }
          } else {
            await _showDialog("❌ Host rejected Class info: ${response.body}");
          }
        } catch (e) {
          await _showDialog("❌ Failed to send class info to host.");
          print("class info send error: $e");
        }
      }

      // ================= HOST MODE =================
      if (_role == DeviceRole.host) {
        final box = await Hive.openBox<Classes>('classes');

        // Check duplicate by name or code
        final existingClass = box.values.firstWhere(
          (c) => (c.className.toLowerCase() == className.toLowerCase() ||
              (c.classCode?.toLowerCase() == classCode.toLowerCase())),
          orElse: () => Classes(id: -1, className: '', date: DateTime(1970)),
        );

        final parsedCode = int.tryParse(existingClass.classCode ?? '');
        if (parsedCode != null) {
          await _showDialog('Class already exists');
          return;
        }

        final newClass = Classes(
          id: newId,
          className: toBeginningOfSentenceCase(className),
          classCode: classCode,
          date: DateTime.now(),
          termId: globalTermId,
          syncStatus: false,
          lastModified: DateTime.now(),
          operationType: 'create',
          modifiedFields: modifiedFields,
          terms: termsToSave,
        );

        await box.add(newClass);

        await _showDialog('Class Added Successfully');
        _classNameController.clear();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Class Submission Feedback"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
  }
}
