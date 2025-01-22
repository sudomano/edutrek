import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _illnessInfoController = TextEditingController();

  String? _selectedValue = 'No Ailment';
  String? _selectedClass;
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _physicalAddressController = TextEditingController();
  final _formerSchoolController = TextEditingController();
  final _religionController = TextEditingController(text: "Christianity");
  final _denominationController = TextEditingController();
  final _studentIdNumberController = TextEditingController();
  final _nationalIdNumberController = TextEditingController();
  final _nationalityController = TextEditingController(text: "Zimbabwean");
  final _districtController = TextEditingController();
  final _previousSchoolPerformanceResultsController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactNumberController = TextEditingController();

  List<String> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _setInitialRegNumber();
  }

  Future<void> _loadClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    setState(() {
      _classes = box.values
          .where((c) => c.termId == globalTermId)
          .map((c) => c.className)
          .toList();
    });
  }

  Future<void> _setInitialRegNumber() async {
    final box = await Hive.openBox<Student>('students');
    setState(() {
      _regNumberController.text = (box.length + 1).toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Student',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Text('Student Class',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildDropdownField('Class (required)', _selectedClass, _classes,
                (value) {
              setState(() {
                _selectedClass = value;
              });
            }),
            const SizedBox(height: 20),
            const Center(
              child: Text('Student Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            _buildTextField('Name (required)', _nameController),
            _buildTextField('Surname (required)', _surnameController),

            _buildDropdownField(
                'Gender (required)', _selectedGender, ['Male', 'Female'],
                (value) {
              setState(() {
                _selectedGender = value;
              });
            }),
            _buildDateField('Date of Birth (required)', _selectedDateOfBirth,
                (date) {
              setState(() {
                _selectedDateOfBirth = date;
              });
            }),
            _buildTextFieldd('Nationality', _nationalityController),
            _buildTextFieldd('District', _districtController),
            _buildTextFieldd('National ID Number', _nationalIdNumberController),
            // _buildTextField(
            //     'Student Registration Number', _studentIdNumberController),
            TextFormField(
              controller: _studentIdNumberController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Student Registration Number (required)',
                filled: true,
                fillColor: const Color.fromARGB(255, 194, 191, 191)
                    .withOpacity(0.3), // Transparent background
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none, // No border
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter Student Registration Number';
                }
                return null;
              },
            ),
            _buildTextField(
                'Physical Address  (required)', _physicalAddressController),
            // Guardian  Section
            const SizedBox(height: 20),
            const Center(
              child: Text('Parent Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTextField('Parent Name (required)', _parentNameController),
            _buildTextField('Parent Phone Number (required)', _phoneController,
                inputType: TextInputType.phone),

            // New Fields Section
            const SizedBox(height: 20),
            const Center(
              child: Text('Religious Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTextFieldd('Religion', _religionController),
            _buildTextFieldd('Denomination', _denominationController),

            const SizedBox(height: 20),
            const Center(
              child: Text('Enrollment Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTextFieldd('Former School', _formerSchoolController),
            _buildTextFieldd('Former School Results',
                _previousSchoolPerformanceResultsController),

            // Emergency Contact Section
            const SizedBox(height: 20),
            const Center(
              child: Text('Emergency Contact',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTextFieldd(
                'Emergency Contact Name', _emergencyContactNameController),
            _buildTextFieldd(
                'Emergency Contact Number', _emergencyContactNumberController),
            // health Contact Section
            const SizedBox(height: 20),
            const Center(
              child: Text('Health Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildDropdownField('Select Option (Required)', _selectedValue,
                ['No Ailment', ' Has Ailment'], (value) {}),

            _buildTextFieldd('Illness Information', _illnessInfoController),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 227, 233, 241),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Add Student',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
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
          fillColor: const Color.fromARGB(255, 194, 191, 191)
              .withOpacity(0.3), // Transparent background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none, // No border
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label'; // Form validation
          }

          return null;
        },
      ),
    );
  }

  Widget _buildTextFieldd(String label, TextEditingController controller,
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
          fillColor: const Color.fromARGB(255, 194, 191, 191)
              .withOpacity(0.3), // Transparent background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none, // No border
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyTextField(
      String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color.fromARGB(255, 194, 191, 191)
              .withOpacity(0.3), // Transparent background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none, // No border
          ),
        ),
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
          fillColor: const Color.fromARGB(255, 194, 191, 191)
              .withOpacity(0.3), // Transparent background
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
            fillColor: const Color.fromARGB(255, 194, 191, 191)
                .withOpacity(0.3), // Transparent background
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
                color: selectedDate == null ? Colors.grey : Colors.black),
          ),
        ),
      ),
    );
  }

  bool _isValidPhoneNumber(String value) {
    // Implement your phone number validation logic here
    final phoneRegExp = RegExp(r'^[0-9]{10,14}$');
    return phoneRegExp.hasMatch(value);
  }

  Future<int> getNextId() async {
    final box = await Hive.openBox<Student>('students');
    if (box.isEmpty) return 1; // Start with ID 1 if no records exist

    int currentMaxId = box.values
        .map((e) => e.id ?? 0)
        .reduce((curr, next) => curr > next ? curr : next);
    return currentMaxId + 1;
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (globalTermId != null) {
        final name = _nameController.text.toLowerCase();
        final surname = _surnameController.text.toLowerCase();
        final className = _selectedClass?.toLowerCase() ?? '';
        final gender = _selectedGender?.toLowerCase() ?? '';
        final studentIdNumber = _studentIdNumberController.text.toLowerCase();

        final box = await Hive.openBox<Student>('students');

        // Check if a student with the same details already exists
        final existingStudents = box.values.where((student) =>
            student.name.toLowerCase() == name &&
            student.surname.toLowerCase() == surname &&
            student.class_.toLowerCase() == className &&
            student.termId == globalTermId &&
            student.gender.toLowerCase() == gender);

        // Check for student ID duplication
        final duplicateId = box.values.any((student) =>
            student.studentIdNumber?.toLowerCase() == studentIdNumber &&
            student.termId == globalTermId);
        if (studentIdNumber.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Student Registration Number is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
              ),
              backgroundColor: Colors
                  .white, // Optional: Change the background color for better contrast
            ),
          );

          return;
        }
        if (_selectedClass!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Class is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
              ),
              backgroundColor: Colors
                  .white, // Optional: Change the background color for better contrast
            ),
          );

          return;
        }
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Name is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
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
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
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
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
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
                'Date Of Birth is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
              ),
              backgroundColor: Colors
                  .white, // Optional: Change the background color for better contrast
            ),
          );

          return;
        }
        if (_physicalAddressController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Physical Address is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
              ),
              backgroundColor: Colors
                  .white, // Optional: Change the background color for better contrast
            ),
          );

          return;
        }
        if (_phoneController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Parent Phone Number is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
              ),
              backgroundColor: Colors
                  .white, // Optional: Change the background color for better contrast
            ),
          );

          return;
        }
        if (_parentNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Parent Name is Required',
                style:
                    TextStyle(color: Colors.red), // Set the text color to red
              ),
              backgroundColor: Colors
                  .white, // Optional: Change the background color for better contrast
            ),
          );

          return;
        }

        if (existingStudents.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student already exists'),
            ),
          );

          return;
        }
        if (duplicateId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(' Registration Number already exists'),
            ),
          );

          return;
        }

        int newId = await getNextId();

        List<String> modifiedFields = [];
        modifiedFields.add('id');
        modifiedFields.add('name');
        modifiedFields.add('surname');
        modifiedFields.add('regNumber');
        modifiedFields.add('class_');
        modifiedFields.add('gender');

        modifiedFields.add('age');
        modifiedFields.add('phoneNumber');
        modifiedFields.add('paymentStatus');
        modifiedFields.add('termId');
        modifiedFields.add('physicalAddress');
        modifiedFields.add('formerSchool');

        modifiedFields.add('religion');
        modifiedFields.add('denomination');
        modifiedFields.add('studentIdNumber');
        modifiedFields.add('nationalIdNumber');
        modifiedFields.add('nationality');
        modifiedFields.add('district');

        modifiedFields.add('previousSchoolPerformanceResults');
        modifiedFields.add('emergencyContactName');
        modifiedFields.add('emergencyContactNumber');
        modifiedFields.add('healthStauts');
        modifiedFields.add('healthDetailedInformation');

        final newStudent = Student(
          id: newId,
          name: name,
          surname: surname,
          regNumber: _regNumberController.text,
          class_: _selectedClass!,
          gender: _selectedGender!,
          age: _selectedDateOfBirth!,
          phoneNumber: _phoneController.text,
          paymentStatus: _parentNameController.text,
          termId: globalTermId,
          syncStatus: false, // Set syncStatus to false
          lastModified: DateTime.now(), // Set lastModified to current datetime
          operationType:
              'create', // Set operationType to 'create' // Set the global term ID
          physicalAddress: _physicalAddressController.text.isEmpty
              ? null
              : _physicalAddressController.text,
          formerSchool: _formerSchoolController.text.isEmpty
              ? null
              : _formerSchoolController.text,
          religion: _religionController.text.isEmpty
              ? null
              : _religionController.text,
          denomination: _denominationController.text.isEmpty
              ? null
              : _denominationController.text,
          studentIdNumber: _studentIdNumberController.text,
          nationalIdNumber: _nationalIdNumberController.text.isEmpty
              ? null
              : _nationalIdNumberController.text,
          nationality: _nationalityController.text.isEmpty
              ? null
              : _nationalityController.text,
          district: _districtController.text.isEmpty
              ? null
              : _districtController.text,
          previousSchoolPerformanceResults:
              _previousSchoolPerformanceResultsController.text.isEmpty
                  ? null
                  : _previousSchoolPerformanceResultsController.text,
          emergencyContactName: _emergencyContactNameController.text.isEmpty
              ? null
              : _emergencyContactNameController.text,
          emergencyContactNumber: _emergencyContactNumberController.text.isEmpty
              ? null
              : _emergencyContactNumberController.text,
          healthStauts: _selectedValue.toString(),
          healthDetailedInformation: _illnessInfoController.text.isEmpty
              ? null
              : _illnessInfoController.text,

          modifiedFields: modifiedFields,
        );

        box.add(newStudent); // Add the student

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student Added Successfully')),
        );

        _clearForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No Selected Term Was Found. Create A New Term or Switch Terms To AnExisting One.')),
        );
      }
      // Return to the previous screen
    }
  }

  void _clearForm() {
    setState(() {
      // Clear all the TextEditingController fields
      _nameController.clear();
      _surnameController.clear();
      _regNumberController.clear();
      _phoneController.clear();
      _parentNameController.clear();
      _physicalAddressController.clear();
      _formerSchoolController.clear();
      _religionController.clear();
      _denominationController.clear();
      _studentIdNumberController.clear();
      _nationalIdNumberController.clear();
      _nationalityController.clear();
      _districtController.clear();
      _previousSchoolPerformanceResultsController.clear();
      _emergencyContactNameController.clear();
      _emergencyContactNumberController.clear();
      _illnessInfoController.clear();

      // Reset the dropdown values and Date of Birth
      _selectedClass = null;
      _selectedGender = null;
      _selectedDateOfBirth = null;
      _selectedValue = null;

      // Reset form validation state
      _formKey.currentState?.reset();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _regNumberController.dispose();

    _phoneController.dispose();
    _parentNameController.dispose();
    _physicalAddressController.dispose();
    _formerSchoolController.dispose();
    _religionController.dispose();
    _denominationController.dispose();
    _studentIdNumberController.dispose();
    _nationalIdNumberController.dispose();
    _nationalityController.dispose();
    _districtController.dispose();
    _previousSchoolPerformanceResultsController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactNumberController.dispose();
    _illnessInfoController.dispose();
    super.dispose();
  }
}
