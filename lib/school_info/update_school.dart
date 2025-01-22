import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:path/path.dart' as path; // For handling file paths

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
  String? _schoolLogoPath; // To store the selected image path

  @override
  void initState() {
    super.initState();
    final Box<School> box = Hive.box<School>('school');

    // Load the current school from the Hive box
    currentSchool = box.getAt(widget.index)!;

    // Populate the text fields with the current school information
    _schoolNameController.text = currentSchool.schoolName ?? '';
    _schoolAddressController.text = currentSchool.schoolAddress ?? '';
    _schoolPhoneNumberController.text = currentSchool.schoolPhoneNumber ?? '';
    _schoolEmailController.text = currentSchool.schoolEmail ?? '';
    _schoolLogoPath = currentSchool.schoolLogoPath;
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update School Info',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('School Name', _schoolNameController),
            const SizedBox(height: 20),
            _buildTextField('School Address', _schoolAddressController),
            const SizedBox(height: 20),
            _buildTextField(
                'School Phone Number', _schoolPhoneNumberController),
            const SizedBox(height: 20),
            _buildTextField('School Email', _schoolEmailController),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateSchool,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 15, 15, 15),
                backgroundColor: Color.fromARGB(255, 251, 252, 254),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Update'),
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo Image Selected!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
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

  void _updateSchool() async {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<School>('school');

      // Get the updated values from the text fields
      final schoolName = _schoolNameController.text.toLowerCase();
      final schoolAddress = _schoolAddressController.text.toLowerCase();
      final schoolPhoneNumber = _schoolPhoneNumberController.text.toLowerCase();
      final schoolEmail = _schoolEmailController.text.toLowerCase();
      final schoolCode = currentSchool.schoolCode;

      // Check if a school with the same name and term already exists
      final existingSchool = box.values.firstWhere(
        (s) => s.schoolName!.toLowerCase() == schoolName,
        orElse: () => School(
          schoolName: '',
          lastModified: DateTime(1970),
        ),
      );

      // Ensure the user isn't updating to a name that already exists
      if (existingSchool.schoolName!.isNotEmpty &&
          existingSchool.schoolName!.toLowerCase() !=
              currentSchool.schoolName!.toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School with this name already exists')),
        );
        return;
      }
      int? newId = existingSchool.id;
      // Track modified fields
      // Track modified fields
      List<String> modifiedFields = currentSchool.modifiedFields ?? [];

// Append new modifications without overwriting
      if (currentSchool.schoolName!.toLowerCase() != schoolName) {
        if (!modifiedFields.contains('schoolName')) {
          modifiedFields.add('schoolName');
        }
      }

      if (currentSchool.schoolAddress?.toLowerCase() != schoolAddress) {
        if (!modifiedFields.contains('schoolAddress')) {
          modifiedFields.add('schoolAddress');
        }
      }

      if (currentSchool.schoolPhoneNumber?.toLowerCase() != schoolPhoneNumber) {
        if (!modifiedFields.contains('schoolPhoneNumber')) {
          modifiedFields.add('schoolPhoneNumber');
        }
      }

      if (currentSchool.schoolEmail?.toLowerCase() != schoolEmail) {
        if (!modifiedFields.contains('schoolEmail')) {
          modifiedFields.add('schoolEmail');
        }
      }

      // Create the updated school object using copyWith to preserve unchanged fields
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
        id: newId,
        schoolLogoPath: _schoolLogoPath, // Include the updated logo path
        modifiedFields: modifiedFields,
      );

      // Update the school in Hive at the specific index
      box.putAt(widget.index, updatedSchool);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School Updated Successfully')),
      );

      Navigator.pop(context);
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
