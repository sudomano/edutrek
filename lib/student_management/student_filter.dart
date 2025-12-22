import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // For PDF preview
import 'package:printing/printing.dart'; // For PDF preview and printing
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/all_payments/filter_payments.dart';
import 'package:zitf_system/arrears_and_prepayments/arrears_and_prepayments.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:path/path.dart' as path;
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart'; // To handle file name extensions
import 'package:excel/excel.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:zitf_system/student_management/create_students/multi_class_selection.dart';
import 'package:zitf_system/student_payments/view_all_paid_students.dart';

class ViewStudentsScreenfilter extends StatefulWidget {
  final String? selectedClassName; // <- Add this line #######################

  const ViewStudentsScreenfilter({Key? key, this.selectedClassName})
      : super(key: key);

  @override
  _ViewStudentsScreenStatefilter createState() =>
      _ViewStudentsScreenStatefilter();
}

class _ViewStudentsScreenStatefilter extends State<ViewStudentsScreenfilter> {
  String? _selectedGender;
  String? _selectedSurname;
  String? _selectedReg;

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSortAscending = true;
  List<String> _selectedClasses = [];

  List<Student> _filteredStudents = [];
  List<String> _classes = [];
  List<String> _genders = ['All', 'Male', 'Female'];

  String? _selectedTermId;

  /// we change here 06/05/25
  List<String> _termIds = [];

  /// we change here 06/05/25

  bool _isSyncing = false;

  String _progressMessage = '';
  final GlobalKey _studentsTableKey = GlobalKey();

  bool _filterByExceptional = false;
  bool _filterByNewcomer = false;

  final TextEditingController _surnameController = TextEditingController();

  final TextEditingController _regNumberController = TextEditingController();

  Future<List<Student>> _studentsFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;
  bool get _isHostIpMissing => _hostIp == null || _hostIp!.isEmpty;

  List<Student>? _cachedServerStudents;
  List<Terms>? _cachedServerTerms;

