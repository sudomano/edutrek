// lib/student_payments/reprint_viewer_page.dart
// Receipt viewer / reprint page. Supports forcedDuplicate for queued prints.
// Rebuilds SMS body from log lines (no smsText required).

import 'dart:convert';
import 'dart:io' show HttpClient, Platform;
import 'package:background_sms/background_sms.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/payment_receipts_log.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';

class ReceiptViewerPage extends StatefulWidget {
  final PaymentLog log;
  final bool
      forcedDuplicate; // when true (queue), show duplicate flag and print as duplicate

  const ReceiptViewerPage({
    super.key,
    required this.log,
    this.forcedDuplicate = false,
  });

  @override
  State<ReceiptViewerPage> createState() => _ReceiptViewerPageState();
}

class _ReceiptViewerPageState extends State<ReceiptViewerPage> {
  late BluetoothHelper bluetoothHelper;
  bool _connected = false;
  bool _scanning = false;
  bool _connecting = false;
  bool _printing = false;
  String tips = "Connect receipt printer";
  int? bluetoothState;
  BluetoothDevice? _device;

  @override
  void initState() {
    super.initState();
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
      if (state == 1)
        setState(() => _connecting = true);
      else
        setState(() => _connecting = false);

      if (state == 4)
        setState(() => _printing = true);
      else if (state == 0 || state == 2) setState(() => _printing = false);
    });

    bluetoothHelper.bluetoothPrint.isScanning.listen((scanning) {
      setState(() => _scanning = scanning);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // convert stored JSON → LineText
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
        content: line["content"]?.toString() ?? "",
        align: _mapPrinterAlign(line["align"]),
        weight: (line["weight"] ?? 0) == 1 ? 1 : 0,
        fontZoom: line["fontZoom"] ?? 1,
        linefeed: line["linefeed"] ?? 1,
      );
    }).toList();
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
      if (_cachedServerSchoolInfo != null &&
          _cachedServerSchoolInfo.isNotEmpty) {
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

  /// Builds an SMS body from the stored receiptLines + metadata (no smsText stored required)
  Future<String> _buildSmsBodyFromLog(PaymentLog log) async {
    final schoolName = await _getSchoolName();
    final buf = StringBuffer();
    buf.writeln(schoolName);
    buf.writeln('');
    // If this view was opened as forcedDuplicate (queue), indicate duplicate in SMS too.
    if (widget.forcedDuplicate) {
      buf.writeln('DUPLICATE MESSAGE.');
      buf.writeln('');
    }
    buf.writeln('Dear Parent,');
    buf.writeln('');
    buf.writeln('${log.studentName} has paid:');

    try {
      for (final l in log.receiptLines) {
        final content = (l['content'] ?? '').toString();
        final trimmed = content.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('---') || trimmed.startsWith('***')) continue;
        final lower = trimmed.toLowerCase();
        if (lower.contains('paid') ||
            lower.contains('total paid') ||
            RegExp(r'\$\s*\d').hasMatch(trimmed) ||
            lower.contains('term') ||
            lower.contains('payments for') ||
            lower.contains('school fees') ||
            lower.contains('term arrears') ||
            lower.contains('total arrears')) {
          buf.writeln(trimmed);
        }
      }
    } catch (_) {}
    buf.writeln('');
    buf.writeln('Payment Date: ${log.dateTime}');
    return buf.toString().trim();
  }

  // ----------------------------
  // Print / Reprint entry point
  // ----------------------------
  Future<void> _printReceipt() async {
    if (_printing || _connecting) return;
    setState(() => _printing = true);

    try {
      if (Platform.isAndroid) {
        if (!_connected) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No printer connected")));
          setState(() => _printing = false);
          return;
        }

        final List<LineText> lines =
            _jsonToReceiptLines(widget.log.receiptLines);

        // Insert duplicate banner only when forcedDuplicate is true
        if (widget.forcedDuplicate) {
          lines.insert(
            0,
            LineText(
              type: LineText.TYPE_TEXT,
              content: "*** DUPLICATE COPY ***",
              align: LineText.ALIGN_CENTER,
              linefeed: 1,
              fontZoom: 1,
              weight: 1,
            ),
          );
        }

        await bluetoothHelper.bluetoothPrint.printReceipt({}, lines);

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Printing started...")));

        // short delay then optionally do after-print actions (sms)
        await Future.delayed(const Duration(milliseconds: 300));
        await _afterPrintActionsAndroid();

        // fallback unlock
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _printing = false);
        });
      } else {
        // fallback for other platforms: treat as preview
        await _openPdfPreviewForLog(widget.log);
        setState(() => _printing = false);
      }
    } catch (e) {
      debugPrint('Print error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Print error: $e")));
      if (mounted) setState(() => _printing = false);
    }
  }

  // ----------------------------
  // AFTER-PRINT: SMS prompt and send
  // ----------------------------
  Future<void> _afterPrintActionsAndroid() async {
    debugPrint("AFTER-PRINT: building sms body...");
    final smsBody = await _buildSmsBodyFromLog(widget.log);

    // Ask user which recipients
    final choices = await _askSmsResendOptions();
    if (choices == null) return;

    final sendParent = choices['parent'] ?? false;
    final sendAdmin = choices['admin'] ?? false;
    if (!sendParent && !sendAdmin) return;

    // Open boxes
    final studentsBox = await Hive.openBox<Student>('students');
    final usersBox = await Hive.openBox<User>('users');

    // try deep match
    final matchedStudent = _deepMatchStudent(widget.log, studentsBox);

    final parentPhone = matchedStudent?.phoneNumber;
    final parentTitleAndName = matchedStudent?.paymentStatus;

    // admin phones (unique)
    final Set<String> adminPhones = {};
    for (final u in usersBox.values) {
      final role = (u.role ?? '').toString().toLowerCase().trim();
      if (role.contains('admin')) {
        final phone = (u.phone ?? '').toString().trim();
        if (phone.isNotEmpty) adminPhones.add(phone);
      }
    }

    // Send to parent (open composer)
    if (sendParent) {
      if (parentPhone == null || parentPhone.trim().isEmpty) {
        _showDialog("Parent phone not available.");
      } else {
        final greeting =
            (parentTitleAndName != null && parentTitleAndName.trim().isNotEmpty)
                ? "Dear ${parentTitleAndName.toUpperCase()},\n\n"
                : "Dear Parent,\n\n";
        final body = "$greeting$smsBody";
        await _sendSmsNotification(body, parentPhone.trim());
      }
    }

    // Send admin (background)
    if (sendAdmin) {
      if (adminPhones.isEmpty) {
        _showDialog("No admin phone numbers found.");
      } else {
        for (final phone in adminPhones) {
          try {
            await sendSms(smsBody, phone);
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            debugPrint('Failed to send admin SMS to $phone: $e');
          }
        }
      }
    }
  }

  // ----------------------------
  // Student deep match (name / surname / _class)
  // ----------------------------
  Student? _deepMatchStudent(PaymentLog log, Box<Student> box) {
    final logName = log.studentName.trim().toLowerCase();
    final logClass = log.className.trim().toLowerCase();

    Student? best;
    int bestScore = 0;
    for (final s in box.values) {
      final name = (s.name ?? '').toString().toLowerCase();
      final surname = (s.surname ?? '').toString().toLowerCase();
      final className = (s.class_ ?? '').toString().toLowerCase();
      final full = "$name $surname".trim();

      int score = 0;
      if (full == logName) score += 6;
      if (full.contains(logName) || logName.contains(full)) score += 3;

      for (final part in logName.split(' ')) {
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

  // ----------------------------
  // SMS helpers
  // ----------------------------
  Future<Map<String, bool>?> _askSmsResendOptions() async {
    bool sendParent = true;
    bool sendAdmin = true;
    return await showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Resend SMS Notification?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                    value: sendParent,
                    title: const Text("Send to Parent (open SMS composer)"),
                    onChanged: (v) => setState(() => sendParent = v ?? false)),
                CheckboxListTile(
                    value: sendAdmin,
                    title: const Text("Send to Admin (background SMS)"),
                    onChanged: (v) => setState(() => sendAdmin = v ?? false)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(
                      ctx, {'parent': sendParent, 'admin': sendAdmin}),
                  child: const Text("Send")),
            ],
          );
        });
      },
    );
  }

  Future<void> sendSms(String message, String recipient) async {
    if (!Platform.isAndroid) {
      _showDialog('Background SMS is only supported on Android.');
      return;
    }
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      var result = await Permission.sms.request();
      if (!result.isGranted) {
        _showDialog('SMS permission is not granted.');
        return;
      }
    }

    try {
      const int chunkSize = 153;
      for (int i = 0; i < message.length; i += chunkSize) {
        final end =
            (i + chunkSize < message.length) ? i + chunkSize : message.length;
        final part = message.substring(i, end);
        final res = await BackgroundSms.sendMessage(
            phoneNumber: recipient, message: part);
        if (res != SmsStatus.sent) {
          debugPrint('Failed to send chunk to $recipient');
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint('Exception while sending SMS: $e');
      _showDialog('Error sending SMS: $e');
    }
  }

  Future<void> _sendSmsNotification(String body, String phone) async {
    final encoded = Uri.encodeComponent(body);
    final uri = Uri.parse('sms:$phone?body=$encoded');
    if (await launcher.canLaunchUrl(uri)) {
      await launcher.launchUrl(uri);
    } else {
      _showDialog('Could not open SMS app.');
    }
  }

  Future<void> _openPdfPreviewForLog(PaymentLog log) async {
    debugPrint('Open PDF preview for ${log.receiptNumber}');
  }

  // ----------------------------
  // UI & helpers
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final isAndroid = Platform.isAndroid;
    final iconData = isAndroid ? Icons.print : Icons.picture_as_pdf;
    final iconTooltip = isAndroid
        ? (_connected
            ? (_printing ? 'Printing...' : 'Print receipt')
            : 'No printer connected')
        : 'Reprint PDF';
    final iconEnabled =
        (isAndroid ? _connected : true) && !_printing && !_connecting;

    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text("Receipt #${log.receiptNumber}")),
        /*actions: [
          IconButton(
              icon: Icon(iconData),
              onPressed: iconEnabled ? _printReceipt : null,
              color: iconEnabled ? Colors.black : Colors.grey,
              tooltip: iconTooltip)
        ],*/
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          _headerCard(log, isDuplicate: widget.forcedDuplicate),
          const SizedBox(height: 12),
          Expanded(child: _receiptPreview(log)),
          const Divider(),
          /* Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(tips, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            if (_connecting) const CircularProgressIndicator(strokeWidth: 2),
            if (_printing && !_connecting)
              const Row(children: [SizedBox(width: 8), Text('Printing...')]),
          ]),*/
        ]),
      ),
      /* floatingActionButton: FloatingActionButton(
          backgroundColor: _scanning ? Colors.red : Colors.blue,
          child: Icon(_scanning ? Icons.stop : Icons.search),
          onPressed: () {
            if (_scanning) {
              bluetoothHelper.bluetoothPrint.stopScan();
              setState(() => tips = 'Scan stopped');
            } else {
              bluetoothHelper.bluetoothPrint
                  .startScan(timeout: const Duration(seconds: 5));
              setState(() => tips = 'Scanning for printers...');
            }
          }),*/
    );
  }

  Widget _headerCard(PaymentLog log, {bool isDuplicate = false}) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(DateTime.tryParse(log.dateTime) ?? DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.studentName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Class: ${log.className}"),
          Text("Date: $dateStr"),
          Text("Receipt #: ${log.receiptNumber}"),
          Text("parent: ${log.parentName}"),
          Text("phone #: ${log.parentPhone}"),
          if (isDuplicate)
            const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text("*** DUPLICATE COPY ***",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  Widget _receiptPreview(PaymentLog log) {
    final lines = _jsonToReceiptLines(log.receiptLines);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8)),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(line.content ?? '',
                textAlign: _uiTextAlign(line.align),
                style: TextStyle(
                    fontSize: (line.fontZoom ?? 1) * 10.0,
                    fontWeight: (line.weight ?? 0) == 1
                        ? FontWeight.bold
                        : FontWeight.normal)),
          );
        },
      ),
    );
  }

  TextAlign _uiTextAlign(int? align) {
    switch (align) {
      case LineText.ALIGN_CENTER:
      case 1:
        return TextAlign.center;
      case LineText.ALIGN_RIGHT:
      case 2:
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  Future<void> _showDialog(String message) async {
    if (!mounted) return;
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("🧾 Payment Feedback"),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("OK"))
                ]));
  }
}
