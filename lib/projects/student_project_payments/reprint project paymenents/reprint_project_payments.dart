import 'dart:io';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/projects/reprint_project_receipt.dart';
import 'package:zitf_system/reusable_codes/bluetooth_helper_codes/bluetooth_tips_helper.dart';
import 'package:zitf_system/services/printing/receipt_builder.dart';

class ProjectReceiptReprintPage extends StatefulWidget {
  final ReceiptSnapshot receipt;
  final bool forcedDuplicate;

  const ProjectReceiptReprintPage({
    super.key,
    required this.receipt,
    this.forcedDuplicate = false,
  });

  @override
  State<ProjectReceiptReprintPage> createState() =>
      _ProjectReceiptReprintPageState();
}

class _ProjectReceiptReprintPageState extends State<ProjectReceiptReprintPage> {
  late BluetoothHelper bluetoothHelper;
  bool _connected = false;
  bool _printing = false;
  bool _connecting = false;
  String tips = "Connect receipt printer";

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
    bluetoothHelper.verifyConnection();

    bluetoothHelper.bluetoothPrint.state.listen((state) {
      if (state == 1) {
        setState(() => _connecting = true);
      } else {
        setState(() => _connecting = false);
      }

      if (state == 4) {
        setState(() => _printing = true);
      } else if (state == 0 || state == 2) {
        setState(() => _printing = false);
      }
    });
  }

  // Convert stored JSON back to LineText
  List<LineText> _buildLines() {
    final lines = ReceiptBuilder.fromJson(widget.receipt.receiptLinesJson);

    if (widget.forcedDuplicate) {
      lines.insert(
        0,
        LineText(
          type: LineText.TYPE_TEXT,
          content: "*** REPRINT COPY ***",
          align: LineText.ALIGN_CENTER,
          weight: 1,
          linefeed: 1,
        ),
      );
    }

    return lines;
  }

  Future<void> _printReceipt() async {
    if (!_connected || _printing || _connecting) return;

    final lines = _buildLines();

    try {
      await bluetoothHelper.bluetoothPrint.printReceipt({}, lines);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reprinting receipt...")),
      );
    } catch (e) {
      debugPrint("Reprint error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;

    return Scaffold(
      appBar: AppBar(
        title: Text("Receipt #${receipt.receiptCode}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _connected ? _printReceipt : null,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _headerCard(receipt),
            const SizedBox(height: 12),
            Expanded(child: _receiptPreview()),
            const SizedBox(height: 10),
            Text(tips, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(ReceiptSnapshot receipt) {
    final dateStr =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(receipt.receiptDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Receipt #: ${receipt.receiptCode}",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Date: $dateStr"),
            Text("Cashier: ${receipt.cashier}"),
            Text(
                "Total Paid: ${receipt.totalPaid.toStringAsFixed(2)} ${receipt.currency}"),
            if (widget.forcedDuplicate)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text("*** REPRINT COPY ***",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _receiptPreview() {
    final lines = _buildLines();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              line.content ?? '',
              textAlign: _uiTextAlign(line.align),
              style: TextStyle(
                fontSize: (line.fontZoom ?? 1) * 10.0,
                fontWeight: (line.weight ?? 0) == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  TextAlign _uiTextAlign(int? align) {
    switch (align) {
      case LineText.ALIGN_CENTER:
        return TextAlign.center;
      case LineText.ALIGN_RIGHT:
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }
}
