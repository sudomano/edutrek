import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class UpdateTeacherScreen extends StatefulWidget {
  final Teachers existingPurpose;

  const UpdateTeacherScreen({super.key, required this.existingPurpose});

  @override
  _UpdateTeacherScreenState createState() => _UpdateTeacherScreenState();
}

class _UpdateTeacherScreenState extends State<UpdateTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _idNumberController;
  late String? _employmentStatusController;
  late String? _selectedGender;
  late DateTime? _selectedDateOfBirth;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late DateTime? _selectedHireDate;
  late TextEditingController _qualificationsController;

  late List<String> _selectedClasses;

  List<String> _classes = [];

  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];

  @override
  void initState() {
    super.initState();
    _initializeFields();

    _loadClasses();
    _loadTerms(); // Load terms when the screen initializes
  }

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    setState(() {
      _availableTerms =
          termsBox.values.map((term) => term.termId).toSet().toList();
    });
  }

  void _initializeFields() {
    _nameController = TextEditingController(text: widget.existingPurpose.name);
    _surnameController =
        TextEditingController(text: widget.existingPurpose.surname);
    _idNumberController =
        TextEditingController(text: widget.existingPurpose.IdNumber);
    _employmentStatusController = widget.existingPurpose.employmentStatus;
    _selectedGender = widget.existingPurpose.gender;
    _selectedDateOfBirth = widget.existingPurpose.dateOfBirth;
    _phoneController =
        TextEditingController(text: widget.existingPurpose.phoneNumber);
    _emailController =
        TextEditingController(text: widget.existingPurpose.email);
    _addressController =
        TextEditingController(text: widget.existingPurpose.address);
    _selectedHireDate = widget.existingPurpose.hireDate;
    _qualificationsController =
        TextEditingController(text: widget.existingPurpose.qualifications);

    _selectedClasses = widget.existingPurpose.assignedClasses != null
        ? List.from(widget.existingPurpose.assignedClasses as Iterable)
        : <String>[];

    _selectedTerms = List<String>.from(widget.existingPurpose.terms ?? []);
  }

  Future<void> _loadClasses() async {
    final box = await Hive.box<Classes>('classes');
    final classes = box.values
        .where((classItem) => classItem.terms!.contains(globalTermId))
        .map((e) => e.className)
        .toList();

    setState(() {
      _classes = classes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Update Staff'),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, 1),
              Color.fromARGB(255, 255, 255, 255)
            ], // Gradient background colors
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildTextField('Name', _nameController),
                  _buildTextField('Surname', _surnameController),
                  _buildTextField('Id Number', _idNumberController),
                  _buildDropdownField(
                      'Gender', _selectedGender, ['Male', 'Female'], (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  }),
                  _buildDropdownField(
                      'Employment Status',
                      _employmentStatusController,
                      ['Employed', 'On Leave', 'On Retirement', 'Dismissed'],
                      (value) {
                    setState(() {
                      _employmentStatusController = value;
                    });
                  }),
                  _buildDateField('Date of Birth', _selectedDateOfBirth,
                      (date) {
                    setState(() {
                      _selectedDateOfBirth = date;
                    });
                  }),
                  _buildTextField('Phone Number', _phoneController,
                      inputType: TextInputType.phone),
                  _buildTextField('Email Address', _emailController,
                      inputType: TextInputType.emailAddress),
                  _buildTextField('Home Address', _addressController,
                      inputType: TextInputType.streetAddress),
                  _buildDateField('Hired Date', _selectedHireDate, (date) {
                    setState(() {
                      _selectedHireDate = date;
                    });
                  }),
                  _buildTextField('Qualifications', _qualificationsController),
                  const SizedBox(height: 16),
                  _buildClassesList(),
                  const SizedBox(height: 20),
                  _buildTermSelection(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _updateStudent(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(
                          255, 225, 232, 243), // Button background color
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Update Teacher',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildClassesList() {
    bool _selectAll = _selectedClasses.length == _classes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: (isChecked) {
                  setState(() {
                    if (isChecked == true) {
                      _selectedClasses = List.from(_classes);
                    } else {
                      _selectedClasses.clear();
                    }
                  });
                },
              ),
              const Text('Select All'),
            ],
          ),
          ..._classes.map((className) {
            return CheckboxListTile(
              title: Text(className),
              value: _selectedClasses.contains(className),
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked == true) {
                    _selectedClasses.add(className);
                  } else {
                    _selectedClasses.remove(className);
                  }
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.3), // Transparent background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none, // No border
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }

          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(String label, String? selectedValue,
      List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.3), // Transparent background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none, // No border
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? selectedDate,
      ValueChanged<DateTime?> onDateSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (selected != null) {
            onDateSelected(selected);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white.withOpacity(0.3), // Transparent background
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none, // No border
            ),
          ),
          child: Text(
            selectedDate == null
                ? 'Select Date'
                : '${selectedDate.toLocal()}'.split(' ')[0],
            style: TextStyle(
              color: selectedDate == null ? Colors.grey : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  void _updateStudent() async {
    if (_formKey.currentState!.validate()) {
      List<String> modifiedFields = widget.existingPurpose.modifiedFields ??
          []; // Initialize with existing modified fields

// Append new modifications without overwriting
      if (!modifiedFields.contains('terms')) {
        modifiedFields.add('terms');
      }
      if (widget.existingPurpose.name.toLowerCase() !=
          _nameController.text.toLowerCase()) {
        if (!modifiedFields.contains('name')) {
          modifiedFields.add('name');
        }
      }

      if (widget.existingPurpose.surname.toLowerCase() !=
          _surnameController.text.toLowerCase()) {
        if (!modifiedFields.contains('surname')) {
          modifiedFields.add('surname');
        }
      }

      if (widget.existingPurpose.IdNumber.toLowerCase() !=
          _idNumberController.text.toLowerCase()) {
        if (!modifiedFields.contains('IdNumber')) {
          modifiedFields.add('IdNumber');
        }
      }

      if (widget.existingPurpose.phoneNumber.toLowerCase() !=
          _phoneController.text.toLowerCase()) {
        if (!modifiedFields.contains('phoneNumber')) {
          modifiedFields.add('phoneNumber');
        }
      }

      if (widget.existingPurpose.gender.toLowerCase() !=
          _selectedGender?.toLowerCase()) {
        if (!modifiedFields.contains('gender')) {
          modifiedFields.add('gender');
        }
      }

      if (widget.existingPurpose.email.toLowerCase() !=
          _emailController.text.toLowerCase()) {
        if (!modifiedFields.contains('email')) {
          modifiedFields.add('email');
        }
      }

      if (widget.existingPurpose.address.toLowerCase() !=
          _addressController.text.toLowerCase()) {
        if (!modifiedFields.contains('address')) {
          modifiedFields.add('address');
        }
      }

      if (_employmentStatusController != null) {
        if (widget.existingPurpose.employmentStatus !=
            _employmentStatusController) {
          if (!modifiedFields.contains('employmentStatus')) {
            modifiedFields.add('employmentStatus');
          }
        }
      }

      if (_selectedHireDate != null) {
        if (widget.existingPurpose.hireDate != _selectedHireDate) {
          if (!modifiedFields.contains('hireDate')) {
            modifiedFields.add('hireDate');
          }
        }
      }

      if (_qualificationsController.text.toLowerCase().isNotEmpty) {
        if (widget.existingPurpose.qualifications.toLowerCase() !=
            _qualificationsController.text.toLowerCase()) {
          if (!modifiedFields.contains('qualifications')) {
            modifiedFields.add('qualifications');
          }
        }
      }
      if (!const DeepCollectionEquality()
          .equals(widget.existingPurpose.assignedClasses, _selectedClasses)) {
        if (!modifiedFields.contains('assignedClasses')) {
          modifiedFields.add('assignedClasses');
        }
      }

      final updatedPurpose = widget.existingPurpose.copyWith(
        name: _nameController.text,
        surname: _surnameController.text,
        IdNumber: _idNumberController.text,
        gender: _selectedGender!,
        employmentStatus: _employmentStatusController!,
        dateOfBirth: _selectedDateOfBirth!,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        address: _addressController.text,
        hireDate: _selectedHireDate!,
        qualifications: _qualificationsController.text,
        paymentPurpose: '',
        paymentAmount: 0.0,
        assignedClasses: _selectedClasses,
        syncStatus: false, // Mark for syncing
        lastModified: DateTime.now(), // Update last modified time
        operationType: 'update', // Mark operation as update
        terms: List<String>.from(_selectedTerms), // ✅ Update terms
      );

      final box = await Hive.openBox<Teachers>('teachers');
      final index = box.values
          .toList()
          .indexWhere((purpose) => purpose.id == widget.existingPurpose.id);

      if (index != -1) {
        box.putAt(index, updatedPurpose); // Update the record in Hive
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff  Updated Successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Staff Was Not Found')),
        );
      }

      setState(() {
        _nameController.clear();
        _surnameController.clear();
        _idNumberController.clear();
        _employmentStatusController;
        _selectedGender = null;
        _selectedDateOfBirth = null;
        _phoneController.clear();
        _emailController.clear();
        _addressController.clear();
        _selectedHireDate = null;
        _qualificationsController.clear();
      });
    }
  }

  @override
  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _qualificationsController.dispose();
    super.dispose();
  }
}
