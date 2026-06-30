import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class UpdateStudentScreen extends StatefulWidget {
  const UpdateStudentScreen({super.key});

  @override
  _UpdateStudentScreenState createState() => _UpdateStudentScreenState();
}

class _UpdateStudentScreenState extends State<UpdateStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _regNumberController = TextEditingController();
  String? _selectedClass;
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  String? _selectedValue = 'No Ailment';
  final _illnessInfoController = TextEditingController();

  final _phoneController = TextEditingController();
  final _paymentStatusController = TextEditingController();
  final _physicalAddressController = TextEditingController();
  final _formerSchoolController = TextEditingController();
  final _religionController = TextEditingController();
  final _denominationController = TextEditingController();
  final _studentIdNumberController = TextEditingController();
  final _nationalIdNumberController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _districtController = TextEditingController();
  final _previousSchoolPerformanceResultsController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactNumberController = TextEditingController();
  List<ExceptionalStudents> _selectedExceptions = [];
  List<ExceptionalStudents> _exceptionalStudents = [];

  bool _isNewComer = false;
  DateTime? _isNewComerFrom;
  DateTime? _isNewComerUntil;

  Student? _foundStudent;

  List<String> _classes = [];
  List<Student> _matchingStudents = [];
  List<String> _availableTerms = [];
  List<String> _selectedTerms = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadTerms(); // Load terms when the screen initializes
    _loadExceptionalStudents();
  }

  void _loadExceptionalStudents() async {
    final box =
        await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');
    final all = box.values.toList();

    setState(() {
      _exceptionalStudents = all
          .where((e) => e.exceptionStatus!.toLowerCase() == 'active')
          .toList();
    });
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Student Update Feedback"),
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

  Future<void> _loadTerms() async {
    final termsBox = await Hive.openBox<Terms>('terms');
    setState(() {
      _availableTerms =
          termsBox.values.map((term) => term.termId).toSet().toList();
    });
  }

  Future<void> _loadClasses() async {
    final box = await Hive.openBox<Classes>('classes');
    setState(() {
      _classes = box.values
          .where((c) => c.terms!.contains(globalTermId))
          .map((c) => c.className)
          .toList();
    });
  }

  void _searchStudents() async {
    final box = await Hive.openBox<Student>('students');
    final students = box.values.toList();
    final searchQuery = _surnameController.text.toLowerCase().trim();

    // If search query is empty, show all students or clear results
    if (searchQuery.isEmpty) {
      setState(() {
        _matchingStudents = [];
      });
      return;
    }

    setState(() {
      _matchingStudents = students.where((student) {
        return _deepMatchStudent(student, searchQuery);
      }).toList();
    });

    if (_matchingStudents.isEmpty) {
      _showDialog('No students found matching "$searchQuery"');
    }
  }

  /// Deep search matching across multiple fields
  bool _deepMatchStudent(Student student, String query) {
    // Get all searchable fields
    final name = (student.name ?? '').toLowerCase();
    final surname = (student.surname ?? '').toLowerCase();
    final fullName = "$name $surname".trim();
    final reversedName = "$surname $name".trim();
    final className = (student.class_ ?? '').toLowerCase();
    final studentId = (student.studentIdNumber ?? '').toLowerCase();
    final phoneNumber = (student.phoneNumber ?? '').toLowerCase();

    // Split query into words for partial matching
    final queryWords = query.split(' ');

    // Remove any empty strings
    final cleanWords = queryWords.where((w) => w.isNotEmpty).toList();

    // Match Type 1: Exact field matches
    if (name.contains(query) ||
        surname.contains(query) ||
        fullName.contains(query) ||
        reversedName.contains(query) ||
        className.contains(query) ||
        studentId.contains(query) ||
        phoneNumber.contains(query)) {
      return true;
    }

    // Match Type 2: Multi-word search (e.g., "John Doe")
    if (cleanWords.length >= 2) {
      // Check if name contains all words
      bool allWordsFoundInName = true;
      for (var word in cleanWords) {
        if (!fullName.contains(word) && !reversedName.contains(word)) {
          allWordsFoundInName = false;
          break;
        }
      }
      if (allWordsFoundInName) return true;

      // Check if name + class combination
      if (cleanWords.length == 2) {
        final firstWord = cleanWords[0];
        final secondWord = cleanWords[1];

        if ((name.contains(firstWord) && className.contains(secondWord)) ||
            (surname.contains(firstWord) && className.contains(secondWord)) ||
            (fullName.contains(firstWord) && className.contains(secondWord))) {
          return true;
        }
      }
    }

    // Match Type 3: Partial word matching (e.g., "Jon" matches "John")
    for (var word in cleanWords) {
      if (word.length >= 3) {
        // Check if any field contains this word as a substring
        if (name.contains(word) ||
            surname.contains(word) ||
            className.contains(word) ||
            studentId.contains(word)) {
          return true;
        }
      }
    }

    // Match Type 4: Starts with matching (useful for autocomplete)
    if (name.startsWith(query) ||
        surname.startsWith(query) ||
        fullName.startsWith(query) ||
        className.startsWith(query) ||
        studentId.startsWith(query)) {
      return true;
    }

    // Match Type 5: Fuzzy matching for names (if query length >= 2)
    if (query.length >= 2) {
      if (_fuzzyMatch(name, query) || _fuzzyMatch(surname, query)) {
        return true;
      }
    }

    return false;
  }

  /// Simple fuzzy matching (checks if characters appear in order)
  bool _fuzzyMatch(String text, String query) {
    if (query.isEmpty || text.isEmpty) return false;

    int queryIndex = 0;
    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        queryIndex++;
      }
    }
    return queryIndex == query.length;
  }

  void _selectStudent(Student student) async {
    print("🟨 Selecting student: ${student.name}");

    setState(() {
      _foundStudent = student;
      // 🔍 Check what comes from the student
      print(
          "📦 student.exceptions: ${student.exceptions?.map((e) => e.exceptionName).toList()}");

      _illnessInfoController.text =
          student.healthDetailedInformation.toString();
      _selectedValue = student.healthStauts.toString();
      _nameController.text = student.name;
      _surnameController.text = student.surname;
      _regNumberController.text = student.regNumber;
      _selectedClass = student.class_;
      _selectedGender = student.gender;
      _selectedDateOfBirth = student.age;
      _phoneController.text = student.phoneNumber;
      _paymentStatusController.text = student.paymentStatus;
      _physicalAddressController.text = student.physicalAddress.toString();
      _formerSchoolController.text = student.formerSchool.toString();
      _religionController.text = student.religion.toString();
      _denominationController.text = student.denomination.toString();
      _studentIdNumberController.text = student.studentIdNumber.toString();
      _nationalIdNumberController.text = student.nationalIdNumber.toString();
      _nationalityController.text = student.nationality.toString();
      _districtController.text = student.district.toString();
      _previousSchoolPerformanceResultsController.text =
          student.previousSchoolPerformanceResults.toString();
      _emergencyContactNameController.text =
          student.emergencyContactName.toString();
      _emergencyContactNumberController.text =
          student.emergencyContactNumber.toString();
      // Preload the selected terms
// Ensure _selectedTerms is assigned a valid list (handle null case)
      // 🔹 Set exceptional and newcomer values from the existing student
      _selectedExceptions = student.exceptions ?? [];
      print(
          "✅ _selectedExceptions after load: ${_selectedExceptions.map((e) => e.exceptionName).toList()}");

      _isNewComer = student.isNewComer ?? false;
      _isNewComerFrom = student.isNewComerFrom;
      _isNewComerUntil = student.isNewComerUntil;
      _selectedTerms = List<String>.from(student.terms ?? []);
      _matchingStudents = [];
    });
    // Now, load the class's terms to override student terms
    await _loadClassTerms(student.class_);
  }

  Future<void> _loadClassTerms(String className) async {
    final classBox = await Hive.openBox<Classes>('classes');
    final selectedClass = classBox.values.firstWhere(
      (c) => c.className == className,
      orElse: () => Classes(
        id: -1,
        className: '',
        classCode: '',
        date: DateTime(1970),
        termId: globalTermId,
      ),
    );

    if (selectedClass.id != -1) {
      // Update the available terms for this class
      setState(() {
        _availableTerms = selectedClass.terms != null
            ? selectedClass.terms!.toSet().toList() // Remove duplicates
            : [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Update Student',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField(
              'Enter Student to Search',
              _surnameController,
              onSubmitted: _searchStudents, // ✅ Pass the search function
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _searchStudents,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Search'),
            ),
            const SizedBox(height: 20),
            if (_matchingStudents.isNotEmpty) ...[
              _buildStudentDropdown(),
              const SizedBox(height: 20),
            ],
            if (_foundStudent != null) ...[
              _buildDropdownField('Class', _selectedClass, _classes, (value) {
                setState(() {
                  _selectedClass = value;
                });
              }),
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
              _buildTextField(
                  'Student Registration Number', _studentIdNumberController),
              _buildTextField('Nationality', _nationalityController),
              _buildTextField('District', _districtController),
              _buildTextField(
                  'National ID Number', _nationalIdNumberController),

              _buildTextField(
                  'Physical Address  (required)', _physicalAddressController),
              // Guardian  Section
              const SizedBox(height: 20),
              const Center(
                child: Text('Parent Information',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTextField(
                  'Parent Name (required)', _paymentStatusController),
              _buildTextField(
                  'Parent Phone Number (required)', _phoneController,
                  inputType: TextInputType.phone),

              // New Fields Section
              const SizedBox(height: 20),
              const Center(
                child: Text('Religious Information',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTextField('Religion', _religionController),
              _buildTextField('Denomination', _denominationController),

              const SizedBox(height: 20),
              const Center(
                child: Text('Enrollment Information',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTextField('Former School', _formerSchoolController),
              _buildTextField('Former School Results',
                  _previousSchoolPerformanceResultsController),

              // Emergency Contact Section
              const SizedBox(height: 20),
              const Center(
                child: Text('Emergency Contact',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTextField(
                  'Emergency Contact Name', _emergencyContactNameController),
              _buildTextField('Emergency Contact Number',
                  _emergencyContactNumberController),
              const SizedBox(height: 20),
              const Center(
                child: Text('Health Information',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildDropdownField('Select Option (Required)', _selectedValue,
                  ['No Ailment', ' Has Ailment', 'null'], (value) {}),

              _buildTextField('Illness Information', _illnessInfoController),
              const SizedBox(height: 20),
              // 🔹 Add Term Selection UI Here 🔹

              const Center(
                child: Text('Special Exceptions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              MultiSelectDialogField<ExceptionalStudents>(
                items: _exceptionalStudents
                    .map((e) => MultiSelectItem(e, e.exceptionName.toString()))
                    .toList(),
                title: const Text("Select Exceptions"),
                // ✅ Map _selectedExceptions by matching exceptionName from _exceptionalStudents
                initialValue: _selectedExceptions
                    .map((selected) {
                      return _exceptionalStudents.firstWhere(
                        (e) => e.exceptionName == selected.exceptionName,
                        orElse: () =>
                            ExceptionalStudents()..exceptionName = 'not found',
                      );
                    })
                    .where((e) => e.exceptionName != 'not found')
                    .toList(),
                onConfirm: (values) {
                  print(
                      "🎯 Selected exceptions: ${values.map((e) => e.exceptionName).toList()}");

                  setState(() {
                    _selectedExceptions = values;
                  });
                },
              ),
              const SizedBox(height: 20),

              CheckboxListTile(
                title: const Text("Is Newcomer?"),
                value: _isNewComer ?? false,
                onChanged: (value) {
                  setState(() {
                    _isNewComer = value!;
                    if (value == true) {
                      Terms? currentTerm;

                      final termsBox = Hive.box<Terms>('terms');
                      final terms = termsBox.values
                          .where((term) => term.termId == globalTermId);
                      if (terms.isNotEmpty) {
                        currentTerm = terms.first;
                      }

                      final now = DateTime.now();
                      final termEnd = currentTerm?.endDate;
                      final DateTime defaultUntilDate =
                          (termEnd != null && termEnd.isAfter(now))
                              ? termEnd
                              : now.add(const Duration(days: 30));

                      setState(() {
                        _isNewComerFrom = now;
                        _isNewComerUntil = defaultUntilDate;
                      });
                    } else {
                      setState(() {
                        _isNewComerFrom = null;
                        _isNewComerUntil = null;
                      });
                    }
                  });
                },
              ),

              if (_isNewComer == true) ...[
                _buildDateField('Newcomer From', _isNewComerFrom, (date) {
                  // Optional: allow the user to override the default
                  setState(() {
                    _isNewComerFrom = date;
                  });
                }),
                _buildDateField('Newcomer Until', _isNewComerUntil, (date) {
                  if (date != null && date.isAfter(DateTime(1900))) {
                    setState(() {
                      _isNewComerUntil = date;
                    });
                  } else {
                    _showDialog('Newcomer Until must be in the future');
                  }
                }),
              ],
              const SizedBox(height: 20),
              const Center(
                child: Text('Select Terms (Update if necessary)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildTermSelection(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _updateStudent(_foundStudent!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(
                      255, 225, 232, 243), // Button background color
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Update Student',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// UI Section for Term Selection
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
                    // Debug: log the selected terms after each change
                    print('Selected terms after change: $_selectedTerms');
                  });
                },
              );
            }).toList(),
          );
  }

  Widget _buildStudentDropdown() {
    return DropdownButtonFormField<Student>(
      value: _foundStudent,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Select Student',
        filled: true,
        fillColor: Colors.white.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      items: _matchingStudents.map((student) {
        final nameLine = '${student.surname}, ${student.name}';
        final infoLine = '${student.class_} | ID: ${student.studentIdNumber}';

        return DropdownMenuItem<Student>(
          value: student,
          child: Tooltip(
            message: '$nameLine\n$infoLine', // ✅ Full info on long press
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nameLine,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    infoLine,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          _selectStudent(value);
        }
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text,
      VoidCallback? onSubmitted}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        textCapitalization: TextCapitalization.words,
        textInputAction:
            TextInputAction.search, // ✅ Change keyboard button to "Search"
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color.fromARGB(255, 194, 191, 191).withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onFieldSubmitted: (value) {
          // ✅ Trigger search when Enter/Search key is pressed
          if (onSubmitted != null) {
            onSubmitted();
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (label == 'Phone Number' && !_isValidPhoneNumber(value)) {
            return 'Please enter a valid phone number';
          }
          return null;
        },
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
          fillColor: Colors.white.withOpacity(0.3), // Transparent background
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
    final uniqueItems = items.toSet().toList(); // Remove duplicates

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: uniqueItems.contains(selectedValue) ? selectedValue : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withOpacity(0.3), // Transparent background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none, // No border
          ),
        ),
        items: uniqueItems.map((item) {
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
            lastDate: DateTime(2100),
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

  bool _isValidPhoneNumber(String value) {
    final phoneRegExp = RegExp(r'^[0-9]{10,14}$');
    return phoneRegExp.hasMatch(value);
  }

  void _updateStudent(Student student) async {
    if (_formKey.currentState!.validate()) {
      // Log the final terms list before updating the student record
      print('Final selected terms before submitting: $_selectedTerms');

      final name = _nameController.text.toLowerCase();
      final surname = _surnameController.text.toLowerCase();
      final reg = _regNumberController.text.toLowerCase();
      final classes = _selectedClass!;
      final gender = _selectedGender!;
      final age = _selectedDateOfBirth!;
      final phone = _phoneController.text.toLowerCase();
      final status = _paymentStatusController.text.toLowerCase();
      final studentIdNumber = student.studentIdNumber;
      int? id = student.id;
      // Fetch the current student record
      final boxen = await Hive.openBox<Student>('students');

      final currentStudent = boxen.values.firstWhere(
        (s) => s.id == student.id,
        orElse: () => Student(
          id: -1,
          name: '',
          surname: '',
          regNumber: '',
          class_: '',
          gender: '',
          age: DateTime(1970),
          phoneNumber: '',
          paymentStatus: '',
          termId: globalTermId,
          syncStatus: false,
          lastModified: DateTime(1970),
          operationType: 'update',
          physicalAddress: '',
          terms: [],
        ),
      );

      if (currentStudent.id == -1) {
        _showDialog('Error: Student not found');
        return;
      }

      // Ensure the terms list in the student is overridden by the class terms
      final classBox = await Hive.openBox<Classes>('classes');
      final selectedClass = classBox.values.firstWhere(
        (c) => c.className == _selectedClass,
        orElse: () => Classes(
          id: -1,
          className: '',
          classCode: '',
          date: DateTime(1970),
          termId: globalTermId,
        ),
      );

      List<String> modifiedFields = student.modifiedFields ??
          []; // Initialize with existing modified fields

      if (!modifiedFields.contains('terms')) {
        modifiedFields.add('terms');
      }

// Append new modifications without overwriting
      if (student.id != id) {
        if (!modifiedFields.contains('id')) {
          modifiedFields.add('id');
        }
      }

      if (student.name.toLowerCase() != name.toLowerCase()) {
        if (!modifiedFields.contains('name')) {
          modifiedFields.add('name');
        }
      }

      if (student.surname.toLowerCase() != surname.toLowerCase()) {
        if (!modifiedFields.contains('surname')) {
          modifiedFields.add('surname');
        }
      }

      if (student.regNumber != reg) {
        if (!modifiedFields.contains('regNumber')) {
          modifiedFields.add('regNumber');
        }
      }

      if (student.class_.toLowerCase() != classes.toLowerCase()) {
        if (!modifiedFields.contains('class_')) {
          modifiedFields.add('class_');
        }
      }

      if (student.gender.toLowerCase() != gender.toLowerCase()) {
        if (!modifiedFields.contains('gender')) {
          modifiedFields.add('gender');
        }
      }

      if (student.age != age) {
        if (!modifiedFields.contains('age')) {
          modifiedFields.add('age');
        }
      }

      if (student.phoneNumber != phone) {
        if (!modifiedFields.contains('phoneNumber')) {
          modifiedFields.add('phoneNumber');
        }
      }

      if (student.paymentStatus != status) {
        if (!modifiedFields.contains('paymentStatus')) {
          modifiedFields.add('paymentStatus');
        }
      }

      if (student.termId != globalTermId) {
        if (!modifiedFields.contains('termId')) {
          modifiedFields.add('termId');
        }
      }
      if (!(student.terms!.contains(globalTermId))) {
        if (!modifiedFields.contains('terms')) {
          modifiedFields.add('terms');
        }
      }
      if (_physicalAddressController.text.toLowerCase().isNotEmpty) {
        if (student.physicalAddress?.toLowerCase() !=
            _physicalAddressController.text.toLowerCase()) {
          if (!modifiedFields.contains('physicalAddress')) {
            modifiedFields.add('physicalAddress');
          }
        }
      }

      if (_formerSchoolController.text.toLowerCase().isNotEmpty) {
        if (student.formerSchool?.toLowerCase() !=
            _formerSchoolController.text.toLowerCase()) {
          if (!modifiedFields.contains('formerSchool')) {
            modifiedFields.add('formerSchool');
          }
        }
      }

      if (_religionController.text.toLowerCase().isNotEmpty) {
        if (student.religion?.toLowerCase() !=
            _religionController.text.toLowerCase()) {
          if (!modifiedFields.contains('religion')) {
            modifiedFields.add('religion');
          }
        }
      }

      if (_denominationController.text.toLowerCase().isNotEmpty) {
        if (student.denomination?.toLowerCase() !=
            _denominationController.text.toLowerCase()) {
          if (!modifiedFields.contains('denomination')) {
            modifiedFields.add('denomination');
          }
        }
      }

      if (_studentIdNumberController.text.toLowerCase().isNotEmpty) {
        if (student.studentIdNumber?.toLowerCase() !=
            _studentIdNumberController.text.toLowerCase()) {
          if (!modifiedFields.contains('studentIdNumber')) {
            modifiedFields.add('studentIdNumber');
          }
        }
      }

      if (_nationalIdNumberController.text.toLowerCase().isNotEmpty) {
        if (student.nationalIdNumber?.toLowerCase() !=
            _nationalIdNumberController.text.toLowerCase()) {
          if (!modifiedFields.contains('nationalIdNumber')) {
            modifiedFields.add('nationalIdNumber');
          }
        }
      }

      if (_nationalityController.text.toLowerCase().isNotEmpty) {
        if (student.nationality?.toLowerCase() !=
            _nationalityController.text.toLowerCase()) {
          if (!modifiedFields.contains('nationality')) {
            modifiedFields.add('nationality');
          }
        }
      }

      if (_districtController.text.toLowerCase().isNotEmpty) {
        if (student.district?.toLowerCase() !=
            _districtController.text.toLowerCase()) {
          if (!modifiedFields.contains('district')) {
            modifiedFields.add('district');
          }
        }
      }

      if (_previousSchoolPerformanceResultsController.text
          .toLowerCase()
          .isNotEmpty) {
        if (student.previousSchoolPerformanceResults?.toLowerCase() !=
            _previousSchoolPerformanceResultsController.text.toLowerCase()) {
          if (!modifiedFields.contains('previousSchoolPerformanceResults')) {
            modifiedFields.add('previousSchoolPerformanceResults');
          }
        }
      }

      if (_emergencyContactNameController.text.toLowerCase().isNotEmpty) {
        if (student.emergencyContactName?.toLowerCase() !=
            _emergencyContactNameController.text.toLowerCase()) {
          if (!modifiedFields.contains('emergencyContactName')) {
            modifiedFields.add('emergencyContactName');
          }
        }
      }

      if (_emergencyContactNumberController.text.toLowerCase().isNotEmpty) {
        if (student.emergencyContactNumber?.toLowerCase() !=
            _emergencyContactNumberController.text.toLowerCase()) {
          if (!modifiedFields.contains('emergencyContactNumber')) {
            modifiedFields.add('emergencyContactNumber');
          }
        }
      }

      if (_selectedValue.toString().toLowerCase().isNotEmpty) {
        if (student.healthStauts?.toLowerCase() !=
            _selectedValue.toString().toLowerCase()) {
          if (!modifiedFields.contains('healthStauts')) {
            modifiedFields.add('healthStauts');
          }
        }
      }

      if (_illnessInfoController.text.toLowerCase().isNotEmpty) {
        if (student.healthDetailedInformation?.toLowerCase() !=
            _illnessInfoController.text.toLowerCase()) {
          if (!modifiedFields.contains('healthDetailedInformation')) {
            modifiedFields.add('healthDetailedInformation');
          }
        }
      }

      if (student.exceptions != null) {
        if (!modifiedFields.contains('exceptions')) {
          modifiedFields.add('exceptions');
        }
      }

      if (student.exceptions != _selectedExceptions) {
        if (!modifiedFields.contains('exceptions')) {
          modifiedFields.add('exceptions');
        }
      }
      if (student.isNewComer != _isNewComer) {
        if (!modifiedFields.contains('isNewComer')) {
          modifiedFields.add('isNewComer');
        }
      }

      if (student.isNewComerFrom != _isNewComerFrom) {
        if (!modifiedFields.contains('isNewComerFrom')) {
          modifiedFields.add('isNewComerFrom');
        }
      }

      if (student.isNewComerUntil != _isNewComerUntil) {
        if (!modifiedFields.contains('isNewComerUntil')) {
          modifiedFields.add('isNewComerUntil');
        }
      }

      final updatedStudent = Student(
        id: id,
        name: name,
        surname: surname,

        regNumber: _regNumberController.text,
        class_: _selectedClass!,
        gender: _selectedGender!,
        age: _selectedDateOfBirth!,
        phoneNumber: _phoneController.text,
        paymentStatus: _paymentStatusController.text.toLowerCase(),
        termId: globalTermId,
        syncStatus: false, // Set syncStatus to false
        lastModified: DateTime.now(), // Set lastModified to current datetime
        operationType:
            'update', // Set operationType to 'create' // Set the global term ID
        physicalAddress: _physicalAddressController.text.isEmpty
            ? null
            : _physicalAddressController.text,
        formerSchool: _formerSchoolController.text.isEmpty
            ? null
            : _formerSchoolController.text,
        religion:
            _religionController.text.isEmpty ? null : _religionController.text,
        denomination: _denominationController.text.isEmpty
            ? null
            : _denominationController.text,
        studentIdNumber: _studentIdNumberController.text.isEmpty
            ? null
            : _studentIdNumberController.text,
        nationalIdNumber: _nationalIdNumberController.text.isEmpty
            ? null
            : _nationalIdNumberController.text,
        nationality: _nationalityController.text.isEmpty
            ? null
            : _nationalityController.text,
        district:
            _districtController.text.isEmpty ? null : _districtController.text,
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
            : _illnessInfoController.text, // Set operationType to 'update'
        // ... existing fields ...
        exceptions: _selectedExceptions, // AList<ExceptionalStudents>
        isNewComer: _isNewComer,
        isNewComerFrom: _isNewComerFrom,
        isNewComerUntil: _isNewComerUntil,
        // ...
        modifiedFields: modifiedFields,
        terms: List<String>.from(_selectedTerms), // ✅ Save Updated Terms Here
      );

      final box = await Hive.openBox<Student>('students');
      final existingStudent = box.values.cast<Student>().firstWhere(
          (c) =>
              c.name.toLowerCase() == name &&
              c.surname.toLowerCase() == surname &&
              c.regNumber.toLowerCase() == reg &&
              c.class_.toLowerCase() == classes &&
              c.gender.toLowerCase() == gender &&
              c.age == age &&
              c.phoneNumber.toLowerCase() == phone &&
              c.paymentStatus.toLowerCase() == status,
          orElse: () => Student(
                name: 'empty',
                surname: 'empty',
                class_: '',
                regNumber: '-1',
                gender: '',
                age: DateTime(1970),
                phoneNumber: '',
                paymentStatus: '',
                termId: globalTermId,
              ) // Ensure termId matches),
          );

      if (existingStudent.name != 'empty' &&
          existingStudent.surname != 'empty' &&
          existingStudent.regNumber != '-1' &&
          existingStudent.class_ != '' &&
          existingStudent.gender != '' &&
          existingStudent.age != '1970' &&
          existingStudent.phoneNumber != '' &&
          existingStudent.paymentStatus != '') {
        _showDialog('Student already exists');
        return;
      }
      final key = box.keys.firstWhere((k) => box.get(k) == student);
      await box.put(key, updatedStudent);

      // Open the student_payments box
      final paymentBox = await Hive.openBox<StudentPayment>('student_payments');

      // Update records in the studentPayments model where termId == globalTermId
      // Your logic for fetching the global term ID
      final paymentsToUpdate = paymentBox.values.where((payment) {
        return student.terms!.contains(payment.termId) &&
            payment.studentName.toLowerCase() == student.name.toLowerCase() &&
            payment.studentSurname.toLowerCase() ==
                student.surname.toLowerCase() &&
            payment.studentClass.toLowerCase() == student.class_.toLowerCase();
      }).toList();

      for (var payment in paymentsToUpdate) {
        final updatedPayment = payment.copyWith(
          studentName: updatedStudent.name,
          studentSurname: updatedStudent.surname,
          studentClass: updatedStudent.class_,
          termId: payment.termId, // 🔁 Retain each termId
          syncStatus: false, // Set syncStatus to false
          lastModified: DateTime.now(), // Set lastModified to current datetime
          operationType: 'update', // Set operationType to 'update'
        );

        final paymentKey =
            paymentBox.keys.firstWhere((k) => paymentBox.get(k) == payment);
        if (paymentsToUpdate.isNotEmpty) {
          await paymentBox.put(paymentKey, updatedPayment);
        }
      }

      _showDialog('Student Updated Successfully');

      setState(() {
        _foundStudent = null;
        _nameController.clear();
        _surnameController.clear();
        _regNumberController.clear();
        _phoneController.clear();
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

        // Reset the dropdown values and Date of Birth
        _selectedClass = null;
        _selectedGender = null;
        _selectedDateOfBirth = null;
        _paymentStatusController.clear();

        _nameController.clear();
        _surnameController.clear();
        _regNumberController.clear();
        _phoneController.clear();
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

        // Reset the dropdown values and Date of Birth
        _selectedClass = null;
        _selectedGender = null;
        _selectedDateOfBirth = null;
        _selectedTerms = [];

        // Reset form validation state
        _formKey.currentState?.reset();
        _selectedExceptions = [];
        _isNewComer = false;
        _isNewComerFrom = null;
        _isNewComerUntil = null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _regNumberController.dispose();

    _phoneController.dispose();
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
    _paymentStatusController.dispose();
    super.dispose();
  }
}
