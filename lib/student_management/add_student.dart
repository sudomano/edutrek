import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/exceptional_students/exceptional_students.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/PK_assignment/pk_assignment.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:zitf_system/reusable_codes/contact_utils/contact_utils.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/server/routes/class_factory.dart';
import 'package:zitf_system/server/routes/exceptions_factory.dart';
import 'package:zitf_system/server/routes/terms_factory.dart';
import 'package:zitf_system/student_management/add_student_from_client.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

enum DeviceRole { host, client }

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
  List<ExceptionalStudents> _allExceptions = [];
  List<ExceptionalStudents> _selectedExceptions = [];

  List<String> _classes = [];

  // --- New: Variables for term selection ---
  List<Terms> _availableTerms = [];
  List<String> _selectedTerms = [];
  // Stores user-selected term IDs

  bool? _isNewComer;
  bool? _isExceptional;
  DateTime? _isNewComerFrom;
  DateTime? _isNewComerUntil;

  Future<DeviceRole> _loadDeviceRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('device_role');

    if (roleStr == 'host') return DeviceRole.host;
    return DeviceRole.client; // default safe
  }

  DeviceRole? _role;
  bool _roleReady = false;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  Future<void> _initializeDevice() async {
    final role = await _loadDeviceRole();

    setState(() {
      _role = role;
      _roleReady = true;
    });

    // 🔐 SAFE: role is now known
    await _loadTerms();
    await _loadClasses();
    _loadExceptions();
    await _setInitialRegNumber();
  }

  Future<bool> _isAdminUser() async {
    try {
      final loggedInUser = getLoggedInUser();
      if (loggedInUser == null) return false;

      final role = loggedInUser.role?.toLowerCase() ?? '';

      // Define which roles have administrative privileges
      final adminRoles = [
        'admin',
        'administrator',
        'superadmin',
        'administration',
        'sub-admin',
        'subadmin'
      ];

      // Check if user's role is in the admin roles list
      return adminRoles.contains(role);
    } catch (e) {
      // If we can't determine, default to false (non-admin)
      return false;
    }
  }

  Future<void> _loadExceptions() async {
    if (!_roleReady) {
      debugPrint('⚠️ Role not ready yet');
      return;
    }

    final bool isAdmin = await _isAdminUser();
    debugPrint('🔍 Is Admin: $isAdmin');
    debugPrint('🔍 Device Role: $_role');

    if (_role == DeviceRole.host) {
      try {
        final box =
            await Hive.openBox<ExceptionalStudents>('exceptionalStudentsBox');

        // Get all exceptions
        final allExceptions = box.values.toList();
        debugPrint('📊 Total exceptions in box: ${allExceptions.length}');

        // Filter by term and status
        final filteredExceptions = allExceptions.where((e) {
          final isActive = e.exceptionStatus != null &&
              e.exceptionStatus!.toLowerCase() == 'active';
          return isActive;
        }).toList();

        debugPrint(
            '📊 Exceptions after status filter: ${filteredExceptions.length}');

        // ✅ CORRECTED: Apply admin filter - EXCLUDE priority exceptions for non-admin
        final finalExceptions = filteredExceptions.where((e) {
          // If NOT admin, EXCLUDE priority exceptions (priorityFlag == 1)
          if (!isAdmin) {
            return e.priorityFlag != 1; // ✅ This should be != 1, not == 0
          }
          // Admin sees everything
          return true;
        }).toList();

        setState(() {
          _allExceptions = finalExceptions;
        });

        debugPrint('📊 Final exceptions loaded: ${_allExceptions.length}');
        debugPrint(
            '📊 Priority exceptions hidden for non-admin: ${filteredExceptions.length - finalExceptions.length}');
      } catch (e) {
        debugPrint('❌ Error loading exceptions from Hive: $e');
        setState(() => _allExceptions = []);
      }
    } else {
      // Client mode
      try {
        debugPrint('📡 Fetching exceptions from server ');
        final exceptions =
            await ExceptionalStudentApiService.fetchActiveExceptions(
                globalTermId!);

        debugPrint('📊 Received ${exceptions.length} exceptions from server');

        // ✅ CORRECTED: Apply admin filter - EXCLUDE priority exceptions for non-admin
        final filteredExceptions = exceptions.where((e) {
          // If NOT admin, EXCLUDE priority exceptions (priorityFlag == 1)
          if (!isAdmin) {
            final priority = e.priorityFlag ?? 0; // Handle null

            return priority != 1;
          }
          // Admin sees everything
          return true;
        }).toList();

        setState(() {
          _allExceptions = filteredExceptions;
        });

        debugPrint('📊 Final exceptions loaded: ${_allExceptions.length}');
        debugPrint(
            '📊 Priority exceptions hidden for non-admin: ${exceptions.length - filteredExceptions.length}');
      } catch (e) {
        debugPrint('❌ Error loading exceptions from server: $e');
        setState(() => _allExceptions = []);
        _showDialog(
          'Unable to load exceptions from host.\n'
          'You cannot add students while offline.',
        );
      }
    }
  }

  Future<void> _loadTerms() async {
    if (!_roleReady) return;

    final now = DateTime.now();

    if (_role == DeviceRole.host) {
      final termsBox = await Hive.openBox<Terms>('terms');
      final terms = termsBox.values.toList();
      final sorted = sortTermsByStatusAndStartDate(terms);

      setState(() {
        _availableTerms = sorted;

        // ✅ SELECT ONLY NON-EXPIRED TERMS
        _selectedTerms = sorted
            .where((t) => t.endDate != null && t.endDate!.isAfter(now))
            .map((t) => t.termId!)
            .toList();
      });
    } else {
      try {
        final terms = await TermApiService.fetchTerms();
        final sorted = sortTermsByStatusAndStartDate(terms);

        setState(() {
          _availableTerms = sorted;

          // ✅ SELECT ONLY NON-EXPIRED TERMS
          _selectedTerms = sorted
              .where((t) => t.endDate != null && t.endDate!.isAfter(now))
              .map((t) => t.termId!)
              .toList();
        });
      } catch (e) {
        setState(() {
          _availableTerms = [];
          _selectedTerms = [];
        });

        _showDialog(
          'Unable to load terms from host.\n'
          'You cannot add students while offline.',
        );
      }
    }
  }

  Future<void> _loadClasses() async {
    if (!_roleReady || globalTermId == null) return;

    if (_role == DeviceRole.host) {
      // HOST → Hive
      final box = await Hive.openBox<Classes>('classes');
      setState(() {
        _classes = box.values
            .where((c) => c.terms!.contains(globalTermId))
            .map((c) => c.className)
            .toList();
      });
    } else {
      // CLIENT → API ONLY
      try {
        final classes = await ClassApiService.fetchClasses(globalTermId!);
        setState(() => _classes = classes);
      } catch (e) {
        setState(() => _classes = []);
        _showDialog(
          'Unable to load classes from host.\n'
          'You cannot add students while offline.',
        );
      }
    }
  }

  Future<void> _setInitialRegNumber() async {
    final box = await Hive.openBox<Student>('students');
    setState(() {
      _regNumberController.text = (box.length + 1).toString();
    });
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Student Submission Feedback"),
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
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Add Student',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Add this near the top of your form
            FutureBuilder<bool>(
              future: _isAdminUser(),
              builder: (context, snapshot) {
                final isAdmin = snapshot.data ?? false;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isAdmin ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAdmin
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAdmin ? Icons.verified : Icons.person,
                        color: isAdmin ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAdmin
                            ? '🔑 Administrator Access - All exceptions visible'
                            : '👤 Standard Access - Priority exceptions hidden',
                        style: TextStyle(
                          color: isAdmin
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight:
                              isAdmin ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text("Is Newcomer?"),
              value: _isNewComer ?? false,
              onChanged: (value) {
                setState(() {
                  _isNewComer = value;
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
                if (date != null && date.isAfter(DateTime.now())) {
                  setState(() {
                    _isNewComerUntil = date;
                  });
                } else {
                  _showDialog('Newcomer Until must be in the future');
                }
              }),
            ],

            CheckboxListTile(
              title: const Text("Is Exceptional?"),
              value: _isExceptional ?? false,
              onChanged: (value) {
                setState(() {
                  _isExceptional = value;
                  if (value == false) {
                    _selectedExceptions = []; // ✅ Reset selected exceptions
                  }
                });
              },
            ),

            // In the build method, update this section:
            if (_isExceptional == true) ...[
              const Center(
                  child: Text('Exceptional Info',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              FutureBuilder<bool>(
                future: _isAdminUser(),
                builder: (context, snapshot) {
                  final isAdmin = snapshot.data ?? false;

                  // ✅ CORRECTED: Filter exceptions based on admin status
                  final filteredExceptions = _allExceptions.where((e) {
                    // If NOT admin, EXCLUDE priority exceptions (priorityFlag == 1)
                    if (!isAdmin) {
                      return e.priorityFlag != 1; // ✅ CORRECTED
                    }
                    return true; // Admin sees everything
                  }).toList();

                  if (filteredExceptions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isAdmin ? Icons.warning_amber : Icons.lock,
                            color: isAdmin ? Colors.orange : Colors.grey,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isAdmin
                                ? 'No exceptions available. Create some first.'
                                : 'No exceptions available for your account level.\nPriority exceptions are restricted to Administrators.',
                            style: TextStyle(
                              color: isAdmin
                                  ? Colors.orange
                                  : Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return MultiSelectDialogField<ExceptionalStudents>(
                    items: filteredExceptions
                        .map((e) => MultiSelectItem<ExceptionalStudents>(
                            e,
                            isAdmin && e.priorityFlag == 1
                                ? '🔴 ${e.exceptionName} (Priority)'
                                : '${e.exceptionName}'))
                        .toList(),
                    title: Text(isAdmin
                        ? "Select Exception(s) - Admin View"
                        : "Select Exception(s) - Standard View"),
                    selectedColor: Colors.blue,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                    buttonText: Text(
                      isAdmin
                          ? "Select Exception(s) (${filteredExceptions.length} available)"
                          : "Select Exception(s) (${filteredExceptions.length} available)",
                      style: const TextStyle(fontSize: 16),
                    ),
                    onConfirm: (values) {
                      setState(() {
                        _selectedExceptions =
                            List<ExceptionalStudents>.from(values);
                      });
                    },
                    initialValue: _selectedExceptions,
                  );
                },
              ),
            ],
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

            // --- New: Term Selection Section ---
            const Center(
              child: Text('Select Terms (optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildTermSelection(),
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

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validateAndSubmit,
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

  Widget _buildTermSelection() {
    return _availableTerms.isEmpty
        ? const Text('No terms available')
        : Column(
            children: _availableTerms.map((term) {
              final isExpired = term.endDate != null &&
                  term.endDate!.isBefore(DateTime.now());

              return CheckboxListTile(
                title: Text(
                  term.termName ?? term.termId!,
                  style: TextStyle(
                    color: isExpired ? Colors.grey : null,
                    decoration: isExpired ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: term.endDate != null
                    ? Text('Ends: ${term.endDate!.toLocal()}')
                    : null,
                value: _selectedTerms.contains(term.termId),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTerms.add(term.termId!);
                    } else {
                      _selectedTerms.remove(term.termId);
                    }
                  });
                },
              );
            }).toList(),
          );
  }

  List<Terms> sortTermsByStatusAndStartDate(List<Terms> terms) {
    final now = DateTime.now();

    terms.sort((a, b) {
      final aExpired = a.endDate != null && a.endDate!.isBefore(now);
      final bExpired = b.endDate != null && b.endDate!.isBefore(now);

      // ✅ Active terms first
      if (aExpired != bExpired) {
        return aExpired ? 1 : -1;
      }

      // ✅ Same group → sort by startDate
      final aStart = a.startDate ?? DateTime(1900);
      final bStart = b.startDate ?? DateTime(1900);

      return bStart.compareTo(aStart); // newest first
    });

    return terms;
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

  Future<void> _validateAndSubmit() async {
    debugPrint("Validating student registration number...");
    final name = _nameController.text.toLowerCase();
    final surname = _surnameController.text.toLowerCase();
    final className = _selectedClass?.toLowerCase() ?? '';
    final box = await Hive.openBox<Student>('students');
    // Check if a student with the same details already exists
    final existingStudents = box.values.any((student) =>
        student.name.toLowerCase() == name &&
        student.surname.toLowerCase() == surname &&
        student.class_.toLowerCase() == className);

    if (existingStudents) {
      debugPrint(
          "Student ID number is empty. Prompting user for confirmation.");
      _showProceedWithoutSameStudentDialog(context);
    }

    if (_studentIdNumberController.text.isEmpty) {
      debugPrint(
          "Student ID number is empty. Prompting user for confirmation.");
      _showProceedWithoutRegNumberDialog(context);
    } else {
      debugPrint("Student ID number provided. Proceeding to validate inputs.");
      _validateInputs();
    }
  }

  Future<void> _showProceedWithoutRegNumberDialog(BuildContext context) async {
    debugPrint("Showing dialog: Proceed without registration number?");

    bool proceed = await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Missing Registration Number'),
          content: const Text(
            'The student registration number is required. Do you want to proceed without it?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint("User selected: No");
                Navigator.of(context).pop(false); // Return "false"
              },
              child: const Text(
                'No',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                debugPrint("User selected: Yes");
                Navigator.of(context).pop(true); // Return "true"
              },
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );

    if (proceed) {
      debugPrint("Proceeding without student registration number.");
      _validateInputs();
    } else {
      debugPrint("User canceled, prompting to enter registration number.");
      _showDialog('Please enter the student registration number.');
    }
  }

  Future<void> _showProceedWithoutSameStudentDialog(
      BuildContext context) async {
    debugPrint("Showing dialog: Proceed with the SAME USER INFO?");

    bool proceed = await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('SAME USER INFOMATION WAS FOUND'),
          content: const Text(
            'The student NAME - SURNAME - CLASS exists. Do you want to proceed anyways?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint("User selected: No");
                Navigator.of(context).pop(false); // Return "false"
              },
              child: const Text(
                'No',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                debugPrint("User selected: Yes");
                Navigator.of(context).pop(true); // Return "true"
              },
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );

    if (proceed) {
      debugPrint("Proceeding with student registration.");
      _validateInputs();
    } else {
      debugPrint("User canceled, prompting to enter different user info.");
      _showDialog('Please enter the student another student.');
    }
  }

  void _validateInputs() {
    if (_selectedClass == null || _selectedClass!.isEmpty) {
      debugPrint("Validation failed: Class is required");
      _showDialog('Class is Required');
      return;
    }

    if (_nameController.text.isEmpty) {
      debugPrint("Validation failed: Name is required");
      _showDialog('Name is Required');
      return;
    }

    if (_surnameController.text.isEmpty) {
      debugPrint("Validation failed: Surname is required");
      _showDialog('Surname is Required');
      return;
    }

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      debugPrint("Validation failed: Gender is required");
      _showDialog('Gender is Required');
      return;
    }

    if (_selectedDateOfBirth == null) {
      debugPrint("Validation failed: Date of Birth is required");
      _showDialog('Date Of Birth is Required');
      return;
    }

    // If all validations pass, proceed to submit
    _submit();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (globalTermId != null) {
        final name = _nameController.text.toLowerCase();
        final surname = _surnameController.text.toLowerCase();
        final className = _selectedClass?.toLowerCase() ?? '';
        final gender = _selectedGender?.toLowerCase() ?? '';
        final studentIdNumber = _studentIdNumberController.text.toLowerCase();
        final regnumber = uuid.v4();

        // ⭐ FIX: Only check duplicates on HOST devices
        if (_role == DeviceRole.host) {
          final box = await Hive.openBox<Student>('students');

          // Check if a student with the same details already exists
          final existingStudents = box.values.where((student) =>
              student.name.toLowerCase() == name &&
              student.surname.toLowerCase() == surname &&
              student.class_.toLowerCase() == className &&
              student.gender.toLowerCase() == gender);

          // Check for student ID duplication
          final duplicateId = box.values.any((student) =>
              student.studentIdNumber?.toLowerCase() == studentIdNumber);

          final duplicateDetails = box.values.any((student) =>
              student.name.toLowerCase() == name &&
              student.surname.toLowerCase() == surname &&
              student.class_.toLowerCase() == className &&
              student.gender.toLowerCase() == gender);

          if (_physicalAddressController.text.isEmpty) {
            _showDialog('Physical Address is Required');
            return;
          }
          if (_phoneController.text.isEmpty) {
            _showDialog('Parent Phone Number is Required');
            return;
          }
          if (_parentNameController.text.isEmpty) {
            _showDialog('Parent Name is Required');
            return;
          }

          if (existingStudents.isNotEmpty) {
            _showDialog('Student already exists');
            return;
          }
          if (duplicateId) {
            _showDialog('Registration Number already exists');
            return;
          }
          if (duplicateDetails) {
            _showDialog(
                'Student With Same Name, Surname, Class, Gender already exists');
            return;
          }
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
        modifiedFields.add('terms');
        modifiedFields.add('isNewComer');
        modifiedFields.add('isNewComerFrom');
        modifiedFields.add('isNewComerUntil');
        modifiedFields.add('exceptions');

        List<ExceptionalStudents>? exceptions =
            _selectedExceptions.isNotEmpty ? _selectedExceptions : null;

        // Determine the terms to use: either the selected ones or default to globalTermId.
        final List<String> termsToSave =
            _selectedTerms.isNotEmpty ? _selectedTerms : [globalTermId!];

        // Save a student record for each term.
        final newStudent = Student(
          exceptions: exceptions,
          id: _role == DeviceRole.host
              ? newId
              : null, // ⭐ FIX: Client gets NULL id
          name: name,
          surname: surname,
          regNumber: _regNumberController.text,
          class_: _selectedClass!,
          gender: _selectedGender!,
          age: _selectedDateOfBirth!,
          phoneNumber: _phoneController.text,
          paymentStatus: _parentNameController.text,
          termId: globalTermId,
          syncStatus: _role == DeviceRole.host
              ? true
              : false, // ⭐ FIX: Host = synced, Client = pending
          lastModified: DateTime.now(),
          operationType: 'create',
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
          studentIdNumber: _studentIdNumberController.text.isEmpty
              ? regnumber
              : _studentIdNumberController.text,
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
          terms: _selectedTerms.isNotEmpty ? _selectedTerms : [globalTermId!],
          isNewComer: _isNewComer ?? false,
          isNewComerFrom: _isNewComerFrom,
          isNewComerUntil: _isNewComerUntil,
        );

        // ⭐ FIX: HOST saves locally, CLIENT only syncs to host
        if (_role == DeviceRole.host) {
          final box = await Hive.openBox<Student>('students');
          await box.add(newStudent);
          await saveParentContact(newStudent);
          _showDialog('✅ Student saved successfully (HOST mode)');
          _reloadFormWithNavigator();
        } else {
          // ⭐ CLIENT: Only sync to host - NO local save
          try {
            _showDialog('⏳ Syncing student to host...');

            final response = await StudentApiService.sendStudents([
              studentsToJson(newStudent),
            ]);

            final inserted = response['insertedStudents'] as List;
            if (inserted.isNotEmpty) {
              _showDialog('✅ Student successfully synced to host!');
              debugPrint('✅ Student synced to host');
              _reloadFormWithNavigator();
            } else {
              _showDialog(
                  '⚠️ Student could not be synced. Please check connection and try again.');
              debugPrint('⚠️ Host accepted request but returned no data');
            }
          } catch (e) {
            // ⭐ CLIENT: On failure, show error - DO NOT save locally
            _showDialog('❌ Failed to sync student.\n'
                'Host may be unreachable or offline.\n'
                'Please check your network connection and try again.\n\n'
                'Error: $e');
            debugPrint('❌ Client sync failed (NO local save): $e');
          }
        }
      } else {
        _showDialog(
            'No Selected Term Was Found. Create A New Term or Switch Terms To An Existing One.');
      }
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

  void _reloadFormWithNavigator() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AddStudentScreen()),
    );
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
