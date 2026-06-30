// ignore_for_file: unused_field

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
import 'package:zitf_system/student_payments/id_service.dart.dart';
import 'package:zitf_system/utils/windows_printer_helper.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

class _CachedStudents {
  final List<Student> students;
  final DateTime expiresAt;
  _CachedStudents(this.students, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class MakePaymentScreen extends StatefulWidget {
  const MakePaymentScreen({Key? key, this.transaction}) : super(key: key);

  final ProjectSaleTransaction? transaction;

  @override
  _MakePaymentScreenState createState() => _MakePaymentScreenState();
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

class _MakePaymentScreenState extends State<MakePaymentScreen> {
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

    // Scroll to Confirm Payment button after adding
    _scrollToConfirmButton();
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

  List<StudentPayment>? _cachedFilteredStudents;

  Future<void>? _arrearsFuture;
  bool _isProcessingPayment = false;

  Future<double>? _totalArrearsFuture;

  Timer? _searchDebounce;
  final Duration _searchDebounceDuration = const Duration(milliseconds: 350);

// Simple in-memory cache for server search results
  final Map<String, _CachedStudents> _studentsCache = {};

  List<Student>?
      _cachedServerStudentsForSearch; // used only for immediate parse

  List<ProjectSaleTransaction>? _cachedServerProjectSaleTransactions;

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

  late List<Student> _students;
  Student? _student;
  Project? _project;
  ProjectItem? _item;
  ProductBatch? _selectedBatches;
  BatchSellUnit? _selectedSellUnit;

// Add this at the beginning of your widget class
  final Map<String, List<bool>> _selectedSubPurposes = {};
  double _cachedTotalEntered = 0.0;

  // Add this to your state variables
  Map<String, dynamic>? _cachedArrearsSummary;
  String? _cachedArrearsSummaryKey;

  late ClientIdManager _idManager;
  bool _idManagerInitialized = false;
  int _localIdCounter = 0;

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
  double _amountPaid = 0;
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

  Future<Map<String, dynamic>> _getOrComputeArrearsSummary({
    required List<Map<String, dynamic>> currentPayments,
    required List<Map<String, dynamic>> updatedArrears,
  }) async {
    // Create a cache key based on student ID and payment list
    final cacheKey =
        '${_selectedStudent?.studentIdNumber}_${currentPayments.length}_${updatedArrears.length}';

    // Check if cache is valid
    if (_cachedArrearsSummary != null && _cachedArrearsSummaryKey == cacheKey) {
      debugPrint('⏱️ [CACHE] Using cached arrears summary');
      return _cachedArrearsSummary!;
    }

    debugPrint('⏱️ [CACHE] Computing arrears summary...');
    final result = await _buildOtherArrearsSummaryWithTotal(
      currentPayments: currentPayments,
      updatedArrears: updatedArrears,
    );

    // Cache the result
    _cachedArrearsSummary = result;
    _cachedArrearsSummaryKey = cacheKey;

    return result;
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

  void _reindexControllers() {
    final newControllers = <int, TextEditingController>{};
    for (int i = 0; i < _paymentPurposes.length; i++) {
      if (_amountControllers.containsKey(i)) {
        newControllers[i] = _amountControllers[i]!;
      } else if (_amountControllers.containsKey(i + 1)) {
        newControllers[i] = _amountControllers[i + 1]!;
      }
    }
    _amountControllers.clear();
    _amountControllers.addAll(newControllers);
  }

  double _originalTotalForValidation = 0.0;
  bool _changeSettled = true; // ✅ default TRUE

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

// Helper method to mark a row as being edited
  void _startEditing(int index) {
    setState(() {
      _isEditingAmount[index] = true;
    });
  }

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

    fetchTerms();
    fetchSchools();
    fetchStudentsMetadata();
    fetchPaymentPurposes();
    fetchStudentPayments();
    fetchUsers(); // <-- NEW
    _fetchProjectsFromServer();
    _fetchProjectItemsFromServer();
    fetchProductBatch();
    fetchBatchSellUnit();
    _fetchProjectSaleTransactions();

    // ✅ Initialize data based on device role
    _initializeDataForRole();
    _initIdManager();

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

  Future<void> _initIdManager() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

      final role = await getDeviceRole();

      if (role == DeviceRole.host) {
        // Host: Initialize the ID service
        await IdService().initialize(); // Use prefixed name
        _idManagerInitialized = true;
        debugPrint('✅ Host ID Service initialized');
      } else {
        // Client: Use ClientIdManager
        _idManager = ClientIdManager(prefs, hostIp); // Use prefixed name
        await _idManager.initialize();
        _idManagerInitialized = true;
        debugPrint('✅ Client ID Manager initialized');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize ID Manager: $e');
      _idManagerInitialized = true; // Allow fallback
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
              child: const Icon(Icons.stop),
              onPressed: () => bluetoothPrint.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
              child: const Icon(Icons.bluetooth_searching),
              onPressed: () => bluetoothPrint.startScan(
                timeout: const Duration(seconds: 5),
              ),
              tooltip: 'Scan for Bluetooth Printers',
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

  // ✅ New method to initialize data based on role
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
    } else {
      // Client mode: Data will come from cached server responses
      // Initialize empty lists first, they'll be populated by the cache
      _students = [];
      _projects = [];
      _items = [];
      _selectedBatch = [];
      _batchSellUnits = [];

      // Wait for cached data to be populated
      await _waitForCachedData();
      await _fetchProjectSaleTransactions();
    }

    setState(() {});
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
        // Populate the terms list with unique term IDs
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
        _terms = allTerms.map((term) => term.termId).toSet().toList();
        _termsMap = {for (var t in allTerms) t.termId: t}; // for quick lookup
        selectedTermId = _terms.contains(globalTermId)
            ? globalTermId
            : (_terms.isNotEmpty ? _terms.first : null);
      } else {
        _terms = [];
        _termsMap = {};
      }

      setState(() {}); // Refresh the UI
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
        // Populate the terms list with unique term IDs
      } else {
        if (_hostIp!.isEmpty) {
          _showDialog("⚠️ Host IP not set. Please configure connection.");
          setState(() {});
          return;
        }

        if (_cachedServerStudentPaymentPurposes == null) {
          final studentPaymentPurposesResponse = await HttpClient()
              .getUrl(Uri.parse('http://$_hostIp:8080/api/paymentPurposes'))
              .then((req) => req.close());

          if (studentPaymentPurposesResponse.statusCode == 200) {
            final studentPaymentPurposesJsonString =
                await studentPaymentPurposesResponse
                    .transform(utf8.decoder)
                    .join();

            final studentPaymentPurposesList =
                jsonDecode(studentPaymentPurposesJsonString) as List;

            _cachedServerStudentPaymentPurposes = studentPaymentPurposesList
                .map((json) =>
                    paymentPurposesFromJson(Map<String, dynamic>.from(json)))
                .toList();
          } else {
            throw Exception("Failed to load payment Purposes data from host.");
          }
        }
        allStudentPaymentPurposes = _cachedServerStudentPaymentPurposes!;
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint("❌ Error fetching initial data: $error");
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
    debugPrint("⏱️ [SMS] _sendSmsNotification started for $phone");
    final stopwatch = Stopwatch()..start();

    if (Platform.isAndroid) {
      if (allPaymentsInfo.isEmpty) {
        debugPrint("⏱️ [SMS] No payment info to send");
        _showDialog('No payment made yet');
        return;
      }
      final encodedBody = Uri.encodeComponent(allPaymentsInfo);

      try {
        debugPrint("⏱️ [SMS] Launching SMS intent...");
        await launcher.launchUrl(
          Uri.parse(
            'sms:$phone${Platform.isAndroid ? '?' : '&'}body=$encodedBody',
          ),
        );
        debugPrint(
            "⏱️ [SMS] SMS launched in ${stopwatch.elapsedMilliseconds}ms");
      } catch (e) {
        debugPrint("❌ [SMS] Failed to send SMS: $e");
      }
    }
  }

  Future<void> sendSms(String allPaymentsInfoadminnew, String recipient) async {
    debugPrint("⏱️ [sendSms] Started for $recipient");
    final stopwatch = Stopwatch()..start();

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
        const int smsChunkLimit = 153;

        List<String> messageParts = [];
        for (int i = 0;
            i < allPaymentsInfoadminnew.length;
            i += smsChunkLimit) {
          int end = (i + smsChunkLimit < allPaymentsInfoadminnew.length)
              ? i + smsChunkLimit
              : allPaymentsInfoadminnew.length;
          messageParts.add(allPaymentsInfoadminnew.substring(i, end));
        }

        debugPrint(
            "⏱️ [sendSms] Sending ${messageParts.length} SMS parts to $recipient");
        for (int i = 0; i < messageParts.length; i++) {
          String part = messageParts[i];
          SmsStatus result = await BackgroundSms.sendMessage(
            phoneNumber: recipient,
            message: part,
          );
          debugPrint(
              "⏱️ [sendSms] Part ${i + 1}/${messageParts.length} sent to $recipient");

          await Future.delayed(const Duration(milliseconds: 500));
        }
        debugPrint(
            "⏱️ [sendSms] All parts sent to $recipient in ${stopwatch.elapsedMilliseconds}ms");
      }
    } catch (e) {
      debugPrint("❌ [sendSms] Error sending SMS to $recipient: $e");
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

  Future<Map<String, dynamic>> _buildOtherArrearsSummaryWithTotal({
    List<Map<String, dynamic>>? currentPayments,
    List<Map<String, dynamic>>? updatedArrears, // Add this parameter
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final termAggregation = prefs.getBool('termAggregation') ?? false;

    try {
      final role = await getDeviceRole();

      // ✅ Get payment purposes
      List<PaymentPurpose> allPurposes;
      if (role == DeviceRole.host) {
        final paymentPurposeBox =
            await Hive.openBox<PaymentPurpose>('payment_purposes');
        allPurposes = paymentPurposeBox.values
            .where((p) =>
                p.associatedClasses?.contains(_selectedStudent!.class_) == true)
            .toList();
      } else {
        if (_cachedServerStudentPaymentPurposes == null) {
          await fetchPaymentPurposes();
        }
        allPurposes = _cachedServerStudentPaymentPurposes!
            .where((p) =>
                p.associatedClasses?.contains(_selectedStudent!.class_) == true)
            .toList();
      }

      // ✅ Build a map of current payments being made
      final Map<String, Map<String, double>> currentPaymentsMap = {};
      if (currentPayments != null) {
        for (var payment in currentPayments) {
          final purposeName = payment['purpose'].paymentPurpose;
          final termId = payment['termId'];
          final amountPaid = payment['currentAmount'] as double;

          currentPaymentsMap.putIfAbsent(purposeName, () => {});
          currentPaymentsMap[purposeName]![termId] =
              (currentPaymentsMap[purposeName]![termId] ?? 0.0) + amountPaid;
        }
      }

      // ✅ Build updated arrears map from the ArrearsSection data
      final Map<String, Map<String, double>> updatedArrearsMap = {};
      if (updatedArrears != null) {
        for (var purposeItem in updatedArrears) {
          final purpose = purposeItem['purpose'];
          final purposeName = purpose.paymentPurpose;
          final subPurposes = purposeItem['subPurposesWithTerms']
                  as List<Map<String, dynamic>>? ??
              [];

          for (var subPurpose in subPurposes) {
            final termId = subPurpose['termId'];
            final amount = subPurpose['amount'] as double;

            updatedArrearsMap.putIfAbsent(purposeName, () => {});
            updatedArrearsMap[purposeName]![termId] = amount;
          }
        }
      }

      String summary = '\n';
      String summaryadmin = '';
      double grandTotal = 0.0;

      if (termAggregation) {
        final Map<String, double> aggregatedPurposeTotals = {};

        for (final purpose in allPurposes) {
          for (final studentTerm in _selectedStudent!.terms ?? []) {
            if (purpose.termId != studentTerm) continue;
            double remainingArrears = 0.0;
            final purposeName = purpose.paymentPurpose;

            if (updatedArrearsMap.containsKey(purposeName) &&
                updatedArrearsMap[purposeName]!.containsKey(studentTerm)) {
              remainingArrears = updatedArrearsMap[purposeName]![studentTerm]!;
            } else {
              // ✅ Get original arrears (check cache first)
              double originalArrears =
                  _getOriginalOrCachedArrears(purpose, studentTerm);

              // ✅ Subtract current payment for this purpose/term
              final paidNow = currentPaymentsMap[purpose.paymentPurpose]
                      ?[studentTerm] ??
                  0.0;
              remainingArrears = (originalArrears - paidNow + paidNow)
                  .clamp(0.0, double.infinity);
            }
            if (remainingArrears > 0) {
              final cleanPurpose = purpose.paymentPurpose
                  .replaceAll(RegExp(r'\s*\(.*?\)'), '')
                  .trim()
                  .toUpperCase();

              aggregatedPurposeTotals[cleanPurpose] =
                  (aggregatedPurposeTotals[cleanPurpose] ?? 0.0) +
                      remainingArrears;
              grandTotal += remainingArrears;
            }
          }
        }

        if (aggregatedPurposeTotals.isNotEmpty) {
          aggregatedPurposeTotals.forEach((purpose, total) {
            summary += '$purpose >> \$${total.toStringAsFixed(2)}\n';
          });
        } else if (currentPayments != null && currentPayments.isNotEmpty) {
          summary += ' All selected purposes have been fully paid!\n';
        }
      } else {
        final Map<String, Map<String, double>> termWiseMap = {};

        for (final purpose in allPurposes) {
          for (final studentTerm in _selectedStudent!.terms ?? []) {
            if (purpose.termId != studentTerm) continue;
            double remainingArrears = 0.0;
            final purposeName = purpose.paymentPurpose;

            if (updatedArrearsMap.containsKey(purposeName) &&
                updatedArrearsMap[purposeName]!.containsKey(studentTerm)) {
              remainingArrears = updatedArrearsMap[purposeName]![studentTerm]!;
            } else {
              // ✅ Get original arrears (check cache first)
              double originalArrears =
                  _getOriginalOrCachedArrears(purpose, studentTerm);

              // ✅ Subtract current payment for this purpose/term
              final paidNow = currentPaymentsMap[purpose.paymentPurpose]
                      ?[studentTerm] ??
                  0.0;
              remainingArrears = (originalArrears - paidNow + paidNow)
                  .clamp(0.0, double.infinity);
            }
            if (remainingArrears > 0) {
              final term = studentTerm.toUpperCase();
              final purposeName = purpose.paymentPurpose.toUpperCase();

              termWiseMap.putIfAbsent(term, () => {});
              termWiseMap[term]![purposeName] =
                  (termWiseMap[term]![purposeName] ?? 0.0) + remainingArrears;
              grandTotal += remainingArrears;
            }
          }
        }

        if (termWiseMap.isNotEmpty) {
          for (final termEntry in termWiseMap.entries) {
            final term = termEntry.key;
            final purposeMap = termEntry.value;

            summary += '\n-TERM: $term \n';
            for (final entry in purposeMap.entries) {
              summary +=
                  '${entry.key} >> \$${entry.value.toStringAsFixed(2)}\n';
            }
          }
        } else if (currentPayments != null && currentPayments.isNotEmpty) {
          summary += ' All selected purposes have been fully paid!\n';
        }
      }

      if (grandTotal > 0) {
        final totalLine =
            '\nTOTAL REMAINING ARREARS: \$${grandTotal.toStringAsFixed(2)}\n';
        summary += totalLine;
        summaryadmin += totalLine;
      } else if (currentPayments != null && currentPayments.isNotEmpty) {
        summary += '\n NO REMAINING ARREARS - ALL CLEARED!\n';
        summaryadmin += '\n NO REMAINING ARREARS - ALL CLEARED!\n';
      }

      return {
        'summary': summary.trim().isEmpty ? '' : summary,
        'grandTotalArrears': grandTotal,
        'summaryadmin': summaryadmin.trim().isEmpty ? '' : summaryadmin,
      };
    } catch (e) {
      debugPrint("❌ Error building arrears summary: $e");
      return {
        'summary': '',
        'grandTotalArrears': 0.0,
        'summaryadmin': '',
      };
    }
  }

// ✅ Add this helper method
  double _getOriginalOrCachedArrears(PaymentPurpose purpose, String termId) {
    final purposeKey = purpose.paymentPurpose ?? purpose.id.toString();

    // Check if there's a cached updated amount
    if (_updatedArrearsCache.containsKey(purposeKey) &&
        _updatedArrearsCache[purposeKey]!.containsKey(termId)) {
      final cachedAmount = _updatedArrearsCache[purposeKey]![termId]!;
      return cachedAmount;
    }

    // Otherwise calculate original
    return _calculateArrearsForTerm(
      purpose: purpose,
      termId: termId,
      purposeName: purpose.paymentPurpose,
    );
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

  Future<Box<PaymentPurpose>> _openPaymentPurposeBox() async {
    return await Hive.openBox<PaymentPurpose>('payment_purposes');
  }

  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTermId(
      String termId) async {
    if (_role == DeviceRole.host) {
      final box = await _openPaymentPurposeBox();
      return box.values.where((p) => p.termId == termId).toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        await fetchPaymentPurposes(); // Ensure it's loaded
      }
      return _cachedServerStudentPaymentPurposes!
          .where((p) => p.termId == termId)
          .toList();
    }
  }

  Future<List<PaymentPurpose>> _getPaymentPurposesForGlobalTerm() async {
    if (_role == DeviceRole.host) {
      final box = await Hive.openBox<PaymentPurpose>('payment_purposes');
      return box.values.where((p) => p.termId == globalTermId).toList();
    } else {
      if (_cachedServerStudentPaymentPurposes == null) {
        await fetchPaymentPurposes(); // Ensure data is available
      }
      return _cachedServerStudentPaymentPurposes!
          .where((p) => p.termId == globalTermId)
          .toList();
    }
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

  void _addPaymentToPurposes(Map<String, dynamic> item) {
    setState(() {
      final index = _paymentPurposes.length;
      _paymentPurposes.add(item);
      _amountControllers[index] = TextEditingController(
        text: (item['currentAmount'] as double).toStringAsFixed(2),
      );
      _updateTotalEntered();
    });
  }

  Future<void> _addPaymentPurpose() async {
    if (_selectedPaymentPurpose == null ||
        _paymentAmount == null ||
        _paymentAmount! <= 0) {
      _showDialog('Please select a valid payment purpose and amount.');
      return;
    }

    if (_arrearsTerms.isNotEmpty && _selectedArrearsTerm == null) {
      _showDialog('Please select a term to pay arrears.');
      return;
    }

    final double amountPaid = _paymentAmount!;
    final String paymentPurpose =
        _selectedPaymentPurpose!.paymentPurpose.toUpperCase();
    final String term = _selectedArrearsTerm ?? globalTermId.toString();

    Map<String, double> updatedArrears = Map.from(_arrearsDetails);
    if (updatedArrears.containsKey(term)) {
      updatedArrears[term] =
          (updatedArrears[term]! - amountPaid).clamp(0.0, double.infinity);
    }

    final School school = await _getSchoolInfo();
    final String schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(_paymentDate);
    final studentName = _selectedStudent?.name.toUpperCase() ?? '';
    final studentSurname = _selectedStudent?.surname.toUpperCase() ?? '';
    final parentName = _selectedStudent?.paymentStatus.toUpperCase() ?? '';
    final parentName11 =
        _selectedStudent?.emergencyContactName?.toUpperCase() ?? '';
    final parentName1 =
        _selectedStudent!.emergencyContactName?.toUpperCase() ?? 'Guardian';

    final String entry =
        '${_paymentPurposes.isEmpty ? '$schoolName\nDear $parentName: \n$studentName $studentSurname has paid:\n' : 'And'} '
        ' \$${amountPaid.toStringAsFixed(2)} for  $paymentPurpose of  $term.\n\n';
    final String entry11 =
        '${_paymentPurposes.isEmpty ? '$schoolName\nDear $parentName11: \n$studentName $studentSurname has paid:\n' : 'And'} '
        ' \$${amountPaid.toStringAsFixed(2)} for  $paymentPurpose of  $term.\n\n';

    final String entry1 =
        '${_paymentPurposes.isEmpty ? '$schoolName\nDear $parentName1: \n$studentName $studentSurname has paid:\n' : 'And'} '
        ' \$${amountPaid.toStringAsFixed(2)} for  $paymentPurpose of  $term.\n\n';

    _paymentInfo = (_paymentInfo ?? '') + entry;
    _paymentInfo11 = (_paymentInfo11 ?? '') + entry11;
    _paymentInfo2 = (_paymentInfo2 ?? '') + entry1;

    final String adminEntry =
        '${_paymentPurposes.isEmpty ? '$studentName $studentSurname paid:' : 'And'} '
        '\n \$${amountPaid.toStringAsFixed(2)} for $paymentPurpose of  $term .\n';

    _paymentInfo1 = (_paymentInfo1 ?? '') + adminEntry;

    _arrearsDetails = updatedArrears;

    setState(() {
      final newItem = {
        'purpose': _selectedPaymentPurpose!,
        'amount': _paymentAmount!,
        'originalAmount': _paymentAmount!,
        'currentAmount': _paymentAmount!,
        'termId': term,
        'amountError': null,
      };

      final index = _paymentPurposes.length;
      _paymentPurposes.add(newItem);

      // ✅ Create controller for the new item
      _amountControllers[index] = TextEditingController(
        text: _paymentAmount!.toStringAsFixed(2),
      );

      _paymentAmountController.clear();
      _paymentAmount = null;
      _selectedPaymentPurpose = null;
      _updateTotalEntered();
    });
  }

  void _autoSplitPendingPartialPaymentsSync() {
    // Create a list of indices to process (iterate backwards to avoid index issues)
    List<int> indicesToSplit = [];

    for (int i = 0; i < _paymentPurposes.length; i++) {
      final payment = _paymentPurposes[i];
      final double originalAmount = payment['originalAmount'] as double;
      final double currentAmount = payment['currentAmount'] as double;
      final bool isRemainingArrears = payment['isRemainingArrears'] == true;

      // Check if this is a partial payment that hasn't been split yet
      if (!isRemainingArrears &&
          currentAmount > 0 &&
          currentAmount < originalAmount &&
          _isEditingAmount[i] == true) {
        indicesToSplit.add(i);
      }
    }

    if (indicesToSplit.isEmpty) {
      return;
    }

    // Process splits from last to first to avoid index shifting issues
    for (int i = indicesToSplit.length - 1; i >= 0; i--) {
      final int index = indicesToSplit[i];
      final payment = _paymentPurposes[index];
      final double originalAmount = payment['originalAmount'] as double;
      final double currentAmount = payment['currentAmount'] as double;

      // Perform the split (assuming _splitPaymentOnAmountChange is synchronous)
      _splitPaymentOnAmountChange(
        index,
        currentAmount,
        originalAmount,
        payment,
      );

      // Stop editing state
      _stopEditing(index);
    }

    // Force refresh the arrears section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _arrearsSectionKey.currentState?.refresh();
    });
  }

// Add this as a class method in _MakePaymentScreenState
  double _getRemainingArrears(PaymentPurpose purpose, String termId) {
    final purposeKey = purpose.paymentPurpose ?? purpose.id.toString();
    if (_updatedArrearsCache.containsKey(purposeKey) &&
        _updatedArrearsCache[purposeKey]!.containsKey(termId)) {
      return _updatedArrearsCache[purposeKey]![termId]!;
    }
    return _calculateArrearsForTerm(
      purpose: purpose,
      termId: termId,
      purposeName: purpose.paymentPurpose,
    );
  }

  void _confirmPayment() {
    final totalStart = DateTime.now();
    debugPrint('⏱️ [CONFIRM] START - Confirm Payment button pressed');

    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final received = double.tryParse(_pmAmountCtrl.text.trim()) ?? 0.0;
    finalReceived = received;
    debugPrint('⏱️ [CONFIRM] Starting auto-split...');
    final splitStart = DateTime.now();
    _autoSplitPendingPartialPaymentsSync();

    debugPrint(
        '⏱️ [CONFIRM] Auto-split completed in ${DateTime.now().difference(splitStart).inMilliseconds}ms');

    // 🆕 STEP 2: Refresh UI after auto-splitting
    debugPrint('⏱️ [CONFIRM] Refreshing UI...');
    final uiStart = DateTime.now();
    setState(() {});
    debugPrint(
        '⏱️ [CONFIRM] UI refresh completed in ${DateTime.now().difference(uiStart).inMilliseconds}ms');

    // Recalculate totals after auto-splitting
    _updateTotalEntered();

    if (received < _totalEntered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Amount received (${_formatCurrency(received)}) cannot be less than total due (${_formatCurrency(_totalEntered)})'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return; // ❌ Stop execution
    }
    if (_selectedStudent == null) {
      _showDialog('Please select a student first');
      return;
    }

    if (_paymentPurposes.isEmpty) {
      _showDialog('Please add at least one payment purpose');
      return;
    }
    debugPrint('⏱️ [CONFIRM] Showing confirmation dialog...');
    final dialogStart = DateTime.now();
    showDialog(
      context: context,
      builder: (context) {
        debugPrint('⏱️ [CONFIRM] Dialog builder started');

        return Stack(
          children: [
            AlertDialog(
              title: const Center(child: Text('Confirm Payment')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(capitalize(
                      'Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}')),
                  Text(capitalize('Class: ${_selectedStudent!.class_} ')),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Purposes')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Term')),
                      ],
                      rows: _paymentPurposes.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final payment = entry.value;
                        final PaymentPurpose purpose = payment['purpose'];

                        final double originalAmount =
                            payment['originalAmount'] as double;
                        final double currentAmount =
                            payment['currentAmount'] as double;

                        final String termId =
                            payment['termId'] ?? purpose.termId ?? '';
                        final term = _termsMap[termId];
                        final termDisplay =
                            term != null ? '(${term.termName})' : '(Unknown)';

                        // ✅ Get or create controller for this row
                        if (!_amountControllers.containsKey(index)) {
                          _amountControllers[index] = TextEditingController(
                            text: (payment['currentAmount'] as double)
                                .toStringAsFixed(2),
                          );
                        }
                        final controller = _amountControllers[index]!;

                        return DataRow(
                          cells: [
                            DataCell(Text(payment['purpose'].paymentPurpose)),
                            // Remove the timer maps and timer-related code

                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    '\$${payment['currentAmount'].toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(termDisplay)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Total Amount Entered: \$$_currency ${finalReceived?.toStringAsFixed(2) ?? 0.0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    debugPrint('⏱️ [CONFIRM] User cancelled payment');

                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    // Set processing state
                    setState(() => _isProcessingPayment = true);

                    try {
                      final studentToSave = _selectedStudent;
                      if (studentToSave == null) {
                        throw Exception("No student selected");
                      }
                      // Fetch school info
                      final School schoolInfo = await _fetchSchoolInfo();

                      // Generate next receipt number
                      int newId = await getNextId();
                      String receiptNo = await getNextReceipt();
                      final currentArrearsData = await _getFreshArrearsData();

                      // Fetch arrears for term section (your existing method)
                      final arrearsData =
                          await _buildOtherArrearsSummaryWithTotal(
                        currentPayments: _paymentPurposes,
                        updatedArrears: currentArrearsData,
                      );

                      // Read aggregation setting
                      final prefs = await SharedPreferences.getInstance();
                      final termAggregation =
                          prefs.getBool('termAggregation') ?? false;
                      final studentId =
                          _selectedStudent!.studentIdNumber.toString();

                      final projectDetails =
                          buildStudentArrearsDetails(studentId);

                      // Build unified receipt using new engine
                      final List<LineText> list = buildReceiptLines(
                        schoolInfo: schoolInfo,
                        newId: newId,
                        receiptNo: receiptNo,
                        selectedStudent: studentToSave,
                        paymentPurposes: _paymentPurposes,
                        paymentDate: _paymentDate,
                        username: user,
                        arrearsData: arrearsData,
                        projectArrears: projectDetails,
                        termAggregation: termAggregation,
                        isDuplicate: false, // <-- reprint flag
                      );

                      // ✅ STEP 1: Process payment FIRST
                      await _makePayment(useId: newId);

                      // ✅ STEP 2: Only after payment succeeds, save receipt log
                      await saveReceiptLog(
                        receiptNumber: newId,
                        student: studentToSave,
                        receiptLines: list,
                      );

                      // Close dialogs
                      Navigator.pop(context); // Close confirmation dialog
                      Navigator.pop(context); // Close payment dialog

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Payment completed successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Payment failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() => _isProcessingPayment = false);
                    }
                  },
                  child: const Text('Confirm And Do Not Print Receipt?'),
                ),
                TextButton(
                  onPressed: _connected
                      ? () async {
                          final buttonStart = DateTime.now();
                          debugPrint(
                              '⏱️ [PRINT-BUTTON] User clicked "Confirm & Print Receipt"');

                          setState(() => _isProcessingPayment = true);

                          try {
                            final studentToSave = _selectedStudent;
                            if (studentToSave == null) {
                              throw Exception("No student selected");
                            }

                            // Step 1: Get fresh arrears data
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Getting arrears data...');
                            final arrearsStart = DateTime.now();

                            final currentArrearsData =
                                await _getFreshArrearsData();
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Arrears data fetched in ${DateTime.now().difference(arrearsStart).inMilliseconds}ms');

                            final School schoolInfo = await _fetchSchoolInfo();

                            debugPrint('⏱️ [PRINT-BUTTON] Getting IDs...');
                            final idStart = DateTime.now();
                            int newId = await getNextId();
                            String receiptNo = await getNextReceipt();
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] IDs obtained in ${DateTime.now().difference(idStart).inMilliseconds}ms (newId: $newId)');

                            // Step 4: Build arrears data
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Building arrears summary...');
                            final arrearsSummaryStart = DateTime.now();
                            final arrearsData =
                                await _getOrComputeArrearsSummary(
                              currentPayments: _paymentPurposes,
                              updatedArrears: currentArrearsData,
                            );
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Arrears summary _getOrComputeArrearsSummary in ${DateTime.now().difference(arrearsSummaryStart).inMilliseconds}ms');

                            final prefs = await SharedPreferences.getInstance();
                            final termAggregation =
                                prefs.getBool('termAggregation') ?? false;
                            final studentId =
                                _selectedStudent!.studentIdNumber.toString();
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Building project details...');
                            final projectStart = DateTime.now();
                            final projectDetails =
                                buildStudentArrearsDetails(studentId);
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Project details built in ${DateTime.now().difference(projectStart).inMilliseconds}ms');

                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Building receipt lines...');
                            final receiptStart = DateTime.now();

                            final List<LineText> list = buildReceiptLines(
                              schoolInfo: schoolInfo,
                              newId: newId,
                              receiptNo: receiptNo,
                              selectedStudent: studentToSave,
                              paymentPurposes: _paymentPurposes,
                              paymentDate: _paymentDate,
                              username: user,
                              arrearsData: arrearsData,
                              projectArrears: projectDetails,
                              termAggregation: termAggregation,
                              isDuplicate: false,
                            );
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Receipt built in ${DateTime.now().difference(receiptStart).inMilliseconds}ms (${list.length} lines)');
                            final paymentStart = DateTime.now();

                            // ✅ STEP 1: Process payment FIRST
                            await _makePayment(useId: newId);
                            debugPrint(
                                '⏱️ [PRINT-BUTTON] Dispatching receipt log save...');

                            try {
                              await saveReceiptLog(
                                receiptNumber: newId,
                                student: studentToSave,
                                receiptLines: list,
                              );
                              debugPrint(
                                  "✅ saveReceiptLog completed successfully");
                            } catch (e, stack) {
                              debugPrint("❌ saveReceiptLog failed: $e");
                              debugPrint("Stack trace: $stack");
                              rethrow;
                            }

                            // ✅ STEP 3: Print receipt (payment already saved)
                            if (Platform.isAndroid) {
                              Map<String, dynamic> config = {};
                              await bluetoothHelper.bluetoothPrint
                                  .printReceipt(config, list);
                            } else if (Platform.isWindows) {
                              // Generate plain text instead of ESC/POS
                              StringBuffer textBuffer = StringBuffer();

                              for (var line in list) {
                                if (line.type == LineText.TYPE_TEXT) {
                                  final content = line.content ?? '';
                                  textBuffer.writeln(content);

                                  // Add extra line feeds
                                  for (int i = 0;
                                      i < (line.linefeed ?? 1) - 1;
                                      i++) {
                                    textBuffer.writeln('');
                                  }
                                }
                              }

                              final plainText = textBuffer.toString();
                              final bytes = utf8.encode(plainText);

                              await WindowsPrinterHelper.printToWindowsPrinter(
                                _selectedWindowsPrinter!,
                                bytes,
                              );
                            } else {
                              throw Exception(
                                  'Printing not supported on this platform');
                            }

                            // Close dialogs
                            Navigator.pop(context); // Close confirmation dialog
                            Navigator.pop(context); // Close payment dialog

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '✅ Payment completed and receipt printed!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e, stackTrace) {
                            debugPrint("❌ ERROR: $e");
                            debugPrint("Stack trace: $stackTrace");

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } finally {
                            setState(() => _isProcessingPayment = false);
                          }
                        }
                      : null,
                  child: Text(
                    Platform.isAndroid
                        ? 'Confirm & Print Receipt (Bluetooth)'
                        : 'Confirm & Print Receipt (USB/Ethernet)',
                  ),
                ),
              ],
            ),
            if (_isProcessingPayment)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true, // Prevent all taps
                  child: Container(
                    color: Colors.black.withOpacity(0.4), // Greyout overlay
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "Processing payment, please wait...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
      },
    );
    debugPrint(
        '⏱️ [CONFIRM] Dialog shown in ${DateTime.now().difference(dialogStart).inMilliseconds}ms');
    debugPrint(
        '⏱️ [CONFIRM] Total confirm time: ${DateTime.now().difference(totalStart).inMilliseconds}ms');
  }