  List<Student>? _cachedFilteredStudents;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.selectedClassName != null) {
        _selectedClasses = [widget.selectedClassName!];

        await _filterStudents();

        Future.delayed(const Duration(milliseconds: 300), () {
          if (_studentsTableKey.currentContext != null) {
            Scrollable.ensureVisible(
              _studentsTableKey.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } else {}
        });
      } else {}
    });

    _initialize();
  }

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Student Manipulation Feedback"),
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

  Future<void> _initialize() async {
    _role = await getDeviceRole();

    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('host_ip') ?? '192.168.68.2';

    setState(() {
      _studentsFuture = (_role == DeviceRole.host)
          ? _fetchStudentsFromHive()
          : _fetchStudentsFromServer();
    });
  }

  Future<List<Student>> _fetchStudentsFromHive() async {
    final box = await Hive.openBox<Student>('students');
    final students = box.values.where((s) => s.termId != null).toList();
    students.sort((a, b) => a.surname.compareTo(b.surname));

    return students;
  }

  Future<List<Student>> _fetchStudentsFromServer() async {
    if (_cachedServerStudents != null) {
      return _cachedServerStudents!;
    }
    if (_isHostIpMissing) {
      debugPrint("Host IP is null, cannot fetch from server");
      if (mounted) {
        _showDialog("⚠️ Host IP not set. Please configure connection.");
      }
      return [];
    }

    try {
      final url = Uri.parse('http://$_hostIp:8080/api/students');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;

        _cachedServerStudents = jsonList
            .map((json) => studentsFromJson(Map<String, dynamic>.from(json)))
            .toList();

        return _cachedServerStudents!;
      } else {
        throw Exception('Failed to load students data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching students data: $e");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
        }
      });
      return [];
    }
  }

  // Helper to update progress message and force rebuild
  void _updateProgress(String message) {
    setState(() {
      _progressMessage = message;
    });
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isSyncing = true;
      _progressMessage = 'Fetching initial data...';
    });

    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      List<Student> allStudents = [];
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final studentBox = await Hive.openBox<Student>('students');
        final termBox = await Hive.openBox<Terms>('terms');

        allStudents = studentBox.values.toList();
        allTerms = termBox.values.toList();
      } else {
        if (_isHostIpMissing) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() => _isSyncing = false);
          return;
        }
        if (_cachedServerTerms == null || _cachedServerStudents == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());
          final studentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/students'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200 &&
              studentsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();
            final studentsJsonString =
                await studentsResponse.transform(utf8.decoder).join();

            final termsList = jsonDecode(termsJsonString) as List;
            final studentsList = jsonDecode(studentsJsonString) as List;

            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
            _cachedServerStudents = studentsList
                .map(
                    (json) => studentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms or students data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
        allStudents = _cachedServerStudents!;
      }

      // Extract term IDs
      _termIds = allTerms.map((e) => e.termId.toString()).toSet().toList();
      _selectedTermId = _termIds.contains(globalTermId)
          ? globalTermId
          : (_termIds.isNotEmpty ? _termIds.first : null);

      // Filter students by selected term
      final filtered = allStudents
          .where((student) =>
              student.terms != null && student.terms!.contains(_selectedTermId))
          .toList();

      // Extract class names
      _classes = ['All'];
      _classes.addAll(filtered.map((s) => s.class_).toSet().toList());
      _selectedClasses = ['All'];

      setState(() {
        _isSyncing = false;
      });
    } catch (error) {
      print("Error fetching initial data: $error");
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _filterStudents() async {
    setState(() {
      _isSyncing = true;
      _progressMessage = 'Fetching Students From Database ...';
    });
    try {
      List<Student> allStudents;

      if (_role == DeviceRole.host) {
        final studentBox = Hive.box<Student>('students');
        allStudents = studentBox.values
            .where(
                (s) => s.termId != null && s.terms!.contains(_selectedTermId))
            .toList();
      } else {
        // Use previously fetched server data
        allStudents = await _studentsFuture;
        allStudents = allStudents
            .where((s) => s.terms!.contains(_selectedTermId))
            .toList();
      }

      List<Student> filtered = allStudents;

      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
        filtered =
            filtered.where((s) => _selectedClasses.contains(s.class_)).toList();
      }

      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains("All")) {
        filtered = filtered.where((student) {
          return _selectedClasses.contains(student.class_);
        }).toList();
      }

      if (_selectedGender != null && _selectedGender != "All") {
        filtered = filtered
            .where((student) => student.gender == _selectedGender)
            .toList();
      }

      if (_selectedSurname?.isNotEmpty ?? false) {
        filtered = filtered
            .where((student) => student.surname
                .toLowerCase()
                .contains(_selectedSurname!.toLowerCase()))
            .toList();
      }

      if (_selectedReg?.isNotEmpty ?? false) {
        filtered = filtered
            .where((s) => s.studentIdNumber!
                .toLowerCase()
                .contains(_selectedReg!.toLowerCase()))
            .toList();
      }

      if (_selectedStartDate != null || _selectedEndDate != null) {
        filtered = filtered.where((s) {
          final dob = s.age;
          if (_selectedStartDate != null && _selectedEndDate != null) {
            return dob.isAfter(_selectedStartDate!) &&
                dob.isBefore(_selectedEndDate!);
          } else if (_selectedStartDate != null) {
            return dob.isAfter(_selectedStartDate!);
          } else {
            return dob.isBefore(_selectedEndDate!);
          }
        }).toList();
      }
      if (_filterByExceptional) {
        filtered = filtered
            .where((s) => s.exceptions != null && s.exceptions!.isNotEmpty)
            .toList();
      }

      if (_filterByNewcomer) {
        filtered = filtered.where((s) => s.isNewComer == true).toList();
      }

      filtered.sort((a, b) => _isSortAscending
          ? a.surname.compareTo(b.surname)
          : b.surname.compareTo(a.surname));

      setState(() {
        _filteredStudents = filtered;
        _cachedFilteredStudents = filtered;
      });

      // ✅ After filtering, show a message if no students are found
      if (filtered.isEmpty) {
        _showDialog('❗ No students found for the selected criteria.');
      } else if (_studentsTableKey.currentContext != null) {
        Scrollable.ensureVisible(
          _studentsTableKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } catch (error) {
      debugPrint("Error during filtering: $error");
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _isSortAscending = !_isSortAscending;
      _filterStudents(); // Reapply the filter to reflect the sorting order change
    });
  }

  Future<Uint8List> generateStudentsPDF(List<Student> students) async {
    final pdf = pw.Document();

    final headers = [
      'Name',
      'Surname',
      'Class',
      'Gender',
      'Date of Birth',
      'Address',
      'Parent Name',
      'Parent Phone', // New column for terms
    ];
    final chunkSize = 300; // Customize as needed (keep below 500 rows/page)

    for (int i = 0; i < _filteredStudents.length; i += chunkSize) {
      final chunk = _filteredStudents.skip(i).take(chunkSize).toList();
      final data = chunk.map((student) {
        return [
          student.name,
          student.surname,
          student.class_,
          student.gender,
          DateFormat('yyyy-MM-dd').format(student.age ?? DateTime.now()),
          student.physicalAddress,
          student.paymentStatus,
          student.phoneNumber,
        ];
      }).toList();

      // Create a PDF page

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32), // Add margins for layout
          build: (pw.Context context) {
            return [
              if (i == 0) ...[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Title of the page
                    pw.Text('Student Information',
                        style: const pw.TextStyle(fontSize: 24)),
                    pw.SizedBox(height: 20),
                  ],
                ),
                // The table should now automatically split across multiple pages
              ],
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerStyle: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                border: pw.TableBorder.all(color: PdfColors.black),
                columnWidths: {
                  0: const pw.FlexColumnWidth(), // Class Name column
                  1: const pw.FlexColumnWidth(), // Created On column
                  2: const pw.FlexColumnWidth(), // Current Term column
                  3: const pw.FlexColumnWidth(), // Class Name column
                  4: const pw.FlexColumnWidth(), // Created On column
                  5: const pw.FlexColumnWidth(), // Current Term column
                  6: const pw.FlexColumnWidth(),
                  7: const pw.FlexColumnWidth(), // Created On column
                  // Created On column
                },
              ),
            ];
          },
        ),
      );
    }
    return pdf.save();
  }

  Future<void> savePDFToFile(
      BuildContext context, Uint8List pdfBytes, String fileName) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        // Get external storage directory
        Directory? directory = await getExternalStorageDirectory();

        if (directory != null) {
          // Define the path to the Download folder
          final downloadDir = Directory('/storage/emulated/0/Download');

          // Create the directory if it doesn't exist
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
            _showDialog("Download directory created.");
          }

          // Define the initial file path
          String filePath = path.join(downloadDir.path, '$fileName.pdf');
          int fileIndex = 1;

          // Check if a file with the same name exists and add an index if necessary
          while (await File(filePath).exists()) {
            filePath = path.join(downloadDir.path, '$fileName-$fileIndex.pdf');
            fileIndex++;
          }

          // Save the PDF file
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          // Show success notification
          _showDialog("PDF saved to $filePath");
        } else {
          // Show error notification
          _showDialog("Error: External storage directory not found.");
        }
      } else {
        // Show permission denied notification
        _showDialog("Permission denied for storage access.");
      }
    } catch (e) {
      // Show error notification
      _showDialog("Error saving PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'View Students Filter',
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Bold font
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        ),
        actions: [
          Tooltip(
            message: 'View Student Receipts',
            child: IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color.fromARGB(255, 245, 164, 2),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewAllStudentPayments(),
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: 'View detailed payments',
            child: IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color.fromARGB(255, 0, 255, 81),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewByScreen(),
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: 'View detailed arrear',
            child: IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color.fromARGB(255, 255, 0, 0),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ArrearsAndPrepayments(),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white,
            ),
            onPressed: () async {
              final studentsToExport =
                  _cachedFilteredStudents ?? _filteredStudents;

              Uint8List pdfBytes = await generateStudentsPDF(studentsToExport);

              // Show the PDF preview and confirm if the user wants to save it
              bool confirmSave =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirmSave) {
                // Save the PDF after confirmation
                await savePDFToFile(context, pdfBytes, 'students_report');
              }
            },
          ),
          IconButton(
              icon: const Icon(
                Icons.edit_document,
                color: Colors.white,
              ),
              onPressed: () async {
                generateAndSaveSpreadsheet();
              }),
        ],
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0, // Optional: Add a subtle shadow
      ),
      body: Center(
        child: Container(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCard(
                        title: 'Select Term',
                        child: DropdownButtonFormField<String>(
                          value: _selectedTermId,
                          hint: const Text('Select Term'),
                          onChanged: (value) {
                            setState(() {
                              if (value != null) _onTermChanged(value);
                            });
                          },
                          items: _termIds.map((termId) {
                            return DropdownMenuItem(
                              value: termId,
                              child: Text(termId),
                            );
                          }).toList(),
                        ),
                      ),
                      _buildCard(
                        title: 'View by Class',
                        child: _buildClassDropdown(),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Surname',
                        child: _buildSurnameField(),
                      ),
                      _buildCard(
                        title: 'View by Registration Number',
                        child: _buildRegField(),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Gender',
                        child: _buildGenderDropdown(),
                      ),
                      const SizedBox(height: 20),
                      _buildCard(
                        title: 'View by Date of Birth',
                        child: _buildDOBPicker(),
                      ),
                      _buildCard(
                        title: 'Filter by Special Categories',
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title:
                                  const Text("Show Only Exceptional Students"),
                              value: _filterByExceptional,
                              onChanged: (value) {
                                setState(() {
                                  _filterByExceptional = value!;
                                });
                              },
                            ),
                            CheckboxListTile(
                              title: const Text("Show Only Newcomer Students"),
                              value: _filterByNewcomer,
                              onChanged: (value) {
                                setState(() {
                                  _filterByNewcomer = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: _isSyncing
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed:
                                    _filterStudents, // Disable button when loading
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                  backgroundColor:
                                      const Color.fromARGB(255, 232, 236, 242),
                                  textStyle: const TextStyle(
                                      fontSize: 18), // Button background color
                                ),
                                child: const Text('Apply Filters'),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sort by Surname: ',
                              style: TextStyle(fontSize: 16)),
                          IconButton(
                            icon: Icon(_isSortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward),
                            onPressed: _toggleSortOrder,
                          ),
                          const SizedBox(height: 20),
                          // Records Found Header
                        ],
                      ),
                      Text(
                        'Records Found: ${_filteredStudents.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _filteredStudents.isEmpty
                          ? const Center(
                              child: Text(
                                'No students found.',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 16),
                              ),
                            )
                          : _buildStudentsTable(), // Records Found Header
                    ],
                  ),
                ),
                if (_isSyncing)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(32),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                _progressMessage,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildClassDropdown() {
    return MultiSelectChip(
      items: _classes,
      initialSelectedItems: _selectedClasses,
      onSelectionChanged: (selectedClasses) {
        setState(() {
          _selectedClasses = selectedClasses;
        });
      },
    );
  }

  Widget _buildSurnameField() {
    return TextField(
      controller: _surnameController,
      decoration: InputDecoration(
        labelText: 'Search Student by Surname',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedSurname = value;
        });
      },
    );
  }

  Widget _buildRegField() {
    return TextField(
      controller: _regNumberController,
      decoration: InputDecoration(
        labelText: 'Search Student by Reg Number',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _selectedReg = value;
        });
      },
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      hint: const Text('Select Gender'),
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
      items: _genders.map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDOBPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Date of Birth Period:',
            style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context, true),
                child: Text(_selectedStartDate != null
                    ? 'From: ${_selectedStartDate!.toLocal()}'.split(' ')[0]
                    : 'From: Select Start Date'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context, false),
                child: Text(_selectedEndDate != null
                    ? 'To: ${_selectedEndDate!.toLocal()}'.split(' ')[0]
                    : 'To: Select End Date'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Widget _buildStudentsTable() {
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();

    // Horizontal scroll increment value
    const double scrollIncrement = 100.0; // You can adjust the value as needed

    // Function to scroll horizontally by increment
    void _scrollLeft() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset - scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Function to scroll horizontally by decrement
    void _scrollRight() {
      horizontalScrollController.animateTo(
        horizontalScrollController.offset + scrollIncrement,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    return Container(
      // ############################
      key: _studentsTableKey, // <== ADD THIS KEY #######################

      child: Stack(
        children: [
          // Main table with vertical and horizontal scrolling
          Scrollbar(
            thumbVisibility: true,
            controller: horizontalScrollController,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: Scrollbar(
                thumbVisibility: true,
                controller: verticalScrollController,
                child: SingleChildScrollView(
                  controller: verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Student Registration Number')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Surname')),
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Gender')),
                      DataColumn(label: Text('Date of Birth')),
                      DataColumn(label: Text('Nationality')),
                      DataColumn(label: Text('District')),
                      DataColumn(label: Text('National ID Number')),
                      DataColumn(label: Text('Student Registration Position')),
                      DataColumn(label: Text('Physical Address')),
                      DataColumn(label: Text('Parent Name')),
                      DataColumn(label: Text('Parent Phone Number')),
                      DataColumn(label: Text('Religion')),
                      DataColumn(label: Text('Denomination')),
                      DataColumn(label: Text('Former School')),
                      DataColumn(label: Text('Former School Results')),
                      DataColumn(label: Text('Emergency Contact Name')),
                      DataColumn(label: Text('Emergency Contact Number')),
                      DataColumn(label: Text('Health Status')),
                      DataColumn(label: Text('Health Detailed Information')),
                      DataColumn(label: Text('Is Exceptional?')),
                      DataColumn(label: Text('Exceptions')),
                      DataColumn(label: Text('Is Newcomer?')),
                      DataColumn(label: Text('Newcomer From')),
                      DataColumn(label: Text('Newcomer Until')),

                      DataColumn(label: Text('Terms Associated')), // New column

                      //  DataColumn(label: Text(' modified Information')),
                    ],
                    rows: _filteredStudents.map((student) {
                      return DataRow(
                        cells: [
                          DataCell(Text(student.studentIdNumber.toString())),
                          DataCell(Text(student.name)),
                          DataCell(Text(student.surname)),
                          DataCell(Text(student.class_)),
                          DataCell(Text(student.gender)),
                          DataCell(Text(student.age.toString().split(' ')[0])),
                          DataCell(Text(student.nationality.toString())),
                          DataCell(Text(student.district.toString())),
                          DataCell(Text(student.nationalIdNumber.toString())),
                          DataCell(Text(student.regNumber.toString())),
                          DataCell(Text(student.physicalAddress.toString())),
                          DataCell(Text(student.paymentStatus.toString())),
                          DataCell(Text(student.phoneNumber.toString())),
                          DataCell(Text(student.religion.toString())),
                          DataCell(Text(student.denomination.toString())),
                          DataCell(Text(student.formerSchool.toString())),
                          DataCell(Text(student.previousSchoolPerformanceResults
                              .toString())),
                          DataCell(
                              Text(student.emergencyContactName.toString())),
                          DataCell(
                              Text(student.emergencyContactNumber.toString())),
                          DataCell(Text((student.healthStauts.toString()))),
                          DataCell(Text(
                              (student.healthDetailedInformation.toString()))),
                          DataCell(
                              Text(student.exceptions != null ? 'Yes' : 'No')),
                          DataCell(Text(
                            (student.exceptions != null &&
                                    student.exceptions!.isNotEmpty)
                                ? student.exceptions!
                                    .map((e) => e.exceptionName)
                                    .join(', ')
                                : 'None',
                          )),
                          DataCell(
                              Text(student.isNewComer == true ? 'Yes' : 'No')),
                          DataCell(Text(student.isNewComerFrom != null
                              ? student.isNewComerFrom!
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0]
                              : '')),
                          DataCell(Text(student.isNewComerUntil != null
                              ? student.isNewComerUntil!
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0]
                              : '')),

                          DataCell(Text(student.terms?.join(", ") ??
                              (''))), // New field to display terms

                          // DataCell(Text(student.modifiedFields.toString())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // Floating arrow buttons for scrolling horizontally (Sticky at the bottom)
          Positioned(
            bottom: 100, // Position the arrows at the bottom
            left: 60,
            right: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left arrow button to scroll left
                FloatingActionButton(
                  onPressed: _scrollLeft,
                  child: const Icon(Icons.arrow_back),
                  mini: true,
                  backgroundColor: Colors.blue,
                ),
                // Right arrow button to scroll right
                FloatingActionButton(
                  onPressed: _scrollRight,
                  child: const Icon(Icons.arrow_forward),
                  mini: true,
                  backgroundColor: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTermChanged(String value) async {
    setState(() {
      _isSyncing = true;
      _selectedTermId = value;
      _selectedClasses = ['All'];
      _selectedGender = 'All';
      _selectedSurname = '';
      _selectedReg = '';

      _selectedStartDate = null;
      _selectedEndDate = null;
      _filterByExceptional = false;
      _filterByNewcomer = false;
      _filteredStudents = [];

      _surnameController.clear(); // <-- Clears the field visibly
      _regNumberController.clear(); // <-- Clears the field visibly
    });

    if (_role == DeviceRole.host) {
      final studentBox = await Hive.openBox<Student>('students');
      final termClasses =
          studentBox.values.where((s) => s.termId == _selectedTermId).toList();

      _classes = ['All'];
      _classes.addAll(termClasses.map((s) => s.class_).toSet().toList());
    } else {
      // Use cached or filtered server data
      final serverStudents = _cachedServerStudents ?? [];

      final termClasses = serverStudents
          .where((s) => s.terms?.contains(_selectedTermId) ?? false)
          .toList();

      _classes = ['All'];
      _classes.addAll(termClasses.map((s) => s.class_).toSet().toList());
    }

    setState(() {
      _isSyncing = false;
    });
  }

  void generateAndSaveSpreadsheet() async {
    // Create an Excel document
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Students'];

    // Add the headers
    sheetObject.appendRow([
      TextCellValue('Id'),
      TextCellValue('Name'),
      TextCellValue('Surname'),
      TextCellValue('Class'),
      TextCellValue('Gender'),
      TextCellValue('Date of Birth'),
      TextCellValue('Nationality'),
      TextCellValue('District'),
      TextCellValue('National ID Number'),
      TextCellValue('Student Registration Number'),
      TextCellValue('Student Registration Position'),
      TextCellValue('Physical Address'),
      TextCellValue('Parent Name'),
      TextCellValue('Parent Phone Number'),
      TextCellValue('Religion'),
      TextCellValue('Denomination'),
      TextCellValue('Former School'),
      TextCellValue('Former School Results'),
      TextCellValue('Emergency Contact Name'),
      TextCellValue('Emergency Contact Number'),
      TextCellValue('Health Condition'),
      TextCellValue('Health Condition Details'),
// ✅ New fields
      TextCellValue('Is Exceptional?'),
      TextCellValue('Exceptions'),
      TextCellValue('Is Newcomer?'),
      TextCellValue('Newcomer From'),
      TextCellValue('Newcomer Until'),
      TextCellValue('Terms Associated'), // New column
    ]);

    // Add the data rows (wrap each value accordingly)
    for (var student in _filteredStudents) {
      sheetObject.appendRow([
        IntCellValue(student.id ?? 0), // Assuming student.id is a number
        TextCellValue(student.name),
        TextCellValue(student.surname),
        TextCellValue(student.class_),
        TextCellValue(student.gender),
        TextCellValue(student.age
            .toString()
            .split(' ')[0]), // Only the year part of the age
        TextCellValue(student.nationality ?? ''),
        TextCellValue(student.district ?? ''),
        TextCellValue(student.nationalIdNumber ?? ''),
        TextCellValue(student.studentIdNumber ?? ''),
        TextCellValue(student.regNumber),
        TextCellValue(student.physicalAddress ?? ''),
        TextCellValue(student.paymentStatus),
        TextCellValue(student.phoneNumber),
        TextCellValue(student.religion ?? ''),
        TextCellValue(student.denomination ?? ''),
        TextCellValue(student.formerSchool ?? ''),
        TextCellValue(student.previousSchoolPerformanceResults ?? ''),
        TextCellValue(student.emergencyContactName ?? ''),
        TextCellValue(student.emergencyContactNumber ?? ''),
        TextCellValue(student.healthStauts ?? ''),

        TextCellValue(student.healthDetailedInformation ?? ''),
        // ✅ New field values
        TextCellValue(student.exceptions != null ? 'Yes' : 'No'),
        TextCellValue(
          (student.exceptions != null && student.exceptions!.isNotEmpty)
              ? student.exceptions!.map((e) => e.exceptionName).join(', ')
              : 'None',
        ),
        TextCellValue(student.isNewComer == true ? 'Yes' : 'No'),
        TextCellValue(student.isNewComerFrom != null
            ? student.isNewComerFrom!.toLocal().toString().split(' ')[0]
            : ''),
        TextCellValue(student.isNewComerUntil != null
            ? student.isNewComerUntil!.toLocal().toString().split(' ')[0]
            : ''),
        TextCellValue(
            student.terms?.join(", ") ?? ('')), // New field to display terms
      ]);
    }
    try {
      final fileBytes = excel.encode();
      if (fileBytes == null) throw Exception("Excel encoding failed.");

      if (Platform.isAndroid) {
        // Get app's scoped documents directory
        final directory = await getApplicationDocumentsDirectory();
        final folder =
            Directory('${directory.path}/school_files/school_students');

        // Create folder if not exists
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        // Generate unique file name with timestamp
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath = '${folder.path}/school_students_$timestamp.xlsx';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        print('✅ Spreadsheet saved to: $filePath');
      } else {
        // Use FilePicker to choose save location
        try {
          String? savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Excel File',
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
            fileName: 'Students.xlsx',
          );

          if (savePath != null) {
            // Write the file
            File(savePath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(excel.encode()!);

            print('Spreadsheet saved at: $savePath');
          } else {
            print('File save operation was canceled.');
          }
        } catch (e) {
          print('Error saving spreadsheet: $e');
        }
      }
    } catch (e) {
      print('Error saving spreadsheet: $e');
    }
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _regNumberController.dispose();

    super.dispose();
  }
}
