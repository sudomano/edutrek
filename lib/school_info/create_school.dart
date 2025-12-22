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
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart'; // Import the School model
import 'package:path/path.dart' as path;
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart'; // For handling file paths

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

  String? _schoolLogoPath; // To store the selected image path

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
    return CenteredFormContainer(
      title: 'New School',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('School Name', _schoolNameController),
            const SizedBox(height: 16),
            _buildTextField('School Address', _schoolAddressController),
            const SizedBox(height: 16),
            _buildTextField(
                'School Phone Number', _schoolPhoneNumberController),
            const SizedBox(height: 16),
            _buildTextField('School Email', _schoolEmailController),
            ElevatedButton(
              onPressed: _pickImage, // Button to pick the logo image
              child: const Text('Pick School Logo'),
            ),
            const SizedBox(height: 16),
            if (_schoolLogoPath != null)
              Text(
                'Logo Selected: ${path.basename(_schoolLogoPath!)}',
                style: const TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Create School'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      // Open file picker to select an image
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        String filePath = result.files.single.path!;

        // Get the appropriate directory for saving the file
        Directory appDirectory = await _getAppDirectory();
        String fileName = path.basename(filePath);
        String newFilePath = path.join(appDirectory.path, fileName);

        // Copy the file to the app directory
        File pickedFile = File(filePath);
        await pickedFile.copy(newFilePath);

        setState(() {
          _schoolLogoPath = newFilePath; // Save the new file path
        });

        await _showDialog('Logo Image Selected!');
      }
    } catch (e) {
      await _showDialog('Could not pick image: $e');
    }
  }

  Future<Directory> _getAppDirectory() async {
    // Platform-specific logic to get the appropriate app directory
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
    if (_formKey.currentState!.validate()) {
      final newPkValue = uuid.v4();
      final prefs = await SharedPreferences.getInstance();

      final schoolName = _schoolNameController.text;
      final schoolAddress = _schoolAddressController.text;
      final schoolPhoneNumber = _schoolPhoneNumberController.text;
      final schoolEmail = _schoolEmailController.text;
      final schoolCode = newPkValue;
      int newId = await getNextId();

      List<String> modifiedFields = [];
      modifiedFields.add('schoolName');
      modifiedFields.add('schoolAddress');
      modifiedFields.add('schoolPhoneNumber');
      modifiedFields.add('schoolEmail');
      modifiedFields.add('termId');
      modifiedFields.add('id');
      modifiedFields.add('schoolCode');

      if (_role == null) {
        await _showDialog("⚠️ Device role not configured. Cannot proceed.");
        return;
      }
      if (_role == DeviceRole.client) {
        final schoolToSend = <Map<String, dynamic>>[];

        schoolToSend.add({
          "id": newId,
          "schoolName": schoolName.trim().toLowerCase(),
          "schoolCode": schoolCode.trim(),
          "schoolAddress": schoolAddress,
          "schoolPhoneNumber": schoolPhoneNumber,
          "schoolEmail": schoolEmail,
          "termId": globalTermId,
          "schoolLogoPath": _schoolLogoPath,
          "syncStatus": false,
          "lastModified": DateTime.now().toIso8601String(),
          "operationType": "create",
          "modifiedFields": [
            "id",
            "schoolName",
            "schoolCode",
            "schoolAddress",
            "schoolPhoneNumber",
            "schoolEmail",
            "termId",
          ],
        });

        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
        final uri = Uri.parse('http://$hostIp:8080/api/school/bulk');

        try {
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"schools": schoolToSend}), // ✅ Aligns with server
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
              builder: (ctx) {
                return AlertDialog(
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
                );
              },
            );

            if (insertedCount > 0) {
              Navigator.pop(context); // Close the form if something was saved
            }
          } else {
            await _showDialog("❌ Host rejected School info: ${response.body}");
          }
        } catch (e) {
          await _showDialog("❌ Failed to send school info to host.");
          print("school info send error: $e");
        }
      }
      if (_role == DeviceRole.host) {
        final box = await Hive.openBox<School>('school');
        if (box.isNotEmpty) {
          await _showDialog(
              'Only One School Is Allowed For This System. You Can Now Only Update!');
          Future.delayed(const Duration(seconds: 3), () {});
          return;
        } else {
          final existingSchools = box.values.cast<School>().where(
                (s) => s.schoolName == schoolName,
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
            // Set the termId from globalTermId
            syncStatus: false, // Set syncStatus to false
            lastModified:
                DateTime.now(), // Set lastModified to current datetime
            operationType: 'create', // Set operationType to 'create'
            schoolLogoPath: _schoolLogoPath, // Store the logo path
            modifiedFields: modifiedFields,
          );

          await box.add(newSchool); // Add the new school to the Hive box

          await _showDialog('School Added Successfully');

          Navigator.pop(context); // Return to the previous screen
        }
      }
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
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }
}
