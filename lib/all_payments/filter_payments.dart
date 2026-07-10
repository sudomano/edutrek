import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:async';
import 'package:background_sms/background_sms.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/services.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/projects/student_project_payments/create_student_project_payment_backup.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/rng.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/batch_sell_unit_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_log_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/product_batch_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/project_items_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/project_sale_transaction_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/projects_serializerr.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/reusable_codes/serializers/users_serializer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zitf_system/utils/windows_printer_helper.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

class _CachedStudents {
  final List<Student> students;
  final DateTime expiresAt;
  _CachedStudents(this.students, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class StudentsArrearsStatementScreen extends StatefulWidget {
  const StudentsArrearsStatementScreen({Key? key, this.transaction})
      : super(key: key);

  final ProjectSaleTransaction? transaction;

  @override
  StudentsArrearsStatementScreenState createState() =>
      StudentsArrearsStatementScreenState();
}

class FocusNodeManager {
  final Map<int, FocusNode> _focusNodes = {};

  FocusNode getFocusNode(int index) {
    if (!_focusNodes.containsKey(index)) {
      _focusNodes[index] = FocusNode();
    }
    return _focusNodes[index]!;
  }

  void dispose() {
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
  }
}

class StudentsArrearsStatementScreenState
    extends State<StudentsArrearsStatementScreen> {
  final GlobalKey<_ArrearsSectionState> _arrearsSectionKey =
      GlobalKey<_ArrearsSectionState>();
  // In your _MakePaymentScreenState class
  final GlobalKey _confirmButtonKey = GlobalKey();
  Future<List<Map<String, dynamic>>> _getFreshArrearsData() async {
    // Force refresh the ArrearsSection to get latest data
    final freshData =
        await _arrearsSectionKey.currentState?.refreshAndGetData();
    return freshData ?? [];
  }

  int _arrearsVersion = 0;
  Map<String, List<bool>> _sharedSelectedSubPurposes = {};
  List<Map<String, dynamic>> _pendingRestorations = [];

  // Add this method to handle selected items from ArrearsSection
  void _handleArrearsSelected(List<Map<String, dynamic>> selectedItems) {
    setState(() {
      for (var item in selectedItems) {
        final newItem = {
          'purpose': item['purpose'],
          'amount': item['amount'],
          'originalAmount': item['amount'],
          'currentAmount': item['amount'],
          'termId': item['termId'] ?? globalTermId.toString(),
          'amountError': null,
          'isRemainingArrears': false,
        };

        final index = _paymentPurposes.length;
        _paymentPurposes.add(newItem);
        _amountControllers[index] = TextEditingController(
          text: (item['amount'] as double).toStringAsFixed(2),
        );
      }
      _updateTotalEntered();
      _removeSelectedItemsFromArrears(selectedItems);
    });
  }

  void _removeSelectedItemsFromArrears(
      List<Map<String, dynamic>> selectedItems) {
    // This will trigger a refresh of the ArrearsSection
    setState(() {
      _arrearsVersion++; // Increment version to force ArrearsSection to reload
    });
  }

  // Add these getter/setter methods for shared state
  Map<String, List<bool>> _getSelectedSubPurposes() {
    return _sharedSelectedSubPurposes;
  }

  void _setSelectedSubPurposes(Map<String, List<bool>> value) {
    _sharedSelectedSubPurposes = value;
  }

  String _selectionSummary = '';

  late final FocusNodeManager _focusManager;
  final FocusNode _pmAmountFocusNode = FocusNode();

  Timer? _pmAmountDebounceTimer;
  final int _pmAmountDebounceDelay = 1200; // Increased to 1200ms for better UX
  DateTime? _lastTypingTime;
  bool _isAutoCorrecting = false; // Flag to prevent recursive auto-correction
  String _lastManuallyEnteredValue = ''; // Track manually entered values
  double? finalReceived; // Store the final received amount after debounce
// bluetooth helper
  late BluetoothHelper bluetoothHelper;
  List<String> _arrearsTerms = [];
  String? _selectedArrearsTerm;

  final _formKey = GlobalKey<FormState>();

  final _studentSearchController = TextEditingController();
  late final FocusNode _searchFocusNode;

  final TextEditingController _paymentAmountController =
      TextEditingController();

  final List<Map<String, dynamic>> _paymentPurposes = [];
  PaymentPurpose? _selectedPaymentPurpose;
  double? _paymentAmount;
  Student? _selectedStudent;
  DateTime _paymentDate = DateTime.now();
  String? _paymentInfo;
  String? _paymentInfo11;

  String? _paymentInfo1;
  String? _paymentInfo2;

  String? _phoneNumber;

  String? selectedTermId;
  String? selectedSchool;

  List<String> _terms = []; // Declare without 'final'
  List<String> _schools = []; // Declare without 'final'

  Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
  DeviceRole? _role;
  String? _hostIp;

  List<StudentPayment>? _cachedServerStudentPayments;
  List<Terms>? _cachedServerTerms;
  List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
  List<Student>? _cachedServerStudents;
  List<School>? _cachedServerSchoolInfo;
  Map<String, Terms> _termsMap = {};

  List<Student>? _cachedFilteredStudents;

  Future<void>? _arrearsFuture;

  Future<double>? _totalArrearsFuture;

  Timer? _searchDebounce;
  final Duration _searchDebounceDuration = const Duration(milliseconds: 350);

// Simple in-memory cache for server search results
  final Map<String, _CachedStudents> _studentsCache = {};

  List<Student>?
      _cachedServerStudentsForSearch; // used only for immediate parse

  List<User> _users = [];
  Map<int?, User> _usersMap = {}; // quick lookup by id
  List<User>? _cachedServerUsers;

  List<Project> _projects = [];
  List<Project>? _cachedServerProjects;
  Map<int?, Project> _projectsMap = {}; // quick lookup by id

  List<ProjectItem> _items = [];
  List<ProjectItem>? _cachedServerProjectItems;
  Map<int?, ProjectItem> _projectItemsMap = {};

  List<ProductBatch> _selectedBatch = [];
  List<ProductBatch>? _cachedProductBatches;
  Map<int?, ProductBatch> _productBatchMap = {};

  List<BatchSellUnit> _batchSellUnits = [];
  List<BatchSellUnit>? _cachedBatchSellUnits;
  Map<int?, BatchSellUnit> _batchSellUnitMap = {};

  int _quantity = 1;

  List<Student> _students = [];
  Student? _student;
  Project? _project;
  ProjectItem? _item;
  ProductBatch? _selectedBatches;
  BatchSellUnit? _selectedSellUnit;

  // CLIENT-SPECIFIC CACHE VARIABLES
  // ==============================
  List<ProjectSaleTransaction>? _cachedServerProjectSaleTransactions;
  List<ProductBatch>? _cachedProductBatchesClient;
  bool _isClientDataLoaded = false;

  // Client mode only: full list of class names (fetched cheaply up front),
  // and whether the full student list is still loading in the background
  // after the first class was loaded and shown.
  List<String> _knownClasses = [];
  bool _isLoadingRemainingStudents = false;

  // Resolves once every startup fetch this screen depends on (students,
  // users, terms, payment purposes, student payments, projects) has
  // completed - awaited before opening the Filter dialog or generating a
  // report, instead of guessing from partial data.
  Future<void>? _initialLoadFuture;

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        fetchUsers(),
        _initializeDataForRole(),
        fetchTerms(),
        fetchSchools(),
        fetchStudentsMetadata(),
        fetchPaymentPurposes(),
        fetchStudentPayments(),
        _fetchProjectsFromServer(),
        _fetchProjectItemsFromServer(),
        fetchProductBatch(),
        fetchBatchSellUnit(),
        _fetchProjectSaleTransactions(),
      ]);
    } catch (e) {
      debugPrint('❌ Error during initial data load: $e');
    }
  }

// Add this to your state variables in StudentsArrearsStatementScreenState
  List<String> _selectedFilterTerms = [];
// Add this at the beginning of your widget class
  final Map<String, List<bool>> _selectedSubPurposes = {};
  double _cachedTotalEntered = 0.0;

  String capitalize(String value) {
    var result = value[0].toUpperCase();
    for (int i = 1; i < value.length; i++) {
      if (value[i - 1] == " ") {
        result = result + value[i].toUpperCase();
      } else {
        result = result + value[i];
      }
    }
    return result;
  }

  List<String> _windowsPrinters = [];
  String? _selectedWindowsPrinter;
  bool _isLoadingPrinters = false;
  bool _isTestingConnection = false;

  // Platform detection
  bool get _isWindows => Platform.isWindows;
  bool get _isAndroid => Platform.isAndroid;

  BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

  bool _connected = false;
  BluetoothDevice? _device;
  String tips = 'connect receipt priter';
  int? BluetoothStates;

  String _paymentMethodType =
      'cash'; // cash | mobile_money | bank_transfer | card | other
  final String _currency = 'USD';
  String? _provider;
  int _purposeListVersion = 0;

  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey _dataTableKey = GlobalKey();

  final TextEditingController _pmAmountCtrl = TextEditingController();
  final TextEditingController _pmReferenceCtrl = TextEditingController();
  final TextEditingController _pmPhoneCtrl = TextEditingController();
  final TextEditingController _pmAccountNumberCtrl = TextEditingController();
  final TextEditingController _pmAccountNameCtrl = TextEditingController();
  final Map<int, TextEditingController> _amountControllers = {};

// Add these to your state variables
  String? _lastUsedPrinter;
  SharedPreferences? _prefs;
  bool _isLoadingLastPrinter = false;

// Add this to your state class
  bool _selectAll = false;
  final Map<String, bool> _selectedStudents = {};

// Add these methods
  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      final studentsToShow = _cachedFilteredStudents ?? _students ?? [];
      for (var student in studentsToShow) {
        if (student is Student) {
          _selectedStudents[student.studentIdNumber.toString()] = _selectAll;
        }
      }
      _updateSelectionSummary();
    });
  }

  void _toggleStudentSelection(String studentId, bool? value) {
    setState(() {
      _selectedStudents[studentId] = value ?? false;
      _selectAll = _selectedStudents.values.every((selected) => selected);
      _updateSelectionSummary();
    });
  }

// Update _getSelectedStudents
  List<Student> _getSelectedStudents() {
    final studentsToShow = _cachedFilteredStudents ?? _students ?? [];
    return studentsToShow
        .whereType<Student>()
        .where((s) => _selectedStudents[s.studentIdNumber] == true)
        .toList();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _lastUsedPrinter = _prefs?.getString('last_windows_printer');

    // Auto-connect after printers are loaded
    if (_lastUsedPrinter != null && _lastUsedPrinter!.isNotEmpty) {
      // Wait for printers to load (add a small delay)
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoConnectLastPrinter();
      });
    }
  }

  Future<void> _autoConnectLastPrinter() async {
    // Don't auto-connect if already connected or already trying
    if (_connected || _isTestingConnection) return;

    // Check if the last used printer exists in current list
    if (_windowsPrinters.contains(_lastUsedPrinter)) {
      setState(() {
        _selectedWindowsPrinter = _lastUsedPrinter;
      });

      // Call your existing connection method
      await _connectWindowsPrinter();
    } else if (_windowsPrinters.isNotEmpty && _lastUsedPrinter != null) {
      // Last printer not found, show notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Last printer "$_lastUsedPrinter" not found. Please select a new printer.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  double get _totalEntered {
    return _paymentPurposes.fold(
      0.0,
      (sum, p) => sum + (p['currentAmount'] as double),
    );
  }

  void _updateTotalEntered() {
    _pmAmountCtrl.text = _cachedTotalEntered.toStringAsFixed(2);
  }

  double _originalTotalForValidation = 0.0;

  Future<void> _showDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🧾 Make Payment Submission Feedback"),
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

  // Add these to your state class
  final Map<int, bool> _isEditingAmount =
      {}; // Tracks which row is being edited

// Optional: Method to clear editing state when needed
  void _stopEditing(int index) {
    setState(() {
      _isEditingAmount[index] = false;
    });
  }

  // Load Windows printers
  Future<void> _loadWindowsPrinters() async {
    if (!_isWindows) return;

    setState(() {
      _isLoadingPrinters = true;
    });

    try {
      final printers = await Printing.listPrinters();
      final availablePrinters =
          printers.where((p) => p.isAvailable).map((p) => p.name).toList();

      setState(() {
        _windowsPrinters = availablePrinters;
        _isLoadingPrinters = false;
      });

      if (availablePrinters.isEmpty) {
        setState(() {
          tips = 'No printers found. Please install a printer driver.';
        });
      } else {
        setState(() {
          tips =
              'Found ${availablePrinters.length} printer(s). Select one to connect.';
        });
      }
    } catch (e) {
      setState(() {
        tips = 'Error loading printers: $e';
        _isLoadingPrinters = false;
      });
    }
  }

  // Connect Windows printer
// Connect Windows printer
  Future<void> _connectWindowsPrinter() async {
    if (_selectedWindowsPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a printer first')),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
      tips = 'Testing connection to $_selectedWindowsPrinter...';
    });

    try {
      final printers = await Printing.listPrinters();
      final selectedPrinter = printers.firstWhere(
        (p) => p.name == _selectedWindowsPrinter,
        orElse: () => throw Exception('Printer not found'),
      );

      if (selectedPrinter.isAvailable) {
        setState(() {
          _connected = true;
          tips = '✅ Connected to ${selectedPrinter.name}';
          _isTestingConnection = false;
        });

        // ✅ SAVE THE LAST USED PRINTER
        await _prefs?.setString(
            'last_windows_printer', _selectedWindowsPrinter!);
        setState(() {
          _lastUsedPrinter = _selectedWindowsPrinter;
        });
      } else {
        throw Exception('Printer is not available');
      }
    } catch (e) {
      setState(() {
        _connected = false;
        tips = '❌ Failed to connect: $e';
        _isTestingConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to connect: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Connect Bluetooth printer (Android)
  Future<void> _connectBluetoothPrinter() async {
    if (_device == null) {
      setState(() {
        tips = 'Please select a Bluetooth device first';
      });
      return;
    }

    setState(() {
      tips = 'Connecting to ${_device!.name}...';
    });

    try {
      await bluetoothHelper.bluetoothPrint.connect(_device!);
      setState(() {
        tips = 'Connected to ${_device!.name}';
        _connected = true;
      });
    } catch (e) {
      setState(() {
        tips = 'Failed to connect: $e';
        _connected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Disconnect printer
  Future<void> _disconnectPrinter() async {
    if (_isAndroid) {
      setState(() {
        tips = 'Disconnecting...';
      });

      try {
        await bluetoothHelper.bluetoothPrint.disconnect();
        setState(() {
          tips = 'Disconnected';
          _connected = false;
          _device = null;
        });
      } catch (e) {
        setState(() {
          tips = 'Failed to disconnect: $e';
        });
      }
    } else if (_isWindows) {
      setState(() {
        tips = 'Disconnected';
        _connected = false;
        _selectedWindowsPrinter = null;
      });
    }
  }

  @override
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadWindowsPrinters(); // Your existing method

    _pmAmountFocusNode.addListener(() {
      if (!_pmAmountFocusNode.hasFocus && !_isAutoCorrecting) {
        final received = double.tryParse(_pmAmountCtrl.text);
        finalReceived = received;

        if (received != null && received < _totalEntered && _totalEntered > 0) {
          _isAutoCorrecting = true;
          final corrected = _totalEntered.toStringAsFixed(2);
          _pmAmountCtrl.text = corrected;

          _isAutoCorrecting = false;
          _formKey.currentState?.validate();
        }
      }
    });
    _focusManager = FocusNodeManager();

    _searchFocusNode = FocusNode();
    _pmAmountDebounceTimer?.cancel();

    // ✅ Track completion of every fetch this screen depends on, so callers
    // (Filter dialog, PDF/report generation) can await real completion
    // instead of polling a heuristic like "_students.isNotEmpty" - which
    // breaks early on the first batch of data, not the full data set.
    _initialLoadFuture = _loadInitialData();

    final tx = widget.transaction;

    if (tx != null) {
      _loadTransactionData(tx);
    }

    if (_isWindows) {
      _loadWindowsPrinters();
    } else {
      // Create a BluetoothHelper instance
      bluetoothHelper = BluetoothHelper();

      // Set up the connection state change callback
      bluetoothHelper.onConnectionStateChanged = (isConnected, message) {
        setState(() {
          _connected = isConnected; // Update UI state
          tips = message; // Update message dynamically
        });
      };

      // Initialize Bluetooth
      bluetoothHelper.initBluetooth();

      // Verify the connection status periodically or based on user action
      Future.delayed(const Duration(seconds: 5), () {
        bluetoothHelper.verifyConnection();
      });

      BluetoothHelper().bluetoothPrint.state.listen((state) {
        BluetoothStates = state;
      });
    }
    _pmAmountCtrl.addListener(() {
      setState(() {}); // refresh change display live
    });
  }

  final PrintQueueManager _printQueueManager = PrintQueueManager();

  Future<void> _addToPrintQueue(List<Student> students) async {
    for (var student in students) {
      final job = PrintJob(
        id: const Uuid().v4(),
        student: student,
        createdAt: DateTime.now(),
      );
      _printQueueManager.addJob(job);
    }

    // Show queue dialog
    _showPrintQueueDialog();
  }

// Add this method to get teacher's assigned classes from the users model
  List<String> _getTeacherAssignedClasses() {
    final loggedInUser = getLoggedInUser();
    if (loggedInUser == null) return [];

    // Find the full user object from _users list
    final user = _users.firstWhere(
      (u) => u.username == loggedInUser.username,
      orElse: () => User(
        id: 0,
        username: '',
        password: '',
        role: '', // unmatched/not-yet-loaded user - don't assume teacher
        assignedClasses: [],
        securityQuestions: const [],
        securityAnswers: const [],
        phone: '',
      ),
    );

    // Check if user has assigned classes
    if (user.assignedClasses != null && user.assignedClasses!.isNotEmpty) {
      return user.assignedClasses!;
    }

    // If no assigned classes, return empty list (will show all students)
    return [];
  }

// Check if current user is a teacher
  bool _isTeacher() {
    final loggedInUser = getLoggedInUser();
    if (loggedInUser == null) return false;

    final user = _users.firstWhere(
      (u) => u.username == loggedInUser.username,
      orElse: () => User(
        id: 0,
        username: '',
        password: '',
        role: '', // unmatched/not-yet-loaded user - don't assume teacher
        assignedClasses: [],
        securityQuestions: const [],
        securityAnswers: const [],
        phone: '',
      ),
    );

    return user.role?.toLowerCase() == 'teacher';
  }

  void _showPrintQueueDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Print Queue'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _printQueueManager.queue.length,
                      itemBuilder: (context, index) {
                        final job = _printQueueManager.queue[index];
                        return ListTile(
                          title: Text(
                              '${job.student.name} ${job.student.surname}'),
                          subtitle: Text(
                              'Status: ${job.status.toString().split('.').last}'),
                          trailing: job.status == PrintStatus.failed
                              ? IconButton(
                                  icon: const Icon(Icons.refresh,
                                      color: Colors.red),
                                  onPressed: () {
                                    // Retry failed print
                                  },
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _printQueueManager.clearQueue();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear Queue'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _printQueueManager.processQueue((job) async {
                            await _printStudentStatement(job.student);
                          });
                        },
                        child: const Text('Start Printing'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _printStudentStatement(Student student) async {
    // Set the selected student to the one being printed
    setState(() {
      _selectedStudent = student;
      _resetPaymentData();
      _totalArrearsFuture = _computeTotalStudentArrears(student);
    });

    // Wait for arrears calculation to complete
    await _totalArrearsFuture;
    await Future.delayed(const Duration(milliseconds: 500));
    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Fetch all necessary data for the statement
      final purposeList =
          await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
              student);
      final feesArrears = await _totalArrearsFuture ?? 0.0;
      final studentId = student.studentIdNumber.toString();
      final projectArrearsDetails = buildStudentArrearsDetails(studentId);
      final totalProjectArrears =
          projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);
      final grandTotal = feesArrears + totalProjectArrears;
      final loggedInUser = getLoggedInUser();
      final user = loggedInUser?.username;
      final username = user != null && user.isNotEmpty ? user : 'Unknown User';
      final School schoolInfo = await _fetchSchoolInfo();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Platform-specific connection check
      if (Platform.isAndroid && !_connected) {
        await _showBluetoothConnectionDialog();
        return;
      }

      if (Platform.isWindows &&
          (_selectedWindowsPrinter == null || !_connected)) {
        await _showWindowsPrinterConnectionDialog();
        return;
      }

      // Build statement lines
      final List<LineText> statementLines = _buildStatementLines(
        schoolInfo: schoolInfo,
        selectedStudent: student,
        feesArrears: feesArrears,
        totalProjectArrears: totalProjectArrears,
        grandTotal: grandTotal,
        purposeList: purposeList,
        projectArrearsDetails: projectArrearsDetails,
        generatedBy: username,
      );

      // Print based on platform
      if (Platform.isAndroid) {
        await bluetoothPrint.printReceipt({}, statementLines);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✓ Statement printed for ${student.name} ${student.surname}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (Platform.isWindows) {
        await _printToWindowsPrinter(statementLines);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✓ Statement printed for ${student.name} ${student.surname}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Printing not supported on this platform');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Error printing statement for ${student.name} ${student.surname}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      print('Error printing statement for ${student.name}: $e');
      rethrow; // Re-throw to let the queue manager know it failed
    }
  }

  Widget _buildFloatingActionButton() {
    if (_isAndroid) {
      // Bluetooth scan button for Android
      return StreamBuilder<bool>(
        stream: bluetoothPrint.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () => bluetoothPrint.stopScan(),
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop),
            );
          } else {
            return FloatingActionButton(
              onPressed: () => bluetoothPrint.startScan(
                timeout: const Duration(seconds: 5),
              ),
              tooltip: 'Scan for Bluetooth Printers',
              child: const Icon(Icons.bluetooth_searching),
            );
          }
        },
      );
    } else if (_isWindows) {
      // Refresh printers button for Windows
      return FloatingActionButton(
        onPressed: _isLoadingPrinters ? null : _loadWindowsPrinters,
        tooltip: 'Refresh Printer List',
        child: _isLoadingPrinters
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh),
      );
    }

    return const SizedBox.shrink();
  }

  // ✅ UPDATED: Initialize data based on role with proper client fetching
  Future<void> _initializeDataForRole() async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      // Host mode: Load directly from Hive
      _students = Hive.box<Student>('students').values.toList();
      _projects = Hive.box<Project>('projects').values.toList();
      _items = Hive.box<ProjectItem>('projectItems').values.toList();
      _selectedBatch =
          Hive.box<ProductBatch>('product_batches').values.toList();
      _batchSellUnits =
          Hive.box<BatchSellUnit>('batch_sell_units').values.toList();

      // Also load payment purposes for host
      await _loadPaymentPurposesForHost();
      if (_isTeacher()) {
        _applyTeacherRestrictions();
      }
      setState(() {
        _updateSelectionSummary();
      });
    } else {
      // Client mode: Fetch data from server
      await _fetchDataForClient();
      if (_isTeacher()) {
        _applyTeacherRestrictions();
      }
      setState(() {
        _updateSelectionSummary();
      });
    }
  }

// In _initializeDataForRole or after loading students:
  void _applyTeacherFilterAndInitialize() {
    // Apply teacher class filter
    if (_isTeacher()) {
      final assignedClasses = _getTeacherAssignedClasses();
      if (assignedClasses.isNotEmpty) {
        // Filter students by teacher's classes
        final filteredStudents = _students.where((student) {
          return assignedClasses.contains(student.class_);
        }).toList();

        setState(() {
          _cachedFilteredStudents = filteredStudents;
          // Also select all filtered students
          _selectedStudents.clear();
          for (var student in filteredStudents) {
            _selectedStudents[student.studentIdNumber.toString()] = true;
          }
          _selectAll = true;
        });
      }
    }

    // Get valid terms for current month
    final validTermIds =
        _getValidTermsForCurrentMonth().map((t) => t.termId).toSet();
    final futureTermIds = _getExcludedFutureTermIds();

    // Auto-select valid terms
    setState(() {
      _selectedFilterTerms = validTermIds.toList();
    });
  }

  // Add this after _students is populated in both host and client modes
  // Single method to handle teacher restrictions
  void _applyTeacherRestrictions() {
    // Only apply if user is a teacher
    if (!_isTeacher()) return;

    // 1. Filter students by teacher's classes (case-insensitive)
    final assignedClasses = _getTeacherAssignedClasses();
    if (assignedClasses.isNotEmpty) {
      // Convert assigned classes to lowercase for case-insensitive comparison
      final assignedClassesLower =
          assignedClasses.map((c) => c.toLowerCase()).toList();

      final filteredStudents = _students.where((student) {
        final studentClass = student.class_?.toLowerCase() ?? '';
        return assignedClassesLower.contains(studentClass);
      }).toList();

      setState(() {
        _cachedFilteredStudents = filteredStudents;
        _students = filteredStudents;

        _selectedStudents.clear();
        for (var student in filteredStudents) {
          _selectedStudents[student.studentIdNumber.toString()] = true;
        }
        _selectAll = true;
        _updateSelectionSummary();
      });
    }

    // 2. Auto-select only valid terms (not future terms)
    final validTermIds =
        _getValidTermsForCurrentMonth().map((t) => t.termId).toSet();
    setState(() {
      _selectedFilterTerms = validTermIds.toList();
    });
  }

// ✅ NEW: Load payment purposes for host
  Future<void> _loadPaymentPurposesForHost() async {
    try {
      final box = Hive.box<PaymentPurpose>('payment_purposes');
      _cachedServerStudentPaymentPurposes = box.values.toList();
    } catch (e) {
      debugPrint('❌ Error loading payment purposes for host: $e');
    }
  }

// ✅ UPDATED: Fetch all data for client
  Future<void> _fetchDataForClient() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      if (_hostIp == null || _hostIp!.isEmpty) {
        _showDialog("⚠️ Host IP not set. Please configure connection.");
        return;
      }

      debugPrint('🔄 Fetching client data from $_hostIp...');

      // Fetch students: load the first class immediately so the screen has
      // something to show fast, then keep loading the rest of the classes
      // in the background instead of blocking on the entire (potentially
      // large) student list in one response.
      if (_cachedServerStudents == null) {
        try {
          final classesResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/students/classes'))
              .then((req) => req.close());

          if (classesResponse.statusCode == 200) {
            final classesJsonString =
                await classesResponse.transform(utf8.decoder).join();
            _knownClasses = (jsonDecode(classesJsonString) as List)
                .map((c) => c.toString())
                .toList();
          } else {
            debugPrint(
                '❌ Failed to fetch classes list: ${classesResponse.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error fetching classes list: $e');
        }

        if (_knownClasses.isNotEmpty) {
          await _fetchStudentsForClass(_knownClasses.first, replaceCache: true);
          debugPrint(
              '✅ Fetched ${_students.length} students for first class (${_knownClasses.first})');
          if (mounted) setState(() {});

          // Load everything else in the background - don't await this, so
          // this function (and anything waiting on it, like the Filter
          // dialog) doesn't get stuck waiting for the full student list.
          _isLoadingRemainingStudents = true;
          _loadRemainingStudentsInBackground();
        } else {
          // No known classes (e.g. empty school, or the classes endpoint
          // failed) - fall back to fetching everything directly.
          await _fetchAllStudents();
        }
      }

      // Fetch payment purposes
      if (_cachedServerStudentPaymentPurposes == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerStudentPaymentPurposes = jsonList
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint(
              '✅ Fetched ${_cachedServerStudentPaymentPurposes!.length} payment purposes');
        } else {
          debugPrint(
              '❌ Failed to fetch payment purposes: ${response.statusCode}');
        }
      }

      // Fetch terms
      if (_cachedServerTerms == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerTerms = jsonList
              .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint('✅ Fetched ${_cachedServerTerms!.length} terms');
        } else {
          debugPrint('❌ Failed to fetch terms: ${response.statusCode}');
        }
      }

      // Fetch projects
      if (_cachedServerProjects == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/projects'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerProjects = jsonList
              .map((json) => projectsFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint('✅ Fetched ${_cachedServerProjects!.length} projects');
        } else {
          debugPrint('❌ Failed to fetch projects: ${response.statusCode}');
        }
      }

      // Fetch project items
      if (_cachedServerProjectItems == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/projectItems'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerProjectItems = jsonList
              .map((json) =>
                  projectItemsFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint(
              '✅ Fetched ${_cachedServerProjectItems!.length} project items');
        } else {
          debugPrint('❌ Failed to fetch project items: ${response.statusCode}');
        }
      }

      // Fetch product batches
      if (_cachedProductBatches == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/productBatches'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedProductBatches = jsonList
              .map((json) =>
                  productBatchesFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint(
              '✅ Fetched ${_cachedProductBatches!.length} product batches');
        } else {
          debugPrint(
              '❌ Failed to fetch product batches: ${response.statusCode}');
        }
      }

      // Fetch batch sell units
      if (_cachedBatchSellUnits == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/batchSellUnit'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedBatchSellUnits = jsonList
              .map((json) =>
                  batchSellUnitFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint(
              '✅ Fetched ${_cachedBatchSellUnits!.length} batch sell units');
        } else {
          debugPrint(
              '❌ Failed to fetch batch sell units: ${response.statusCode}');
        }
      }

      // Fetch project sale transactions
      if (_cachedServerProjectSaleTransactions == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse(
                'http://$_hostIp:8080/api/projectSaleTransactions/all'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerProjectSaleTransactions = jsonList
              .map((json) => projectSaleTransactionFromJson(
                  Map<String, dynamic>.from(json)))
              .toList();
          debugPrint(
              '✅ Fetched ${_cachedServerProjectSaleTransactions!.length} project sale transactions');
        } else {
          debugPrint(
              '❌ Failed to fetch project sale transactions: ${response.statusCode}');
        }
      }

      // Fetch student payments
      if (_cachedServerStudentPayments == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerStudentPayments = jsonList
              .map((json) =>
                  studentPaymentsFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint(
              '✅ Fetched ${_cachedServerStudentPayments!.length} student payments');
        } else {
          debugPrint(
              '❌ Failed to fetch student payments: ${response.statusCode}');
        }
      }

      // Fetch users (for admin SMS)
      if (_cachedServerUsers == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$_hostIp:8080/api/users'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonString) as List;
          _cachedServerUsers = jsonList
              .map((json) => usersFromJson(Map<String, dynamic>.from(json)))
              .toList();
          debugPrint('✅ Fetched ${_cachedServerUsers!.length} users');
        } else {
          debugPrint('❌ Failed to fetch users: ${response.statusCode}');
        }
      }

      // Populate local lists from cached data
      _students = _cachedServerStudents ?? [];
      _projects = _cachedServerProjects ?? [];
      _items = _cachedServerProjectItems ?? [];
      _selectedBatch = _cachedProductBatches ?? [];
      _batchSellUnits = _cachedBatchSellUnits ?? [];

      // Build terms map
      if (_cachedServerTerms != null) {
        _termsMap = {for (var t in _cachedServerTerms!) t.termId: t};
        _terms =
            _cachedServerTerms!.map((term) => term.termId).toSet().toList();
      }

      _isClientDataLoaded = true;

      debugPrint('✅ Client data loaded successfully:');
      debugPrint('  - Students: ${_students.length}');
      debugPrint('  - Projects: ${_projects.length}');
      debugPrint('  - Project Items: ${_items.length}');
      debugPrint('  - Product Batches: ${_selectedBatch.length}');
      debugPrint('  - Terms: ${_terms.length}');

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error fetching client data: $e');
      _showDialog('Failed to load data from host. Please check connection.');
    }
  }

  // Fetches students for a single class from the host and merges them into
  // _students/_cachedServerStudents. Pass replaceCache on the very first
  // call (establishing the initial partial cache) rather than merging into
  // an existing one.
  Future<void> _fetchStudentsForClass(String className,
      {bool replaceCache = false}) async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse(
              'http://$_hostIp:8080/api/students/all?class=${Uri.encodeQueryComponent(className)}'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;
        final fetched = jsonList
            .map((json) => studentsFromJson(Map<String, dynamic>.from(json)))
            .toList();

        if (replaceCache || _cachedServerStudents == null) {
          _cachedServerStudents = fetched;
        } else {
          final existingIds =
              _cachedServerStudents!.map((s) => s.studentIdNumber).toSet();
          _cachedServerStudents = [
            ..._cachedServerStudents!,
            ...fetched.where((s) => !existingIds.contains(s.studentIdNumber)),
          ];
        }
        _students = _cachedServerStudents ?? [];
      } else {
        debugPrint(
            '❌ Failed to fetch students for class "$className": ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching students for class "$className": $e');
    }
  }

  Future<void> _fetchAllStudents() async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$_hostIp:8080/api/students/all'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonString) as List;
        _cachedServerStudents = jsonList
            .map((json) => studentsFromJson(Map<String, dynamic>.from(json)))
            .toList();
        _students = _cachedServerStudents ?? [];
        debugPrint('✅ Fetched ${_students.length} students');
      } else {
        debugPrint('❌ Failed to fetch students: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching all students: $e');
    }
  }

  Future<void> _loadRemainingStudentsInBackground() async {
    try {
      await _fetchAllStudents();
      debugPrint(
          '✅ Background load complete: ${_students.length} total students');
    } finally {
      _isLoadingRemainingStudents = false;
      if (mounted) setState(() {});
    }
  }

  // Passed into FilterDialog so it can fetch a specific class's students on
  // demand if the user picks one that hasn't finished loading in the
  // background yet.
  Future<List<Student>> _fetchStudentsForClassOnDemand(String className) async {
    await _fetchStudentsForClass(className);
    if (mounted) setState(() {});
    return _cachedServerStudents
            ?.where((s) =>
                (s.class_ ?? '').toLowerCase() == className.toLowerCase())
            .toList() ??
        [];
  }

  // ✅ Helper to wait for cached data in client mode
  Future<void> _waitForCachedData() async {
    int attempts = 0;
    const maxAttempts = 20; // 2 seconds max wait

    while (attempts < maxAttempts) {
      if (_cachedServerStudents != null &&
          _cachedServerStudentPaymentPurposes != null &&
          _cachedServerTerms != null) {
        _students = _cachedServerStudents!;
        _projects = _cachedServerProjects!;
        _items = _cachedServerProjectItems!;
        _selectedBatch = _cachedProductBatches!;
        _batchSellUnits = _cachedBatchSellUnits!;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  Future<void> _fetchProjectSaleTransactions() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      if (_role == DeviceRole.host) {
        // HOST: Already have access to Hive box
        return;
      } else {
        // CLIENT: Fetch from server
        if (_hostIp!.isEmpty) {
          return;
        }

        if (_cachedServerProjectSaleTransactions == null) {
          final response = await HttpClient()
              .getUrl(Uri.parse(
                  'http://$_hostIp:8080/api/projectSaleTransactions/all'))
              .then((req) => req.close());

          if (response.statusCode == 200) {
            final jsonString = await response.transform(utf8.decoder).join();
            final jsonList = jsonDecode(jsonString) as List;

            _cachedServerProjectSaleTransactions = jsonList
                .map((json) => projectSaleTransactionFromJson(
                    Map<String, dynamic>.from(json)))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching project sale transactions: $e');
    }
  }

  Future<void> _fetchProjectsFromServer() async {
    try {
      _role = await getDeviceRole();

      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Project> allProjects = [];

      if (_role == DeviceRole.host) {
        //
        // ------------------ HOST: Load users from local Hive ------------------
        //
        final projectBox = await Hive.openBox<Project>('projects');
        allProjects = projectBox.values.toList();
      } else {
        //
        // ------------------ CLIENT: Fetch users from host ------------------
        //
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }

        if (_cachedServerProjects != null) {
          allProjects = _cachedServerProjects!;
        } else {
          final projectsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/projects'))
              .then((req) => req.close());

          if (projectsResponse.statusCode == 200) {
            final projectsJsonString =
                await projectsResponse.transform(utf8.decoder).join();

            final projectsList = jsonDecode(projectsJsonString) as List;

            _cachedServerProjects = projectsList
                .map(
                    (json) => projectsFromJson(Map<String, dynamic>.from(json)))
                .toList();

            allProjects = _cachedServerProjects!;
          } else {
            throw Exception(
                "Failed to load projects data from host. Status code: ${projectsResponse.statusCode}");
          }
        }
      }

      //
      // ------------------ Populate lookup structures ------------------
      //
      if (allProjects.isNotEmpty) {
        _projects = allProjects;
        _projectsMap = {
          for (var p in allProjects) int.tryParse(p.projectCode): p
        };
      } else {
        _projects = [];
        _projectsMap = {};
      }

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching projects: $error");
      debugPrint(stack.toString());
      setState(() {});
    }
  }

  Future<void> _fetchProjectItemsFromServer() async {
    try {
      _role = await getDeviceRole();

      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<ProjectItem> allProjectItems = [];

      if (_role == DeviceRole.host) {
        //
        // ------------------ HOST: Load users from local Hive ------------------
        //
        final projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
        allProjectItems = projectItemBox.values.toList();
      } else {
        //
        // ------------------ CLIENT: Fetch users from host ------------------
        //
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }

        if (_cachedServerProjectItems != null) {
          allProjectItems = _cachedServerProjectItems!;
        } else {
          final projectItemsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/projectItems'))
              .then((req) => req.close());

          if (projectItemsResponse.statusCode == 200) {
            final projectItemsJsonString =
                await projectItemsResponse.transform(utf8.decoder).join();

            final projectItemsList = jsonDecode(projectItemsJsonString) as List;

            _cachedServerProjectItems = projectItemsList
                .map((json) =>
                    projectItemsFromJson(Map<String, dynamic>.from(json)))
                .toList();

            allProjectItems = _cachedServerProjectItems!;
          } else {
            throw Exception(
                "Failed to load project items data from host. Status code: ${projectItemsResponse.statusCode}");
          }
        }
      }

      //
      // ------------------ Populate lookup structures ------------------
      //
      if (allProjectItems.isNotEmpty) {
        _items = allProjectItems;
        _projectItemsMap = {
          for (var p in allProjectItems)
            int.tryParse(p.projectItemCode.toString()): p
        };
      } else {
        _items = [];
        _projectItemsMap = {};
      }

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching project items: $error");
      debugPrint(stack.toString());
      setState(() {});
    }
  }

  Future<void> fetchProductBatch() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<ProductBatch> productBatches = [];

      if (_role == DeviceRole.host) {
        final productBatchBox =
            await Hive.openBox<ProductBatch>('product_batches');

        productBatches = productBatchBox.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedProductBatches == null) {
          final productBatchesResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/productBatches'))
              .then((req) => req.close());

          if (productBatchesResponse.statusCode == 200) {
            final productBatchesJsonString =
                await productBatchesResponse.transform(utf8.decoder).join();

            final productBatchesList =
                jsonDecode(productBatchesJsonString) as List;

            _cachedProductBatches = productBatchesList
                .map((json) =>
                    productBatchesFromJson(Map<String, dynamic>.from(json)))
                .toList();

            productBatches = _cachedProductBatches!;
          } else {
            throw Exception("Failed to load product batches data from host.");
          }
        }

        productBatches = _cachedProductBatches!;
      }
      if (productBatches.isNotEmpty) {
        _selectedBatch = productBatches;
        _productBatchMap = {
          for (var p in productBatches) int.tryParse(p.batchCode.toString()): p
        };
      } else {
        _selectedBatch = [];
        _productBatchMap = {};
      }

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<void> fetchBatchSellUnit() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<BatchSellUnit> productBatchSellUnit = [];

      if (_role == DeviceRole.host) {
        final productBatchSellUnitBox =
            await Hive.openBox<BatchSellUnit>('batch_sell_units');

        productBatchSellUnit = productBatchSellUnitBox.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedBatchSellUnits == null) {
          final productBatchSellUnitResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/batchSellUnit'))
              .then((req) => req.close());

          if (productBatchSellUnitResponse.statusCode == 200) {
            final productBatchSellJsonString =
                await productBatchSellUnitResponse
                    .transform(utf8.decoder)
                    .join();

            final productBatchSellUnitList =
                jsonDecode(productBatchSellJsonString) as List;

            _cachedBatchSellUnits = productBatchSellUnitList
                .map((json) =>
                    batchSellUnitFromJson(Map<String, dynamic>.from(json)))
                .toList();

            productBatchSellUnit = _cachedBatchSellUnits!;
          } else {
            throw Exception(
                "Failed to load product batch sell unit data from host.");
          }
        }

        productBatchSellUnit = _cachedBatchSellUnits!;
      }
      if (productBatchSellUnit.isNotEmpty) {
        _batchSellUnits = productBatchSellUnit;
        _batchSellUnitMap = {
          for (var p in productBatchSellUnit)
            int.tryParse(p.sellUnitCode.toString()): p
        };
      } else {
        _selectedBatch = [];
        _batchSellUnitMap = {};
      }

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

// ✅ Load transaction data (works for both host and client)
  Future<void> _loadTransactionData(ProjectSaleTransaction tx) async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      // Host mode: Direct Hive access
      _student = Hive.box<Student>('students')
          .values
          .firstWhereOrNull((s) => s.studentIdNumber == tx.studentId);

      _project = Hive.box<Project>('projects')
          .values
          .firstWhereOrNull((p) => p.projectCode == tx.projectCode);

      _item = Hive.box<ProjectItem>('projectItems')
          .values
          .firstWhereOrNull((i) => i.projectItemCode == tx.projectItemCode);

      _selectedBatches = Hive.box<ProductBatch>('product_batches')
          .values
          .firstWhereOrNull((b) => b.batchCode == tx.batchCode);

      _selectedSellUnit = Hive.box<BatchSellUnit>('batch_sell_units')
          .values
          .firstWhereOrNull((u) => u.sellUnitCode == tx.sellUnitCode);
    } else {
      // Client mode: Search in cached data
      _student = _cachedServerStudents
          ?.firstWhereOrNull((s) => s.studentIdNumber == tx.studentId);

      _project = await _findProjectInCacheOrServer(tx.projectCode);
      _item = await _findItemInCacheOrServer(tx.projectItemCode);
      _selectedBatches = await _findBatchInCacheOrServer(tx.batchCode);
      _selectedSellUnit = await _findSellUnitInCacheOrServer(tx.sellUnitCode);
    }

    _quantity = tx.quantitySold;

    setState(() {});
  }

// ✅ Helper to find project in cache or fetch from server
  Future<Project?> _findProjectInCacheOrServer(String projectCode) async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      return Hive.box<Project>('projects')
          .values
          .firstWhereOrNull((p) => p.projectCode == projectCode);
    }

    // Client mode: First check if we have cached projects
    if (_cachedServerProjects != null && _cachedServerProjects!.isNotEmpty) {
      return _cachedServerProjects!
          .firstWhereOrNull((p) => p.projectCode == projectCode);
    }

    // If not, try to fetch from server
    final projects = await _fetchProjectsFromServerAndCache();
    return projects.firstWhereOrNull((p) => p.projectCode == projectCode);
  }

// ✅ Helper to find item in cache or fetch from server
  Future<ProjectItem?> _findItemInCacheOrServer(String itemCode) async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      return Hive.box<ProjectItem>('projectItems')
          .values
          .firstWhereOrNull((i) => i.projectItemCode == itemCode);
    }

    // Client mode: First check if we have cached project items
    if (_cachedServerProjectItems != null &&
        _cachedServerProjectItems!.isNotEmpty) {
      return _cachedServerProjectItems!
          .firstWhereOrNull((i) => i.projectItemCode == itemCode);
    }

    // If not, try to fetch from server
    final items = await _fetchProjectItemsFromServerAndCache();
    return items.firstWhereOrNull((i) => i.projectItemCode == itemCode);
  }

// ✅ Helper for batch lookup
  Future<ProductBatch?> _findBatchInCacheOrServer(String batchCode) async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      return Hive.box<ProductBatch>('product_batches')
          .values
          .firstWhereOrNull((b) => b.batchCode == batchCode);
    }

    // Client mode: First check cached product batches
    if (_cachedProductBatches != null && _cachedProductBatches!.isNotEmpty) {
      return _cachedProductBatches!
          .firstWhereOrNull((b) => b.batchCode == batchCode);
    }

    // If not, fetch from server
    final batches = await _fetchProductBatchesFromServerAndCache();
    return batches.firstWhereOrNull((b) => b.batchCode == batchCode);
  }

// ✅ Helper for sell unit lookup
  Future<BatchSellUnit?> _findSellUnitInCacheOrServer(
      String sellUnitCode) async {
    final role = await getDeviceRole();

    if (role == DeviceRole.host) {
      return Hive.box<BatchSellUnit>('batch_sell_units')
          .values
          .firstWhereOrNull((u) => u.sellUnitCode == sellUnitCode);
    }

    // Client mode: First check cached batch sell units
    if (_cachedBatchSellUnits != null && _cachedBatchSellUnits!.isNotEmpty) {
      return _cachedBatchSellUnits!
          .firstWhereOrNull((u) => u.sellUnitCode == sellUnitCode);
    }

    // If not, fetch from server
    final sellUnits = await _fetchBatchSellUnitsFromServerAndCache();
    return sellUnits.firstWhereOrNull((u) => u.sellUnitCode == sellUnitCode);
  }

// ✅ New methods that fetch and cache from server (client mode)
  Future<List<Project>> _fetchProjectsFromServerAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$hostIp:8080/api/projects'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonStr) as List;
        final projects = jsonList
            .map((json) => projectsFromJson(Map<String, dynamic>.from(json)))
            .toList();

        _cachedServerProjects = projects;
        return projects;
      }
    } catch (e) {
      debugPrint('Error fetching projects from server: $e');
    }

    return [];
  }

  Future<List<ProjectItem>> _fetchProjectItemsFromServerAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$hostIp:8080/api/projectItems'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonStr) as List;
        final items = jsonList
            .map(
                (json) => projectItemsFromJson(Map<String, dynamic>.from(json)))
            .toList();

        _cachedServerProjectItems = items;
        return items;
      }
    } catch (e) {
      debugPrint('Error fetching project items from server: $e');
    }

    return [];
  }

  Future<List<ProductBatch>> _fetchProductBatchesFromServerAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$hostIp:8080/api/productBatches'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonStr) as List;
        final batches = jsonList
            .map((json) =>
                productBatchesFromJson(Map<String, dynamic>.from(json)))
            .toList();

        _cachedProductBatches = batches;
        return batches;
      }
    } catch (e) {
      debugPrint('Error fetching product batches from server: $e');
    }

    return [];
  }

  Future<List<BatchSellUnit>> _fetchBatchSellUnitsFromServerAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$hostIp:8080/api/batchSellUnit'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final jsonList = jsonDecode(jsonStr) as List;
        final sellUnits = jsonList
            .map((json) =>
                batchSellUnitFromJson(Map<String, dynamic>.from(json)))
            .toList();

        _cachedBatchSellUnits = sellUnits;
        return sellUnits;
      }
    } catch (e) {
      debugPrint('Error fetching batch sell units from server: $e');
    }

    return [];
  }

// ✅ Helper method to check if using server data
  bool get isUsingServerData => _role == DeviceRole.client;

// ✅ Method to refresh all data from server
  Future<void> refreshFromServer() async {
    if (_role == DeviceRole.client) {
      await Future.wait([
        fetchStudentPayments(),
        fetchPaymentPurposes(),
        fetchTerms(),
        fetchUsers(),
        _fetchProjectsFromServerAndCache(),
        _fetchProjectItemsFromServerAndCache(),
        _fetchProductBatchesFromServerAndCache(),
        _fetchBatchSellUnitsFromServerAndCache(),
      ]);

      // Update local lists with cached data
      if (_cachedServerProjects != null) {
        _projects = _cachedServerProjects!;
      }
      if (_cachedServerProjectItems != null) {
        _items = _cachedServerProjectItems!;
      }
      if (_cachedProductBatches != null) {
        _selectedBatch = _cachedProductBatches!;
      }
      if (_cachedBatchSellUnits != null) {
        _batchSellUnits = _cachedBatchSellUnits!;
      }

      setState(() {});
    }
  }

// ✅ Single item fetchers (for individual lookups)
  Future<Project?> _fetchSingleProjectFromServer(String projectCode) async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$hostIp:8080/api/projects/$projectCode'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return projectsFromJson(json);
      }
    } catch (e) {
      debugPrint('Error fetching single project: $e');
    }

    return null;
  }

  Future<ProjectItem?> _fetchSingleItemFromServer(String itemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(Uri.parse('http://$hostIp:8080/api/projectItems/$itemCode'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return projectItemsFromJson(json);
      }
    } catch (e) {
      debugPrint('Error fetching single item: $e');
    }

    return null;
  }

  Future<ProductBatch?> _fetchSingleBatchFromServer(String batchCode) async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(
              Uri.parse('http://$hostIp:8080/api/productBatches/$batchCode'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return productBatchesFromJson(json);
      }
    } catch (e) {
      debugPrint('Error fetching single batch: $e');
    }

    return null;
  }

  Future<BatchSellUnit?> _fetchSingleSellUnitFromServer(
      String sellUnitCode) async {
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    try {
      final response = await HttpClient()
          .getUrl(
              Uri.parse('http://$hostIp:8080/api/batchSellUnit/$sellUnitCode'))
          .then((req) => req.close());

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return batchSellUnitFromJson(json);
      }
    } catch (e) {
      debugPrint('Error fetching single sell unit: $e');
    }

    return null;
  }
  // ✅ Update existing methods to use role-appropriate data access

  Future<void> fetchUsers() async {
    try {
      _role = await getDeviceRole();

      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      List<User> allUsers = [];

      if (_role == DeviceRole.host) {
        //
        // ------------------ HOST: Load users from local Hive ------------------
        //
        final userBox = await Hive.openBox<User>('users');
        allUsers = userBox.values.toList();
      } else {
        //
        // ------------------ CLIENT: Fetch users from host ------------------
        //
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }

        if (_cachedServerUsers != null) {
          allUsers = _cachedServerUsers!;
        } else {
          final usersResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/users'))
              .then((req) => req.close());

          if (usersResponse.statusCode == 200) {
            final usersJsonString =
                await usersResponse.transform(utf8.decoder).join();

            final usersList = jsonDecode(usersJsonString) as List;

            _cachedServerUsers = usersList
                .map((json) => usersFromJson(Map<String, dynamic>.from(json)))
                .toList();

            allUsers = _cachedServerUsers!;
          } else {
            throw Exception(
                "Failed to load users data from host. Status code: ${usersResponse.statusCode}");
          }
        }
      }

      //
      // ------------------ Populate lookup structures ------------------
      //
      if (allUsers.isNotEmpty) {
        _users = allUsers;
        _usersMap = {for (var u in allUsers) u.id: u};
      } else {
        _users = [];
        _usersMap = {};
      }

      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching users: $error");
      debugPrint(stack.toString());
      setState(() {});
    }
  }

  Future<void> fetchTerms() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<Terms> allTerms = [];

      if (_role == DeviceRole.host) {
        final termBox = await Hive.openBox<Terms>('terms');
        allTerms = termBox.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerTerms == null) {
          final termsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
              .then((req) => req.close());

          if (termsResponse.statusCode == 200) {
            final termsJsonString =
                await termsResponse.transform(utf8.decoder).join();
            final termsList = jsonDecode(termsJsonString) as List;
            _cachedServerTerms = termsList
                .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load terms data from host.");
          }
        }
        allTerms = _cachedServerTerms!;
      }

      if (allTerms.isNotEmpty) {
        // ✅ ONLY filter terms for teachers
        if (_isTeacher()) {
          // Only include terms with start date <= current month
          final now = DateTime.now();
          final currentMonth = DateTime(now.year, now.month, 1);

          final validTerms = allTerms.where((term) {
            final termStart =
                DateTime(term.startDate.year, term.startDate.month, 1);
            return termStart.compareTo(currentMonth) <= 0;
          }).toList();

          _terms = validTerms.map((term) => term.termId).toSet().toList();
          _termsMap = {for (var t in allTerms) t.termId: t};

          // Auto-select valid terms for teachers
          _selectedFilterTerms = _terms;
        } else {
          // ✅ Non-teachers see ALL terms
          _terms = allTerms.map((term) => term.termId).toSet().toList();
          _termsMap = {for (var t in allTerms) t.termId: t};
          // Don't auto-filter for non-teachers
        }

        selectedTermId = _terms.contains(globalTermId)
            ? globalTermId
            : (_terms.isNotEmpty ? _terms.first : null);
      } else {
        _terms = [];
        _termsMap = {};
      }

      setState(() {});
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  Future<void> fetchSchools() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<School> allSchools = [];

      if (_role == DeviceRole.host) {
        final box = await Hive.openBox<School>('school');
        allSchools = box.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerSchoolInfo == null) {
          final schooResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/school'))
              .then((req) => req.close());

          if (schooResponse.statusCode == 200) {
            final schoolsJsonString =
                await schooResponse.transform(utf8.decoder).join();

            final schoolsList = jsonDecode(schoolsJsonString) as List;

            _cachedServerSchoolInfo = schoolsList
                .map((json) => schoolFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load school data from host.");
          }
        }
        allSchools = _cachedServerSchoolInfo!;
      }

      setState(() {}); // Refresh the UI
    } catch (error) {
      debugPrint("Error fetching initial data: $error");
      setState(() {});
    }
  }

  Future<void> fetchStudentsMetadata() async {
    // Keep lightweight startup tasks here (e.g., counts, last sync timestamp)
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      // Optionally fetch small metadata endpoint like /api/students/summary
    } catch (e) {
      debugPrint('❌ fetchStudentsMetadata error: $e');
    }
  }

  // ✅ UPDATED: fetchPaymentPurposes with proper client support
  Future<void> fetchPaymentPurposes() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<PaymentPurpose> allStudentPaymentPurposes = [];

      if (_role == DeviceRole.host) {
        final paymentPurposeBox =
            await Hive.openBox<PaymentPurpose>('payment_purposes');
        allStudentPaymentPurposes = paymentPurposeBox.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }

        if (_cachedServerStudentPaymentPurposes == null) {
          final response = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
              .then((req) => req.close());

          if (response.statusCode == 200) {
            final jsonStr = await response.transform(utf8.decoder).join();
            final list = jsonDecode(jsonStr) as List;
            _cachedServerStudentPaymentPurposes = list
                .map((json) =>
                    paymentPurposesFromJson(Map<String, dynamic>.from(json)))
                .toList();
            debugPrint(
                '✅ Fetched ${_cachedServerStudentPaymentPurposes!.length} payment purposes from server');
          } else {
            debugPrint(
                '❌ Failed to fetch payment purposes: ${response.statusCode}');
          }
        }
        allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching payment purposes: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<void> fetchStudentPayments() async {
    try {
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
      List<StudentPayment> allStudentPayments = [];

      if (_role == DeviceRole.host) {
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');

        allStudentPayments = paymentBox.values.toList();
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }
        if (_cachedServerStudentPayments == null) {
          final studentPaymentsResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
              .then((req) => req.close());

          if (studentPaymentsResponse.statusCode == 200) {
            final studentPaymentsJsonString =
                await studentPaymentsResponse.transform(utf8.decoder).join();

            final studentPaymentsList =
                jsonDecode(studentPaymentsJsonString) as List;

            _cachedServerStudentPayments = studentPaymentsList
                .map((json) =>
                    studentPaymentsFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load student Payments data from host.");
          }
        }

        allStudentPayments = _cachedServerStudentPayments!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
      debugPrint("🪵 Stacktrace: $stack");
      setState(() {});
    }
  }

  Future<School> _getSchoolInfo() async {
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (role == DeviceRole.host) {
      final schoolBox = await Hive.openBox<School>('school');
      if (schoolBox.isNotEmpty) {
        return schoolBox.values.first;
      }
    } else {
      if (_cachedServerSchoolInfo == null) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/school'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final jsonList = jsonDecode(jsonStr) as List;
          _cachedServerSchoolInfo = jsonList
              .map((e) => schoolFromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          throw Exception("❌ Failed to fetch school data from host.");
        }
      }

      if (_cachedServerSchoolInfo != null &&
          _cachedServerSchoolInfo!.isNotEmpty) {
        return _cachedServerSchoolInfo!.first;
      }
    }

    // Fallback default
    return School(
      schoolName: 'School Receipt',
      schoolAddress: 'P.O.Box...',
      schoolEmail: '@school.co.zw',
      schoolPhoneNumber: '+263...',
    );
  }

  Future<void> _sendSmsNotification(
      String allPaymentsInfo, String? phone) async {
    if (Platform.isAndroid) {
      if (allPaymentsInfo.isEmpty) {
        _showDialog('No payment made yet');
        return;
      }
      final encodedBody = Uri.encodeComponent(allPaymentsInfo);

      await launcher.launchUrl(
        Uri.parse(
          'sms:$phone${Platform.isAndroid ? '?' : '&'}body=$encodedBody',
        ),
      );
    }
  }

  Future<void> sendSms(String allPaymentsInfoadminnew, String recipient) async {
    if (Platform.isAndroid) {
      var status = await Permission.sms.status;

      if (!status.isGranted) {
        var result = await Permission.sms.request();

        if (!result.isGranted) {
          _showDialog('SMS permission is not granted. Cannot send SMS.');
          return;
        }
      }
    }

    try {
      if (Platform.isAndroid) {
        const int smsChunkLimit = 153; // Use 153 to allow concatenation headers

        List<String> messageParts = [];
        for (int i = 0;
            i < allPaymentsInfoadminnew.length;
            i += smsChunkLimit) {
          int end = (i + smsChunkLimit < allPaymentsInfoadminnew.length)
              ? i + smsChunkLimit
              : allPaymentsInfoadminnew.length;
          messageParts.add(allPaymentsInfoadminnew.substring(i, end));
        }

        for (int i = 0; i < messageParts.length; i++) {
          String part = messageParts[i];
          SmsStatus result = await BackgroundSms.sendMessage(
            phoneNumber: recipient,
            message: part,
          );

          await Future.delayed(
              const Duration(milliseconds: 500)); // Delay to avoid issues
        }
      }
    } catch (e) {
      _showDialog('Error sending SMS: $e');
    }
  }

  double _calculateArrearsForTerm({
    required PaymentPurpose purpose,
    required String termId,
    required String purposeName,
  }) {
    // Use appropriate data source depending on role
    final allPayments = _role == DeviceRole.host
        ? Hive.box<StudentPayment>('student_payments').values
        : (_cachedServerStudentPayments ?? []);

    final allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values
        : (_cachedServerTerms ?? []);

    // Total paid from Hive
    final hivePaid = allPayments
        .where((payment) =>
            payment.studentName.toLowerCase() ==
                _selectedStudent!.name.toLowerCase() &&
            payment.studentSurname.toLowerCase() ==
                _selectedStudent!.surname.toLowerCase() &&
            payment.termId == termId &&
            payment.paymentPurpose.toLowerCase() == purposeName.toLowerCase())
        .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));

    // Total paid in current session
    final sessionPaid = _paymentPurposes
        .where((p) =>
            p['termId'] == termId &&
            p['purpose'].paymentPurpose.toLowerCase() ==
                purposeName.toLowerCase())
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));

    double totalPaid = hivePaid + sessionPaid;
    double arrears = purpose.purposeAmount - totalPaid;

    // Apply exception adjustment
    arrears = getAdjustedArrear(
      arrears,
      _selectedStudent!,
      purpose,
      termId,
    );

    // Handle newcomer-only rule
    if (purpose.forNewcomersOnly == true) {
      if (_selectedStudent!.isNewComer != true) {
        return 0.0;
      }

      final newcomerUntil = _selectedStudent!.isNewComerUntil;
      final newcomerFrom = _selectedStudent!.isNewComerFrom;

      if (newcomerUntil != null && newcomerFrom != null) {
        try {
          final term = allTerms.firstWhere(
            (t) =>
                (t.termId?.trim().toLowerCase() ?? '') ==
                (purpose.termId?.trim().toLowerCase() ?? ''),
          );
          if (term.endDate != null) {
            if (term.startDate.isAfter(newcomerUntil) ||
                term.endDate!.isBefore(newcomerFrom)) {
              return 0.0;
            }
          }
        } catch (_) {
          return 0.0; // Term not found — skip
        }
      } else if (newcomerUntil != null) {
        try {
          final term = allTerms.firstWhere(
            (t) =>
                (t.termId?.trim().toLowerCase() ?? '') ==
                (purpose.termId?.trim().toLowerCase() ?? ''),
          );
          if (term.startDate.isAfter(newcomerUntil)) {
            return 0.0;
          }
        } catch (_) {
          return 0.0; // Term not found — skip
        }
      } else {
        return 0.0;
      }
    }

    return arrears;
  }

  Future<School> _fetchSchoolInfo() async {
    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<School>('school');
      if (box.isNotEmpty) {
        return box.values.first;
      }
    } else {
      if (_cachedServerSchoolInfo != null &&
          _cachedServerSchoolInfo!.isNotEmpty) {
        return _cachedServerSchoolInfo!.first;
      }
    }

    // Fallback if no valid data found
    return School(
      schoolName: 'School Receipt',
      schoolAddress: 'P.O.Box....',
      schoolEmail: '@school.co.zw',
      schoolPhoneNumber: '+263.........',
    );
  }

  bool deepMatchStudentWithInverse(Student s, String query) {
    if (query.trim().isEmpty) return true;

    final q = query.toLowerCase().trim();
    final parts = q.split(RegExp(r'\s+'));

    final name = (s.name ?? '').toLowerCase();
    final surname = (s.surname ?? '').toLowerCase();
    final fullName = ('$name $surname').trim();
    final fullNameInverse = ('$surname $name').trim();
    final idNum = (s.studentIdNumber ?? '').toLowerCase();
    final classe = (s.class_ ?? '').toLowerCase();

    final fields = [
      name,
      surname,
      fullName,
      fullNameInverse,
      idNum,
      classe,
    ];

    // Every search word must match *some* field
    return parts.every((part) => fields.any((field) => field.contains(part)));
  }

  Future<void> _searchStudent(String query, {bool showDialog = false}) async {
    try {
      // Ensure we have role and host IP resolved
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip') ?? _hostIp;

      List<Student> results = [];

      if (_role == DeviceRole.host) {
        // Host: local Hive query (fast)
        final studentBox = await Hive.openBox<Student>('students');
        results = studentBox.values
            .where((s) => s.termId != null)
            .where((s) => deepMatchStudentWithInverse(s, query))
            .toList();
      } else {
        // Client: check per-query cache first
        final cached = _studentsCache[query];
        if (cached != null && cached.isValid) {
          results = cached.students;
        } else {
          if (_hostIp == null || _hostIp!.isEmpty) {
            _showDialog('⚠️ Host IP not set. Please configure connection.');
            return;
          }

          final uri = Uri.parse(
              'http://$_hostIp:8080/api/students?search=${Uri.encodeQueryComponent(query)}');
          final request = await HttpClient().getUrl(uri);
          final response = await request.close();

          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final parsed = jsonDecode(body) as List<dynamic>;

            results = parsed
                .map(
                    (json) => studentsFromJson(Map<String, dynamic>.from(json)))
                .toList();

            // store in cache for short time (30 seconds)
            _studentsCache[query] = _CachedStudents(
                results, DateTime.now().add(const Duration(seconds: 30)));
          } else {
            _showDialog(
                '⚠️ Failed to fetch students from host (${response.statusCode})');
            return;
          }
        }
      }

      if (results.isEmpty) {
        if (showDialog) _showDialog('No matching students found for: "$query"');
      } else {
        if (showDialog) _displayStudentSelectionDialog(results);
      }
    } catch (e, st) {
      _showDialog('⚠️ Error searching students.');
    }
  }

  void _displayStudentSelectionDialog(List<Student> students) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select a Student'),
          content: SizedBox(
            height: 200,
            width: 200,
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  title: Text(capitalize('${student.name} ${student.surname}')),
                  subtitle: Text(capitalize('Class: ${student.class_}')),
                  onTap: () {
                    setState(() {
                      _selectedStudent = student;
                      _resetPaymentData(); // ← Clear all previous payment data

                      _totalArrearsFuture =
                          _computeTotalStudentArrears(student);

                      // ✅ Clear all selections and payment data
                      _selectedPaymentPurpose = null;
                      _selectedArrearsTerm = null;
                      _paymentInfo = '';
                      _paymentInfo11 = '';
                      _paymentInfo1 = '';
                      _paymentInfo2 = '';
                      _paymentPurposes.clear(); // Clear added payment items
                      _selectedSubPurposes
                          .clear(); // ← CRITICAL: Clear checkbox selections
                      _paymentAmountController.clear();
                      _paymentAmount = null;
                      _pmAmountCtrl.clear();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

// Helper method to build info row (without font parameter)
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

// Helper method to build amount row (without font parameter)
  pw.Widget _buildAmountRow(
    String label,
    double amount, {
    PdfColor color = PdfColors.black,
    bool isBold = false,
    double fontSize = 14,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
          pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// Helper method to build table cell (no changes needed)
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: alignment,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
        ),
      ),
    );
  }

  Future<void> _generateMultiPagePdf(List<Student> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students to generate PDF for')),
      );
      return;
    }

    final progressNotifier = ValueNotifier<int>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (context, count, _) => Text(
                count == 0
                    ? 'Preparing report for ${students.length} students...'
                    : 'Processing student $count of ${students.length}...',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
    // showDialog() doesn't paint synchronously - the renderer needs a real
    // event-loop turn before the frame actually shows. Without this, the
    // loop below (near-instant Hive reads on host) can run to completion
    // before the renderer ever gets a turn, so the dialog is requested but
    // never actually painted - looking like a plain freeze.
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final pdf = pw.Document();
      final schoolInfo = await _fetchSchoolInfo();
      final loggedInUser = getLoggedInUser();
      final username = loggedInUser?.username ?? 'Unknown User';

      // Load all arrears data for all students
      final Map<String, dynamic> studentArrearsData = {};
      for (var i = 0; i < students.length; i++) {
        final student = students[i];
        final originalSelectedStudent = _selectedStudent;
        _selectedStudent = student;

        final purposeList =
            await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
                student);
        final feesArrears = await _computeTotalStudentArrears(student);
        final studentId = student.studentIdNumber.toString();
        final projectArrearsDetails = buildStudentArrearsDetails(studentId);
        final totalProjectArrears =
            projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);

        studentArrearsData[student.studentIdNumber.toString()] = {
          'purposeList': purposeList,
          'feesArrears': feesArrears,
          'projectArrearsDetails': projectArrearsDetails,
          'totalProjectArrears': totalProjectArrears,
          'grandTotal': (feesArrears ?? 0) + totalProjectArrears,
          'student': student,
        };

        _selectedStudent = originalSelectedStudent;
        progressNotifier.value = i + 1;
        // Yield every few students so the counter above actually gets a
        // chance to paint instead of jumping straight from 0 to the total.
        if (i % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      // Add each student on a separate page
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        final data = studentArrearsData[student.studentIdNumber.toString()];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) {
              // Build the column children list explicitly
              final List<pw.Widget> columnChildren = [];

              // Add header
              columnChildren
                  .add(_buildPdfHeader(schoolInfo, i + 1, students.length));

              // Add student content widgets
              final studentContent = _buildStudentContent(student, data);
              columnChildren.addAll(studentContent);

              // Add footer
              columnChildren.add(_buildPdfFooter(username));

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: columnChildren,
              );
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();

      if (mounted) Navigator.pop(context);

      // Show PDF preview dialog
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PDF Preview - ${students.length} Students',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdfBytes,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      progressNotifier.dispose();
    }
  }

  List<pw.Widget> _buildStudentContent(Student student, dynamic arrearsData) {
    final purposeList = arrearsData?['purposeList'] ?? [];
    final feesArrears = arrearsData?['feesArrears'] ?? 0.0;
    final projectArrearsDetails = arrearsData?['projectArrearsDetails'] ?? [];
    final totalProjectArrears = arrearsData?['totalProjectArrears'] ?? 0.0;
    final grandTotal = arrearsData?['grandTotal'] ?? 0.0;

    final List<pw.Widget> containerChildren = [];

    // Student Header
    containerChildren.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue100,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${student.name} ${student.surname}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'ID: ${student.studentIdNumber}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    containerChildren.add(pw.SizedBox(height: 10));

    // Student Info
    containerChildren.add(
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text('Class: ${student.class_ ?? "N/A"}'),
          ),
          pw.Expanded(
            child: pw.Text('Phone: ${student.phoneNumber ?? "N/A"}'),
          ),
        ],
      ),
    );

    containerChildren.add(pw.Divider());
    containerChildren.add(pw.SizedBox(height: 10));

    // Fees Arrears Section
    containerChildren.add(
      pw.Text(
        'Fees Arrears:',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
    );
    containerChildren.add(pw.SizedBox(height: 5));

    if (purposeList.isNotEmpty) {
      for (var entry in purposeList) {
        containerChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
            child: pw.Text(
              '• ${entry['purpose'].paymentPurpose}: ${entry['arrearsPreview']}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        );
      }
    }

    containerChildren.add(pw.SizedBox(height: 5));
    containerChildren.add(
      pw.Text(
        'Total Fees Arrears: \$${feesArrears.toStringAsFixed(2)}',
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.red,
        ),
      ),
    );

    // Project Arrears Section
    if (projectArrearsDetails.isNotEmpty) {
      containerChildren.add(pw.SizedBox(height: 10));
      containerChildren.add(
        pw.Text(
          'Project Arrears:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      );
      containerChildren.add(pw.SizedBox(height: 5));

      for (var detail in projectArrearsDetails) {
        containerChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
            child: pw.Text(
              '• ${detail.projectName}: \$${detail.arrears.toStringAsFixed(2)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        );
      }

      containerChildren.add(pw.SizedBox(height: 5));
      containerChildren.add(
        pw.Text(
          'Total Project Arrears: \$${totalProjectArrears.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange,
          ),
        ),
      );
    }

    containerChildren.add(pw.Divider());

    // Grand Total
    containerChildren.add(
      pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'GRAND TOTAL: \$${grandTotal.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red,
          ),
        ),
      ),
    );

    // Return a single Container with the Column inside
    final List<pw.Widget> result = [];
    result.add(pw.SizedBox(height: 10));
    result.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: containerChildren,
        ),
      ),
    );

    return result;
  }

  Future<void> _generateSummarizedPdf(List<Student> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No students to generate summary PDF for')),
      );
      return;
    }

    final progressNotifier = ValueNotifier<int>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (context, count, _) => Text(
                count == 0
                    ? 'Generating Summary Report for ${students.length} students...'
                    : 'Processing student $count of ${students.length}...',
              ),
            ),
          ],
        ),
      ),
    );
    // See comment in _generateMultiPagePdf - without this yield, the loop
    // below can run to completion before the dialog ever gets painted.
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final pdf = pw.Document();
      final schoolInfo = await _fetchSchoolInfo();
      final loggedInUser = getLoggedInUser();
      final username = loggedInUser?.username ?? 'Unknown User';

      // Collect arrears data for all students
      final List<Map<String, dynamic>> studentData = [];
      double totalArrears = 0.0;

      for (var i = 0; i < students.length; i++) {
        final student = students[i];
        final originalSelectedStudent = _selectedStudent;
        _selectedStudent = student;

        final feesArrears = await _computeTotalStudentArrears(student);
        final studentId = student.studentIdNumber.toString();
        final projectArrearsDetails = buildStudentArrearsDetails(studentId);
        final totalProjectArrears =
            projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);
        final grandTotal = feesArrears + totalProjectArrears;

        studentData.add({
          'student': student,
          'arrears': grandTotal,
          'feesArrears': feesArrears,
          'projectArrears': totalProjectArrears,
        });
        totalArrears += grandTotal;

        _selectedStudent = originalSelectedStudent;
        progressNotifier.value = i + 1;
        // Yield every few students so the counter above actually gets a
        // chance to paint instead of jumping straight from 0 to the total.
        if (i % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      // Sort alphabetically by surname
      studentData.sort((a, b) {
        final surnameA = (a['student'] as Student).surname?.toLowerCase() ?? '';
        final surnameB = (b['student'] as Student).surname?.toLowerCase() ?? '';
        return surnameA.compareTo(surnameB);
      });

      // Split into cleared (arrears == 0) and with arrears (arrears > 0)
      final clearedStudents =
          studentData.where((d) => d['arrears'] == 0).toList();
      final arrearsStudents =
          studentData.where((d) => d['arrears'] > 0).toList();

      // Sort arrears students by amount (highest first)
      arrearsStudents.sort((a, b) => b['arrears'].compareTo(a['arrears']));

      // Calculate how many rows fit per page (leaving room for header, stats, etc.)
      const int rowsPerPage = 25; // Adjust based on your needs

      // Build pages
      int pageNumber = 1;
      int totalPages = 0;

      // Calculate total pages needed
      final clearedPages = (clearedStudents.length / rowsPerPage).ceil();
      final arrearsPages = (arrearsStudents.length / rowsPerPage).ceil();
      totalPages = clearedPages + arrearsPages;
      if (totalPages == 0) totalPages = 1;

      // Inside _generateSummarizedPdf method, update the addSummaryPage function:

      void addSummaryPage({
        required String title,
        required Color titleColor,
        required List<Map<String, dynamic>> data,
        required int startIndex,
        required int pageNum,
        required int totalPages,
        required int totalStudents,
        required int clearedCount,
        required double totalArrears,
        required bool showStats,
        required School schoolInfo,
        required String username,
        required List<String> terms, // Add this parameter
      }) {
        final endIndex = (startIndex + rowsPerPage > data.length)
            ? data.length
            : startIndex + rowsPerPage;
        final pageData = data.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildSummaryPdfHeader(
                    schoolInfo,
                    totalStudents,
                    totalArrears,
                    pageNum,
                    totalPages,
                    terms, // Pass the terms
                  ),
                  pw.SizedBox(height: 8),

                  // Show stats only on first page
                  if (showStats) ...[
                    _buildSummaryStats(
                        totalStudents, clearedCount, totalArrears),
                    pw.SizedBox(height: 12),
                  ],

                  // Section Title
                  pw.Text(
                    '$title (${data.length})',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: titleColor == Colors.green
                          ? PdfColors.green
                          : PdfColors.red,
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Table
                  _buildStudentSummaryTable(pageData, startIndex),
                  pw.SizedBox(height: 10),

                  // Footer
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 6),
                  _buildPdfFooter(username),
                ],
              );
            },
          ),
        );
      }

      // Add Cleared Students pages
      int currentPage = 1;
      bool showStats = true;

      // For Cleared Students:
      if (clearedStudents.isNotEmpty) {
        for (int i = 0; i < clearedStudents.length; i += rowsPerPage) {
          addSummaryPage(
            title: 'SECTION 1: CLEARED STUDENTS',
            titleColor: Colors.green,
            data: clearedStudents,
            startIndex: i,
            pageNum: currentPage,
            totalPages: totalPages,
            totalStudents: students.length,
            clearedCount: clearedStudents.length,
            totalArrears: totalArrears,
            showStats: showStats,
            schoolInfo: schoolInfo,
            username: username,
            terms: _selectedFilterTerms.isNotEmpty
                ? _selectedFilterTerms
                : _terms, // Pass the terms
          );
          currentPage++;
          showStats = false;
        }
      }

// For Students With Arrears:
      if (arrearsStudents.isNotEmpty) {
        showStats = true;

        for (int i = 0; i < arrearsStudents.length; i += rowsPerPage) {
          addSummaryPage(
            title: 'SECTION 2: STUDENTS WITH ARREARS',
            titleColor: Colors.red,
            data: arrearsStudents,
            startIndex: i,
            pageNum: currentPage,
            totalPages: totalPages,
            totalStudents: students.length,
            clearedCount: clearedStudents.length,
            totalArrears: totalArrears,
            showStats: showStats,
            schoolInfo: schoolInfo,
            username: username,
            terms: _selectedFilterTerms.isNotEmpty
                ? _selectedFilterTerms
                : _terms, // Pass the terms
          );
          currentPage++;
          showStats = false;
        }
      }

      final pdfBytes = await pdf.save();

      if (mounted) Navigator.pop(context);

      // Show PDF preview
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Summary Report - ${students.length} Students',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf,
                                color: Colors.red),
                            onPressed: () async {
                              // Save or share PDF
                              final bytes = await pdf.save();
                              // Implement save/share functionality
                            },
                            tooltip: 'Save PDF',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdfBytes,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating summary PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      progressNotifier.dispose();
    }
  }

  pw.Widget _buildSummaryPdfHeader(
    School schoolInfo,
    int totalStudents,
    double totalArrears,
    int pageNum,
    int totalPages,
    List<String> terms, // Add this parameter
  ) {
    // Format the terms list for display
    final bool isAdmin = _isAdminUser();

    final sortedTerms = _sortTermsChronologically(terms);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          schoolInfo.schoolName?.toUpperCase() ?? 'SCHOOL NAME',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(schoolInfo.schoolAddress ?? 'Address'),
        pw.Text(schoolInfo.schoolPhoneNumber ?? ''),
        pw.SizedBox(height: 8),
        pw.Text(
          'STUDENT ARREARS SUMMARY REPORT',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('Total Students: $totalStudents'),
            pw.SizedBox(width: 20),
            if (isAdmin) ...[
              pw.Text('Total Arrears: \$${totalArrears.toStringAsFixed(2)}'),
            ],
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10),
          constraints: const pw.BoxConstraints(maxWidth: 500),
          child: pw.Wrap(
            alignment: pw.WrapAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              pw.Text(
                'Terms: ',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey,
                    fontWeight: pw.FontWeight.bold),
              ),
              ...sortedTerms
                  .map((term) => pw.Text(
                        term,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey),
                      ))
                  .toList(),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Page $pageNum of $totalPages',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
      ],
    );
  }

  pw.Widget _buildStudentSummaryTable(
      List<Map<String, dynamic>> data, int startIndex) {
    if (data.isEmpty) {
      return pw.Text('No students in this category.',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(25), // #
        1: const pw.FixedColumnWidth(70), // Surname
        2: const pw.FixedColumnWidth(70), // Name
        3: const pw.FixedColumnWidth(40), // Gender
        4: const pw.FixedColumnWidth(65), // Arrears
        5: const pw.FixedColumnWidth(100), // Parent Phone
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildSummaryTableCell('№', isHeader: true),
            _buildSummaryTableCell('Surname', isHeader: true),
            _buildSummaryTableCell('Name', isHeader: true),
            _buildSummaryTableCell('Gender', isHeader: true),
            _buildSummaryTableCell('Arrears',
                isHeader: true, alignment: pw.Alignment.centerRight),
            _buildSummaryTableCell('Parent Phone', isHeader: true),
          ],
        ),
        // Rows
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final student = item['student'] as Student;
          final arrears = item['arrears'] as double;
          final isEven = index % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.grey50 : PdfColors.white,
            ),
            children: [
              _buildSummaryTableCell('${startIndex + index + 1}'),
              _buildSummaryTableCell(student.surname ?? ''),
              _buildSummaryTableCell(student.name ?? ''),
              _buildSummaryTableCell(student.gender ?? ''),
              _buildSummaryTableCell(
                '\$${arrears.toStringAsFixed(2)}',
                alignment: pw.Alignment.centerRight,
                textColor: arrears > 0 ? PdfColors.red : PdfColors.green,
              ),
              _buildSummaryTableCell(student.phoneNumber ?? ''),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildSummaryTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    PdfColor textColor = PdfColors.black,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: alignment,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 10 : 9,
          color: textColor,
        ),
        textAlign: alignment == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : alignment == pw.Alignment.center
                ? pw.TextAlign.center
                : pw.TextAlign.left,
      ),
    );
  }

  bool _isAdminUser() {
    final loggedInUser = getLoggedInUser();
    if (loggedInUser == null) return false;

    final role = loggedInUser.role?.toLowerCase() ?? '';
    return role == 'admin' || role == 'administration';
  }

// Build summary stats widget
  pw.Widget _buildSummaryStats(
      int totalStudents, int clearedCount, double totalArrears) {
    final withArrears = totalStudents - clearedCount;
    final bool isAdmin = _isAdminUser(); // Define isAdmin here

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.green100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Cleared',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.green700),
              ),
              pw.Text(
                clearedCount.toString(),
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.red100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'With Arrears',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.red700),
              ),
              pw.Text(
                withArrears.toString(),
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red700),
              ),
            ],
          ),
        ),
        // CONDITIONAL: Only show Total Arrears if user is admin
        if (isAdmin)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Total Arrears',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.blue700),
                ),
                pw.Text(
                  '\$${totalArrears.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700),
                ),
              ],
            ),
          ),
      ],
    );
  }

// Helper method to sort terms chronologically
  List<String> _sortTermsChronologically(List<String> terms) {
    // Parse term strings and sort by year, then month
    final monthOrder = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    // Extract year and month from term string
    List<Map<String, dynamic>> parsedTerms = [];
    for (var term in terms) {
      // Try to extract year and month
      final yearMatch = RegExp(r'(\d{4})').firstMatch(term);
      final monthMatch =
          RegExp(r'\((\w+)\)', caseSensitive: false).firstMatch(term);

      int year = yearMatch != null ? int.parse(yearMatch.group(1)!) : 0;
      int month = 0;

      if (monthMatch != null) {
        final monthName = monthMatch.group(1)!.toLowerCase();
        month = monthOrder[monthName] ?? 0;
      } else {
        // Try to extract term number if no month
        final termNumMatch =
            RegExp(r'Term\s+(\d+)', caseSensitive: false).firstMatch(term);
        if (termNumMatch != null) {
          // Default months based on term number (approximate)
          final termNum = int.parse(termNumMatch.group(1)!);
          month = (termNum - 1) * 3 +
              1; // Term 1 -> Jan, Term 2 -> Apr, Term 3 -> Jul, Term 4 -> Oct
        }
      }

      parsedTerms.add({
        'term': term,
        'year': year,
        'month': month,
      });
    }

    // Sort by year, then month
    parsedTerms.sort((a, b) {
      if (a['year'] != b['year']) return a['year'].compareTo(b['year']);
      return a['month'].compareTo(b['month']);
    });

    return parsedTerms.map((e) => e['term'] as String).toList();
  }

// Add this method to your state class
  bool _hasFiltersApplied() {
    // Check if any filters are active
    // This checks if cachedFilteredStudents is different from all students
    // or if any students are selected
    if (_cachedFilteredStudents != null) {
      // Check if filtered students list is different from full list
      final allStudents = _students;
      final filteredStudents = _cachedFilteredStudents!;

      // If the lists have different lengths, filters are applied
      if (allStudents.length != filteredStudents.length) {
        return true;
      }

      // Check if the lists contain different students (order might differ)
      final allIds = allStudents.map((s) => s.studentIdNumber).toSet();
      final filteredIds =
          filteredStudents.map((s) => s.studentIdNumber).toSet();
      if (!allIds.containsAll(filteredIds) ||
          !filteredIds.containsAll(allIds)) {
        return true;
      }
    }

    // Also check if students are selected (this is a form of filtering)
    final selectedStudents = _getSelectedStudents();
    if (selectedStudents.isNotEmpty &&
        selectedStudents.length < _students.length) {
      return true;
    }

    // No filters applied
    return false;
  }

// Full student PDF section with arrears details
  List<pw.Widget> _buildFullStudentPdfSection(
      Student student, dynamic arrearsData) {
    final purposeList = arrearsData?['purposeList'] ?? [];
    final feesArrears = arrearsData?['feesArrears'] ?? 0.0;
    final projectArrearsDetails = arrearsData?['projectArrearsDetails'] ?? [];
    final totalProjectArrears = arrearsData?['totalProjectArrears'] ?? 0.0;
    final grandTotal = arrearsData?['grandTotal'] ?? 0.0;

    return [
      pw.SizedBox(height: 20),
      pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Student Header
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${student.name} ${student.surname}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'ID: ${student.studentIdNumber}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Student Info
            pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Text('Class: ${student.class_ ?? "N/A"}')),
                pw.Expanded(
                    child: pw.Text('Phone: ${student.phoneNumber ?? "N/A"}')),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Fees Arrears Section
            pw.Text('Fees Arrears:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            if (purposeList.isNotEmpty)
              ...purposeList.map((entry) {
                final purpose = entry['purpose'];
                final preview = entry['arrearsPreview'];
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
                  child: pw.Text('• ${purpose.paymentPurpose}: $preview',
                      style: const pw.TextStyle(fontSize: 11)),
                );
              }).toList(),
            pw.SizedBox(height: 5),
            pw.Text('Total Fees Arrears: \$${feesArrears.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.red)),

            // Project Arrears Section
            if (projectArrearsDetails.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Project Arrears:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ...projectArrearsDetails
                  .map((detail) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
                        child: pw.Text(
                            '• ${detail.projectName}: \$${detail.arrears.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              pw.SizedBox(height: 5),
              pw.Text(
                  'Total Project Arrears: \$${totalProjectArrears.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
            ],

            pw.Divider(),

            // Grand Total
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'GRAND TOTAL: \$${grandTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  pw.Widget _buildPdfHeader(School schoolInfo, int pageNum, int totalPages) {
    return pw.Column(
      children: [
        pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Column(children: [
            pw.Text(
              'STUDENT ARREARS STATEMENT',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(schoolInfo.schoolName ?? 'School Name'),
            pw.Text(schoolInfo.schoolAddress ?? 'Address'),
            pw.SizedBox(height: 5),
            pw.Text('Page $pageNum of $totalPages',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            pw.Divider(thickness: 2),
          ]),
        ),
      ],
    );
  }

  pw.Widget _buildPdfFooter(String username) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
        pw.Text('Generated by: $username',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        pw.Text('Generated on: ${DateTime.now().toString().substring(0, 19)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
      ],
    );
  }

  void _updateSelectionSummary() {
    // Check if _students is initialized
    if (_students.isEmpty && _cachedFilteredStudents == null) {
      setState(() {
        _selectionSummary = 'Loading students...';
      });
      return;
    }

    final selectedStudents = _getSelectedStudents();
    if (selectedStudents.isEmpty) {
      setState(() {
        _selectionSummary = 'No students selected';
      });
    } else {
      final studentNames = selectedStudents
          .map((s) => '${s.name} ${s.surname}')
          .take(3) // Show only first 3 names to keep it readable
          .join(', ');
      final remaining = selectedStudents.length - 3;
      setState(() {
        _selectionSummary =
            '${selectedStudents.length} student(s) selected: $studentNames${remaining > 0 ? ' + $remaining more' : ''}';
      });
    }
  }

  void _showSelectedStudentsActions(List<Student> selectedStudents) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Selected Students'),
              subtitle: Text('Choose an action'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Generate PDF for Selected'),
              onTap: () {
                Navigator.pop(context);
                _generateMultiPagePdf(selectedStudents);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.green),
              title: const Text('Add to Print Queue'),
              onTap: () {
                Navigator.pop(context);
                _addToPrintQueue(selectedStudents);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print Immediately'),
              onTap: () {
                Navigator.pop(context);
                _printSelectedStudents(selectedStudents);
              },
            ),
            // Add a new action for quick print
            ListTile(
              leading: const Icon(Icons.local_printshop, color: Colors.orange),
              title: const Text('Quick Print Selected (from bottom sheet)'),
              onTap: () {
                Navigator.pop(context);
                if (selectedStudents.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No students selected for printing'),
                    ),
                  );
                  return;
                }
                _addToPrintQueue(selectedStudents);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSelectedStudents(List<Student> students) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var student in students) {
        await _printStudentStatement(student);
        await Future.delayed(
            const Duration(seconds: 1)); // Delay between prints
      }
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printed ${students.length} statements')),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error printing: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _onSearchSubmitted(String query) {
    if (query.isEmpty) return;

    _searchStudent(query, showDialog: true);
  }

  double get totalEntered =>
      _paymentPurposes.fold(0.0, (sum, p) => sum + (p['currentAmount'] ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;

    if (globalTermId != null) {
      return Stack(
        children: [
          Scaffold(
            floatingActionButton: _buildFloatingActionButton(),
            appBar: AppBar(
              title: const Center(
                child: Text(
                  'Student Arrears Statements',
                  style: TextStyle(
                    fontSize: 14.0, // Adjust font size
                    fontWeight: FontWeight.normal, // Bold font
                    color: Colors.white, // Title color
                    letterSpacing: 1.2, // Slight letter spacing for elegance
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.summarize),
                  onPressed: _hasFiltersApplied()
                      ? () {
                          final studentsToPrint =
                              _cachedFilteredStudents ?? _students;
                          if (studentsToPrint.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'No students available to generate summary'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          _generateSummarizedPdf(studentsToPrint);
                        }
                      : null,
                  tooltip: _hasFiltersApplied()
                      ? 'Generate Summary Report'
                      : '⚠️ Apply filters or select students first',
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () async {
                    // Show persistent loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => WillPopScope(
                        onWillPop: () async => false,
                        child: const AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Loading student data...',
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please wait',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    try {
                      // Wait for the actual load to finish - not a heuristic
                      // like "_students has at least one entry", which
                      // terminates early on partial data (e.g. only the
                      // first class synced so far) and made the class filter
                      // look like it only ever offered one class.
                      await _initialLoadFuture;

                      if (mounted) Navigator.pop(context);

                      final hasData = _students.isNotEmpty ||
                          (_cachedFilteredStudents != null &&
                              _cachedFilteredStudents!.isNotEmpty);

                      if (!hasData) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Failed to load student data. Please try again.'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }

                      final currentSelections =
                          Map<String, bool>.from(_selectedStudents);

                      await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (context) => FilterDialog(
                          students: _students.isNotEmpty
                              ? _students
                              : (_cachedFilteredStudents ?? []),
                          initialSelections: currentSelections,
                          selectedTerms: _selectedFilterTerms,
                          users: _users, // ✅ Pass the users list here
                          knownClasses: _knownClasses,
                          onFetchClassStudents: _role == DeviceRole.host
                              ? null
                              : _fetchStudentsForClassOnDemand,
                          onFilterApplied: (filteredStudents, selectedTerms,
                              arrearsFilterType) {
                            setState(() {
                              _cachedFilteredStudents = filteredStudents;
                              _selectedFilterTerms = selectedTerms;
                              _selectedStudents.clear();
                              for (var student in filteredStudents) {
                                _selectedStudents[
                                    student.studentIdNumber.toString()] = true;
                              }
                              _selectAll = true;
                              _arrearsVersion++;
                            });
                          },
                        ),
                      );
                    } catch (e) {
                      if (mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading data: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  tooltip: 'Filter & Select Students',
                ),
                // Multi-page PDF button
                // Multi-page PDF button - With better UX
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _hasFiltersApplied()
                      ? () {
                          final studentsToPrint =
                              _cachedFilteredStudents ?? _students;
                          if (studentsToPrint.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'No students available to generate PDF'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          _generateMultiPagePdf(studentsToPrint);
                        }
                      : null,
                  tooltip: _hasFiltersApplied()
                      ? 'Generate PDF Statement'
                      : '⚠️ Apply filters or select students first',
                ),
                // Print Queue button
                IconButton(
                  icon: Badge(
                    label: Text('${_printQueueManager.queue.length}'),
                    isLabelVisible: _printQueueManager.queue.isNotEmpty,
                    child: const Icon(Icons.print),
                  ),
                  onPressed: () {
                    final studentsToPrint =
                        _cachedFilteredStudents ?? _students;
                    _addToPrintQueue(studentsToPrint);
                  },
                  tooltip: 'Print Queue',
                ),
              ],
              backgroundColor: const Color.fromARGB(255, 38, 140, 191),
            ),
            body: Center(
              child: SingleChildScrollView(
                controller: _mainScrollController, // Add this controller
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromRGBO(255, 255, 255, 1),
                        Color.fromRGBO(255, 255, 255, 1)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      RefreshIndicator(
                        onRefresh: () =>
                            bluetoothHelper.bluetoothPrint.startScan(
                          timeout: const Duration(seconds: 5),
                        ),
                        child: SingleChildScrollView(
                            child: // In your build method, where the printer UI is
                                Column(
                          children: [
                            // Platform indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isWindows
                                    ? Colors.blue.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isWindows
                                        ? Icons.computer
                                        : Icons.phone_android,
                                    size: 16,
                                    color: _isWindows
                                        ? Colors.blue.shade900
                                        : Colors.green.shade900,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isWindows
                                        ? 'WINDOWS MODE'
                                        : 'ANDROID MODE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isWindows
                                          ? Colors.blue.shade900
                                          : Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _connected
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _connected
                                        ? Icons.check_circle
                                        : Icons.warning,
                                    size: 14,
                                    color: _connected
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _connected ? 'Connected' : 'Not Connected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _connected
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Platform-specific printer UI
                            if (_isWindows) ...[
                              // Windows Printer Selection
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _isLoadingPrinters
                                              ? const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16),
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                )
                                              : DropdownButtonFormField<String>(
                                                  value:
                                                      _selectedWindowsPrinter,
                                                  hint: const Text(
                                                      'Select Windows Printer'),
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                  ),
                                                  items: [
                                                    const DropdownMenuItem(
                                                      value: null,
                                                      child: Text(
                                                          '-- Select a printer --'),
                                                    ),
                                                    ..._windowsPrinters
                                                        .map((printer) {
                                                      bool isLastUsed =
                                                          printer ==
                                                              _lastUsedPrinter;
                                                      return DropdownMenuItem(
                                                        value: printer,
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                printer,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            if (isLastUsed &&
                                                                !_connected)
                                                              const Icon(
                                                                Icons.history,
                                                                size: 16,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                            if (isLastUsed &&
                                                                _connected)
                                                              const Icon(
                                                                Icons
                                                                    .check_circle,
                                                                size: 16,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                          ],
                                                        ),
                                                      );
                                                    }),
                                                  ],
                                                  onChanged:
                                                      _isTestingConnection
                                                          ? null
                                                          : (value) {
                                                              setState(() {
                                                                _selectedWindowsPrinter =
                                                                    value;
                                                                _connected =
                                                                    false; // Reset connection when printer changes
                                                              });
                                                            },
                                                ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          onPressed: _isLoadingPrinters
                                              ? null
                                              : _loadWindowsPrinters,
                                          tooltip: 'Refresh printers',
                                        ),
                                        if (_lastUsedPrinter != null &&
                                            !_connected &&
                                            !_isTestingConnection)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: TextButton.icon(
                                              onPressed:
                                                  _autoConnectLastPrinter,
                                              icon: const Icon(Icons.history,
                                                  size: 16),
                                              label: Text(
                                                  'Reconnect to: $_lastUsedPrinter'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.blue,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _connected ||
                                                    _isTestingConnection ||
                                                    _selectedWindowsPrinter ==
                                                        null
                                                ? null
                                                : _connectWindowsPrinter,
                                            icon: _isTestingConnection
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2),
                                                  )
                                                : const Icon(Icons.link),
                                            label: Text(_isTestingConnection
                                                ? 'Connecting...'
                                                : 'Connect'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: !_connected
                                                ? null
                                                : _disconnectPrinter,
                                            icon: const Icon(Icons.link_off),
                                            label: const Text('Disconnect'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                  color: Colors.red),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (_selectedWindowsPrinter != null &&
                                  !_connected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Selected: $_selectedWindowsPrinter',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.blue),
                                  ),
                                ),
                            ],

                            if (_isAndroid) ...[
                              // Android Bluetooth UI
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 10),
                                          child: Text(tips),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    StreamBuilder<List<BluetoothDevice>>(
                                      stream: bluetoothHelper
                                          .bluetoothPrint.scanResults,
                                      initialData: const [],
                                      builder: (c, snapshot) => Column(
                                        children: snapshot.data!
                                            .map((d) => ListTile(
                                                  title: Text(d.name ?? ''),
                                                  subtitle:
                                                      Text(d.address ?? ''),
                                                  onTap: () async {
                                                    setState(() {
                                                      _device = d;
                                                      _connected = false;
                                                    });
                                                  },
                                                  trailing: _device != null &&
                                                          _device!.address ==
                                                              d.address
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green)
                                                      : null,
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _connected
                                                ? null
                                                : _connectBluetoothPrinter,
                                            icon: const Icon(
                                                Icons.bluetooth_connected),
                                            label: const Text('Connect'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: !_connected
                                                ? null
                                                : _disconnectPrinter,
                                            icon: const Icon(
                                                Icons.bluetooth_disabled),
                                            label: const Text('Disconnect'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                  color: Colors.red),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        )),
                      ),
                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode
                            .onUserInteraction, // Automatically triggers validation

                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            if (_selectedStudents.isNotEmpty)
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 8, bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '📋 Selection Summary',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (_selectedFilterTerms.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  top: 8, bottom: 8),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.orange.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.filter_alt,
                                                      size: 16,
                                                      color: Colors.orange),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Filtered by Terms: ${_selectedFilterTerms.join(", ")}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .orange.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.close,
                                                        size: 16),
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedFilterTerms
                                                            .clear();
                                                        _cachedFilteredStudents =
                                                            null;
                                                        _arrearsVersion++;
                                                      });
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Print selected button
                                    if (_getSelectedStudents().isNotEmpty)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                        onPressed: () {
                                          final selectedStudents =
                                              _getSelectedStudents();
                                          if (selectedStudents.isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'No students selected for printing'),
                                              ),
                                            );
                                            return;
                                          }
                                          _addToPrintQueue(selectedStudents);
                                        },
                                        icon: const Icon(Icons.print, size: 18),
                                        label: Text(
                                          'Print Selected (${_getSelectedStudents().length})',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (_selectedStudent != null)
                              Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 10),
                                      if (_selectedStudent != null)
                                        Builder(
                                          builder: (_) {
                                            final studentId = _selectedStudent!
                                                .studentIdNumber
                                                .toString();

                                            // 🔹 PROJECT ARREARS
                                            final projectArrearsDetails =
                                                buildStudentArrearsDetails(
                                                    studentId);

                                            final totalProjectArrears =
                                                projectArrearsDetails
                                                    .fold<double>(
                                              0,
                                              (sum, e) => sum + e.arrears,
                                            );

                                            return Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 20),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    /// 👤 STUDENT INFO
                                                    Text(
                                                        'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}'),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                        'Class: ${_selectedStudent!.class_}'),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                        '${_selectedStudent!.paymentStatus}: ${_selectedStudent!.phoneNumber}'),

                                                    if (_selectedStudent!
                                                                .emergencyContactNumber !=
                                                            null &&
                                                        _selectedStudent!
                                                            .emergencyContactNumber!
                                                            .isNotEmpty)
                                                      Text(
                                                          '${_selectedStudent!.emergencyContactName}: ${_selectedStudent!.emergencyContactNumber}'),

                                                    const Divider(height: 30),
                                                    if (_selectedStudent !=
                                                        null)

                                                      /// 💰 FEES ARREARS (Existing Future)
                                                      FutureBuilder<double>(
                                                        future:
                                                            _totalArrearsFuture,
                                                        builder: (context,
                                                            snapshot) {
                                                          if (snapshot
                                                                  .connectionState ==
                                                              ConnectionState
                                                                  .waiting) {
                                                            return const Text(
                                                              'Calculating total arrears...',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic),
                                                            );
                                                          }

                                                          if (snapshot
                                                              .hasError) {
                                                            return Text(
                                                              'Error fetching arrears: ${snapshot.error}',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .red),
                                                            );
                                                          }

                                                          final feesArrears =
                                                              snapshot.data ??
                                                                  0.0;

                                                          final grandTotal =
                                                              feesArrears +
                                                                  totalProjectArrears;

                                                          return Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              /// =========================
                                                              /// 🔥 GRAND TOTAL
                                                              /// =========================
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        14),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  gradient:
                                                                      LinearGradient(
                                                                    colors: [
                                                                      Colors.red
                                                                          .withOpacity(
                                                                              0.1),
                                                                      Colors
                                                                          .deepOrange
                                                                          .withOpacity(
                                                                              0.1),
                                                                    ],
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .red
                                                                          .withOpacity(
                                                                              0.2)),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .account_balance_wallet,
                                                                        color: Colors
                                                                            .red),
                                                                    const SizedBox(
                                                                        width:
                                                                            10),
                                                                    const Expanded(
                                                                      child:
                                                                          Text(
                                                                        'Total Student\'s Outstanding',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      '\$${grandTotal.toStringAsFixed(2)}',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            18,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .red,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 16),

                                                              /// =========================
                                                              /// 📋 PROJECT ARREARS HEADER
                                                              /// =========================
                                                              if (projectArrearsDetails
                                                                  .isNotEmpty)
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          12),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .deepPurple
                                                                        .withOpacity(
                                                                            0.06),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .deepPurple
                                                                            .withOpacity(0.15)),
                                                                  ),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const Text(
                                                                        '📋 Project Arrears Overview',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.deepPurple,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              10),

                                                                      /// =========================
                                                                      /// PROJECT CARDS
                                                                      /// =========================
                                                                      ...projectArrearsDetails
                                                                          .map(
                                                                              (s) {
                                                                        return Container(
                                                                          margin: const EdgeInsets
                                                                              .symmetric(
                                                                              vertical: 6),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                Colors.white,
                                                                            borderRadius:
                                                                                BorderRadius.circular(12),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: Colors.black.withOpacity(0.05),
                                                                                blurRadius: 6,
                                                                                offset: const Offset(0, 3),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          child:
                                                                              Padding(
                                                                            padding:
                                                                                const EdgeInsets.all(12),
                                                                            child:
                                                                                Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                /// PROJECT NAME
                                                                                Row(
                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                  children: [
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        s.projectName,
                                                                                        style: const TextStyle(
                                                                                          fontSize: 15,
                                                                                          fontWeight: FontWeight.bold,
                                                                                          color: Colors.black87,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    Container(
                                                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                                                      decoration: BoxDecoration(
                                                                                        color: Colors.red.withOpacity(0.1),
                                                                                        borderRadius: BorderRadius.circular(20),
                                                                                      ),
                                                                                      child: Text(
                                                                                        "\$${s.arrears.toStringAsFixed(2)}",
                                                                                        style: const TextStyle(
                                                                                          color: Colors.red,
                                                                                          fontWeight: FontWeight.bold,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),

                                                                                const SizedBox(height: 8),

                                                                                /// ITEM DETAILS
                                                                                Text(
                                                                                  'Item: ${s.itemName}',
                                                                                  style: TextStyle(
                                                                                    color: Colors.grey.shade700,
                                                                                    fontSize: 13,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(height: 4),
                                                                                Text(
                                                                                  'Batch: ${s.batchName}',
                                                                                  style: TextStyle(
                                                                                    color: Colors.grey.shade600,
                                                                                    fontSize: 13,
                                                                                  ),
                                                                                ),

                                                                                const SizedBox(height: 12),

                                                                                /// ACTION BUTTONS
                                                                                Row(
                                                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                                                  children: [
                                                                                    /// FULL PAY
                                                                                    ElevatedButton.icon(
                                                                                      style: ElevatedButton.styleFrom(
                                                                                        backgroundColor: Colors.redAccent,
                                                                                        foregroundColor: Colors.white,
                                                                                        shape: RoundedRectangleBorder(
                                                                                          borderRadius: BorderRadius.circular(10),
                                                                                        ),
                                                                                      ),
                                                                                      icon: const Icon(Icons.payments, size: 18),
                                                                                      label: const Text("Pay Full"),
                                                                                      onPressed: () {
                                                                                        Navigator.push(
                                                                                          context,
                                                                                          MaterialPageRoute(
                                                                                            builder: (_) => const ProjectPaymentScreen(),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    ),

                                                                                    const SizedBox(width: 10),

                                                                                    /// PARTIAL PAY
                                                                                    ElevatedButton.icon(
                                                                                      style: ElevatedButton.styleFrom(
                                                                                        backgroundColor: Colors.deepPurple,
                                                                                        foregroundColor: Colors.white,
                                                                                        shape: RoundedRectangleBorder(
                                                                                          borderRadius: BorderRadius.circular(10),
                                                                                        ),
                                                                                      ),
                                                                                      icon: const Icon(Icons.payment, size: 18),
                                                                                      label: const Text("Partial"),
                                                                                      onPressed: () {
                                                                                        Navigator.push(
                                                                                          context,
                                                                                          MaterialPageRoute(
                                                                                            builder: (_) => const ProjectPaymentScreen(),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }),
                                                                    ],
                                                                  ),
                                                                ),

                                                              const SizedBox(
                                                                  height: 12),

                                                              /// =========================
                                                              /// 📦 TOTAL PROJECT ARREARS
                                                              /// =========================
                                                              if (totalProjectArrears >
                                                                  0)
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          12),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .orange
                                                                        .withOpacity(
                                                                            0.08),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .orange
                                                                            .withOpacity(0.2)),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      const Icon(
                                                                          Icons
                                                                              .warning_amber_rounded,
                                                                          color:
                                                                              Colors.orange),
                                                                      const SizedBox(
                                                                          width:
                                                                              10),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          'Project Arrears Total',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color:
                                                                                Colors.grey.shade800,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        '\$${totalProjectArrears.toStringAsFixed(2)}',
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.deepOrange,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    const SizedBox(height: 52),

                                                    // Replace the entire FutureBuilder with this:
                                                    ArrearsSection(
                                                      key:
                                                          _arrearsSectionKey, // Force rebuild when version changes
                                                      student:
                                                          _selectedStudent!,
                                                      version: _arrearsVersion,
                                                      onItemsSelected:
                                                          _handleArrearsSelected,
                                                      getSelectedSubPurposes:
                                                          _getSelectedSubPurposes,
                                                      setSelectedSubPurposes:
                                                          _setSelectedSubPurposes,
                                                      fetchArrears:
                                                          _fetchArrearsWithRestorations,
                                                      restoredItems:
                                                          _pendingRestorations,
                                                      onRefreshRequested: () {},
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // If globalTermId is null, show an alternative UI or a message
      return Scaffold(
          appBar: AppBar(
            title: const Text('No Selected Term Found'),
          ),
          body: const Center(
            child: Text(
              'No term is currently active. Either switch to an existing term or create a new term to proceed.',
              style: TextStyle(
                fontSize: 16.0, // Set font size
                fontWeight: FontWeight.bold, // Set font weight
                color: Colors.redAccent, // Set text color
                letterSpacing: 1.2, // Set spacing between letters
                height: 1.5, // Set line height (space between lines)
              ),
              textAlign: TextAlign.center, // Align text to the center
            ),
          ));
    }
  }

// Filter students based on teacher's assigned classes
  // Filter students based on teacher's assigned classes (case-insensitive)
  List<Student> _filterStudentsByTeacherClasses(List<Student> students) {
    if (!_isTeacher()) return students;

    final assignedClasses = _getTeacherAssignedClasses();
    if (assignedClasses.isEmpty) return students; // No restrictions

    // Convert assigned classes to lowercase for case-insensitive comparison
    final assignedClassesLower =
        assignedClasses.map((c) => c.toLowerCase()).toList();

    return students.where((student) {
      final studentClass = student.class_?.toLowerCase() ?? '';
      return assignedClassesLower.contains(studentClass);
    }).toList();
  }

// Get terms that are valid (start date is on or before current month)
  List<Terms> _getValidTermsForCurrentMonth() {
    // ✅ If not a teacher, return ALL terms
    if (!_isTeacher()) {
      return _role == DeviceRole.host
          ? Hive.box<Terms>('terms').values.toList()
          : _cachedServerTerms ?? [];
    }

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    return allTerms.where((term) {
      // Include terms where start date is on or before the current month
      final termStart = DateTime(term.startDate.year, term.startDate.month, 1);
      return termStart.compareTo(currentMonth) <= 0;
    }).toList();
  }

// Get term IDs that should be excluded (future terms) - ONLY for teachers
  List<String> _getExcludedFutureTermIds() {
    // ✅ If not a teacher, return empty list (no exclusions)
    if (!_isTeacher()) return [];

    final validTerms = _getValidTermsForCurrentMonth();
    final validTermIds = validTerms.map((t) => t.termId).toSet();

    List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    return allTerms
        .where((term) => !validTermIds.contains(term.termId))
        .map((t) => t.termId)
        .toList();
  }

// Add this map to store updated arrears amounts
  final Map<String, Map<String, double>> _updatedArrearsCache = {};

  Future<List<Map<String, dynamic>>> _fetchArrearsWithRestorations(
      Student student) async {
    // Fetch original arrears
    List<Map<String, dynamic>> originalArrears =
        await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviwNew(
            student);

    if (_pendingRestorations.isEmpty) {
      return originalArrears;
    }

    // Create a map keyed by purpose NAME only (NOT including termId)
    Map<String, Map<String, dynamic>> purposeMap = {};
    for (var item in originalArrears) {
      final purpose = item['purpose'];
      final purposeName = purpose.paymentPurpose ?? '';
      purposeMap[purposeName] = item;
    }

    // Group restorations by purpose name
    Map<String, List<Map<String, dynamic>>> groupedRestorations = {};
    for (var restoration in _pendingRestorations) {
      final purpose = restoration['purpose'];
      final purposeName = purpose.paymentPurpose ?? '';
      if (!groupedRestorations.containsKey(purposeName)) {
        groupedRestorations[purposeName] = [];
      }
      groupedRestorations[purposeName]!.add(restoration);
    }

    // Apply restorations to matching purposes
    for (var entry in groupedRestorations.entries) {
      final purposeName = entry.key;
      final restorations = entry.value;

      if (purposeMap.containsKey(purposeName)) {
        final existingItem = purposeMap[purposeName]!;

        // Calculate total restoration amount for this purpose
        double totalRestorationAmount = 0;
        for (var restoration in restorations) {
          totalRestorationAmount += restoration['amount'] as double;
        }

        // Update the parent purpose amount
        final existingPreview = existingItem['arrearsPreview'] ?? '';
        final existingAmount = _extractAmountFromPreview(existingPreview);
        final newAmount = existingAmount + totalRestorationAmount;
        existingItem['arrearsPreview'] =
            _updateAmountInPreview(existingPreview, newAmount);

        // Update subPurposesWithTerms
        if (existingItem['subPurposesWithTerms'] == null) {
          existingItem['subPurposesWithTerms'] = [];
        }

        // Add restored amounts to sub-purposes (by term)
        for (var restoration in restorations) {
          final termId = restoration['termId'];
          final amount = restoration['amount'] as double;

          // Check if this term already exists in sub-purposes
          bool termExists = false;
          for (var subItem in existingItem['subPurposesWithTerms']) {
            if (subItem['termId'] == termId) {
              // Update existing term
              final currentSubAmount = subItem['amount'] as double;
              subItem['amount'] = currentSubAmount + 0;
              subItem['preview'] =
                  _updateAmountInPreview(subItem['preview'], subItem['amount']);
              termExists = true;
              break;
            }
          }

          if (!termExists) {
            // Add new sub-purpose for this term
            existingItem['subPurposesWithTerms'].add({
              'preview': '$termId [${_formatCurrency(amount)}] ',
              'amount': amount,
              'termId': termId,
            });
          }
        }

        // Rebuild the arrearsPreview from all sub-purposes
        existingItem['arrearsPreview'] = existingItem['subPurposesWithTerms']
            .map((sub) => sub['preview'])
            .join(', ');
      } else {
        // Purpose doesn't exist - create new item
        double totalAmount = 0;
        String? firstTermId;
        PaymentPurpose? firstPurpose;

        for (var restoration in restorations) {
          totalAmount += restoration['amount'] as double;
          if (firstTermId == null) {
            firstTermId = restoration['termId'];
            firstPurpose = restoration['purpose'];
          }
        }

        final newItem = {
          'purpose': firstPurpose,
          'termId': firstTermId,
          'arrearsPreview': '$firstTermId [${_formatCurrency(totalAmount)}] ',
          'subPurposesWithTerms': restorations
              .map((r) => {
                    'preview':
                        '$firstTermId [${_formatCurrency(r['amount'])}] ',
                    'amount': r['amount'],
                    'termId': r['termId'],
                  })
              .toList(),
        };
        originalArrears.add(newItem);
      }
    }

    return originalArrears;
  }

  double _extractAmountFromPreview(String preview) {
    final regex = RegExp(r'\[\$(\d+(?:\.\d+)?)\]|\$(\d+(?:\.\d+)?)');
    final match = regex.firstMatch(preview);
    if (match != null) {
      String amountStr = match.group(1) ?? match.group(2) ?? '';
      if (amountStr.isNotEmpty) {
        return double.parse(amountStr);
      }
    }
    return 0.0;
  }

  String _updateAmountInPreview(String preview, double newAmount) {
    final regex = RegExp(r'(\[\$)(\d+(?:\.\d+)?)(\])|(\$)(\d+(?:\.\d+)?)');
    return preview.replaceAllMapped(regex, (match) {
      if (match.group(1) != null) {
        return '${match.group(1)}${newAmount.toStringAsFixed(2)}${match.group(3)}';
      } else {
        return '${match.group(4)}${newAmount.toStringAsFixed(2)}';
      }
    });
  }

  Timer? _debounce;

  double calculateArrears(String saleCode) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    final sale = txBox.values.firstWhere(
      (t) => t.transactionCode == saleCode && t.createsObligation,
    );

    final subsequentPayments = txBox.values
        .where(
            (t) => t.parentTransactionCode == saleCode && t.settlesObligation)
        .fold<double>(0, (sum, t) => sum + t.amountPaid);

    final totalPaid = sale.amountPaid + subsequentPayments;

    return (sale.totalAmount - totalPaid).clamp(0, double.infinity);
  }

  List<ArrearsSummary> buildStudentArrearsDetails(String studentId) {
    // ✅ Check if client and no cached data
    if (_role == DeviceRole.client) {
      if (_cachedServerProjectSaleTransactions == null ||
          _cachedProductBatches == null) {
        return [];
      }
    }

    // ✅ Get transactions and batches based on role
    List<ProjectSaleTransaction> allTransactions = [];
    Map<String, ProductBatch> batchMap = {};
    List<ProjectSaleTransaction> _cart = []; // ✅ Preserve cart list

    if (_role == DeviceRole.host) {
      // ✅ HOST: Direct Hive access for both boxes
      final txBox =
          Hive.box<ProjectSaleTransaction>('project_sale_transactions');
      final batchBox = Hive.box<ProductBatch>('product_batches');

      allTransactions = txBox.values.toList();

      // Build batch map from Hive
      for (var batch in batchBox.values) {
        batchMap[batch.batchCode.toString()] = batch;
      }
    } else {
      // ✅ CLIENT: Use cached data for both
      allTransactions = _cachedServerProjectSaleTransactions!;

      // Build batch map from cached data
      for (var batch in _cachedProductBatches!) {
        batchMap[batch.batchCode.toString()] = batch;
      }
    }

    // ✅ Get sales (creates obligation) for this student
    final sales = allTransactions.where((t) =>
        t.studentId == studentId && t.createsObligation && t.isDeleted != true);

    return sales
        .map((sale) {
          // ✅ Calculate payments for this sale (same as original)
          final payments = allTransactions
              .where((t) =>
                  t.parentTransactionCode == sale.transactionCode &&
                  t.settlesObligation &&
                  t.isDeleted != true)
              .fold<double>(0, (sum, t) => sum + t.amountPaid);

          final totalPaid = sale.amountPaid + payments;
          final arrears =
              (sale.totalAmount - totalPaid).clamp(0, double.infinity);

          // ✅ 🔥 subtract cart payments for same parent sale (same as original)
          final cartPayments = _cart
              .where((t) => t.parentTransactionCode == sale.transactionCode)
              .fold<double>(0, (sum, t) => sum + t.amountPaid);

          final adjustedArrears =
              (arrears - cartPayments).clamp(0, double.infinity);

          // ✅ Get project (same as original)
          final project = _projects.firstWhere(
            (p) => p.projectCode == sale.projectCode,
            orElse: () => Project(
              name: 'Unknown Project',
              projectCode: '',
              status: 'inactive',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              projectType: 'unknown',
              participationType: 'none',
            ),
          );

          // ✅ Get item (same as original)
          final item = _items.firstWhere(
            (i) => i.projectItemCode == sale.projectItemCode,
            orElse: () => ProjectItem(
              name: 'Unknown Item',
              projectItemCode: '',
            ),
          );

          // ✅ Get batch from map (same as original, but using map instead of direct Hive)
          final batch = batchMap[sale.batchCode];
          final batchName = batch?.reference ?? 'Unknown Batch';

          // ✅ Return ArrearsSummary with all original calculations
          return ArrearsSummary(
            transactionCode: sale.transactionCode,
            projectName: project.name ?? 'Unknown Project',
            itemName: item.name ?? 'Unknown Item',
            batchName: batchName,
            totalAmount: sale.totalAmount,
            totalPaid: totalPaid + cartPayments, // ✅ Same as original
            arrears: adjustedArrears.toDouble(), // ✅ Same as original
          );
        })
        .where((s) => s.arrears > 0)
        .toList();
  }

  Future<double> _computeTotalStudentArrears(Student student) async {
    double total = 0.0;

    try {
      final arrearPurposes =
          await _fetchUniquePaymentPurposesByStudentWithArrears(student);

      for (final entry in arrearPurposes) {
        if (_role == DeviceRole.host) {
          final purpose = entry['purpose'] as PaymentPurpose;
          final arrearsData = await _computeArrearsForPurpose(purpose);

          for (final amt in arrearsData.values) {
            if (amt > 0) total += amt;
          }
        } else {
          final arrearsData = entry['arrears'] as Map<String, double>? ?? {};

          for (final amt in arrearsData.values) {
            if (amt > 0) total += amt;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to compute total arrears: $e');
    }

    return total;
  }

  Future<List<Map<String, dynamic>>>
      _fetchUniquePaymentPurposesByStudentWithArrears(Student student) async {
    final List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }
      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    final excludedTermIds = _getExcludedFutureTermIds();

    final Set<String> seenPurposeNames = {};
    final List<PaymentPurpose> filtered = [];

    for (final purpose in allPurposes) {
      // Skip purposes that belong to future terms

      if (excludedTermIds.contains(purpose.termId)) {
        continue;
      }
      final isForClass = purpose.associatedClasses
              ?.any((c) => c.toLowerCase() == student.class_?.toLowerCase()) ??
          false;

      final isException = purpose.exceptions?.any(
            (e) =>
                student.exceptions
                    ?.any((s) => s.exceptionId == e.exceptionId) ??
                false,
          ) ??
          false;

      bool isNewcomerRelated = purpose.forNewcomersOnly == true;
      bool newcomerConditionAllows = true;

      if (isNewcomerRelated) {
        if (student.isNewComer != true) {
          newcomerConditionAllows = false;
        } else if (student.isNewComerUntil != null) {
          final newcomerUntil = student.isNewComerUntil!;
          final term = _termsMap[purpose.termId];
          if (term != null && term.startDate.isAfter(newcomerUntil)) {
            newcomerConditionAllows = false;
          }
        }
      }

      final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
          newcomerConditionAllows;

      if (shouldInclude) {
        final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
        if (!seenPurposeNames.contains(nameKey)) {
          seenPurposeNames.add(nameKey);
          filtered.add(purpose);
        }
      }
    }

    // ------------------------------------------------------------
    // STEP 2: Compute arrears & build preview string
    // ------------------------------------------------------------
    final List<Map<String, dynamic>> resultList = [];

    for (final purpose in filtered) {
      try {
        final arrearsData = await _computeArrearsForPurpose(purpose);

        // Filter only terms with positive arrears
        final nonZeroArrears =
            arrearsData.entries.where((e) => e.value > 0).toList();

        if (nonZeroArrears.isNotEmpty) {
          // Sort alphabetically by term text
          final monthMap = {
            'january': 1,
            'february': 2,
            'march': 3,
            'april': 4,
            'may': 5,
            'june': 6,
            'july': 7,
            'august': 8,
            'september': 9,
            'october': 10,
            'november': 11,
            'december': 12,
          };

          nonZeroArrears.sort((a, b) {
            final termRegex = RegExp(r'(\d{4})\s+Term\s+(\d+)\s*\((\w+)\)',
                caseSensitive: false);

            final matchA = termRegex.firstMatch(a.key);
            final matchB = termRegex.firstMatch(b.key);

            if (matchA == null || matchB == null) return a.key.compareTo(b.key);

            final yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
            final yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;

            final termA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
            final termB = int.tryParse(matchB.group(2) ?? '0') ?? 0;

            final monthA = monthMap[(matchA.group(3) ?? '').toLowerCase()] ?? 0;
            final monthB = monthMap[(matchB.group(3) ?? '').toLowerCase()] ?? 0;

            // Compare year first, then term, then month
            if (yearA != yearB) return yearA.compareTo(yearB);
            if (termA != termB) return termA.compareTo(termB);
            return monthA.compareTo(monthB);
          });

// Build preview: show max 3 arrears
          final previewParts = nonZeroArrears.take(3).map((e) {
            final display = e.key; // Already like "2025 Term 1 (February)"
            return '$display (\$${e.value.toStringAsFixed(2)})';
          }).join(', ');

          final hasMore = nonZeroArrears.length > 3 ? ', ...' : '';
          final arrearsPreview = '($previewParts$hasMore)';

          resultList.add({
            'purpose': purpose,
            'arrears': {for (var e in nonZeroArrears) e.key: e.value},
            'arrearsPreview': arrearsPreview,
          });
        }
      } catch (e) {
        debugPrint(
            '⚠️ Failed arrears preview for ${purpose.paymentPurpose}: $e');
      }
    }

    return resultList;
  }

  Future<List<Map<String, dynamic>>>
      _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
          Student student) async {
    final List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }
      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    final Set<String> seenPurposeNames = {};
    final List<PaymentPurpose> filtered = [];

    for (final purpose in allPurposes) {
      // Skip purposes that don't belong to selected terms
      if (_selectedFilterTerms.isNotEmpty &&
          purpose.termId != null &&
          !_selectedFilterTerms.contains(purpose.termId)) {
        continue;
      }

      final isForClass =
          purpose.associatedClasses?.contains(student.class_) ?? false;

      final isException = purpose.exceptions?.any(
            (e) =>
                student.exceptions
                    ?.any((s) => s.exceptionId == e.exceptionId) ??
                false,
          ) ??
          false;

      bool isNewcomerRelated = purpose.forNewcomersOnly == true;
      bool newcomerConditionAllows = true;

      if (isNewcomerRelated) {
        if (student.isNewComer != true) {
          newcomerConditionAllows = false;
        } else if (student.isNewComerUntil != null) {
          final newcomerUntil = student.isNewComerUntil!;
          final term = _termsMap[purpose.termId];
          if (term != null && term.startDate.isAfter(newcomerUntil)) {
            newcomerConditionAllows = false;
          }
        }
      }

      final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
          newcomerConditionAllows;

      if (shouldInclude) {
        final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
        if (!seenPurposeNames.contains(nameKey)) {
          seenPurposeNames.add(nameKey);
          filtered.add(purpose);
        }
      }
    }

    // ------------------------------------------------------------
    // STEP 2: Compute arrears & build preview string
    // ------------------------------------------------------------
    final List<Map<String, dynamic>> resultList = [];

    for (final purpose in filtered) {
      try {
        final arrearsData = await _computeArrearsForPurpose(purpose);
        final List<Map<String, dynamic>> subPurposesWithTerms = [];

        // Filter only terms with positive arrears
        final nonZeroArrears =
            arrearsData.entries.where((e) => e.value > 0).toList();

        if (nonZeroArrears.isNotEmpty) {
          // Sort alphabetically by term text
          final monthMap = {
            'january': 1,
            'february': 2,
            'march': 3,
            'april': 4,
            'may': 5,
            'june': 6,
            'july': 7,
            'august': 8,
            'september': 9,
            'october': 10,
            'november': 11,
            'december': 12,
          };

          nonZeroArrears.sort((a, b) {
            final termRegex = RegExp(r'(\d{4})\s+Term\s+(\d+)\s*\((\w+)\)',
                caseSensitive: false);

            final matchA = termRegex.firstMatch(a.key);
            final matchB = termRegex.firstMatch(b.key);

            if (matchA == null || matchB == null) return a.key.compareTo(b.key);

            final yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
            final yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;

            final termA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
            final termB = int.tryParse(matchB.group(2) ?? '0') ?? 0;

            final monthA = monthMap[(matchA.group(3) ?? '').toLowerCase()] ?? 0;
            final monthB = monthMap[(matchB.group(3) ?? '').toLowerCase()] ?? 0;

            // Compare year first, then term, then month
            if (yearA != yearB) return yearA.compareTo(yearB);
            if (termA != termB) return termA.compareTo(termB);
            return monthA.compareTo(monthB);
          });
          final previewParts = nonZeroArrears.map((e) {
            final display = e.key;
            return '$display (\$${e.value.toStringAsFixed(2)})';
          }).join(', ');

          final arrearsPreview = '($previewParts)';
          resultList.add({
            'purpose': purpose,
            'arrears': {for (var e in nonZeroArrears) e.key: e.value},
            'arrearsPreview': arrearsPreview,
          });
        }
      } catch (e) {
        debugPrint(
            '⚠️ Failed arrears preview for ${purpose.paymentPurpose}: $e');
      }
    }

    return resultList;
  }

  Future<List<Map<String, dynamic>>>
      _fetchUniquePaymentPurposesByStudentWithArrearsForPreviwNew(
          Student student) async {
    final List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }
      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    final Set<String> seenPurposeNames = {};
    final List<PaymentPurpose> filtered = [];

    for (final purpose in allPurposes) {
      final isForClass =
          purpose.associatedClasses?.contains(student.class_) ?? false;

      final isException = purpose.exceptions?.any(
            (e) =>
                student.exceptions
                    ?.any((s) => s.exceptionId == e.exceptionId) ??
                false,
          ) ??
          false;

      bool isNewcomerRelated = purpose.forNewcomersOnly == true;
      bool newcomerConditionAllows = true;

      if (isNewcomerRelated) {
        if (student.isNewComer != true) {
          newcomerConditionAllows = false;
        } else if (student.isNewComerUntil != null) {
          final newcomerUntil = student.isNewComerUntil!;
          final term = _termsMap[purpose.termId];
          if (term != null && term.startDate.isAfter(newcomerUntil)) {
            newcomerConditionAllows = false;
          }
        }
      }

      final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
          newcomerConditionAllows;

      if (shouldInclude) {
        final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
        if (!seenPurposeNames.contains(nameKey)) {
          seenPurposeNames.add(nameKey);
          filtered.add(purpose);
        }
      }
    }

    // ------------------------------------------------------------
    // STEP 2: Compute arrears & build preview string
    // ------------------------------------------------------------
    final List<Map<String, dynamic>> result = [];

    for (final purpose in filtered) {
      // ← Use 'filtered' instead of 'allPurposes'
      Map<String, double> arrearsDetails =
          await _computeArrearsForPurpose(purpose);
      // Build list of sub-purposes with term IDs

      // ✅ Apply any updated remaining amounts from the cache
      final purposeKey = purpose.paymentPurpose ?? purpose.id.toString();
      final cachedUpdates = _updatedArrearsCache[purposeKey];

      if (cachedUpdates != null) {
        for (var entry in cachedUpdates.entries) {
          final termId = entry.key;
          final remainingAmount = entry.value;

          if (remainingAmount <= 0) {
            arrearsDetails.remove(termId);
          } else {
            arrearsDetails[termId] = remainingAmount;
          }
        }
      }
      final List<Map<String, dynamic>> subPurposesWithTerms = [];

      for (final entry in arrearsDetails.entries) {
        if (entry.value > 0) {
          // ← Only add if amount > 0
          subPurposesWithTerms.add({
            'termId': entry.key,
            'amount': entry.value,
            'preview': '${entry.key} (\$${entry.value.toStringAsFixed(2)})',
          });
        }
      }

      // ← ONLY add to result if there are sub-purposes
      if (subPurposesWithTerms.isNotEmpty) {
        result.add({
          'purpose': purpose,
          'subPurposesWithTerms': subPurposesWithTerms,
          'arrearsPreview':
              subPurposesWithTerms.map((e) => e['preview']).join(', '),
        });
      }
    }

    return result;
  }

  double getAdjustedArrear(
      double arrear, Student student, PaymentPurpose purpose, String termId) {
    final studentExceptions = student.exceptions ?? [];
    final applicablePurposeExceptions = purpose.exceptions ?? [];

    double totalDeduction = 0.0;

    for (var studentException in studentExceptions) {
      if (studentException.exceptionStatus?.toLowerCase() != 'active') continue;

      if (!(studentException.terms?.any(
              (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
          false)) continue;

      final isLinkedToPurpose = applicablePurposeExceptions
          .any((pEx) => pEx.exceptionId == studentException.exceptionId);
      if (!isLinkedToPurpose) continue;

      final double? figure =
          double.tryParse(studentException.exceptionFigure ?? '');
      if (figure == null) continue;

      if (studentException.exceptionType?.toLowerCase() == 'amount') {
        totalDeduction += figure;
      } else if (studentException.exceptionType?.toLowerCase() ==
          'percentage') {
        final percent = (figure / 100) * purpose.purposeAmount;
        totalDeduction += percent;
      }
    }

    final beforeClamp = arrear - totalDeduction;

    // safer than clamp()
    final adjusted = max(0.0, beforeClamp);
    return adjusted;
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByClass(
      String termId, String class_) async {
    if (termId.isEmpty || class_.isEmpty) {
      return [];
    }

    List<PaymentPurpose> allPurposes;

    if (_role == DeviceRole.host) {
      final paymentPurposeBox =
          await Hive.openBox<PaymentPurpose>('payment_purposes');
      allPurposes = paymentPurposeBox.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;

          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        } else {
          throw Exception('Failed to fetch payment purposes from server.');
        }
      }

      allPurposes = _cachedServerStudentPaymentPurposes!;
    }

    // Filter for the given term and class
    final allPaymentPurposes = allPurposes.where((purpose) {
      return purpose.termId == termId &&
          (purpose.associatedClasses?.contains(class_) ?? false);
    }).toList();

    return allPaymentPurposes;
  }

  bool _isCheckingArrears = false; // Prevent duplicate execution
  Map<String, double> _arrearsDetails = {}; // Store term and arrears amount
  double _sumPaymentsFromHive({
    required List<StudentPayment> studentPayments,
    required String termId,
    required String purposeName,
  }) {
    if (_selectedStudent == null) return 0.0;

    return studentPayments
        .where((payment) =>
            payment.termId == termId &&
            payment.paymentPurpose.toLowerCase() == purposeName.toLowerCase() &&
            payment.studentName.toLowerCase() ==
                _selectedStudent!.name.toLowerCase() &&
            payment.studentSurname.toLowerCase() ==
                _selectedStudent!.surname.toLowerCase())
        .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));
  }

  double _sumPaymentsFromSession({
    required String termId,
    required String purposeName,
  }) {
    return _paymentPurposes
        .where((p) =>
            p['termId'] == termId &&
            p['purpose'].paymentPurpose.toLowerCase() ==
                purposeName.toLowerCase())
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  Future<void> _checkArrears(PaymentPurpose selectedPurpose) async {
    if (_isCheckingArrears) return;
    setState(() {
      _isCheckingArrears = true;
      setState(() {
        _arrearsDetails.clear();
        _arrearsTerms.clear();
      });
    });

    if (_role != DeviceRole.host) {
      // Ensure caches are warmed before reading them below - see comment in
      // _computeArrearsForPurpose.
      await fetchTerms();
      await fetchStudentPayments();
    }

    final List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    _arrearsDetails.clear();
    List<String> overdueTerms = [];

    for (final term in allTerms) {
      if (!_selectedStudent!.terms!.contains(term.termId)) continue;

      // Fetch purposes specifically for this term
      final termPurposes = await _fetchPaymentPurposesByTerm(term.termId);

// Find matching purpose for this term by name
      final matchingPurpose = termPurposes.firstWhere(
        (p) =>
            p.paymentPurpose.toLowerCase() ==
            selectedPurpose.paymentPurpose.toLowerCase(),
        orElse: () => PaymentPurpose(
          paymentPurpose: 'N/A',
          associatedClasses: [],
          id: 0,
          purposeAmount: 0.0,
        ),
      );

      if (matchingPurpose.paymentPurpose == 'N/A') continue;

      // Validate class association
      final isClassMatch = matchingPurpose.associatedClasses
              ?.contains(_selectedStudent!.class_) ??
          false;
      if (!isClassMatch) continue;

      // Apply newcomer condition check
      final isNewcomer = selectedPurpose.forNewcomersOnly == true;
      final termStartDate = term.startDate;
      final termEndDate = term.endDate;

      bool isNewcomerValid = true;

      if (isNewcomer) {
        if (termEndDate != null) {
          if (_selectedStudent?.isNewComer != true ||
              _selectedStudent?.isNewComerUntil == null ||
              termStartDate.isAfter(_selectedStudent!.isNewComerUntil!) ||
              termEndDate.isBefore(_selectedStudent!.isNewComerFrom!)) {
            isNewcomerValid = false;
          }
        } else if (_selectedStudent?.isNewComer != true ||
            _selectedStudent?.isNewComerUntil == null ||
            termStartDate.isAfter(_selectedStudent!.isNewComerUntil!)) {
          isNewcomerValid = false;
        }
      }

      if (!isNewcomerValid) continue;

      final allStudentPayments = _role == DeviceRole.host
          ? Hive.box<StudentPayment>('student_payments').values.toList()
          : _cachedServerStudentPayments ?? [];
      // Calculate paid amounts
      final double hivePaid = _sumPaymentsFromHive(
        studentPayments: allStudentPayments,
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final double sessionPaid = _sumPaymentsFromSession(
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final totalPaid = hivePaid + sessionPaid;
      double arrears = matchingPurpose.purposeAmount - totalPaid;

      arrears = getAdjustedArrear(
        arrears,
        _selectedStudent!,
        matchingPurpose,
        term.termId,
      );

      if (arrears > 0) {
        overdueTerms.add(term.termId);
        _arrearsDetails[term.termId] = arrears;
      }
    }

    setState(() {
      _arrearsTerms = overdueTerms;
      _isCheckingArrears = false;
    });
  }

  Future<Map<String, double>> _computeArrearsForPurpose(
      PaymentPurpose selectedPurpose) async {
    if (_role != DeviceRole.host) {
      // _cachedServerTerms/_cachedServerStudentPayments are normally warmed
      // by fire-and-forget calls in initState, which may not have completed
      // yet the first time this runs (host reads Hive directly, so it never
      // hits this gap). Ensure they're populated before reading them below.
      await fetchTerms();
      await fetchStudentPayments();
    }
    final List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    // Get excluded future term IDs
    final excludedTermIds = _getExcludedFutureTermIds();

    final Map<String, double> arrearsDetails = {};

    for (final term in allTerms) {
      // Skip future terms
      if (excludedTermIds.contains(term.termId)) {
        continue;
      }
      // Skip terms that are not in the selected filter terms (if any are selected)
      if (_selectedFilterTerms.isNotEmpty &&
          !_selectedFilterTerms.contains(term.termId)) {
        continue;
      }
      if (!_selectedStudent!.terms!.contains(term.termId)) continue;

      final termPurposes = await _fetchPaymentPurposesByTerm(term.termId);

      final matchingPurpose = termPurposes.firstWhere(
        (p) =>
            p.paymentPurpose.toLowerCase() ==
            selectedPurpose.paymentPurpose.toLowerCase(),
        orElse: () => PaymentPurpose(
          paymentPurpose: 'N/A',
          associatedClasses: [],
          id: 0,
          purposeAmount: 0.0,
        ),
      );

      if (matchingPurpose.paymentPurpose == 'N/A') continue;

      final isClassMatch = matchingPurpose.associatedClasses
              ?.contains(_selectedStudent!.class_) ??
          false;
      if (!isClassMatch) continue;

      // Apply newcomer condition check
      final isNewcomer = selectedPurpose.forNewcomersOnly == true;
      final termStartDate = term.startDate;
      final termEndDate = term.endDate;

      bool isNewcomerValid = true;
      if (isNewcomer) {
        if (termEndDate != null) {
          if (_selectedStudent?.isNewComer != true ||
              _selectedStudent?.isNewComerUntil == null ||
              termStartDate.isAfter(_selectedStudent!.isNewComerUntil!) ||
              termEndDate.isBefore(_selectedStudent!.isNewComerFrom!)) {
            isNewcomerValid = false;
          }
        } else if (_selectedStudent?.isNewComer != true ||
            _selectedStudent?.isNewComerUntil == null ||
            termStartDate.isAfter(_selectedStudent!.isNewComerUntil!)) {
          isNewcomerValid = false;
        }
      }

      if (!isNewcomerValid) continue;

      final allStudentPayments = _role == DeviceRole.host
          ? Hive.box<StudentPayment>('student_payments').values.toList()
          : _cachedServerStudentPayments ?? [];

      final double hivePaid = _sumPaymentsFromHive(
        studentPayments: allStudentPayments,
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final double sessionPaid = _sumPaymentsFromSession(
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final totalPaid = hivePaid + sessionPaid;
      double arrears = matchingPurpose.purposeAmount - totalPaid;

      arrears = getAdjustedArrear(
        arrears,
        _selectedStudent!,
        matchingPurpose,
        term.termId,
      );

      if (arrears > 0) {
        arrearsDetails[term.termId] = arrears;
      }
    }

    return arrearsDetails;
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTerm(
      String termId) async {
    List<PaymentPurpose> allPurposes = [];

    if (_role == DeviceRole.host) {
      final box = Hive.box<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final response = await HttpClient()
            .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
            .then((req) => req.close());

        if (response.statusCode == 200) {
          final jsonStr = await response.transform(utf8.decoder).join();
          final list = jsonDecode(jsonStr) as List;
          _cachedServerStudentPaymentPurposes = list
              .map((json) =>
                  paymentPurposesFromJson(Map<String, dynamic>.from(json)))
              .toList();
        }
      }
      allPurposes = _cachedServerStudentPaymentPurposes ?? [];
    }

    // ✅ ONLY exclude future terms for teachers
    if (_isTeacher()) {
      final excludedTermIds = _getExcludedFutureTermIds();
      return allPurposes
          .where((purpose) =>
              purpose.termId == termId && !excludedTermIds.contains(termId))
          .toList();
    } else {
      // ✅ Non-teachers see ALL purposes for the term
      return allPurposes.where((purpose) => purpose.termId == termId).toList();
    }
  }

  // Method to handle search
  void _performSearch(String query) {
    if (query.isEmpty) return;
    _onSearchSubmitted(query);
  }

  // Handle keyboard events for Windows
  void _handleKeyEvent(RawKeyEvent event) {
    if (Theme.of(context).platform == TargetPlatform.windows &&
        event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      // Check if the search field is focused
      if (_searchFocusNode.hasFocus) {
        _performSearch(_studentSearchController.text.trim());
      }
    }
  }

// Add this helper method to mask phone numbers
  String _maskPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'N/A';
    }

    // Remove any non-digit characters (spaces, dashes, etc.)
    String cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Check if it has at least 10 digits
    if (cleaned.length >= 10) {
      // Keep last 4 digits, mask the rest with stars
      String last4 = cleaned.substring(cleaned.length - 4);
      String masked = '*' * (cleaned.length - 4) + last4;

      // Re-insert any original formatting? Just return masked digits
      return masked;
    } else {
      // Invalid or too short, return as is
      return phoneNumber;
    }
  }

// Build statement lines using the package's LineText class
  List<LineText> _buildStatementLines({
    required School schoolInfo,
    required Student selectedStudent,
    required double feesArrears,
    required double totalProjectArrears,
    required double grandTotal,
    required List<Map<String, dynamic>> purposeList,
    required List<ArrearsSummary> projectArrearsDetails,
    required String generatedBy,
  }) {
    List<LineText> lines = [];

    // Helper function to add text line using package's LineText
    void addLine(
      String content, {
      int align = LineText.ALIGN_LEFT,
      int linefeed = 1,
      int fontZoom = 0,
      int weight = 0,
      bool underline = false,
    }) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: content,
        align: align,
        linefeed: linefeed,
        fontZoom: fontZoom,
        weight: weight,
        underline: underline ? 1 : 0,
      ));
    }

    // Helper function to add divider
    void addDivider({String char = '-', int length = 42}) {
      addLine(char * length, align: LineText.ALIGN_CENTER);
    }

    // Header Section
    addLine('ARREARS STATEMENT',
        align: LineText.ALIGN_CENTER,
        linefeed: 2,
        fontZoom: 2,
        weight: 1,
        underline: true);

    addLine('', linefeed: 1);
    addLine('', linefeed: 1);
    addLine(' ${schoolInfo.schoolName?.toUpperCase() ?? ""}',
        align: LineText.ALIGN_CENTER, weight: 2);
    addLine(' ${schoolInfo.schoolAddress?.toUpperCase() ?? ""}',
        align: LineText.ALIGN_CENTER);
    addLine(' ${schoolInfo.schoolPhoneNumber ?? ""}',
        align: LineText.ALIGN_CENTER);
    addLine(' ${schoolInfo.schoolEmail ?? ""}',
        align: LineText.ALIGN_CENTER, underline: true);
    addDivider();

    // Student Information Section
    addLine('STUDENT INFORMATION', align: LineText.ALIGN_CENTER, weight: 2);

    addDivider();
    addLine('Name: ${selectedStudent.name} ${selectedStudent.surname}');
    addLine('Class: ${selectedStudent.class_ ?? 'N/A'}');
    addLine('Student ID: ${selectedStudent.studentIdNumber}');
    String maskedPhone = _maskPhoneNumber(selectedStudent.phoneNumber);
    addLine('Phone Number: $maskedPhone');

    // Masked emergency contact if valid
    if (selectedStudent.emergencyContactNumber != null &&
        selectedStudent.emergencyContactNumber!.isNotEmpty) {
      String maskedEmergency =
          _maskPhoneNumber(selectedStudent.emergencyContactNumber);
      addLine('Emergency:  $maskedEmergency');
    }

    addLine('Statement To: ${selectedStudent.paymentStatus ?? 'N/A'}');
    addDivider();

    // Payment Purposes Section (with individual amounts on separate lines)
    if (purposeList.isNotEmpty) {
      addLine('PAYMENT PURPOSE ARREARS',
          align: LineText.ALIGN_CENTER, weight: 1, underline: true);
      addDivider();

      double totalFeesArrears = 0.0;

      // Display each purpose on its own line with its amount
      for (var entry in purposeList) {
        final purpose = entry['purpose'];
        final arrearsMap = entry['arrears'] as Map<String, double>? ?? {};

        // Calculate total arrears for this purpose
        double purposeTotal =
            arrearsMap.values.fold(0.0, (sum, amount) => sum + amount);
        totalFeesArrears += purposeTotal;
        final preview = entry['arrearsPreview'];
        // Add purpose name
        addLine('${purpose.paymentPurpose.toString().toUpperCase() ?? 'N/A'}',
            weight: 1, align: LineText.ALIGN_CENTER, linefeed: 1);
        addLine('', linefeed: 1);

        // Split preview by commas and create new lines for each part
        if (preview != null && preview.isNotEmpty) {
          // Remove surrounding parentheses if present
          String cleanPreview = preview;
          if (cleanPreview.startsWith('(') && cleanPreview.endsWith(')')) {
            cleanPreview = cleanPreview.substring(1, cleanPreview.length - 1);
          }

          // Split by comma and trim each part
          List<String> previewParts =
              cleanPreview.split(',').map((part) => part.trim()).toList();

          // Add each part as a new line
          for (String part in previewParts) {
            if (part.isNotEmpty) {
              addLine('  $part',
                  align: LineText.ALIGN_LEFT, linefeed: 1, weight: 1);
              addLine('', linefeed: 1);
            }
          }
        }
      }
      addLine('', linefeed: 1);
      // Display purpose with its individual amount

      addLine('', linefeed: 0);
      addLine('', linefeed: 1);
      addLine('TOTAL FEES ARREARS: \$${totalFeesArrears.toStringAsFixed(2)}',
          align: LineText.ALIGN_RIGHT, weight: 1);
      addLine('', linefeed: 1);
    }
    addDivider();
    // Project Arrears Details Section
    if (projectArrearsDetails.isNotEmpty) {
      addLine('PROJECT ARREARS DETAILS',
          align: LineText.ALIGN_CENTER, weight: 1, underline: true);
      addDivider();

      // Header
      addLine('Project'.padRight(25) + 'Amount'.padLeft(15), weight: 1);
      addLine('', linefeed: 1);

      for (var detail in projectArrearsDetails) {
        String projectLine = '${detail.projectName} - ${detail.itemName}';
        if (projectLine.length > 25) {
          projectLine = projectLine.substring(0, 22) + '...';
        }
        String amountLine = _formatCurrency(detail.arrears);
        addLine(projectLine.padRight(25) + amountLine.padLeft(15));
        addLine('', linefeed: 1);
      }

      addLine('', linefeed: 1);
      addLine('TOTAL PROJECT ARREARS: ${_formatCurrency(totalProjectArrears)}',
          align: LineText.ALIGN_RIGHT, weight: 1);
      addLine('', linefeed: 1);
    }

    addLine('', linefeed: 1);
    addDivider();

    // Arrears Overview Section
    addLine('TOTAL ARREARS OVERVIEW',
        align: LineText.ALIGN_CENTER, weight: 1, underline: true);
    addDivider();
    addLine('Fees Arrears: ${_formatCurrency(feesArrears)}',
        align: LineText.ALIGN_RIGHT);
    if (totalProjectArrears > 0) {
      addLine('Project Arrears: ${_formatCurrency(totalProjectArrears)}',
          align: LineText.ALIGN_RIGHT);
    }
    addLine('', linefeed: 1);

    addLine('GRAND TOTAL ARREARS: ${_formatCurrency(grandTotal)}',
        align: LineText.ALIGN_RIGHT, weight: 1);
    addLine('', linefeed: 1);

    // Footer Section
    addDivider(char: '=', length: 42);
    addLine('', linefeed: 1);
    addLine('GENERATED ON', align: LineText.ALIGN_CENTER, weight: 1);
    addLine(_formatDateTime(DateTime.now()), align: LineText.ALIGN_CENTER);
    addLine('', linefeed: 1);
    addLine('GENERATED BY', align: LineText.ALIGN_CENTER, weight: 1);
    addLine(generatedBy.toUpperCase(), align: LineText.ALIGN_CENTER);
    addLine('', linefeed: 1);
    addDivider(char: '*', length: 42);
    addLine('This is a computer-generated statement',
        align: LineText.ALIGN_CENTER);
    addLine('No signature required', align: LineText.ALIGN_CENTER);
    addDivider(char: '*', length: 42);
    addLine('', linefeed: 2);
    addLine('', linefeed: 2);
    addLine('', linefeed: 2);

    return lines;
  }

  /// 🆕 Show Windows printer connection dialog
  Future<void> _showWindowsPrinterConnectionDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Windows Printer Not Connected'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_disabled, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Please select and connect to a Windows printer first'),
            SizedBox(height: 8),
            Text('Use the printer selector and Connect button above'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a printer and click Connect'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 🆕 Print to Windows printer
  Future<void> _printToWindowsPrinter(List<LineText> statementLines) async {
    if (_selectedWindowsPrinter == null) {
      throw Exception('No Windows printer selected');
    }

    if (!_connected) {
      throw Exception('Windows printer not connected. Please connect first.');
    }

    // Generate plain text from LineText objects
    StringBuffer textBuffer = StringBuffer();

    for (var line in statementLines) {
      if (line.type == LineText.TYPE_TEXT) {
        final content = line.content ?? '';
        textBuffer.writeln(content);

        // Add extra line feeds
        for (int i = 0; i < (line.linefeed ?? 1) - 1; i++) {
          textBuffer.writeln('');
        }
      }
    }

    final plainText = textBuffer.toString();
    final bytes = utf8.encode(plainText);

    // Send to Windows printer
    await WindowsPrinterHelper.printToWindowsPrinter(
      _selectedWindowsPrinter!,
      bytes,
    );
  }

// Format currency
  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

// Format date time
  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

// Show Bluetooth connection dialog
  // Show Bluetooth connection dialog
  Future<void> _showBluetoothConnectionDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth Printer Not Connected'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Please connect to a Bluetooth printer first'),
            SizedBox(height: 8),
            Text('Use the Connect button below to pair your printer'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // The user can manually connect using the existing Connect button in the UI
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Please select a printer and click Connect above'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetPaymentData() {
    setState(() {
      _paymentPurposes.clear();
      _selectedSubPurposes.clear();
      _selectedPaymentPurpose = null;
      _selectedArrearsTerm = null;
      _paymentAmount = null;
      _paymentAmountController.clear();
      _pmAmountCtrl.clear();
      _cachedTotalEntered = 0.0;
      _updatedArrearsCache.clear();
      _purposeListVersion++; // Force refresh
    });
  }

  void _clearSelections() {
    setState(() {
      _selectedSubPurposes.clear();
      _selectedPaymentPurpose = null;
      _selectedArrearsTerm = null;
      _paymentAmount = null;
      _paymentAmountController.clear();
    });
  }

  void _clearAllServerCaches() {
    _cachedServerStudentPayments = null;
    _cachedServerTerms = null;
    _cachedServerStudentPaymentPurposes = null;
    _cachedServerStudents = null;
    _cachedServerSchoolInfo = null;
    _cachedFilteredStudents = null;
    _cachedServerProjects = null;
    _cachedServerProjectItems = null;
    _cachedProductBatches = null;
    _cachedBatchSellUnits = null;

    @override
    void dispose() {
      _pmAmountDebounceTimer?.cancel();
      _pmAmountFocusNode.dispose();
      _focusManager.dispose();

      for (var controller in _amountControllers.values) {
        controller.dispose();
      }
      _amountControllers.clear();
      bluetoothHelper.dispose(); // Properly dispose of BluetoothHelper

      _paymentAmountController.dispose();
      _studentSearchController.dispose();
      _searchFocusNode.dispose();
      _searchDebounce?.cancel();

      super.dispose();
    }
  }
}

// ==================== ARREARS SECTION WIDGET ====================
class ArrearsSection extends StatefulWidget {
  final Student student;
  final int version;
  final Function(List<Map<String, dynamic>>) onItemsSelected;
  final Map<String, List<bool>> Function() getSelectedSubPurposes;
  final void Function(Map<String, List<bool>>) setSelectedSubPurposes;
  final Future<List<Map<String, dynamic>>> Function(Student)
      fetchArrears; // Add this
  final List<Map<String, dynamic>> restoredItems; // Add this
  final VoidCallback? onRefreshRequested; // Add this callback
  final VoidCallback? onScrollToConfirmButton; // Add this (replace or add new)

  const ArrearsSection({
    Key? key,
    required this.student,
    required this.version,
    required this.onItemsSelected,
    required this.getSelectedSubPurposes,
    required this.setSelectedSubPurposes,
    required this.fetchArrears, // Add this
    this.restoredItems = const [], // Add this
    this.onRefreshRequested, // Add this
    this.onScrollToConfirmButton,
  }) : super(key: key);

  @override
  State<ArrearsSection> createState() => _ArrearsSectionState();
}

class _ArrearsSectionState extends State<ArrearsSection> {
  List<Map<String, dynamic>> _purposeList = [];
  bool _isLoading = true;
  String? _error;
  Map<String, List<bool>> _selectedSubPurposes = {};
  void refresh() {
    _loadData();
  }

// Add this method to ArrearsSectionState
  List<Map<String, dynamic>> getCurrentArrearsData() {
    return _purposeList;
  }

  Future<List<Map<String, dynamic>>> refreshAndGetData() async {
    await _loadData();
    return _purposeList;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ArrearsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Also check if restoredItems changed
    if (oldWidget.student != widget.student ||
        oldWidget.version != widget.version ||
        oldWidget.restoredItems.length != widget.restoredItems.length) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      // CRITICAL: Clear selections first to avoid stale data
      _selectedSubPurposes.clear();
    });

    try {
      final data = await widget.fetchArrears(widget.student);

      setState(() {
        _purposeList = data;
        _isLoading = false;
      });

      // Initialize selections AFTER purposeList is updated
      _initializeSelections();

      // Notify parent after successful load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRefreshRequested?.call();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initializeSelections() {
    // Clear existing selections
    _selectedSubPurposes.clear();

    if (_purposeList.isEmpty) {
      return;
    }

    for (int i = 0; i < _purposeList.length; i++) {
      final purposeData = _purposeList[i];
      final preview = purposeData['arrearsPreview'] ?? '';

      if (preview.isEmpty) {
        continue;
      }

      final subPurposes = preview.split(',').map((s) => s.trim()).toList();
      final purposeKey = purposeData['purpose'].paymentPurpose ?? 'purpose_$i';

      // Create a fresh list with the correct length
      _selectedSubPurposes[purposeKey] =
          List<bool>.filled(subPurposes.length, false);
    }

    // Update parent with current selections
    widget.setSelectedSubPurposes(_selectedSubPurposes);
  }

  void _selectAllPurposes(bool select) {
    setState(() {
      for (int i = 0; i < _purposeList.length; i++) {
        final purposeData = _purposeList[i];
        final preview = purposeData['arrearsPreview'] ?? '';
        if (preview.isEmpty) continue;

        final subPurposes = preview.split(',').map((s) => s.trim()).toList();
        final purposeKey =
            purposeData['purpose'].paymentPurpose ?? 'purpose_$i';

        // Always create a new list with the correct length
        _selectedSubPurposes[purposeKey] =
            List<bool>.filled(subPurposes.length, select);
      }
      widget.setSelectedSubPurposes(_selectedSubPurposes);
    });
  }

  List<Map<String, dynamic>> getSelectedItems() {
    List<Map<String, dynamic>> selectedItems = [];

    for (int i = 0; i < _purposeList.length; i++) {
      final purposeData = _purposeList[i];
      final purpose = purposeData['purpose'];
      final subPurposesWithTerms =
          purposeData['subPurposesWithTerms'] as List<Map<String, dynamic>>? ??
              [];
      final purposeKey = purpose.paymentPurpose ?? 'purpose_$i';

      final selections = _selectedSubPurposes[purposeKey] ?? [];

      // Ensure selections length matches
      if (selections.length != subPurposesWithTerms.length &&
          subPurposesWithTerms.isNotEmpty) {
        // Reinitialize if mismatch
        _selectedSubPurposes[purposeKey] =
            List<bool>.filled(subPurposesWithTerms.length, false);
        widget.setSelectedSubPurposes(_selectedSubPurposes);
        continue;
      }

      for (int j = 0;
          j < selections.length && j < subPurposesWithTerms.length;
          j++) {
        if (selections[j]) {
          final subData = subPurposesWithTerms[j];
          selectedItems.add({
            'purpose': purpose,
            'subPurpose': subData['preview'],
            'amount': subData['amount'],
            'termId': subData['termId'],
          });
        }
      }
    }
    return selectedItems;
  }

  double _calculateOverallTotal(List<Map<String, dynamic>> purposeList) {
    double overallTotal = 0.0;

    try {
      for (var entry in purposeList) {
        final String preview = entry['arrearsPreview'];
        if (preview.isEmpty) continue;

        final List<String> subPurposes = preview
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        for (var subPurpose in subPurposes) {
          try {
            // Look for pattern like [$50] or [$75.50] or $50
            final RegExp regex =
                RegExp(r'\[\$(\d+(?:\.\d+)?)\]|\$(\d+(?:\.\d+)?)');
            final match = regex.firstMatch(subPurpose);
            if (match != null) {
              String amountStr = match.group(1) ?? match.group(2) ?? '';
              if (amountStr.isNotEmpty) {
                overallTotal += double.parse(amountStr);
              }
            } else {
              // Fallback: try to find any number
              final fallbackRegex = RegExp(r'(\d+(?:\.\d+)?)');
              final fallbackMatch = fallbackRegex.firstMatch(subPurpose);
              if (fallbackMatch != null) {
                overallTotal += double.parse(fallbackMatch.group(1)!);
              }
            }
          } catch (e) {
            print('Error parsing sub-purpose: "$subPurpose" - $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('Error calculating overall total: $e');
    }

    return overallTotal;
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  void _proceedWithSelected() {
    final selectedItems = getSelectedItems();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    widget.onItemsSelected(selectedItems);
    _selectAllPurposes(false);
    widget.onRefreshRequested?.call();

    // Scroll to Confirm Payment button instead
    widget.onScrollToConfirmButton?.call(); // Change this
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Text('Error: $_error');
    }

    if (_purposeList.isEmpty) {
      return const Text('No Arrears found for this student.');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📊 Fees Arrears Overview",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

// Responsive Overall Total and Buttons Section
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.indigo.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Check if screen is small (width < 500)
                  final isSmallScreen = constraints.maxWidth < 500;

                  if (isSmallScreen) {
                    // Column layout for small screens
                    return Column(
                      children: [
                        // Total Amount Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Overall Total Arrears",
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(
                                    _calculateOverallTotal(_purposeList)),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Row layout for larger screens
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Overall Total Arrears",
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(
                                    _calculateOverallTotal(_purposeList)),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _selectAllPurposes(true),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.green),
                                foregroundColor: Colors.green,
                              ),
                              child: const Text("Select All"),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _selectAllPurposes(false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                              ),
                              child: const Text("Deselect All"),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _proceedWithSelected,
                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text(
                            "PROCEED",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Purpose List Section
            ..._purposeList.asMap().entries.expand((purposeEntry) {
              final int purposeIndex = purposeEntry.key;
              final purposeData = purposeEntry.value;
              final purpose = purposeData['purpose'];
              final List<Map<String, dynamic>> subPurposesWithTerms =
                  purposeData['subPurposesWithTerms'] ?? [];
              final String purposeKey =
                  purpose.paymentPurpose ?? 'purpose_$purposeIndex';

              if (subPurposesWithTerms.isEmpty) return <Widget>[];

              final Color purposeColor = [
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.purple,
                Colors.teal,
                Colors.indigo,
                Colors.pink,
                Colors.amber
              ][purposeIndex % 8];
              final Color lightColor = purposeColor.withOpacity(0.08);
              final Color borderColor = purposeColor.withOpacity(0.4);
              final double totalAmount = subPurposesWithTerms.fold(
                  0.0, (sum, item) => sum + (item['amount'] as double));
              final bool isAllSelected = _selectedSubPurposes[purposeKey]
                      ?.every((selected) => selected) ??
                  false;

              final headerCard = Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lightColor, lightColor.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: CheckboxListTile(
                  value: isAllSelected,
                  onChanged: (bool? checked) {
                    setState(() {
                      final currentSelections =
                          _selectedSubPurposes[purposeKey] ?? [];
                      _selectedSubPurposes[purposeKey] = List<bool>.filled(
                          currentSelections.length, checked ?? false);
                      widget.setSelectedSubPurposes(_selectedSubPurposes);
                    });
                  },
                  activeColor: purposeColor,
                  checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  title: Text(
                    purpose.paymentPurpose ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: purposeColor,
                        fontSize: 16),
                  ),
                  subtitle: Text(
                    "Total Arrears: ${_formatCurrency(totalAmount)}",
                    style: TextStyle(
                        color: purposeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  secondary: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: purposeColor,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_formatCurrency(totalAmount),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              );

              final subCards =
                  subPurposesWithTerms.asMap().entries.map((subEntry) {
                final int subIndex = subEntry.key;
                final subData = subEntry.value;
                final String subPurposePreview = subData['preview'];
                final double subAmount = subData['amount'];

                // SAFETY: Get selections for this purpose key
                final selections = _selectedSubPurposes[purposeKey];

                // If selections don't exist or index is out of range, initialize them
                if (selections == null || subIndex >= selections.length) {
                  if (!_selectedSubPurposes.containsKey(purposeKey)) {
                    _selectedSubPurposes[purposeKey] =
                        List<bool>.filled(subPurposesWithTerms.length, false);
                  }
                  final currentSelections = _selectedSubPurposes[purposeKey]!;
                  if (subIndex >= currentSelections.length) {
                    // Extend the list if needed
                    _selectedSubPurposes[purposeKey] =
                        List<bool>.filled(subPurposesWithTerms.length, false);
                  }
                  widget.setSelectedSubPurposes(_selectedSubPurposes);
                }

                final bool isSelected =
                    (_selectedSubPurposes[purposeKey]?[subIndex] ?? false);

                return Container(
                  margin: const EdgeInsets.only(
                      left: 16, top: 2, bottom: 2, right: 0),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? lightColor.withOpacity(0.5) : lightColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? purposeColor
                          : borderColor.withOpacity(0.3),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? checked) {
                      // 🆕 CHECK IF ITEM HAS [ or ] characters
                      if (subPurposePreview.contains('[') ||
                          subPurposePreview.contains(']')) {
                        // Show warning dialog
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Item Cannot Be Selected'),
                              content: Text(
                                'This item (${subPurposePreview.length > 50 ? subPurposePreview.substring(0, 50) + '...' : subPurposePreview}) already exists as a child in the ready payments section.\n\n'
                                'Please modify the amount directly in the payment table instead.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          },
                        );
                        return; // ❌ Prevent selection
                      }

                      // Normal selection logic
                      setState(() {
                        if (_selectedSubPurposes.containsKey(purposeKey)) {
                          final currentSelections =
                              _selectedSubPurposes[purposeKey]!;
                          if (subIndex < currentSelections.length) {
                            currentSelections[subIndex] = checked ?? false;
                            _selectedSubPurposes[purposeKey] =
                                List.from(currentSelections);
                            widget.setSelectedSubPurposes(_selectedSubPurposes);
                          }
                        }
                      });
                    },
                    activeColor: purposeColor,
                    checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      subPurposePreview,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.normal,
                        // 🆕 ADD STRIKETHROUGH for items with [ or ]
                        decoration: (subPurposePreview.contains('[') ||
                                subPurposePreview.contains(']'))
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        // 🆕 Make text lighter for disabled items
                        color: (subPurposePreview.contains('[') ||
                                subPurposePreview.contains(']'))
                            ? Colors.grey.shade500
                            : null,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        // 🆕 Different background for disabled items
                        color: (subPurposePreview.contains('[') ||
                                subPurposePreview.contains(']'))
                            ? Colors.grey.shade200
                            : purposeColor.withOpacity(isSelected ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (subPurposePreview.contains('[') ||
                                  subPurposePreview.contains(']'))
                              ? Colors.grey.shade400
                              : purposeColor
                                  .withOpacity(isSelected ? 0.5 : 0.3),
                        ),
                      ),
                      child: Text(
                        _formatCurrency(subAmount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          // 🆕 Lighter text for disabled items
                          color: (subPurposePreview.contains('[') ||
                                  subPurposePreview.contains(']'))
                              ? Colors.grey.shade500
                              : purposeColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList();

              final separator = purposeIndex < _purposeList.length - 1
                  ? Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      height: 1,
                      color: Colors.grey[300])
                  : const SizedBox.shrink();

              return [headerCard, ...subCards, separator];
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// Add to your state class
class PrintJob {
  final String id;
  final Student student;
  final DateTime createdAt;
  PrintStatus status;

  PrintJob({
    required this.id,
    required this.student,
    required this.createdAt,
    this.status = PrintStatus.pending,
  });
}

enum PrintStatus { pending, printing, completed, failed }

class PrintQueueManager {
  final List<PrintJob> _queue = [];
  bool _isPrinting = false;

  List<PrintJob> get queue => List.unmodifiable(_queue);
  bool get isPrinting => _isPrinting;

  void addJob(PrintJob job) {
    _queue.add(job);
  }

  void addJobs(List<PrintJob> jobs) {
    _queue.addAll(jobs);
  }

  void removeJob(String id) {
    _queue.removeWhere((j) => j.id == id);
  }

  void clearQueue() {
    _queue.clear();
  }

  Future<void> processQueue(Function(PrintJob) printFunction) async {
    if (_isPrinting) return;

    _isPrinting = true;

    while (_queue.isNotEmpty) {
      final job = _queue.first;
      job.status = PrintStatus.printing;

      try {
        await printFunction(job);
        job.status = PrintStatus.completed;
        _queue.removeAt(0);
      } catch (e) {
        job.status = PrintStatus.failed;
        // Optionally retry or move to failed list
      }
    }

    _isPrinting = false;
  }
}

class ArrearsSummary {
  final String transactionCode;
  final String projectName;
  final String itemName;
  final String batchName;
  final double totalAmount;
  final double totalPaid;
  final double arrears;

  ArrearsSummary({
    required this.transactionCode,
    required this.projectName,
    required this.itemName,
    required this.batchName,
    required this.totalAmount,
    required this.totalPaid,
    required this.arrears,
  });
}

class FilterDialog extends StatefulWidget {
  final List<Student> students;
  final Function(List<Student>, List<String>, String) onFilterApplied;
  final Map<String, bool>? initialSelections;
  final List<String> selectedTerms;
  final List<User> users; // Add this
  // Full list of class names, even ones whose students haven't loaded yet
  // (the parent screen loads the first class fast, then the rest in the
  // background) - lets the class dropdown offer every class immediately.
  final List<String> knownClasses;
  // Fetches a single class's students on demand, for when the user picks a
  // class that hasn't finished loading in the background yet.
  final Future<List<Student>> Function(String className)? onFetchClassStudents;

  const FilterDialog({
    Key? key,
    required this.students,
    required this.onFilterApplied,
    this.initialSelections,
    this.selectedTerms = const [],
    required this.users, // Add this
    this.knownClasses = const [],
    this.onFetchClassStudents,
  }) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  String? _selectedClass;
  List<String> _selectedTerms = [];
  String? _selectedPaymentPurpose;
  bool _selectAll = false;
  Map<String, bool> _selectedStudents = {};

  // Arrears filter type
  String _arrearsFilterType = 'all'; // 'all', 'arrears_only', 'fully_paid'

  List<String> _availableClasses = [];
  List<String> _availableTerms = [];
  List<String> _availablePaymentPurposes = [];
  List<Student> _originalStudents = [];
  List<Student> _filteredStudents = [];
  bool _filtersApplied = false;
  bool _isFetchingClassOnDemand = false;

// Check if current user is a teacher
  bool _isTeacher() {
    final loggedInUser = getLoggedInUser();
    if (loggedInUser == null) return false;

    final user = widget.users.firstWhere(
      (u) => u.username == loggedInUser.username,
      orElse: () => User(
        id: 0,
        username: '',
        password: '',
        role: '', // unmatched/not-yet-loaded user - don't assume teacher
        assignedClasses: [],
        securityQuestions: const [],
        securityAnswers: const [],
        phone: '',
      ),
    );

    return user.role?.toLowerCase() == 'teacher';
  }

// Get teacher's assigned classes
  List<String> _getTeacherAssignedClasses() {
    final loggedInUser = getLoggedInUser();
    if (loggedInUser == null) return [];

    final user = widget.users.firstWhere(
      (u) => u.username == loggedInUser.username,
      orElse: () => User(
        id: 0,
        username: '',
        password: '',
        role: '', // unmatched/not-yet-loaded user - don't assume teacher
        assignedClasses: [],
        securityQuestions: const [],
        securityAnswers: const [],
        phone: '',
      ),
    );

    if (user.assignedClasses != null && user.assignedClasses!.isNotEmpty) {
      // Return as-is, but we'll do case-insensitive comparison later
      return user.assignedClasses!;
    }
    return [];
  }

  @override
  void initState() {
    super.initState();

    // Apply teacher filter to original students if user is a teacher (case-insensitive)
    if (_isTeacher()) {
      final assignedClasses = _getTeacherAssignedClasses();
      if (assignedClasses.isNotEmpty) {
        final assignedClassesLower =
            assignedClasses.map((c) => c.toLowerCase()).toList();

        _originalStudents = widget.students.where((student) {
          final studentClass = student.class_?.toLowerCase() ?? '';
          return assignedClassesLower.contains(studentClass);
        }).toList();
      } else {
        _originalStudents = List.from(widget.students);
      }
    } else {
      _originalStudents = List.from(widget.students);
    }

    _filteredStudents = List.from(_originalStudents);
    _selectedTerms = List.from(widget.selectedTerms);
    _extractFilterOptions();

    if (widget.initialSelections != null) {
      _selectedStudents = Map.from(widget.initialSelections!);
    } else {
      for (var student in _originalStudents) {
        _selectedStudents[student.studentIdNumber.toString()] = true;
      }
    }

    if (_selectedTerms.isNotEmpty) {
      _applyFilters();
    }
    _updateSelectAllState();
    _filtersApplied = true;
  }

  void _updateSelectAllState() {
    final allSelected = _filteredStudents
        .every((s) => _selectedStudents[s.studentIdNumber] == true);
    final noneSelected = _filteredStudents
        .every((s) => _selectedStudents[s.studentIdNumber] == false);
    if (allSelected) {
      _selectAll = true;
    } else if (noneSelected) {
      _selectAll = false;
    } else {
      _selectAll = false;
    }
  }

  void _extractFilterOptions() {
    // Get all classes from students, plus the full known-classes list (some
    // of which may not have any loaded students yet - the parent screen
    // loads the first class fast and the rest in the background) so the
    // dropdown offers every class immediately, not just whatever has
    // finished loading so far.
    List<String> allClasses = <String>{
      ..._originalStudents
          .map((s) => s.class_)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>(),
      ...widget.knownClasses,
    }.toList()
      ..sort();

    // Check if user is a teacher and filter classes accordingly (case-insensitive)
    if (_isTeacher()) {
      final assignedClasses = _getTeacherAssignedClasses();
      if (assignedClasses.isNotEmpty) {
        // Convert assigned classes to lowercase for comparison
        final assignedClassesLower =
            assignedClasses.map((c) => c.toLowerCase()).toList();

        // Only show classes that are assigned to the teacher AND exist in the student list
        _availableClasses = allClasses
            .where((c) => assignedClassesLower.contains(c.toLowerCase()))
            .toList()
          ..sort();
      } else {
        // If teacher has no assigned classes, show all classes
        _availableClasses = allClasses;
      }
    } else {
      // Non-teachers see all classes
      _availableClasses = allClasses;
    }

    // Terms extraction remains the same
    _availableTerms = _originalStudents
        .expand((s) => s.terms ?? [])
        .where((t) => t != null && t.isNotEmpty)
        .map((t) => t.trim())
        .toSet()
        .cast<String>()
        .toList()
      ..sort();
  }

  // Wraps _applyFilters(): if the selected class hasn't finished loading in
  // the background yet, fetch just that class on demand first instead of
  // filtering against data that isn't there yet.
  Future<void> _onApplyFiltersPressed() async {
    final selectedClass = _selectedClass;
    if (selectedClass != null && widget.onFetchClassStudents != null) {
      final alreadyLoaded = _originalStudents.any(
          (s) => (s.class_ ?? '').toLowerCase() == selectedClass.toLowerCase());

      if (!alreadyLoaded) {
        setState(() => _isFetchingClassOnDemand = true);
        try {
          final fetched = await widget.onFetchClassStudents!(selectedClass);
          final existingIds =
              _originalStudents.map((s) => s.studentIdNumber).toSet();
          final newStudents = fetched
              .where((s) => !existingIds.contains(s.studentIdNumber))
              .toList();
          setState(() {
            _originalStudents = [..._originalStudents, ...newStudents];
          });
        } catch (e) {
          debugPrint('❌ Failed to fetch class "$selectedClass" on demand: $e');
        } finally {
          setState(() => _isFetchingClassOnDemand = false);
        }
      }
    }

    _applyFilters();
  }

  void _applyFilters() {
    List<Student> filtered = List.from(_originalStudents);

    if (_surnameController.text.trim().isNotEmpty) {
      final query = _surnameController.text.trim().toLowerCase();
      filtered = filtered
          .where((s) => s.surname?.toLowerCase().contains(query) ?? false)
          .toList();
    }

    if (_regNumberController.text.trim().isNotEmpty) {
      final query = _regNumberController.text.trim().toLowerCase();
      filtered = filtered
          .where(
              (s) => s.studentIdNumber?.toLowerCase().contains(query) ?? false)
          .toList();
    }

    if (_selectedClass != null && _selectedClass!.isNotEmpty) {
      // Case-insensitive class comparison
      final selectedClassLower = _selectedClass!.toLowerCase();
      filtered = filtered.where((s) {
        final studentClass = s.class_?.toLowerCase() ?? '';
        return studentClass == selectedClassLower;
      }).toList();
    }

    if (_selectedTerms.isNotEmpty) {
      filtered = filtered.where((s) {
        final studentTerms = s.terms ?? [];
        for (var selectedTerm in _selectedTerms) {
          final selectedTermLower = selectedTerm.trim().toLowerCase();
          for (var studentTerm in studentTerms) {
            if (studentTerm.trim().toLowerCase() == selectedTermLower) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    }

    setState(() {
      _filteredStudents = filtered;
      _filtersApplied = true;
      for (var student in filtered) {
        if (!_selectedStudents.containsKey(student.studentIdNumber)) {
          _selectedStudents[student.studentIdNumber.toString()] = true;
        }
      }
      _updateSelectAllState();
    });
  }

  void _resetFilters() {
    _surnameController.clear();
    _regNumberController.clear();
    _selectedClass = null;
    _selectedTerms.clear();
    _selectedPaymentPurpose = null;
    _arrearsFilterType = 'all';
    _filteredStudents = List.from(_originalStudents);
    _filtersApplied = true;
    for (var student in _originalStudents) {
      _selectedStudents[student.studentIdNumber.toString()] = true;
    }
    _selectAll = true;
    setState(() {});
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      for (var student in _filteredStudents) {
        _selectedStudents[student.studentIdNumber.toString()] = _selectAll;
      }
    });
  }

  void _toggleStudentSelection(String studentId, bool? value) {
    setState(() {
      _selectedStudents[studentId] = value ?? false;
      _updateSelectAllState();
    });
  }

  List<Student> getSelectedStudents() {
    return _filteredStudents
        .where((s) => _selectedStudents[s.studentIdNumber] == true)
        .toList();
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _arrearsFilterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _arrearsFilterType = value;
          _filtersApplied = false;
        });
      },
      selectedColor: color,
      backgroundColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter & Select Students',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Surname Filter
                      TextField(
                        controller: _surnameController,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Surname',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _filtersApplied = false,
                      ),
                      const SizedBox(height: 16),

                      // Registration Number Filter
                      TextField(
                        controller: _regNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Registration Number',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _filtersApplied = false,
                      ),
                      const SizedBox(height: 16),

                      // Class Filter Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Class',
                          prefixIcon: Icon(Icons.class_),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('All Classes')),
                          ..._availableClasses.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedClass = value);
                          _filtersApplied = false;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Terms Multi-Select
                      Row(
                        children: [
                          const Text(
                            'Filter by Terms',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTerms = List.from(_availableTerms);
                                _filtersApplied = false;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Select All',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTerms.clear();
                                _filtersApplied = false;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Deselect All',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableTerms.map((term) {
                            final isSelected = _selectedTerms.contains(term);
                            return FilterChip(
                              label: Text(
                                term,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedTerms.add(term);
                                  } else {
                                    _selectedTerms.remove(term);
                                  }
                                  _filtersApplied = false;
                                });
                              },
                              selectedColor: Colors.blue.shade100,
                              checkmarkColor: Colors.blue,
                            );
                          }).toList(),
                        ),
                      ),
                      if (_selectedTerms.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_selectedTerms.length} term(s) selected',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),
                      const Divider(),

                      // ============ ARREARS FILTER SECTION ============
                      const Text(
                        'Payment Status Filter',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Arrears filter chips
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterChip('All Students', 'all', Colors.blue),
                          _buildFilterChip(
                              'With Arrears', 'arrears_only', Colors.red),
                          _buildFilterChip(
                              'Fully Paid', 'fully_paid', Colors.green),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Apply Filters Button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isFetchingClassOnDemand
                                  ? null
                                  : _onApplyFiltersPressed,
                              icon: _isFetchingClassOnDemand
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.filter_alt),
                              label: Text(
                                _isFetchingClassOnDemand
                                    ? 'LOADING CLASS...'
                                    : 'APPLY FILTERS',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.clear_all),
                              label: const Text('RESET'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),

                      // Student Selection Section
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Students (${_filteredStudents.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!_filtersApplied)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '⚠️ Apply filters to see results',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text(
                          'Select All Students',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: _selectAll,
                        onChanged: _toggleSelectAll,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _filteredStudents.isEmpty
                            ? const Center(
                                child: Text(
                                  'No students match the filters',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = _filteredStudents[index];
                                  return CheckboxListTile(
                                    title: Text(
                                        '${student.name} ${student.surname}'),
                                    subtitle: Text(
                                        'Class: ${student.class_} | ID: ${student.studentIdNumber}'),
                                    value: _selectedStudents[
                                            student.studentIdNumber] ??
                                        false,
                                    onChanged: (value) {
                                      _toggleStudentSelection(
                                          student.studentIdNumber.toString(),
                                          value);
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset All'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final selected = getSelectedStudents();
                          // Pass filter type back to parent
                          widget.onFilterApplied(
                            selected,
                            _selectedTerms,
                            _arrearsFilterType, // Pass the filter type
                          );
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Apply (${getSelectedStudents().length} selected)',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'package:collection/collection.dart';
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:printing/printing.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:zitf_system/auth/userdb.dart';
// import 'package:zitf_system/database/payment_purpose.dart';
// import 'package:zitf_system/database/payment_receipts_log.dart';
// import 'package:zitf_system/database/projects/project_item_batch_model.dart';
// import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
// import 'package:zitf_system/database/projects/project_item_model.dart';
// import 'package:zitf_system/database/projects/project_model.dart';
// import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
// import 'package:zitf_system/database/school_info.dart';
// import 'package:zitf_system/database/student.dart';
// import 'package:zitf_system/database/student_payments.dart';
// import 'package:url_launcher/url_launcher.dart' as launcher;
// import 'dart:async';
// import 'package:background_sms/background_sms.dart';
// import 'package:permission_handler/permission_handler.dart';

// import 'package:bluetooth_print/bluetooth_print.dart';
// import 'package:bluetooth_print/bluetooth_print_model.dart';
// import 'package:flutter/services.dart';
// import 'package:zitf_system/database/terms.dart';
// import 'package:zitf_system/global%20files/global_term_id.dart';
// import 'package:zitf_system/main.dart';
// import 'package:zitf_system/projects/student_project_payments/create_student_project_payment_backup.dart';
// import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
// import 'package:uuid/data.dart';
// import 'package:uuid/uuid.dart';
// import 'package:uuid/rng.dart';
// import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
// import 'package:zitf_system/reusable_codes/serializers/batch_sell_unit_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/payment_log_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/payment_purpose_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/product_batch_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/project_items_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/project_sale_transaction_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/projects_serializerr.dart';
// import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/student_payments_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
// import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';
// import 'package:http/http.dart' as http;
// import 'package:zitf_system/reusable_codes/serializers/users_serializer.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:zitf_system/utils/windows_printer_helper.dart';
// import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

// class _CachedStudents {
//   final List<Student> students;
//   final DateTime expiresAt;
//   _CachedStudents(this.students, this.expiresAt);
//   bool get isValid => DateTime.now().isBefore(expiresAt);
// }

// class StudentsArrearsStatementScreen extends StatefulWidget {
//   const StudentsArrearsStatementScreen({Key? key, this.transaction})
//       : super(key: key);

//   final ProjectSaleTransaction? transaction;

//   @override
//   StudentsArrearsStatementScreenState createState() =>
//       StudentsArrearsStatementScreenState();
// }

// class FocusNodeManager {
//   final Map<int, FocusNode> _focusNodes = {};

//   FocusNode getFocusNode(int index) {
//     if (!_focusNodes.containsKey(index)) {
//       _focusNodes[index] = FocusNode();
//     }
//     return _focusNodes[index]!;
//   }

//   void dispose() {
//     for (var node in _focusNodes.values) {
//       node.dispose();
//     }
//     _focusNodes.clear();
//   }
// }

// class StudentsArrearsStatementScreenState
//     extends State<StudentsArrearsStatementScreen> {
//   final GlobalKey<_ArrearsSectionState> _arrearsSectionKey =
//       GlobalKey<_ArrearsSectionState>();
//   // In your _MakePaymentScreenState class
//   final GlobalKey _confirmButtonKey = GlobalKey();
//   Future<List<Map<String, dynamic>>> _getFreshArrearsData() async {
//     // Force refresh the ArrearsSection to get latest data
//     final freshData =
//         await _arrearsSectionKey.currentState?.refreshAndGetData();
//     return freshData ?? [];
//   }

//   int _arrearsVersion = 0;
//   Map<String, List<bool>> _sharedSelectedSubPurposes = {};
//   List<Map<String, dynamic>> _pendingRestorations = [];

//   // Add this method to handle selected items from ArrearsSection
//   void _handleArrearsSelected(List<Map<String, dynamic>> selectedItems) {
//     setState(() {
//       for (var item in selectedItems) {
//         final newItem = {
//           'purpose': item['purpose'],
//           'amount': item['amount'],
//           'originalAmount': item['amount'],
//           'currentAmount': item['amount'],
//           'termId': item['termId'] ?? globalTermId.toString(),
//           'amountError': null,
//           'isRemainingArrears': false,
//         };

//         final index = _paymentPurposes.length;
//         _paymentPurposes.add(newItem);
//         _amountControllers[index] = TextEditingController(
//           text: (item['amount'] as double).toStringAsFixed(2),
//         );
//       }
//       _updateTotalEntered();
//       _removeSelectedItemsFromArrears(selectedItems);
//     });
//   }

//   void _removeSelectedItemsFromArrears(
//       List<Map<String, dynamic>> selectedItems) {
//     // This will trigger a refresh of the ArrearsSection
//     setState(() {
//       _arrearsVersion++; // Increment version to force ArrearsSection to reload
//     });
//   }

//   // Add these getter/setter methods for shared state
//   Map<String, List<bool>> _getSelectedSubPurposes() {
//     return _sharedSelectedSubPurposes;
//   }

//   void _setSelectedSubPurposes(Map<String, List<bool>> value) {
//     _sharedSelectedSubPurposes = value;
//   }

//   String _selectionSummary = '';

//   late final FocusNodeManager _focusManager;
//   final FocusNode _pmAmountFocusNode = FocusNode();

//   Timer? _pmAmountDebounceTimer;
//   final int _pmAmountDebounceDelay = 1200; // Increased to 1200ms for better UX
//   DateTime? _lastTypingTime;
//   bool _isAutoCorrecting = false; // Flag to prevent recursive auto-correction
//   String _lastManuallyEnteredValue = ''; // Track manually entered values
//   double? finalReceived; // Store the final received amount after debounce
// // bluetooth helper
//   late BluetoothHelper bluetoothHelper;
//   List<String> _arrearsTerms = [];
//   String? _selectedArrearsTerm;

//   final _formKey = GlobalKey<FormState>();

//   final _studentSearchController = TextEditingController();
//   late final FocusNode _searchFocusNode;

//   final TextEditingController _paymentAmountController =
//       TextEditingController();

//   final List<Map<String, dynamic>> _paymentPurposes = [];
//   PaymentPurpose? _selectedPaymentPurpose;
//   double? _paymentAmount;
//   Student? _selectedStudent;
//   DateTime _paymentDate = DateTime.now();
//   String? _paymentInfo;
//   String? _paymentInfo11;

//   String? _paymentInfo1;
//   String? _paymentInfo2;

//   String? _phoneNumber;

//   String? selectedTermId;
//   String? selectedSchool;

//   List<String> _terms = []; // Declare without 'final'
//   List<String> _schools = []; // Declare without 'final'

//   Future<List<StudentPayment>> _StudentPaymentFuture = Future.value([]);
//   DeviceRole? _role;
//   String? _hostIp;

//   List<StudentPayment>? _cachedServerStudentPayments;
//   List<Terms>? _cachedServerTerms;
//   List<PaymentPurpose>? _cachedServerStudentPaymentPurposes;
//   List<Student>? _cachedServerStudents;
//   List<School>? _cachedServerSchoolInfo;
//   Map<String, Terms> _termsMap = {};

//   List<Student>? _cachedFilteredStudents;

//   Future<void>? _arrearsFuture;

//   Future<double>? _totalArrearsFuture;

//   Timer? _searchDebounce;
//   final Duration _searchDebounceDuration = const Duration(milliseconds: 350);

// // Simple in-memory cache for server search results
//   final Map<String, _CachedStudents> _studentsCache = {};

//   List<Student>?
//       _cachedServerStudentsForSearch; // used only for immediate parse

//   List<User> _users = [];
//   Map<int?, User> _usersMap = {}; // quick lookup by id
//   List<User>? _cachedServerUsers;

//   List<Project> _projects = [];
//   List<Project>? _cachedServerProjects;
//   Map<int?, Project> _projectsMap = {}; // quick lookup by id

//   List<ProjectItem> _items = [];
//   List<ProjectItem>? _cachedServerProjectItems;
//   Map<int?, ProjectItem> _projectItemsMap = {};

//   List<ProductBatch> _selectedBatch = [];
//   List<ProductBatch>? _cachedProductBatches;
//   Map<int?, ProductBatch> _productBatchMap = {};

//   List<BatchSellUnit> _batchSellUnits = [];
//   List<BatchSellUnit>? _cachedBatchSellUnits;
//   Map<int?, BatchSellUnit> _batchSellUnitMap = {};

//   int _quantity = 1;

//   List<Student> _students = [];
//   Student? _student;
//   Project? _project;
//   ProjectItem? _item;
//   ProductBatch? _selectedBatches;
//   BatchSellUnit? _selectedSellUnit;

//   // CLIENT-SPECIFIC CACHE VARIABLES
//   // ==============================
//   List<ProjectSaleTransaction>? _cachedServerProjectSaleTransactions;
//   List<ProductBatch>? _cachedProductBatchesClient;
//   bool _isClientDataLoaded = false;

// // Add this to your state variables in StudentsArrearsStatementScreenState
//   List<String> _selectedFilterTerms = [];
// // Add this at the beginning of your widget class
//   final Map<String, List<bool>> _selectedSubPurposes = {};
//   double _cachedTotalEntered = 0.0;

//   String capitalize(String value) {
//     var result = value[0].toUpperCase();
//     for (int i = 1; i < value.length; i++) {
//       if (value[i - 1] == " ") {
//         result = result + value[i].toUpperCase();
//       } else {
//         result = result + value[i];
//       }
//     }
//     return result;
//   }

//   List<String> _windowsPrinters = [];
//   String? _selectedWindowsPrinter;
//   bool _isLoadingPrinters = false;
//   bool _isTestingConnection = false;

//   // Platform detection
//   bool get _isWindows => Platform.isWindows;
//   bool get _isAndroid => Platform.isAndroid;

//   BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

//   bool _connected = false;
//   BluetoothDevice? _device;
//   String tips = 'connect receipt priter';
//   int? BluetoothStates;

//   String _paymentMethodType =
//       'cash'; // cash | mobile_money | bank_transfer | card | other
//   final String _currency = 'USD';
//   String? _provider;
//   int _purposeListVersion = 0;

//   final ScrollController _mainScrollController = ScrollController();
//   final GlobalKey _dataTableKey = GlobalKey();

//   final TextEditingController _pmAmountCtrl = TextEditingController();
//   final TextEditingController _pmReferenceCtrl = TextEditingController();
//   final TextEditingController _pmPhoneCtrl = TextEditingController();
//   final TextEditingController _pmAccountNumberCtrl = TextEditingController();
//   final TextEditingController _pmAccountNameCtrl = TextEditingController();
//   final Map<int, TextEditingController> _amountControllers = {};

// // Add these to your state variables
//   String? _lastUsedPrinter;
//   SharedPreferences? _prefs;
//   bool _isLoadingLastPrinter = false;

// // Add this to your state class
//   bool _selectAll = false;
//   final Map<String, bool> _selectedStudents = {};

// // Add these methods
//   void _toggleSelectAll(bool? value) {
//     setState(() {
//       _selectAll = value ?? false;
//       final studentsToShow = _cachedFilteredStudents ?? _students ?? [];
//       for (var student in studentsToShow) {
//         if (student is Student) {
//           _selectedStudents[student.studentIdNumber.toString()] = _selectAll;
//         }
//       }
//       _updateSelectionSummary();
//     });
//   }

//   void _toggleStudentSelection(String studentId, bool? value) {
//     setState(() {
//       _selectedStudents[studentId] = value ?? false;
//       _selectAll = _selectedStudents.values.every((selected) => selected);
//       _updateSelectionSummary();
//     });
//   }

// // Update _getSelectedStudents
//   List<Student> _getSelectedStudents() {
//     final studentsToShow = _cachedFilteredStudents ?? _students ?? [];
//     return studentsToShow
//         .whereType<Student>()
//         .where((s) => _selectedStudents[s.studentIdNumber] == true)
//         .toList();
//   }

//   Future<void> _loadPreferences() async {
//     _prefs = await SharedPreferences.getInstance();
//     _lastUsedPrinter = _prefs?.getString('last_windows_printer');

//     // Auto-connect after printers are loaded
//     if (_lastUsedPrinter != null && _lastUsedPrinter!.isNotEmpty) {
//       // Wait for printers to load (add a small delay)
//       Future.delayed(const Duration(milliseconds: 500), () {
//         _autoConnectLastPrinter();
//       });
//     }
//   }

//   Future<void> _autoConnectLastPrinter() async {
//     // Don't auto-connect if already connected or already trying
//     if (_connected || _isTestingConnection) return;

//     // Check if the last used printer exists in current list
//     if (_windowsPrinters.contains(_lastUsedPrinter)) {
//       setState(() {
//         _selectedWindowsPrinter = _lastUsedPrinter;
//       });

//       // Call your existing connection method
//       await _connectWindowsPrinter();
//     } else if (_windowsPrinters.isNotEmpty && _lastUsedPrinter != null) {
//       // Last printer not found, show notification
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//               'Last printer "$_lastUsedPrinter" not found. Please select a new printer.'),
//           backgroundColor: Colors.orange,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     }
//   }

//   double get _totalEntered {
//     return _paymentPurposes.fold(
//       0.0,
//       (sum, p) => sum + (p['currentAmount'] as double),
//     );
//   }

//   void _updateTotalEntered() {
//     _pmAmountCtrl.text = _cachedTotalEntered.toStringAsFixed(2);
//   }

//   double _originalTotalForValidation = 0.0;

//   Future<void> _showDialog(String message) async {
//     await showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("🧾 Make Payment Submission Feedback"),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(),
//             child: const Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }

//   // Add these to your state class
//   final Map<int, bool> _isEditingAmount =
//       {}; // Tracks which row is being edited

// // Optional: Method to clear editing state when needed
//   void _stopEditing(int index) {
//     setState(() {
//       _isEditingAmount[index] = false;
//     });
//   }

//   // Load Windows printers
//   Future<void> _loadWindowsPrinters() async {
//     if (!_isWindows) return;

//     setState(() {
//       _isLoadingPrinters = true;
//     });

//     try {
//       final printers = await Printing.listPrinters();
//       final availablePrinters =
//           printers.where((p) => p.isAvailable).map((p) => p.name).toList();

//       setState(() {
//         _windowsPrinters = availablePrinters;
//         _isLoadingPrinters = false;
//       });

//       if (availablePrinters.isEmpty) {
//         setState(() {
//           tips = 'No printers found. Please install a printer driver.';
//         });
//       } else {
//         setState(() {
//           tips =
//               'Found ${availablePrinters.length} printer(s). Select one to connect.';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         tips = 'Error loading printers: $e';
//         _isLoadingPrinters = false;
//       });
//     }
//   }

//   // Connect Windows printer
// // Connect Windows printer
//   Future<void> _connectWindowsPrinter() async {
//     if (_selectedWindowsPrinter == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a printer first')),
//       );
//       return;
//     }

//     setState(() {
//       _isTestingConnection = true;
//       tips = 'Testing connection to $_selectedWindowsPrinter...';
//     });

//     try {
//       final printers = await Printing.listPrinters();
//       final selectedPrinter = printers.firstWhere(
//         (p) => p.name == _selectedWindowsPrinter,
//         orElse: () => throw Exception('Printer not found'),
//       );

//       if (selectedPrinter.isAvailable) {
//         setState(() {
//           _connected = true;
//           tips = '✅ Connected to ${selectedPrinter.name}';
//           _isTestingConnection = false;
//         });

//         // ✅ SAVE THE LAST USED PRINTER
//         await _prefs?.setString(
//             'last_windows_printer', _selectedWindowsPrinter!);
//         setState(() {
//           _lastUsedPrinter = _selectedWindowsPrinter;
//         });
//       } else {
//         throw Exception('Printer is not available');
//       }
//     } catch (e) {
//       setState(() {
//         _connected = false;
//         tips = '❌ Failed to connect: $e';
//         _isTestingConnection = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('❌ Failed to connect: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   // Connect Bluetooth printer (Android)
//   Future<void> _connectBluetoothPrinter() async {
//     if (_device == null) {
//       setState(() {
//         tips = 'Please select a Bluetooth device first';
//       });
//       return;
//     }

//     setState(() {
//       tips = 'Connecting to ${_device!.name}...';
//     });

//     try {
//       await bluetoothHelper.bluetoothPrint.connect(_device!);
//       setState(() {
//         tips = 'Connected to ${_device!.name}';
//         _connected = true;
//       });
//     } catch (e) {
//       setState(() {
//         tips = 'Failed to connect: $e';
//         _connected = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to connect: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   // Disconnect printer
//   Future<void> _disconnectPrinter() async {
//     if (_isAndroid) {
//       setState(() {
//         tips = 'Disconnecting...';
//       });

//       try {
//         await bluetoothHelper.bluetoothPrint.disconnect();
//         setState(() {
//           tips = 'Disconnected';
//           _connected = false;
//           _device = null;
//         });
//       } catch (e) {
//         setState(() {
//           tips = 'Failed to disconnect: $e';
//         });
//       }
//     } else if (_isWindows) {
//       setState(() {
//         tips = 'Disconnected';
//         _connected = false;
//         _selectedWindowsPrinter = null;
//       });
//     }
//   }

//   @override
//   @override
//   void initState() {
//     super.initState();
//     _loadPreferences();
//     _loadWindowsPrinters(); // Your existing method

//     _pmAmountFocusNode.addListener(() {
//       if (!_pmAmountFocusNode.hasFocus && !_isAutoCorrecting) {
//         final received = double.tryParse(_pmAmountCtrl.text);
//         finalReceived = received;

//         if (received != null && received < _totalEntered && _totalEntered > 0) {
//           _isAutoCorrecting = true;
//           final corrected = _totalEntered.toStringAsFixed(2);
//           _pmAmountCtrl.text = corrected;

//           _isAutoCorrecting = false;
//           _formKey.currentState?.validate();
//         }
//       }
//     });
//     _focusManager = FocusNodeManager();

//     _searchFocusNode = FocusNode();
//     _pmAmountDebounceTimer?.cancel();

//     fetchTerms();
//     fetchSchools();
//     fetchStudentsMetadata();
//     fetchPaymentPurposes();
//     fetchStudentPayments();
//     fetchUsers(); // <-- NEW
//     _fetchProjectsFromServer();
//     _fetchProjectItemsFromServer();
//     fetchProductBatch();
//     fetchBatchSellUnit();
//     _fetchProjectSaleTransactions();

//     // ✅ Initialize data based on device role
//     _initializeDataForRole();

//     final tx = widget.transaction;

//     if (tx != null) {
//       _loadTransactionData(tx);
//     }

//     if (_isWindows) {
//       _loadWindowsPrinters();
//     } else {
//       // Create a BluetoothHelper instance
//       bluetoothHelper = BluetoothHelper();

//       // Set up the connection state change callback
//       bluetoothHelper.onConnectionStateChanged = (isConnected, message) {
//         setState(() {
//           _connected = isConnected; // Update UI state
//           tips = message; // Update message dynamically
//         });
//       };

//       // Initialize Bluetooth
//       bluetoothHelper.initBluetooth();

//       // Verify the connection status periodically or based on user action
//       Future.delayed(const Duration(seconds: 5), () {
//         bluetoothHelper.verifyConnection();
//       });

//       BluetoothHelper().bluetoothPrint.state.listen((state) {
//         BluetoothStates = state;
//       });
//     }
//     _pmAmountCtrl.addListener(() {
//       setState(() {}); // refresh change display live
//     });
//   }

//   final PrintQueueManager _printQueueManager = PrintQueueManager();

//   Future<void> _addToPrintQueue(List<Student> students) async {
//     for (var student in students) {
//       final job = PrintJob(
//         id: const Uuid().v4(),
//         student: student,
//         createdAt: DateTime.now(),
//       );
//       _printQueueManager.addJob(job);
//     }

//     // Show queue dialog
//     _showPrintQueueDialog();
//   }

// // Add this method to get teacher's assigned classes from the users model
//   List<String> _getTeacherAssignedClasses() {
//     final loggedInUser = getLoggedInUser();
//     if (loggedInUser == null) return [];

//     // Find the full user object from _users list
//     final user = _users.firstWhere(
//       (u) => u.username == loggedInUser.username,
//       orElse: () => User(
//         id: 0,
//         username: '',
//         password: '',
//         role: 'teacher',
//         assignedClasses: [],
//         securityQuestions: const [],
//         securityAnswers: const [],
//         phone: '',
//       ),
//     );

//     // Check if user has assigned classes
//     if (user.assignedClasses != null && user.assignedClasses!.isNotEmpty) {
//       return user.assignedClasses!;
//     }

//     // If no assigned classes, return empty list (will show all students)
//     return [];
//   }

// // Check if current user is a teacher
//   bool _isTeacher() {
//     final loggedInUser = getLoggedInUser();
//     if (loggedInUser == null) return false;

//     final user = _users.firstWhere(
//       (u) => u.username == loggedInUser.username,
//       orElse: () => User(
//         id: 0,
//         username: '',
//         password: '',
//         role: 'teacher',
//         assignedClasses: [],
//         securityQuestions: const [],
//         securityAnswers: const [],
//         phone: '',
//       ),
//     );

//     return user.role?.toLowerCase() == 'teacher';
//   }

//   void _showPrintQueueDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: const Text('Print Queue'),
//             content: SizedBox(
//               width: 400,
//               height: 400,
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: _printQueueManager.queue.length,
//                       itemBuilder: (context, index) {
//                         final job = _printQueueManager.queue[index];
//                         return ListTile(
//                           title: Text(
//                               '${job.student.name} ${job.student.surname}'),
//                           subtitle: Text(
//                               'Status: ${job.status.toString().split('.').last}'),
//                           trailing: job.status == PrintStatus.failed
//                               ? IconButton(
//                                   icon: const Icon(Icons.refresh,
//                                       color: Colors.red),
//                                   onPressed: () {
//                                     // Retry failed print
//                                   },
//                                 )
//                               : null,
//                         );
//                       },
//                     ),
//                   ),
//                   const Divider(),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.end,
//                     children: [
//                       TextButton(
//                         onPressed: () {
//                           _printQueueManager.clearQueue();
//                           Navigator.pop(context);
//                         },
//                         child: const Text('Clear Queue'),
//                       ),
//                       const SizedBox(width: 8),
//                       ElevatedButton(
//                         onPressed: () {
//                           _printQueueManager.processQueue((job) async {
//                             await _printStudentStatement(job.student);
//                           });
//                         },
//                         child: const Text('Start Printing'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Future<void> _printStudentStatement(Student student) async {
//     // Set the selected student to the one being printed
//     setState(() {
//       _selectedStudent = student;
//       _resetPaymentData();
//       _totalArrearsFuture = _computeTotalStudentArrears(student);
//     });

//     // Wait for arrears calculation to complete
//     await _totalArrearsFuture;
//     await Future.delayed(const Duration(milliseconds: 500));
//     // Show loading indicator
//     if (mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (context) => const Center(child: CircularProgressIndicator()),
//       );
//     }

//     try {
//       // Fetch all necessary data for the statement
//       final purposeList =
//           await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
//               student);
//       final feesArrears = await _totalArrearsFuture ?? 0.0;
//       final studentId = student.studentIdNumber.toString();
//       final projectArrearsDetails = buildStudentArrearsDetails(studentId);
//       final totalProjectArrears =
//           projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);
//       final grandTotal = feesArrears + totalProjectArrears;
//       final loggedInUser = getLoggedInUser();
//       final user = loggedInUser?.username;
//       final username = user != null && user.isNotEmpty ? user : 'Unknown User';
//       final School schoolInfo = await _fetchSchoolInfo();

//       // Close loading dialog
//       if (mounted) Navigator.pop(context);

//       // Platform-specific connection check
//       if (Platform.isAndroid && !_connected) {
//         await _showBluetoothConnectionDialog();
//         return;
//       }

//       if (Platform.isWindows &&
//           (_selectedWindowsPrinter == null || !_connected)) {
//         await _showWindowsPrinterConnectionDialog();
//         return;
//       }

//       // Build statement lines
//       final List<LineText> statementLines = _buildStatementLines(
//         schoolInfo: schoolInfo,
//         selectedStudent: student,
//         feesArrears: feesArrears,
//         totalProjectArrears: totalProjectArrears,
//         grandTotal: grandTotal,
//         purposeList: purposeList,
//         projectArrearsDetails: projectArrearsDetails,
//         generatedBy: username,
//       );

//       // Print based on platform
//       if (Platform.isAndroid) {
//         await bluetoothPrint.printReceipt({}, statementLines);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   '✓ Statement printed for ${student.name} ${student.surname}'),
//               backgroundColor: Colors.green,
//               duration: const Duration(seconds: 2),
//             ),
//           );
//         }
//       } else if (Platform.isWindows) {
//         await _printToWindowsPrinter(statementLines);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   '✓ Statement printed for ${student.name} ${student.surname}'),
//               backgroundColor: Colors.green,
//               duration: const Duration(seconds: 2),
//             ),
//           );
//         }
//       } else {
//         throw Exception('Printing not supported on this platform');
//       }
//     } catch (e) {
//       // Close loading dialog if still open
//       if (mounted) Navigator.pop(context);

//       // Show error message
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//                 '❌ Error printing statement for ${student.name} ${student.surname}: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 4),
//           ),
//         );
//       }
//       print('Error printing statement for ${student.name}: $e');
//       rethrow; // Re-throw to let the queue manager know it failed
//     }
//   }

//   Widget _buildFloatingActionButton() {
//     if (_isAndroid) {
//       // Bluetooth scan button for Android
//       return StreamBuilder<bool>(
//         stream: bluetoothPrint.isScanning,
//         initialData: false,
//         builder: (c, snapshot) {
//           if (snapshot.data == true) {
//             return FloatingActionButton(
//               onPressed: () => bluetoothPrint.stopScan(),
//               backgroundColor: Colors.red,
//               child: const Icon(Icons.stop),
//             );
//           } else {
//             return FloatingActionButton(
//               onPressed: () => bluetoothPrint.startScan(
//                 timeout: const Duration(seconds: 5),
//               ),
//               tooltip: 'Scan for Bluetooth Printers',
//               child: const Icon(Icons.bluetooth_searching),
//             );
//           }
//         },
//       );
//     } else if (_isWindows) {
//       // Refresh printers button for Windows
//       return FloatingActionButton(
//         onPressed: _isLoadingPrinters ? null : _loadWindowsPrinters,
//         tooltip: 'Refresh Printer List',
//         child: _isLoadingPrinters
//             ? const SizedBox(
//                 width: 24,
//                 height: 24,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   color: Colors.white,
//                 ),
//               )
//             : const Icon(Icons.refresh),
//       );
//     }

//     return const SizedBox.shrink();
//   }

//   // ✅ UPDATED: Initialize data based on role with proper client fetching
//   Future<void> _initializeDataForRole() async {
//     final role = await getDeviceRole();

//     if (role == DeviceRole.host) {
//       // Host mode: Load directly from Hive
//       _students = Hive.box<Student>('students').values.toList();
//       _projects = Hive.box<Project>('projects').values.toList();
//       _items = Hive.box<ProjectItem>('projectItems').values.toList();
//       _selectedBatch =
//           Hive.box<ProductBatch>('product_batches').values.toList();
//       _batchSellUnits =
//           Hive.box<BatchSellUnit>('batch_sell_units').values.toList();

//       // Also load payment purposes for host
//       await _loadPaymentPurposesForHost();
//       if (_isTeacher()) {
//         _applyTeacherRestrictions();
//       }
//       setState(() {
//         _updateSelectionSummary();
//       });
//     } else {
//       // Client mode: Fetch data from server
//       await _fetchDataForClient();
//       if (_isTeacher()) {
//         _applyTeacherRestrictions();
//       }
//       setState(() {
//         _updateSelectionSummary();
//       });
//     }
//   }

// // In _initializeDataForRole or after loading students:
//   void _applyTeacherFilterAndInitialize() {
//     // Apply teacher class filter
//     if (_isTeacher()) {
//       final assignedClasses = _getTeacherAssignedClasses();
//       if (assignedClasses.isNotEmpty) {
//         // Filter students by teacher's classes
//         final filteredStudents = _students.where((student) {
//           return assignedClasses.contains(student.class_);
//         }).toList();

//         setState(() {
//           _cachedFilteredStudents = filteredStudents;
//           // Also select all filtered students
//           _selectedStudents.clear();
//           for (var student in filteredStudents) {
//             _selectedStudents[student.studentIdNumber.toString()] = true;
//           }
//           _selectAll = true;
//         });
//       }
//     }

//     // Get valid terms for current month
//     final validTermIds =
//         _getValidTermsForCurrentMonth().map((t) => t.termId).toSet();
//     final futureTermIds = _getExcludedFutureTermIds();

//     // Auto-select valid terms
//     setState(() {
//       _selectedFilterTerms = validTermIds.toList();
//     });
//   }

//   // Add this after _students is populated in both host and client modes
//   // Single method to handle teacher restrictions
//   void _applyTeacherRestrictions() {
//     // Only apply if user is a teacher
//     if (!_isTeacher()) return;

//     // 1. Filter students by teacher's classes (case-insensitive)
//     final assignedClasses = _getTeacherAssignedClasses();
//     if (assignedClasses.isNotEmpty) {
//       // Convert assigned classes to lowercase for case-insensitive comparison
//       final assignedClassesLower =
//           assignedClasses.map((c) => c.toLowerCase()).toList();

//       final filteredStudents = _students.where((student) {
//         final studentClass = student.class_?.toLowerCase() ?? '';
//         return assignedClassesLower.contains(studentClass);
//       }).toList();

//       setState(() {
//         _cachedFilteredStudents = filteredStudents;
//         _students = filteredStudents;

//         _selectedStudents.clear();
//         for (var student in filteredStudents) {
//           _selectedStudents[student.studentIdNumber.toString()] = true;
//         }
//         _selectAll = true;
//         _updateSelectionSummary();
//       });
//     }

//     // 2. Auto-select only valid terms (not future terms)
//     final validTermIds =
//         _getValidTermsForCurrentMonth().map((t) => t.termId).toSet();
//     setState(() {
//       _selectedFilterTerms = validTermIds.toList();
//     });
//   }

// // ✅ NEW: Load payment purposes for host
//   Future<void> _loadPaymentPurposesForHost() async {
//     try {
//       final box = Hive.box<PaymentPurpose>('payment_purposes');
//       _cachedServerStudentPaymentPurposes = box.values.toList();
//     } catch (e) {
//       debugPrint('❌ Error loading payment purposes for host: $e');
//     }
//   }

// // ✅ UPDATED: Fetch all data for client
//   Future<void> _fetchDataForClient() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//       if (_hostIp == null || _hostIp!.isEmpty) {
//         _showDialog("⚠️ Host IP not set. Please configure connection.");
//         return;
//       }

//       debugPrint('🔄 Fetching client data from $_hostIp...');

//       // Fetch students
//       if (_cachedServerStudents == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/students/all'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerStudents = jsonList
//               .map((json) => studentsFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint('✅ Fetched ${_cachedServerStudents!.length} students');
//         } else {
//           debugPrint('❌ Failed to fetch students: ${response.statusCode}');
//         }
//       }

//       // Fetch payment purposes
//       if (_cachedServerStudentPaymentPurposes == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerStudentPaymentPurposes = jsonList
//               .map((json) =>
//                   paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint(
//               '✅ Fetched ${_cachedServerStudentPaymentPurposes!.length} payment purposes');
//         } else {
//           debugPrint(
//               '❌ Failed to fetch payment purposes: ${response.statusCode}');
//         }
//       }

//       // Fetch terms
//       if (_cachedServerTerms == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerTerms = jsonList
//               .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint('✅ Fetched ${_cachedServerTerms!.length} terms');
//         } else {
//           debugPrint('❌ Failed to fetch terms: ${response.statusCode}');
//         }
//       }

//       // Fetch projects
//       if (_cachedServerProjects == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/projects'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerProjects = jsonList
//               .map((json) => projectsFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint('✅ Fetched ${_cachedServerProjects!.length} projects');
//         } else {
//           debugPrint('❌ Failed to fetch projects: ${response.statusCode}');
//         }
//       }

//       // Fetch project items
//       if (_cachedServerProjectItems == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/projectItems'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerProjectItems = jsonList
//               .map((json) =>
//                   projectItemsFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint(
//               '✅ Fetched ${_cachedServerProjectItems!.length} project items');
//         } else {
//           debugPrint('❌ Failed to fetch project items: ${response.statusCode}');
//         }
//       }

//       // Fetch product batches
//       if (_cachedProductBatches == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/productBatches'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedProductBatches = jsonList
//               .map((json) =>
//                   productBatchesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint(
//               '✅ Fetched ${_cachedProductBatches!.length} product batches');
//         } else {
//           debugPrint(
//               '❌ Failed to fetch product batches: ${response.statusCode}');
//         }
//       }

//       // Fetch batch sell units
//       if (_cachedBatchSellUnits == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/batchSellUnit'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedBatchSellUnits = jsonList
//               .map((json) =>
//                   batchSellUnitFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint(
//               '✅ Fetched ${_cachedBatchSellUnits!.length} batch sell units');
//         } else {
//           debugPrint(
//               '❌ Failed to fetch batch sell units: ${response.statusCode}');
//         }
//       }

//       // Fetch project sale transactions
//       if (_cachedServerProjectSaleTransactions == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse(
//                 'http://$_hostIp:8080/api/projectSaleTransactions/all'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerProjectSaleTransactions = jsonList
//               .map((json) => projectSaleTransactionFromJson(
//                   Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint(
//               '✅ Fetched ${_cachedServerProjectSaleTransactions!.length} project sale transactions');
//         } else {
//           debugPrint(
//               '❌ Failed to fetch project sale transactions: ${response.statusCode}');
//         }
//       }

//       // Fetch student payments
//       if (_cachedServerStudentPayments == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerStudentPayments = jsonList
//               .map((json) =>
//                   studentPaymentsFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint(
//               '✅ Fetched ${_cachedServerStudentPayments!.length} student payments');
//         } else {
//           debugPrint(
//               '❌ Failed to fetch student payments: ${response.statusCode}');
//         }
//       }

//       // Fetch users (for admin SMS)
//       if (_cachedServerUsers == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$_hostIp:8080/api/users'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonString = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonString) as List;
//           _cachedServerUsers = jsonList
//               .map((json) => usersFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//           debugPrint('✅ Fetched ${_cachedServerUsers!.length} users');
//         } else {
//           debugPrint('❌ Failed to fetch users: ${response.statusCode}');
//         }
//       }

//       // Populate local lists from cached data
//       _students = _cachedServerStudents ?? [];
//       _projects = _cachedServerProjects ?? [];
//       _items = _cachedServerProjectItems ?? [];
//       _selectedBatch = _cachedProductBatches ?? [];
//       _batchSellUnits = _cachedBatchSellUnits ?? [];

//       // Build terms map
//       if (_cachedServerTerms != null) {
//         _termsMap = {for (var t in _cachedServerTerms!) t.termId: t};
//         _terms =
//             _cachedServerTerms!.map((term) => term.termId).toSet().toList();
//       }

//       _isClientDataLoaded = true;

//       debugPrint('✅ Client data loaded successfully:');
//       debugPrint('  - Students: ${_students.length}');
//       debugPrint('  - Projects: ${_projects.length}');
//       debugPrint('  - Project Items: ${_items.length}');
//       debugPrint('  - Product Batches: ${_selectedBatch.length}');
//       debugPrint('  - Terms: ${_terms.length}');

//       setState(() {});
//     } catch (e) {
//       debugPrint('❌ Error fetching client data: $e');
//       _showDialog('Failed to load data from host. Please check connection.');
//     }
//   }

//   // ✅ Helper to wait for cached data in client mode
//   Future<void> _waitForCachedData() async {
//     int attempts = 0;
//     const maxAttempts = 20; // 2 seconds max wait

//     while (attempts < maxAttempts) {
//       if (_cachedServerStudents != null &&
//           _cachedServerStudentPaymentPurposes != null &&
//           _cachedServerTerms != null) {
//         _students = _cachedServerStudents!;
//         _projects = _cachedServerProjects!;
//         _items = _cachedServerProjectItems!;
//         _selectedBatch = _cachedProductBatches!;
//         _batchSellUnits = _cachedBatchSellUnits!;
//         break;
//       }
//       await Future.delayed(const Duration(milliseconds: 100));
//       attempts++;
//     }
//   }

//   Future<void> _fetchProjectSaleTransactions() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//       if (_role == DeviceRole.host) {
//         // HOST: Already have access to Hive box
//         return;
//       } else {
//         // CLIENT: Fetch from server
//         if (_hostIp!.isEmpty) {
//           return;
//         }

//         if (_cachedServerProjectSaleTransactions == null) {
//           final response = await HttpClient()
//               .getUrl(Uri.parse(
//                   'http://$_hostIp:8080/api/projectSaleTransactions/all'))
//               .then((req) => req.close());

//           if (response.statusCode == 200) {
//             final jsonString = await response.transform(utf8.decoder).join();
//             final jsonList = jsonDecode(jsonString) as List;

//             _cachedServerProjectSaleTransactions = jsonList
//                 .map((json) => projectSaleTransactionFromJson(
//                     Map<String, dynamic>.from(json)))
//                 .toList();
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ Error fetching project sale transactions: $e');
//     }
//   }

//   Future<void> _fetchProjectsFromServer() async {
//     try {
//       _role = await getDeviceRole();

//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<Project> allProjects = [];

//       if (_role == DeviceRole.host) {
//         //
//         // ------------------ HOST: Load users from local Hive ------------------
//         //
//         final projectBox = await Hive.openBox<Project>('projects');
//         allProjects = projectBox.values.toList();
//       } else {
//         //
//         // ------------------ CLIENT: Fetch users from host ------------------
//         //
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }

//         if (_cachedServerProjects != null) {
//           allProjects = _cachedServerProjects!;
//         } else {
//           final projectsResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/projects'))
//               .then((req) => req.close());

//           if (projectsResponse.statusCode == 200) {
//             final projectsJsonString =
//                 await projectsResponse.transform(utf8.decoder).join();

//             final projectsList = jsonDecode(projectsJsonString) as List;

//             _cachedServerProjects = projectsList
//                 .map(
//                     (json) => projectsFromJson(Map<String, dynamic>.from(json)))
//                 .toList();

//             allProjects = _cachedServerProjects!;
//           } else {
//             throw Exception(
//                 "Failed to load projects data from host. Status code: ${projectsResponse.statusCode}");
//           }
//         }
//       }

//       //
//       // ------------------ Populate lookup structures ------------------
//       //
//       if (allProjects.isNotEmpty) {
//         _projects = allProjects;
//         _projectsMap = {
//           for (var p in allProjects) int.tryParse(p.projectCode): p
//         };
//       } else {
//         _projects = [];
//         _projectsMap = {};
//       }

//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching projects: $error");
//       debugPrint(stack.toString());
//       setState(() {});
//     }
//   }

//   Future<void> _fetchProjectItemsFromServer() async {
//     try {
//       _role = await getDeviceRole();

//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<ProjectItem> allProjectItems = [];

//       if (_role == DeviceRole.host) {
//         //
//         // ------------------ HOST: Load users from local Hive ------------------
//         //
//         final projectItemBox = await Hive.openBox<ProjectItem>('projectItems');
//         allProjectItems = projectItemBox.values.toList();
//       } else {
//         //
//         // ------------------ CLIENT: Fetch users from host ------------------
//         //
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }

//         if (_cachedServerProjectItems != null) {
//           allProjectItems = _cachedServerProjectItems!;
//         } else {
//           final projectItemsResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/projectItems'))
//               .then((req) => req.close());

//           if (projectItemsResponse.statusCode == 200) {
//             final projectItemsJsonString =
//                 await projectItemsResponse.transform(utf8.decoder).join();

//             final projectItemsList = jsonDecode(projectItemsJsonString) as List;

//             _cachedServerProjectItems = projectItemsList
//                 .map((json) =>
//                     projectItemsFromJson(Map<String, dynamic>.from(json)))
//                 .toList();

//             allProjectItems = _cachedServerProjectItems!;
//           } else {
//             throw Exception(
//                 "Failed to load project items data from host. Status code: ${projectItemsResponse.statusCode}");
//           }
//         }
//       }

//       //
//       // ------------------ Populate lookup structures ------------------
//       //
//       if (allProjectItems.isNotEmpty) {
//         _items = allProjectItems;
//         _projectItemsMap = {
//           for (var p in allProjectItems)
//             int.tryParse(p.projectItemCode.toString()): p
//         };
//       } else {
//         _items = [];
//         _projectItemsMap = {};
//       }

//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching project items: $error");
//       debugPrint(stack.toString());
//       setState(() {});
//     }
//   }

//   Future<void> fetchProductBatch() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<ProductBatch> productBatches = [];

//       if (_role == DeviceRole.host) {
//         final productBatchBox =
//             await Hive.openBox<ProductBatch>('product_batches');

//         productBatches = productBatchBox.values.toList();
//       } else {
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }
//         if (_cachedProductBatches == null) {
//           final productBatchesResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/productBatches'))
//               .then((req) => req.close());

//           if (productBatchesResponse.statusCode == 200) {
//             final productBatchesJsonString =
//                 await productBatchesResponse.transform(utf8.decoder).join();

//             final productBatchesList =
//                 jsonDecode(productBatchesJsonString) as List;

//             _cachedProductBatches = productBatchesList
//                 .map((json) =>
//                     productBatchesFromJson(Map<String, dynamic>.from(json)))
//                 .toList();

//             productBatches = _cachedProductBatches!;
//           } else {
//             throw Exception("Failed to load product batches data from host.");
//           }
//         }

//         productBatches = _cachedProductBatches!;
//       }
//       if (productBatches.isNotEmpty) {
//         _selectedBatch = productBatches;
//         _productBatchMap = {
//           for (var p in productBatches) int.tryParse(p.batchCode.toString()): p
//         };
//       } else {
//         _selectedBatch = [];
//         _productBatchMap = {};
//       }

//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching initial data: $error");
//       debugPrint("🪵 Stacktrace: $stack");
//       setState(() {});
//     }
//   }

//   Future<void> fetchBatchSellUnit() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<BatchSellUnit> productBatchSellUnit = [];

//       if (_role == DeviceRole.host) {
//         final productBatchSellUnitBox =
//             await Hive.openBox<BatchSellUnit>('batch_sell_units');

//         productBatchSellUnit = productBatchSellUnitBox.values.toList();
//       } else {
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }
//         if (_cachedBatchSellUnits == null) {
//           final productBatchSellUnitResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/batchSellUnit'))
//               .then((req) => req.close());

//           if (productBatchSellUnitResponse.statusCode == 200) {
//             final productBatchSellJsonString =
//                 await productBatchSellUnitResponse
//                     .transform(utf8.decoder)
//                     .join();

//             final productBatchSellUnitList =
//                 jsonDecode(productBatchSellJsonString) as List;

//             _cachedBatchSellUnits = productBatchSellUnitList
//                 .map((json) =>
//                     batchSellUnitFromJson(Map<String, dynamic>.from(json)))
//                 .toList();

//             productBatchSellUnit = _cachedBatchSellUnits!;
//           } else {
//             throw Exception(
//                 "Failed to load product batch sell unit data from host.");
//           }
//         }

//         productBatchSellUnit = _cachedBatchSellUnits!;
//       }
//       if (productBatchSellUnit.isNotEmpty) {
//         _batchSellUnits = productBatchSellUnit;
//         _batchSellUnitMap = {
//           for (var p in productBatchSellUnit)
//             int.tryParse(p.sellUnitCode.toString()): p
//         };
//       } else {
//         _selectedBatch = [];
//         _batchSellUnitMap = {};
//       }

//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching initial data: $error");
//       debugPrint("🪵 Stacktrace: $stack");
//       setState(() {});
//     }
//   }

// // ✅ Load transaction data (works for both host and client)
//   Future<void> _loadTransactionData(ProjectSaleTransaction tx) async {
//     final role = await getDeviceRole();

//     if (role == DeviceRole.host) {
//       // Host mode: Direct Hive access
//       _student = Hive.box<Student>('students')
//           .values
//           .firstWhereOrNull((s) => s.studentIdNumber == tx.studentId);

//       _project = Hive.box<Project>('projects')
//           .values
//           .firstWhereOrNull((p) => p.projectCode == tx.projectCode);

//       _item = Hive.box<ProjectItem>('projectItems')
//           .values
//           .firstWhereOrNull((i) => i.projectItemCode == tx.projectItemCode);

//       _selectedBatches = Hive.box<ProductBatch>('product_batches')
//           .values
//           .firstWhereOrNull((b) => b.batchCode == tx.batchCode);

//       _selectedSellUnit = Hive.box<BatchSellUnit>('batch_sell_units')
//           .values
//           .firstWhereOrNull((u) => u.sellUnitCode == tx.sellUnitCode);
//     } else {
//       // Client mode: Search in cached data
//       _student = _cachedServerStudents
//           ?.firstWhereOrNull((s) => s.studentIdNumber == tx.studentId);

//       _project = await _findProjectInCacheOrServer(tx.projectCode);
//       _item = await _findItemInCacheOrServer(tx.projectItemCode);
//       _selectedBatches = await _findBatchInCacheOrServer(tx.batchCode);
//       _selectedSellUnit = await _findSellUnitInCacheOrServer(tx.sellUnitCode);
//     }

//     _quantity = tx.quantitySold;

//     setState(() {});
//   }

// // ✅ Helper to find project in cache or fetch from server
//   Future<Project?> _findProjectInCacheOrServer(String projectCode) async {
//     final role = await getDeviceRole();

//     if (role == DeviceRole.host) {
//       return Hive.box<Project>('projects')
//           .values
//           .firstWhereOrNull((p) => p.projectCode == projectCode);
//     }

//     // Client mode: First check if we have cached projects
//     if (_cachedServerProjects != null && _cachedServerProjects!.isNotEmpty) {
//       return _cachedServerProjects!
//           .firstWhereOrNull((p) => p.projectCode == projectCode);
//     }

//     // If not, try to fetch from server
//     final projects = await _fetchProjectsFromServerAndCache();
//     return projects.firstWhereOrNull((p) => p.projectCode == projectCode);
//   }

// // ✅ Helper to find item in cache or fetch from server
//   Future<ProjectItem?> _findItemInCacheOrServer(String itemCode) async {
//     final role = await getDeviceRole();

//     if (role == DeviceRole.host) {
//       return Hive.box<ProjectItem>('projectItems')
//           .values
//           .firstWhereOrNull((i) => i.projectItemCode == itemCode);
//     }

//     // Client mode: First check if we have cached project items
//     if (_cachedServerProjectItems != null &&
//         _cachedServerProjectItems!.isNotEmpty) {
//       return _cachedServerProjectItems!
//           .firstWhereOrNull((i) => i.projectItemCode == itemCode);
//     }

//     // If not, try to fetch from server
//     final items = await _fetchProjectItemsFromServerAndCache();
//     return items.firstWhereOrNull((i) => i.projectItemCode == itemCode);
//   }

// // ✅ Helper for batch lookup
//   Future<ProductBatch?> _findBatchInCacheOrServer(String batchCode) async {
//     final role = await getDeviceRole();

//     if (role == DeviceRole.host) {
//       return Hive.box<ProductBatch>('product_batches')
//           .values
//           .firstWhereOrNull((b) => b.batchCode == batchCode);
//     }

//     // Client mode: First check cached product batches
//     if (_cachedProductBatches != null && _cachedProductBatches!.isNotEmpty) {
//       return _cachedProductBatches!
//           .firstWhereOrNull((b) => b.batchCode == batchCode);
//     }

//     // If not, fetch from server
//     final batches = await _fetchProductBatchesFromServerAndCache();
//     return batches.firstWhereOrNull((b) => b.batchCode == batchCode);
//   }

// // ✅ Helper for sell unit lookup
//   Future<BatchSellUnit?> _findSellUnitInCacheOrServer(
//       String sellUnitCode) async {
//     final role = await getDeviceRole();

//     if (role == DeviceRole.host) {
//       return Hive.box<BatchSellUnit>('batch_sell_units')
//           .values
//           .firstWhereOrNull((u) => u.sellUnitCode == sellUnitCode);
//     }

//     // Client mode: First check cached batch sell units
//     if (_cachedBatchSellUnits != null && _cachedBatchSellUnits!.isNotEmpty) {
//       return _cachedBatchSellUnits!
//           .firstWhereOrNull((u) => u.sellUnitCode == sellUnitCode);
//     }

//     // If not, fetch from server
//     final sellUnits = await _fetchBatchSellUnitsFromServerAndCache();
//     return sellUnits.firstWhereOrNull((u) => u.sellUnitCode == sellUnitCode);
//   }

// // ✅ New methods that fetch and cache from server (client mode)
//   Future<List<Project>> _fetchProjectsFromServerAndCache() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(Uri.parse('http://$hostIp:8080/api/projects'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final jsonList = jsonDecode(jsonStr) as List;
//         final projects = jsonList
//             .map((json) => projectsFromJson(Map<String, dynamic>.from(json)))
//             .toList();

//         _cachedServerProjects = projects;
//         return projects;
//       }
//     } catch (e) {
//       debugPrint('Error fetching projects from server: $e');
//     }

//     return [];
//   }

//   Future<List<ProjectItem>> _fetchProjectItemsFromServerAndCache() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(Uri.parse('http://$hostIp:8080/api/projectItems'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final jsonList = jsonDecode(jsonStr) as List;
//         final items = jsonList
//             .map(
//                 (json) => projectItemsFromJson(Map<String, dynamic>.from(json)))
//             .toList();

//         _cachedServerProjectItems = items;
//         return items;
//       }
//     } catch (e) {
//       debugPrint('Error fetching project items from server: $e');
//     }

//     return [];
//   }

//   Future<List<ProductBatch>> _fetchProductBatchesFromServerAndCache() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(Uri.parse('http://$hostIp:8080/api/productBatches'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final jsonList = jsonDecode(jsonStr) as List;
//         final batches = jsonList
//             .map((json) =>
//                 productBatchesFromJson(Map<String, dynamic>.from(json)))
//             .toList();

//         _cachedProductBatches = batches;
//         return batches;
//       }
//     } catch (e) {
//       debugPrint('Error fetching product batches from server: $e');
//     }

//     return [];
//   }

//   Future<List<BatchSellUnit>> _fetchBatchSellUnitsFromServerAndCache() async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(Uri.parse('http://$hostIp:8080/api/batchSellUnit'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final jsonList = jsonDecode(jsonStr) as List;
//         final sellUnits = jsonList
//             .map((json) =>
//                 batchSellUnitFromJson(Map<String, dynamic>.from(json)))
//             .toList();

//         _cachedBatchSellUnits = sellUnits;
//         return sellUnits;
//       }
//     } catch (e) {
//       debugPrint('Error fetching batch sell units from server: $e');
//     }

//     return [];
//   }

// // ✅ Helper method to check if using server data
//   bool get isUsingServerData => _role == DeviceRole.client;

// // ✅ Method to refresh all data from server
//   Future<void> refreshFromServer() async {
//     if (_role == DeviceRole.client) {
//       await Future.wait([
//         fetchStudentPayments(),
//         fetchPaymentPurposes(),
//         fetchTerms(),
//         fetchUsers(),
//         _fetchProjectsFromServerAndCache(),
//         _fetchProjectItemsFromServerAndCache(),
//         _fetchProductBatchesFromServerAndCache(),
//         _fetchBatchSellUnitsFromServerAndCache(),
//       ]);

//       // Update local lists with cached data
//       if (_cachedServerProjects != null) {
//         _projects = _cachedServerProjects!;
//       }
//       if (_cachedServerProjectItems != null) {
//         _items = _cachedServerProjectItems!;
//       }
//       if (_cachedProductBatches != null) {
//         _selectedBatch = _cachedProductBatches!;
//       }
//       if (_cachedBatchSellUnits != null) {
//         _batchSellUnits = _cachedBatchSellUnits!;
//       }

//       setState(() {});
//     }
//   }

// // ✅ Single item fetchers (for individual lookups)
//   Future<Project?> _fetchSingleProjectFromServer(String projectCode) async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(Uri.parse('http://$hostIp:8080/api/projects/$projectCode'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final json = jsonDecode(jsonStr) as Map<String, dynamic>;
//         return projectsFromJson(json);
//       }
//     } catch (e) {
//       debugPrint('Error fetching single project: $e');
//     }

//     return null;
//   }

//   Future<ProjectItem?> _fetchSingleItemFromServer(String itemCode) async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(Uri.parse('http://$hostIp:8080/api/projectItems/$itemCode'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final json = jsonDecode(jsonStr) as Map<String, dynamic>;
//         return projectItemsFromJson(json);
//       }
//     } catch (e) {
//       debugPrint('Error fetching single item: $e');
//     }

//     return null;
//   }

//   Future<ProductBatch?> _fetchSingleBatchFromServer(String batchCode) async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(
//               Uri.parse('http://$hostIp:8080/api/productBatches/$batchCode'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final json = jsonDecode(jsonStr) as Map<String, dynamic>;
//         return productBatchesFromJson(json);
//       }
//     } catch (e) {
//       debugPrint('Error fetching single batch: $e');
//     }

//     return null;
//   }

//   Future<BatchSellUnit?> _fetchSingleSellUnitFromServer(
//       String sellUnitCode) async {
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     try {
//       final response = await HttpClient()
//           .getUrl(
//               Uri.parse('http://$hostIp:8080/api/batchSellUnit/$sellUnitCode'))
//           .then((req) => req.close());

//       if (response.statusCode == 200) {
//         final jsonStr = await response.transform(utf8.decoder).join();
//         final json = jsonDecode(jsonStr) as Map<String, dynamic>;
//         return batchSellUnitFromJson(json);
//       }
//     } catch (e) {
//       debugPrint('Error fetching single sell unit: $e');
//     }

//     return null;
//   }
//   // ✅ Update existing methods to use role-appropriate data access

//   Future<void> fetchUsers() async {
//     try {
//       _role = await getDeviceRole();

//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//       List<User> allUsers = [];

//       if (_role == DeviceRole.host) {
//         //
//         // ------------------ HOST: Load users from local Hive ------------------
//         //
//         final userBox = await Hive.openBox<User>('users');
//         allUsers = userBox.values.toList();
//       } else {
//         //
//         // ------------------ CLIENT: Fetch users from host ------------------
//         //
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }

//         if (_cachedServerUsers != null) {
//           allUsers = _cachedServerUsers!;
//         } else {
//           final usersResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/users'))
//               .then((req) => req.close());

//           if (usersResponse.statusCode == 200) {
//             final usersJsonString =
//                 await usersResponse.transform(utf8.decoder).join();

//             final usersList = jsonDecode(usersJsonString) as List;

//             _cachedServerUsers = usersList
//                 .map((json) => usersFromJson(Map<String, dynamic>.from(json)))
//                 .toList();

//             allUsers = _cachedServerUsers!;
//           } else {
//             throw Exception(
//                 "Failed to load users data from host. Status code: ${usersResponse.statusCode}");
//           }
//         }
//       }

//       //
//       // ------------------ Populate lookup structures ------------------
//       //
//       if (allUsers.isNotEmpty) {
//         _users = allUsers;
//         _usersMap = {for (var u in allUsers) u.id: u};
//       } else {
//         _users = [];
//         _usersMap = {};
//       }

//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching users: $error");
//       debugPrint(stack.toString());
//       setState(() {});
//     }
//   }

//   Future<void> fetchTerms() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<Terms> allTerms = [];

//       if (_role == DeviceRole.host) {
//         final termBox = await Hive.openBox<Terms>('terms');
//         allTerms = termBox.values.toList();
//       } else {
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }
//         if (_cachedServerTerms == null) {
//           final termsResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/terms'))
//               .then((req) => req.close());

//           if (termsResponse.statusCode == 200) {
//             final termsJsonString =
//                 await termsResponse.transform(utf8.decoder).join();
//             final termsList = jsonDecode(termsJsonString) as List;
//             _cachedServerTerms = termsList
//                 .map((json) => termsFromJson(Map<String, dynamic>.from(json)))
//                 .toList();
//           } else {
//             throw Exception("Failed to load terms data from host.");
//           }
//         }
//         allTerms = _cachedServerTerms!;
//       }

//       if (allTerms.isNotEmpty) {
//         // ✅ ONLY filter terms for teachers
//         if (_isTeacher()) {
//           // Only include terms with start date <= current month
//           final now = DateTime.now();
//           final currentMonth = DateTime(now.year, now.month, 1);

//           final validTerms = allTerms.where((term) {
//             final termStart =
//                 DateTime(term.startDate.year, term.startDate.month, 1);
//             return termStart.compareTo(currentMonth) <= 0;
//           }).toList();

//           _terms = validTerms.map((term) => term.termId).toSet().toList();
//           _termsMap = {for (var t in allTerms) t.termId: t};

//           // Auto-select valid terms for teachers
//           _selectedFilterTerms = _terms;
//         } else {
//           // ✅ Non-teachers see ALL terms
//           _terms = allTerms.map((term) => term.termId).toSet().toList();
//           _termsMap = {for (var t in allTerms) t.termId: t};
//           // Don't auto-filter for non-teachers
//         }

//         selectedTermId = _terms.contains(globalTermId)
//             ? globalTermId
//             : (_terms.isNotEmpty ? _terms.first : null);
//       } else {
//         _terms = [];
//         _termsMap = {};
//       }

//       setState(() {});
//     } catch (error) {
//       debugPrint("Error fetching initial data: $error");
//       setState(() {});
//     }
//   }

//   Future<void> fetchSchools() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<School> allSchools = [];

//       if (_role == DeviceRole.host) {
//         final box = await Hive.openBox<School>('school');
//         allSchools = box.values.toList();
//       } else {
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }
//         if (_cachedServerSchoolInfo == null) {
//           final schooResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/school'))
//               .then((req) => req.close());

//           if (schooResponse.statusCode == 200) {
//             final schoolsJsonString =
//                 await schooResponse.transform(utf8.decoder).join();

//             final schoolsList = jsonDecode(schoolsJsonString) as List;

//             _cachedServerSchoolInfo = schoolsList
//                 .map((json) => schoolFromJson(Map<String, dynamic>.from(json)))
//                 .toList();
//           } else {
//             throw Exception("Failed to load school data from host.");
//           }
//         }
//         allSchools = _cachedServerSchoolInfo!;
//       }

//       setState(() {}); // Refresh the UI
//     } catch (error) {
//       debugPrint("Error fetching initial data: $error");
//       setState(() {});
//     }
//   }

//   Future<void> fetchStudentsMetadata() async {
//     // Keep lightweight startup tasks here (e.g., counts, last sync timestamp)
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       // Optionally fetch small metadata endpoint like /api/students/summary
//     } catch (e) {
//       debugPrint('❌ fetchStudentsMetadata error: $e');
//     }
//   }

//   // ✅ UPDATED: fetchPaymentPurposes with proper client support
//   Future<void> fetchPaymentPurposes() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<PaymentPurpose> allStudentPaymentPurposes = [];

//       if (_role == DeviceRole.host) {
//         final paymentPurposeBox =
//             await Hive.openBox<PaymentPurpose>('payment_purposes');
//         allStudentPaymentPurposes = paymentPurposeBox.values.toList();
//       } else {
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }

//         if (_cachedServerStudentPaymentPurposes == null) {
//           final response = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
//               .then((req) => req.close());

//           if (response.statusCode == 200) {
//             final jsonStr = await response.transform(utf8.decoder).join();
//             final list = jsonDecode(jsonStr) as List;
//             _cachedServerStudentPaymentPurposes = list
//                 .map((json) =>
//                     paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//                 .toList();
//             debugPrint(
//                 '✅ Fetched ${_cachedServerStudentPaymentPurposes!.length} payment purposes from server');
//           } else {
//             debugPrint(
//                 '❌ Failed to fetch payment purposes: ${response.statusCode}');
//           }
//         }
//         allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
//       }
//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching payment purposes: $error");
//       debugPrint("🪵 Stacktrace: $stack");
//       setState(() {});
//     }
//   }

//   Future<void> fetchStudentPayments() async {
//     try {
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
//       List<StudentPayment> allStudentPayments = [];

//       if (_role == DeviceRole.host) {
//         final paymentBox =
//             await Hive.openBox<StudentPayment>('student_payments');

//         allStudentPayments = paymentBox.values.toList();
//       } else {
//         if (_hostIp!.isEmpty) {
//           _showDialog("⚠️ Host IP not set. Please configure connection.");
//           setState(() {});
//           return;
//         }
//         if (_cachedServerStudentPayments == null) {
//           final studentPaymentsResponse = await HttpClient()
//               .getUrl(Uri.parse('http://$_hostIp:8080/api/studentPayments'))
//               .then((req) => req.close());

//           if (studentPaymentsResponse.statusCode == 200) {
//             final studentPaymentsJsonString =
//                 await studentPaymentsResponse.transform(utf8.decoder).join();

//             final studentPaymentsList =
//                 jsonDecode(studentPaymentsJsonString) as List;

//             _cachedServerStudentPayments = studentPaymentsList
//                 .map((json) =>
//                     studentPaymentsFromJson(Map<String, dynamic>.from(json)))
//                 .toList();
//           } else {
//             throw Exception("Failed to load student Payments data from host.");
//           }
//         }

//         allStudentPayments = _cachedServerStudentPayments!;
//       }
//       setState(() {});
//     } catch (error, stack) {
//       debugPrint("❌ Error fetching initial data: $error");
//       debugPrint("🪵 Stacktrace: $stack");
//       setState(() {});
//     }
//   }

//   Future<School> _getSchoolInfo() async {
//     final role = await getDeviceRole();
//     final prefs = await SharedPreferences.getInstance();
//     final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//     if (role == DeviceRole.host) {
//       final schoolBox = await Hive.openBox<School>('school');
//       if (schoolBox.isNotEmpty) {
//         return schoolBox.values.first;
//       }
//     } else {
//       if (_cachedServerSchoolInfo == null) {
//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$hostIp:8080/api/school'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonStr = await response.transform(utf8.decoder).join();
//           final jsonList = jsonDecode(jsonStr) as List;
//           _cachedServerSchoolInfo = jsonList
//               .map((e) => schoolFromJson(Map<String, dynamic>.from(e)))
//               .toList();
//         } else {
//           throw Exception("❌ Failed to fetch school data from host.");
//         }
//       }

//       if (_cachedServerSchoolInfo != null &&
//           _cachedServerSchoolInfo!.isNotEmpty) {
//         return _cachedServerSchoolInfo!.first;
//       }
//     }

//     // Fallback default
//     return School(
//       schoolName: 'School Receipt',
//       schoolAddress: 'P.O.Box...',
//       schoolEmail: '@school.co.zw',
//       schoolPhoneNumber: '+263...',
//     );
//   }

//   Future<void> _sendSmsNotification(
//       String allPaymentsInfo, String? phone) async {
//     if (Platform.isAndroid) {
//       if (allPaymentsInfo.isEmpty) {
//         _showDialog('No payment made yet');
//         return;
//       }
//       final encodedBody = Uri.encodeComponent(allPaymentsInfo);

//       await launcher.launchUrl(
//         Uri.parse(
//           'sms:$phone${Platform.isAndroid ? '?' : '&'}body=$encodedBody',
//         ),
//       );
//     }
//   }

//   Future<void> sendSms(String allPaymentsInfoadminnew, String recipient) async {
//     if (Platform.isAndroid) {
//       var status = await Permission.sms.status;

//       if (!status.isGranted) {
//         var result = await Permission.sms.request();

//         if (!result.isGranted) {
//           _showDialog('SMS permission is not granted. Cannot send SMS.');
//           return;
//         }
//       }
//     }

//     try {
//       if (Platform.isAndroid) {
//         const int smsChunkLimit = 153; // Use 153 to allow concatenation headers

//         List<String> messageParts = [];
//         for (int i = 0;
//             i < allPaymentsInfoadminnew.length;
//             i += smsChunkLimit) {
//           int end = (i + smsChunkLimit < allPaymentsInfoadminnew.length)
//               ? i + smsChunkLimit
//               : allPaymentsInfoadminnew.length;
//           messageParts.add(allPaymentsInfoadminnew.substring(i, end));
//         }

//         for (int i = 0; i < messageParts.length; i++) {
//           String part = messageParts[i];
//           SmsStatus result = await BackgroundSms.sendMessage(
//             phoneNumber: recipient,
//             message: part,
//           );

//           await Future.delayed(
//               const Duration(milliseconds: 500)); // Delay to avoid issues
//         }
//       }
//     } catch (e) {
//       _showDialog('Error sending SMS: $e');
//     }
//   }

//   double _calculateArrearsForTerm({
//     required PaymentPurpose purpose,
//     required String termId,
//     required String purposeName,
//   }) {
//     // Use appropriate data source depending on role
//     final allPayments = _role == DeviceRole.host
//         ? Hive.box<StudentPayment>('student_payments').values
//         : (_cachedServerStudentPayments ?? []);

//     final allTerms = _role == DeviceRole.host
//         ? Hive.box<Terms>('terms').values
//         : (_cachedServerTerms ?? []);

//     // Total paid from Hive
//     final hivePaid = allPayments
//         .where((payment) =>
//             payment.studentName.toLowerCase() ==
//                 _selectedStudent!.name.toLowerCase() &&
//             payment.studentSurname.toLowerCase() ==
//                 _selectedStudent!.surname.toLowerCase() &&
//             payment.termId == termId &&
//             payment.paymentPurpose.toLowerCase() == purposeName.toLowerCase())
//         .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));

//     // Total paid in current session
//     final sessionPaid = _paymentPurposes
//         .where((p) =>
//             p['termId'] == termId &&
//             p['purpose'].paymentPurpose.toLowerCase() ==
//                 purposeName.toLowerCase())
//         .fold(0.0, (sum, p) => sum + (p['amount'] as double));

//     double totalPaid = hivePaid + sessionPaid;
//     double arrears = purpose.purposeAmount - totalPaid;

//     // Apply exception adjustment
//     arrears = getAdjustedArrear(
//       arrears,
//       _selectedStudent!,
//       purpose,
//       termId,
//     );

//     // Handle newcomer-only rule
//     if (purpose.forNewcomersOnly == true) {
//       if (_selectedStudent!.isNewComer != true) {
//         return 0.0;
//       }

//       final newcomerUntil = _selectedStudent!.isNewComerUntil;
//       final newcomerFrom = _selectedStudent!.isNewComerFrom;

//       if (newcomerUntil != null && newcomerFrom != null) {
//         try {
//           final term = allTerms.firstWhere(
//             (t) =>
//                 (t.termId?.trim().toLowerCase() ?? '') ==
//                 (purpose.termId?.trim().toLowerCase() ?? ''),
//           );
//           if (term.endDate != null) {
//             if (term.startDate.isAfter(newcomerUntil) ||
//                 term.endDate!.isBefore(newcomerFrom)) {
//               return 0.0;
//             }
//           }
//         } catch (_) {
//           return 0.0; // Term not found — skip
//         }
//       } else if (newcomerUntil != null) {
//         try {
//           final term = allTerms.firstWhere(
//             (t) =>
//                 (t.termId?.trim().toLowerCase() ?? '') ==
//                 (purpose.termId?.trim().toLowerCase() ?? ''),
//           );
//           if (term.startDate.isAfter(newcomerUntil)) {
//             return 0.0;
//           }
//         } catch (_) {
//           return 0.0; // Term not found — skip
//         }
//       } else {
//         return 0.0;
//       }
//     }

//     return arrears;
//   }

//   Future<School> _fetchSchoolInfo() async {
//     if (_role == DeviceRole.host) {
//       final box = await Hive.openBox<School>('school');
//       if (box.isNotEmpty) {
//         return box.values.first;
//       }
//     } else {
//       if (_cachedServerSchoolInfo != null &&
//           _cachedServerSchoolInfo!.isNotEmpty) {
//         return _cachedServerSchoolInfo!.first;
//       }
//     }

//     // Fallback if no valid data found
//     return School(
//       schoolName: 'School Receipt',
//       schoolAddress: 'P.O.Box....',
//       schoolEmail: '@school.co.zw',
//       schoolPhoneNumber: '+263.........',
//     );
//   }

//   bool deepMatchStudentWithInverse(Student s, String query) {
//     if (query.trim().isEmpty) return true;

//     final q = query.toLowerCase().trim();
//     final parts = q.split(RegExp(r'\s+'));

//     final name = (s.name ?? '').toLowerCase();
//     final surname = (s.surname ?? '').toLowerCase();
//     final fullName = ('$name $surname').trim();
//     final fullNameInverse = ('$surname $name').trim();
//     final idNum = (s.studentIdNumber ?? '').toLowerCase();
//     final classe = (s.class_ ?? '').toLowerCase();

//     final fields = [
//       name,
//       surname,
//       fullName,
//       fullNameInverse,
//       idNum,
//       classe,
//     ];

//     // Every search word must match *some* field
//     return parts.every((part) => fields.any((field) => field.contains(part)));
//   }

//   Future<void> _searchStudent(String query, {bool showDialog = false}) async {
//     try {
//       // Ensure we have role and host IP resolved
//       _role = await getDeviceRole();
//       final prefs = await SharedPreferences.getInstance();
//       _hostIp = prefs.getString('host_ip') ?? _hostIp;

//       List<Student> results = [];

//       if (_role == DeviceRole.host) {
//         // Host: local Hive query (fast)
//         final studentBox = await Hive.openBox<Student>('students');
//         results = studentBox.values
//             .where((s) => s.termId != null)
//             .where((s) => deepMatchStudentWithInverse(s, query))
//             .toList();
//       } else {
//         // Client: check per-query cache first
//         final cached = _studentsCache[query];
//         if (cached != null && cached.isValid) {
//           results = cached.students;
//         } else {
//           if (_hostIp == null || _hostIp!.isEmpty) {
//             _showDialog('⚠️ Host IP not set. Please configure connection.');
//             return;
//           }

//           final uri = Uri.parse(
//               'http://$_hostIp:8080/api/students?search=${Uri.encodeQueryComponent(query)}');
//           final request = await HttpClient().getUrl(uri);
//           final response = await request.close();

//           if (response.statusCode == 200) {
//             final body = await response.transform(utf8.decoder).join();
//             final parsed = jsonDecode(body) as List<dynamic>;

//             results = parsed
//                 .map(
//                     (json) => studentsFromJson(Map<String, dynamic>.from(json)))
//                 .toList();

//             // store in cache for short time (30 seconds)
//             _studentsCache[query] = _CachedStudents(
//                 results, DateTime.now().add(const Duration(seconds: 30)));
//           } else {
//             _showDialog(
//                 '⚠️ Failed to fetch students from host (${response.statusCode})');
//             return;
//           }
//         }
//       }

//       if (results.isEmpty) {
//         if (showDialog) _showDialog('No matching students found for: "$query"');
//       } else {
//         if (showDialog) _displayStudentSelectionDialog(results);
//       }
//     } catch (e, st) {
//       _showDialog('⚠️ Error searching students.');
//     }
//   }

//   void _displayStudentSelectionDialog(List<Student> students) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Select a Student'),
//           content: SizedBox(
//             height: 200,
//             width: 200,
//             child: ListView.builder(
//               itemCount: students.length,
//               itemBuilder: (context, index) {
//                 final student = students[index];
//                 return ListTile(
//                   title: Text(capitalize('${student.name} ${student.surname}')),
//                   subtitle: Text(capitalize('Class: ${student.class_}')),
//                   onTap: () {
//                     setState(() {
//                       _selectedStudent = student;
//                       _resetPaymentData(); // ← Clear all previous payment data

//                       _totalArrearsFuture =
//                           _computeTotalStudentArrears(student);

//                       // ✅ Clear all selections and payment data
//                       _selectedPaymentPurpose = null;
//                       _selectedArrearsTerm = null;
//                       _paymentInfo = '';
//                       _paymentInfo11 = '';
//                       _paymentInfo1 = '';
//                       _paymentInfo2 = '';
//                       _paymentPurposes.clear(); // Clear added payment items
//                       _selectedSubPurposes
//                           .clear(); // ← CRITICAL: Clear checkbox selections
//                       _paymentAmountController.clear();
//                       _paymentAmount = null;
//                       _pmAmountCtrl.clear();
//                     });
//                     Navigator.pop(context);
//                   },
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

// // Helper method to build info row (without font parameter)
//   pw.Widget _buildInfoRow(String label, String value) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 4),
//       child: pw.Row(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Container(
//             width: 120,
//             child: pw.Text(
//               '$label:',
//               style: pw.TextStyle(
//                 fontWeight: pw.FontWeight.bold,
//               ),
//             ),
//           ),
//           pw.Expanded(
//             child: pw.Text(value),
//           ),
//         ],
//       ),
//     );
//   }

// // Helper method to build amount row (without font parameter)
//   pw.Widget _buildAmountRow(
//     String label,
//     double amount, {
//     PdfColor color = PdfColors.black,
//     bool isBold = false,
//     double fontSize = 14,
//   }) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 6),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text(
//             label,
//             style: pw.TextStyle(
//               fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
//               fontSize: fontSize,
//             ),
//           ),
//           pw.Text(
//             '\$${amount.toStringAsFixed(2)}',
//             style: pw.TextStyle(
//               fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
//               fontSize: fontSize,
//               color: color,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

// // Helper method to build table cell (no changes needed)
//   pw.Widget _buildTableCell(
//     String text, {
//     bool isHeader = false,
//     pw.Alignment alignment = pw.Alignment.centerLeft,
//   }) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(8),
//       alignment: alignment,
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
//           fontSize: isHeader ? 12 : 11,
//         ),
//       ),
//     );
//   }

//   Future<void> _generateMultiPagePdf(List<Student> students) async {
//     if (students.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No students to generate PDF for')),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(child: CircularProgressIndicator()),
//     );

//     try {
//       final pdf = pw.Document();
//       final schoolInfo = await _fetchSchoolInfo();
//       final loggedInUser = getLoggedInUser();
//       final username = loggedInUser?.username ?? 'Unknown User';

//       // Load all arrears data for all students
//       final Map<String, dynamic> studentArrearsData = {};
//       for (var student in students) {
//         final originalSelectedStudent = _selectedStudent;
//         _selectedStudent = student;

//         final purposeList =
//             await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
//                 student);
//         final feesArrears = await _computeTotalStudentArrears(student);
//         final studentId = student.studentIdNumber.toString();
//         final projectArrearsDetails = buildStudentArrearsDetails(studentId);
//         final totalProjectArrears =
//             projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);

//         studentArrearsData[student.studentIdNumber.toString()] = {
//           'purposeList': purposeList,
//           'feesArrears': feesArrears,
//           'projectArrearsDetails': projectArrearsDetails,
//           'totalProjectArrears': totalProjectArrears,
//           'grandTotal': (feesArrears ?? 0) + totalProjectArrears,
//           'student': student,
//         };

//         _selectedStudent = originalSelectedStudent;
//       }

//       // Add each student on a separate page
//       for (int i = 0; i < students.length; i++) {
//         final student = students[i];
//         final data = studentArrearsData[student.studentIdNumber.toString()];

//         pdf.addPage(
//           pw.Page(
//             pageFormat: PdfPageFormat.a4,
//             margin: const pw.EdgeInsets.all(20),
//             build: (context) {
//               // Build the column children list explicitly
//               final List<pw.Widget> columnChildren = [];

//               // Add header
//               columnChildren
//                   .add(_buildPdfHeader(schoolInfo, i + 1, students.length));

//               // Add student content widgets
//               final studentContent = _buildStudentContent(student, data);
//               columnChildren.addAll(studentContent);

//               // Add footer
//               columnChildren.add(_buildPdfFooter(username));

//               return pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: columnChildren,
//               );
//             },
//           ),
//         );
//       }

//       final pdfBytes = await pdf.save();

//       if (mounted) Navigator.pop(context);

//       // Show PDF preview dialog
//       await showDialog(
//         context: context,
//         builder: (context) => Dialog(
//           insetPadding: EdgeInsets.zero,
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.95,
//             height: MediaQuery.of(context).size.height * 0.95,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Column(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                     borderRadius: const BorderRadius.only(
//                       topLeft: Radius.circular(12),
//                       topRight: Radius.circular(12),
//                     ),
//                     border: Border(
//                       bottom: BorderSide(color: Colors.grey.shade300),
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'PDF Preview - ${students.length} Students',
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.close),
//                         onPressed: () => Navigator.pop(context),
//                         tooltip: 'Close',
//                       ),
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   child: PdfPreview(
//                     build: (format) => pdfBytes,
//                     allowPrinting: true,
//                     allowSharing: true,
//                     initialPageFormat: PdfPageFormat.a4,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     } catch (e) {
//       if (mounted) Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error generating PDF: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   List<pw.Widget> _buildStudentContent(Student student, dynamic arrearsData) {
//     final purposeList = arrearsData?['purposeList'] ?? [];
//     final feesArrears = arrearsData?['feesArrears'] ?? 0.0;
//     final projectArrearsDetails = arrearsData?['projectArrearsDetails'] ?? [];
//     final totalProjectArrears = arrearsData?['totalProjectArrears'] ?? 0.0;
//     final grandTotal = arrearsData?['grandTotal'] ?? 0.0;

//     final List<pw.Widget> containerChildren = [];

//     // Student Header
//     containerChildren.add(
//       pw.Container(
//         padding: const pw.EdgeInsets.all(10),
//         decoration: pw.BoxDecoration(
//           color: PdfColors.blue100,
//           borderRadius: pw.BorderRadius.circular(5),
//         ),
//         child: pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Text(
//               '${student.name} ${student.surname}',
//               style: pw.TextStyle(
//                 fontSize: 16,
//                 fontWeight: pw.FontWeight.bold,
//               ),
//             ),
//             pw.Text(
//               'ID: ${student.studentIdNumber}',
//               style: const pw.TextStyle(fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );

//     containerChildren.add(pw.SizedBox(height: 10));

//     // Student Info
//     containerChildren.add(
//       pw.Row(
//         children: [
//           pw.Expanded(
//             child: pw.Text('Class: ${student.class_ ?? "N/A"}'),
//           ),
//           pw.Expanded(
//             child: pw.Text('Phone: ${student.phoneNumber ?? "N/A"}'),
//           ),
//         ],
//       ),
//     );

//     containerChildren.add(pw.Divider());
//     containerChildren.add(pw.SizedBox(height: 10));

//     // Fees Arrears Section
//     containerChildren.add(
//       pw.Text(
//         'Fees Arrears:',
//         style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//       ),
//     );
//     containerChildren.add(pw.SizedBox(height: 5));

//     if (purposeList.isNotEmpty) {
//       for (var entry in purposeList) {
//         containerChildren.add(
//           pw.Padding(
//             padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
//             child: pw.Text(
//               '• ${entry['purpose'].paymentPurpose}: ${entry['arrearsPreview']}',
//               style: const pw.TextStyle(fontSize: 11),
//             ),
//           ),
//         );
//       }
//     }

//     containerChildren.add(pw.SizedBox(height: 5));
//     containerChildren.add(
//       pw.Text(
//         'Total Fees Arrears: \$${feesArrears.toStringAsFixed(2)}',
//         style: pw.TextStyle(
//           fontWeight: pw.FontWeight.bold,
//           color: PdfColors.red,
//         ),
//       ),
//     );

//     // Project Arrears Section
//     if (projectArrearsDetails.isNotEmpty) {
//       containerChildren.add(pw.SizedBox(height: 10));
//       containerChildren.add(
//         pw.Text(
//           'Project Arrears:',
//           style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//         ),
//       );
//       containerChildren.add(pw.SizedBox(height: 5));

//       for (var detail in projectArrearsDetails) {
//         containerChildren.add(
//           pw.Padding(
//             padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
//             child: pw.Text(
//               '• ${detail.projectName}: \$${detail.arrears.toStringAsFixed(2)}',
//               style: const pw.TextStyle(fontSize: 11),
//             ),
//           ),
//         );
//       }

//       containerChildren.add(pw.SizedBox(height: 5));
//       containerChildren.add(
//         pw.Text(
//           'Total Project Arrears: \$${totalProjectArrears.toStringAsFixed(2)}',
//           style: pw.TextStyle(
//             fontWeight: pw.FontWeight.bold,
//             color: PdfColors.orange,
//           ),
//         ),
//       );
//     }

//     containerChildren.add(pw.Divider());

//     // Grand Total
//     containerChildren.add(
//       pw.Container(
//         alignment: pw.Alignment.centerRight,
//         child: pw.Text(
//           'GRAND TOTAL: \$${grandTotal.toStringAsFixed(2)}',
//           style: pw.TextStyle(
//             fontSize: 14,
//             fontWeight: pw.FontWeight.bold,
//             color: PdfColors.red,
//           ),
//         ),
//       ),
//     );

//     // Return a single Container with the Column inside
//     final List<pw.Widget> result = [];
//     result.add(pw.SizedBox(height: 10));
//     result.add(
//       pw.Container(
//         padding: const pw.EdgeInsets.all(15),
//         decoration: pw.BoxDecoration(
//           border: pw.Border.all(color: PdfColors.grey300),
//           borderRadius: pw.BorderRadius.circular(10),
//         ),
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: containerChildren,
//         ),
//       ),
//     );

//     return result;
//   }

//   Future<void> _generateSummarizedPdf(List<Student> students) async {
//     if (students.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('No students to generate summary PDF for')),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text('Generating Summary Report...'),
//           ],
//         ),
//       ),
//     );

//     try {
//       final pdf = pw.Document();
//       final schoolInfo = await _fetchSchoolInfo();
//       final loggedInUser = getLoggedInUser();
//       final username = loggedInUser?.username ?? 'Unknown User';

//       // Collect arrears data for all students
//       final List<Map<String, dynamic>> studentData = [];
//       double totalArrears = 0.0;

//       for (var student in students) {
//         final originalSelectedStudent = _selectedStudent;
//         _selectedStudent = student;

//         final feesArrears = await _computeTotalStudentArrears(student);
//         final studentId = student.studentIdNumber.toString();
//         final projectArrearsDetails = buildStudentArrearsDetails(studentId);
//         final totalProjectArrears =
//             projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);
//         final grandTotal = feesArrears + totalProjectArrears;

//         studentData.add({
//           'student': student,
//           'arrears': grandTotal,
//           'feesArrears': feesArrears,
//           'projectArrears': totalProjectArrears,
//         });
//         totalArrears += grandTotal;

//         _selectedStudent = originalSelectedStudent;
//       }

//       // Sort alphabetically by surname
//       studentData.sort((a, b) {
//         final surnameA = (a['student'] as Student).surname?.toLowerCase() ?? '';
//         final surnameB = (b['student'] as Student).surname?.toLowerCase() ?? '';
//         return surnameA.compareTo(surnameB);
//       });

//       // Split into cleared (arrears == 0) and with arrears (arrears > 0)
//       final clearedStudents =
//           studentData.where((d) => d['arrears'] == 0).toList();
//       final arrearsStudents =
//           studentData.where((d) => d['arrears'] > 0).toList();

//       // Sort arrears students by amount (highest first)
//       arrearsStudents.sort((a, b) => b['arrears'].compareTo(a['arrears']));

//       // Calculate how many rows fit per page (leaving room for header, stats, etc.)
//       const int rowsPerPage = 25; // Adjust based on your needs

//       // Build pages
//       int pageNumber = 1;
//       int totalPages = 0;

//       // Calculate total pages needed
//       final clearedPages = (clearedStudents.length / rowsPerPage).ceil();
//       final arrearsPages = (arrearsStudents.length / rowsPerPage).ceil();
//       totalPages = clearedPages + arrearsPages;
//       if (totalPages == 0) totalPages = 1;

//       // Inside _generateSummarizedPdf method, update the addSummaryPage function:

//       void addSummaryPage({
//         required String title,
//         required Color titleColor,
//         required List<Map<String, dynamic>> data,
//         required int startIndex,
//         required int pageNum,
//         required int totalPages,
//         required int totalStudents,
//         required int clearedCount,
//         required double totalArrears,
//         required bool showStats,
//         required School schoolInfo,
//         required String username,
//         required List<String> terms, // Add this parameter
//       }) {
//         final endIndex = (startIndex + rowsPerPage > data.length)
//             ? data.length
//             : startIndex + rowsPerPage;
//         final pageData = data.sublist(startIndex, endIndex);

//         pdf.addPage(
//           pw.Page(
//             pageFormat: PdfPageFormat.a4,
//             margin: const pw.EdgeInsets.all(20),
//             build: (context) {
//               return pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   // Header
//                   _buildSummaryPdfHeader(
//                     schoolInfo,
//                     totalStudents,
//                     totalArrears,
//                     pageNum,
//                     totalPages,
//                     terms, // Pass the terms
//                   ),
//                   pw.SizedBox(height: 8),

//                   // Show stats only on first page
//                   if (showStats) ...[
//                     _buildSummaryStats(
//                         totalStudents, clearedCount, totalArrears),
//                     pw.SizedBox(height: 12),
//                   ],

//                   // Section Title
//                   pw.Text(
//                     '$title (${data.length})',
//                     style: pw.TextStyle(
//                       fontSize: 14,
//                       fontWeight: pw.FontWeight.bold,
//                       color: titleColor == Colors.green
//                           ? PdfColors.green
//                           : PdfColors.red,
//                     ),
//                   ),
//                   pw.SizedBox(height: 6),

//                   // Table
//                   _buildStudentSummaryTable(pageData, startIndex),
//                   pw.SizedBox(height: 10),

//                   // Footer
//                   pw.Divider(thickness: 1),
//                   pw.SizedBox(height: 6),
//                   _buildPdfFooter(username),
//                 ],
//               );
//             },
//           ),
//         );
//       }

//       // Add Cleared Students pages
//       int currentPage = 1;
//       bool showStats = true;

//       // For Cleared Students:
//       if (clearedStudents.isNotEmpty) {
//         for (int i = 0; i < clearedStudents.length; i += rowsPerPage) {
//           addSummaryPage(
//             title: 'SECTION 1: CLEARED STUDENTS',
//             titleColor: Colors.green,
//             data: clearedStudents,
//             startIndex: i,
//             pageNum: currentPage,
//             totalPages: totalPages,
//             totalStudents: students.length,
//             clearedCount: clearedStudents.length,
//             totalArrears: totalArrears,
//             showStats: showStats,
//             schoolInfo: schoolInfo,
//             username: username,
//             terms: _selectedFilterTerms.isNotEmpty
//                 ? _selectedFilterTerms
//                 : _terms, // Pass the terms
//           );
//           currentPage++;
//           showStats = false;
//         }
//       }

// // For Students With Arrears:
//       if (arrearsStudents.isNotEmpty) {
//         showStats = true;

//         for (int i = 0; i < arrearsStudents.length; i += rowsPerPage) {
//           addSummaryPage(
//             title: 'SECTION 2: STUDENTS WITH ARREARS',
//             titleColor: Colors.red,
//             data: arrearsStudents,
//             startIndex: i,
//             pageNum: currentPage,
//             totalPages: totalPages,
//             totalStudents: students.length,
//             clearedCount: clearedStudents.length,
//             totalArrears: totalArrears,
//             showStats: showStats,
//             schoolInfo: schoolInfo,
//             username: username,
//             terms: _selectedFilterTerms.isNotEmpty
//                 ? _selectedFilterTerms
//                 : _terms, // Pass the terms
//           );
//           currentPage++;
//           showStats = false;
//         }
//       }

//       final pdfBytes = await pdf.save();

//       if (mounted) Navigator.pop(context);

//       // Show PDF preview
//       await showDialog(
//         context: context,
//         builder: (context) => Dialog(
//           insetPadding: EdgeInsets.zero,
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.95,
//             height: MediaQuery.of(context).size.height * 0.95,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Column(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                     borderRadius: const BorderRadius.only(
//                       topLeft: Radius.circular(12),
//                       topRight: Radius.circular(12),
//                     ),
//                     border: Border(
//                       bottom: BorderSide(color: Colors.grey.shade300),
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Summary Report - ${students.length} Students',
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Row(
//                         children: [
//                           IconButton(
//                             icon: const Icon(Icons.picture_as_pdf,
//                                 color: Colors.red),
//                             onPressed: () async {
//                               // Save or share PDF
//                               final bytes = await pdf.save();
//                               // Implement save/share functionality
//                             },
//                             tooltip: 'Save PDF',
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.close),
//                             onPressed: () => Navigator.pop(context),
//                             tooltip: 'Close',
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   child: PdfPreview(
//                     build: (format) => pdfBytes,
//                     allowPrinting: true,
//                     allowSharing: true,
//                     initialPageFormat: PdfPageFormat.a4,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     } catch (e) {
//       if (mounted) Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error generating summary PDF: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   pw.Widget _buildSummaryPdfHeader(
//     School schoolInfo,
//     int totalStudents,
//     double totalArrears,
//     int pageNum,
//     int totalPages,
//     List<String> terms, // Add this parameter
//   ) {
//     // Format the terms list for display
//     final bool isAdmin = _isAdminUser();

//     final sortedTerms = _sortTermsChronologically(terms);

//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.center,
//       children: [
//         pw.Text(
//           schoolInfo.schoolName?.toUpperCase() ?? 'SCHOOL NAME',
//           style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
//         ),
//         pw.SizedBox(height: 4),
//         pw.Text(schoolInfo.schoolAddress ?? 'Address'),
//         pw.Text(schoolInfo.schoolPhoneNumber ?? ''),
//         pw.SizedBox(height: 8),
//         pw.Text(
//           'STUDENT ARREARS SUMMARY REPORT',
//           style: pw.TextStyle(
//             fontSize: 16,
//             fontWeight: pw.FontWeight.bold,
//             decoration: pw.TextDecoration.underline,
//           ),
//         ),
//         pw.SizedBox(height: 4),
//         pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.center,
//           children: [
//             pw.Text('Total Students: $totalStudents'),
//             pw.SizedBox(width: 20),
//             if (isAdmin) ...[
//               pw.Text('Total Arrears: \$${totalArrears.toStringAsFixed(2)}'),
//             ],
//           ],
//         ),
//         pw.SizedBox(height: 4),
//         pw.Container(
//           padding: const pw.EdgeInsets.symmetric(horizontal: 10),
//           constraints: const pw.BoxConstraints(maxWidth: 500),
//           child: pw.Wrap(
//             alignment: pw.WrapAlignment.center,
//             spacing: 4,
//             runSpacing: 2,
//             children: [
//               pw.Text(
//                 'Terms: ',
//                 style: pw.TextStyle(
//                     fontSize: 9,
//                     color: PdfColors.grey,
//                     fontWeight: pw.FontWeight.bold),
//               ),
//               ...sortedTerms
//                   .map((term) => pw.Text(
//                         term,
//                         style: const pw.TextStyle(
//                             fontSize: 9, color: PdfColors.grey),
//                       ))
//                   .toList(),
//             ],
//           ),
//         ),
//         pw.SizedBox(height: 4),
//         pw.Text(
//           'Page $pageNum of $totalPages',
//           style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
//         ),
//       ],
//     );
//   }

//   pw.Widget _buildStudentSummaryTable(
//       List<Map<String, dynamic>> data, int startIndex) {
//     if (data.isEmpty) {
//       return pw.Text('No students in this category.',
//           style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey));
//     }

//     return pw.Table(
//       border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
//       columnWidths: {
//         0: const pw.FixedColumnWidth(25), // #
//         1: const pw.FixedColumnWidth(70), // Surname
//         2: const pw.FixedColumnWidth(70), // Name
//         3: const pw.FixedColumnWidth(40), // Gender
//         4: const pw.FixedColumnWidth(65), // Arrears
//         5: const pw.FixedColumnWidth(100), // Parent Phone
//       },
//       children: [
//         // Header
//         pw.TableRow(
//           decoration: pw.BoxDecoration(color: PdfColors.grey300),
//           children: [
//             _buildSummaryTableCell('№', isHeader: true),
//             _buildSummaryTableCell('Surname', isHeader: true),
//             _buildSummaryTableCell('Name', isHeader: true),
//             _buildSummaryTableCell('Gender', isHeader: true),
//             _buildSummaryTableCell('Arrears',
//                 isHeader: true, alignment: pw.Alignment.centerRight),
//             _buildSummaryTableCell('Parent Phone', isHeader: true),
//           ],
//         ),
//         // Rows
//         ...data.asMap().entries.map((entry) {
//           final index = entry.key;
//           final item = entry.value;
//           final student = item['student'] as Student;
//           final arrears = item['arrears'] as double;
//           final isEven = index % 2 == 0;

//           return pw.TableRow(
//             decoration: pw.BoxDecoration(
//               color: isEven ? PdfColors.grey50 : PdfColors.white,
//             ),
//             children: [
//               _buildSummaryTableCell('${startIndex + index + 1}'),
//               _buildSummaryTableCell(student.surname ?? ''),
//               _buildSummaryTableCell(student.name ?? ''),
//               _buildSummaryTableCell(student.gender ?? ''),
//               _buildSummaryTableCell(
//                 '\$${arrears.toStringAsFixed(2)}',
//                 alignment: pw.Alignment.centerRight,
//                 textColor: arrears > 0 ? PdfColors.red : PdfColors.green,
//               ),
//               _buildSummaryTableCell(student.phoneNumber ?? ''),
//             ],
//           );
//         }).toList(),
//       ],
//     );
//   }

//   pw.Widget _buildSummaryTableCell(
//     String text, {
//     bool isHeader = false,
//     pw.Alignment alignment = pw.Alignment.centerLeft,
//     PdfColor textColor = PdfColors.black,
//   }) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(4),
//       alignment: alignment,
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
//           fontSize: isHeader ? 10 : 9,
//           color: textColor,
//         ),
//         textAlign: alignment == pw.Alignment.centerRight
//             ? pw.TextAlign.right
//             : alignment == pw.Alignment.center
//                 ? pw.TextAlign.center
//                 : pw.TextAlign.left,
//       ),
//     );
//   }

//   bool _isAdminUser() {
//     final loggedInUser = getLoggedInUser();
//     if (loggedInUser == null) return false;

//     final role = loggedInUser.role?.toLowerCase() ?? '';
//     return role == 'admin' || role == 'administration';
//   }

// // Build summary stats widget
//   pw.Widget _buildSummaryStats(
//       int totalStudents, int clearedCount, double totalArrears) {
//     final withArrears = totalStudents - clearedCount;
//     final bool isAdmin = _isAdminUser(); // Define isAdmin here

//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
//       children: [
//         pw.Container(
//           padding: const pw.EdgeInsets.all(10),
//           decoration: pw.BoxDecoration(
//             color: PdfColors.green100,
//             borderRadius: pw.BorderRadius.circular(8),
//           ),
//           child: pw.Column(
//             children: [
//               pw.Text(
//                 'Cleared',
//                 style: pw.TextStyle(fontSize: 12, color: PdfColors.green700),
//               ),
//               pw.Text(
//                 clearedCount.toString(),
//                 style: pw.TextStyle(
//                     fontSize: 24,
//                     fontWeight: pw.FontWeight.bold,
//                     color: PdfColors.green700),
//               ),
//             ],
//           ),
//         ),
//         pw.Container(
//           padding: const pw.EdgeInsets.all(10),
//           decoration: pw.BoxDecoration(
//             color: PdfColors.red100,
//             borderRadius: pw.BorderRadius.circular(8),
//           ),
//           child: pw.Column(
//             children: [
//               pw.Text(
//                 'With Arrears',
//                 style: pw.TextStyle(fontSize: 12, color: PdfColors.red700),
//               ),
//               pw.Text(
//                 withArrears.toString(),
//                 style: pw.TextStyle(
//                     fontSize: 24,
//                     fontWeight: pw.FontWeight.bold,
//                     color: PdfColors.red700),
//               ),
//             ],
//           ),
//         ),
//         // CONDITIONAL: Only show Total Arrears if user is admin
//         if (isAdmin)
//           pw.Container(
//             padding: const pw.EdgeInsets.all(10),
//             decoration: pw.BoxDecoration(
//               color: PdfColors.blue100,
//               borderRadius: pw.BorderRadius.circular(8),
//             ),
//             child: pw.Column(
//               children: [
//                 pw.Text(
//                   'Total Arrears',
//                   style: pw.TextStyle(fontSize: 12, color: PdfColors.blue700),
//                 ),
//                 pw.Text(
//                   '\$${totalArrears.toStringAsFixed(2)}',
//                   style: pw.TextStyle(
//                       fontSize: 24,
//                       fontWeight: pw.FontWeight.bold,
//                       color: PdfColors.blue700),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

// // Helper method to sort terms chronologically
//   List<String> _sortTermsChronologically(List<String> terms) {
//     // Parse term strings and sort by year, then month
//     final monthOrder = {
//       'january': 1,
//       'february': 2,
//       'march': 3,
//       'april': 4,
//       'may': 5,
//       'june': 6,
//       'july': 7,
//       'august': 8,
//       'september': 9,
//       'october': 10,
//       'november': 11,
//       'december': 12,
//     };

//     // Extract year and month from term string
//     List<Map<String, dynamic>> parsedTerms = [];
//     for (var term in terms) {
//       // Try to extract year and month
//       final yearMatch = RegExp(r'(\d{4})').firstMatch(term);
//       final monthMatch =
//           RegExp(r'\((\w+)\)', caseSensitive: false).firstMatch(term);

//       int year = yearMatch != null ? int.parse(yearMatch.group(1)!) : 0;
//       int month = 0;

//       if (monthMatch != null) {
//         final monthName = monthMatch.group(1)!.toLowerCase();
//         month = monthOrder[monthName] ?? 0;
//       } else {
//         // Try to extract term number if no month
//         final termNumMatch =
//             RegExp(r'Term\s+(\d+)', caseSensitive: false).firstMatch(term);
//         if (termNumMatch != null) {
//           // Default months based on term number (approximate)
//           final termNum = int.parse(termNumMatch.group(1)!);
//           month = (termNum - 1) * 3 +
//               1; // Term 1 -> Jan, Term 2 -> Apr, Term 3 -> Jul, Term 4 -> Oct
//         }
//       }

//       parsedTerms.add({
//         'term': term,
//         'year': year,
//         'month': month,
//       });
//     }

//     // Sort by year, then month
//     parsedTerms.sort((a, b) {
//       if (a['year'] != b['year']) return a['year'].compareTo(b['year']);
//       return a['month'].compareTo(b['month']);
//     });

//     return parsedTerms.map((e) => e['term'] as String).toList();
//   }

// // Add this method to your state class
//   bool _hasFiltersApplied() {
//     // Check if any filters are active
//     // This checks if cachedFilteredStudents is different from all students
//     // or if any students are selected
//     if (_cachedFilteredStudents != null) {
//       // Check if filtered students list is different from full list
//       final allStudents = _students;
//       final filteredStudents = _cachedFilteredStudents!;

//       // If the lists have different lengths, filters are applied
//       if (allStudents.length != filteredStudents.length) {
//         return true;
//       }

//       // Check if the lists contain different students (order might differ)
//       final allIds = allStudents.map((s) => s.studentIdNumber).toSet();
//       final filteredIds =
//           filteredStudents.map((s) => s.studentIdNumber).toSet();
//       if (!allIds.containsAll(filteredIds) ||
//           !filteredIds.containsAll(allIds)) {
//         return true;
//       }
//     }

//     // Also check if students are selected (this is a form of filtering)
//     final selectedStudents = _getSelectedStudents();
//     if (selectedStudents.isNotEmpty &&
//         selectedStudents.length < _students.length) {
//       return true;
//     }

//     // No filters applied
//     return false;
//   }

// // Full student PDF section with arrears details
//   List<pw.Widget> _buildFullStudentPdfSection(
//       Student student, dynamic arrearsData) {
//     final purposeList = arrearsData?['purposeList'] ?? [];
//     final feesArrears = arrearsData?['feesArrears'] ?? 0.0;
//     final projectArrearsDetails = arrearsData?['projectArrearsDetails'] ?? [];
//     final totalProjectArrears = arrearsData?['totalProjectArrears'] ?? 0.0;
//     final grandTotal = arrearsData?['grandTotal'] ?? 0.0;

//     return [
//       pw.SizedBox(height: 20),
//       pw.Container(
//         padding: const pw.EdgeInsets.all(15),
//         decoration: pw.BoxDecoration(
//           border: pw.Border.all(color: PdfColors.grey300),
//           borderRadius: pw.BorderRadius.circular(10),
//         ),
//         child: pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             // Student Header
//             pw.Container(
//               padding: const pw.EdgeInsets.all(10),
//               decoration: pw.BoxDecoration(
//                 color: PdfColors.blue100,
//                 borderRadius: pw.BorderRadius.circular(5),
//               ),
//               child: pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 children: [
//                   pw.Text(
//                     '${student.name} ${student.surname}',
//                     style: pw.TextStyle(
//                         fontSize: 16, fontWeight: pw.FontWeight.bold),
//                   ),
//                   pw.Text(
//                     'ID: ${student.studentIdNumber}',
//                     style: const pw.TextStyle(fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//             pw.SizedBox(height: 10),

//             // Student Info
//             pw.Row(
//               children: [
//                 pw.Expanded(
//                     child: pw.Text('Class: ${student.class_ ?? "N/A"}')),
//                 pw.Expanded(
//                     child: pw.Text('Phone: ${student.phoneNumber ?? "N/A"}')),
//               ],
//             ),
//             pw.Divider(),
//             pw.SizedBox(height: 10),

//             // Fees Arrears Section
//             pw.Text('Fees Arrears:',
//                 style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//             pw.SizedBox(height: 5),
//             if (purposeList.isNotEmpty)
//               ...purposeList.map((entry) {
//                 final purpose = entry['purpose'];
//                 final preview = entry['arrearsPreview'];
//                 return pw.Padding(
//                   padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
//                   child: pw.Text('• ${purpose.paymentPurpose}: $preview',
//                       style: const pw.TextStyle(fontSize: 11)),
//                 );
//               }).toList(),
//             pw.SizedBox(height: 5),
//             pw.Text('Total Fees Arrears: \$${feesArrears.toStringAsFixed(2)}',
//                 style: pw.TextStyle(
//                     fontWeight: pw.FontWeight.bold, color: PdfColors.red)),

//             // Project Arrears Section
//             if (projectArrearsDetails.isNotEmpty) ...[
//               pw.SizedBox(height: 10),
//               pw.Text('Project Arrears:',
//                   style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//               pw.SizedBox(height: 5),
//               ...projectArrearsDetails
//                   .map((detail) => pw.Padding(
//                         padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
//                         child: pw.Text(
//                             '• ${detail.projectName}: \$${detail.arrears.toStringAsFixed(2)}',
//                             style: const pw.TextStyle(fontSize: 11)),
//                       ))
//                   .toList(),
//               pw.SizedBox(height: 5),
//               pw.Text(
//                   'Total Project Arrears: \$${totalProjectArrears.toStringAsFixed(2)}',
//                   style: pw.TextStyle(
//                       fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
//             ],

//             pw.Divider(),

//             // Grand Total
//             pw.Container(
//               alignment: pw.Alignment.centerRight,
//               child: pw.Text(
//                 'GRAND TOTAL: \$${grandTotal.toStringAsFixed(2)}',
//                 style: pw.TextStyle(
//                   fontSize: 14,
//                   fontWeight: pw.FontWeight.bold,
//                   color: PdfColors.red,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ];
//   }

//   pw.Widget _buildPdfHeader(School schoolInfo, int pageNum, int totalPages) {
//     return pw.Column(
//       children: [
//         pw.Container(
//           alignment: pw.Alignment.center,
//           child: pw.Column(children: [
//             pw.Text(
//               'STUDENT ARREARS STATEMENT',
//               style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
//             ),
//             pw.SizedBox(height: 5),
//             pw.Text(schoolInfo.schoolName ?? 'School Name'),
//             pw.Text(schoolInfo.schoolAddress ?? 'Address'),
//             pw.SizedBox(height: 5),
//             pw.Text('Page $pageNum of $totalPages',
//                 style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
//             pw.Divider(thickness: 2),
//           ]),
//         ),
//       ],
//     );
//   }

//   pw.Widget _buildPdfFooter(String username) {
//     return pw.Column(
//       children: [
//         pw.Divider(thickness: 1),
//         pw.SizedBox(height: 10),
//         pw.Text('Generated by: $username',
//             style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
//         pw.Text('Generated on: ${DateTime.now().toString().substring(0, 19)}',
//             style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
//       ],
//     );
//   }

//   void _updateSelectionSummary() {
//     // Check if _students is initialized
//     if (_students.isEmpty && _cachedFilteredStudents == null) {
//       setState(() {
//         _selectionSummary = 'Loading students...';
//       });
//       return;
//     }

//     final selectedStudents = _getSelectedStudents();
//     if (selectedStudents.isEmpty) {
//       setState(() {
//         _selectionSummary = 'No students selected';
//       });
//     } else {
//       final studentNames = selectedStudents
//           .map((s) => '${s.name} ${s.surname}')
//           .take(3) // Show only first 3 names to keep it readable
//           .join(', ');
//       final remaining = selectedStudents.length - 3;
//       setState(() {
//         _selectionSummary =
//             '${selectedStudents.length} student(s) selected: $studentNames${remaining > 0 ? ' + $remaining more' : ''}';
//       });
//     }
//   }

//   void _showSelectedStudentsActions(List<Student> selectedStudents) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const ListTile(
//               title: Text('Selected Students'),
//               subtitle: Text('Choose an action'),
//             ),
//             const Divider(),
//             ListTile(
//               leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
//               title: const Text('Generate PDF for Selected'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _generateMultiPagePdf(selectedStudents);
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.print, color: Colors.green),
//               title: const Text('Add to Print Queue'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _addToPrintQueue(selectedStudents);
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.print, color: Colors.blue),
//               title: const Text('Print Immediately'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _printSelectedStudents(selectedStudents);
//               },
//             ),
//             // Add a new action for quick print
//             ListTile(
//               leading: const Icon(Icons.local_printshop, color: Colors.orange),
//               title: const Text('Quick Print Selected (from bottom sheet)'),
//               onTap: () {
//                 Navigator.pop(context);
//                 if (selectedStudents.isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('No students selected for printing'),
//                     ),
//                   );
//                   return;
//                 }
//                 _addToPrintQueue(selectedStudents);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _printSelectedStudents(List<Student> students) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(child: CircularProgressIndicator()),
//     );

//     try {
//       for (var student in students) {
//         await _printStudentStatement(student);
//         await Future.delayed(
//             const Duration(seconds: 1)); // Delay between prints
//       }
//       if (mounted) Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Printed ${students.length} statements')),
//       );
//     } catch (e) {
//       if (mounted) Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error printing: $e'), backgroundColor: Colors.red),
//       );
//     }
//   }

//   void _onSearchSubmitted(String query) {
//     if (query.isEmpty) return;

//     _searchStudent(query, showDialog: true);
//   }

//   double get totalEntered =>
//       _paymentPurposes.fold(0.0, (sum, p) => sum + (p['currentAmount'] ?? 0.0));

//   @override
//   Widget build(BuildContext context) {
//     final isWindows = Theme.of(context).platform == TargetPlatform.windows;

//     if (globalTermId != null) {
//       return Stack(
//         children: [
//           Scaffold(
//             floatingActionButton: _buildFloatingActionButton(),
//             appBar: AppBar(
//               title: const Center(
//                 child: Text(
//                   'Student Arrears Statements',
//                   style: TextStyle(
//                     fontSize: 14.0, // Adjust font size
//                     fontWeight: FontWeight.normal, // Bold font
//                     color: Colors.white, // Title color
//                     letterSpacing: 1.2, // Slight letter spacing for elegance
//                   ),
//                 ),
//               ),
//               actions: [
//                 IconButton(
//                   icon: const Icon(Icons.summarize),
//                   onPressed: _hasFiltersApplied()
//                       ? () {
//                           final studentsToPrint =
//                               _cachedFilteredStudents ?? _students;
//                           if (studentsToPrint.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text(
//                                     'No students available to generate summary'),
//                                 backgroundColor: Colors.orange,
//                               ),
//                             );
//                             return;
//                           }
//                           _generateSummarizedPdf(studentsToPrint);
//                         }
//                       : null,
//                   tooltip: _hasFiltersApplied()
//                       ? 'Generate Summary Report'
//                       : '⚠️ Apply filters or select students first',
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.filter_list),
//                   onPressed: () async {
//                     // Show persistent loading dialog
//                     showDialog(
//                       context: context,
//                       barrierDismissible: false,
//                       builder: (context) => WillPopScope(
//                         onWillPop: () async => false,
//                         child: const AlertDialog(
//                           content: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               CircularProgressIndicator(),
//                               SizedBox(height: 16),
//                               Text(
//                                 'Loading student data...',
//                                 style: TextStyle(fontSize: 16),
//                               ),
//                               SizedBox(height: 8),
//                               Text(
//                                 'Please wait',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );

//                     try {
//                       // Wait for data to load with timeout
//                       int attempts = 0;
//                       const maxAttempts = 30;

//                       while (attempts < maxAttempts) {
//                         if (_students.isNotEmpty ||
//                             (_cachedFilteredStudents != null &&
//                                 _cachedFilteredStudents!.isNotEmpty)) {
//                           break;
//                         }
//                         await Future.delayed(const Duration(milliseconds: 100));
//                         attempts++;
//                       }

//                       if (mounted) Navigator.pop(context);

//                       final hasData = _students.isNotEmpty ||
//                           (_cachedFilteredStudents != null &&
//                               _cachedFilteredStudents!.isNotEmpty);

//                       if (!hasData) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text(
//                                 'Failed to load student data. Please try again.'),
//                             backgroundColor: Colors.red,
//                             duration: Duration(seconds: 3),
//                           ),
//                         );
//                         return;
//                       }

//                       final currentSelections =
//                           Map<String, bool>.from(_selectedStudents);

//                       await showDialog<Map<String, dynamic>>(
//                         context: context,
//                         builder: (context) => FilterDialog(
//                           students: _students.isNotEmpty
//                               ? _students
//                               : (_cachedFilteredStudents ?? []),
//                           initialSelections: currentSelections,
//                           selectedTerms: _selectedFilterTerms,
//                           users: _users, // ✅ Pass the users list here
//                           onFilterApplied: (filteredStudents, selectedTerms,
//                               arrearsFilterType) {
//                             setState(() {
//                               _cachedFilteredStudents = filteredStudents;
//                               _selectedFilterTerms = selectedTerms;
//                               _selectedStudents.clear();
//                               for (var student in filteredStudents) {
//                                 _selectedStudents[
//                                     student.studentIdNumber.toString()] = true;
//                               }
//                               _selectAll = true;
//                               _arrearsVersion++;
//                             });
//                           },
//                         ),
//                       );
//                     } catch (e) {
//                       if (mounted) Navigator.pop(context);
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text('Error loading data: $e'),
//                           backgroundColor: Colors.red,
//                           duration: const Duration(seconds: 3),
//                         ),
//                       );
//                     }
//                   },
//                   tooltip: 'Filter & Select Students',
//                 ),
//                 // Multi-page PDF button
//                 // Multi-page PDF button - With better UX
//                 IconButton(
//                   icon: const Icon(Icons.picture_as_pdf),
//                   onPressed: _hasFiltersApplied()
//                       ? () {
//                           final studentsToPrint =
//                               _cachedFilteredStudents ?? _students;
//                           if (studentsToPrint.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text(
//                                     'No students available to generate PDF'),
//                                 backgroundColor: Colors.orange,
//                               ),
//                             );
//                             return;
//                           }
//                           _generateMultiPagePdf(studentsToPrint);
//                         }
//                       : null,
//                   tooltip: _hasFiltersApplied()
//                       ? 'Generate PDF Statement'
//                       : '⚠️ Apply filters or select students first',
//                 ),
//                 // Print Queue button
//                 IconButton(
//                   icon: Badge(
//                     label: Text('${_printQueueManager.queue.length}'),
//                     isLabelVisible: _printQueueManager.queue.isNotEmpty,
//                     child: const Icon(Icons.print),
//                   ),
//                   onPressed: () {
//                     final studentsToPrint =
//                         _cachedFilteredStudents ?? _students;
//                     _addToPrintQueue(studentsToPrint);
//                   },
//                   tooltip: 'Print Queue',
//                 ),
//               ],
//               backgroundColor: const Color.fromARGB(255, 38, 140, 191),
//             ),
//             body: Center(
//               child: SingleChildScrollView(
//                 controller: _mainScrollController, // Add this controller
//                 child: Container(
//                   constraints: const BoxConstraints(maxWidth: 600),
//                   padding: const EdgeInsets.all(16),
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Color.fromRGBO(255, 255, 255, 1),
//                         Color.fromRGBO(255, 255, 255, 1)
//                       ],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                   child: Column(
//                     children: [
//                       RefreshIndicator(
//                         onRefresh: () =>
//                             bluetoothHelper.bluetoothPrint.startScan(
//                           timeout: const Duration(seconds: 5),
//                         ),
//                         child: SingleChildScrollView(
//                             child: // In your build method, where the printer UI is
//                                 Column(
//                           children: [
//                             // Platform indicator
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 12, vertical: 6),
//                               decoration: BoxDecoration(
//                                 color: _isWindows
//                                     ? Colors.blue.shade100
//                                     : Colors.green.shade100,
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     _isWindows
//                                         ? Icons.computer
//                                         : Icons.phone_android,
//                                     size: 16,
//                                     color: _isWindows
//                                         ? Colors.blue.shade900
//                                         : Colors.green.shade900,
//                                   ),
//                                   const SizedBox(width: 6),
//                                   Text(
//                                     _isWindows
//                                         ? 'WINDOWS MODE'
//                                         : 'ANDROID MODE',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.bold,
//                                       color: _isWindows
//                                           ? Colors.blue.shade900
//                                           : Colors.green.shade900,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),

//                             const SizedBox(height: 10),

//                             // Status indicator
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 12, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color: _connected
//                                     ? Colors.green.shade50
//                                     : Colors.orange.shade50,
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     _connected
//                                         ? Icons.check_circle
//                                         : Icons.warning,
//                                     size: 14,
//                                     color: _connected
//                                         ? Colors.green
//                                         : Colors.orange,
//                                   ),
//                                   const SizedBox(width: 6),
//                                   Text(
//                                     _connected ? 'Connected' : 'Not Connected',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w500,
//                                       color: _connected
//                                           ? Colors.green
//                                           : Colors.orange,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),

//                             const SizedBox(height: 10),

//                             // Platform-specific printer UI
//                             if (_isWindows) ...[
//                               // Windows Printer Selection
//                               Container(
//                                 padding: const EdgeInsets.all(12),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade50,
//                                   borderRadius: BorderRadius.circular(12),
//                                   border:
//                                       Border.all(color: Colors.grey.shade300),
//                                 ),
//                                 child: Column(
//                                   children: [
//                                     Row(
//                                       children: [
//                                         Expanded(
//                                           child: _isLoadingPrinters
//                                               ? const Center(
//                                                   child: Padding(
//                                                     padding: EdgeInsets.all(16),
//                                                     child:
//                                                         CircularProgressIndicator(),
//                                                   ),
//                                                 )
//                                               : DropdownButtonFormField<String>(
//                                                   value:
//                                                       _selectedWindowsPrinter,
//                                                   hint: const Text(
//                                                       'Select Windows Printer'),
//                                                   isExpanded: true,
//                                                   decoration: InputDecoration(
//                                                     border: OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                               8),
//                                                     ),
//                                                     contentPadding:
//                                                         const EdgeInsets
//                                                             .symmetric(
//                                                       horizontal: 12,
//                                                       vertical: 12,
//                                                     ),
//                                                   ),
//                                                   items: [
//                                                     const DropdownMenuItem(
//                                                       value: null,
//                                                       child: Text(
//                                                           '-- Select a printer --'),
//                                                     ),
//                                                     ..._windowsPrinters
//                                                         .map((printer) {
//                                                       bool isLastUsed =
//                                                           printer ==
//                                                               _lastUsedPrinter;
//                                                       return DropdownMenuItem(
//                                                         value: printer,
//                                                         child: Row(
//                                                           children: [
//                                                             Expanded(
//                                                               child: Text(
//                                                                 printer,
//                                                                 overflow:
//                                                                     TextOverflow
//                                                                         .ellipsis,
//                                                               ),
//                                                             ),
//                                                             if (isLastUsed &&
//                                                                 !_connected)
//                                                               const Icon(
//                                                                 Icons.history,
//                                                                 size: 16,
//                                                                 color:
//                                                                     Colors.blue,
//                                                               ),
//                                                             if (isLastUsed &&
//                                                                 _connected)
//                                                               const Icon(
//                                                                 Icons
//                                                                     .check_circle,
//                                                                 size: 16,
//                                                                 color: Colors
//                                                                     .green,
//                                                               ),
//                                                           ],
//                                                         ),
//                                                       );
//                                                     }),
//                                                   ],
//                                                   onChanged:
//                                                       _isTestingConnection
//                                                           ? null
//                                                           : (value) {
//                                                               setState(() {
//                                                                 _selectedWindowsPrinter =
//                                                                     value;
//                                                                 _connected =
//                                                                     false; // Reset connection when printer changes
//                                                               });
//                                                             },
//                                                 ),
//                                         ),
//                                         const SizedBox(width: 8),
//                                         IconButton(
//                                           icon: const Icon(Icons.refresh),
//                                           onPressed: _isLoadingPrinters
//                                               ? null
//                                               : _loadWindowsPrinters,
//                                           tooltip: 'Refresh printers',
//                                         ),
//                                         if (_lastUsedPrinter != null &&
//                                             !_connected &&
//                                             !_isTestingConnection)
//                                           Padding(
//                                             padding:
//                                                 const EdgeInsets.only(top: 8),
//                                             child: TextButton.icon(
//                                               onPressed:
//                                                   _autoConnectLastPrinter,
//                                               icon: const Icon(Icons.history,
//                                                   size: 16),
//                                               label: Text(
//                                                   'Reconnect to: $_lastUsedPrinter'),
//                                               style: TextButton.styleFrom(
//                                                 foregroundColor: Colors.blue,
//                                               ),
//                                             ),
//                                           ),
//                                       ],
//                                     ),
//                                     const SizedBox(height: 12),
//                                     Row(
//                                       children: [
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: _connected ||
//                                                     _isTestingConnection ||
//                                                     _selectedWindowsPrinter ==
//                                                         null
//                                                 ? null
//                                                 : _connectWindowsPrinter,
//                                             icon: _isTestingConnection
//                                                 ? const SizedBox(
//                                                     width: 20,
//                                                     height: 20,
//                                                     child:
//                                                         CircularProgressIndicator(
//                                                             strokeWidth: 2),
//                                                   )
//                                                 : const Icon(Icons.link),
//                                             label: Text(_isTestingConnection
//                                                 ? 'Connecting...'
//                                                 : 'Connect'),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.green,
//                                               foregroundColor: Colors.white,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       vertical: 12),
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 8),
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: !_connected
//                                                 ? null
//                                                 : _disconnectPrinter,
//                                             icon: const Icon(Icons.link_off),
//                                             label: const Text('Disconnect'),
//                                             style: OutlinedButton.styleFrom(
//                                               foregroundColor: Colors.red,
//                                               side: const BorderSide(
//                                                   color: Colors.red),
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       vertical: 12),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),

//                               if (_selectedWindowsPrinter != null &&
//                                   !_connected)
//                                 Padding(
//                                   padding: const EdgeInsets.only(top: 8),
//                                   child: Text(
//                                     'Selected: $_selectedWindowsPrinter',
//                                     style: const TextStyle(
//                                         fontSize: 12, color: Colors.blue),
//                                   ),
//                                 ),
//                             ],

//                             if (_isAndroid) ...[
//                               // Android Bluetooth UI
//                               Container(
//                                 padding: const EdgeInsets.all(12),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade50,
//                                   borderRadius: BorderRadius.circular(12),
//                                   border:
//                                       Border.all(color: Colors.grey.shade300),
//                                 ),
//                                 child: Column(
//                                   children: [
//                                     Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.symmetric(
//                                               vertical: 10, horizontal: 10),
//                                           child: Text(tips),
//                                         ),
//                                       ],
//                                     ),
//                                     const Divider(),
//                                     StreamBuilder<List<BluetoothDevice>>(
//                                       stream: bluetoothHelper
//                                           .bluetoothPrint.scanResults,
//                                       initialData: const [],
//                                       builder: (c, snapshot) => Column(
//                                         children: snapshot.data!
//                                             .map((d) => ListTile(
//                                                   title: Text(d.name ?? ''),
//                                                   subtitle:
//                                                       Text(d.address ?? ''),
//                                                   onTap: () async {
//                                                     setState(() {
//                                                       _device = d;
//                                                       _connected = false;
//                                                     });
//                                                   },
//                                                   trailing: _device != null &&
//                                                           _device!.address ==
//                                                               d.address
//                                                       ? const Icon(
//                                                           Icons.check_circle,
//                                                           color: Colors.green)
//                                                       : null,
//                                                 ))
//                                             .toList(),
//                                       ),
//                                     ),
//                                     const Divider(),
//                                     Row(
//                                       children: [
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: _connected
//                                                 ? null
//                                                 : _connectBluetoothPrinter,
//                                             icon: const Icon(
//                                                 Icons.bluetooth_connected),
//                                             label: const Text('Connect'),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.green,
//                                               foregroundColor: Colors.white,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       vertical: 12),
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 8),
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: !_connected
//                                                 ? null
//                                                 : _disconnectPrinter,
//                                             icon: const Icon(
//                                                 Icons.bluetooth_disabled),
//                                             label: const Text('Disconnect'),
//                                             style: OutlinedButton.styleFrom(
//                                               foregroundColor: Colors.red,
//                                               side: const BorderSide(
//                                                   color: Colors.red),
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       vertical: 12),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ],
//                         )),
//                       ),
//                       Form(
//                         key: _formKey,
//                         autovalidateMode: AutovalidateMode
//                             .onUserInteraction, // Automatically triggers validation

//                         child: Column(
//                           children: [
//                             const SizedBox(height: 20),
//                             if (_selectedStudents.isNotEmpty)
//                               Container(
//                                 margin:
//                                     const EdgeInsets.only(top: 8, bottom: 8),
//                                 padding: const EdgeInsets.all(12),
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue.shade50,
//                                   borderRadius: BorderRadius.circular(8),
//                                   border:
//                                       Border.all(color: Colors.blue.shade200),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             '📋 Selection Summary',
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.blue.shade800,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           if (_selectedFilterTerms.isNotEmpty)
//                                             Container(
//                                               margin: const EdgeInsets.only(
//                                                   top: 8, bottom: 8),
//                                               padding: const EdgeInsets.all(8),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.orange.shade50,
//                                                 borderRadius:
//                                                     BorderRadius.circular(8),
//                                                 border: Border.all(
//                                                     color:
//                                                         Colors.orange.shade200),
//                                               ),
//                                               child: Row(
//                                                 children: [
//                                                   const Icon(Icons.filter_alt,
//                                                       size: 16,
//                                                       color: Colors.orange),
//                                                   const SizedBox(width: 8),
//                                                   Expanded(
//                                                     child: Text(
//                                                       'Filtered by Terms: ${_selectedFilterTerms.join(", ")}',
//                                                       style: TextStyle(
//                                                         fontSize: 12,
//                                                         color: Colors
//                                                             .orange.shade800,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                   IconButton(
//                                                     icon: const Icon(
//                                                         Icons.close,
//                                                         size: 16),
//                                                     onPressed: () {
//                                                       setState(() {
//                                                         _selectedFilterTerms
//                                                             .clear();
//                                                         _cachedFilteredStudents =
//                                                             null;
//                                                         _arrearsVersion++;
//                                                       });
//                                                     },
//                                                     padding: EdgeInsets.zero,
//                                                     constraints:
//                                                         const BoxConstraints(),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                         ],
//                                       ),
//                                     ),
//                                     // Print selected button
//                                     if (_getSelectedStudents().isNotEmpty)
//                                       ElevatedButton.icon(
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: Colors.green,
//                                           foregroundColor: Colors.white,
//                                           padding: const EdgeInsets.symmetric(
//                                               horizontal: 16, vertical: 8),
//                                         ),
//                                         onPressed: () {
//                                           final selectedStudents =
//                                               _getSelectedStudents();
//                                           if (selectedStudents.isEmpty) {
//                                             ScaffoldMessenger.of(context)
//                                                 .showSnackBar(
//                                               const SnackBar(
//                                                 content: Text(
//                                                     'No students selected for printing'),
//                                               ),
//                                             );
//                                             return;
//                                           }
//                                           _addToPrintQueue(selectedStudents);
//                                         },
//                                         icon: const Icon(Icons.print, size: 18),
//                                         label: Text(
//                                           'Print Selected (${_getSelectedStudents().length})',
//                                           style: const TextStyle(fontSize: 12),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             if (_selectedStudent != null)
//                               Card(
//                                 margin:
//                                     const EdgeInsets.symmetric(vertical: 20),
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(16),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       const SizedBox(height: 10),
//                                       if (_selectedStudent != null)
//                                         Builder(
//                                           builder: (_) {
//                                             final studentId = _selectedStudent!
//                                                 .studentIdNumber
//                                                 .toString();

//                                             // 🔹 PROJECT ARREARS
//                                             final projectArrearsDetails =
//                                                 buildStudentArrearsDetails(
//                                                     studentId);

//                                             final totalProjectArrears =
//                                                 projectArrearsDetails
//                                                     .fold<double>(
//                                               0,
//                                               (sum, e) => sum + e.arrears,
//                                             );

//                                             return Card(
//                                               margin:
//                                                   const EdgeInsets.symmetric(
//                                                       vertical: 20),
//                                               child: Padding(
//                                                 padding:
//                                                     const EdgeInsets.all(16),
//                                                 child: Column(
//                                                   crossAxisAlignment:
//                                                       CrossAxisAlignment.start,
//                                                   children: [
//                                                     /// 👤 STUDENT INFO
//                                                     Text(
//                                                         'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}'),
//                                                     const SizedBox(height: 10),
//                                                     Text(
//                                                         'Class: ${_selectedStudent!.class_}'),
//                                                     const SizedBox(height: 10),
//                                                     Text(
//                                                         '${_selectedStudent!.paymentStatus}: ${_selectedStudent!.phoneNumber}'),

//                                                     if (_selectedStudent!
//                                                                 .emergencyContactNumber !=
//                                                             null &&
//                                                         _selectedStudent!
//                                                             .emergencyContactNumber!
//                                                             .isNotEmpty)
//                                                       Text(
//                                                           '${_selectedStudent!.emergencyContactName}: ${_selectedStudent!.emergencyContactNumber}'),

//                                                     const Divider(height: 30),
//                                                     if (_selectedStudent !=
//                                                         null)

//                                                       /// 💰 FEES ARREARS (Existing Future)
//                                                       FutureBuilder<double>(
//                                                         future:
//                                                             _totalArrearsFuture,
//                                                         builder: (context,
//                                                             snapshot) {
//                                                           if (snapshot
//                                                                   .connectionState ==
//                                                               ConnectionState
//                                                                   .waiting) {
//                                                             return const Text(
//                                                               'Calculating total arrears...',
//                                                               style: TextStyle(
//                                                                   color: Colors
//                                                                       .grey,
//                                                                   fontStyle:
//                                                                       FontStyle
//                                                                           .italic),
//                                                             );
//                                                           }

//                                                           if (snapshot
//                                                               .hasError) {
//                                                             return Text(
//                                                               'Error fetching arrears: ${snapshot.error}',
//                                                               style: const TextStyle(
//                                                                   color: Colors
//                                                                       .red),
//                                                             );
//                                                           }

//                                                           final feesArrears =
//                                                               snapshot.data ??
//                                                                   0.0;

//                                                           final grandTotal =
//                                                               feesArrears +
//                                                                   totalProjectArrears;

//                                                           return Column(
//                                                             crossAxisAlignment:
//                                                                 CrossAxisAlignment
//                                                                     .start,
//                                                             children: [
//                                                               /// =========================
//                                                               /// 🔥 GRAND TOTAL
//                                                               /// =========================
//                                                               Container(
//                                                                 padding:
//                                                                     const EdgeInsets
//                                                                         .all(
//                                                                         14),
//                                                                 decoration:
//                                                                     BoxDecoration(
//                                                                   gradient:
//                                                                       LinearGradient(
//                                                                     colors: [
//                                                                       Colors.red
//                                                                           .withOpacity(
//                                                                               0.1),
//                                                                       Colors
//                                                                           .deepOrange
//                                                                           .withOpacity(
//                                                                               0.1),
//                                                                     ],
//                                                                   ),
//                                                                   borderRadius:
//                                                                       BorderRadius
//                                                                           .circular(
//                                                                               12),
//                                                                   border: Border.all(
//                                                                       color: Colors
//                                                                           .red
//                                                                           .withOpacity(
//                                                                               0.2)),
//                                                                 ),
//                                                                 child: Row(
//                                                                   children: [
//                                                                     const Icon(
//                                                                         Icons
//                                                                             .account_balance_wallet,
//                                                                         color: Colors
//                                                                             .red),
//                                                                     const SizedBox(
//                                                                         width:
//                                                                             10),
//                                                                     const Expanded(
//                                                                       child:
//                                                                           Text(
//                                                                         'Total Student\'s Outstanding',
//                                                                         style:
//                                                                             TextStyle(
//                                                                           fontSize:
//                                                                               16,
//                                                                           fontWeight:
//                                                                               FontWeight.bold,
//                                                                         ),
//                                                                       ),
//                                                                     ),
//                                                                     Text(
//                                                                       '\$${grandTotal.toStringAsFixed(2)}',
//                                                                       style:
//                                                                           const TextStyle(
//                                                                         fontSize:
//                                                                             18,
//                                                                         fontWeight:
//                                                                             FontWeight.bold,
//                                                                         color: Colors
//                                                                             .red,
//                                                                       ),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ),
//                                                               const SizedBox(
//                                                                   height: 16),

//                                                               /// =========================
//                                                               /// 📋 PROJECT ARREARS HEADER
//                                                               /// =========================
//                                                               if (projectArrearsDetails
//                                                                   .isNotEmpty)
//                                                                 Container(
//                                                                   padding:
//                                                                       const EdgeInsets
//                                                                           .all(
//                                                                           12),
//                                                                   decoration:
//                                                                       BoxDecoration(
//                                                                     color: Colors
//                                                                         .deepPurple
//                                                                         .withOpacity(
//                                                                             0.06),
//                                                                     borderRadius:
//                                                                         BorderRadius.circular(
//                                                                             12),
//                                                                     border: Border.all(
//                                                                         color: Colors
//                                                                             .deepPurple
//                                                                             .withOpacity(0.15)),
//                                                                   ),
//                                                                   child: Column(
//                                                                     crossAxisAlignment:
//                                                                         CrossAxisAlignment
//                                                                             .start,
//                                                                     children: [
//                                                                       const Text(
//                                                                         '📋 Project Arrears Overview',
//                                                                         style:
//                                                                             TextStyle(
//                                                                           fontSize:
//                                                                               16,
//                                                                           fontWeight:
//                                                                               FontWeight.bold,
//                                                                           color:
//                                                                               Colors.deepPurple,
//                                                                         ),
//                                                                       ),
//                                                                       const SizedBox(
//                                                                           height:
//                                                                               10),

//                                                                       /// =========================
//                                                                       /// PROJECT CARDS
//                                                                       /// =========================
//                                                                       ...projectArrearsDetails
//                                                                           .map(
//                                                                               (s) {
//                                                                         return Container(
//                                                                           margin: const EdgeInsets
//                                                                               .symmetric(
//                                                                               vertical: 6),
//                                                                           decoration:
//                                                                               BoxDecoration(
//                                                                             color:
//                                                                                 Colors.white,
//                                                                             borderRadius:
//                                                                                 BorderRadius.circular(12),
//                                                                             boxShadow: [
//                                                                               BoxShadow(
//                                                                                 color: Colors.black.withOpacity(0.05),
//                                                                                 blurRadius: 6,
//                                                                                 offset: const Offset(0, 3),
//                                                                               ),
//                                                                             ],
//                                                                           ),
//                                                                           child:
//                                                                               Padding(
//                                                                             padding:
//                                                                                 const EdgeInsets.all(12),
//                                                                             child:
//                                                                                 Column(
//                                                                               crossAxisAlignment: CrossAxisAlignment.start,
//                                                                               children: [
//                                                                                 /// PROJECT NAME
//                                                                                 Row(
//                                                                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                                                                   children: [
//                                                                                     Expanded(
//                                                                                       child: Text(
//                                                                                         s.projectName,
//                                                                                         style: const TextStyle(
//                                                                                           fontSize: 15,
//                                                                                           fontWeight: FontWeight.bold,
//                                                                                           color: Colors.black87,
//                                                                                         ),
//                                                                                       ),
//                                                                                     ),
//                                                                                     Container(
//                                                                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                                                                                       decoration: BoxDecoration(
//                                                                                         color: Colors.red.withOpacity(0.1),
//                                                                                         borderRadius: BorderRadius.circular(20),
//                                                                                       ),
//                                                                                       child: Text(
//                                                                                         "\$${s.arrears.toStringAsFixed(2)}",
//                                                                                         style: const TextStyle(
//                                                                                           color: Colors.red,
//                                                                                           fontWeight: FontWeight.bold,
//                                                                                         ),
//                                                                                       ),
//                                                                                     ),
//                                                                                   ],
//                                                                                 ),

//                                                                                 const SizedBox(height: 8),

//                                                                                 /// ITEM DETAILS
//                                                                                 Text(
//                                                                                   'Item: ${s.itemName}',
//                                                                                   style: TextStyle(
//                                                                                     color: Colors.grey.shade700,
//                                                                                     fontSize: 13,
//                                                                                   ),
//                                                                                 ),
//                                                                                 const SizedBox(height: 4),
//                                                                                 Text(
//                                                                                   'Batch: ${s.batchName}',
//                                                                                   style: TextStyle(
//                                                                                     color: Colors.grey.shade600,
//                                                                                     fontSize: 13,
//                                                                                   ),
//                                                                                 ),

//                                                                                 const SizedBox(height: 12),

//                                                                                 /// ACTION BUTTONS
//                                                                                 Row(
//                                                                                   mainAxisAlignment: MainAxisAlignment.end,
//                                                                                   children: [
//                                                                                     /// FULL PAY
//                                                                                     ElevatedButton.icon(
//                                                                                       style: ElevatedButton.styleFrom(
//                                                                                         backgroundColor: Colors.redAccent,
//                                                                                         foregroundColor: Colors.white,
//                                                                                         shape: RoundedRectangleBorder(
//                                                                                           borderRadius: BorderRadius.circular(10),
//                                                                                         ),
//                                                                                       ),
//                                                                                       icon: const Icon(Icons.payments, size: 18),
//                                                                                       label: const Text("Pay Full"),
//                                                                                       onPressed: () {
//                                                                                         Navigator.push(
//                                                                                           context,
//                                                                                           MaterialPageRoute(
//                                                                                             builder: (_) => const ProjectPaymentScreen(),
//                                                                                           ),
//                                                                                         );
//                                                                                       },
//                                                                                     ),

//                                                                                     const SizedBox(width: 10),

//                                                                                     /// PARTIAL PAY
//                                                                                     ElevatedButton.icon(
//                                                                                       style: ElevatedButton.styleFrom(
//                                                                                         backgroundColor: Colors.deepPurple,
//                                                                                         foregroundColor: Colors.white,
//                                                                                         shape: RoundedRectangleBorder(
//                                                                                           borderRadius: BorderRadius.circular(10),
//                                                                                         ),
//                                                                                       ),
//                                                                                       icon: const Icon(Icons.payment, size: 18),
//                                                                                       label: const Text("Partial"),
//                                                                                       onPressed: () {
//                                                                                         Navigator.push(
//                                                                                           context,
//                                                                                           MaterialPageRoute(
//                                                                                             builder: (_) => const ProjectPaymentScreen(),
//                                                                                           ),
//                                                                                         );
//                                                                                       },
//                                                                                     ),
//                                                                                   ],
//                                                                                 ),
//                                                                               ],
//                                                                             ),
//                                                                           ),
//                                                                         );
//                                                                       }),
//                                                                     ],
//                                                                   ),
//                                                                 ),

//                                                               const SizedBox(
//                                                                   height: 12),

//                                                               /// =========================
//                                                               /// 📦 TOTAL PROJECT ARREARS
//                                                               /// =========================
//                                                               if (totalProjectArrears >
//                                                                   0)
//                                                                 Container(
//                                                                   padding:
//                                                                       const EdgeInsets
//                                                                           .all(
//                                                                           12),
//                                                                   decoration:
//                                                                       BoxDecoration(
//                                                                     color: Colors
//                                                                         .orange
//                                                                         .withOpacity(
//                                                                             0.08),
//                                                                     borderRadius:
//                                                                         BorderRadius.circular(
//                                                                             12),
//                                                                     border: Border.all(
//                                                                         color: Colors
//                                                                             .orange
//                                                                             .withOpacity(0.2)),
//                                                                   ),
//                                                                   child: Row(
//                                                                     children: [
//                                                                       const Icon(
//                                                                           Icons
//                                                                               .warning_amber_rounded,
//                                                                           color:
//                                                                               Colors.orange),
//                                                                       const SizedBox(
//                                                                           width:
//                                                                               10),
//                                                                       Expanded(
//                                                                         child:
//                                                                             Text(
//                                                                           'Project Arrears Total',
//                                                                           style:
//                                                                               TextStyle(
//                                                                             fontWeight:
//                                                                                 FontWeight.bold,
//                                                                             color:
//                                                                                 Colors.grey.shade800,
//                                                                           ),
//                                                                         ),
//                                                                       ),
//                                                                       Text(
//                                                                         '\$${totalProjectArrears.toStringAsFixed(2)}',
//                                                                         style:
//                                                                             const TextStyle(
//                                                                           fontSize:
//                                                                               16,
//                                                                           fontWeight:
//                                                                               FontWeight.bold,
//                                                                           color:
//                                                                               Colors.deepOrange,
//                                                                         ),
//                                                                       ),
//                                                                     ],
//                                                                   ),
//                                                                 ),
//                                                             ],
//                                                           );
//                                                         },
//                                                       ),
//                                                     const SizedBox(height: 52),

//                                                     // Replace the entire FutureBuilder with this:
//                                                     ArrearsSection(
//                                                       key:
//                                                           _arrearsSectionKey, // Force rebuild when version changes
//                                                       student:
//                                                           _selectedStudent!,
//                                                       version: _arrearsVersion,
//                                                       onItemsSelected:
//                                                           _handleArrearsSelected,
//                                                       getSelectedSubPurposes:
//                                                           _getSelectedSubPurposes,
//                                                       setSelectedSubPurposes:
//                                                           _setSelectedSubPurposes,
//                                                       fetchArrears:
//                                                           _fetchArrearsWithRestorations,
//                                                       restoredItems:
//                                                           _pendingRestorations,
//                                                       onRefreshRequested: () {},
//                                                     ),
//                                                   ],
//                                                 ),
//                                               ),
//                                             );
//                                           },
//                                         ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     } else {
//       // If globalTermId is null, show an alternative UI or a message
//       return Scaffold(
//           appBar: AppBar(
//             title: const Text('No Selected Term Found'),
//           ),
//           body: const Center(
//             child: Text(
//               'No term is currently active. Either switch to an existing term or create a new term to proceed.',
//               style: TextStyle(
//                 fontSize: 16.0, // Set font size
//                 fontWeight: FontWeight.bold, // Set font weight
//                 color: Colors.redAccent, // Set text color
//                 letterSpacing: 1.2, // Set spacing between letters
//                 height: 1.5, // Set line height (space between lines)
//               ),
//               textAlign: TextAlign.center, // Align text to the center
//             ),
//           ));
//     }
//   }

// // Filter students based on teacher's assigned classes
//   // Filter students based on teacher's assigned classes (case-insensitive)
//   List<Student> _filterStudentsByTeacherClasses(List<Student> students) {
//     if (!_isTeacher()) return students;

//     final assignedClasses = _getTeacherAssignedClasses();
//     if (assignedClasses.isEmpty) return students; // No restrictions

//     // Convert assigned classes to lowercase for case-insensitive comparison
//     final assignedClassesLower =
//         assignedClasses.map((c) => c.toLowerCase()).toList();

//     return students.where((student) {
//       final studentClass = student.class_?.toLowerCase() ?? '';
//       return assignedClassesLower.contains(studentClass);
//     }).toList();
//   }

// // Get terms that are valid (start date is on or before current month)
//   List<Terms> _getValidTermsForCurrentMonth() {
//     // ✅ If not a teacher, return ALL terms
//     if (!_isTeacher()) {
//       return _role == DeviceRole.host
//           ? Hive.box<Terms>('terms').values.toList()
//           : _cachedServerTerms ?? [];
//     }

//     final now = DateTime.now();
//     final currentMonth = DateTime(now.year, now.month, 1);

//     List<Terms> allTerms = _role == DeviceRole.host
//         ? Hive.box<Terms>('terms').values.toList()
//         : _cachedServerTerms ?? [];

//     return allTerms.where((term) {
//       // Include terms where start date is on or before the current month
//       final termStart = DateTime(term.startDate.year, term.startDate.month, 1);
//       return termStart.compareTo(currentMonth) <= 0;
//     }).toList();
//   }

// // Get term IDs that should be excluded (future terms) - ONLY for teachers
//   List<String> _getExcludedFutureTermIds() {
//     // ✅ If not a teacher, return empty list (no exclusions)
//     if (!_isTeacher()) return [];

//     final validTerms = _getValidTermsForCurrentMonth();
//     final validTermIds = validTerms.map((t) => t.termId).toSet();

//     List<Terms> allTerms = _role == DeviceRole.host
//         ? Hive.box<Terms>('terms').values.toList()
//         : _cachedServerTerms ?? [];

//     return allTerms
//         .where((term) => !validTermIds.contains(term.termId))
//         .map((t) => t.termId)
//         .toList();
//   }

// // Add this map to store updated arrears amounts
//   final Map<String, Map<String, double>> _updatedArrearsCache = {};

//   Future<List<Map<String, dynamic>>> _fetchArrearsWithRestorations(
//       Student student) async {
//     // Fetch original arrears
//     List<Map<String, dynamic>> originalArrears =
//         await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviwNew(
//             student);

//     if (_pendingRestorations.isEmpty) {
//       return originalArrears;
//     }

//     // Create a map keyed by purpose NAME only (NOT including termId)
//     Map<String, Map<String, dynamic>> purposeMap = {};
//     for (var item in originalArrears) {
//       final purpose = item['purpose'];
//       final purposeName = purpose.paymentPurpose ?? '';
//       purposeMap[purposeName] = item;
//     }

//     // Group restorations by purpose name
//     Map<String, List<Map<String, dynamic>>> groupedRestorations = {};
//     for (var restoration in _pendingRestorations) {
//       final purpose = restoration['purpose'];
//       final purposeName = purpose.paymentPurpose ?? '';
//       if (!groupedRestorations.containsKey(purposeName)) {
//         groupedRestorations[purposeName] = [];
//       }
//       groupedRestorations[purposeName]!.add(restoration);
//     }

//     // Apply restorations to matching purposes
//     for (var entry in groupedRestorations.entries) {
//       final purposeName = entry.key;
//       final restorations = entry.value;

//       if (purposeMap.containsKey(purposeName)) {
//         final existingItem = purposeMap[purposeName]!;

//         // Calculate total restoration amount for this purpose
//         double totalRestorationAmount = 0;
//         for (var restoration in restorations) {
//           totalRestorationAmount += restoration['amount'] as double;
//         }

//         // Update the parent purpose amount
//         final existingPreview = existingItem['arrearsPreview'] ?? '';
//         final existingAmount = _extractAmountFromPreview(existingPreview);
//         final newAmount = existingAmount + totalRestorationAmount;
//         existingItem['arrearsPreview'] =
//             _updateAmountInPreview(existingPreview, newAmount);

//         // Update subPurposesWithTerms
//         if (existingItem['subPurposesWithTerms'] == null) {
//           existingItem['subPurposesWithTerms'] = [];
//         }

//         // Add restored amounts to sub-purposes (by term)
//         for (var restoration in restorations) {
//           final termId = restoration['termId'];
//           final amount = restoration['amount'] as double;

//           // Check if this term already exists in sub-purposes
//           bool termExists = false;
//           for (var subItem in existingItem['subPurposesWithTerms']) {
//             if (subItem['termId'] == termId) {
//               // Update existing term
//               final currentSubAmount = subItem['amount'] as double;
//               subItem['amount'] = currentSubAmount + 0;
//               subItem['preview'] =
//                   _updateAmountInPreview(subItem['preview'], subItem['amount']);
//               termExists = true;
//               break;
//             }
//           }

//           if (!termExists) {
//             // Add new sub-purpose for this term
//             existingItem['subPurposesWithTerms'].add({
//               'preview': '$termId [${_formatCurrency(amount)}] ',
//               'amount': amount,
//               'termId': termId,
//             });
//           }
//         }

//         // Rebuild the arrearsPreview from all sub-purposes
//         existingItem['arrearsPreview'] = existingItem['subPurposesWithTerms']
//             .map((sub) => sub['preview'])
//             .join(', ');
//       } else {
//         // Purpose doesn't exist - create new item
//         double totalAmount = 0;
//         String? firstTermId;
//         PaymentPurpose? firstPurpose;

//         for (var restoration in restorations) {
//           totalAmount += restoration['amount'] as double;
//           if (firstTermId == null) {
//             firstTermId = restoration['termId'];
//             firstPurpose = restoration['purpose'];
//           }
//         }

//         final newItem = {
//           'purpose': firstPurpose,
//           'termId': firstTermId,
//           'arrearsPreview': '$firstTermId [${_formatCurrency(totalAmount)}] ',
//           'subPurposesWithTerms': restorations
//               .map((r) => {
//                     'preview':
//                         '$firstTermId [${_formatCurrency(r['amount'])}] ',
//                     'amount': r['amount'],
//                     'termId': r['termId'],
//                   })
//               .toList(),
//         };
//         originalArrears.add(newItem);
//       }
//     }

//     return originalArrears;
//   }

//   double _extractAmountFromPreview(String preview) {
//     final regex = RegExp(r'\[\$(\d+(?:\.\d+)?)\]|\$(\d+(?:\.\d+)?)');
//     final match = regex.firstMatch(preview);
//     if (match != null) {
//       String amountStr = match.group(1) ?? match.group(2) ?? '';
//       if (amountStr.isNotEmpty) {
//         return double.parse(amountStr);
//       }
//     }
//     return 0.0;
//   }

//   String _updateAmountInPreview(String preview, double newAmount) {
//     final regex = RegExp(r'(\[\$)(\d+(?:\.\d+)?)(\])|(\$)(\d+(?:\.\d+)?)');
//     return preview.replaceAllMapped(regex, (match) {
//       if (match.group(1) != null) {
//         return '${match.group(1)}${newAmount.toStringAsFixed(2)}${match.group(3)}';
//       } else {
//         return '${match.group(4)}${newAmount.toStringAsFixed(2)}';
//       }
//     });
//   }

//   Timer? _debounce;

//   double calculateArrears(String saleCode) {
//     final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

//     final sale = txBox.values.firstWhere(
//       (t) => t.transactionCode == saleCode && t.createsObligation,
//     );

//     final subsequentPayments = txBox.values
//         .where(
//             (t) => t.parentTransactionCode == saleCode && t.settlesObligation)
//         .fold<double>(0, (sum, t) => sum + t.amountPaid);

//     final totalPaid = sale.amountPaid + subsequentPayments;

//     return (sale.totalAmount - totalPaid).clamp(0, double.infinity);
//   }

//   List<ArrearsSummary> buildStudentArrearsDetails(String studentId) {
//     // ✅ Check if client and no cached data
//     if (_role == DeviceRole.client) {
//       if (_cachedServerProjectSaleTransactions == null ||
//           _cachedProductBatches == null) {
//         return [];
//       }
//     }

//     // ✅ Get transactions and batches based on role
//     List<ProjectSaleTransaction> allTransactions = [];
//     Map<String, ProductBatch> batchMap = {};
//     List<ProjectSaleTransaction> _cart = []; // ✅ Preserve cart list

//     if (_role == DeviceRole.host) {
//       // ✅ HOST: Direct Hive access for both boxes
//       final txBox =
//           Hive.box<ProjectSaleTransaction>('project_sale_transactions');
//       final batchBox = Hive.box<ProductBatch>('product_batches');

//       allTransactions = txBox.values.toList();

//       // Build batch map from Hive
//       for (var batch in batchBox.values) {
//         batchMap[batch.batchCode.toString()] = batch;
//       }
//     } else {
//       // ✅ CLIENT: Use cached data for both
//       allTransactions = _cachedServerProjectSaleTransactions!;

//       // Build batch map from cached data
//       for (var batch in _cachedProductBatches!) {
//         batchMap[batch.batchCode.toString()] = batch;
//       }
//     }

//     // ✅ Get sales (creates obligation) for this student
//     final sales = allTransactions.where((t) =>
//         t.studentId == studentId && t.createsObligation && t.isDeleted != true);

//     return sales
//         .map((sale) {
//           // ✅ Calculate payments for this sale (same as original)
//           final payments = allTransactions
//               .where((t) =>
//                   t.parentTransactionCode == sale.transactionCode &&
//                   t.settlesObligation &&
//                   t.isDeleted != true)
//               .fold<double>(0, (sum, t) => sum + t.amountPaid);

//           final totalPaid = sale.amountPaid + payments;
//           final arrears =
//               (sale.totalAmount - totalPaid).clamp(0, double.infinity);

//           // ✅ 🔥 subtract cart payments for same parent sale (same as original)
//           final cartPayments = _cart
//               .where((t) => t.parentTransactionCode == sale.transactionCode)
//               .fold<double>(0, (sum, t) => sum + t.amountPaid);

//           final adjustedArrears =
//               (arrears - cartPayments).clamp(0, double.infinity);

//           // ✅ Get project (same as original)
//           final project = _projects.firstWhere(
//             (p) => p.projectCode == sale.projectCode,
//             orElse: () => Project(
//               name: 'Unknown Project',
//               projectCode: '',
//               status: 'inactive',
//               createdAt: DateTime.now(),
//               updatedAt: DateTime.now(),
//               projectType: 'unknown',
//               participationType: 'none',
//             ),
//           );

//           // ✅ Get item (same as original)
//           final item = _items.firstWhere(
//             (i) => i.projectItemCode == sale.projectItemCode,
//             orElse: () => ProjectItem(
//               name: 'Unknown Item',
//               projectItemCode: '',
//             ),
//           );

//           // ✅ Get batch from map (same as original, but using map instead of direct Hive)
//           final batch = batchMap[sale.batchCode];
//           final batchName = batch?.reference ?? 'Unknown Batch';

//           // ✅ Return ArrearsSummary with all original calculations
//           return ArrearsSummary(
//             transactionCode: sale.transactionCode,
//             projectName: project.name ?? 'Unknown Project',
//             itemName: item.name ?? 'Unknown Item',
//             batchName: batchName,
//             totalAmount: sale.totalAmount,
//             totalPaid: totalPaid + cartPayments, // ✅ Same as original
//             arrears: adjustedArrears.toDouble(), // ✅ Same as original
//           );
//         })
//         .where((s) => s.arrears > 0)
//         .toList();
//   }

//   Future<double> _computeTotalStudentArrears(Student student) async {
//     double total = 0.0;

//     try {
//       final arrearPurposes =
//           await _fetchUniquePaymentPurposesByStudentWithArrears(student);

//       for (final entry in arrearPurposes) {
//         if (_role == DeviceRole.host) {
//           final purpose = entry['purpose'] as PaymentPurpose;
//           final arrearsData = await _computeArrearsForPurpose(purpose);

//           for (final amt in arrearsData.values) {
//             if (amt > 0) total += amt;
//           }
//         } else {
//           final arrearsData = entry['arrears'] as Map<String, double>? ?? {};

//           for (final amt in arrearsData.values) {
//             if (amt > 0) total += amt;
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('⚠️ Failed to compute total arrears: $e');
//     }

//     return total;
//   }

//   Future<List<Map<String, dynamic>>>
//       _fetchUniquePaymentPurposesByStudentWithArrears(Student student) async {
//     final List<PaymentPurpose> allPurposes;

//     if (_role == DeviceRole.host) {
//       final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
//       allPurposes = box.values.toList();
//     } else {
//       if (_cachedServerStudentPaymentPurposes == null) {
//         final prefs = await SharedPreferences.getInstance();
//         final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonStr = await response.transform(utf8.decoder).join();
//           final list = jsonDecode(jsonStr) as List;

//           _cachedServerStudentPaymentPurposes = list
//               .map((json) =>
//                   paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//         } else {
//           throw Exception('Failed to fetch payment purposes from server.');
//         }
//       }
//       allPurposes = _cachedServerStudentPaymentPurposes!;
//     }

//     final excludedTermIds = _getExcludedFutureTermIds();

//     final Set<String> seenPurposeNames = {};
//     final List<PaymentPurpose> filtered = [];

//     for (final purpose in allPurposes) {
//       // Skip purposes that belong to future terms

//       if (excludedTermIds.contains(purpose.termId)) {
//         continue;
//       }
//       final isForClass = purpose.associatedClasses
//               ?.any((c) => c.toLowerCase() == student.class_?.toLowerCase()) ??
//           false;

//       final isException = purpose.exceptions?.any(
//             (e) =>
//                 student.exceptions
//                     ?.any((s) => s.exceptionId == e.exceptionId) ??
//                 false,
//           ) ??
//           false;

//       bool isNewcomerRelated = purpose.forNewcomersOnly == true;
//       bool newcomerConditionAllows = true;

//       if (isNewcomerRelated) {
//         if (student.isNewComer != true) {
//           newcomerConditionAllows = false;
//         } else if (student.isNewComerUntil != null) {
//           final newcomerUntil = student.isNewComerUntil!;
//           final term = _termsMap[purpose.termId];
//           if (term != null && term.startDate.isAfter(newcomerUntil)) {
//             newcomerConditionAllows = false;
//           }
//         }
//       }

//       final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
//           newcomerConditionAllows;

//       if (shouldInclude) {
//         final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
//         if (!seenPurposeNames.contains(nameKey)) {
//           seenPurposeNames.add(nameKey);
//           filtered.add(purpose);
//         }
//       }
//     }

//     // ------------------------------------------------------------
//     // STEP 2: Compute arrears & build preview string
//     // ------------------------------------------------------------
//     final List<Map<String, dynamic>> resultList = [];

//     for (final purpose in filtered) {
//       try {
//         final arrearsData = await _computeArrearsForPurpose(purpose);

//         // Filter only terms with positive arrears
//         final nonZeroArrears =
//             arrearsData.entries.where((e) => e.value > 0).toList();

//         if (nonZeroArrears.isNotEmpty) {
//           // Sort alphabetically by term text
//           final monthMap = {
//             'january': 1,
//             'february': 2,
//             'march': 3,
//             'april': 4,
//             'may': 5,
//             'june': 6,
//             'july': 7,
//             'august': 8,
//             'september': 9,
//             'october': 10,
//             'november': 11,
//             'december': 12,
//           };

//           nonZeroArrears.sort((a, b) {
//             final termRegex = RegExp(r'(\d{4})\s+Term\s+(\d+)\s*\((\w+)\)',
//                 caseSensitive: false);

//             final matchA = termRegex.firstMatch(a.key);
//             final matchB = termRegex.firstMatch(b.key);

//             if (matchA == null || matchB == null) return a.key.compareTo(b.key);

//             final yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
//             final yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;

//             final termA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
//             final termB = int.tryParse(matchB.group(2) ?? '0') ?? 0;

//             final monthA = monthMap[(matchA.group(3) ?? '').toLowerCase()] ?? 0;
//             final monthB = monthMap[(matchB.group(3) ?? '').toLowerCase()] ?? 0;

//             // Compare year first, then term, then month
//             if (yearA != yearB) return yearA.compareTo(yearB);
//             if (termA != termB) return termA.compareTo(termB);
//             return monthA.compareTo(monthB);
//           });

// // Build preview: show max 3 arrears
//           final previewParts = nonZeroArrears.take(3).map((e) {
//             final display = e.key; // Already like "2025 Term 1 (February)"
//             return '$display (\$${e.value.toStringAsFixed(2)})';
//           }).join(', ');

//           final hasMore = nonZeroArrears.length > 3 ? ', ...' : '';
//           final arrearsPreview = '($previewParts$hasMore)';

//           resultList.add({
//             'purpose': purpose,
//             'arrears': {for (var e in nonZeroArrears) e.key: e.value},
//             'arrearsPreview': arrearsPreview,
//           });
//         }
//       } catch (e) {
//         debugPrint(
//             '⚠️ Failed arrears preview for ${purpose.paymentPurpose}: $e');
//       }
//     }

//     return resultList;
//   }

//   Future<List<Map<String, dynamic>>>
//       _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
//           Student student) async {
//     final List<PaymentPurpose> allPurposes;

//     if (_role == DeviceRole.host) {
//       final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
//       allPurposes = box.values.toList();
//     } else {
//       if (_cachedServerStudentPaymentPurposes == null) {
//         final prefs = await SharedPreferences.getInstance();
//         final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonStr = await response.transform(utf8.decoder).join();
//           final list = jsonDecode(jsonStr) as List;

//           _cachedServerStudentPaymentPurposes = list
//               .map((json) =>
//                   paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//         } else {
//           throw Exception('Failed to fetch payment purposes from server.');
//         }
//       }
//       allPurposes = _cachedServerStudentPaymentPurposes!;
//     }

//     final Set<String> seenPurposeNames = {};
//     final List<PaymentPurpose> filtered = [];

//     for (final purpose in allPurposes) {
//       // Skip purposes that don't belong to selected terms
//       if (_selectedFilterTerms.isNotEmpty &&
//           purpose.termId != null &&
//           !_selectedFilterTerms.contains(purpose.termId)) {
//         continue;
//       }

//       final isForClass =
//           purpose.associatedClasses?.contains(student.class_) ?? false;

//       final isException = purpose.exceptions?.any(
//             (e) =>
//                 student.exceptions
//                     ?.any((s) => s.exceptionId == e.exceptionId) ??
//                 false,
//           ) ??
//           false;

//       bool isNewcomerRelated = purpose.forNewcomersOnly == true;
//       bool newcomerConditionAllows = true;

//       if (isNewcomerRelated) {
//         if (student.isNewComer != true) {
//           newcomerConditionAllows = false;
//         } else if (student.isNewComerUntil != null) {
//           final newcomerUntil = student.isNewComerUntil!;
//           final term = _termsMap[purpose.termId];
//           if (term != null && term.startDate.isAfter(newcomerUntil)) {
//             newcomerConditionAllows = false;
//           }
//         }
//       }

//       final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
//           newcomerConditionAllows;

//       if (shouldInclude) {
//         final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
//         if (!seenPurposeNames.contains(nameKey)) {
//           seenPurposeNames.add(nameKey);
//           filtered.add(purpose);
//         }
//       }
//     }

//     // ------------------------------------------------------------
//     // STEP 2: Compute arrears & build preview string
//     // ------------------------------------------------------------
//     final List<Map<String, dynamic>> resultList = [];

//     for (final purpose in filtered) {
//       try {
//         final arrearsData = await _computeArrearsForPurpose(purpose);
//         final List<Map<String, dynamic>> subPurposesWithTerms = [];

//         // Filter only terms with positive arrears
//         final nonZeroArrears =
//             arrearsData.entries.where((e) => e.value > 0).toList();

//         if (nonZeroArrears.isNotEmpty) {
//           // Sort alphabetically by term text
//           final monthMap = {
//             'january': 1,
//             'february': 2,
//             'march': 3,
//             'april': 4,
//             'may': 5,
//             'june': 6,
//             'july': 7,
//             'august': 8,
//             'september': 9,
//             'october': 10,
//             'november': 11,
//             'december': 12,
//           };

//           nonZeroArrears.sort((a, b) {
//             final termRegex = RegExp(r'(\d{4})\s+Term\s+(\d+)\s*\((\w+)\)',
//                 caseSensitive: false);

//             final matchA = termRegex.firstMatch(a.key);
//             final matchB = termRegex.firstMatch(b.key);

//             if (matchA == null || matchB == null) return a.key.compareTo(b.key);

//             final yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
//             final yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;

//             final termA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
//             final termB = int.tryParse(matchB.group(2) ?? '0') ?? 0;

//             final monthA = monthMap[(matchA.group(3) ?? '').toLowerCase()] ?? 0;
//             final monthB = monthMap[(matchB.group(3) ?? '').toLowerCase()] ?? 0;

//             // Compare year first, then term, then month
//             if (yearA != yearB) return yearA.compareTo(yearB);
//             if (termA != termB) return termA.compareTo(termB);
//             return monthA.compareTo(monthB);
//           });
//           final previewParts = nonZeroArrears.map((e) {
//             final display = e.key;
//             return '$display (\$${e.value.toStringAsFixed(2)})';
//           }).join(', ');

//           final arrearsPreview = '($previewParts)';
//           resultList.add({
//             'purpose': purpose,
//             'arrears': {for (var e in nonZeroArrears) e.key: e.value},
//             'arrearsPreview': arrearsPreview,
//           });
//         }
//       } catch (e) {
//         debugPrint(
//             '⚠️ Failed arrears preview for ${purpose.paymentPurpose}: $e');
//       }
//     }

//     return resultList;
//   }

//   Future<List<Map<String, dynamic>>>
//       _fetchUniquePaymentPurposesByStudentWithArrearsForPreviwNew(
//           Student student) async {
//     final List<PaymentPurpose> allPurposes;

//     if (_role == DeviceRole.host) {
//       final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
//       allPurposes = box.values.toList();
//     } else {
//       if (_cachedServerStudentPaymentPurposes == null) {
//         final prefs = await SharedPreferences.getInstance();
//         final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonStr = await response.transform(utf8.decoder).join();
//           final list = jsonDecode(jsonStr) as List;

//           _cachedServerStudentPaymentPurposes = list
//               .map((json) =>
//                   paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//         } else {
//           throw Exception('Failed to fetch payment purposes from server.');
//         }
//       }
//       allPurposes = _cachedServerStudentPaymentPurposes!;
//     }

//     final Set<String> seenPurposeNames = {};
//     final List<PaymentPurpose> filtered = [];

//     for (final purpose in allPurposes) {
//       final isForClass =
//           purpose.associatedClasses?.contains(student.class_) ?? false;

//       final isException = purpose.exceptions?.any(
//             (e) =>
//                 student.exceptions
//                     ?.any((s) => s.exceptionId == e.exceptionId) ??
//                 false,
//           ) ??
//           false;

//       bool isNewcomerRelated = purpose.forNewcomersOnly == true;
//       bool newcomerConditionAllows = true;

//       if (isNewcomerRelated) {
//         if (student.isNewComer != true) {
//           newcomerConditionAllows = false;
//         } else if (student.isNewComerUntil != null) {
//           final newcomerUntil = student.isNewComerUntil!;
//           final term = _termsMap[purpose.termId];
//           if (term != null && term.startDate.isAfter(newcomerUntil)) {
//             newcomerConditionAllows = false;
//           }
//         }
//       }

//       final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
//           newcomerConditionAllows;

//       if (shouldInclude) {
//         final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
//         if (!seenPurposeNames.contains(nameKey)) {
//           seenPurposeNames.add(nameKey);
//           filtered.add(purpose);
//         }
//       }
//     }

//     // ------------------------------------------------------------
//     // STEP 2: Compute arrears & build preview string
//     // ------------------------------------------------------------
//     final List<Map<String, dynamic>> result = [];

//     for (final purpose in filtered) {
//       // ← Use 'filtered' instead of 'allPurposes'
//       Map<String, double> arrearsDetails =
//           await _computeArrearsForPurpose(purpose);
//       // Build list of sub-purposes with term IDs

//       // ✅ Apply any updated remaining amounts from the cache
//       final purposeKey = purpose.paymentPurpose ?? purpose.id.toString();
//       final cachedUpdates = _updatedArrearsCache[purposeKey];

//       if (cachedUpdates != null) {
//         for (var entry in cachedUpdates.entries) {
//           final termId = entry.key;
//           final remainingAmount = entry.value;

//           if (remainingAmount <= 0) {
//             arrearsDetails.remove(termId);
//           } else {
//             arrearsDetails[termId] = remainingAmount;
//           }
//         }
//       }
//       final List<Map<String, dynamic>> subPurposesWithTerms = [];

//       for (final entry in arrearsDetails.entries) {
//         if (entry.value > 0) {
//           // ← Only add if amount > 0
//           subPurposesWithTerms.add({
//             'termId': entry.key,
//             'amount': entry.value,
//             'preview': '${entry.key} (\$${entry.value.toStringAsFixed(2)})',
//           });
//         }
//       }

//       // ← ONLY add to result if there are sub-purposes
//       if (subPurposesWithTerms.isNotEmpty) {
//         result.add({
//           'purpose': purpose,
//           'subPurposesWithTerms': subPurposesWithTerms,
//           'arrearsPreview':
//               subPurposesWithTerms.map((e) => e['preview']).join(', '),
//         });
//       }
//     }

//     return result;
//   }

//   double getAdjustedArrear(
//       double arrear, Student student, PaymentPurpose purpose, String termId) {
//     final studentExceptions = student.exceptions ?? [];
//     final applicablePurposeExceptions = purpose.exceptions ?? [];

//     double totalDeduction = 0.0;

//     for (var studentException in studentExceptions) {
//       if (studentException.exceptionStatus?.toLowerCase() != 'active') continue;

//       if (!(studentException.terms?.any(
//               (t) => t.trim().toLowerCase() == termId.trim().toLowerCase()) ??
//           false)) continue;

//       final isLinkedToPurpose = applicablePurposeExceptions
//           .any((pEx) => pEx.exceptionId == studentException.exceptionId);
//       if (!isLinkedToPurpose) continue;

//       final double? figure =
//           double.tryParse(studentException.exceptionFigure ?? '');
//       if (figure == null) continue;

//       if (studentException.exceptionType?.toLowerCase() == 'amount') {
//         totalDeduction += figure;
//       } else if (studentException.exceptionType?.toLowerCase() ==
//           'percentage') {
//         final percent = (figure / 100) * purpose.purposeAmount;
//         totalDeduction += percent;
//       }
//     }

//     final beforeClamp = arrear - totalDeduction;

//     // safer than clamp()
//     final adjusted = max(0.0, beforeClamp);
//     return adjusted;
//   }

//   Future<List<PaymentPurpose>> _fetchPaymentPurposesByClass(
//       String termId, String class_) async {
//     if (termId.isEmpty || class_.isEmpty) {
//       return [];
//     }

//     List<PaymentPurpose> allPurposes;

//     if (_role == DeviceRole.host) {
//       final paymentPurposeBox =
//           await Hive.openBox<PaymentPurpose>('payment_purposes');
//       allPurposes = paymentPurposeBox.values.toList();
//     } else {
//       if (_cachedServerStudentPaymentPurposes == null) {
//         final prefs = await SharedPreferences.getInstance();
//         final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonStr = await response.transform(utf8.decoder).join();
//           final list = jsonDecode(jsonStr) as List;

//           _cachedServerStudentPaymentPurposes = list
//               .map((json) =>
//                   paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//         } else {
//           throw Exception('Failed to fetch payment purposes from server.');
//         }
//       }

//       allPurposes = _cachedServerStudentPaymentPurposes!;
//     }

//     // Filter for the given term and class
//     final allPaymentPurposes = allPurposes.where((purpose) {
//       return purpose.termId == termId &&
//           (purpose.associatedClasses?.contains(class_) ?? false);
//     }).toList();

//     return allPaymentPurposes;
//   }

//   bool _isCheckingArrears = false; // Prevent duplicate execution
//   Map<String, double> _arrearsDetails = {}; // Store term and arrears amount
//   double _sumPaymentsFromHive({
//     required List<StudentPayment> studentPayments,
//     required String termId,
//     required String purposeName,
//   }) {
//     if (_selectedStudent == null) return 0.0;

//     return studentPayments
//         .where((payment) =>
//             payment.termId == termId &&
//             payment.paymentPurpose.toLowerCase() == purposeName.toLowerCase() &&
//             payment.studentName.toLowerCase() ==
//                 _selectedStudent!.name.toLowerCase() &&
//             payment.studentSurname.toLowerCase() ==
//                 _selectedStudent!.surname.toLowerCase())
//         .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));
//   }

//   double _sumPaymentsFromSession({
//     required String termId,
//     required String purposeName,
//   }) {
//     return _paymentPurposes
//         .where((p) =>
//             p['termId'] == termId &&
//             p['purpose'].paymentPurpose.toLowerCase() ==
//                 purposeName.toLowerCase())
//         .fold(0.0, (sum, p) => sum + (p['amount'] as double));
//   }

//   Future<void> _checkArrears(PaymentPurpose selectedPurpose) async {
//     if (_isCheckingArrears) return;
//     setState(() {
//       _isCheckingArrears = true;
//       setState(() {
//         _arrearsDetails.clear();
//         _arrearsTerms.clear();
//       });
//     });

//     final List<Terms> allTerms = _role == DeviceRole.host
//         ? Hive.box<Terms>('terms').values.toList()
//         : _cachedServerTerms ?? [];

//     _arrearsDetails.clear();
//     List<String> overdueTerms = [];

//     for (final term in allTerms) {
//       if (!_selectedStudent!.terms!.contains(term.termId)) continue;

//       // Fetch purposes specifically for this term
//       final termPurposes = await _fetchPaymentPurposesByTerm(term.termId);

// // Find matching purpose for this term by name
//       final matchingPurpose = termPurposes.firstWhere(
//         (p) =>
//             p.paymentPurpose.toLowerCase() ==
//             selectedPurpose.paymentPurpose.toLowerCase(),
//         orElse: () => PaymentPurpose(
//           paymentPurpose: 'N/A',
//           associatedClasses: [],
//           id: 0,
//           purposeAmount: 0.0,
//         ),
//       );

//       if (matchingPurpose.paymentPurpose == 'N/A') continue;

//       // Validate class association
//       final isClassMatch = matchingPurpose.associatedClasses
//               ?.contains(_selectedStudent!.class_) ??
//           false;
//       if (!isClassMatch) continue;

//       // Apply newcomer condition check
//       final isNewcomer = selectedPurpose.forNewcomersOnly == true;
//       final termStartDate = term.startDate;
//       final termEndDate = term.endDate;

//       bool isNewcomerValid = true;

//       if (isNewcomer) {
//         if (termEndDate != null) {
//           if (_selectedStudent?.isNewComer != true ||
//               _selectedStudent?.isNewComerUntil == null ||
//               termStartDate.isAfter(_selectedStudent!.isNewComerUntil!) ||
//               termEndDate.isBefore(_selectedStudent!.isNewComerFrom!)) {
//             isNewcomerValid = false;
//           }
//         } else if (_selectedStudent?.isNewComer != true ||
//             _selectedStudent?.isNewComerUntil == null ||
//             termStartDate.isAfter(_selectedStudent!.isNewComerUntil!)) {
//           isNewcomerValid = false;
//         }
//       }

//       if (!isNewcomerValid) continue;

//       final allStudentPayments = _role == DeviceRole.host
//           ? Hive.box<StudentPayment>('student_payments').values.toList()
//           : _cachedServerStudentPayments ?? [];
//       // Calculate paid amounts
//       final double hivePaid = _sumPaymentsFromHive(
//         studentPayments: allStudentPayments,
//         termId: term.termId,
//         purposeName: selectedPurpose.paymentPurpose,
//       );

//       final double sessionPaid = _sumPaymentsFromSession(
//         termId: term.termId,
//         purposeName: selectedPurpose.paymentPurpose,
//       );

//       final totalPaid = hivePaid + sessionPaid;
//       double arrears = matchingPurpose.purposeAmount - totalPaid;

//       arrears = getAdjustedArrear(
//         arrears,
//         _selectedStudent!,
//         matchingPurpose,
//         term.termId,
//       );

//       if (arrears > 0) {
//         overdueTerms.add(term.termId);
//         _arrearsDetails[term.termId] = arrears;
//       }
//     }

//     setState(() {
//       _arrearsTerms = overdueTerms;
//       _isCheckingArrears = false;
//     });
//   }

//   Future<Map<String, double>> _computeArrearsForPurpose(
//       PaymentPurpose selectedPurpose) async {
//     final List<Terms> allTerms = _role == DeviceRole.host
//         ? Hive.box<Terms>('terms').values.toList()
//         : _cachedServerTerms ?? [];

//     // Get excluded future term IDs
//     final excludedTermIds = _getExcludedFutureTermIds();

//     final Map<String, double> arrearsDetails = {};

//     for (final term in allTerms) {
//       // Skip future terms
//       if (excludedTermIds.contains(term.termId)) {
//         continue;
//       }
//       // Skip terms that are not in the selected filter terms (if any are selected)
//       if (_selectedFilterTerms.isNotEmpty &&
//           !_selectedFilterTerms.contains(term.termId)) {
//         continue;
//       }
//       if (!_selectedStudent!.terms!.contains(term.termId)) continue;

//       final termPurposes = await _fetchPaymentPurposesByTerm(term.termId);

//       final matchingPurpose = termPurposes.firstWhere(
//         (p) =>
//             p.paymentPurpose.toLowerCase() ==
//             selectedPurpose.paymentPurpose.toLowerCase(),
//         orElse: () => PaymentPurpose(
//           paymentPurpose: 'N/A',
//           associatedClasses: [],
//           id: 0,
//           purposeAmount: 0.0,
//         ),
//       );

//       if (matchingPurpose.paymentPurpose == 'N/A') continue;

//       final isClassMatch = matchingPurpose.associatedClasses
//               ?.contains(_selectedStudent!.class_) ??
//           false;
//       if (!isClassMatch) continue;

//       // Apply newcomer condition check
//       final isNewcomer = selectedPurpose.forNewcomersOnly == true;
//       final termStartDate = term.startDate;
//       final termEndDate = term.endDate;

//       bool isNewcomerValid = true;
//       if (isNewcomer) {
//         if (termEndDate != null) {
//           if (_selectedStudent?.isNewComer != true ||
//               _selectedStudent?.isNewComerUntil == null ||
//               termStartDate.isAfter(_selectedStudent!.isNewComerUntil!) ||
//               termEndDate.isBefore(_selectedStudent!.isNewComerFrom!)) {
//             isNewcomerValid = false;
//           }
//         } else if (_selectedStudent?.isNewComer != true ||
//             _selectedStudent?.isNewComerUntil == null ||
//             termStartDate.isAfter(_selectedStudent!.isNewComerUntil!)) {
//           isNewcomerValid = false;
//         }
//       }

//       if (!isNewcomerValid) continue;

//       final allStudentPayments = _role == DeviceRole.host
//           ? Hive.box<StudentPayment>('student_payments').values.toList()
//           : _cachedServerStudentPayments ?? [];

//       final double hivePaid = _sumPaymentsFromHive(
//         studentPayments: allStudentPayments,
//         termId: term.termId,
//         purposeName: selectedPurpose.paymentPurpose,
//       );

//       final double sessionPaid = _sumPaymentsFromSession(
//         termId: term.termId,
//         purposeName: selectedPurpose.paymentPurpose,
//       );

//       final totalPaid = hivePaid + sessionPaid;
//       double arrears = matchingPurpose.purposeAmount - totalPaid;

//       arrears = getAdjustedArrear(
//         arrears,
//         _selectedStudent!,
//         matchingPurpose,
//         term.termId,
//       );

//       if (arrears > 0) {
//         arrearsDetails[term.termId] = arrears;
//       }
//     }

//     return arrearsDetails;
//   }

//   Future<List<PaymentPurpose>> _fetchPaymentPurposesByTerm(
//       String termId) async {
//     List<PaymentPurpose> allPurposes = [];

//     if (_role == DeviceRole.host) {
//       final box = Hive.box<PaymentPurpose>('payment_purposes');
//       allPurposes = box.values.toList();
//     } else {
//       if (_cachedServerStudentPaymentPurposes == null) {
//         final prefs = await SharedPreferences.getInstance();
//         final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

//         final response = await HttpClient()
//             .getUrl(Uri.parse('http://$hostIp:8080/api/paymentPurposes'))
//             .then((req) => req.close());

//         if (response.statusCode == 200) {
//           final jsonStr = await response.transform(utf8.decoder).join();
//           final list = jsonDecode(jsonStr) as List;
//           _cachedServerStudentPaymentPurposes = list
//               .map((json) =>
//                   paymentPurposesFromJson(Map<String, dynamic>.from(json)))
//               .toList();
//         }
//       }
//       allPurposes = _cachedServerStudentPaymentPurposes ?? [];
//     }

//     // ✅ ONLY exclude future terms for teachers
//     if (_isTeacher()) {
//       final excludedTermIds = _getExcludedFutureTermIds();
//       return allPurposes
//           .where((purpose) =>
//               purpose.termId == termId && !excludedTermIds.contains(termId))
//           .toList();
//     } else {
//       // ✅ Non-teachers see ALL purposes for the term
//       return allPurposes.where((purpose) => purpose.termId == termId).toList();
//     }
//   }

//   // Method to handle search
//   void _performSearch(String query) {
//     if (query.isEmpty) return;
//     _onSearchSubmitted(query);
//   }

//   // Handle keyboard events for Windows
//   void _handleKeyEvent(RawKeyEvent event) {
//     if (Theme.of(context).platform == TargetPlatform.windows &&
//         event is RawKeyDownEvent &&
//         event.logicalKey == LogicalKeyboardKey.enter) {
//       // Check if the search field is focused
//       if (_searchFocusNode.hasFocus) {
//         _performSearch(_studentSearchController.text.trim());
//       }
//     }
//   }

// // Add this helper method to mask phone numbers
//   String _maskPhoneNumber(String? phoneNumber) {
//     if (phoneNumber == null || phoneNumber.isEmpty) {
//       return 'N/A';
//     }

//     // Remove any non-digit characters (spaces, dashes, etc.)
//     String cleaned = phoneNumber.replaceAll(RegExp(r'\D'), '');

//     // Check if it has at least 10 digits
//     if (cleaned.length >= 10) {
//       // Keep last 4 digits, mask the rest with stars
//       String last4 = cleaned.substring(cleaned.length - 4);
//       String masked = '*' * (cleaned.length - 4) + last4;

//       // Re-insert any original formatting? Just return masked digits
//       return masked;
//     } else {
//       // Invalid or too short, return as is
//       return phoneNumber;
//     }
//   }

// // Build statement lines using the package's LineText class
//   List<LineText> _buildStatementLines({
//     required School schoolInfo,
//     required Student selectedStudent,
//     required double feesArrears,
//     required double totalProjectArrears,
//     required double grandTotal,
//     required List<Map<String, dynamic>> purposeList,
//     required List<ArrearsSummary> projectArrearsDetails,
//     required String generatedBy,
//   }) {
//     List<LineText> lines = [];

//     // Helper function to add text line using package's LineText
//     void addLine(
//       String content, {
//       int align = LineText.ALIGN_LEFT,
//       int linefeed = 1,
//       int fontZoom = 0,
//       int weight = 0,
//       bool underline = false,
//     }) {
//       lines.add(LineText(
//         type: LineText.TYPE_TEXT,
//         content: content,
//         align: align,
//         linefeed: linefeed,
//         fontZoom: fontZoom,
//         weight: weight,
//         underline: underline ? 1 : 0,
//       ));
//     }

//     // Helper function to add divider
//     void addDivider({String char = '-', int length = 42}) {
//       addLine(char * length, align: LineText.ALIGN_CENTER);
//     }

//     // Header Section
//     addLine('ARREARS STATEMENT',
//         align: LineText.ALIGN_CENTER,
//         linefeed: 2,
//         fontZoom: 2,
//         weight: 1,
//         underline: true);

//     addLine('', linefeed: 1);
//     addLine('', linefeed: 1);
//     addLine(' ${schoolInfo.schoolName?.toUpperCase() ?? ""}',
//         align: LineText.ALIGN_CENTER, weight: 2);
//     addLine(' ${schoolInfo.schoolAddress?.toUpperCase() ?? ""}',
//         align: LineText.ALIGN_CENTER);
//     addLine(' ${schoolInfo.schoolPhoneNumber ?? ""}',
//         align: LineText.ALIGN_CENTER);
//     addLine(' ${schoolInfo.schoolEmail ?? ""}',
//         align: LineText.ALIGN_CENTER, underline: true);
//     addDivider();

//     // Student Information Section
//     addLine('STUDENT INFORMATION', align: LineText.ALIGN_CENTER, weight: 2);

//     addDivider();
//     addLine('Name: ${selectedStudent.name} ${selectedStudent.surname}');
//     addLine('Class: ${selectedStudent.class_ ?? 'N/A'}');
//     addLine('Student ID: ${selectedStudent.studentIdNumber}');
//     String maskedPhone = _maskPhoneNumber(selectedStudent.phoneNumber);
//     addLine('Phone Number: $maskedPhone');

//     // Masked emergency contact if valid
//     if (selectedStudent.emergencyContactNumber != null &&
//         selectedStudent.emergencyContactNumber!.isNotEmpty) {
//       String maskedEmergency =
//           _maskPhoneNumber(selectedStudent.emergencyContactNumber);
//       addLine('Emergency:  $maskedEmergency');
//     }

//     addLine('Statement To: ${selectedStudent.paymentStatus ?? 'N/A'}');
//     addDivider();

//     // Payment Purposes Section (with individual amounts on separate lines)
//     if (purposeList.isNotEmpty) {
//       addLine('PAYMENT PURPOSE ARREARS',
//           align: LineText.ALIGN_CENTER, weight: 1, underline: true);
//       addDivider();

//       double totalFeesArrears = 0.0;

//       // Display each purpose on its own line with its amount
//       for (var entry in purposeList) {
//         final purpose = entry['purpose'];
//         final arrearsMap = entry['arrears'] as Map<String, double>? ?? {};

//         // Calculate total arrears for this purpose
//         double purposeTotal =
//             arrearsMap.values.fold(0.0, (sum, amount) => sum + amount);
//         totalFeesArrears += purposeTotal;
//         final preview = entry['arrearsPreview'];
//         // Add purpose name
//         addLine('${purpose.paymentPurpose.toString().toUpperCase() ?? 'N/A'}',
//             weight: 1, align: LineText.ALIGN_CENTER, linefeed: 1);
//         addLine('', linefeed: 1);

//         // Split preview by commas and create new lines for each part
//         if (preview != null && preview.isNotEmpty) {
//           // Remove surrounding parentheses if present
//           String cleanPreview = preview;
//           if (cleanPreview.startsWith('(') && cleanPreview.endsWith(')')) {
//             cleanPreview = cleanPreview.substring(1, cleanPreview.length - 1);
//           }

//           // Split by comma and trim each part
//           List<String> previewParts =
//               cleanPreview.split(',').map((part) => part.trim()).toList();

//           // Add each part as a new line
//           for (String part in previewParts) {
//             if (part.isNotEmpty) {
//               addLine('  $part',
//                   align: LineText.ALIGN_LEFT, linefeed: 1, weight: 1);
//               addLine('', linefeed: 1);
//             }
//           }
//         }
//       }
//       addLine('', linefeed: 1);
//       // Display purpose with its individual amount

//       addLine('', linefeed: 0);
//       addLine('', linefeed: 1);
//       addLine('TOTAL FEES ARREARS: \$${totalFeesArrears.toStringAsFixed(2)}',
//           align: LineText.ALIGN_RIGHT, weight: 1);
//       addLine('', linefeed: 1);
//     }
//     addDivider();
//     // Project Arrears Details Section
//     if (projectArrearsDetails.isNotEmpty) {
//       addLine('PROJECT ARREARS DETAILS',
//           align: LineText.ALIGN_CENTER, weight: 1, underline: true);
//       addDivider();

//       // Header
//       addLine('Project'.padRight(25) + 'Amount'.padLeft(15), weight: 1);
//       addLine('', linefeed: 1);

//       for (var detail in projectArrearsDetails) {
//         String projectLine = '${detail.projectName} - ${detail.itemName}';
//         if (projectLine.length > 25) {
//           projectLine = projectLine.substring(0, 22) + '...';
//         }
//         String amountLine = _formatCurrency(detail.arrears);
//         addLine(projectLine.padRight(25) + amountLine.padLeft(15));
//         addLine('', linefeed: 1);
//       }

//       addLine('', linefeed: 1);
//       addLine('TOTAL PROJECT ARREARS: ${_formatCurrency(totalProjectArrears)}',
//           align: LineText.ALIGN_RIGHT, weight: 1);
//       addLine('', linefeed: 1);
//     }

//     addLine('', linefeed: 1);
//     addDivider();

//     // Arrears Overview Section
//     addLine('TOTAL ARREARS OVERVIEW',
//         align: LineText.ALIGN_CENTER, weight: 1, underline: true);
//     addDivider();
//     addLine('Fees Arrears: ${_formatCurrency(feesArrears)}',
//         align: LineText.ALIGN_RIGHT);
//     if (totalProjectArrears > 0) {
//       addLine('Project Arrears: ${_formatCurrency(totalProjectArrears)}',
//           align: LineText.ALIGN_RIGHT);
//     }
//     addLine('', linefeed: 1);

//     addLine('GRAND TOTAL ARREARS: ${_formatCurrency(grandTotal)}',
//         align: LineText.ALIGN_RIGHT, weight: 1);
//     addLine('', linefeed: 1);

//     // Footer Section
//     addDivider(char: '=', length: 42);
//     addLine('', linefeed: 1);
//     addLine('GENERATED ON', align: LineText.ALIGN_CENTER, weight: 1);
//     addLine(_formatDateTime(DateTime.now()), align: LineText.ALIGN_CENTER);
//     addLine('', linefeed: 1);
//     addLine('GENERATED BY', align: LineText.ALIGN_CENTER, weight: 1);
//     addLine(generatedBy.toUpperCase(), align: LineText.ALIGN_CENTER);
//     addLine('', linefeed: 1);
//     addDivider(char: '*', length: 42);
//     addLine('This is a computer-generated statement',
//         align: LineText.ALIGN_CENTER);
//     addLine('No signature required', align: LineText.ALIGN_CENTER);
//     addDivider(char: '*', length: 42);
//     addLine('', linefeed: 2);
//     addLine('', linefeed: 2);
//     addLine('', linefeed: 2);

//     return lines;
//   }

//   /// 🆕 Show Windows printer connection dialog
//   Future<void> _showWindowsPrinterConnectionDialog() async {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Windows Printer Not Connected'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.print_disabled, size: 64, color: Colors.red),
//             SizedBox(height: 16),
//             Text('Please select and connect to a Windows printer first'),
//             SizedBox(height: 8),
//             Text('Use the printer selector and Connect button above'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Please select a printer and click Connect'),
//                   duration: Duration(seconds: 3),
//                 ),
//               );
//             },
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   /// 🆕 Print to Windows printer
//   Future<void> _printToWindowsPrinter(List<LineText> statementLines) async {
//     if (_selectedWindowsPrinter == null) {
//       throw Exception('No Windows printer selected');
//     }

//     if (!_connected) {
//       throw Exception('Windows printer not connected. Please connect first.');
//     }

//     // Generate plain text from LineText objects
//     StringBuffer textBuffer = StringBuffer();

//     for (var line in statementLines) {
//       if (line.type == LineText.TYPE_TEXT) {
//         final content = line.content ?? '';
//         textBuffer.writeln(content);

//         // Add extra line feeds
//         for (int i = 0; i < (line.linefeed ?? 1) - 1; i++) {
//           textBuffer.writeln('');
//         }
//       }
//     }

//     final plainText = textBuffer.toString();
//     final bytes = utf8.encode(plainText);

//     // Send to Windows printer
//     await WindowsPrinterHelper.printToWindowsPrinter(
//       _selectedWindowsPrinter!,
//       bytes,
//     );
//   }

// // Format currency
//   String _formatCurrency(double amount) {
//     return '\$${amount.toStringAsFixed(2)}';
//   }

// // Format date time
//   String _formatDateTime(DateTime date) {
//     return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
//   }

// // Show Bluetooth connection dialog
//   // Show Bluetooth connection dialog
//   Future<void> _showBluetoothConnectionDialog() async {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Bluetooth Printer Not Connected'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
//             SizedBox(height: 16),
//             Text('Please connect to a Bluetooth printer first'),
//             SizedBox(height: 8),
//             Text('Use the Connect button below to pair your printer'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               // The user can manually connect using the existing Connect button in the UI
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content:
//                       Text('Please select a printer and click Connect above'),
//                   duration: Duration(seconds: 3),
//                 ),
//               );
//             },
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _resetPaymentData() {
//     setState(() {
//       _paymentPurposes.clear();
//       _selectedSubPurposes.clear();
//       _selectedPaymentPurpose = null;
//       _selectedArrearsTerm = null;
//       _paymentAmount = null;
//       _paymentAmountController.clear();
//       _pmAmountCtrl.clear();
//       _cachedTotalEntered = 0.0;
//       _updatedArrearsCache.clear();
//       _purposeListVersion++; // Force refresh
//     });
//   }

//   void _clearSelections() {
//     setState(() {
//       _selectedSubPurposes.clear();
//       _selectedPaymentPurpose = null;
//       _selectedArrearsTerm = null;
//       _paymentAmount = null;
//       _paymentAmountController.clear();
//     });
//   }

//   void _clearAllServerCaches() {
//     _cachedServerStudentPayments = null;
//     _cachedServerTerms = null;
//     _cachedServerStudentPaymentPurposes = null;
//     _cachedServerStudents = null;
//     _cachedServerSchoolInfo = null;
//     _cachedFilteredStudents = null;
//     _cachedServerProjects = null;
//     _cachedServerProjectItems = null;
//     _cachedProductBatches = null;
//     _cachedBatchSellUnits = null;

//     @override
//     void dispose() {
//       _pmAmountDebounceTimer?.cancel();
//       _pmAmountFocusNode.dispose();
//       _focusManager.dispose();

//       for (var controller in _amountControllers.values) {
//         controller.dispose();
//       }
//       _amountControllers.clear();
//       bluetoothHelper.dispose(); // Properly dispose of BluetoothHelper

//       _paymentAmountController.dispose();
//       _studentSearchController.dispose();
//       _searchFocusNode.dispose();
//       _searchDebounce?.cancel();

//       super.dispose();
//     }
//   }
// }

// // ==================== ARREARS SECTION WIDGET ====================
// class ArrearsSection extends StatefulWidget {
//   final Student student;
//   final int version;
//   final Function(List<Map<String, dynamic>>) onItemsSelected;
//   final Map<String, List<bool>> Function() getSelectedSubPurposes;
//   final void Function(Map<String, List<bool>>) setSelectedSubPurposes;
//   final Future<List<Map<String, dynamic>>> Function(Student)
//       fetchArrears; // Add this
//   final List<Map<String, dynamic>> restoredItems; // Add this
//   final VoidCallback? onRefreshRequested; // Add this callback
//   final VoidCallback? onScrollToConfirmButton; // Add this (replace or add new)

//   const ArrearsSection({
//     Key? key,
//     required this.student,
//     required this.version,
//     required this.onItemsSelected,
//     required this.getSelectedSubPurposes,
//     required this.setSelectedSubPurposes,
//     required this.fetchArrears, // Add this
//     this.restoredItems = const [], // Add this
//     this.onRefreshRequested, // Add this
//     this.onScrollToConfirmButton,
//   }) : super(key: key);

//   @override
//   State<ArrearsSection> createState() => _ArrearsSectionState();
// }

// class _ArrearsSectionState extends State<ArrearsSection> {
//   List<Map<String, dynamic>> _purposeList = [];
//   bool _isLoading = true;
//   String? _error;
//   Map<String, List<bool>> _selectedSubPurposes = {};
//   void refresh() {
//     _loadData();
//   }

// // Add this method to ArrearsSectionState
//   List<Map<String, dynamic>> getCurrentArrearsData() {
//     return _purposeList;
//   }

//   Future<List<Map<String, dynamic>>> refreshAndGetData() async {
//     await _loadData();
//     return _purposeList;
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   @override
//   void didUpdateWidget(ArrearsSection oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     // Also check if restoredItems changed
//     if (oldWidget.student != widget.student ||
//         oldWidget.version != widget.version ||
//         oldWidget.restoredItems.length != widget.restoredItems.length) {
//       _loadData();
//     }
//   }

//   Future<void> _loadData() async {
//     setState(() {
//       _isLoading = true;
//       _error = null;
//       // CRITICAL: Clear selections first to avoid stale data
//       _selectedSubPurposes.clear();
//     });

//     try {
//       final data = await widget.fetchArrears(widget.student);

//       setState(() {
//         _purposeList = data;
//         _isLoading = false;
//       });

//       // Initialize selections AFTER purposeList is updated
//       _initializeSelections();

//       // Notify parent after successful load
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         widget.onRefreshRequested?.call();
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _isLoading = false;
//       });
//     }
//   }

//   void _initializeSelections() {
//     // Clear existing selections
//     _selectedSubPurposes.clear();

//     if (_purposeList.isEmpty) {
//       return;
//     }

//     for (int i = 0; i < _purposeList.length; i++) {
//       final purposeData = _purposeList[i];
//       final preview = purposeData['arrearsPreview'] ?? '';

//       if (preview.isEmpty) {
//         continue;
//       }

//       final subPurposes = preview.split(',').map((s) => s.trim()).toList();
//       final purposeKey = purposeData['purpose'].paymentPurpose ?? 'purpose_$i';

//       // Create a fresh list with the correct length
//       _selectedSubPurposes[purposeKey] =
//           List<bool>.filled(subPurposes.length, false);
//     }

//     // Update parent with current selections
//     widget.setSelectedSubPurposes(_selectedSubPurposes);
//   }

//   void _selectAllPurposes(bool select) {
//     setState(() {
//       for (int i = 0; i < _purposeList.length; i++) {
//         final purposeData = _purposeList[i];
//         final preview = purposeData['arrearsPreview'] ?? '';
//         if (preview.isEmpty) continue;

//         final subPurposes = preview.split(',').map((s) => s.trim()).toList();
//         final purposeKey =
//             purposeData['purpose'].paymentPurpose ?? 'purpose_$i';

//         // Always create a new list with the correct length
//         _selectedSubPurposes[purposeKey] =
//             List<bool>.filled(subPurposes.length, select);
//       }
//       widget.setSelectedSubPurposes(_selectedSubPurposes);
//     });
//   }

//   List<Map<String, dynamic>> getSelectedItems() {
//     List<Map<String, dynamic>> selectedItems = [];

//     for (int i = 0; i < _purposeList.length; i++) {
//       final purposeData = _purposeList[i];
//       final purpose = purposeData['purpose'];
//       final subPurposesWithTerms =
//           purposeData['subPurposesWithTerms'] as List<Map<String, dynamic>>? ??
//               [];
//       final purposeKey = purpose.paymentPurpose ?? 'purpose_$i';

//       final selections = _selectedSubPurposes[purposeKey] ?? [];

//       // Ensure selections length matches
//       if (selections.length != subPurposesWithTerms.length &&
//           subPurposesWithTerms.isNotEmpty) {
//         // Reinitialize if mismatch
//         _selectedSubPurposes[purposeKey] =
//             List<bool>.filled(subPurposesWithTerms.length, false);
//         widget.setSelectedSubPurposes(_selectedSubPurposes);
//         continue;
//       }

//       for (int j = 0;
//           j < selections.length && j < subPurposesWithTerms.length;
//           j++) {
//         if (selections[j]) {
//           final subData = subPurposesWithTerms[j];
//           selectedItems.add({
//             'purpose': purpose,
//             'subPurpose': subData['preview'],
//             'amount': subData['amount'],
//             'termId': subData['termId'],
//           });
//         }
//       }
//     }
//     return selectedItems;
//   }

//   double _calculateOverallTotal(List<Map<String, dynamic>> purposeList) {
//     double overallTotal = 0.0;

//     try {
//       for (var entry in purposeList) {
//         final String preview = entry['arrearsPreview'];
//         if (preview.isEmpty) continue;

//         final List<String> subPurposes = preview
//             .split(',')
//             .map((s) => s.trim())
//             .where((s) => s.isNotEmpty)
//             .toList();

//         for (var subPurpose in subPurposes) {
//           try {
//             // Look for pattern like [$50] or [$75.50] or $50
//             final RegExp regex =
//                 RegExp(r'\[\$(\d+(?:\.\d+)?)\]|\$(\d+(?:\.\d+)?)');
//             final match = regex.firstMatch(subPurpose);
//             if (match != null) {
//               String amountStr = match.group(1) ?? match.group(2) ?? '';
//               if (amountStr.isNotEmpty) {
//                 overallTotal += double.parse(amountStr);
//               }
//             } else {
//               // Fallback: try to find any number
//               final fallbackRegex = RegExp(r'(\d+(?:\.\d+)?)');
//               final fallbackMatch = fallbackRegex.firstMatch(subPurpose);
//               if (fallbackMatch != null) {
//                 overallTotal += double.parse(fallbackMatch.group(1)!);
//               }
//             }
//           } catch (e) {
//             print('Error parsing sub-purpose: "$subPurpose" - $e');
//             continue;
//           }
//         }
//       }
//     } catch (e) {
//       print('Error calculating overall total: $e');
//     }

//     return overallTotal;
//   }

//   String _formatCurrency(double amount) {
//     return '\$${amount.toStringAsFixed(2)}';
//   }

//   void _proceedWithSelected() {
//     final selectedItems = getSelectedItems();

//     if (selectedItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select at least one item')),
//       );
//       return;
//     }

//     widget.onItemsSelected(selectedItems);
//     _selectAllPurposes(false);
//     widget.onRefreshRequested?.call();

//     // Scroll to Confirm Payment button instead
//     widget.onScrollToConfirmButton?.call(); // Change this
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (_error != null) {
//       return Text('Error: $_error');
//     }

//     if (_purposeList.isEmpty) {
//       return const Text('No Arrears found for this student.');
//     }

//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 10),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "📊 Fees Arrears Overview",
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             const SizedBox(height: 10),

// // Responsive Overall Total and Buttons Section
//             Container(
//               margin: const EdgeInsets.only(bottom: 16),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Colors.blue.shade50, Colors.indigo.shade50],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.blue.shade200),
//               ),
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   // Check if screen is small (width < 500)
//                   final isSmallScreen = constraints.maxWidth < 500;

//                   if (isSmallScreen) {
//                     // Column layout for small screens
//                     return Column(
//                       children: [
//                         // Total Amount Section
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.5),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 "Overall Total Arrears",
//                                 style:
//                                     TextStyle(fontSize: 12, color: Colors.grey),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 _formatCurrency(
//                                     _calculateOverallTotal(_purposeList)),
//                                 style: const TextStyle(
//                                   fontSize: 24,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.indigo,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     );
//                   } else {
//                     // Row layout for larger screens
//                     return Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           flex: 2,
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 "Overall Total Arrears",
//                                 style:
//                                     TextStyle(fontSize: 12, color: Colors.grey),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 _formatCurrency(
//                                     _calculateOverallTotal(_purposeList)),
//                                 style: const TextStyle(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.indigo,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 16),
//                         Row(
//                           children: [
//                             OutlinedButton(
//                               onPressed: () => _selectAllPurposes(true),
//                               style: OutlinedButton.styleFrom(
//                                 side: const BorderSide(color: Colors.green),
//                                 foregroundColor: Colors.green,
//                               ),
//                               child: const Text("Select All"),
//                             ),
//                             const SizedBox(width: 8),
//                             OutlinedButton(
//                               onPressed: () => _selectAllPurposes(false),
//                               style: OutlinedButton.styleFrom(
//                                 side: const BorderSide(color: Colors.red),
//                                 foregroundColor: Colors.red,
//                               ),
//                               child: const Text("Deselect All"),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(width: 16),
//                         ElevatedButton.icon(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 16, vertical: 12),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                           ),
//                           onPressed: _proceedWithSelected,
//                           icon: const Icon(Icons.payment, size: 18),
//                           label: const Text(
//                             "PROCEED",
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold, fontSize: 14),
//                           ),
//                         ),
//                       ],
//                     );
//                   }
//                 },
//               ),
//             ),

//             // Purpose List Section
//             ..._purposeList.asMap().entries.expand((purposeEntry) {
//               final int purposeIndex = purposeEntry.key;
//               final purposeData = purposeEntry.value;
//               final purpose = purposeData['purpose'];
//               final List<Map<String, dynamic>> subPurposesWithTerms =
//                   purposeData['subPurposesWithTerms'] ?? [];
//               final String purposeKey =
//                   purpose.paymentPurpose ?? 'purpose_$purposeIndex';

//               if (subPurposesWithTerms.isEmpty) return <Widget>[];

//               final Color purposeColor = [
//                 Colors.blue,
//                 Colors.green,
//                 Colors.orange,
//                 Colors.purple,
//                 Colors.teal,
//                 Colors.indigo,
//                 Colors.pink,
//                 Colors.amber
//               ][purposeIndex % 8];
//               final Color lightColor = purposeColor.withOpacity(0.08);
//               final Color borderColor = purposeColor.withOpacity(0.4);
//               final double totalAmount = subPurposesWithTerms.fold(
//                   0.0, (sum, item) => sum + (item['amount'] as double));
//               final bool isAllSelected = _selectedSubPurposes[purposeKey]
//                       ?.every((selected) => selected) ??
//                   false;

//               final headerCard = Container(
//                 margin: const EdgeInsets.only(top: 8, bottom: 4),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [lightColor, lightColor.withOpacity(0.3)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: borderColor),
//                 ),
//                 child: CheckboxListTile(
//                   value: isAllSelected,
//                   onChanged: (bool? checked) {
//                     setState(() {
//                       final currentSelections =
//                           _selectedSubPurposes[purposeKey] ?? [];
//                       _selectedSubPurposes[purposeKey] = List<bool>.filled(
//                           currentSelections.length, checked ?? false);
//                       widget.setSelectedSubPurposes(_selectedSubPurposes);
//                     });
//                   },
//                   activeColor: purposeColor,
//                   checkboxShape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(4)),
//                   title: Text(
//                     purpose.paymentPurpose ?? '',
//                     style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: purposeColor,
//                         fontSize: 16),
//                   ),
//                   subtitle: Text(
//                     "Total Arrears: ${_formatCurrency(totalAmount)}",
//                     style: TextStyle(
//                         color: purposeColor,
//                         fontWeight: FontWeight.w600,
//                         fontSize: 14),
//                   ),
//                   secondary: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                         color: purposeColor,
//                         borderRadius: BorderRadius.circular(20)),
//                     child: Text(_formatCurrency(totalAmount),
//                         style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 14)),
//                   ),
//                 ),
//               );

//               final subCards =
//                   subPurposesWithTerms.asMap().entries.map((subEntry) {
//                 final int subIndex = subEntry.key;
//                 final subData = subEntry.value;
//                 final String subPurposePreview = subData['preview'];
//                 final double subAmount = subData['amount'];

//                 // SAFETY: Get selections for this purpose key
//                 final selections = _selectedSubPurposes[purposeKey];

//                 // If selections don't exist or index is out of range, initialize them
//                 if (selections == null || subIndex >= selections.length) {
//                   if (!_selectedSubPurposes.containsKey(purposeKey)) {
//                     _selectedSubPurposes[purposeKey] =
//                         List<bool>.filled(subPurposesWithTerms.length, false);
//                   }
//                   final currentSelections = _selectedSubPurposes[purposeKey]!;
//                   if (subIndex >= currentSelections.length) {
//                     // Extend the list if needed
//                     _selectedSubPurposes[purposeKey] =
//                         List<bool>.filled(subPurposesWithTerms.length, false);
//                   }
//                   widget.setSelectedSubPurposes(_selectedSubPurposes);
//                 }

//                 final bool isSelected =
//                     (_selectedSubPurposes[purposeKey]?[subIndex] ?? false);

//                 return Container(
//                   margin: const EdgeInsets.only(
//                       left: 16, top: 2, bottom: 2, right: 0),
//                   decoration: BoxDecoration(
//                     color:
//                         isSelected ? lightColor.withOpacity(0.5) : lightColor,
//                     borderRadius: BorderRadius.circular(6),
//                     border: Border.all(
//                       color: isSelected
//                           ? purposeColor
//                           : borderColor.withOpacity(0.3),
//                       width: isSelected ? 1.5 : 0.5,
//                     ),
//                   ),
//                   child: CheckboxListTile(
//                     value: isSelected,
//                     onChanged: (bool? checked) {
//                       // 🆕 CHECK IF ITEM HAS [ or ] characters
//                       if (subPurposePreview.contains('[') ||
//                           subPurposePreview.contains(']')) {
//                         // Show warning dialog
//                         showDialog(
//                           context: context,
//                           builder: (BuildContext context) {
//                             return AlertDialog(
//                               title: const Text('Item Cannot Be Selected'),
//                               content: Text(
//                                 'This item (${subPurposePreview.length > 50 ? subPurposePreview.substring(0, 50) + '...' : subPurposePreview}) already exists as a child in the ready payments section.\n\n'
//                                 'Please modify the amount directly in the payment table instead.',
//                               ),
//                               actions: [
//                                 TextButton(
//                                   onPressed: () => Navigator.pop(context),
//                                   child: const Text('OK',
//                                       style: TextStyle(
//                                           fontWeight: FontWeight.bold)),
//                                 ),
//                               ],
//                             );
//                           },
//                         );
//                         return; // ❌ Prevent selection
//                       }

//                       // Normal selection logic
//                       setState(() {
//                         if (_selectedSubPurposes.containsKey(purposeKey)) {
//                           final currentSelections =
//                               _selectedSubPurposes[purposeKey]!;
//                           if (subIndex < currentSelections.length) {
//                             currentSelections[subIndex] = checked ?? false;
//                             _selectedSubPurposes[purposeKey] =
//                                 List.from(currentSelections);
//                             widget.setSelectedSubPurposes(_selectedSubPurposes);
//                           }
//                         }
//                       });
//                     },
//                     activeColor: purposeColor,
//                     checkboxShape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(4)),
//                     contentPadding:
//                         const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                     title: Text(
//                       subPurposePreview,
//                       style: TextStyle(
//                         fontSize: 13,
//                         fontWeight:
//                             isSelected ? FontWeight.w500 : FontWeight.normal,
//                         // 🆕 ADD STRIKETHROUGH for items with [ or ]
//                         decoration: (subPurposePreview.contains('[') ||
//                                 subPurposePreview.contains(']'))
//                             ? TextDecoration.lineThrough
//                             : TextDecoration.none,
//                         // 🆕 Make text lighter for disabled items
//                         color: (subPurposePreview.contains('[') ||
//                                 subPurposePreview.contains(']'))
//                             ? Colors.grey.shade500
//                             : null,
//                       ),
//                     ),
//                     secondary: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         // 🆕 Different background for disabled items
//                         color: (subPurposePreview.contains('[') ||
//                                 subPurposePreview.contains(']'))
//                             ? Colors.grey.shade200
//                             : purposeColor.withOpacity(isSelected ? 0.2 : 0.1),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: (subPurposePreview.contains('[') ||
//                                   subPurposePreview.contains(']'))
//                               ? Colors.grey.shade400
//                               : purposeColor
//                                   .withOpacity(isSelected ? 0.5 : 0.3),
//                         ),
//                       ),
//                       child: Text(
//                         _formatCurrency(subAmount),
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           // 🆕 Lighter text for disabled items
//                           color: (subPurposePreview.contains('[') ||
//                                   subPurposePreview.contains(']'))
//                               ? Colors.grey.shade500
//                               : purposeColor,
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList();

//               final separator = purposeIndex < _purposeList.length - 1
//                   ? Container(
//                       margin: const EdgeInsets.symmetric(vertical: 8),
//                       height: 1,
//                       color: Colors.grey[300])
//                   : const SizedBox.shrink();

//               return [headerCard, ...subCards, separator];
//             }).toList(),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Add to your state class
// class PrintJob {
//   final String id;
//   final Student student;
//   final DateTime createdAt;
//   PrintStatus status;

//   PrintJob({
//     required this.id,
//     required this.student,
//     required this.createdAt,
//     this.status = PrintStatus.pending,
//   });
// }

// enum PrintStatus { pending, printing, completed, failed }

// class PrintQueueManager {
//   final List<PrintJob> _queue = [];
//   bool _isPrinting = false;

//   List<PrintJob> get queue => List.unmodifiable(_queue);
//   bool get isPrinting => _isPrinting;

//   void addJob(PrintJob job) {
//     _queue.add(job);
//   }

//   void addJobs(List<PrintJob> jobs) {
//     _queue.addAll(jobs);
//   }

//   void removeJob(String id) {
//     _queue.removeWhere((j) => j.id == id);
//   }

//   void clearQueue() {
//     _queue.clear();
//   }

//   Future<void> processQueue(Function(PrintJob) printFunction) async {
//     if (_isPrinting) return;

//     _isPrinting = true;

//     while (_queue.isNotEmpty) {
//       final job = _queue.first;
//       job.status = PrintStatus.printing;

//       try {
//         await printFunction(job);
//         job.status = PrintStatus.completed;
//         _queue.removeAt(0);
//       } catch (e) {
//         job.status = PrintStatus.failed;
//         // Optionally retry or move to failed list
//       }
//     }

//     _isPrinting = false;
//   }
// }

// class ArrearsSummary {
//   final String transactionCode;
//   final String projectName;
//   final String itemName;
//   final String batchName;
//   final double totalAmount;
//   final double totalPaid;
//   final double arrears;

//   ArrearsSummary({
//     required this.transactionCode,
//     required this.projectName,
//     required this.itemName,
//     required this.batchName,
//     required this.totalAmount,
//     required this.totalPaid,
//     required this.arrears,
//   });
// }

// class FilterDialog extends StatefulWidget {
//   final List<Student> students;
//   final Function(List<Student>, List<String>, String) onFilterApplied;
//   final Map<String, bool>? initialSelections;
//   final List<String> selectedTerms;
//   final List<User> users; // Add this

//   const FilterDialog({
//     Key? key,
//     required this.students,
//     required this.onFilterApplied,
//     this.initialSelections,
//     this.selectedTerms = const [],
//     required this.users, // Add this
//   }) : super(key: key);

//   @override
//   State<FilterDialog> createState() => _FilterDialogState();
// }

// class _FilterDialogState extends State<FilterDialog> {
//   final TextEditingController _surnameController = TextEditingController();
//   final TextEditingController _regNumberController = TextEditingController();
//   String? _selectedClass;
//   List<String> _selectedTerms = [];
//   String? _selectedPaymentPurpose;
//   bool _selectAll = false;
//   Map<String, bool> _selectedStudents = {};

//   // Arrears filter type
//   String _arrearsFilterType = 'all'; // 'all', 'arrears_only', 'fully_paid'

//   List<String> _availableClasses = [];
//   List<String> _availableTerms = [];
//   List<String> _availablePaymentPurposes = [];
//   List<Student> _originalStudents = [];
//   List<Student> _filteredStudents = [];
//   bool _filtersApplied = false;

// // Check if current user is a teacher
//   bool _isTeacher() {
//     final loggedInUser = getLoggedInUser();
//     if (loggedInUser == null) return false;

//     final user = widget.users.firstWhere(
//       (u) => u.username == loggedInUser.username,
//       orElse: () => User(
//         id: 0,
//         username: '',
//         password: '',
//         role: 'teacher',
//         assignedClasses: [],
//         securityQuestions: const [],
//         securityAnswers: const [],
//         phone: '',
//       ),
//     );

//     return user.role?.toLowerCase() == 'teacher';
//   }

// // Get teacher's assigned classes
//   List<String> _getTeacherAssignedClasses() {
//     final loggedInUser = getLoggedInUser();
//     if (loggedInUser == null) return [];

//     final user = widget.users.firstWhere(
//       (u) => u.username == loggedInUser.username,
//       orElse: () => User(
//         id: 0,
//         username: '',
//         password: '',
//         role: 'teacher',
//         assignedClasses: [],
//         securityQuestions: const [],
//         securityAnswers: const [],
//         phone: '',
//       ),
//     );

//     if (user.assignedClasses != null && user.assignedClasses!.isNotEmpty) {
//       // Return as-is, but we'll do case-insensitive comparison later
//       return user.assignedClasses!;
//     }
//     return [];
//   }

//   @override
//   void initState() {
//     super.initState();

//     // Apply teacher filter to original students if user is a teacher (case-insensitive)
//     if (_isTeacher()) {
//       final assignedClasses = _getTeacherAssignedClasses();
//       if (assignedClasses.isNotEmpty) {
//         final assignedClassesLower =
//             assignedClasses.map((c) => c.toLowerCase()).toList();

//         _originalStudents = widget.students.where((student) {
//           final studentClass = student.class_?.toLowerCase() ?? '';
//           return assignedClassesLower.contains(studentClass);
//         }).toList();
//       } else {
//         _originalStudents = List.from(widget.students);
//       }
//     } else {
//       _originalStudents = List.from(widget.students);
//     }

//     _filteredStudents = List.from(_originalStudents);
//     _selectedTerms = List.from(widget.selectedTerms);
//     _extractFilterOptions();

//     if (widget.initialSelections != null) {
//       _selectedStudents = Map.from(widget.initialSelections!);
//     } else {
//       for (var student in _originalStudents) {
//         _selectedStudents[student.studentIdNumber.toString()] = true;
//       }
//     }

//     if (_selectedTerms.isNotEmpty) {
//       _applyFilters();
//     }
//     _updateSelectAllState();
//     _filtersApplied = true;
//   }

//   void _updateSelectAllState() {
//     final allSelected = _filteredStudents
//         .every((s) => _selectedStudents[s.studentIdNumber] == true);
//     final noneSelected = _filteredStudents
//         .every((s) => _selectedStudents[s.studentIdNumber] == false);
//     if (allSelected) {
//       _selectAll = true;
//     } else if (noneSelected) {
//       _selectAll = false;
//     } else {
//       _selectAll = false;
//     }
//   }

//   void _extractFilterOptions() {
//     // Get all classes from students
//     List<String> allClasses = _originalStudents
//         .map((s) => s.class_)
//         .where((c) => c != null && c.isNotEmpty)
//         .toSet()
//         .cast<String>()
//         .toList()
//       ..sort();

//     // Check if user is a teacher and filter classes accordingly (case-insensitive)
//     if (_isTeacher()) {
//       final assignedClasses = _getTeacherAssignedClasses();
//       if (assignedClasses.isNotEmpty) {
//         // Convert assigned classes to lowercase for comparison
//         final assignedClassesLower =
//             assignedClasses.map((c) => c.toLowerCase()).toList();

//         // Only show classes that are assigned to the teacher AND exist in the student list
//         _availableClasses = allClasses
//             .where((c) => assignedClassesLower.contains(c.toLowerCase()))
//             .toList()
//           ..sort();
//       } else {
//         // If teacher has no assigned classes, show all classes
//         _availableClasses = allClasses;
//       }
//     } else {
//       // Non-teachers see all classes
//       _availableClasses = allClasses;
//     }

//     // Terms extraction remains the same
//     _availableTerms = _originalStudents
//         .expand((s) => s.terms ?? [])
//         .where((t) => t != null && t.isNotEmpty)
//         .map((t) => t.trim())
//         .toSet()
//         .cast<String>()
//         .toList()
//       ..sort();
//   }

//   void _applyFilters() {
//     List<Student> filtered = List.from(_originalStudents);

//     if (_surnameController.text.trim().isNotEmpty) {
//       final query = _surnameController.text.trim().toLowerCase();
//       filtered = filtered
//           .where((s) => s.surname?.toLowerCase().contains(query) ?? false)
//           .toList();
//     }

//     if (_regNumberController.text.trim().isNotEmpty) {
//       final query = _regNumberController.text.trim().toLowerCase();
//       filtered = filtered
//           .where(
//               (s) => s.studentIdNumber?.toLowerCase().contains(query) ?? false)
//           .toList();
//     }

//     if (_selectedClass != null && _selectedClass!.isNotEmpty) {
//       // Case-insensitive class comparison
//       final selectedClassLower = _selectedClass!.toLowerCase();
//       filtered = filtered.where((s) {
//         final studentClass = s.class_?.toLowerCase() ?? '';
//         return studentClass == selectedClassLower;
//       }).toList();
//     }

//     if (_selectedTerms.isNotEmpty) {
//       filtered = filtered.where((s) {
//         final studentTerms = s.terms ?? [];
//         for (var selectedTerm in _selectedTerms) {
//           final selectedTermLower = selectedTerm.trim().toLowerCase();
//           for (var studentTerm in studentTerms) {
//             if (studentTerm.trim().toLowerCase() == selectedTermLower) {
//               return true;
//             }
//           }
//         }
//         return false;
//       }).toList();
//     }

//     setState(() {
//       _filteredStudents = filtered;
//       _filtersApplied = true;
//       for (var student in filtered) {
//         if (!_selectedStudents.containsKey(student.studentIdNumber)) {
//           _selectedStudents[student.studentIdNumber.toString()] = true;
//         }
//       }
//       _updateSelectAllState();
//     });
//   }

//   void _resetFilters() {
//     _surnameController.clear();
//     _regNumberController.clear();
//     _selectedClass = null;
//     _selectedTerms.clear();
//     _selectedPaymentPurpose = null;
//     _arrearsFilterType = 'all';
//     _filteredStudents = List.from(_originalStudents);
//     _filtersApplied = true;
//     for (var student in _originalStudents) {
//       _selectedStudents[student.studentIdNumber.toString()] = true;
//     }
//     _selectAll = true;
//     setState(() {});
//   }

//   void _toggleSelectAll(bool? value) {
//     setState(() {
//       _selectAll = value ?? false;
//       for (var student in _filteredStudents) {
//         _selectedStudents[student.studentIdNumber.toString()] = _selectAll;
//       }
//     });
//   }

//   void _toggleStudentSelection(String studentId, bool? value) {
//     setState(() {
//       _selectedStudents[studentId] = value ?? false;
//       _updateSelectAllState();
//     });
//   }

//   List<Student> getSelectedStudents() {
//     return _filteredStudents
//         .where((s) => _selectedStudents[s.studentIdNumber] == true)
//         .toList();
//   }

//   Widget _buildFilterChip(String label, String value, Color color) {
//     final isSelected = _arrearsFilterType == value;
//     return FilterChip(
//       label: Text(
//         label,
//         style: TextStyle(
//           fontSize: 12,
//           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//           color: isSelected ? Colors.white : Colors.black87,
//         ),
//       ),
//       selected: isSelected,
//       onSelected: (selected) {
//         setState(() {
//           _arrearsFilterType = value;
//           _filtersApplied = false;
//         });
//       },
//       selectedColor: color,
//       backgroundColor: Colors.grey.shade50,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//         side: BorderSide(
//           color: isSelected ? color : Colors.grey.shade300,
//           width: isSelected ? 2 : 1,
//         ),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: ConstrainedBox(
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.of(context).size.width * 0.9,
//           maxHeight: MediaQuery.of(context).size.height * 0.85,
//         ),
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Filter & Select Students',
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//               const Divider(),
//               Expanded(
//                 child: SingleChildScrollView(
//                   child: Column(
//                     children: [
//                       // Surname Filter
//                       TextField(
//                         controller: _surnameController,
//                         decoration: const InputDecoration(
//                           labelText: 'Filter by Surname',
//                           prefixIcon: Icon(Icons.person),
//                           border: OutlineInputBorder(),
//                         ),
//                         onChanged: (_) => _filtersApplied = false,
//                       ),
//                       const SizedBox(height: 16),

//                       // Registration Number Filter
//                       TextField(
//                         controller: _regNumberController,
//                         decoration: const InputDecoration(
//                           labelText: 'Filter by Registration Number',
//                           prefixIcon: Icon(Icons.numbers),
//                           border: OutlineInputBorder(),
//                         ),
//                         onChanged: (_) => _filtersApplied = false,
//                       ),
//                       const SizedBox(height: 16),

//                       // Class Filter Dropdown
//                       DropdownButtonFormField<String>(
//                         value: _selectedClass,
//                         decoration: const InputDecoration(
//                           labelText: 'Filter by Class',
//                           prefixIcon: Icon(Icons.class_),
//                           border: OutlineInputBorder(),
//                         ),
//                         items: [
//                           const DropdownMenuItem(
//                               value: null, child: Text('All Classes')),
//                           ..._availableClasses.map((c) => DropdownMenuItem(
//                                 value: c,
//                                 child: Text(c),
//                               )),
//                         ],
//                         onChanged: (value) {
//                           setState(() => _selectedClass = value);
//                           _filtersApplied = false;
//                         },
//                       ),
//                       const SizedBox(height: 16),

//                       // Terms Multi-Select
//                       Row(
//                         children: [
//                           const Text(
//                             'Filter by Terms',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 14,
//                             ),
//                           ),
//                           const Spacer(),
//                           TextButton(
//                             onPressed: () {
//                               setState(() {
//                                 _selectedTerms = List.from(_availableTerms);
//                                 _filtersApplied = false;
//                               });
//                             },
//                             style: TextButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 8, vertical: 4),
//                               minimumSize: Size.zero,
//                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                             ),
//                             child: const Text(
//                               'Select All',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.blue,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 4),
//                           TextButton(
//                             onPressed: () {
//                               setState(() {
//                                 _selectedTerms.clear();
//                                 _filtersApplied = false;
//                               });
//                             },
//                             style: TextButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 8, vertical: 4),
//                               minimumSize: Size.zero,
//                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                             ),
//                             child: const Text(
//                               'Deselect All',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.red,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 4),
//                       Container(
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey.shade300),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         padding: const EdgeInsets.all(8),
//                         child: Wrap(
//                           spacing: 8,
//                           runSpacing: 8,
//                           children: _availableTerms.map((term) {
//                             final isSelected = _selectedTerms.contains(term);
//                             return FilterChip(
//                               label: Text(
//                                 term,
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: isSelected
//                                       ? FontWeight.w500
//                                       : FontWeight.normal,
//                                 ),
//                               ),
//                               selected: isSelected,
//                               onSelected: (selected) {
//                                 setState(() {
//                                   if (selected) {
//                                     _selectedTerms.add(term);
//                                   } else {
//                                     _selectedTerms.remove(term);
//                                   }
//                                   _filtersApplied = false;
//                                 });
//                               },
//                               selectedColor: Colors.blue.shade100,
//                               checkmarkColor: Colors.blue,
//                             );
//                           }).toList(),
//                         ),
//                       ),
//                       if (_selectedTerms.isNotEmpty)
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4),
//                           child: Align(
//                             alignment: Alignment.centerRight,
//                             child: Text(
//                               '${_selectedTerms.length} term(s) selected',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey.shade600,
//                                 fontStyle: FontStyle.italic,
//                               ),
//                             ),
//                           ),
//                         ),

//                       const SizedBox(height: 16),
//                       const Divider(),

//                       // ============ ARREARS FILTER SECTION ============
//                       const Text(
//                         'Payment Status Filter',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                       const SizedBox(height: 8),

//                       // Arrears filter chips
//                       Wrap(
//                         spacing: 8,
//                         children: [
//                           _buildFilterChip('All Students', 'all', Colors.blue),
//                           _buildFilterChip(
//                               'With Arrears', 'arrears_only', Colors.red),
//                           _buildFilterChip(
//                               'Fully Paid', 'fully_paid', Colors.green),
//                         ],
//                       ),

//                       const SizedBox(height: 16),

//                       // Apply Filters Button
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.blue,
//                                 foregroundColor: Colors.white,
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 12),
//                               ),
//                               onPressed: _applyFilters,
//                               icon: const Icon(Icons.filter_alt),
//                               label: const Text(
//                                 'APPLY FILTERS',
//                                 style: TextStyle(fontWeight: FontWeight.bold),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: OutlinedButton.icon(
//                               style: OutlinedButton.styleFrom(
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 12),
//                               ),
//                               onPressed: _resetFilters,
//                               icon: const Icon(Icons.clear_all),
//                               label: const Text('RESET'),
//                             ),
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 16),
//                       const Divider(),

//                       // Student Selection Section
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               'Students (${_filteredStudents.length})',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ),
//                           if (!_filtersApplied)
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 8, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color: Colors.orange.shade100,
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: Text(
//                                 '⚠️ Apply filters to see results',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.orange.shade800,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       CheckboxListTile(
//                         title: const Text(
//                           'Select All Students',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         value: _selectAll,
//                         onChanged: _toggleSelectAll,
//                         controlAffinity: ListTileControlAffinity.leading,
//                       ),
//                       const SizedBox(height: 8),
//                       Container(
//                         height: 200,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey.shade300),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: _filteredStudents.isEmpty
//                             ? const Center(
//                                 child: Text(
//                                   'No students match the filters',
//                                   style: TextStyle(color: Colors.grey),
//                                 ),
//                               )
//                             : ListView.builder(
//                                 itemCount: _filteredStudents.length,
//                                 itemBuilder: (context, index) {
//                                   final student = _filteredStudents[index];
//                                   return CheckboxListTile(
//                                     title: Text(
//                                         '${student.name} ${student.surname}'),
//                                     subtitle: Text(
//                                         'Class: ${student.class_} | ID: ${student.studentIdNumber}'),
//                                     value: _selectedStudents[
//                                             student.studentIdNumber] ??
//                                         false,
//                                     onChanged: (value) {
//                                       _toggleStudentSelection(
//                                           student.studentIdNumber.toString(),
//                                           value);
//                                     },
//                                     controlAffinity:
//                                         ListTileControlAffinity.leading,
//                                     dense: true,
//                                   );
//                                 },
//                               ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const Divider(),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   TextButton(
//                     onPressed: _resetFilters,
//                     child: const Text('Reset All'),
//                   ),
//                   Row(
//                     children: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: const Text('Cancel'),
//                       ),
//                       const SizedBox(width: 8),
//                       ElevatedButton(
//                         onPressed: () {
//                           final selected = getSelectedStudents();
//                           // Pass filter type back to parent
//                           widget.onFilterApplied(
//                             selected,
//                             _selectedTerms,
//                             _arrearsFilterType, // Pass the filter type
//                           );
//                           Navigator.pop(context);
//                         },
//                         child: Text(
//                           'Apply (${getSelectedStudents().length} selected)',
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
