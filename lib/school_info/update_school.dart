import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateSchoolScreen extends StatefulWidget {
  final int index;

  const UpdateSchoolScreen({super.key, required this.index});

  @override
  _UpdateSchoolScreenState createState() => _UpdateSchoolScreenState();
}

class _UpdateSchoolScreenState extends State<UpdateSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _schoolPhoneNumberController = TextEditingController();
  final _schoolEmailController = TextEditingController();

  late School currentSchool;
  String? _schoolLogoPath;
  bool _isSubmitting = false;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadSchool();
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

  void _loadSchool() {
    final Box<School> box = Hive.box<School>('school');
    currentSchool = box.getAt(widget.index)!;

    _schoolNameController.text = currentSchool.schoolName ?? '';
    _schoolAddressController.text = currentSchool.schoolAddress ?? '';
    _schoolPhoneNumberController.text = currentSchool.schoolPhoneNumber ?? '';
    _schoolEmailController.text = currentSchool.schoolEmail ?? '';
    _schoolLogoPath = currentSchool.schoolLogoPath;
  }

  @override
  Widget build(BuildContext context) {
    final isHost = _role == DeviceRole.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update School Info'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        foregroundColor: Colors.white,
        elevation: 4.0,
        actions: [
          // ✅ Show deletion status if school is deleted
          if (currentSchool.isDeleted ?? false)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DELETED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: CenteredFormContainer(
        title: 'Update School Info',
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Status indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: (currentSchool.isDeleted ?? false)
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (currentSchool.isDeleted ?? false)
                        ? Colors.red.shade300
                        : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (currentSchool.isDeleted ?? false)
                          ? Icons.delete_outline
                          : Icons.check_circle,
                      color: (currentSchool.isDeleted ?? false)
                          ? Colors.red
                          : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (currentSchool.isDeleted ?? false)
                            ? '⚠️ This school is deleted. Update to restore it.'
                            : '✅ School is active',
                        style: TextStyle(
                          color: (currentSchool.isDeleted ?? false)
                              ? Colors.red.shade700
                              : Colors.green.shade700,
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
              const SizedBox(height: 20),
              _buildTextField('School Address', _schoolAddressController),
              const SizedBox(height: 20),
              _buildTextField(
                  'School Phone Number', _schoolPhoneNumberController),
              const SizedBox(height: 20),
              _buildTextField('School Email', _schoolEmailController),
              const SizedBox(height: 20),

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
              const SizedBox(height: 20),

              // ✅ Update button with loading state
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _updateSchool,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 38, 140, 191),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                      : const Text('Update School',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              // ✅ Restore button for deleted schools
              if (currentSchool.isDeleted ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _restoreSchool,
                      icon: const Icon(Icons.restore, color: Colors.green),
                      label: const Text(
                        'Restore This School',
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
          const SnackBar(content: Text('✅ Logo Image Selected!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
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
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Future<void> _updateSchool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final box = Hive.box<School>('school');
      final schoolName = _schoolNameController.text.trim().toLowerCase();
      final schoolAddress = _schoolAddressController.text.trim().toLowerCase();
      final schoolPhoneNumber =
          _schoolPhoneNumberController.text.trim().toLowerCase();
      final schoolEmail = _schoolEmailController.text.trim().toLowerCase();
      final schoolCode = currentSchool.schoolCode;

      // Check if a school with the same name already exists (excluding current)
      final existingSchool = box.values.firstWhere(
        (s) =>
            s.schoolName?.toLowerCase() == schoolName &&
            s.id != currentSchool.id &&
            !(s.isDeleted ?? false),
        orElse: () => School(schoolName: '', lastModified: DateTime(1970)),
      );

      if (existingSchool.schoolName?.isNotEmpty == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School with this name already exists')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // ✅ Track modified fields
      List<String> modifiedFields = currentSchool.modifiedFields ?? [];

      if (currentSchool.schoolName?.toLowerCase() != schoolName &&
          !modifiedFields.contains('schoolName')) {
        modifiedFields.add('schoolName');
      }
      if (currentSchool.schoolAddress?.toLowerCase() != schoolAddress &&
          !modifiedFields.contains('schoolAddress')) {
        modifiedFields.add('schoolAddress');
      }
      if (currentSchool.schoolPhoneNumber?.toLowerCase() != schoolPhoneNumber &&
          !modifiedFields.contains('schoolPhoneNumber')) {
        modifiedFields.add('schoolPhoneNumber');
      }
      if (currentSchool.schoolEmail?.toLowerCase() != schoolEmail &&
          !modifiedFields.contains('schoolEmail')) {
        modifiedFields.add('schoolEmail');
      }
      if (currentSchool.schoolLogoPath != _schoolLogoPath &&
          !modifiedFields.contains('schoolLogoPath')) {
        modifiedFields.add('schoolLogoPath');
      }

      // ✅ If school was deleted, restore it on update
      final isDeleted = currentSchool.isDeleted ?? false;

      final updatedSchool = currentSchool.copyWith(
        schoolName: schoolName.toUpperCase(),
        schoolCode: schoolCode,
        schoolAddress: schoolAddress,
        schoolPhoneNumber: schoolPhoneNumber,
        termId: globalTermId,
        syncStatus: false,
        schoolEmail: schoolEmail,
        lastModified: DateTime.now(),
        operationType: 'update',
        schoolLogoPath: _schoolLogoPath,
        modifiedFields: modifiedFields,
        // ✅ If was deleted, restore on update
        isDeleted: false,
        deletedSyncStatus: false,
      );

      // Update locally
      box.putAt(widget.index, updatedSchool);

      // ✅ Send update to server if client
      if (_role == DeviceRole.client && _hostIp != null) {
        await _sendUpdateToServer(updatedSchool);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDeleted
              ? '✅ School restored and updated successfully'
              : '✅ School Updated Successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating school: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendUpdateToServer(School school) async {
    if (_hostIp == null) return;

    try {
      final schoolJson = {
        'schoolCode': school.schoolCode,
        'schoolName': school.schoolName,
        'schoolAddress': school.schoolAddress,
        'schoolPhoneNumber': school.schoolPhoneNumber,
        'schoolEmail': school.schoolEmail,
        'schoolLogoPath': school.schoolLogoPath,
        'termId': school.termId,
        'operationType': 'update',
        'syncStatus': 0,
        'lastModified': DateTime.now().toIso8601String(),
        'isDeleted': school.isDeleted ?? false,
        'deletedSyncStatus': school.deletedSyncStatus ?? false,
        'modifiedFields': school.modifiedFields,
      };

      final response = await http.put(
        Uri.parse('http://$_hostIp:8080/api/school'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(schoolJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        school.syncStatus = true;
        school.operationType = 'none';
        await school.save();
      }
    } catch (e) {
      print('Error sending update to server: $e');
    }
  }

  // ✅ Restore school
  Future<void> _restoreSchool() async {
    setState(() => _isSubmitting = true);

    try {
      currentSchool.restoreDeleted();
      await currentSchool.save();

      if (_role == DeviceRole.client && _hostIp != null) {
        final response = await http.post(
          Uri.parse('http://$_hostIp:8080/api/school'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'restore',
            'schoolCode': currentSchool.schoolCode,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          currentSchool.syncStatus = true;
          currentSchool.deletedSyncStatus = true;
          await currentSchool.save();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ School restored successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring school: $e')),
      );
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
}
