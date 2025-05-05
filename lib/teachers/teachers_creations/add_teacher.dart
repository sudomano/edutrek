import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart'; // Import your Teachers model

class AddTeacherScreen extends StatefulWidget {
  const AddTeacherScreen({Key? key}) : super(key: key);

  @override
  _AddTeacherScreenState createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>(); // Form validation key
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _employmentStatusController = TextEditingController();
  final _genderController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedHireDate;
  final _qualificationsController = TextEditingController();

  List<String> _classes = []; // List of class names
  List<String> _selectedClasses = []; // Selected classes

  List<String> _availableTerms = [];
  List<String> _selectedTerms = []; // Stores user-selected term IDs

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    setState(() {
      _availableTerms =
          termsBox.values.map((term) => term.termId).toSet().toList();
      _selectedTerms =
          List.from(_availableTerms); // Select all terms by default
    });
  }

  Future<void> _fetchClasses() async {
    final box = await Hive.box<Classes>('classes');
    final classes = box.values
        .where((purposeItem) =>
            purposeItem.termId != null &&
            purposeItem.terms!.contains(globalTermId))
        .map((e) => e.className)
        .toList();
    setState(() {
      _classes = classes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Staff',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Center(
              child: Text('Select Terms (optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTermSelection(),
            const SizedBox(height: 20),
            _buildTextField('Name (required)', _nameController),
            _buildTextField('Surname (required)', _surnameController),
            _buildIdNumberField('ID Number (required)', _idNumberController),
            _buildGenderDropdown('Gender (required)', _genderController),
            _buildEmploymentStatusDropdown(
                'Employment Status (required)', _employmentStatusController),
            _buildDateField('Date of Birth (required)', _selectedDateOfBirth),
            _buildPhoneNumberField('Phone Number (required)', _phoneController),
            _buildTextField('Email (required)', _emailController,
                inputType: TextInputType.emailAddress),
            _buildTextField('Address (required)', _addressController),
            _buildDateField('Hire Date (required)', _selectedHireDate),
            _buildTextField('Roles And Qualifications (required)',
                _qualificationsController),
            const SizedBox(height: 16),
            _buildClassesList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Add Staff'),
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

  Widget _buildClassesList() {
    // Boolean to track the Select/Deselect All state
    bool _selectAll = _selectedClasses.length == _classes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select/Deselect All Checkbox
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: (isChecked) {
                    setState(() {
                      if (isChecked == true) {
                        // Select all classes
                        _selectedClasses = List.from(_classes);
                      } else {
                        // Deselect all classes
                        _selectedClasses.clear();
                      }
                    });
                  },
                ),
                Text(
                  'Assign Classes',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14.0, // Reduced font size
                        color: Colors.black87, // Slightly muted color
                      ),
                ),
              ],
            ),
          ),
          // List of checkboxes for individual classes
          ..._classes.map((className) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                  title: Text(
                    className,
                    style: TextStyle(
                      fontSize: 14.0, // Reduced font size
                      color:
                          Colors.black87, // Slightly muted for professionalism
                    ),
                  ),
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
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Theme.of(context)
                      .primaryColor, // Primary color for checked state
                ),
              ),
            );
          }).toList(),
        ],
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
      ),
    );
  }

  Widget _buildDropdownFields(String label, String? selectedValue,
      List<String> items, ValueChanged<String?> onChanged) {
    // Add a null option to the items list
    List<String> dropdownItems =
        ['None'] + items; // 'None' represents a null selection

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
        items: dropdownItems.map((item) {
          return DropdownMenuItem(
            value: item == 'None' ? null : item, // Set null for 'None'
            child: Text(item),
          );
        }).toList(),
        onChanged: (value) {
          // Call the onChanged callback with null if 'None' is selected
          onChanged(value == 'None' ? null : value);
        },
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
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
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

  Widget _buildDateField(String label, DateTime? selectedDate) {
    final dateFormat = DateFormat('yyyy-MM-dd');
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
            setState(() {
              if (label == 'Date of Birth (required)') {
                _selectedDateOfBirth = selected;
              } else if (label == 'Hire Date (required)') {
                _selectedHireDate = selected;
              }
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
          ),
          child: Text(
            selectedDate == null
                ? 'Select $label'
                : dateFormat.format(selectedDate),
          ),
        ),
      ),
    );
  }

  Widget _buildIdNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          } else if (!_isValidIdNumber(value)) {
            return 'ID Number must contain only one letter, numbers, and be less than 15 characters';
          }
          return null;
        },
        onChanged: (value) {
          controller.value = controller.value.copyWith(
            text: value.toUpperCase(),
            selection: TextSelection.fromPosition(
              TextPosition(offset: value.length),
            ),
          );
        },
      ),
    );
  }

  bool _isValidIdNumber(String value) {
    if (value.length > 15) return false;
    final RegExp idRegExp = RegExp(r'^[0-9]');
    return idRegExp.hasMatch(value);
  }

  Widget _buildGenderDropdown(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        items: ['Male', 'Female']
            .map((String gender) => DropdownMenuItem<String>(
                  value: gender,
                  child: Text(gender),
                ))
            .toList(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null) {
            return 'Please select a $label';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            controller.text = value!;
          });
        },
      ),
    );
  }

  Widget _buildEmploymentStatusDropdown(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        items: ['Employed', 'On Leave', 'On Retirement', 'Dismissed']
            .map((String employmentStatus) => DropdownMenuItem<String>(
                  value: employmentStatus,
                  child: Text(employmentStatus),
                ))
            .toList(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null) {
            return 'Please select a $label';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            controller.text = value!;
          });
        },
      ),
    );
  }

  Widget _buildPhoneNumberField(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          } else if (!RegExp(r'^[0-9]').hasMatch(value)) {
            return 'Please enter a valid phone number';
          }
          return null;
        },
      ),
    );
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<Teachers>('teachers');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final box = await Hive.openBox<Teachers>('teachers');
      int newId = await getNextId();

      final name = _nameController.text;
      final surname = _surnameController.text;
      final idNumber = _idNumberController.text;
      final gender = _genderController.text;
      final employmentStatus = _employmentStatusController.text;
      final phoneNumber = _phoneController.text;
      final email = _emailController.text;
      final address = _addressController.text;
      final qualifications = _qualificationsController.text;

      // Check for student ID duplication
      final duplicateId = box.values
          .any((student) => student.IdNumber.toLowerCase() == idNumber);

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Name is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (idNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'National Identification Number is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (gender.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gender is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (surname.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Surname  Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (gender.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gender is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (employmentStatus.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Employment Status is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone Number is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (_selectedDateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Date of Birth is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (_selectedHireDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Date of Hire is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }
      if (address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Physical Address is Required',
              style: TextStyle(color: Colors.red), // Set the text color to red
            ),
            backgroundColor: Colors
                .white, // Optional: Change the background color for better contrast
          ),
        );

        return;
      }

      if (duplicateId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' National Identification Number already exists'),
          ),
        );

        return;
      }
      List<String> modifiedFields = [];
      modifiedFields.add('id');
      modifiedFields.add('name');
      modifiedFields.add('surname');
      modifiedFields.add('IdNumber');
      modifiedFields.add('assignedClass');
      modifiedFields.add('assignedClasses');

      modifiedFields.add('gender');
      modifiedFields.add('dateOfBirth');
      modifiedFields.add('phoneNumber');
      modifiedFields.add('paymentPurpose');
      modifiedFields.add('isPaid');
      modifiedFields.add('paymentAmount');

      modifiedFields.add('paymentDate');
      modifiedFields.add('email');
      modifiedFields.add('address');
      modifiedFields.add('hireDate');
      modifiedFields.add('qualifications');
      modifiedFields.add('employmentStatus');
      modifiedFields.add('termId');
      modifiedFields.add('terms');

      // Determine the terms to use: either the selected ones or default to globalTermId.
      final List<String> termsToSave =
          _selectedTerms.isNotEmpty ? _selectedTerms : [globalTermId!];

      final teacher = Teachers(
        id: newId,
        name: name,
        surname: surname,
        IdNumber: idNumber,
        assignedClass: '',
        assignedClasses: _selectedClasses,
        gender: gender,
        dateOfBirth: _selectedDateOfBirth ?? DateTime.now(),
        phoneNumber: phoneNumber,
        paymentPurpose: 'N/A',
        isPaid: false,
        paymentAmount: 0.0,
        paymentDate: null, // Payment date to be populated later
        email: email.isEmpty ? '' : email,
        address: address,
        hireDate: _selectedHireDate ?? DateTime.now(),
        qualifications: qualifications,
        employmentStatus: employmentStatus,
        termId: globalTermId,
        syncStatus: false,
        operationType: 'create',
        lastModified: DateTime.now(),
        modifiedFields: modifiedFields,
        terms: _selectedTerms.isNotEmpty ? _selectedTerms : [globalTermId!],

        // Assign global termId here
      );
// Check if teacher with the same ID Number already exists
      final existingTeacher = box.values.firstWhere(
        (teacher) => teacher.IdNumber == idNumber,
        orElse: () => Teachers(
          name: 'empty',
          surname: 'empty',
          gender: '',
          phoneNumber: '',
          IdNumber: 'empty',
          dateOfBirth: DateTime(1970),
          paymentPurpose: '',
          paymentDate: null,
          paymentAmount: 0,
          email: '',
          address: '',
          hireDate: DateTime(1970),
          qualifications: '',
          employmentStatus: '',
          termId: globalTermId,
        ),
      );

      if (existingTeacher.IdNumber == 'empty') {
        box.add(teacher);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff Added Successfully')),
        );

        Navigator.pop(context); // Return to previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Staff with this ID Number already exists')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _idNumberController.dispose();
    _genderController.dispose();
    _employmentStatusController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _qualificationsController.dispose();
    super.dispose();
  }
}
