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
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
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
  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];
  DeviceRole? _role;
  String? _hostIp;
  bool _isSubmitting = false;

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
      _role ??= await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termsBox = await Hive.openBox<Terms>('terms');
        // ✅ Only load active (non-deleted) terms
        allTerms =
            termsBox.values.where((t) => !(t.isDeleted ?? false)).toList();
      } else {
        if (_hostIp == null || _hostIp!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("⚠️ Host IP not set. Please configure connection.")),
          );
          return;
        }

        if (_cachedServerTerms == null) {
          // ✅ Include deleted terms flag to filter on client
          final url =
              Uri.parse('http://$_hostIp:8080/api/terms?include_deleted=true');
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final List<dynamic> termsJson = jsonDecode(response.body);
            _cachedServerTerms = termsJson
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception(
                "Failed to load terms from host (status ${response.statusCode}).");
          }
        }
        // ✅ Only load active (non-deleted) terms
        allTerms =
            _cachedServerTerms!.where((t) => !(t.isDeleted ?? false)).toList();
      }

      setState(() {
        _availableTerms = allTerms.map((term) => term.termId).toSet().toList();
        _selectedTerms = List.from(_availableTerms);
        _termsMap = {for (var t in allTerms) t.termId: t};
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
        allTerms =
            termBox.values.where((t) => !(t.isDeleted ?? false)).toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerTerms == null) {
          final termsResponse = await http.get(
              Uri.parse('http://$_hostIp:8080/api/terms?include_deleted=true'));

          if (termsResponse.statusCode == 200) {
            final termsList = jsonDecode(termsResponse.body) as List;
            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }
        }
        allTerms =
            _cachedServerTerms!.where((t) => !(t.isDeleted ?? false)).toList();
      }

      if (allTerms.isNotEmpty) {
        _availableTerms = allTerms.map((term) => term.termId).toSet().toList();
        _termsMap = {for (var t in allTerms) t.termId: t};
      } else {
        _availableTerms = [];
        _termsMap = {};
      }

      setState(() {});
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = _role == DeviceRole.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Class'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        foregroundColor: Colors.white,
        elevation: 4.0,
        actions: [
          // ✅ Role indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isHost ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isHost ? 'HOST' : 'CLIENT',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: CenteredFormContainer(
        title: 'Create Classes',
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Status indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isHost ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isHost ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isHost ? Icons.check_circle : Icons.info_outline,
                      color: isHost ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHost
                            ? '🔑 Host Mode - Class will be created locally'
                            : 'ℹ️ Client Mode - Class will be sent to host',
                        style: TextStyle(
                          color: isHost
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField('Class Name (required)', _classNameController),
              const SizedBox(height: 16),
              const Center(
                child: Text('Select Terms (optional)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTermSelection(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 38, 140, 191),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Class',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
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
        filled: true,
        fillColor: Colors.white,
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
    // ✅ Only count non-deleted classes
    final activeClasses =
        box.values.where((c) => !(c.isDeleted ?? false)).toList();
    if (activeClasses.isEmpty) return 1;

    int currentMaxId = activeClasses
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

      setState(() => _isSubmitting = true);

      try {
        final prefs = await SharedPreferences.getInstance();
        final _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
        final newPkValue = uuid.v4();
        final className = _classNameController.text.trim();
        final classCode = newPkValue;

        final box = await Hive.openBox<Classes>('classes');
        // ✅ Only check non-deleted classes
        final existingClass = box.values
            .where((c) => !(c.isDeleted ?? false))
            .cast<Classes>()
            .firstWhere(
              (c) => (c.className.toLowerCase() == className.toLowerCase() ||
                  (c.classCode?.toLowerCase() == classCode.toLowerCase())),
              orElse: () =>
                  Classes(id: -1, className: '', date: DateTime(1970)),
            );

        if (existingClass.id != -1) {
          _showDialog('Class already exists');
          setState(() => _isSubmitting = false);
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

        if (_role == null) {
          await _showDialog("⚠️ Device role not configured. Cannot proceed.");
          setState(() => _isSubmitting = false);
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
            "terms": termsToSave,
            "syncStatus": false,
            "lastModified": DateTime.now().toIso8601String(),
            "operationType": "create",
            "modifiedFields": modifiedFields,
            // ✅ Deletion fields - new class is not deleted
            "isDeleted": false,
            "deletedSyncStatus": true,
          });

          final uri = Uri.parse('http://$_hostIp:8080/api/classes/bulk');

          try {
            final response = await http.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({"classes": classToSend}),
            );

            if (response.statusCode == 200) {
              // ✅ Also save locally on client
              final newClass = Classes(
                id: newId,
                className: toBeginningOfSentenceCase(className),
                classCode: classCode,
                date: DateTime.now(),
                termId: globalTermId,
                syncStatus: true,
                lastModified: DateTime.now(),
                operationType: 'none',
                modifiedFields: modifiedFields,
                terms: termsToSave,
                isDeleted: false,
                deletedSyncStatus: true,
              );
              await box.add(newClass);

              final Map<String, dynamic> responseData =
                  jsonDecode(response.body);
              final List<dynamic> feedback = responseData['feedback'] ?? [];
              int insertedCount = responseData['insertedCount'] ?? 0;

              if (feedback.isEmpty) {
                await _showDialog("⚠️ No feedback received from host.");
                setState(() => _isSubmitting = false);
                return;
              }

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
          // ✅ Check duplicate by name or code (excluding deleted)
          final existingClass = box.values
              .where((c) => !(c.isDeleted ?? false))
              .firstWhere(
                (c) => (c.className.toLowerCase() == className.toLowerCase() ||
                    (c.classCode?.toLowerCase() == classCode.toLowerCase())),
                orElse: () =>
                    Classes(id: -1, className: '', date: DateTime(1970)),
              );

          if (existingClass.id != -1) {
            await _showDialog('Class already exists');
            setState(() => _isSubmitting = false);
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
            isDeleted: false,
            deletedSyncStatus: true,
          );

          await box.add(newClass);

          await _showDialog('Class Added Successfully');
          _classNameController.clear();
          Navigator.pop(context);
        }
      } catch (e) {
        await _showDialog('Error creating class: $e');
      } finally {
        setState(() => _isSubmitting = false);
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
