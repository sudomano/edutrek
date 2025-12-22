// lib/student_payments/receipt_history_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:background_sms/background_sms.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/payment_log_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';
import 'package:zitf_system/reusable_codes/serializers/users_serializer.dart';
import 'package:zitf_system/student_payments/reprint_viewer_page.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:http/http.dart' as http;

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

  bool showFilters = false;

  int _batchSize = 100;
  int _currentBatchEnd = 100;

  DeviceRole? _role;
  String? _hostIp;

  List<PaymentLog> _remoteLogs = [];
  bool _loading = false;

  List<School>? _cachedServerSchoolInfo;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _initData();

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

    // Listen to Bluetooth state
    bluetoothHelper.bluetoothPrint.state.listen((state) {
      bluetoothState = state;

      setState(() {
        _connecting = state == 1;
        _printing = state == 4;
      });
    });

    // Listen for scanning
    bluetoothHelper.bluetoothPrint.isScanning.listen((scanning) {
      setState(() => _scanning = scanning);
    });

    // Listen for discovered devices
    bluetoothHelper.bluetoothPrint.scanResults.listen((results) {
      setState(() => _scanResults = results);
    });
  }

  Future<void> _initData() async {
    final host = await isHostDevice();
    print("📡 Device mode: ${host ? "HOST" : "CLIENT"}");

    if (host) {
      print("📦 HOST: Reading Hive logs directly");
      _logBox = Hive.box<PaymentLog>("payment_log");
    } else {
      print("🌍 CLIENT: Fetching logs from HOST API");
      await _fetchRemoteLogs();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AutomatedSmsHelpers.resumeDraftSequence();
    }
  }

  Future<bool> isHostDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _role = await getDeviceRole();

    if (_role == DeviceRole.host) {
      print(DeviceRole.host); // <-- semicolon added
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

      final uri = Uri.parse(
          "http://$hostIp:8080/api/receipt_logs?search=$_searchQuery");

      print("🌍 FETCH => $uri");

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

    // auto reconnect attempt
    _attemptAutoReconnect(savedAddress);
  }

  Future<void> _attemptAutoReconnect(String address) async {
    print("🔄 [AUTO] Starting auto-reconnect to: $address");
    setState(() {
      tips = "Reconnecting to last printer…";
      _autoReconnecting = true;
    });

    try {
      print("🔄 [AUTO] Starting scan...");
      await bluetoothHelper.bluetoothPrint.startScan(
        timeout: const Duration(seconds: 4),
      );

      // WAIT for stream to update → get latest list
      final devices = await bluetoothHelper.bluetoothPrint.scanResults
          .timeout(const Duration(seconds: 5))
          .firstWhere((list) => list.isNotEmpty, orElse: () => []);

      print("📡 [AUTO] Scan results found ${devices.length} device(s).");
      for (var d in devices) {
        print("📡 Device: ${d.name} | ${d.address}");
      }

      final match = devices.firstWhere(
        (d) => d.address == address,
        orElse: () => [] as BluetoothDevice,
      );

      if (match == null) {
        print(" [AUTO] Previous printer NOT FOUND.");
        setState(() {
          tips = "Previous printer not found";
          _autoReconnecting = false;
        });
        return;
      }

      print(
          "🔗 [AUTO] Attempting connection to ${match.name} (${match.address})");

      await bluetoothHelper.bluetoothPrint.connect(match);

      print("✅ [AUTO] Reconnected to ${match.name}");

      setState(() {
        _device = match;
        _connected = true;
        tips = "Reconnected to ${match.name}";
      });
    } catch (e) {
      print("❌ [AUTO] Reconnect failed: $e");
      setState(() => tips = "Reconnection failed");
    } finally {
      _autoReconnecting = false;
    }
  }

  List<PaymentLog> get _filteredLogs {
    print("🧠 Running _filteredLogs getter…");

    final hostLogs = _logBox.values.toList();
    final remoteLogs = List<PaymentLog>.from(_remoteLogs);

    List<PaymentLog> logs = hostLogs.isNotEmpty ? hostLogs : remoteLogs;
    print("📦 Source logs count: ${logs.length}");

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
      print("🔍 After search filter: ${logs.length}");
    }

    // STUDENT FILTER
    if (filterStudent.isNotEmpty) {
      logs = logs
          .where((log) => log.studentName
              .toLowerCase()
              .contains(filterStudent.toLowerCase()))
          .toList();
      print("🧑‍🎓 Student filter: ${logs.length}");
    }

    // CLASS FILTER
    if (filterClass.isNotEmpty) {
      logs = logs
          .where((log) =>
              log.className.toLowerCase().contains(filterClass.toLowerCase()))
          .toList();
      print("🏷 Class filter: ${logs.length}");
    }

    // RECEIPT NUMBER
    if (filterReceiptNumber.isNotEmpty) {
      logs = logs
          .where((log) =>
              log.receiptNumber.toString().contains(filterReceiptNumber))
          .toList();
      print("🧾 Receipt # filter: ${logs.length}");
    }

    // DATE RANGE
    if (filterFromDate != null) {
      logs = logs.where((log) {
        final dt = DateTime.tryParse(log.dateTime);
        if (dt == null) return false; // ignore bad dates
        return dt.isAfter(filterFromDate!);
      }).toList();

      print("📆 From date filter: ${logs.length}");
    }

    if (filterToDate != null) {
      logs = logs.where((log) {
        final dt = DateTime.tryParse(log.dateTime);
        if (dt == null) return false;
        return dt.isBefore(filterToDate!);
      }).toList();

      print("📆 To date filter: ${logs.length}");
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

  // DELETE
  void _confirmDelete(PaymentLog log) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Receipt"),
        content:
            const Text("Are you sure you want to delete this receipt log?"),
        actions: [
          TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context)),
          TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                log.delete();
                Navigator.pop(context);
              }),
        ],
      ),
    );
  }

  // ----------------------------
  // UI BUILD
  // ----------------------------

  // ----------------------------