  List<LineText> buildReceiptLines({
    required School schoolInfo,
    required int newId,
    required String receiptNo,
    required Student selectedStudent,
    required List<Map<String, dynamic>> paymentPurposes,
    required DateTime paymentDate,
    required String username,
    required Map<String, dynamic> arrearsData,
    List<ArrearsSummary>? projectArrears,
    required bool termAggregation,
    bool isDuplicate = true, // <--- NEW PARAM
  }) {
    List<LineText> list = [];

    // ---------------------- HEADER ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'FEES RECEIPT',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      fontZoom: 1,
      weight: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolName?.toUpperCase() ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      fontZoom: 2,
      weight: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolAddress?.toUpperCase() ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolPhoneNumber ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolEmail ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // ---------------------- STUDENT INFO ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "RECEIVED FROM",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      weight: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content:
          "Name: ${selectedStudent.name.toUpperCase()} ${selectedStudent.surname.toUpperCase()}",
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "Class: ${selectedStudent.class_.toUpperCase()}",
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // ---------------------- PAYMENTS ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "PAYMENTS FOR",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      weight: 1,
    ));

    double totalPaid = 0;

    for (var payment in paymentPurposes) {
      double amount = payment['currentAmount'];
      totalPaid += amount;

      final purposeName = payment['purpose']
          .paymentPurpose
          .toString()
          .toUpperCase()
          .replaceAll(RegExp(r'\s*\(.*?\)'), '')
          .trim();

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: "$purposeName :    \$ $amount",
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));

      final termLabel = termAggregation
          ? payment['termId'].replaceAll(RegExp(r'\s*\(.*?\)'), '').trim()
          : payment['termId'];

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: "TERM OF :  $termLabel",
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
    }

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // ---------------------- TOTALS ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "TOTALS",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "TOTAL PAID: \$ ${totalPaid.toStringAsFixed(2)}",
      align: LineText.ALIGN_RIGHT,
      weight: 1,
      linefeed: 1,
    ));

    // ---------------------- ARREARS ----------------------
    final arrearsSummary = arrearsData['summary'] ?? "";

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TERM ARREARS SECTION',
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    for (String line in arrearsSummary.trim().split("\n")) {
      final trimmed = line.trim();
      final isHeader = trimmed.startsWith("-TERM:") ||
          trimmed.toUpperCase().startsWith("TOTAL");

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: trimmed,
        align: LineText.ALIGN_CENTER,
        weight: isHeader ? 1 : 0,
        linefeed: 1,
      ));
    }
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // ---------------------- PROJECT ARREARS ----------------------

    if (projectArrears != null && projectArrears.isNotEmpty) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'PROJECT ARREARS SECTION',
        align: LineText.ALIGN_CENTER,
        weight: 1,
        linefeed: 1,
      ));

      double total = 0;

      for (final s in projectArrears) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content:
              "${s.projectName} - ${s.itemName} : \$${s.arrears.toStringAsFixed(2)}",
          align: LineText.ALIGN_LEFT,
          linefeed: 1,
        ));

        total += s.arrears;
      }

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: "TOTAL PROJECT ARREARS: \$${total.toStringAsFixed(2)}",
        align: LineText.ALIGN_RIGHT,
        weight: 1,
        linefeed: 1,
      ));
    }
    final paymentText = formatPaymentSnapshot();

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    for (String line in paymentText.split("\n")) {
      if (line.trim().isEmpty) continue;

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: line,
        align: LineText.ALIGN_LEFT,
        linefeed: 1,
      ));
    }
    // ---------------------- RECEIPT FOOTER ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "RECEIVED ON",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(paymentDate)}",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "PAYMENT CAPTURED BY",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "Cashier: ${username.toUpperCase()}",
      align: LineText.ALIGN_RIGHT,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '***********************************************',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "RECEIPT NO.",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "#: $newId",
      align: LineText.ALIGN_RIGHT,
      weight: 1,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: receiptNo,
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    // ---------------------- DUPLICATE FLAG ----------------------
    if (isDuplicate) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: "*** DUPLICATE COPY ***",
        align: LineText.ALIGN_CENTER,
        weight: 1,
        linefeed: 1,
      ));
    }

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '***********************************************',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    return list;
  }

  List<Map<String, dynamic>> receiptLinesToJson(List<LineText> lines) {
    return lines.map((line) {
      return {
        "type": line.type,
        "content": line.content,
        "align": line.align,
        "linefeed": line.linefeed,
        "fontZoom": line.fontZoom,
        "weight": line.weight,
      };
    }).toList();
  }

  PosAlign _getAlign(int align) {
    switch (align) {
      case 1:
        return PosAlign.center; // Wait, example shows lowercase 'center'?
      case 2:
        return PosAlign.right;
      default:
        return PosAlign.left;
    }
  }

  Future<void> saveReceiptLog({
    required int receiptNumber,
    required Student student,
    required List<LineText> receiptLines,
    bool isReprint = false,
    String? originalReceiptNumber,
    int? reprintCount,
  }) async {
    debugPrint("📝 saveReceiptLog START");
    debugPrint("⏱️ [saveReceiptLog] Started at ${DateTime.now()}");
    final stopwatch = Stopwatch()..start();

    debugPrint("  - receiptNumber: $receiptNumber");
    debugPrint("  - student: ${student.name} ${student.surname}");
    debugPrint("  - receiptLines count: ${receiptLines.length}");
    debugPrint("  - isReprint: $isReprint");
    debugPrint("  - originalReceiptNumber: $originalReceiptNumber");
    debugPrint("  - reprintCount: $reprintCount");

    // ✅ Check required fields
    if (student.name == null) {
      debugPrint("❌ ERROR: student.name is null");
      throw Exception("student.name cannot be null");
    }
    if (student.surname == null) {
      debugPrint("❌ ERROR: student.surname is null");
      throw Exception("student.surname cannot be null");
    }
    if (student.class_ == null) {
      debugPrint("❌ ERROR: student.class_ is null");
      throw Exception("student.class_ cannot be null");
    }

    final role = await getDeviceRole();
    final phone = (student.phoneNumber ?? "").trim();
    final parentName = (student.paymentStatus ?? "").toUpperCase();

    // ✅ Generate unique logId
    final String logId =
        'LOG_${receiptNumber}_${DateTime.now().millisecondsSinceEpoch}';

    debugPrint("⏱️ [saveReceiptLog] Building log object...");
    final logBuildStart = DateTime.now();

    final log = PaymentLog(
      receiptNumber: receiptNumber,
      studentName: "${student.name} ${student.surname}",
      className: student.class_,
      dateTime: DateTime.now().toIso8601String(),
      receiptLines: receiptLinesToJson(receiptLines),
      parentName: parentName,
      parentPhone: phone,
      // ✅ NEW: Sync fields
      logId: logId,
      isReprint: isReprint,
      originalReceiptNumber: originalReceiptNumber,
      reprintCount: reprintCount ?? (isReprint ? 1 : 0),
      syncStatus: false, // Not synced yet
      lastModified: DateTime.now(),
      operationType: 'create',
      modifiedFields: [
        'receiptNumber',
        'studentName',
        'className',
        'dateTime',
        'receiptLines',
        'parentName',
        'parentPhone',
        'isReprint',
        'originalReceiptNumber',
        'reprintCount',
        'logId',
      ],
    );

    debugPrint(
        "⏱️ [saveReceiptLog] Log built in ${DateTime.now().difference(logBuildStart).inMilliseconds}ms");
    debugPrint("  - logId: ${log.logId}");
    debugPrint("  - isReprint: ${log.isReprint}");
    debugPrint("  - reprintCount: ${log.reprintCount}");

    if (role == DeviceRole.host) {
      // ----------------------------
      // HOST → Save locally to Hive
      // ----------------------------
      debugPrint("⏱️ [saveReceiptLog] HOST: Saving to Hive...");
      final hiveStart = DateTime.now();
      final box = await Hive.openBox<PaymentLog>('payment_log');
      await box.add(log);
      debugPrint(
          "⏱️ [saveReceiptLog] Hive save completed in ${DateTime.now().difference(hiveStart).inMilliseconds}ms");
      debugPrint("✅ PaymentLog saved locally with logId: ${log.logId}");
    } else {
      // ----------------------------
      // CLIENT → Send to host via API
      // ----------------------------
      debugPrint("⏱️ [saveReceiptLog] CLIENT: Sending to host...");
      try {
        final prefs = await SharedPreferences.getInstance();
        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

        final uri = Uri.parse("http://$hostIp:8080/api/receipt_logs/bulk");

        // ✅ Convert to JSON with all sync fields
        final payload = {
          "logs": [paymentLogToJson(log)],
        };

        debugPrint("⏱️ [saveReceiptLog] HTTP POST to $uri...");
        debugPrint("  - payload: ${jsonEncode(payload)}");

        final httpStart = DateTime.now();
        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );
        debugPrint(
            "⏱️ [saveReceiptLog] HTTP POST completed in ${DateTime.now().difference(httpStart).inMilliseconds}ms, status: ${response.statusCode}");
        debugPrint("  - response body: ${response.body}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("✅ PaymentLog sent to host successfully: ${log.logId}");
        } else {
          debugPrint(
              "⚠️ Host returned status ${response.statusCode}: ${response.body}");
          // ⚠️ Save locally as fallback
          final box = await Hive.openBox<PaymentLog>('payment_log');
          await box.add(log);
          debugPrint(
              "✅ PaymentLog saved locally as fallback with logId: ${log.logId}");
        }
      } catch (e) {
        debugPrint("❌ CLIENT: Exception sending log to host: $e");
        // ⚠️ Save locally as fallback
        try {
          final box = await Hive.openBox<PaymentLog>('payment_log');
          await box.add(log);
          debugPrint(
              "✅ PaymentLog saved locally as fallback with logId: ${log.logId}");
        } catch (e2) {
          debugPrint("❌ Failed to save locally as fallback: $e2");
        }
      }
    }

    debugPrint(
        "⏱️ [saveReceiptLog] Completed in ${stopwatch.elapsedMilliseconds}ms");
    debugPrint("📝 saveReceiptLog END");
  }

  Future<double> _calculateRemainingCurrentPurposeBalances() async {
    await fetchStudentPayments(); // Ensures _cachedServerStudentPayments is populated if needed
    await fetchPaymentPurposes(); // Ensures _cachedServerStudentPaymentPurposes is populated if needed

    final studentName = _selectedStudent!.name.toLowerCase();
    final studentSurname = _selectedStudent!.surname.toLowerCase();
    final studentclass = _selectedStudent!.class_.toLowerCase();

    final List<StudentPayment> allPayments = _role == DeviceRole.host
        ? Hive.box<StudentPayment>('student_payments').values.toList()
        : _cachedServerStudentPayments ?? [];

    final Map<String, Map<String, double>> remainingMap =
        {}; // purpose -> term -> remaining

    for (var sessionPayment in _paymentPurposes) {
      final String purposeName =
          sessionPayment['purpose'].paymentPurpose.toLowerCase();

      final String termId = sessionPayment['termId'];
      final double fullAmount = sessionPayment['purpose'].purposeAmount;

      // Get previous payments from Hive
      final double hivePaid = allPayments
          .where((p) =>
              p.studentName.toLowerCase() == studentName &&
              p.studentSurname.toLowerCase() == studentSurname &&
              p.termId == termId &&
              p.paymentPurpose.toLowerCase() == purposeName)
          .fold(0.0, (sum, p) => sum + (p.amountToPay ?? 0.0));

      // Get session payments
      final double sessionPaid = _paymentPurposes
          .where((p) =>
              p['termId'] == termId &&
              p['purpose'].paymentPurpose.toLowerCase() == purposeName)
          .fold(0.0, (sum, p) => sum + (p['amount'] as double));

      final double totalPaid = hivePaid + sessionPaid;
      final double remaining =
          (fullAmount - totalPaid).clamp(0.0, double.infinity);

      // Avoid double-counting across multiple entries
      remainingMap.putIfAbsent(purposeName, () => {});
      remainingMap[purposeName]![termId] = remaining;
    }

    // Sum all remaining amounts
    double totalRemaining = remainingMap.values
        .expand((termMap) => termMap.values)
        .fold(0.0, (sum, r) => sum + r);

    return totalRemaining;
  }

  Future<double> _calculateAllSchoolFeesBalances() async {
    await fetchStudentPayments();
    await fetchPaymentPurposes();

    final studentName = _selectedStudent!.name.toLowerCase();
    final studentSurname = _selectedStudent!.surname.toLowerCase();
    final studentClass = _selectedStudent!.class_;

    final List<StudentPayment> allPayments = _role == DeviceRole.host
        ? Hive.box<StudentPayment>('student_payments').values.toList()
        : _cachedServerStudentPayments ?? [];

    final List<PaymentPurpose> allPurposes = _role == DeviceRole.host
        ? await Hive.openBox<PaymentPurpose>('payment_purposes')
            .then((box) => box.values.toList())
        : _cachedServerStudentPaymentPurposes ?? [];

    final schoolFeePurposes = allPurposes.where((p) =>
        p.paymentPurpose.toLowerCase() == 'school fees' &&
        p.associatedClasses?.contains(studentClass) == true);
    double totalBalance = 0.0;

    for (var purpose in schoolFeePurposes) {
      final double paid = allPayments
          .where((payment) =>
              payment.studentName.toLowerCase() == studentName &&
              payment.studentSurname.toLowerCase() == studentSurname &&
              payment.termId == purpose.termId &&
              payment.paymentPurpose.toLowerCase() == 'school fees')
          .fold(0.0, (sum, payment) => sum + (payment.amountToPay ?? 0.0));

      final sessionPaid = _paymentPurposes
          .where((p) =>
              p['termId'] == purpose.termId &&
              p['purpose'].paymentPurpose.toLowerCase() == 'school fees')
          .fold(0.0, (sum, p) => sum + (p['amount'] as double));

      double totalPaid = paid + sessionPaid;
      double arrears =
          (purpose.purposeAmount - totalPaid).clamp(0.0, double.infinity);
      totalBalance += arrears;
    }

    return totalBalance;
  }

  Future<void> _makePayment({int? useId}) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('⏱️ [START] _makePayment started');

    final prefs = await SharedPreferences.getInstance();
    final termAggregation = prefs.getBool('termAggregation') ?? false;
    final studentName = _selectedStudent!.name.toUpperCase();
    final studentSurname = _selectedStudent!.surname.toUpperCase();
    final phone = _selectedStudent!.phoneNumber;
    final phone1 = _selectedStudent!.emergencyContactNumber;

    final parentName = _selectedStudent!.paymentStatus.toUpperCase();
    final parentName1 = _selectedStudent!.emergencyContactName?.toUpperCase();

    final adminBox = Hive.box<User>('users');
    // ✅ Collect both "admin" and "administration"
    final adminUsers = adminBox.values
        .where((term) =>
            term.role.toLowerCase() == "admin" ||
            term.role.toLowerCase() == "administration")
        .toList();

    // ✅ Get current arrears data from ArrearsSection
    debugPrint('⏱️ [1] Getting arrears data from ArrearsSection...');
    final currentArrearsDataStart = DateTime.now();
    final currentArrearsData =
        _arrearsSectionKey.currentState?.getCurrentArrearsData() ?? [];
    debugPrint(
        '⏱️ [1] Arrears data retrieved in ${DateTime.now().difference(currentArrearsDataStart).inMilliseconds}ms, ${currentArrearsData.length} items');

    debugPrint('⏱️ [2] Building arrears summary...');
    final arrearsDataStart = DateTime.now();
    // ✅ USE CACHED ARREARS SUMMARY (don't recompute)
    final arrearsData = await _getOrComputeArrearsSummary(
      currentPayments: _paymentPurposes,
      updatedArrears: currentArrearsData,
    );
    debugPrint(
        '⏱️ [2] Arrears summary built in ${DateTime.now().difference(arrearsDataStart).inMilliseconds}ms');

    final otherArrearsSummary = arrearsData['summary'];
    final otherArrearsSummaryadmin = arrearsData['summaryadmin'];
    final grandTotalArrears = arrearsData['grandTotalArrears'] as double;

    debugPrint('⏱️ [3] Calculating school fees balances...');
    final schoolFeesStart = DateTime.now();
    final double remainingSchoolFees = await _calculateAllSchoolFeesBalances();
    debugPrint(
        '⏱️ [3] School fees calculated in ${DateTime.now().difference(schoolFeesStart).inMilliseconds}ms');

    final grandGrandTotal = remainingSchoolFees + grandTotalArrears;

    final termsNameMap = _termsMap.map((k, v) => MapEntry(k, v.termName ?? k));

    final arrearsLine =
        otherArrearsSummary.trim().isNotEmpty ? otherArrearsSummary + '\n' : '';
    final arrearsLineadmin = otherArrearsSummaryadmin.trim().isNotEmpty
        ? otherArrearsSummaryadmin + '\n'
        : '';
    final DateFormat formatters = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDates = formatters.format(_paymentDate);

    double totalPaid = _paymentPurposes.fold(
      0.0,
      (sum, p) => sum + (p['currentAmount'] as double),
    );
    final studentId = _selectedStudent!.studentIdNumber.toString();

    debugPrint('⏱️ [4] Building project arrears details...');
    final projectStart = DateTime.now();
    final projectDetails = buildStudentArrearsDetails(studentId);
    debugPrint(
        '⏱️ [4] Project arrears built in ${DateTime.now().difference(projectStart).inMilliseconds}ms, ${projectDetails.length} items');

    final projectSummary = buildProjectArrearsSummary(projectDetails);
    final paymentDetails = formatPaymentSnapshot();

    debugPrint('⏱️ [5] Building SMS messages...');
    final smsStart = DateTime.now();
    final allPaymentsInfonewag = buildAggregatedPaymentSummary(
      (await _getSchoolInfo()).schoolName?.toUpperCase() ?? 'SCHOOL',
      parentName,
      '$studentName $studentSurname',
      _paymentPurposes,
      termsNameMap,
      projectArrearsSummary: projectSummary,
    );
    final allPaymentsInfonewag1 = buildAggregatedPaymentSummary1(
      (await _getSchoolInfo()).schoolName?.toUpperCase() ?? 'SCHOOL',
      parentName1.toString(),
      '$studentName $studentSurname',
      _paymentPurposes,
      termsNameMap,
      projectArrearsSummary: projectSummary,
    );
    final allPaymentsInfoadminnewg = buildAggregatedPaymentSummaryadmin(
      (await _getSchoolInfo()).schoolName?.toUpperCase() ?? 'SCHOOL',
      '$studentName $studentSurname',
      _paymentPurposes,
      termsNameMap,
      projectArrearsSummary: projectSummary,
    );

    final allPaymentsInfonew = allPaymentsInfonewag +
        '\n \n Total Paid: \$${totalPaid.toStringAsFixed(2)}' +
        '\n \n ARREARS SECTION' +
        arrearsLine +
        'Payment Date: ' +
        formattedDates;

    final allPaymentsInfonew1 = allPaymentsInfonewag1 +
        '\n \n Total Paid: \$${totalPaid.toStringAsFixed(2)}' +
        '\n \n ARREARS SECTION' +
        arrearsLine +
        'Payment Date: ' +
        formattedDates;
    final allPaymentsInfoadminnew = allPaymentsInfoadminnewg +
        '\n \n TOTAL PAID AMOUNT: \$${totalPaid.toStringAsFixed(2)}' +
        arrearsLineadmin +
        'Payment Date: ' +
        formattedDates;
    debugPrint(
        '⏱️ [5] SMS messages built in ${DateTime.now().difference(smsStart).inMilliseconds}ms');

    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final double amountReceived = finalReceived ?? finalReceived ?? 0.0;

    final double totalEntered = _paymentPurposes.fold(
      0.0,
      (sum, p) => sum + (p['currentAmount'] as double),
    );

    final double changeGiven =
        amountReceived > totalEntered ? amountReceived - totalEntered : 0.0;

    if (amountReceived <= 0) {
      _showDialog("Please enter amount received.");
      return;
    }

    if (amountReceived < totalEntered) {
      _showDialog("Amount received cannot be less than total payment.");
      return;
    } else if (amountReceived >= totalEntered) {
      if (_role == DeviceRole.client) {
        debugPrint('⏱️ [6] CLIENT MODE: Starting payment process...');
        setState(() => _isProcessingPayment = true);

        final paymentsToSend = <Map<String, dynamic>>[];
        debugPrint('⏱️ [6a] Getting next ID...');
        final idStart = DateTime.now();
        int newId = useId ?? await getNextId(); // ← Use provided ID or fetch
        debugPrint(
            '⏱️ [6a] getNextId completed in ${DateTime.now().difference(idStart).inMilliseconds}ms, newId: $newId');
        debugPrint('⏱️ [6b] Building payment payload...');
        final payloadStart = DateTime.now();
        for (var payment in _paymentPurposes) {
          String receiptNo = await getNextReceipt();

          paymentsToSend.add({
            "id": newId,
            "receiptNumber": receiptNo,
            "studentName": studentName,
            "studentSurname": studentSurname,
            "studentClass": _selectedStudent!.class_,
            "phoneNumber": phone,
            "paymentPurpose": payment['purpose'].paymentPurpose.toUpperCase(),
            "amountToPay": payment['currentAmount'],
            "paymentDate": _paymentDate.toIso8601String(),
            "termId": payment['termId'],
            "syncStatus": false,
            "lastModified": DateTime.now().toIso8601String(),
            "operationType": "create",
            "paymentMethodType": _paymentMethodType,
            "paymentMethodAmount": amountReceived,
            "paymentReference": _pmReferenceCtrl.text.trim(),
            "mobileMoneyPhone": _pmPhoneCtrl.text.trim(),
            "mobileMoneyProvider": _provider ?? '',
            "bankAccountNumber": _pmAccountNumberCtrl.text.trim(),
            "bankAccountName": _pmAccountNameCtrl.text.trim(),
            "changeGiven": changeGiven,
            "modifiedFields": [
              "id",
              "receiptNumber",
              "studentName",
              "studentSurname",
              "studentClass",
              "phoneNumber",
              "paymentPurpose",
              "amountToPay",
              "paymentDate",
              "termId",
              "username",
              "role",
              "paymentMethodType",
              "paymentMethodAmount",
              "paymentReference",
              "mobileMoneyPhone",
              "mobileMoneyProvider",
              "bankAccountNumber",
              "bankAccountName",
              "changeGiven",
            ],
          });
        }
        debugPrint(
            '⏱️ [6b] Payment payload built in ${DateTime.now().difference(payloadStart).inMilliseconds}ms, ${paymentsToSend.length} payments');

        final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';
        final uri = Uri.parse('http://$hostIp:8080/api/studentPayments/bulk');

        try {
          // ✅ STEP 1: Save payment to database FIRST
          debugPrint('⏱️ [7] SENDING PAYMENT TO HOST via HTTP POST...');
          final httpStart = DateTime.now();
          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"payments": paymentsToSend}),
          );
          debugPrint(
              '⏱️ [7] HTTP POST completed in ${DateTime.now().difference(httpStart).inMilliseconds}ms, status: ${response.statusCode}');

          final school = await _getSchoolInfo();
          final schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

          if (response.statusCode == 200) {
            debugPrint('⏱️ [8] Payment successful on host!');

            final List<Future> smsTasks = [];

            // ✅ Payment successful - Now send SMS notifications
            debugPrint('⏱️ [9] Sending SMS notifications...');
            final smsSendStart = DateTime.now();

            if (termAggregation) {
              if (phone.isNotEmpty) {
                smsTasks.add(_sendSmsNotification(allPaymentsInfonew, phone));
                smsTasks.add(Future.delayed(const Duration(milliseconds: 800)));
              }
              if (phone1 != null && phone1.isNotEmpty) {
                smsTasks.add(_sendSmsNotification(allPaymentsInfonew1, phone1));
                smsTasks.add(Future.delayed(const Duration(milliseconds: 800)));
              }
            } else {
              if (phone.isNotEmpty) {
                smsTasks.add(_sendSmsNotification(allPaymentsInfonew, phone));
                smsTasks.add(Future.delayed(const Duration(milliseconds: 800)));
              }
              if (phone1 != null && phone1.isNotEmpty) {
                smsTasks.add(_sendSmsNotification(allPaymentsInfonew1, phone1));
                smsTasks.add(Future.delayed(const Duration(milliseconds: 800)));
              }
            }

            final adminUsersClient = _users
                .where((u) =>
                    u.role.toLowerCase() == "admin" ||
                    u.role.toLowerCase() == "administration")
                .toList();

            // Send admin SMS
            final adminSmsFutures = <Future>[];
            for (final admin in adminUsersClient) {
              adminSmsFutures
                  .add(sendSms(allPaymentsInfoadminnew, admin.phone));
            }
            await Future.wait(adminSmsFutures);
            debugPrint(
                '⏱️ [9] SMS sending completed in ${DateTime.now().difference(smsSendStart).inMilliseconds}ms');

            debugPrint('⏱️ [10] Clearing records and resetting...');
            await _clearStudentRecordsAfterPayment();
            await _clearPaymentRecords();
            _resetForm();
            _clearAllServerCaches();
            Navigator.pop(context);
            Navigator.pop(context);
            debugPrint(
                '⏱️ [END] Payment completed in ${stopwatch.elapsedMilliseconds}ms');
          } else {
            debugPrint('❌ Host rejected payment: ${response.body}');
            _showDialog("❌ Host rejected payment: ${response.body}");
            _clearAllServerCaches();
          }
        } catch (e) {
          debugPrint('❌ Failed to send payment to host: $e');
          _showDialog("❌ Failed to send payment to host.");
          _clearAllServerCaches();
        } finally {
          if (mounted) setState(() => _isProcessingPayment = false);
        }
      } else {
        // HOST MODE
        debugPrint('⏱️ [6] HOST MODE: Starting payment process...');

        debugPrint('⏱️ [7] Opening payment box...');
        final boxStart = DateTime.now();
        final paymentBox =
            await Hive.openBox<StudentPayment>('student_payments');
        debugPrint(
            '⏱️ [7] Payment box opened in ${DateTime.now().difference(boxStart).inMilliseconds}ms');

        debugPrint('⏱️ [8] Getting next ID...');
        final idStart = DateTime.now();
        int newId = useId ?? await getNextId(); // ← Use provided ID or fetch

        debugPrint(
            '⏱️ [8] getNextId completed in ${DateTime.now().difference(idStart).inMilliseconds}ms, newId: $newId');
        // ✅ STEP 1: Save payment to database FIRST
        debugPrint('⏱️ [9] Saving payments to Hive...');
        final hiveStart = DateTime.now();
        for (var payment in _paymentPurposes) {
          final paymentPurpose =
              payment['purpose'].paymentPurpose.toUpperCase();
          final paymentAmount = payment['currentAmount'];
          String receiptNumber = await getNextReceipt();

          List<String> modifiedFields = [];
          modifiedFields.add('id');
          modifiedFields.add('receiptNumber');
          modifiedFields.add('studentName');
          modifiedFields.add('studentSurname');
          modifiedFields.add('studentClass');
          modifiedFields.add('phoneNumber');
          modifiedFields.add('paymentPurpose');
          modifiedFields.add('amountToPay');
          modifiedFields.add('paymentDate');
          modifiedFields.add('termId');
          modifiedFields.add('username');
          modifiedFields.add('role');
          modifiedFields.add('paymentMethodType');
          modifiedFields.add('paymentMethodAmount');
          modifiedFields.add('paymentReference');
          modifiedFields.add('mobileMoneyPhone');
          modifiedFields.add('mobileMoneyProvider');
          modifiedFields.add('bankAccountNumber');
          modifiedFields.add('bankAccountName');
          modifiedFields.add('changeGiven');

          final newPayment = StudentPayment(
            id: newId,
            receiptNumber: receiptNumber,
            studentName: studentName,
            studentSurname: studentSurname,
            studentClass: _selectedStudent!.class_,
            phoneNumber: phone,
            paymentPurpose: paymentPurpose,
            amountToPay: paymentAmount,
            paymentDate: _paymentDate,
            termId: payment['termId'],
            syncStatus: false,
            lastModified: DateTime.now(),
            operationType: 'create',
            modifiedFields: modifiedFields,
            username: user,
            role: role,
            paymentMethodType: _paymentMethodType,
            paymentMethodAmount: amountReceived,
            paymentReference: _pmReferenceCtrl.text.trim(),
            mobileMoneyPhone: _pmPhoneCtrl.text.trim(),
            mobileMoneyProvider: _provider ?? '',
            bankAccountNumber: _pmAccountNumberCtrl.text.trim(),
            bankAccountName: _pmAccountNameCtrl.text.trim(),
            changeGiven: changeGiven,
          );

          await paymentBox.add(newPayment);
          newId++; // Increment for next payment
        }
        debugPrint(
            '⏱️ [9] Hive save completed in ${DateTime.now().difference(hiveStart).inMilliseconds}ms');

        // ✅ STEP 2: Payment saved - Now send SMS notifications
        debugPrint('⏱️ [10] Sending SMS notifications...');
        final smsSendStart = DateTime.now();

        await Future.wait(
          adminUsers.map((admin) async {
            final school = await _getSchoolInfo();
            final schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

            try {
              if (termAggregation) {
                await Future.wait(
                  adminUsers.map(
                      (admin) => sendSms(allPaymentsInfoadminnew, admin.phone)),
                );
              } else {
                await sendSms(allPaymentsInfoadminnew, admin.phone);
              }
            } catch (e) {
              print(
                  "⚠️ Failed to send SMS to ${admin.username} (${admin.phone}): $e");
            }
          }),
        );

        final school = await _getSchoolInfo();
        final schoolName = school.schoolName?.toUpperCase() ?? 'SCHOOL';

        if (termAggregation) {
          if (phone.isNotEmpty) {
            await _sendSmsNotification(allPaymentsInfonew, phone);
          }
          if (phone1 != null && phone1.isNotEmpty) {
            await _sendSmsNotification(allPaymentsInfonew1, phone1);
          }
        } else {
          if (phone.isNotEmpty) {
            await _sendSmsNotification(allPaymentsInfonew, phone);
          }
          if (phone1 != null && phone1.isNotEmpty) {
            await _sendSmsNotification(allPaymentsInfonew1, phone1);
          }
        }
        debugPrint(
            '⏱️ [10] SMS sending completed in ${DateTime.now().difference(smsSendStart).inMilliseconds}ms');

        debugPrint('⏱️ [11] Clearing records and resetting...');
        await _clearStudentRecordsAfterPayment();
        await _clearPaymentRecords();
        _resetForm();
        _clearAllServerCaches();
        _showDialog('Student Payment Made SUCCESSFULLY.');
        Navigator.pop(context);
        Navigator.pop(context);
        _resetForm();
        debugPrint(
            '⏱️ [END] Payment completed in ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }

  /// Clears ALL restoration-related variables after successful payment
  Future<void> _clearAllRestorationData() async {
    setState(() {
      // Clear pending restorations list
      _pendingRestorations.clear();

      // Clear updated arrears cache
      _updatedArrearsCache.clear();

      // Increment arrears version to force UI refresh
      _arrearsVersion++;

      // Clear any other restoration-related state
      // If you have these variables, uncomment them:
      // _tempArrearsBalances?.clear();
      // _pendingAdjustments?.clear();
      // _restoredItems?.clear();
    });

    // Force refresh the arrears section to show cleared state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_arrearsSectionKey.currentState != null) {
        _arrearsSectionKey.currentState?.refresh();
      }
    });
  }

  /// Clears all previous student records after successful payment
  Future<void> _clearStudentRecordsAfterPayment() async {
    try {
      setState(() {
        // Clear the selected student
        _selectedStudent = null;

        // Clear payment purposes list
        _paymentPurposes.clear();

        // ========== CLEAR ALL RESTORATION VARIABLES ==========
        _pendingRestorations.clear();
        _updatedArrearsCache.clear();
        _arrearsVersion++; // Force UI refresh
        // =====================================================

        // Clear any cached payment data
        _clearAllServerCaches();

        // Reset form fields
        _pmAmountCtrl.clear();
        _pmReferenceCtrl.clear();
        _pmPhoneCtrl.clear();
        _pmAccountNumberCtrl.clear();
        _pmAccountNameCtrl.clear();

        // Reset payment method variables
        _paymentMethodType = 'CASH';
        _provider = null;
      });

      // Force refresh the arrears section
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_arrearsSectionKey.currentState != null) {
          _arrearsSectionKey.currentState?.refresh();
        }
      });
    } catch (e) {
      print('❌ Error clearing student records: $e');
    }
  }

  Future<void> _clearPaymentRecords() async {
    setState(() {
      // Clear payment purposes
      _paymentPurposes.clear();

      // Reset form fields
      _pmAmountCtrl.clear();
      _pmReferenceCtrl.clear();
      _pmPhoneCtrl.clear();
      _pmAccountNumberCtrl.clear();
      _pmAccountNameCtrl.clear();

      // Reset payment method
      _paymentMethodType = 'CASH';
      _provider = null;

      // Keep the selected student
      // _selectedStudent remains unchanged
    });
  }

  Map<String, dynamic> buildPaymentSnapshot() {
    final received = finalReceived ?? finalReceived ?? 0.0;
    final change = received > _totalEntered ? received - _totalEntered : 0.0;

    return {
      "type": _paymentMethodType,
      "totalDue": _totalEntered,
      "amountReceived": received,
      "change": change,
      "reference": _pmReferenceCtrl.text.trim(),
      "phone": _pmPhoneCtrl.text.trim(),
      "provider": _provider ?? '',
      "accountNumber": _pmAccountNumberCtrl.text.trim(),
      "accountName": _pmAccountNameCtrl.text.trim(),
      "currency": _currency,
    };
  }

  String formatPaymentSnapshot() {
    final received = finalReceived ?? finalReceived ?? 0.0;
    final change = received > _totalEntered ? received - _totalEntered : 0.0;
    final buffer = StringBuffer();

    buffer.writeln("PAYMENT DETAILS");
    buffer.writeln("--------------------------------");

    buffer.writeln("Method: ${_paymentMethodType.toUpperCase()}");
    buffer.writeln("Total Due: $_currency ${_totalEntered.toStringAsFixed(2)}");
    buffer
        .writeln("Amount Received: $_currency ${received.toStringAsFixed(2)}");
    buffer.writeln("Change: $_currency ${change.toStringAsFixed(2)}");

    // ✅ NEW: Change settlement status
    buffer.writeln("Change Settled: ${_changeSettled ? 'YES' : 'NO'}");

    // Optional (powerful)
    if (!_changeSettled && change > 0) {
      buffer.writeln("Pending Change: $_currency ${change.toStringAsFixed(2)}");
    }

    if (_pmReferenceCtrl.text.trim().isNotEmpty) {
      buffer.writeln("Reference: ${_pmReferenceCtrl.text.trim()}");
    }

    if (_paymentMethodType == 'mobile_money') {
      if (_pmPhoneCtrl.text.trim().isNotEmpty) {
        buffer.writeln("Phone: ${_pmPhoneCtrl.text.trim()}");
      }
      if (_provider != null && _provider!.isNotEmpty) {
        buffer.writeln("Provider: $_provider");
      }
    }

    if (_paymentMethodType == 'bank_transfer') {
      if (_pmAccountNumberCtrl.text.trim().isNotEmpty) {
        buffer.writeln("Acc No: ${_pmAccountNumberCtrl.text.trim()}");
      }
      if (_pmAccountNameCtrl.text.trim().isNotEmpty) {
        buffer.writeln("Acc Name: ${_pmAccountNameCtrl.text.trim()}");
      }
    }

    return buffer.toString();
  }

  String buildProjectArrearsSummary(List<ArrearsSummary> list) {
    if (list.isEmpty) return "";

    final buffer = StringBuffer();

    double total = 0;

    for (final s in list) {
      buffer.writeln(
          "${s.projectName} - ${s.itemName} : \$${s.arrears.toStringAsFixed(2)}");
      total += s.arrears;
    }

    buffer.writeln("------------------------");
    buffer.writeln("TOTAL PROJECT ARREARS: \$${total.toStringAsFixed(2)}");

    return buffer.toString();
  }

  String buildAggregatedPaymentSummary(
      String schoolName,
      String parentName,
      String studentName,
      List<Map<String, dynamic>>
          payments, // {'purpose': PaymentPurpose, 'amount': double, 'termId': String}
      Map<String, String> termsMap,
      {String? projectArrearsSummary} // 👈 NEW
      // termId -> termName
      ) {
    // Map of paymentPurpose → Map<cleanTermName, totalAmount>
    final Map<String, Map<String, double>> summary = {};

    for (var payment in payments) {
      final purposeName = payment['purpose'].paymentPurpose ?? 'UNKNOWN';
      final termId = payment['termId'] ?? '';
      final amount = payment['currentAmount'] as double? ?? 0.0;

      // Clean the term name by removing brackets
      final termName = termsMap[termId] ?? termId;
      final cleanTermName =
          termName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      summary.putIfAbsent(purposeName, () => {});
      summary[purposeName]
          ?.update(cleanTermName, (v) => v + amount, ifAbsent: () => amount);
    }

    final buffer = StringBuffer();
    buffer.write('$schoolName\n Dear $parentName,\n $studentName has paid ');

    final parts = <String>[];
    summary.forEach((purpose, termMap) {
      termMap.forEach((cleanTermName, totalAmount) {
        parts.add(
            '\$${totalAmount.toStringAsFixed(2)} for ${purpose.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim().toUpperCase()} of $cleanTermName');
      });
    });

    buffer.write(parts.join(' \n And '));
    buffer.write('.');
    if (projectArrearsSummary != null &&
        projectArrearsSummary.trim().isNotEmpty) {
      buffer.writeln('Project Arrears Section:');
      buffer.writeln(projectArrearsSummary.trim());

      buffer.write('.');
      buffer.writeln('Fees Arrears section:');
    }
    return buffer.toString();
  }

  String buildAggregatedPaymentSummary1(
      String schoolName,
      String parentName1,
      String studentName,
      List<Map<String, dynamic>>
          payments, // {'purpose': PaymentPurpose, 'amount': double, 'termId': String}
      Map<String, String> termsMap,
      {String? projectArrearsSummary} // 👈 NEW
      // termId -> termName
      ) {
    // Map of paymentPurpose → Map<cleanTermName, totalAmount>
    final Map<String, Map<String, double>> summary = {};

    for (var payment in payments) {
      final purposeName = payment['purpose'].paymentPurpose ?? 'UNKNOWN';
      final termId = payment['termId'] ?? '';
      final amount = payment['currentAmount'] as double? ?? 0.0;

      // Clean the term name by removing brackets
      final termName = termsMap[termId] ?? termId;
      final cleanTermName =
          termName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      summary.putIfAbsent(purposeName, () => {});
      summary[purposeName]
          ?.update(cleanTermName, (v) => v + amount, ifAbsent: () => amount);
    }

    final buffer = StringBuffer();
    buffer.write('$schoolName\n Dear $parentName1,\n $studentName has paid ');

    final parts = <String>[];
    summary.forEach((purpose, termMap) {
      termMap.forEach((cleanTermName, totalAmount) {
        parts.add(
            '\$${totalAmount.toStringAsFixed(2)} for ${purpose.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim().toUpperCase()} of $cleanTermName');
      });
    });

    buffer.write(parts.join(' \n And '));
    buffer.write('.');
    if (projectArrearsSummary != null &&
        projectArrearsSummary.trim().isNotEmpty) {
      buffer.writeln('Project Arrears Section:');
      buffer.writeln(projectArrearsSummary.trim());
      buffer.write('.');
      buffer.writeln('Fees Arrears section:');
    }
    return buffer.toString();
  }

  String buildAggregatedPaymentSummaryadmin(
      String schoolName,
      String studentName,
      List<Map<String, dynamic>>
          payments, // {'purpose': PaymentPurpose, 'amount': double, 'termId': String}
      Map<String, String> termsMap,
      {String? projectArrearsSummary} // 👈 NEW
      // termId -> termName
      ) {
    // Map of paymentPurpose → Map<cleanTermName, totalAmount>
    final Map<String, Map<String, double>> summary = {};

    for (var payment in payments) {
      final purposeName = payment['purpose'].paymentPurpose ?? 'UNKNOWN';
      final termId = payment['termId'] ?? '';
      final amount = payment['currentAmount'] as double? ?? 0.0;

      // Clean the term name by removing brackets
      final termName = termsMap[termId] ?? termId;
      final cleanTermName =
          termName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      summary.putIfAbsent(purposeName, () => {});
      summary[purposeName]
          ?.update(cleanTermName, (v) => v + amount, ifAbsent: () => amount);
    }

    final buffer = StringBuffer();
    buffer.write('$schoolName\n $studentName  paid ');

    final parts = <String>[];
    summary.forEach((purpose, termMap) {
      termMap.forEach((cleanTermName, totalAmount) {
        parts.add(
            '\$${totalAmount.toStringAsFixed(2)} for $purpose of $cleanTermName');
      });
    });

    buffer.write(parts.join(' and '));
    buffer.write('.');
    if (projectArrearsSummary != null &&
        projectArrearsSummary.trim().isNotEmpty) {
      buffer.writeln('Project Arrears section:');
      buffer.writeln(projectArrearsSummary.trim());
      buffer.write('.');
      buffer.writeln('Fees Arrears section:');
    }
    return buffer.toString();
  }

  Future<int> getNextId() async {
    // If ID Manager is not initialized, initialize it
    if (!_idManagerInitialized) {
      await _initIdManager();
    }

    try {
      final role = await getDeviceRole();

      if (role == DeviceRole.host) {
        // HOST: Get current ID WITHOUT incrementing
        final idService = IdService();
        final currentId = await idService.getCurrentId();

        // Mark the ID as reserved (this will increment the counter)
        await idService.reserveSingleId(clientId: 'host');

        // Return the ID BEFORE increment
        return currentId + 1; // Returns the next available ID
      } else {
        // CLIENT: Get next ID from manager
        // The manager should return the current ID and increment internally
        return await _idManager.getNextId();
      }
    } catch (e) {
      debugPrint('❌ Error getting next ID: $e');
      _localIdCounter++;
      debugPrint('⚠️ Using fallback ID: $_localIdCounter');
      return _localIdCounter;
    }
  }

