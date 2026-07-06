import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:http/http.dart' as http;

class CreateSchool extends StatefulWidget {
  const CreateSchool({super.key});

  @override
  _CreateSchoolState createState() => _CreateSchoolState();
}

class _CreateSchoolState extends State<CreateSchool> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _schoolPhoneNumberController = TextEditingController();
  final _schoolEmailController = TextEditingController();
  DeviceRole? _role;
  String? _hostIp;

  String? _schoolLogoPath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final bool isHost = _role == DeviceRole.host;

    return CenteredFormContainer(
      title: 'New School',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // ✅ Role indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                          ? '🔑 Host Mode - School will be created locally'
                          : 'ℹ️ Client Mode - School will be sent to host for creation',
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

            _buildTextField('School Name', _schoolNameController),
            const SizedBox(height: 16),
            _buildTextField('School Address', _schoolAddressController),
            const SizedBox(height: 16),
            _buildTextField(
                'School Phone Number', _schoolPhoneNumberController),
            const SizedBox(height: 16),
            _buildTextField('School Email', _schoolEmailController),
            const SizedBox(height: 16),

            // Logo picker
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Pick School Logo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
              ),
            ),
            if (_schoolLogoPath != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Logo: ${path.basename(_schoolLogoPath!)}',
                        style: const TextStyle(color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ✅ Submit Button with loading state
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
                    : const Text('Create School',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        String filePath = result.files.single.path!;
        Directory appDirectory = await _getAppDirectory();
        String fileName = path.basename(filePath);
        String newFilePath = path.join(appDirectory.path, fileName);

        File pickedFile = File(filePath);
        await pickedFile.copy(newFilePath);

        setState(() {
          _schoolLogoPath = newFilePath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Logo image selected!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Could not pick image: $e')),
      );
    }
  }

  Future<Directory> _getAppDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      return await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final newPkValue = uuid.v4();
      final prefs = await SharedPreferences.getInstance();

      final schoolName = _schoolNameController.text.trim();
      final schoolAddress = _schoolAddressController.text.trim();
      final schoolPhoneNumber = _schoolPhoneNumberController.text.trim();
      final schoolEmail = _schoolEmailController.text.trim();
      final schoolCode = newPkValue;
      int newId = await getNextId();

      List<String> modifiedFields = [
        'schoolName',
        'schoolAddress',
        'schoolPhoneNumber',
        'schoolEmail',
        'termId',
        'id',
        'schoolCode',
        'schoolLogoPath'
      ];

      if (_role == null) {
        await _showDialog("⚠️ Device role not configured. Cannot proceed.");
        return;
      }

      if (_role == DeviceRole.client) {
        // ✅ Client mode: Send to host
        final schoolToSend = {
          "id": newId,
          "schoolName": schoolName.toLowerCase(),
          "schoolCode": schoolCode,
          "schoolAddress": schoolAddress,
          "schoolPhoneNumber": schoolPhoneNumber,
          "schoolEmail": schoolEmail,
          "termId": globalTermId,
          "schoolLogoPath": _schoolLogoPath,
          "syncStatus": false,
          "lastModified": DateTime.now().toIso8601String(),
          "operationType": "create",
          // ✅ Deletion fields - new school is not deleted
          "isDeleted": false,
          "deletedSyncStatus": true,
          "modifiedFields": modifiedFields,
        };

        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
        final uri = Uri.parse('http://$hostIp:8080/api/school/bulk');

        try {
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "schools": [schoolToSend]
            }),
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            final List<dynamic> feedback = responseData['feedback'] ?? [];
            int insertedCount = responseData['insertedCount'] ?? 0;

            // ✅ Also save locally on client for offline access
            final box = await Hive.openBox<School>('school');
            final newSchool = School(
              id: newId,
              schoolName: schoolName.toLowerCase(),
              schoolCode: schoolCode,
              schoolAddress: schoolAddress,
              schoolPhoneNumber: schoolPhoneNumber,
              schoolEmail: schoolEmail,
              termId: globalTermId,
              syncStatus: true, // Already sent to server
              lastModified: DateTime.now(),
              operationType: 'none',
              schoolLogoPath: _schoolLogoPath,
              modifiedFields: modifiedFields,
              // ✅ Deletion fields
              isDeleted: false,
              deletedSyncStatus: true,
            );
            await box.add(newSchool);

            if (feedback.isEmpty) {
              await _showDialog("⚠️ No feedback received from host.");
              return;
            }

            StringBuffer resultBuffer = StringBuffer();
            for (var entry in feedback) {
              final code = entry['schoolCode'] ?? 'unknown';
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
              builder: (ctx) => AlertDialog(
                title: const Text("🧾 School Submission Feedback"),
                content: SingleChildScrollView(
                  child: Text(resultBuffer.toString()),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("OK"),
                  ),
                ],
              ),
            );

            if (insertedCount > 0) {
              Navigator.pop(context);
            }
          } else {
            await _showDialog("❌ Host rejected School info: ${response.body}");
          }
        } catch (e) {
          await _showDialog("❌ Failed to send school info to host.");
          print("School info send error: $e");
        }
      }

      if (_role == DeviceRole.host) {
        // ✅ Host mode: Save locally
        final box = await Hive.openBox<School>('school');
        if (box.isNotEmpty) {
          await _showDialog(
              'Only One School Is Allowed For This System. You Can Now Only Update!');
          return;
        }

        final existingSchools = box.values.where(
          (s) => s.schoolName?.toLowerCase() == schoolName.toLowerCase(),
        );
        School? existingSchool =
            existingSchools.isNotEmpty ? existingSchools.first : null;

        if (existingSchool != null) {
          await _showDialog('School already exists');
          return;
        }

        final newSchool = School(
          id: newId,
          schoolName: schoolName.toLowerCase(),
          schoolCode: schoolCode,
          schoolAddress: schoolAddress,
          schoolPhoneNumber: schoolPhoneNumber,
          schoolEmail: schoolEmail,
          termId: globalTermId,
          syncStatus: false,
          lastModified: DateTime.now(),
          operationType: 'create',
          schoolLogoPath: _schoolLogoPath,
          modifiedFields: modifiedFields,
          // ✅ Deletion fields
          isDeleted: false,
          deletedSyncStatus: true,
        );

        await box.add(newSchool);
        await _showDialog('School Added Successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      await _showDialog('Error creating school: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _schoolPhoneNumberController.dispose();
    _schoolEmailController.dispose();
    super.dispose();
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 School Submission Feedback"),
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

  Future<int> getNextId() async {
    final box = await Hive.openBox<School>('school');
    final activeSchools =
        box.values.where((s) => !(s.isDeleted ?? false)).toList();
    if (activeSchools.isEmpty) return 1;

    int currentMaxId = activeSchools
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }
}