// POP-UP RECEIPT PREVIEW
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
                // Header
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

                // Student info
                Text("${log.studentName} • ${log.className}"),
                Text("Date: ${log.dateTime}"),
                const SizedBox(height: 12),

                // Receipt lines
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

                // Close button
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
          if (_selectedIndexes.isNotEmpty)
            IconButton(
              tooltip: 'Print queue',
              icon: const Icon(Icons.print),
              onPressed: () => _printSelectedReceipts(_filteredLogs),
            )
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

              // Centered Search Bar
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildSearchBar(),
              ),

              const SizedBox(height: 8),

              // Centered Filter Panel
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildFilterPanel(),
              ),

              const SizedBox(height: 12),

              // Receipts in a tall box that can scroll inside main scroll view
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
      floatingActionButton: _selectedIndexes.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.print),
              label: Text("Print ${_selectedIndexes.length}"),
              onPressed: () => _printSelectedReceipts(_filteredLogs),
            ),
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
        onChanged: (value) => setState(() => _searchQuery = value),
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

                // --- TEXT INPUTS ---
                _buildFilterInput("Student Name", (v) => filterStudent = v),
                _buildFilterInput("Class Name", (v) => filterClass = v),
                _buildFilterInput(
                    "Receipt Number", (v) => filterReceiptNumber = v),
                _buildFilterInput(
                    "Text inside Receipt Lines", (v) => filterLineContent = v),

                const SizedBox(height: 10),

                // --- DATE RANGE ---
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
        print("📡 Mode: ${host ? "HOST" : "CLIENT"}");

        // 1. GET SOURCE LIST
        List<PaymentLog> logs =
            host ? _logBox.values.toList() : List.from(_remoteLogs);

        print("📦 Loaded raw logs: ${logs.length}");

        // 2. SORT (corrected, since sort() returns void)
        logs.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));
        print("🔢 Logs sorted OK");

        // 3. Apply batching BEFORE filter
        final total = logs.length;
        final end = _currentBatchEnd.clamp(0, total);
        final pagedReceipts = logs.sublist(0, end);
        print("📑 Batching: showing $end of $total");

        // 4. Apply filtering
        final filtered = pagedReceipts.where((r) {
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

        print("🔍 Filtered results: ${filtered.length}");

        if (filtered.isEmpty) {
          return const Center(child: Text("No receipts found"));
        }

        return Column(
          children: [
            // SELECT ALL
            Row(
              children: [
                Checkbox(
                  value: filtered.isNotEmpty &&
                      _selectedIndexes.length == filtered.length,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedIndexes
                          ..clear()
                          ..addAll(List.generate(filtered.length, (i) => i));
                      } else {
                        _selectedIndexes.clear();
                      }

                      print("✔ Select All changed → $_selectedIndexes");
                    });
                  },
                ),
                const Text(
                  "Select All",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // PAGINATION
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentBatchEnd < total)
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _currentBatchEnd += _batchSize);
                      print("➡ Load next batch: $_currentBatchEnd");
                    },
                    child: const Text("Load Next 100"),
                  ),
                const SizedBox(width: 12),
                if (_currentBatchEnd < total)
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _currentBatchEnd = total);
                      print("📥 Load ALL logs");
                    },
                    child: const Text("Load All"),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // MAIN LIST
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final log = filtered[index];
                final selected = _selectedIndexes.contains(index);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: Checkbox(
                      value: selected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedIndexes.add(index);
                          } else {
                            _selectedIndexes.remove(index);
                          }
                          print("🟦 Row $index selected → $checked");
                        });
                      },
                    ),
                    title: Text(
                      log.studentName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text("${log.className} • ${log.dateTime}"),
                    onTap: () {
                      print(
                          "📄 Opening viewer for receipt ${log.receiptNumber}");
                      _showReceiptPreview(log);
                    },
                    onLongPress: () {
                      print("🗑 Long press delete ${log.receiptNumber}");
                      _confirmDelete(log);
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
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

        // ───────────────────────────────────────────
        // TITLE (with auto reconnect status)
        // ───────────────────────────────────────────
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

        // ───────────────────────────────────────────
        // EXPANSION CONTENTS
        // ───────────────────────────────────────────
        children: [
          if (_scanning) const LinearProgressIndicator(),
          const SizedBox(height: 8),

          // ───────────────────────────────────────────
          // SCAN BUTTON
          // ───────────────────────────────────────────
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

          // ───────────────────────────────────────────
          // DEVICE LIST (StreamBuilder source)
          // ───────────────────────────────────────────
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

          const SizedBox(height: 10),

          // ───────────────────────────────────────────
          // CONNECT / DISCONNECT BUTTONS
          // ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CONNECT
              OutlinedButton(
                onPressed: _connected
                    ? null
                    : () async {
                        if (_device == null) {
                          setState(() => tips = "Please select a device first");
                          return;
                        }

                        setState(() {
                          _connecting = true;
                          tips = "Connecting…";
                        });

                        try {
                          await bluetoothHelper.bluetoothPrint
                              .connect(_device!);

                          // SAVE PRINTER FOR AUTO-RECONNECT
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
                      },
                child: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Connect"),
              ),

              const SizedBox(width: 10),

              // DISCONNECT
              OutlinedButton(
                onPressed: _connected
                    ? () async {
                        setState(() {
                          tips = "Disconnecting…";
                          _connecting = true;
                        });

                        try {
                          await bluetoothHelper.bluetoothPrint.disconnect();
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

  void _showDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Notice"),
        content: Text(msg),
        actions: [
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
    print("🖨 Starting print queue...");
    print("🔢 Selected indexes: $_selectedIndexes");

    // 1. Detect host/client
    final host = await isHostDevice();
    print("📡 Device mode: ${host ? "HOST" : "CLIENT"}");

    // 2. Load source logs
    List<PaymentLog> sourceLogs =
        host ? _logBox.values.toList() : List.from(_remoteLogs);

    print("📦 Raw logs loaded: ${sourceLogs.length}");

    // 3. Sort newest → oldest
    sourceLogs.sort((a, b) => b.receiptNumber.compareTo(a.receiptNumber));
    print("🧾 Logs sorted successfully.");

    // 4. Map selected indexes to the *filtered* list
    if (_selectedIndexes.isEmpty) {
      print("⚠ No receipts selected. Aborting print.");
      return;
    }

    if (_selectedIndexes.length > filteredList.length) {
      print("❌ ERROR: Selected index overflow. Resetting selection.");
      setState(() => _selectedIndexes.clear());
      return;
    }

    final List<PaymentLog> toPrint =
        _selectedIndexes.map((i) => filteredList[i]).toList();

    print("🗂 Receipts to print: ${toPrint.length}");

    if (toPrint.isEmpty) {
      print("⚠ Empty print list after mapping. Aborting.");
      return;
    }

    // 5. Printer connection check
    if (!_connected) {
      print("❌ Printer not connected.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please connect a printer first.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Printing ${toPrint.length} receipts…")),
    );

    try {
      // 6. PRINT LOGS IN ORDER
      print("🖨 Starting automated printing...");
      await AutomatedPrintHelper.printLogsInSequence(
        toPrint,
        bluetoothHelper.bluetoothPrint,
      );

      print("📨 Sending SMS notifications...");
      await AutomatedSmsHelpers.sendLogsInSequence(
        toPrint,
        sendParent: true,
        sendAdmins: true,
        showDialog: _showDialog,
      );

      print("✔ Print + SMS completed.");
    } catch (e, st) {
      print("❌ ERROR during printing or SMS: $e");
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    // 7. Clear selections
    setState(() {
      _selectedIndexes.clear();
    });
    print("🧹 Cleared selection.");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Finished printing queue.")),
    );
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
      List<PaymentLog> logs, BluetoothPrint bluetooth) async {
    for (final log in logs) {
      try {
        final lines = _jsonToReceiptLines(log.receiptLines);

        // Add duplicate header for REPRINTS ONLY
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
      }
    }
  }
}

Future<String> _getSchoolName() async {
  List<School>? _cachedServerSchoolInfo;

  try {
    // Detect device role
    final role = await getDeviceRole();

    // Load host IP for client devices
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    // ---------------------------
    // HOST MODE
    // ---------------------------
    if (role == DeviceRole.host) {
      final box = await Hive.openBox<School>('school');
      if (box.isNotEmpty) {
        return box.values.first.schoolName ?? "SCHOOL";
      }
      return "SCHOOL";
    }

    // ---------------------------
    // CLIENT MODE
    // ---------------------------
    if (hostIp.isEmpty) {
      debugPrint("❌ Host IP not set.");
      return "SCHOOL";
    }

    // If already cached from previous fetch, return cached
    if (_cachedServerSchoolInfo != null && _cachedServerSchoolInfo.isNotEmpty) {
      return _cachedServerSchoolInfo.first.schoolName ?? "SCHOOL";
    }

    // Fetch from host
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
  // ───────────────────────────────────────────────────────────────
  // Collect all parent messages into drafts
  // ───────────────────────────────────────────────────────────────
  static Future<List<Map<String, String>>> draftParentMessages(
      List<PaymentLog> logs) async {
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    List<Student> allStudents = [];
    List<Student>? _cachedServerStudentInfo;

    // HOST → Local Hive
    if (role == DeviceRole.host) {
      final box = await Hive.openBox<Student>("students");
      allStudents = box.values.toList();
    }
    // CLIENT → Fetch from host
    else {
      print(
          "📱 CLIENT MODE: Using parentName & parentPhone from logs directly");
      allStudents = []; // completely unused now
    }

    // Build drafts
    final List<Map<String, String>> drafts = [];

    for (final log in logs) {
      String phone = "";
      String greeting = "";
      if (role == DeviceRole.host) {
        final student = _deepMatchStudentHostClient(log, allStudents);

        phone = student?.phoneNumber?.trim() ?? "";
        if (student == null) {
          print("⚠️ No student match for ${log.studentName}, skipping");
          continue;
        }

        phone = student.phoneNumber?.trim() ?? "";
        if (phone.isEmpty) {
          print("⚠️ HOST: Missing phone for student ${student.name}, skipping");
          continue;
        }
        greeting = (student?.paymentStatus?.isNotEmpty ?? false)
            ? "Dear ${student!.paymentStatus!.toUpperCase()},\n\n"
            : "DUPLICATE COPY,\n";
      } else {
        phone = (log.parentPhone ?? "").trim();
        if (phone.isEmpty) {
          print("⚠️ CLIENT: Missing parentPhone in log, skipping");
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
      print("✅ Draft added for $phone");
    }

    return drafts;
  }

  // ───────────────────────────────────────────────────────────────
  // Open SMS app for user to review/send all drafts sequentially
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
  // SEND BACKGROUND SMS (Admins only)
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
// Build message from receipt log (ADVANCED VERSION)
// ───────────────────────────────────────────────────────────────
  static Future<String> buildSmsFromLogAdvanced(
    PaymentLog log, {
    required bool forcedDuplicate,
    required Future<String> Function() getSchoolName,
  }) async {
    final schoolName = await getSchoolName();
    final buf = StringBuffer();

    // School name
    buf.writeln(schoolName);
    buf.writeln('');

    // Duplicate marker
    if (forcedDuplicate) {
      buf.writeln('DUPLICATE MESSAGE.');
      buf.writeln('');
    }

    // Greeting
    buf.writeln('DUPLICATE COPY,');
    buf.writeln('');
    buf.writeln('${log.studentName} has paid:');

    try {
      for (final line in log.receiptLines) {
        final content = (line['content'] ?? '').toString();
        final trimmed = content.trim();
        if (trimmed.isEmpty) continue;

        // Skip separators
        if (trimmed.startsWith('---') || trimmed.startsWith('***')) continue;

        final lower = trimmed.toLowerCase();

        // Only pick meaningful lines
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

  // ───────────────────────────────────────────────────────────────
  // Deep match student
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
  // MAIN SEQUENCE → Draft all parent SMS, then send admins in background
  // ───────────────────────────────────────────────────────────────
  static Future<void> sendLogsInSequence(
    List<PaymentLog> logs, {
    required Function(String) showDialog,
    required bool sendParent,
    required bool sendAdmins,
  }) async {
    List<User>? _cachedServerUsersInfo;

    // Detect role & host IP
    final role = await getDeviceRole();
    final prefs = await SharedPreferences.getInstance();
    final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

    // 1️⃣ Build drafts for parents
    List<Map<String, String>> parentDrafts = [];
    if (sendParent) {
      parentDrafts = await draftParentMessages(logs);
      await openSmsDrafts(parentDrafts, showDialog);
    }

    // 2️⃣ Send background SMS to admins
    if (sendAdmins) {
      List<User> allUsers = [];

      // HOST: Local users box
      if (role == DeviceRole.host) {
        final usersBox = await Hive.openBox<User>("users");
        allUsers = usersBox.values.toList();
      }
      // CLIENT: Fetch from host
      else {
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

      // Extract admin phones
      final adminPhones = allUsers
          .where((u) => (u.role ?? "").toLowerCase().contains("admin"))
          .map((u) => (u.phone ?? "").trim())
          .where((p) => p.isNotEmpty)
          .toSet();

      for (final log in logs) {
        final schoolName = await _getSchoolName();

        final smsBodyCore =
            await AutomatedSmsHelpers.buildSmsFromLogAdvanced(log,
                forcedDuplicate: false, // from your UI if needed
                getSchoolName: _getSchoolName // <-- pass your function here
                );
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
