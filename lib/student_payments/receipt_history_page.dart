// lib/student_payments/receipt_history_page.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:background_sms/background_sms.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_log_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/users_serializer.dart';
import 'package:zitf_system/student_payments/reprint_viewer_page.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:http/http.dart' as http;
import 'package:zitf_system/utils/windows_printer_helper_for_reprints.dart';

class ReceiptHistoryPage extends StatefulWidget {
  const ReceiptHistoryPage({super.key});

  @override
  State<ReceiptHistoryPage> createState() => _ReceiptHistoryPageState();
}

class _ReceiptHistoryPageState extends State<ReceiptHistoryPage>
    with WidgetsBindingObserver {
  late Box<PaymentLog> _logBox;
  String _searchQuery = "";
  final Set<int> _selectedIndexes = {};

  // Bluetooth Manager
  late BluetoothHelper bluetoothHelper;
  bool _connected = false;
  bool _scanning = false;
  bool _connecting = false;
  bool _printing = false;
  String tips = "Connect receipt printer";
  int? bluetoothState;
  BluetoothDevice? _device;
  List<BluetoothDevice> _scanResults = [];
  bool _autoReconnecting = false;

// FILTER STATE
  String filterStudent = "";
  String filterClass = "";
  String filterReceiptNumber = "";
  String filterLineContent = "";
  DateTime? filterFromDate;
  DateTime? filterToDate;
  bool get _isWindows => Platform.isWindows;
  bool get _isAndroid => Platform.isAndroid;
  bool showFilters = false;

  int _batchSize = 100;
  int _currentBatchEnd = 100;

  DeviceRole? _role;
  String? _hostIp;

  List<PaymentLog> _remoteLogs = [];
  bool _loading = false;

  List<School>? _cachedServerSchoolInfo;

  List<String> _windowsPrinters = [];
  String? _selectedWindowsPrinter;
  String? _lastUsedPrinter;
  bool _isLoadingPrinters = false;
  bool _isTestingConnection = false;
  SharedPreferences? _prefs;
  bool _isLoadingLastPrinter = false;

  bool _isMultiSelectMode = false;
  final Set<PaymentLog> _selectedReceiptsForAction = {};
  bool _isDeleting = false;
  bool _isUpdating = false;
  bool _showDeleted = false; // ✅ Toggle to show deleted receipts

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

  @override
  void initState() {
    super.initState();

    _loadSavedPrinter();
    _initData();
    if (_isWindows) {
      _loadWindowsPrinters();
      _loadPreferences();
    }
    WidgetsBinding.instance.addObserver(this);

    _logBox = Hive.box<PaymentLog>("payment_log");

    bluetoothHelper = BluetoothHelper();

    bluetoothHelper.onConnectionStateChanged = (isConnected, message) {
      setState(() {
        _connected = isConnected;
        tips = message;
      });
    };

    bluetoothHelper.initBluetooth();

    Future.delayed(const Duration(seconds: 2), () {
      bluetoothHelper.verifyConnection();
    });

    bluetoothHelper.bluetoothPrint.state.listen((state) {
      bluetoothState = state;
      setState(() {
        _connecting = state == 1;
        _printing = state == 4;
      });
    });

    bluetoothHelper.bluetoothPrint.isScanning.listen((scanning) {
      setState(() => _scanning = scanning);
    });

    bluetoothHelper.bluetoothPrint.scanResults.listen((results) {
      setState(() => _scanResults = results);
    });
  }

  Future<void> _initData() async {
    final host = await isHostDevice();

    if (host) {
      _logBox = Hive.box<PaymentLog>("payment_log");
    } else {
      await _fetchRemoteLogs();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        await _loadPreferences();
      }
    } catch (e) {
      setState(() {
        tips = 'Error loading printers: $e';
        _isLoadingPrinters = false;
      });
    }
  }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AutomatedSmsHelpers.resumeDraftSequence();
      if (_isWindows &&
          _lastUsedPrinter != null &&
          !_connected &&
          !_isTestingConnection) {
        _loadWindowsPrinters();
      }
    }
  }

  Future<bool> isHostDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _role = await getDeviceRole();

    if (_role == DeviceRole.host) {
      print(DeviceRole.host);
      return true;
    } else {
      return false;
    }
  }

  Future<void> _fetchRemoteLogs() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip') ?? "192.168.8.2";

      // ✅ Include deleted parameter for sync purposes
      final uri = Uri.parse(
          "http://$hostIp:8080/api/receipt_logs?search=$_searchQuery&include_deleted=true");

      final res = await http.get(uri);

      print("📥 Response code: ${res.statusCode}");

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);

        print("📦 Received ${data.length} logs from host");

        _remoteLogs =
            data.map<PaymentLog>((e) => paymentLogFromJson(e)).toList();
      } else {
        print("❌ Host rejected request: ${res.body}");
      }
    } catch (e) {
      print("❌ Error fetching logs: $e");
    }

    setState(() => _loading = false);
  }

  Future<void> _loadSavedPrinter() async {
    final box = await Hive.openBox('printer_prefs');
    final savedAddress = box.get('last_printer');

    if (savedAddress == null) return;

    _attemptAutoReconnect(savedAddress);
  }

  Future<void> _attemptAutoReconnect(String address) async {
    setState(() {
      tips = "Reconnecting to last printer…";
      _autoReconnecting = true;
    });

    try {
      await bluetoothHelper.bluetoothPrint.startScan(
        timeout: const Duration(seconds: 4),
      );

      final devices = await bluetoothHelper.bluetoothPrint.scanResults
          .timeout(const Duration(seconds: 5))
          .firstWhere((list) => list.isNotEmpty, orElse: () => []);

      final match = devices.firstWhere(
        (d) => d.address == address,
        orElse: () => [] as BluetoothDevice,
      );

      if (match == null) {
        setState(() {
          tips = "Previous printer not found";
          _autoReconnecting = false;
        });
        return;
      }

      await bluetoothHelper.bluetoothPrint.connect(match);

      setState(() {
        _device = match;
        _connected = true;
        tips = "Reconnected to ${match.name}";
      });
    } catch (e) {
      setState(() => tips = "Reconnection failed");
    } finally {
      _autoReconnecting = false;
    }
  }

  // ✅ Get filtered logs with deletion filter
  List<PaymentLog> get _filteredLogs {
    final hostLogs = _logBox.values.toList();
    final remoteLogs = List<PaymentLog>.from(_remoteLogs);

    List<PaymentLog> logs = hostLogs.isNotEmpty ? hostLogs : remoteLogs;

    // ✅ Filter out deleted logs if not showing deleted
    if (!_showDeleted) {
      logs = logs.where((log) => !(log.isDeleted ?? false)).toList();
    }

    // SORT (avoid null crash)
    logs.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));

    // TEXT SEARCH
    if (_searchQuery.isNotEmpty) {
      logs = logs
          .where((log) =>
              log.studentName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              log.className
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              log.receiptNumber.toString().contains(_searchQuery))
          .toList();
    }

    // STUDENT FILTER
    if (filterStudent.isNotEmpty) {
      logs = logs
          .where((log) => log.studentName
              .toLowerCase()
              .contains(filterStudent.toLowerCase()))
          .toList();
    }

    // CLASS FILTER
    if (filterClass.isNotEmpty) {
      logs = logs
          .where((log) =>
              log.className.toLowerCase().contains(filterClass.toLowerCase()))
          .toList();
    }

    // RECEIPT NUMBER
    if (filterReceiptNumber.isNotEmpty) {
      logs = logs
          .where((log) =>
              log.receiptNumber.toString().contains(filterReceiptNumber))
          .toList();
    }

    // DATE RANGE
    if (filterFromDate != null) {
      logs = logs.where((log) {
        final dt = DateTime.tryParse(log.dateTime);
        if (dt == null) return false;
        return dt.isAfter(filterFromDate!);
      }).toList();
    }

    if (filterToDate != null) {
      logs = logs.where((log) {
        final dt = DateTime.tryParse(log.dateTime);
        if (dt == null) return false;
        return dt.isBefore(filterToDate!);
      }).toList();
    }

    return logs;
  }

  // OPEN RECEIPT VIEW
  void _openReceiptViewer(PaymentLog log) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptViewerPage(log: log)),
    );
  }

  // ✅ SOFT DELETE single receipt
  void _confirmDelete(PaymentLog log) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Receipt"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Soft delete receipt #${log.receiptNumber} for ${log.studentName}?",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "This will mark it as deleted and sync to host.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeSoftDelete(log);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ✅ Execute soft delete
  Future<void> _executeSoftDelete(PaymentLog log) async {
    setState(() => _isDeleting = true);

    try {
      // ✅ Mark as soft deleted with sync flags
      log.markDeleted(
        deletedBy: 'User: ${log.studentName}',
        reason: 'Soft deleted from ReceiptHistoryPage',
      );
      log.syncStatus = false;
      log.deletedSyncStatus = false;
      log.operationType = 'delete';
      log.lastModified = DateTime.now();
      log.modifiedFields = [
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'deleteReason',
        'deletedSyncStatus',
        'syncStatus',
        'operationType',
        'lastModified'
      ];

      await log.save();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("✅ Receipt #${log.receiptNumber} soft-deleted successfully"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await _refreshData();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error deleting receipt: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  // ✅ Restore soft-deleted receipt
  Future<void> _restoreReceipt(PaymentLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Restore"),
        content: Text(
          'Restore receipt #${log.receiptNumber} for ${log.studentName}?\n\n'
          'This will mark it as active again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      log.restoreDeleted();
      log.syncStatus = false;
      log.deletedSyncStatus = false;
      log.operationType = 'update';
      log.lastModified = DateTime.now();
      log.modifiedFields = [
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'deleteReason',
        'deletedSyncStatus',
        'syncStatus',
        'operationType',
        'lastModified'
      ];

      await log.save();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("✅ Receipt #${log.receiptNumber} restored successfully"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await _refreshData();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error restoring receipt: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  /// Share selected receipts via various methods
  Future<void> _shareSelectedReceipts(List<PaymentLog> receipts) async {
    if (receipts.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Preparing receipts for sharing..."),
            ],
          ),
        ),
      );

      String combinedText = await _buildCombinedReceiptText(receipts);

      Navigator.pop(context);

      await Share.share(
        combinedText,
        subject: 'Receipts #${receipts.map((r) => r.receiptNumber).join(', ')}',
      );

      setState(() {
        _selectedReceiptsForAction.clear();
        _isMultiSelectMode = false;
        _selectedIndexes.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ ${receipts.length} receipt(s) shared successfully"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error sharing receipts: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build combined receipt text for sharing
  Future<String> _buildCombinedReceiptText(List<PaymentLog> receipts) async {
    final StringBuffer buffer = StringBuffer();
    final schoolName = await _getSchoolName();

    buffer.writeln('=' * 50);
    buffer.writeln('  $schoolName');
    buffer.writeln('  RECEIPT HISTORY');
    buffer.writeln('=' * 50);
    buffer.writeln('');
    buffer.writeln('Total Receipts: ${receipts.length}');
    buffer.writeln('Shared on: ${DateTime.now().toLocal()}');
    buffer.writeln('');
    buffer.writeln('-' * 50);

    for (int i = 0; i < receipts.length; i++) {
      final log = receipts[i];
      buffer.writeln('');
      buffer.writeln(
          '📄 RECEIPT #${log.receiptNumber} (${i + 1}/${receipts.length})');
      buffer.writeln('-' * 40);
      buffer.writeln('Student: ${log.studentName}');
      buffer.writeln('Class: ${log.className}');
      buffer.writeln('Date: ${log.dateTime}');
      buffer.writeln('');
      buffer.writeln('--- Details ---');

      for (final line in log.receiptLines) {
        final content = line['content']?.toString() ?? '';
        if (content.trim().isNotEmpty) {
          buffer.writeln(content);
        }
      }

      final totalAmount = _extractTotalAmountFromReceipt(log);
      if (totalAmount.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('Total Amount: $totalAmount');
      }

      buffer.writeln('-' * 40);
      buffer.writeln('');
    }

    buffer.writeln('=' * 50);
    buffer.writeln('  End of Receipts');
    buffer.writeln('=' * 50);

    return buffer.toString();
  }

  /// Share receipts as PDF
  Future<void> _shareReceiptsAsPDF(List<PaymentLog> receipts) async {
    if (receipts.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Generating PDF..."),
            ],
          ),
        ),
      );

      final pdfBytes = await _generateReceiptsPDF(receipts);

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/receipts_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Receipts #${receipts.map((r) => r.receiptNumber).join(', ')}',
        subject: 'Receipts PDF',
      );

      try {
        await file.delete();
      } catch (_) {}

      setState(() {
        _selectedReceiptsForAction.clear();
        _isMultiSelectMode = false;
        _selectedIndexes.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ PDF shared successfully"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error sharing PDF: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Generate PDF from receipts
  Future<Uint8List> _generateReceiptsPDF(List<PaymentLog> receipts) async {
    final pdf = pw.Document();
    final schoolName = await _getSchoolName();

    for (int i = 0; i < receipts.length; i++) {
      final log = receipts[i];

      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  schoolName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'RECEIPT #${log.receiptNumber}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Student: ${log.studentName}'),
                pw.Text('Class: ${log.className}'),
                pw.Text('Date: ${log.dateTime}'),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                ...log.receiptLines.map((line) {
                  final content = line['content']?.toString() ?? '';
                  if (content.trim().isEmpty) return pw.SizedBox();
                  return pw.Text(
                    content,
                    style: pw.TextStyle(
                      fontWeight: (line['weight'] ?? 0) == 1
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      fontSize:
                          ((line['fontZoom'] as num?)?.toDouble() ?? 1) * 12,
                    ),
                    textAlign: () {
                      switch (line['align']) {
                        case 1:
                          return pw.TextAlign.center;
                        case 2:
                          return pw.TextAlign.right;
                        default:
                          return pw.TextAlign.left;
                      }
                    }(),
                  );
                }).toList(),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text(
                  'Total Amount: ${_extractTotalAmountFromReceipt(log)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${i + 1}/${receipts.length}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ----------------------------
  // UI BUILD
  // ----------------------------

  void _showReceiptPreview(PaymentLog log) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Center(
                      child: Text(
                        "Receipt #${log.receiptNumber}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Text("${log.studentName} • ${log.className}"),
                Text("Date: ${log.dateTime}"),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: log.receiptLines.length,
                    itemBuilder: (context, index) {
                      final line = log.receiptLines[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          line['content'] ?? "",
                          style: TextStyle(
                            fontWeight: (line['weight'] ?? 0) == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize:
                                ((line['fontZoom'] as num?)?.toDouble() ?? 1) *
                                    14,
                          ),
                          textAlign: () {
                            switch (line['align']) {
                              case 1:
                                return TextAlign.center;
                              case 2:
                                return TextAlign.right;
                              default:
                                return TextAlign.left;
                            }
                          }(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Receipt History"),
        actions: [
          // ✅ Toggle to show deleted receipts
          IconButton(
            icon: Icon(
              _showDeleted ? Icons.visibility : Icons.visibility_off,
              color: _showDeleted ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDeleted = !_showDeleted;
              });
            },
            tooltip: _showDeleted ? 'Hide Deleted' : 'Show Deleted',
          ),
          IconButton(
            tooltip: 'Reprint Statistics',
            icon: const Icon(Icons.analytics),
            onPressed: _showReprintStatistics,
          ),
          if (_selectedIndexes.isNotEmpty)
            IconButton(
              tooltip: 'Print queue',
              icon: const Icon(Icons.print),
              onPressed: () =>
                  _printSelectedReceipts(_filteredLogsWithReprints),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildPrinterPanel(),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildSearchBar(),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildFilterPanel(),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: _buildReceiptList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isMultiSelectMode &&
              _selectedReceiptsForAction.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _showBulkActionDialog(_selectedReceiptsForAction.toList()),
              icon: const Icon(Icons.settings),
              label: Text("Actions (${_selectedReceiptsForAction.length})"),
              backgroundColor: Colors.blue,
            )
          : (_selectedIndexes.isEmpty
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.print),
                  label: Text("Print ${_selectedIndexes.length}"),
                  onPressed: () =>
                      _printSelectedReceipts(_filteredLogsWithReprints),
                )),
    );
  }

  // ----------------------------
  // SEARCH BAR
  // ----------------------------
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search by name, class, date or receipt number",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentBatchEnd = _batchSize;
        }),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Column(
      children: [
        TextButton.icon(
          icon: Icon(
            showFilters ? Icons.filter_alt_off : Icons.filter_alt,
          ),
          label: Text(
            showFilters ? "Hide Filters" : "Show Filters",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: () => setState(() => showFilters = !showFilters),
        ),
        if (!showFilters) SizedBox.shrink(),
        if (showFilters)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  spreadRadius: 1,
                  color: Colors.black.withOpacity(0.1),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Filters",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildFilterInput("Student Name", (v) {
                  setState(() {
                    filterStudent = v;
                    _currentBatchEnd = _batchSize;
                  });
                }),
                _buildFilterInput("Class Name", (v) {
                  setState(() {
                    filterClass = v;
                    _currentBatchEnd = _batchSize;
                  });
                }),
                _buildFilterInput("Receipt Number", (v) {
                  setState(() {
                    filterReceiptNumber = v;
                    _currentBatchEnd = _batchSize;
                  });
                }),
                _buildFilterInput("Text inside Receipt Lines", (v) {
                  setState(() {
                    filterLineContent = v;
                    _currentBatchEnd = _batchSize;
                  });
                }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        child: Text(
                          filterFromDate == null
                              ? "From Date"
                              : "From: ${filterFromDate!.toString().substring(0, 10)}",
                        ),
                        onPressed: () async {
                          final pick = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (pick != null) {
                            setState(() => filterFromDate = pick);
                            _currentBatchEnd = _batchSize;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        child: Text(
                          filterToDate == null
                              ? "To Date"
                              : "To: ${filterToDate!.toString().substring(0, 10)}",
                        ),
                        onPressed: () async {
                          final pick = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (pick != null) {
                            setState(() => filterToDate = pick);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reset Filters"),
                    onPressed: () {
                      setState(() {
                        filterStudent = "";
                        filterClass = "";
                        filterReceiptNumber = "";
                        filterLineContent = "";
                        filterFromDate = null;
                        filterToDate = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<List<PaymentLog>> findDuplicateReceipts(List<PaymentLog> logs) {
    final Map<String, List<PaymentLog>> receiptsByNumber = {};

    for (var log in logs) {
      final receiptNum = log.receiptNumber.toString();
      if (!receiptsByNumber.containsKey(receiptNum)) {
        receiptsByNumber[receiptNum] = [];
      }
      receiptsByNumber[receiptNum]!.add(log);
    }

    final duplicates =
        receiptsByNumber.values.where((list) => list.length > 1).toList();

    return duplicates;
  }

  bool _showReprintsOnly = false;
  String _reprintFilterStatus =
      "All Receipts"; // "All Receipts", "Reprints Only", "Original Only"

  List<PaymentLog> get _filteredLogsWithReprints {
    final allFiltered = _filteredLogs;

    if (_reprintFilterStatus == "All Receipts") {
      return allFiltered;
    }

    final duplicatesMap = <String, List<PaymentLog>>{};
    for (var log in allFiltered) {
      final receiptNum = log.receiptNumber.toString();
      duplicatesMap.putIfAbsent(receiptNum, () => []).add(log);
    }

    final duplicateReceiptNumbers = duplicatesMap.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => entry.key)
        .toSet();

    if (_reprintFilterStatus == "Reprints Only") {
      final result = <PaymentLog>[];
      for (var receiptNum in duplicateReceiptNumbers) {
        final receipts = duplicatesMap[receiptNum]!;
        receipts.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        result.addAll(receipts.sublist(1));
      }
      return result;
    } else if (_reprintFilterStatus == "Original Only") {
      final result = <PaymentLog>[];
      for (var receiptNum in duplicateReceiptNumbers) {
        final receipts = duplicatesMap[receiptNum]!;
        receipts.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        result.add(receipts.first);
      }
      return result;
    }

    return allFiltered;
  }

  void _showBulkActionDialog(List<PaymentLog> selectedReceipts) {
    if (selectedReceipts.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Actions (${selectedReceipts.length} selected)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text("Print Receipts"),
              onTap: () {
                Navigator.pop(_);
                _printSelectedReceipts(selectedReceipts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.purple),
              title: const Text("Share as Text"),
              subtitle: const Text("Share via email, messaging apps, etc."),
              onTap: () {
                Navigator.pop(_);
                _shareSelectedReceipts(selectedReceipts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("Share as PDF"),
              subtitle: const Text("Generate and share PDF file"),
              onTap: () {
                Navigator.pop(_);
                _shareReceiptsAsPDF(selectedReceipts);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.green),
              title: const Text("Mark as Reprint"),
              onTap: () {
                Navigator.pop(_);
                _markAsReprints(selectedReceipts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Selected"),
              onTap: () {
                Navigator.pop(_);
                _confirmBulkDelete(selectedReceipts);
              },
            ),
            if (selectedReceipts.any((log) =>
                findDuplicateReceipts(_filteredLogs).any((group) => group.any(
                    (g) =>
                        g.receiptNumber == log.receiptNumber &&
                        group.indexOf(g) > 0))))
              ListTile(
                leading: const Icon(Icons.clean_hands, color: Colors.orange),
                title: const Text("Keep Only Original"),
                subtitle: const Text("Delete all reprints, keep first receipt"),
                onTap: () {
                  Navigator.pop(_);
                  _keepOnlyOriginals(selectedReceipts);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  /// Edit multiple receipts
  Future<void> _editMultipleReceipts(List<PaymentLog> receipts) async {
    if (receipts.isEmpty) return;

    setState(() => _isUpdating = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Updating ${receipts.length} receipts..."),
            ],
          ),
        ),
      );

      int successCount = 0;
      int failCount = 0;

      for (var receipt in receipts) {
        try {
          // ✅ Preserve deletion status when editing
          final updatedReceipt = PaymentLog(
            receiptNumber: receipt.receiptNumber,
            studentName: receipt.studentName,
            className: receipt.className,
            dateTime: DateTime.now().toIso8601String(),
            receiptLines: List<Map<String, dynamic>>.from(receipt.receiptLines),
            parentName: receipt.parentName,
            parentPhone: receipt.parentPhone,
            isReprint: true,
            originalReceiptNumber: (receipt.originalReceiptNumber?.toString() ??
                receipt.receiptNumber.toString()),
            // ✅ Preserve deletion status
            isDeleted: receipt.isDeleted ?? false,
            deletedAt: receipt.deletedAt,
            deletedBy: receipt.deletedBy,
            deleteReason: receipt.deleteReason,
            deletedSyncStatus: receipt.deletedSyncStatus ?? false,
          );

          await receipt.delete();
          await _logBox.add(updatedReceipt);
          successCount++;
        } catch (e) {
          print("Error updating receipt ${receipt.receiptNumber}: $e");
          failCount++;
        }
      }

      Navigator.pop(context);

      _showResultDialog(
        "Edit Complete",
        "✅ Successfully updated: $successCount\n❌ Failed: $failCount",
        Icons.edit,
      );

      setState(() {
        _selectedReceiptsForAction.clear();
        _isMultiSelectMode = false;
        _selectedIndexes.clear();
      });

      await _refreshData();
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog("Error updating receipts: $e");
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  /// Mark receipts as reprints
  Future<void> _markAsReprints(List<PaymentLog> receipts) async {
    if (receipts.isEmpty) return;

    setState(() => _isUpdating = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Marking as reprints..."),
            ],
          ),
        ),
      );

      int successCount = 0;
      int failCount = 0;

      for (var receipt in receipts) {
        try {
          // ✅ Preserve deletion status when marking as reprint
          final updatedReceipt = PaymentLog(
            receiptNumber: receipt.receiptNumber,
            studentName: receipt.studentName,
            className: receipt.className,
            dateTime: receipt.dateTime,
            receiptLines: List<Map<String, dynamic>>.from(receipt.receiptLines),
            parentName: receipt.parentName,
            parentPhone: receipt.parentPhone,
            isReprint: true,
            originalReceiptNumber: (receipt.originalReceiptNumber?.toString() ??
                receipt.receiptNumber.toString()),
            reprintCount: (receipt.reprintCount ?? 0) + 1,
            // ✅ Preserve deletion status
            isDeleted: receipt.isDeleted ?? false,
            deletedAt: receipt.deletedAt,
            deletedBy: receipt.deletedBy,
            deleteReason: receipt.deleteReason,
            deletedSyncStatus: receipt.deletedSyncStatus ?? false,
          );

          await receipt.delete();
          await _logBox.add(updatedReceipt);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      Navigator.pop(context);

      _showResultDialog(
        "Mark Complete",
        "✅ Marked as reprint: $successCount\n❌ Failed: $failCount",
        Icons.copy,
      );

      setState(() {
        _selectedReceiptsForAction.clear();
        _isMultiSelectMode = false;
        _selectedIndexes.clear();
      });

      await _refreshData();
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog("Error marking receipts: $e");
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ✅ Bulk delete with soft delete
  Future<void> _confirmBulkDelete(List<PaymentLog> receipts) async {
    if (receipts.isEmpty) return;

    final bool isSingle = receipts.length == 1;
    final String title = isSingle ? "Delete Receipt" : "Delete Receipts";
    final String content = isSingle
        ? "Soft delete receipt #${receipts.first.receiptNumber}?"
        : "Soft delete ${receipts.length} receipts?";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeBulkSoftDelete(receipts);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ✅ Execute bulk soft delete
  Future<void> _executeBulkSoftDelete(List<PaymentLog> receipts) async {
    setState(() => _isDeleting = true);

    int successCount = 0;
    int failCount = 0;

    for (var receipt in receipts) {
      try {
        receipt.markDeleted(
          deletedBy: 'User: ${receipt.studentName}',
          reason: 'Bulk soft deleted from ReceiptHistoryPage',
        );
        receipt.syncStatus = false;
        receipt.deletedSyncStatus = false;
        receipt.operationType = 'delete';
        receipt.lastModified = DateTime.now();
        receipt.modifiedFields = [
          'isDeleted',
          'deletedAt',
          'deletedBy',
          'deleteReason',
          'deletedSyncStatus',
          'syncStatus',
          'operationType',
          'lastModified'
        ];
        await receipt.save();
        successCount++;
      } catch (e) {
        print("Error deleting receipt ${receipt.receiptNumber}: $e");
        failCount++;
      }
    }

    setState(() {
      _selectedReceiptsForAction.clear();
      _isMultiSelectMode = false;
      _selectedIndexes.clear();
      _isDeleting = false;
    });

    await _refreshData();

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Successfully soft-deleted $successCount receipt(s)"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Deleted: $successCount, Failed: $failCount"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Keep only original receipts, delete all reprints
  Future<void> _keepOnlyOriginals(List<PaymentLog> receipts) async {
    final allReceipts = _filteredLogs;
    final duplicates = findDuplicateReceipts(allReceipts);

    final reprintsToDelete = <PaymentLog>[];

    for (var receipt in receipts) {
      for (var group in duplicates) {
        if (group.any((g) => g.receiptNumber == receipt.receiptNumber)) {
          group.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          reprintsToDelete.addAll(group.sublist(1));
        }
      }
    }

    if (reprintsToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No reprint copies found to delete"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Reprints"),
        content: Text(
            "Delete ${reprintsToDelete.length} reprint copy(s)? Originals will be kept."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeBulkSoftDelete(reprintsToDelete);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text("Delete Reprints"),
          ),
        ],
      ),
    );
  }

  /// Helper method to refresh data
  Future<void> _refreshData() async {
    final host = await isHostDevice();
    if (!host) {
      await _fetchRemoteLogs();
    }
    setState(() {});
  }

  /// Show result dialog
  void _showResultDialog(String title, String message, IconData icon) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Show info dialog
  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildReprintFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.content_copy, size: 20, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                "Reprint Filter",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text("All Receipts"),
                selected: _reprintFilterStatus == "All Receipts",
                onSelected: (selected) {
                  setState(() {
                    _reprintFilterStatus = "All Receipts";
                    _currentBatchEnd = _batchSize;
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.blue.shade100,
              ),
              FilterChip(
                label: const Text("⚠️ Reprints Only"),
                selected: _reprintFilterStatus == "Reprints Only",
                onSelected: (selected) {
                  setState(() {
                    _reprintFilterStatus = "Reprints Only";
                    _currentBatchEnd = _batchSize;
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.orange.shade100,
                avatar: const Icon(Icons.warning_amber, size: 16),
              ),
              FilterChip(
                label: const Text("📄 Originals with Reprints"),
                selected: _reprintFilterStatus == "Original Only",
                onSelected: (selected) {
                  setState(() {
                    _reprintFilterStatus = "Original Only";
                    _currentBatchEnd = _batchSize;
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.green.shade100,
              ),
            ],
          ),
          if (_reprintFilterStatus != "All Receipts")
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _reprintFilterStatus == "Reprints Only"
                    ? "Showing only duplicate receipts (reprints)"
                    : "Showing only original receipts that have been reprinted",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showReprintStatistics() {
    final allReceipts = _filteredLogs;
    final duplicates = findDuplicateReceipts(allReceipts);

    int totalReprints = 0;
    for (var group in duplicates) {
      totalReprints += group.length - 1;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reprint Statistics"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📊 Total Receipts: ${allReceipts.length}"),
            const SizedBox(height: 8),
            Text("🔄 Receipts with Reprints: ${duplicates.length}"),
            const SizedBox(height: 8),
            Text("📄 Total Reprint Copies: $totalReprints"),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              "Receipts with multiple prints:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              width: 300,
              child: ListView.builder(
                itemCount: duplicates.length,
                itemBuilder: (context, index) {
                  final group = duplicates[index];
                  final receiptNum = group.first.receiptNumber;
                  final count = group.length;
                  final dates =
                      group.map((g) => g.dateTime.substring(0, 10)).toList();

                  return Card(
                    child: ListTile(
                      title: Text("Receipt #$receiptNum"),
                      subtitle: Text(
                        "Printed $count times on: ${dates.join(', ')}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.warning, color: Colors.orange),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  /// Reusable filter input box with styling
  Widget _buildFilterInput(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }

  // ----------------------------
  // RECEIPT LIST
  // ----------------------------
  Widget _buildReceiptList() {
    return FutureBuilder<bool>(
      future: isHostDevice(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final host = snapshot.data!;

        List<PaymentLog> logs =
            host ? _logBox.values.toList() : List.from(_remoteLogs);

        // ✅ Filter out deleted logs if not showing deleted
        if (!_showDeleted) {
          logs = logs.where((log) => !(log.isDeleted ?? false)).toList();
        }

        logs.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));

        final filtered = logs.where((r) {
          final s = _searchQuery.toLowerCase();

          bool matchesSearch = r.studentName.toLowerCase().contains(s) ||
              r.className.toLowerCase().contains(s) ||
              r.receiptNumber.toString().contains(s) ||
              r.dateTime.toLowerCase().contains(s);

          bool matchesStudent = filterStudent.isEmpty ||
              r.studentName.toLowerCase().contains(filterStudent.toLowerCase());

          bool matchesClass = filterClass.isEmpty ||
              r.className.toLowerCase().contains(filterClass.toLowerCase());

          bool matchesReceipt = filterReceiptNumber.isEmpty ||
              r.receiptNumber.toString().contains(filterReceiptNumber);

          bool matchesLines = filterLineContent.isEmpty ||
              r.receiptLines.any((line) => line
                  .toString()
                  .toLowerCase()
                  .contains(filterLineContent.toLowerCase()));

          bool matchesDate = true;
          if (filterFromDate != null || filterToDate != null) {
            final rDate = DateTime.tryParse(r.dateTime);
            if (rDate != null) {
              if (filterFromDate != null && rDate.isBefore(filterFromDate!)) {
                matchesDate = false;
              }
              if (filterToDate != null && rDate.isAfter(filterToDate!)) {
                matchesDate = false;
              }
            }
          }

          return matchesSearch &&
              matchesStudent &&
              matchesClass &&
              matchesReceipt &&
              matchesLines &&
              matchesDate;
        }).toList();

        List<PaymentLog> finalFiltered;
        if (_reprintFilterStatus == "All Receipts") {
          finalFiltered = filtered;
        } else {
          final duplicatesMap = <String, List<PaymentLog>>{};
          for (var log in filtered) {
            final receiptNum = log.receiptNumber.toString();
            duplicatesMap.putIfAbsent(receiptNum, () => []).add(log);
          }

          final duplicateReceiptNumbers = duplicatesMap.entries
              .where((entry) => entry.value.length > 1)
              .map((entry) => entry.key)
              .toSet();

          if (_reprintFilterStatus == "Reprints Only") {
            final result = <PaymentLog>[];
            for (var receiptNum in duplicateReceiptNumbers) {
              final receipts = duplicatesMap[receiptNum]!;
              receipts.sort((a, b) => a.dateTime.compareTo(b.dateTime));
              result.addAll(receipts.sublist(1));
            }
            finalFiltered = result;
          } else {
            final result = <PaymentLog>[];
            for (var receiptNum in duplicateReceiptNumbers) {
              final receipts = duplicatesMap[receiptNum]!;
              receipts.sort((a, b) => a.dateTime.compareTo(b.dateTime));
              result.add(receipts.first);
            }
            finalFiltered = result;
          }
        }

        if (finalFiltered.isEmpty) {
          return const Center(child: Text("No receipts found"));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-select controls
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isMultiSelectMode
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMultiSelectMode
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!_isMultiSelectMode)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isMultiSelectMode = true;
                                _selectedReceiptsForAction.clear();
                              });
                            },
                            icon: const Icon(Icons.checklist, size: 18),
                            label: const Text("Select Multiple for Actions"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (_isMultiSelectMode) ...[
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isMultiSelectMode = false;
                                      _selectedReceiptsForAction.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text("Cancel"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_selectedReceiptsForAction.isNotEmpty)
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showBulkActionDialog(
                                        _selectedReceiptsForAction.toList()),
                                    icon: const Icon(Icons.settings, size: 18),
                                    label: Text(
                                        "Actions (${_selectedReceiptsForAction.length})"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status bar with delete filter info
                if (_showDeleted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing ${finalFiltered.where((l) => l.isDeleted == true).length} deleted receipts',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Reprint Filter
                _buildReprintFilter(),

                // Select All Row
                Row(
                  children: [
                    Checkbox(
                      value: finalFiltered.isNotEmpty &&
                          _selectedIndexes.length == finalFiltered.length,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedIndexes
                              ..clear()
                              ..addAll(List.generate(
                                  finalFiltered.length, (i) => i));
                          } else {
                            _selectedIndexes.clear();
                          }
                        });
                      },
                    ),
                    const Text(
                      "Select All for Printing",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_reprintFilterStatus != "All Receipts")
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _reprintFilterStatus == "Reprints Only"
                              ? "⚠️ Showing ${finalFiltered.length} reprints"
                              : "📄 Showing ${finalFiltered.length} originals with reprints",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  "Showing ${_currentBatchEnd.clamp(0, finalFiltered.length)} of ${finalFiltered.length} receipts",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

                if (_currentBatchEnd < finalFiltered.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _currentBatchEnd += _batchSize);
                          },
                          child: const Text("Load Next 100"),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(
                                () => _currentBatchEnd = finalFiltered.length);
                          },
                          child: const Text("Load All"),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _currentBatchEnd.clamp(0, finalFiltered.length),
                    itemBuilder: (context, index) {
                      final log = finalFiltered[index];
                      final selected = _selectedIndexes.contains(index);
                      final hasDuplicates = findDuplicateReceipts(finalFiltered)
                          .any((group) => group.any(
                              (g) => g.receiptNumber == log.receiptNumber));
                      final isDeleted = log.isDeleted ?? false;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        color: isDeleted ? Colors.grey.shade100 : null,
                        child: ListTile(
                          leading: _isMultiSelectMode
                              ? Checkbox(
                                  value:
                                      _selectedReceiptsForAction.contains(log),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedReceiptsForAction.add(log);
                                      } else {
                                        _selectedReceiptsForAction.remove(log);
                                      }
                                    });
                                  },
                                )
                              : Checkbox(
                                  value: selected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedIndexes.add(index);
                                      } else {
                                        _selectedIndexes.remove(index);
                                      }
                                    });
                                  },
                                ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "${log.studentName} • #${log.receiptNumber}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            decoration: isDeleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color:
                                                isDeleted ? Colors.grey : null,
                                          ),
                                        ),
                                        if (isDeleted) ...[
                                          const SizedBox(width: 8),
                                          const Chip(
                                            label: Text('DELETED'),
                                            backgroundColor: Colors.red,
                                            labelStyle: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    _buildTotalPaidAmount(log),
                                  ],
                                ),
                              ),
                              if (hasDuplicates)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "REPRINT",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${log.className} • ${log.dateTime}",
                                style: TextStyle(
                                  decoration: isDeleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDeleted ? Colors.grey : null,
                                ),
                              ),
                              if (isDeleted && log.deletedAt != null)
                                Text(
                                  'Deleted: ${log.deletedAt!.toLocal()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            _showReceiptPreview(log);
                          },
                          onLongPress: () {
                            _confirmDelete(log);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDeleted)
                                IconButton(
                                  icon: const Icon(Icons.restore,
                                      color: Colors.green),
                                  onPressed: () => _restoreReceipt(log),
                                  tooltip: 'Restore Receipt',
                                ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _editMultipleReceipts([log]);
                                      break;
                                    case 'reprint':
                                      _markAsReprints([log]);
                                      break;
                                    case 'delete':
                                      if (isDeleted) {
                                        _showInfoDialog('Already Deleted',
                                            'This receipt is already soft-deleted.');
                                      } else {
                                        _confirmBulkDelete([log]);
                                      }
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit,
                                            size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit Receipt'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'reprint',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy,
                                            size: 18, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Mark as Reprint'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDeleted ? Icons.info : Icons.delete,
                                          size: 18,
                                          color: isDeleted
                                              ? Colors.grey
                                              : Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(isDeleted
                                            ? 'Already Deleted'
                                            : 'Delete Receipt'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Helper method to extract total paid amount from receipt lines
  Widget _buildTotalPaidAmount(PaymentLog log) {
    String totalAmount = _extractTotalAmountFromReceipt(log);

    if (totalAmount.isEmpty) {
      return const SizedBox.shrink();
    }

    final isReprint = (log.reprintCount ?? 0) > 0 || (log.isReprint ?? false);
    final isDeleted = log.isDeleted ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDeleted
            ? Colors.grey.shade200
            : isReprint
                ? Colors.orange.shade50
                : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDeleted
              ? Colors.grey.shade400
              : isReprint
                  ? Colors.orange.shade200
                  : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_money,
            size: 14,
            color: isDeleted
                ? Colors.grey
                : isReprint
                    ? Colors.orange
                    : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            totalAmount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDeleted
                  ? Colors.grey
                  : isReprint
                      ? Colors.orange.shade800
                      : Colors.green.shade800,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
            ),
          ),
          if (isReprint) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.copy,
              size: 12,
              color: Colors.orange,
            ),
          ],
          if (isDeleted) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.delete_outline,
              size: 12,
              color: Colors.grey,
            ),
          ],
        ],
      ),
    );
  }

  /// Extract the total paid amount from receipt lines
  String _extractTotalAmountFromReceipt(PaymentLog log) {
    try {
      if (log.receiptLines.isEmpty) return '';

      for (var line in log.receiptLines) {
        final content = line['content']?.toString() ?? '';

        if (content.toUpperCase().contains('TOTAL PAID')) {
          final regExp = RegExp(r'\$?\s*([\d,]+\.?\d*)');
          final match = regExp.firstMatch(content);

          if (match != null && match.groupCount >= 1) {
            String amount = match.group(1) ?? '';
            if (amount.isNotEmpty) {
              if (!amount.contains('.')) {
                amount = '$amount.00';
              }
              return '\$$amount';
            }
          }
        }
      }

      return '';
    } catch (e) {
      debugPrint('Error extracting total amount: $e');
      return '';
    }
  }

  // ----------------------------
  // PRINTER PANEL UI
  // ----------------------------
  Widget _buildPrinterPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        initiallyExpanded: !_connected,
        leading: Icon(
          _connected ? Icons.print_rounded : Icons.print_disabled,
          color: _connected ? Colors.green : Colors.red,
        ),
        title: Text(
          _connected
              ? "Printer Connected"
              : (_autoReconnecting
                  ? "Reconnecting…"
                  : "Printer: Not Connected"),
          style: TextStyle(
            color: _connected ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(tips),
        children: [
          if (_scanning) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          if (Platform.isAndroid) ...[
            // Android Bluetooth UI
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(_scanning ? "Scanning…" : "Scan Printers"),
              onPressed: () {
                bluetoothHelper.bluetoothPrint.startScan(
                  timeout: const Duration(seconds: 4),
                );
                setState(() => tips = "Scanning for printers…");
              },
            ),
            const Divider(),
            StreamBuilder<List<BluetoothDevice>>(
              stream: bluetoothHelper.bluetoothPrint.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];

                if (devices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text("No printers found"),
                  );
                }

                return Column(
                  children: devices.map((device) {
                    final isSelected = _device?.address == device.address;
                    return ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(device.name ?? "Unknown"),
                      subtitle: Text(device.address ?? ""),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() {
                          _device = device;
                          tips = "Device selected: ${device.name}";
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ] else if (Platform.isWindows) ...[
            // Windows Printer UI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
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
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedWindowsPrinter,
                                hint: const Text('Select Windows Printer'),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('-- Select a printer --'),
                                  ),
                                  ..._windowsPrinters.map((printer) {
                                    bool isLastUsed =
                                        printer == _lastUsedPrinter;
                                    return DropdownMenuItem(
                                      value: printer,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              printer,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isLastUsed && !_connected)
                                            const Icon(
                                              Icons.history,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                          if (isLastUsed && _connected)
                                            const Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: _isTestingConnection
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedWindowsPrinter = value;
                                          _connected = false;
                                        });
                                      },
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed:
                            _isLoadingPrinters ? null : _loadWindowsPrinters,
                        tooltip: 'Refresh printers',
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
                                  _selectedWindowsPrinter == null
                              ? null
                              : _connectWindowsPrinter,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.link),
                          label: Text(_isTestingConnection
                              ? 'Connecting...'
                              : 'Connect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: !_connected ? null : _disconnectPrinter,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_lastUsedPrinter != null &&
                      !_connected &&
                      !_isTestingConnection)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: _autoConnectLastPrinter,
                        icon: const Icon(Icons.history, size: 16),
                        label: Text('Reconnect to: $_lastUsedPrinter'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_selectedWindowsPrinter != null && !_connected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected: $_selectedWindowsPrinter',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _connected
                    ? null
                    : () async {
                        if (Platform.isAndroid) {
                          if (_device == null) {
                            setState(
                                () => tips = "Please select a device first");
                            return;
                          }

                          setState(() {
                            _connecting = true;
                            tips = "Connecting…";
                          });

                          try {
                            await bluetoothHelper.bluetoothPrint
                                .connect(_device!);
                            final box = await Hive.openBox('printer_prefs');
                            box.put('last_printer', _device!.address);
                            setState(() {
                              _connected = true;
                              tips = "Connected to ${_device!.name}";
                            });
                          } catch (e) {
                            setState(() => tips = "Failed to connect: $e");
                          } finally {
                            setState(() => _connecting = false);
                          }
                        } else if (Platform.isWindows) {
                          // Windows connection handled by _connectWindowsPrinter
                        }
                      },
                child: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Connect"),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _connected
                    ? () async {
                        setState(() {
                          tips = "Disconnecting…";
                          _connecting = true;
                        });

                        try {
                          if (Platform.isAndroid) {
                            await bluetoothHelper.bluetoothPrint.disconnect();
                          } else if (Platform.isWindows) {
                            await _disconnectPrinter();
                          }
                          setState(() {
                            _connected = false;
                            tips = "Disconnected";
                          });
                        } catch (e) {
                          setState(() => tips = "Failed to disconnect: $e");
                        } finally {
                          setState(() => _connecting = false);
                        }
                      }
                    : null,
                child: const Text("Disconnect"),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

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

  void _showDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Notice"),
        content: Text(msg),
        actions: [
          IconButton(
            tooltip: 'Reprint Statistics',
            icon: const Icon(Icons.analytics),
            onPressed: _showReprintStatistics,
          ),
          if (_selectedIndexes.isNotEmpty)
            IconButton(
              tooltip: 'Print queue',
              icon: const Icon(Icons.print),
              onPressed: () =>
                  _printSelectedReceipts(_filteredLogsWithReprints),
            ),
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  // ----------------------------
// PRINT QUEUE (Host + Client)
// ----------------------------
  Future<void> _printSelectedReceipts(List<PaymentLog> filteredList) async {
    final host = await isHostDevice();

    List<PaymentLog> sourceLogs =
        host ? _logBox.values.toList() : List.from(_remoteLogs);

    sourceLogs.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));

    if (_selectedIndexes.isEmpty) {
      return;
    }

    if (_selectedIndexes.length > filteredList.length) {
      setState(() => _selectedIndexes.clear());
      return;
    }

    final List<PaymentLog> toPrint =
        _selectedIndexes.map((i) => filteredList[i]).toList();

    if (toPrint.isEmpty) {
      return;
    }

    if (Platform.isAndroid && !_connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please connect a Bluetooth printer first.")),
      );
      return;
    }

    if (Platform.isWindows &&
        (_selectedWindowsPrinter == null || !_connected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please select and connect a Windows printer first.")),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Printing ${toPrint.length} receipts…")),
    );

    try {
      if (Platform.isAndroid) {
        await AutomatedPrintHelper.printLogsInSequence(
          toPrint,
          bluetoothHelper.bluetoothPrint,
          context,
        );
      } else if (Platform.isWindows) {
        await _printLogsToWindowsPrinter(toPrint);
      }
      await AutomatedSmsHelpers.sendLogsInSequence(
        toPrint,
        sendParent: true,
        sendAdmins: true,
        showDialog: _showDialog,
      );
    } catch (e, st) {
      print("❌ ERROR during printing or SMS: $e");
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() {
      _selectedIndexes.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Finished printing queue.")),
    );
  }

  /// Print logs to Windows printer
  Future<void> _printLogsToWindowsPrinter(List<PaymentLog> logs) async {
    for (final log in logs) {
      try {
        final lines = _jsonToReceiptLines(log.receiptLines);

        lines.insert(
            0,
            LineText(
              type: LineText.TYPE_TEXT,
              content: "*** DUPLICATE COPY ***",
              align: LineText.ALIGN_CENTER,
              linefeed: 1,
              weight: 1,
            ));

        await WindowsPrinterHelper.printLineTextToWindowsPrinter(
          _selectedWindowsPrinter!,
          lines,
        );
        debugPrint("✔ Printed receipt ${log.receiptNumber}");

        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint("❌ Failed to print ${log.receiptNumber}: $e");
      }
    }
  }

  /// Convert JSON receipt lines to LineText objects
  List<LineText> _jsonToReceiptLines(List<Map<String, dynamic>> json) {
    int _mapPrinterAlign(dynamic a) {
      switch (a) {
        case 1:
          return LineText.ALIGN_CENTER;
        case 2:
          return LineText.ALIGN_RIGHT;
        default:
          return LineText.ALIGN_LEFT;
      }
    }

    return json.map((line) {
      return LineText(
        type: LineText.TYPE_TEXT,
        content: line['content']?.toString() ?? '',
        align: _mapPrinterAlign(line['align']),
        weight: (line['weight'] ?? 0) == 1 ? 1 : 0,
        fontZoom: line['fontZoom'] ?? 1,
        linefeed: line['linefeed'] ?? 1,
      );
    }).toList();
  }
}

// ===================================================================
// AUTOMATED PRINT HELPER
// ===================================================================
class AutomatedPrintHelper {
  String buildSmsFromLog(PaymentLog log) {
    final buffer = StringBuffer();

    for (final line in log.receiptLines) {
      final content = line['content']?.toString() ?? "";
      if (content.trim().isNotEmpty) buffer.writeln(content);
    }

    return buffer.toString().trim();
  }

  static List<LineText> _jsonToReceiptLines(List<Map<String, dynamic>> json) {
    int _mapPrinterAlign(dynamic a) {
      switch (a) {
        case 1:
          return LineText.ALIGN_CENTER;
        case 2:
          return LineText.ALIGN_RIGHT;
        default:
          return LineText.ALIGN_LEFT;
      }
    }

    return json.map((line) {
      return LineText(
        type: LineText.TYPE_TEXT,
        content: line['content']?.toString() ?? '',
        align: _mapPrinterAlign(line['align']),
        weight: (line['weight'] ?? 0) == 1 ? 1 : 0,
        fontZoom: line['fontZoom'] ?? 1,
        linefeed: line['linefeed'] ?? 1,
      );
    }).toList();
  }

  static Future<void> printLogsInSequence(
      List<PaymentLog> logs, BluetoothPrint bluetooth,
      [BuildContext? context]) async {
    for (final log in logs) {
      try {
        final lines = _jsonToReceiptLines(log.receiptLines);

        lines.insert(
            0,
            LineText(
                type: LineText.TYPE_TEXT,
                content: "*** DUPLICATE COPY ***",
                align: LineText.ALIGN_CENTER,
                linefeed: 1,
                weight: 1));

        await bluetooth.printReceipt({}, lines);
        debugPrint("✔ Printed receipt ${log.receiptNumber}");

        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint("❌ Failed to print ${log.receiptNumber}: $e");
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to print ${log.receiptNumber}: $e")),
          );
        }
      }
    }
  }
}

Future<String> _getSchoolName() async {
  List<School>? _cachedServerSchoolInfo;

  try {
    final role = await getDeviceRole();

    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    if (role == DeviceRole.host) {
      final box = await Hive.openBox<School>('school');
      if (box.isNotEmpty) {
        return box.values.first.schoolName ?? "SCHOOL";
      }
      return "SCHOOL";
    }

    if (hostIp.isEmpty) {
      debugPrint("❌ Host IP not set.");
      return "SCHOOL";
    }

    if (_cachedServerSchoolInfo != null && _cachedServerSchoolInfo.isNotEmpty) {
      return _cachedServerSchoolInfo.first.schoolName ?? "SCHOOL";
    }

    final response = await HttpClient()
        .getUrl(Uri.parse('http://$hostIp:8080/api/school'))
        .then((req) => req.close());

    if (response.statusCode == 200) {
      final schoolsJsonString = await response.transform(utf8.decoder).join();

      final schoolsList = jsonDecode(schoolsJsonString) as List;

      _cachedServerSchoolInfo = schoolsList
          .map((json) => schoolFromJson(Map<String, dynamic>.from(json)))
          .toList();

      if (_cachedServerSchoolInfo!.isNotEmpty) {
        return _cachedServerSchoolInfo!.first.schoolName ?? "SCHOOL";
      }
    } else {
      debugPrint("❌ Host returned status ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("⚠️ Error getting school name: $e");
  }

  return "SCHOOL";
}

class AutomatedSmsHelpers {
  static Future<List<Map<String, String>>> draftParentMessages(
      List<PaymentLog> logs) async {
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    List<Student> allStudents = [];
    List<Student>? _cachedServerStudentInfo;

    if (role == DeviceRole.host) {
      final box = await Hive.openBox<Student>("students");
      allStudents = box.values.toList();
    } else {
      allStudents = [];
    }

    final List<Map<String, String>> drafts = [];

    for (final log in logs) {
      String phone = "";
      String greeting = "";
      if (role == DeviceRole.host) {
        final student = _deepMatchStudentHostClient(log, allStudents);

        phone = student?.phoneNumber?.trim() ?? "";
        if (student == null) {
          continue;
        }

        phone = student.phoneNumber?.trim() ?? "";
        if (phone.isEmpty) {
          continue;
        }
        greeting = (student?.paymentStatus?.isNotEmpty ?? false)
            ? "Dear ${student!.paymentStatus!.toUpperCase()},\n\n"
            : "DUPLICATE COPY,\n";
      } else {
        phone = (log.parentPhone ?? "").trim();
        if (phone.isEmpty) {
          continue;
        }
        if (log.parentName != null && log.parentName!.trim().isNotEmpty) {
          greeting = (log.parentName) != null
              ? "Dear ${log.parentName?.toUpperCase()},\n\n"
              : "DUPLICATE COPY,\n";
        } else {
          greeting = "Dear Parent,\n\n";
        }
      }

      final schoolName = await _getSchoolName();

      final message = "$greeting${await buildSmsFromLogAdvanced(
        log,
        forcedDuplicate: false,
        getSchoolName: () async => schoolName,
      )}";

      drafts.add({"phone": phone, "message": message});
    }

    return drafts;
  }

  static int _currentDraftIndex = 0;
  static List<Map<String, String>> _draftQueue = [];
  static Function(String)? _dialogCallback;

  static void resumeDraftSequence() {
    _currentDraftIndex++;

    if (_currentDraftIndex < _draftQueue.length) {
      debugPrint("🔄 User returned → opening next SMS draft");
      _openSingleDraft();
    } else {
      debugPrint("🎉 All parent drafts completed!");
    }
  }

  static Future<void> openSmsDrafts(
    List<Map<String, String>> drafts,
    Function(String) showDialog,
  ) async {
    _draftQueue = drafts;
    _currentDraftIndex = 0;
    _dialogCallback = showDialog;

    if (_draftQueue.isEmpty) return;

    debugPrint("📨 Starting SMS draft sequence for ${drafts.length} parents");

    _openSingleDraft();
  }

  static Future<void> _openSingleDraft() async {
    if (_currentDraftIndex >= _draftQueue.length) {
      debugPrint("🎉 All drafts opened successfully.");
      return;
    }

    final draft = _draftQueue[_currentDraftIndex];
    final encoded = Uri.encodeComponent(draft["message"]!);
    final uri = Uri.parse("sms:${draft['phone']}?body=$encoded");

    debugPrint(
        "📬 Opening SMS draft ${_currentDraftIndex + 1} / ${_draftQueue.length}");

    if (await launcher.canLaunchUrl(uri)) {
      await launcher.launchUrl(uri);
    } else {
      _dialogCallback?.call("Could not open SMS app for ${draft['phone']}");
      _currentDraftIndex++;
      _openSingleDraft();
    }
  }

  static Future<bool> _sendSms(String phone, String message) async {
    if (!Platform.isAndroid) return false;

    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
      if (!status.isGranted) {
        debugPrint("❌ SMS permission denied");
        return false;
      }
    }

    try {
      const int chunkSize = 153;
      bool allSent = true;

      for (int i = 0; i < message.length; i += chunkSize) {
        final end =
            (i + chunkSize < message.length) ? i + chunkSize : message.length;
        final part = message.substring(i, end);

        SmsStatus? result = await BackgroundSms.sendMessage(
          phoneNumber: phone,
          message: part,
          simSlot: 0,
        );

        if (result != SmsStatus.sent) {
          result = await BackgroundSms.sendMessage(
            phoneNumber: phone,
            message: part,
            simSlot: 1,
          );
        }

        if (result != SmsStatus.sent) {
          debugPrint("❌ Failed to send SMS chunk to $phone");
          allSent = false;
        } else {
          debugPrint("📨 SMS chunk sent to $phone");
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      return allSent;
    } catch (e) {
      debugPrint("❌ Exception while sending SMS: $e");
      return false;
    }
  }

  static Future<String> buildSmsFromLogAdvanced(
    PaymentLog log, {
    required bool forcedDuplicate,
    required Future<String> Function() getSchoolName,
  }) async {
    final schoolName = await getSchoolName();
    final buf = StringBuffer();

    buf.writeln(schoolName);
    buf.writeln('');

    if (forcedDuplicate) {
      buf.writeln('DUPLICATE MESSAGE.');
      buf.writeln('');
    }

    buf.writeln('DUPLICATE COPY,');
    buf.writeln('');
    buf.writeln('${log.studentName} has paid:');

    try {
      for (final line in log.receiptLines) {
        final content = (line['content'] ?? '').toString();
        final trimmed = content.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('---') || trimmed.startsWith('***')) continue;

        final lower = trimmed.toLowerCase();

        final matches = lower.contains('paid') ||
            lower.contains('total paid') ||
            RegExp(r'\$\s*\d').hasMatch(trimmed) ||
            lower.contains('term') ||
            lower.contains('payments for') ||
            lower.contains('school fees') ||
            lower.contains('term arrears') ||
            lower.contains('total arrears');

        if (matches) buf.writeln(trimmed);
      }
    } catch (e) {
      debugPrint("⚠️ Error parsing receipt lines: $e");
    }

    buf.writeln('');
    buf.writeln('Payment Date: ${log.dateTime}');

    return buf.toString().trim();
  }

  static Student? _deepMatchStudentHostClient(
      PaymentLog log, List<Student> students) {
    final logName = log.studentName.trim().toLowerCase();
    final logClass = log.className.trim().toLowerCase();

    Student? best;
    int bestScore = 0;

    for (final s in students) {
      final name = (s.name ?? "").toLowerCase();
      final surname = (s.surname ?? "").toLowerCase();
      final className = (s.class_ ?? "").toLowerCase();
      final full = "$name $surname".trim();

      int score = 0;
      if (full == logName) score += 6;
      if (full.contains(logName) || logName.contains(full)) score += 3;
      for (final part in logName.split(" ")) {
        if (part.isNotEmpty && full.contains(part)) score += 2;
      }
      if (className.contains(logClass) || logClass.contains(className))
        score += 3;

      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }

    return bestScore >= 4 ? best : null;
  }

  static Future<void> sendLogsInSequence(
    List<PaymentLog> logs, {
    required Function(String) showDialog,
    required bool sendParent,
    required bool sendAdmins,
  }) async {
    List<User>? _cachedServerUsersInfo;

    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    List<Map<String, String>> parentDrafts = [];
    if (sendParent) {
      parentDrafts = await draftParentMessages(logs);
      await openSmsDrafts(parentDrafts, showDialog);
    }

    if (sendAdmins) {
      List<User> allUsers = [];

      if (role == DeviceRole.host) {
        final usersBox = await Hive.openBox<User>("users");
        allUsers = usersBox.values.toList();
      } else {
        if (_cachedServerUsersInfo == null) {
          try {
            final res = await HttpClient()
                .getUrl(Uri.parse("http://$hostIp:8080/api/users"))
                .then((req) => req.close());

            if (res.statusCode == 200) {
              final jsonStr = await res.transform(utf8.decoder).join();
              final list = jsonDecode(jsonStr) as List;

              _cachedServerUsersInfo = list
                  .map((e) => usersFromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
          } catch (_) {}
        }

        allUsers = _cachedServerUsersInfo ?? [];
      }

      final adminPhones = allUsers
          .where((u) => (u.role ?? "").toLowerCase().contains("admin"))
          .map((u) => (u.phone ?? "").trim())
          .where((p) => p.isNotEmpty)
          .toSet();

      for (final log in logs) {
        final schoolName = await _getSchoolName();

        final smsBodyCore = await AutomatedSmsHelpers.buildSmsFromLogAdvanced(
            log,
            forcedDuplicate: false,
            getSchoolName: _getSchoolName);
        for (final adminPhone in adminPhones) {
          final ok = await _sendSms(adminPhone, smsBodyCore);
          if (ok) {
            debugPrint("👨‍💼 Admin SMS sent → $adminPhone");
          } else {
            debugPrint("❌ Failed admin SMS → $adminPhone");
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }

    debugPrint("🎉 All queued SMS operations completed.");
  }
}
