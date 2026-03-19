import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/projects/reprint_project_receipt.dart';
import 'package:zitf_system/projects/student_project_payments/reprint%20project%20paymenents/reprint_project_payments.dart';

class ProjectReceiptDashboardPage extends StatefulWidget {
  const ProjectReceiptDashboardPage({super.key});

  @override
  State<ProjectReceiptDashboardPage> createState() =>
      _ProjectReceiptDashboardPageState();
}

class _ProjectReceiptDashboardPageState
    extends State<ProjectReceiptDashboardPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  List<ReceiptSnapshot> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  void _loadReceipts() {
    final box = Hive.box<ReceiptSnapshot>('receipt_snapshots');
    setState(() {
      _filtered = box.values.toList();
    });
  }

  void _applyFilters() {
    final box = Hive.box<ReceiptSnapshot>('receipt_snapshots');

    final search = _searchCtrl.text.toLowerCase();

    final results = box.values.where((r) {
      final matchesSearch = r.studentName.toLowerCase().contains(search) ||
          r.receiptCode.toLowerCase().contains(search);

      final matchesDate = _dateRange == null
          ? true
          : r.receiptDate.isAfter(
                  _dateRange!.start.subtract(const Duration(days: 1))) &&
              r.receiptDate
                  .isBefore(_dateRange!.end.add(const Duration(days: 1)));

      return matchesSearch && matchesDate;
    }).toList();

    setState(() {
      _filtered = results;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalReceipts = _filtered.length;
    final totalAmount = _filtered.fold(0.0, (sum, r) => sum + r.totalPaid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Project Receipt Reprints"),
      ),
      body: Column(
        children: [
          _summaryHeader(totalReceipts, totalAmount),
          _searchSection(),
          Expanded(child: _receiptList()),
        ],
      ),
    );
  }

  Widget _summaryHeader(int count, double totalAmount) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [
              const Text("Receipts"),
              Text(count.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))
            ]),
            Column(children: [
              const Text("Total Amount"),
              Text(totalAmount.toStringAsFixed(2),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16))
            ]),
          ],
        ),
      ),
    );
  }

  Widget _searchSection() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: "Search student or receipt #",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
    );
  }

  Widget _receiptList() {
    if (_filtered.isEmpty) {
      return const Center(child: Text("No receipts found"));
    }

    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final receipt = _filtered[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(receipt.studentName),
            subtitle: Text(
                "Receipt: ${receipt.receiptCode}\n${DateFormat('yyyy-MM-dd HH:mm').format(receipt.receiptDate)}"),
            trailing: Text(
              receipt.totalPaid.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectReceiptReprintPage(
                    receipt: receipt,
                    forcedDuplicate: true,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