// Add this method to your class - WITHOUT custom fonts
  Future<void> _generatePdfPreview() async {
    if (_selectedStudent == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();

      // Fetch arrears data
      final purposeList =
          await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
              _selectedStudent!);
      final feesArrears = await _totalArrearsFuture;
      final studentId = _selectedStudent!.studentIdNumber.toString();
      final projectArrearsDetails = buildStudentArrearsDetails(studentId);
      final totalProjectArrears =
          projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);
      final grandTotal = (feesArrears ?? 0) + totalProjectArrears;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // Header
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    'STUDENT FEE STATEMENT',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated on: ${DateTime.now().toString().substring(0, 19)}',
                    style:
                        const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),

            // Student Information Section
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'STUDENT INFORMATION',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildInfoRow('Full Name',
                      '${_selectedStudent!.name} ${_selectedStudent!.surname}'),
                  _buildInfoRow('Class', _selectedStudent!.class_ ?? 'N/A'),
                  _buildInfoRow('Student ID',
                      _selectedStudent!.studentIdNumber.toString()),
                  _buildInfoRow(
                      'Phone Number', _selectedStudent!.phoneNumber ?? 'N/A'),
                  if (_selectedStudent!.emergencyContactNumber != null &&
                      _selectedStudent!.emergencyContactNumber!.isNotEmpty)
                    _buildInfoRow('Emergency Contact',
                        '${_selectedStudent!.emergencyContactName}: ${_selectedStudent!.emergencyContactNumber}'),
                  _buildInfoRow('Payment Status',
                      _selectedStudent!.paymentStatus ?? 'N/A'),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Arrears Overview Section
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FEES ARREARS OVERVIEW',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 15),

                  // Fees Arrears
                  _buildAmountRow('Fees Arrears', feesArrears ?? 0,
                      color: (feesArrears ?? 0) > 0
                          ? PdfColors.red
                          : PdfColors.green),

                  if (totalProjectArrears > 0)
                    _buildAmountRow('Project Arrears', totalProjectArrears,
                        color: PdfColors.orange),

                  pw.Divider(thickness: 1),
                  _buildAmountRow('Total Outstanding', grandTotal,
                      color: PdfColors.red, isBold: true, fontSize: 18),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Payment Purposes Section
            if (purposeList.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PAYMENT PURPOSES',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    ...purposeList.map((entry) {
                      final purpose = entry['purpose'];
                      final preview = entry['arrearsPreview'];
                      return pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey200),
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              purpose.paymentPurpose ?? 'N/A',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              preview,
                              style: const pw.TextStyle(
                                  fontSize: 11, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

            pw.SizedBox(height: 20),

            // Project Arrears Details Section
            if (projectArrearsDetails.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PROJECT ARREARS DETAILS',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            _buildTableCell('Project Name', isHeader: true),
                            _buildTableCell('Item', isHeader: true),
                            _buildTableCell('Batch', isHeader: true),
                            _buildTableCell('Arrears',
                                isHeader: true,
                                alignment: pw.Alignment.centerRight),
                          ],
                        ),
                        ...projectArrearsDetails.map((detail) => pw.TableRow(
                              children: [
                                _buildTableCell(detail.projectName),
                                _buildTableCell(detail.itemName),
                                _buildTableCell(detail.batchName),
                                _buildTableCell(
                                  '\$${detail.arrears.toStringAsFixed(2)}',
                                  alignment: pw.Alignment.centerRight,
                                ),
                              ],
                            )),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Total Project Arrears: \$${totalProjectArrears.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'This is a computer-generated statement. No signature required.',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'For any discrepancies, please contact the accounts office.',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show PDF preview
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Student_Statement_${_selectedStudent!.studentIdNumber}.pdf',
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
      print('Error generating PDF: $e');
    }
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

  Future<String> getNextReceipt() async {
    const uuid = Uuid();

    String receiptNo = uuid.v4();

    return receiptNo;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetForm() {
    _studentSearchController.clear();
    _pmAmountCtrl.clear();
    _pmReferenceCtrl.clear();
    _pmPhoneCtrl.clear();
    _pmAccountNumberCtrl.clear();
    _pmAccountNameCtrl.clear();
    _provider = '';
    _paymentMethodType = 'cash';
    setState(() {
      _selectedStudent = null;
      _paymentPurposes.clear();
      _paymentDate = DateTime.now();
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.isEmpty) return;

    _searchStudent(query, showDialog: true);
  }

  double get totalEntered =>
      _paymentPurposes.fold(0.0, (sum, p) => sum + (p['currentAmount'] ?? 0.0));
  void _splitPaymentOnAmountChange(
    int index,
    double paidAmount,
    double originalAmount,
    Map<String, dynamic> payment,
  ) {
    final remainingAmount = originalAmount - paidAmount;

    setState(() {
      // Update the current payment to reflect only the paid amount
      payment['currentAmount'] = paidAmount;
      payment['originalAmount'] = paidAmount;
      payment['isRemainingArrears'] = false;

      // Remove any error if present
      payment['amountError'] = null;

      // Update the controller text
      if (_amountControllers.containsKey(index)) {
        _amountControllers[index]?.text = paidAmount.toStringAsFixed(2);
      }

      _updateTotalEntered();
    });

    // RESTORE THE REMAINING AMOUNT TO ARREARS SECTION
    _restoreToArrearsList(
      payment['purpose'],
      payment['termId'] ?? '',
      remainingAmount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;
    Widget searchField = RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: isWindows ? _handleKeyEvent : null,
      child: TextFormField(
        controller: _studentSearchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onFieldSubmitted: (value) {
          _performSearch(value.trim());
        },
        decoration: InputDecoration(
          labelText: 'Search Student by Surname',
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                _performSearch(_studentSearchController.text.trim()),
          ),
        ),
        onChanged: (value) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(_searchDebounceDuration, () {
            _searchStudent(value.trim(), showDialog: false);
          });
        },
      ),
    );
    if (globalTermId != null) {
      return Stack(
        children: [
          Scaffold(
            floatingActionButton: _buildFloatingActionButton(),
            appBar: AppBar(
              title: const Center(
                child: Text(
                  'Make Payment',
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
                  icon: const Icon(Icons.print),
                  onPressed: _printStatementViaBluetooth,
                  tooltip: Platform.isAndroid
                      ? 'Print Statement via Bluetooth'
                      : 'Print Statement via Windows Printer',
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _generatePdfPreview,
                  tooltip: 'Generate PDF Statement',
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
                            searchField,
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
                                                      onScrollToConfirmButton:
                                                          () {
                                                        _scrollToConfirmButton();
                                                      },
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
                            const SizedBox(height: 20),
                            Container(
                              key: _dataTableKey, // Add this key

                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Purpose')),
                                    DataColumn(label: Text('Amount')),
                                    DataColumn(label: Text('Term')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: _paymentPurposes
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final int index = entry.key;
                                    final payment = entry.value;
                                    final PaymentPurpose purpose =
                                        payment['purpose'];

                                    final double originalAmount =
                                        payment['originalAmount'] as double;
                                    final double currentAmount =
                                        payment['currentAmount'] as double;
                                    final String termId = payment['termId'] ??
                                        purpose.termId ??
                                        '';
                                    final term = _termsMap[termId];
                                    final termDisplay = term != null
                                        ? '(${term.termName})'
                                        : '(Unknown)';

                                    // ✅ Get or create controller for this row
                                    if (!_amountControllers
                                        .containsKey(index)) {
                                      _amountControllers[index] =
                                          TextEditingController(
                                        text:
                                            (payment['currentAmount'] as double)
                                                .toStringAsFixed(2),
                                      );
                                    }
                                    final controller =
                                        _amountControllers[index]!;
                                    final Map<int, FocusNode> _focusNodes = {};
                                    if (!_focusNodes.containsKey(index)) {
                                      _focusNodes[index] = FocusNode();
                                    }
                                    final focusNode = _focusNodes[index]!;
                                    return DataRow(
                                      color:
                                          payment['isRemainingArrears'] == true
                                              ? WidgetStateProperty.all(
                                                  Colors.orange.shade50)
                                              : null,
                                      cells: [
                                        DataCell(Text(
                                            payment['purpose'].paymentPurpose)),
                                        // Get or create focus node

                                        // Remove the timer maps and timer-related code

                                        // Updated DataCell with check icon that stays visible once editing starts
                                        DataCell(
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 100,
                                                child: TextFormField(
                                                  controller: controller,
                                                  focusNode: _focusManager
                                                      .getFocusNode(index),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    prefixText: '\$',
                                                    border:
                                                        const OutlineInputBorder(),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    errorText:
                                                        payment['amountError'],
                                                  ),
                                                  onChanged: (value) {
                                                    // Mark as editing when user types - icon appears and STAYS
                                                    _startEditing(index);

                                                    if (value.isEmpty) {
                                                      payment['currentAmount'] =
                                                          0.0;
                                                      payment['amountError'] =
                                                          null;
                                                    } else {
                                                      final double? newAmount =
                                                          double.tryParse(
                                                              value);
                                                      if (newAmount == null) {
                                                        payment['amountError'] =
                                                            'Invalid amount';
                                                      } else if (newAmount >
                                                          originalAmount) {
                                                        payment['amountError'] =
                                                            'Cannot exceed \$${originalAmount.toStringAsFixed(2)}';
                                                        payment['currentAmount'] =
                                                            originalAmount;
                                                        controller.text =
                                                            originalAmount
                                                                .toStringAsFixed(
                                                                    2);
                                                      } else if (newAmount <=
                                                          0) {
                                                        payment['amountError'] =
                                                            'Amount must be greater than zero';
                                                        payment['currentAmount'] =
                                                            0.0;
                                                      } else {
                                                        payment['amountError'] =
                                                            null;
                                                        payment['currentAmount'] =
                                                            newAmount;
                                                      }
                                                    }
                                                    _pmAmountCtrl.text =
                                                        _totalEntered
                                                            .toStringAsFixed(2);
                                                  },
                                                  onTap: () {
                                                    // Mark as editing when field is tapped - icon appears and STAYS
                                                    _startEditing(index);

                                                    controller.selection =
                                                        TextSelection(
                                                      baseOffset: 0,
                                                      extentOffset: controller
                                                          .text.length,
                                                    );
                                                  },
                                                ),
                                              ),
                                              // Show check icon ONLY if:
                                              // 1. This is not a remaining arrears item
                                              // 2. The user has started editing this field (icon stays once appeared)
                                              // 3. The entered amount is partial (not full amount)
                                              if (payment['isRemainingArrears'] !=
                                                      true &&
                                                  _isEditingAmount[index] ==
                                                      true &&
                                                  payment['currentAmount'] >
                                                      0 &&
                                                  payment['currentAmount'] <
                                                      originalAmount)
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green),
                                                  tooltip:
                                                      'Confirm partial payment and split remaining',
                                                  onPressed: () {
                                                    final double newAmount =
                                                        payment['currentAmount']
                                                            as double;
                                                    if (newAmount > 0 &&
                                                        newAmount <
                                                            originalAmount) {
                                                      _splitPaymentOnAmountChange(
                                                        index,
                                                        newAmount,
                                                        originalAmount,
                                                        payment,
                                                      );
                                                      // Icon disappears only after split is confirmed
                                                      _stopEditing(index);
                                                    }
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(termDisplay)),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.red),
                                            tooltip: 'Remove this purpose',
                                            onPressed: () {
                                              final currentAmt =
                                                  payment['currentAmount']
                                                      as double;

                                              final originalAmt =
                                                  payment['originalAmount']
                                                      as double;

                                              final termId =
                                                  payment['termId'] ??
                                                      payment['purpose']
                                                          .termId ??
                                                      '';
                                              final purpose =
                                                  payment['purpose'];

                                              // ========== 🆕 REMOVE FROM PENDING RESTORATIONS ==========
                                              // Find and remove any pending restoration that matches this purpose and term
                                              final restorationIndex =
                                                  _pendingRestorations.indexWhere(
                                                      (restoration) =>
                                                          restoration[
                                                                  'purpose'] ==
                                                              purpose &&
                                                          restoration[
                                                                  'termId'] ==
                                                              termId);

                                              if (restorationIndex != -1) {
                                                final removedRestoration =
                                                    _pendingRestorations[
                                                        restorationIndex];

                                                _pendingRestorations
                                                    .removeAt(restorationIndex);
                                              }
                                              // =========================================================

                                              // If this was a partial payment, restore the remaining amount
                                              if (currentAmt < originalAmt &&
                                                  payment['isRemainingArrears'] !=
                                                      true) {
                                                final amountToRestore =
                                                    originalAmt - currentAmt;

                                                _restoreToArrearsList(
                                                  payment['purpose'],
                                                  payment['termId'] ?? '',
                                                  amountToRestore,
                                                );
                                              }

                                              // If this is a remaining arrears item, restore full amount
                                              if (payment[
                                                      'isRemainingArrears'] ==
                                                  true) {
                                                _restoreToArrearsList(
                                                  payment['purpose'],
                                                  payment['termId'] ?? '',
                                                  originalAmt,
                                                );
                                              }

                                              setState(() {
                                                // Dispose controller

                                                _amountControllers
                                                    .remove(index);
                                                _paymentPurposes
                                                    .removeAt(index);
                                                _amountControllers[index]
                                                    ?.dispose();
                                                // Re-index remaining controllers
                                                final newControllers = <int,
                                                    TextEditingController>{};
                                                for (int i = 0;
                                                    i < _paymentPurposes.length;
                                                    i++) {
                                                  if (_amountControllers
                                                      .containsKey(i)) {
                                                    newControllers[i] =
                                                        _amountControllers[i]!;
                                                  } else if (_amountControllers
                                                      .containsKey(i + 1)) {
                                                    newControllers[i] =
                                                        _amountControllers[
                                                            i + 1]!;
                                                  }
                                                }
                                                _amountControllers.clear();
                                                _amountControllers
                                                    .addAll(newControllers);
                                                _reindexControllers();
                                                _updateTotalEntered();
                                              });

                                              // Force refresh the ArrearsSection
                                              _arrearsSectionKey.currentState
                                                  ?.refresh();
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                'Total Amount Entered: \$$_currency ${_totalEntered.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _paymentPurposeSection(),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Change Settled?",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _changeSettled ? "YES" : "NO",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _changeSettled
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      key: ValueKey(_changeSettled),
                                      value: _changeSettled,
                                      activeColor: Colors.green,
                                      inactiveThumbColor: Colors.red,
                                      onChanged: (value) {
                                        setState(() {
                                          _changeSettled = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton(
                              key: _confirmButtonKey, // Add this key
                              onPressed: _confirmPayment,
                              child: const Text('Confirm Payment'),
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
          if (_isProcessingPayment)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true, // Prevent all taps
                child: Container(
                  color: Colors.black.withOpacity(0.4), // Greyout overlay
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Processing payment, please wait...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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

  void _refreshArrears() {
    setState(() {
      _arrearsVersion++; // This triggers ArrearsSection to reload
    });
  }

  void _scrollToConfirmButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox =
          _confirmButtonKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero).dy;
        final currentOffset = _mainScrollController.offset;
        final targetOffset = currentOffset + position - 100;

        _mainScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          _scrollToConfirmButton();
        });
      }
    });
  }

// Add this map to store updated arrears amounts
  final Map<String, Map<String, double>> _updatedArrearsCache = {};

  void _restoreToArrearsList(
      PaymentPurpose purpose, String termId, double amount) {
    setState(() {
      _arrearsVersion++;

      // Check if there's already a pending restoration for this purpose/term
      bool found = false;
      for (var restoration in _pendingRestorations) {
        if (restoration['purpose'] == purpose &&
            restoration['termId'] == termId) {
          // Merge amounts
          restoration['amount'] = (restoration['amount'] as double) + amount;
          found = true;
          break;
        }
      }

      if (!found) {
        _pendingRestorations.add({
          'purpose': purpose,
          'termId': termId,
          'amount': amount,
          'timestamp': DateTime.now(),
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _arrearsSectionKey.currentState?.refresh();
    });
  }

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

  // In your _MakePaymentScreenState class
  Future<List<Map<String, dynamic>>> _getCurrentArrearsForReceipt() async {
    // Get the current data from ArrearsSection
    final currentData =
        _arrearsSectionKey.currentState?.getCurrentArrearsData();
    if (currentData != null && currentData.isNotEmpty) {
      return currentData;
    }
    return [];
  }

// Store pending updates
  List<Map<String, dynamic>> _arrearsUpdates = [];

  void _refreshPurposeList() {
    // This will cause the FutureBuilder to refetch
    setState(() {
      _purposeListVersion++; // Add a version counter variable
    });
  }

  Widget _buildFeesQuickSummary() {
    if (_selectedStudent == null) {
      return const SizedBox.shrink();
    }

    final term = _selectedArrearsTerm;
    final amount = _paymentAmount ?? 0.0;
    final arrears = term != null ? (_arrearsDetails[term] ?? 0.0) : 0.0;

    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "💳 Fees Payment Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const Divider(),

            Text(
              "Student: ${_selectedStudent!.name} ${_selectedStudent!.surname}",
            ),

            const SizedBox(height: 6),

            /// 🔥 PURPOSE (optional now)
            Text(
              "Purpose: ${_selectedPaymentPurpose?.paymentPurpose ?? 'Not selected'}",
            ),

            const SizedBox(height: 6),

            Text("Term: ${term ?? '-'}"),

            const SizedBox(height: 6),

            Text(
              "Arrears: \$${arrears.toStringAsFixed(2)}",
              style: TextStyle(
                color: arrears > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Amount to Pay: \$${amount.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            if (term != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  term == globalTermId
                      ? '✔ Prepayment allowed'
                      : '⚠ Cannot exceed arrears',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: term == globalTermId ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Timer? _debounce;

  Widget _paymentPurposeSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            /// PAYMENT METHOD
            DropdownButtonFormField<String>(
              value: _paymentMethodType,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(
                    value: 'mobile_money', child: Text('Mobile Money')),
                DropdownMenuItem(
                    value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _paymentMethodType = v!),
            ),
            const SizedBox(height: 12),
            // Your TextFormField with debug lines
            TextFormField(
              controller: _pmAmountCtrl,
              focusNode: _pmAmountFocusNode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '\$',
                border: OutlineInputBorder(),
                labelText: 'Amount Received',
                hintText: 'Enter amount received',
              ),
              onTap: () {
                _originalTotalForValidation = _totalEntered;
                _lastManuallyEnteredValue = _pmAmountCtrl.text;

                _pmAmountCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _pmAmountCtrl.text.length,
                );
              },
              onChanged: (value) {
                final now = DateTime.now();

                if (_isAutoCorrecting) {
                  return;
                }

                _lastTypingTime = now;
                _lastManuallyEnteredValue = value;

                // Cancel any pending debounce timer
                if (_pmAmountDebounceTimer != null) {
                  _pmAmountDebounceTimer?.cancel();
                }

                // Set a new timer for warning (NOT auto-correction)
                _pmAmountDebounceTimer =
                    Timer(Duration(milliseconds: _pmAmountDebounceDelay), () {
                  final elapsed = DateTime.now()
                      .difference(_lastTypingTime!)
                      .inMilliseconds;

                  if (_lastTypingTime != null &&
                      elapsed >= _pmAmountDebounceDelay) {
                    if (_pmAmountFocusNode.hasFocus) {
                      final received = finalReceived ?? finalReceived ?? 0.0;

                      if (received != null &&
                          received < _totalEntered &&
                          !_isAutoCorrecting) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '⚠️ Amount is less than required ${_formatCurrency(_totalEntered)}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } else {}
                    }
                  }
                });

                // Just validate WITHOUT auto-correction

                _formKey.currentState?.validate();
              },
              onEditingComplete: () {
                if (_isAutoCorrecting) {
                  FocusScope.of(context).nextFocus();
                  return;
                }

                _pmAmountDebounceTimer?.cancel();

                final parsed = double.tryParse(_pmAmountCtrl.text);

                if (parsed != null &&
                    parsed < _totalEntered &&
                    !_isAutoCorrecting) {
                  _isAutoCorrecting = true;
                  final corrected = _totalEntered.toStringAsFixed(2);
                  _pmAmountCtrl.text = corrected;

                  _isAutoCorrecting = false;
                }

                FocusScope.of(context).nextFocus();
              },
              onFieldSubmitted: (value) {
                if (_isAutoCorrecting) return;

                _pmAmountDebounceTimer?.cancel();

                final parsed = double.tryParse(value);
                if (parsed != null &&
                    parsed < _totalEntered &&
                    !_isAutoCorrecting) {
                  _isAutoCorrecting = true;
                  final corrected = _totalEntered.toStringAsFixed(2);
                  _pmAmountCtrl.text = corrected;

                  _isAutoCorrecting = false;
                }
              },
              validator: (value) {
                if (_isAutoCorrecting) {
                  return null;
                }

                if (value == null || value.isEmpty) {
                  return 'Please enter amount received';
                }

                final received = double.tryParse(value);

                if (received == null) {
                  return 'Invalid amount';
                }

                if (received <= 0) {
                  // Auto-correct the field when validator is triggered
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final corrected = _totalEntered.toStringAsFixed(2);
                    _pmAmountCtrl.text = corrected;
                  });
                  return 'Amount cannot be less than ${_formatCurrency(_totalEntered)}';
                }

                return null;
              },
            ),
            if (_pmAmountCtrl.text.isNotEmpty)
              Builder(
                builder: (_) {
                  final received =
                      double.tryParse(_pmAmountCtrl.text.trim()) ?? 0.0;

                  final change =
                      received > _totalEntered ? received - _totalEntered : 0.0;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Payment Summary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Due"),
                            Text(
                              "$_currency ${_totalEntered.toStringAsFixed(2)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Amount Received"),
                            Text(
                              "$_currency ${received.toStringAsFixed(2)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Change",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              "$_currency ${change.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),

            /// ADDITIONAL DETAILS PER PAYMENT METHOD
            if (_paymentMethodType != 'cash') ...[
              TextFormField(
                controller: _pmReferenceCtrl,
                decoration: const InputDecoration(labelText: 'Reference'),
              ),
            ],

            if (_paymentMethodType == 'mobile_money') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _pmPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Provider'),
                onChanged: (v) => _provider = v.trim(),
              ),
            ],

            if (_paymentMethodType == 'bank_transfer') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _pmAccountNumberCtrl,
                decoration: const InputDecoration(labelText: 'Account Number'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pmAccountNameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

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

  Future<List<PaymentPurpose>> _fetchUniquePaymentPurposesByStudent(
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
      // Newcomer-specific exclusion logic
      bool newcomerConditionAllows = true;

      if (isNewcomerRelated) {
        if (student.isNewComer != true) {
          // Not a newcomer at all
          newcomerConditionAllows = false;
        } else {
          if (student.isNewComerUntil != null) {
            final newcomerUntil = student.isNewComerUntil!;
            // Look up the term's start date
            final term = _termsMap[purpose.termId];

            if (term != null) {
              final termStart = term.startDate;

              if (termStart.isAfter(newcomerUntil)) {
                // Term started after newcomer status expired
                newcomerConditionAllows = false;
              }
            }
          }
        }
      }

      final shouldInclude = (isForClass || isException || isNewcomerRelated) &&
          newcomerConditionAllows;

      // Deduplicate by paymentPurpose name
      if (shouldInclude) {
        final nameKey = (purpose.paymentPurpose ?? '').toLowerCase().trim();
        if (!seenPurposeNames.contains(nameKey)) {
          seenPurposeNames.add(nameKey);
          filtered.add(purpose);
        }
      }
    }

    // ------------------------------------------------------------
    // Step 2: Pre-compute arrears for each applicable purpose
    // ------------------------------------------------------------
    final List<PaymentPurpose> purposesWithArrears = [];

    for (final purpose in filtered) {
      try {
        final arrearsData = await _computeArrearsForPurpose(purpose);

        final hasAnyArrears = arrearsData.values.any((v) => v > 0);
        if (hasAnyArrears) {
          purposesWithArrears.add(purpose);
        }
      } catch (e) {
        debugPrint('⚠️ Failed arrears check for ${purpose.paymentPurpose}: $e');
      }
    }

    return purposesWithArrears;
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
    final List<Terms> allTerms = _role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : _cachedServerTerms ?? [];

    final Map<String, double> arrearsDetails = {};

    for (final term in allTerms) {
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

// Fetch payment purposes by termId
  Future<List<PaymentPurpose>> _fetchPaymentPurposesByTerm(
      String termId) async {
    List<PaymentPurpose> allPurposes = [];

    if (_role == DeviceRole.host) {
      // Host reads from local Hive box
      final box = Hive.box<PaymentPurpose>('payment_purposes');
      allPurposes = box.values.toList();
    } else {
      // Client uses cached server data
      allPurposes = _cachedServerStudentPaymentPurposes ?? [];
    }

    return allPurposes.where((purpose) => purpose.termId == termId).toList();
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

// The main print method remains the same
  Future<void> _printStatementViaBluetooth() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student selected')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final purposeList =
          await _fetchUniquePaymentPurposesByStudentWithArrearsForPreviw(
              _selectedStudent!);
      final feesArrears = await _totalArrearsFuture ?? 0.0;
      final studentId = _selectedStudent!.studentIdNumber.toString();
      final projectArrearsDetails = buildStudentArrearsDetails(studentId);
      final totalProjectArrears =
          projectArrearsDetails.fold<double>(0, (sum, e) => sum + e.arrears);
      final grandTotal = feesArrears + totalProjectArrears;
      final loggedInUser = getLoggedInUser();

      final user = loggedInUser.username;

      final username = user != null && user.isNotEmpty ? user : 'Unknown User';
      final School schoolInfo = await _fetchSchoolInfo();

      if (mounted) Navigator.pop(context);
      // 🆕 Platform-specific connection check
      if (Platform.isAndroid && !_connected) {
        await _showBluetoothConnectionDialog();
        return;
      }

      if (Platform.isWindows &&
          (_selectedWindowsPrinter == null || !_connected)) {
        await _showWindowsPrinterConnectionDialog();
        return;
      }
      final List<LineText> statementLines = _buildStatementLines(
        schoolInfo: schoolInfo,
        selectedStudent: _selectedStudent!,
        feesArrears: feesArrears,
        totalProjectArrears: totalProjectArrears,
        grandTotal: grandTotal,
        purposeList: purposeList,
        projectArrearsDetails: projectArrearsDetails,
        generatedBy: username,
      );
      if (Platform.isAndroid) {
        // Android Bluetooth printing
        await bluetoothPrint.printReceipt({}, statementLines);
      } else if (Platform.isWindows) {
        // Windows printing
        await _printToWindowsPrinter(statementLines);
      } else {
        throw Exception('Printing not supported on this platform');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing statement: $e')),
      );
      print('Error printing statement: $e');
    }
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
                        const SizedBox(height: 12),

                        // Select/Deselect Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _selectAllPurposes(true),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.green),
                                  foregroundColor: Colors.green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text("Select All"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _selectAllPurposes(false),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  foregroundColor: Colors.red,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text("Deselect All"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Proceed Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _proceedWithSelected,
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text(
                              "PROCEED TO PAYMENT",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
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

            const SizedBox(height: 42),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _proceedWithSelected,
                icon: const Icon(Icons.payment, size: 18),
                label: const Text(
                  "PROCEED WITH SELECTED",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
