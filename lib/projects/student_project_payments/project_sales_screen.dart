import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/projects/student_project_payments/project_sales_details_screen.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/serializers/school_serializer.dart';

const double kMaxContentWidth = 1280;
const double kPagePadding = 16;
const double kSectionPadding = 16;
const double kBorderRadius = 12;

class ProjectSalesViewScreen extends StatefulWidget {
  const ProjectSalesViewScreen({super.key});

  @override
  State<ProjectSalesViewScreen> createState() => _ProjectSalesViewScreenState();
}

class _ProjectSalesViewScreenState extends State<ProjectSalesViewScreen> {
  late List<ProjectSaleTransaction> _all;
  late List<Student> _students;
  late List<Project> _projects;
  late List<ProjectItem> _items;

  Student? _student;
  Project? _project;
  ProjectItem? _item;
  String? _paymentMethod;
  String? _currency;
  String? _financialType;
  bool _showOutstandingOnly = false;
  DateTimeRange? _dateRange;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _listScrollCtrl = ScrollController();

  double get _totalSales => _filtered
      .where((t) => t.createsObligation)
      .fold(0.0, (sum, t) => sum + t.totalAmount);

  double get _totalPayments => _filtered
      .where((t) => t.settlesObligation)
      .fold(0.0, (sum, t) => sum + t.amountPaid);

  double get _totalOutstanding => _filtered
      .where((t) => t.createsObligation)
      .fold(0.0, (sum, t) => sum + _calculateOutstanding(t, _all));

  Map<String, List<ProjectSaleTransaction>> _groupedTransactions = {};
  Map<String, Map<String, double>> _studentSummary = {};

  double _computedTotalSettlements = 0.0;
  double _computedTotalSales = 0.0;
  double _computedTotalPayments = 0.0;
  double _computedTotalOutstanding = 0.0;

  Map<String, dynamic> _hierarchicalData = {};
  DateTime? _singleDate;
  List<School>? _cachedServerSchoolInfo;

  @override
  void initState() {
    super.initState();
    _load();
    fetchSchools();
  }

  void _load() {
    _all = Hive.box<ProjectSaleTransaction>('project_sale_transactions')
        .values
        .toList();
    _students = Hive.box<Student>('students').values.toList();
    _projects = Hive.box<Project>('projects').values.toList();
    _items = Hive.box<ProjectItem>('projectItems').values.toList();

    // Select all by default
    _selectedProjects = List<Project>.from(_projects);
    _selectedItems = List<ProjectItem>.from(_items);
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

  double _calculateOutstanding(
      ProjectSaleTransaction sale, List<ProjectSaleTransaction> allTx) {
    if (!sale.createsObligation) return 0.0;
    final linkedPayments = allTx.where(
      (t) =>
          t.parentTransactionCode == sale.transactionCode &&
          t.settlesObligation,
    );
    final totalPaid = sale.amountPaid +
        linkedPayments.fold<double>(0, (sum, t) => sum + t.amountPaid);
    return (sale.totalAmount - totalPaid).clamp(0, double.infinity);
  }

  List<ProjectSaleTransaction> get _filtered {
    final query = _searchCtrl.text.toLowerCase();
    return _all.where((t) {
      if (_student != null && t.studentId != _student!.studentIdNumber) {
        return false;
      }
      if (_selectedProjects.isNotEmpty &&
          !_selectedProjects.any((p) => p.projectCode == t.projectCode)) {
        return false;
      }

      if (_selectedItems.isNotEmpty &&
          !_selectedItems.any((i) => i.projectItemCode == t.projectItemCode)) {
        return false;
      }

      if (_paymentMethod != null && t.paymentMethod != _paymentMethod) {
        return false;
      }
      if (_currency != null && t.currency != _currency) return false;
      if (_financialType != null &&
          t.financialType.toLowerCase() != _financialType!.toLowerCase()) {
        return false;
      }
      if (_dateRange != null) {
        final txDate = DateTime(t.transactionDate.year, t.transactionDate.month,
            t.transactionDate.day);

        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month,
            _dateRange!.start.day);

        final end = DateTime(
            _dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);

        if (txDate.isBefore(start) || txDate.isAfter(end)) {
          return false;
        }
      }
      if (_showOutstandingOnly && _calculateOutstanding(t, _all) <= 0) {
        return false;
      }
      if (query.isNotEmpty &&
          !(t.transactionCode.toLowerCase().contains(query) ||
              (t.reference).toLowerCase().contains(query))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  Future<Uint8List> generateProjectsPDF({
    required List<ProjectSaleTransaction> transactions,
    required List<Student> students,
    required List<Project> projects,
    required List<ProjectItem> items,
  }) async {
    final pdf = pw.Document();

    // Headers
    final headers = [
      'Project',
      'Item',
      'Batch',
      'Date',
      'Qty',
      'Total',
      'Outstanding',
      'Payment Method',
      'Payment Code'
    ];

    // Fetch school info
    final School schoolInfo = await _getSchoolInfo();

    // Optional logo
    pw.MemoryImage? logoImage;
    if (schoolInfo.schoolLogoPath != null &&
        File(schoolInfo.schoolLogoPath!).existsSync()) {
      logoImage =
          pw.MemoryImage(File(schoolInfo.schoolLogoPath!).readAsBytesSync());
    }

    // ------------------- HEADER & FOOTER -------------------
    pw.Widget buildHeader() => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoImage != null)
              pw.Container(width: 80, height: 80, child: pw.Image(logoImage))
            else
              pw.Container(width: 80, height: 80, child: pw.Text("NO LOGO")),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(schoolInfo.schoolName!.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                  if (schoolInfo.schoolAddress != null)
                    pw.Text(schoolInfo.schoolAddress!.toUpperCase(),
                        textAlign: pw.TextAlign.right),
                  pw.Text("Email: ${schoolInfo.schoolEmail ?? ''}",
                      textAlign: pw.TextAlign.right),
                  pw.Text("Phone: ${schoolInfo.schoolPhoneNumber ?? ''}",
                      textAlign: pw.TextAlign.right),
                ],
              ),
            )
          ],
        );

    pw.Widget buildFooter(pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                "${schoolInfo.schoolName!.toLowerCase()} computer-generated document.",
                style: pw.TextStyle(fontSize: 8)),
            pw.Text("Page ${context.pageNumber} / ${context.pagesCount}",
                style: pw.TextStyle(fontSize: 8)),
          ],
        );

    // ------------------- GROUP BY STUDENT -------------------
    final Map<String, List<ProjectSaleTransaction>> grouped = {};
    for (final t in transactions) {
      grouped.putIfAbsent(t.studentId ?? 'Unknown', () => []).add(t);
    }

    double grandTotal = 0;

    for (final entry in grouped.entries) {
      final studentId = entry.key;
      final studentTxs = entry.value;
      final student =
          students.firstWhereOrNull((s) => s.studentIdNumber == studentId);

      double studentTotal = 0;

      final data = studentTxs.map((t) {
        final project =
            projects.firstWhereOrNull((p) => p.projectCode == t.projectCode);
        final item = items
            .firstWhereOrNull((i) => i.projectItemCode == t.projectItemCode);
        final outstanding = _calculateOutstanding(t, transactions);
        studentTotal += t.totalAmount;

        return [
          project?.name ?? '',
          item?.name ?? '',
          t.batchCode ?? '',
          DateFormat('yyyy-MM-dd').format(t.transactionDate),
          t.quantitySold.toString(),
          t.totalAmount.toStringAsFixed(2),
          outstanding.toStringAsFixed(2),
          t.paymentMethod ?? '',
          t.parentTransactionCode ?? '',
        ];
      }).toList();

      grandTotal += studentTotal;

      // Add subtotal
      data.add([
        '',
        '',
        '',
        '',
        'Subtotal',
        studentTotal.toStringAsFixed(2),
        '',
        '',
        '',
      ]);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => buildHeader(),
        footer: (context) => buildFooter(context),
        build: (context) => [
          pw.Center(
              child: pw.Text(
            "Project Transactions for ${student?.name ?? ''} ${student?.surname ?? ''} ${student?.class_ ?? ''}",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          )),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(color: PdfColors.black),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ));
    }

    // FINAL SUMMARY PAGE
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => buildHeader(),
      footer: (context) => buildFooter(context),
      build: (context) => [
        pw.Center(
            child: pw.Text("GRAND TOTAL",
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 12),
        pw.Text("Total Amount: \$${grandTotal.toStringAsFixed(2)}"),
      ],
    ));

    return pdf.save();
  }

// ------------------- SAVE PDF -------------------
  Future<void> savePDFToFile(
      BuildContext context, Uint8List bytes, String fileName) async {
    try {
      if (await Permission.storage.request().isGranted) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists())
          await downloadDir.create(recursive: true);

        String filePath = path.join(downloadDir.path, '$fileName.pdf');
        int index = 1;
        while (await File(filePath).exists()) {
          filePath = path.join(downloadDir.path, '$fileName-$index.pdf');
          index++;
        }

        final file = File(filePath);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF saved to $filePath')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _computeGroupedData(); // <-- ADD THIS

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Project Transactions')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_load),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final txs = _filtered; // filtered transactions
              final pdfBytes = await generateProjectsPDF(
                transactions: txs,
                students: _students,
                projects: _projects,
                items: _items,
              );

              final confirm =
                  await PDFPreviewUtil.showPDFPreview(context, pdfBytes);

              if (confirm) {
                await savePDFToFile(
                    context, pdfBytes, 'project_transactions_report');
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kPagePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: kMaxContentWidth, minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters adapt to screen size
                  _filtersResponsive(),

                  const SizedBox(height: 16),

                  // Summary cards wrap on small screens
                  Center(child: _summaryResponsive()),

                  const SizedBox(height: 16),

                  // Grouped results stack naturally
                  _groupedResults(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// ---------------- SUMMARY RESPONSIVE ----------------
  Widget _summaryResponsive() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 700;
        final cardWidth = isSmall ? double.infinity : 200.0;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _summaryCard("Total Sales", _computedTotalSales,
                Icons.shopping_cart, Colors.blue,
                width: cardWidth),
            _summaryCard("Total Initial Payments", _computedTotalSettlements,
                Icons.payments, Colors.green,
                width: cardWidth),
            _summaryCard("Total Settlements", _computedTotalPayments,
                Icons.account_balance_wallet, Colors.orange,
                width: cardWidth),
            _summaryCard(
                "Total Outstanding",
                _computedTotalOutstanding,
                Icons.warning,
                _computedTotalOutstanding > 0 ? Colors.red : Colors.green,
                width: cardWidth),
          ],
        );
      },
    );
  }

  Widget _studentFilter(double width) {
    return SizedBox(
      width: width,
      child: Autocomplete<Student>(
        displayStringForOption: (Student s) =>
            "${s.name} ${s.surname} • ${s.class_} • ${s.studentIdNumber}",
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Student>.empty();
          }
          final query = textEditingValue.text.toLowerCase();
          return _students.where((s) =>
              s.name.toLowerCase().contains(query) ||
              s.surname.toLowerCase().contains(query) ||
              (s.class_?.toLowerCase() ?? '').contains(query) ||
              s.studentIdNumber!.toLowerCase().contains(query));
        },
        onSelected: (Student selection) {
          setState(() => _student = selection);
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          // keep controller in sync with selected student
          if (_student != null) {
            controller.text =
                "${_student!.name} ${_student!.surname} • ${_student!.class_} • ${_student!.studentIdNumber}";
          }

          return TextField(
            controller: controller,
            focusNode: focusNode,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              labelText: 'Student',
              prefixIcon: const Icon(Icons.person),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kBorderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(kBorderRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final student = options.elementAt(index);
                  return ListTile(
                    title: Text("${student.name} ${student.surname}"),
                    subtitle: Text(
                        "Class: ${student.class_} | Reg#: ${student.studentIdNumber}"),
                    onTap: () => onSelected(student),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _multiSelect<T>({
    required String hint,
    required List<T> items,
    required List<T> selectedItems,
    required String Function(T) label,
    required void Function(List<T>) onSelectionChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () async {
          // 🔥 MOVE tempSelected HERE (outside StatefulBuilder)
          List<T> tempSelected = List<T>.from(selectedItems);

          final results = await showDialog<List<T>>(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: Text(hint),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: items.map((item) {
                          final isSelected = tempSelected.contains(item);

                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(label(item)),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  tempSelected.add(item);
                                } else {
                                  tempSelected.remove(item);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            tempSelected = List<T>.from(items);
                          });
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            tempSelected.clear();
                          });
                        },
                        child: const Text('Deselect All'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, tempSelected);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
            },
          );

          if (results != null) {
            setState(() {
              onSelectionChanged(results);
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: hint,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kBorderRadius),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedItems.isEmpty
                ? [
                    Text('None selected',
                        style: TextStyle(color: Colors.grey[600]))
                  ]
                : selectedItems
                    .map((e) => Chip(label: Text(label(e))))
                    .toList(),
          ),
        ),
      ),
    );
  }

  // ---------------- POLISHED FILTERS ----------------

  Widget _filtersResponsive() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final children = _filterFields(isDesktop);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.start,
                    children: children,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children
                        .map((w) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: w,
                            ))
                        .toList(),
                  ),
          ),
        );
      },
    );
  }

  List<Project> _selectedProjects = [];
  List<ProjectItem> _selectedItems = [];
  List<Widget> _filterFields(bool isDesktop) {
    final width = isDesktop ? 250.0 : double.infinity;

    return [
      _studentFilter(width), // <- new robust student filter

      // Multi-select Project
      _multiSelect<Project>(
        hint: 'Projects',
        items: _projects,
        selectedItems: _selectedProjects,
        label: (p) => p.name,
        onSelectionChanged: (selected) =>
            setState(() => _selectedProjects = selected),
        width: width,
      ),

      // Multi-select Items
      _multiSelect<ProjectItem>(
        hint: 'Items',
        items: _items,
        selectedItems: _selectedItems,
        label: (i) => i.name ?? '',
        onSelectionChanged: (selected) =>
            setState(() => _selectedItems = selected),
        width: width,
      ),

      CheckboxListTile(
        value: _showOutstandingOnly,
        onChanged: (v) => setState(() => _showOutstandingOnly = v ?? false),
        title: const Text('Outstanding Only'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.date_range),
        label: const Text('Date Range'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
        ),
        onPressed: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _dateRange = picked);
        },
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.red,
        ),
        onPressed: () {
          setState(() {
            _student = null;
            _project = null;
            _item = null;
            _paymentMethod = null;
            _currency = null;
            _financialType = null;
            _showOutstandingOnly = false;
            _dateRange = null;
            _searchCtrl.clear();
          });
        },
        child: const Text('Clear Filters'),
      ),
    ];
  }

  Widget _summaryCard(String title, double value, IconData icon, Color color,
      {double width = 200}) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(value.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- GROUPED RESULTS ----------------
  void _computeGroupedData() {
    final filtered = _filtered;

    _groupedTransactions = groupBy<ProjectSaleTransaction, String>(
      filtered,
      (t) => t.studentId ?? '',
    );

    _studentSummary = {};
    _hierarchicalData = {};

    double totalSales = 0;
    double totalPayments = 0;
    double totalSettlements = 0;
    double totalOutstanding = 0;

    for (final studentEntry in _groupedTransactions.entries) {
      final studentId = studentEntry.key ?? '';
      final txList = studentEntry.value;

      double studentSales = 0;
      double studentPaid = 0;

      final Map<String, List<ProjectSaleTransaction>> projectGrouped =
          groupBy<ProjectSaleTransaction, String>(
        txList,
        (t) => t.projectCode ?? '',
      );

      Map<String, dynamic> projectMap = {};

      for (final projectEntry in projectGrouped.entries) {
        final Map<String, List<ProjectSaleTransaction>> itemGrouped =
            groupBy<ProjectSaleTransaction, String>(
          projectEntry.value,
          (t) => t.projectItemCode ?? '',
        );

        Map<String, dynamic> itemMap = {};

        for (final itemEntry in itemGrouped.entries) {
          final Map<String, List<ProjectSaleTransaction>> batchGrouped =
              groupBy<ProjectSaleTransaction, String>(
            itemEntry.value,
            (t) => t.batchCode ?? '',
          );

          Map<String, dynamic> batchMap = {};

          for (final batchEntry in batchGrouped.entries) {
            final Map<String, List<ProjectSaleTransaction>> periodGrouped =
                groupBy<ProjectSaleTransaction, String>(
              batchEntry.value,
              (t) => t.paymentDatetransacted.toString() ?? "N/A",
            );
            batchMap[batchEntry.key ?? "N/A"] = periodGrouped;
          }

          itemMap[itemEntry.key ?? ""] = batchMap;
        }

        projectMap[projectEntry.key ?? ""] = itemMap;
      }

      for (final tx in txList) {
        if (tx.createsObligation) {
          studentSales += tx.totalAmount;

          final paidAmount = tx.totalAmount - _calculateOutstanding(tx, _all);

          studentPaid += paidAmount;

          totalSettlements += paidAmount;
          totalOutstanding += _calculateOutstanding(tx, _all);
        }

        if (tx.settlesObligation) {
          totalPayments += tx.amountPaid;
        }
      }

      totalSales += studentSales;

      _studentSummary[studentId] = {
        "sales": studentSales,
        "paid": studentPaid,
        "outstanding": studentSales - studentPaid,
      };

      _hierarchicalData[studentId] = projectMap;
    }

    _computedTotalSales = totalSales;
    _computedTotalPayments = totalPayments;
    _computedTotalSettlements = totalSettlements;
    _computedTotalOutstanding = totalOutstanding;
  }

  Widget _groupedResults() {
    if (_hierarchicalData.isEmpty) {
      return const Center(child: Text("No transactions found"));
    }

    final sortedStudents = _hierarchicalData.keys.toList()
      ..sort((a, b) {
        final studentA =
            _students.firstWhereOrNull((s) => s.studentIdNumber == a);
        final studentB =
            _students.firstWhereOrNull((s) => s.studentIdNumber == b);

        return (studentA?.surname ?? '')
            .toLowerCase()
            .compareTo((studentB?.surname ?? '').toLowerCase());
      });

    return Column(
      children: sortedStudents.map((studentId) {
        final student =
            _students.firstWhereOrNull((s) => s.studentIdNumber == studentId);

        final summary = _studentSummary[studentId] ?? {};
        final projects = _hierarchicalData[studentId] as Map<String, dynamic>;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            title: Text(
                "${student?.surname ?? ''}, ${student?.name ?? ''} • ${student?.class_ ?? ''}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                "Sales: ${(summary["sales"] ?? 0).toStringAsFixed(2)} | "
                "Paid: ${(summary["paid"] ?? 0).toStringAsFixed(2)} | "
                "Outstanding: ${(summary["outstanding"] ?? 0).toStringAsFixed(2)}"),
            children: projects.entries.map((projectEntry) {
              final project = _projects
                  .firstWhereOrNull((p) => p.projectCode == projectEntry.key);

              final items = projectEntry.value as Map<String, dynamic>;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project?.name ?? '',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...items.entries.map((itemEntry) {
                    final item = _items.firstWhereOrNull(
                        (i) => i.projectItemCode == itemEntry.key);
                    final batches = itemEntry.value as Map<String, dynamic>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item?.name ?? '',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ...batches.entries.map((batchEntry) {
                          final periods = batchEntry.value
                              as Map<String, List<ProjectSaleTransaction>>;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Batch: ${batchEntry.key}",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              ...periods.entries.expand((periodEntry) {
                                final sortedTx = periodEntry.value
                                  ..sort((a, b) => b.transactionDate
                                      .compareTo(a.transactionDate));
                                return sortedTx.map(_detailedRow);
                              }),
                            ],
                          );
                        }),
                      ],
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _detailedRow(ProjectSaleTransaction t) {
    final project =
        _projects.firstWhereOrNull((p) => p.projectCode == t.projectCode);
    final item =
        _items.firstWhereOrNull((i) => i.projectItemCode == t.projectItemCode);
    final outstanding = _calculateOutstanding(t, _all);

    return ListTile(
      title: Text("${project?.name ?? ''} • ${item?.name ?? ''}",
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
          "Qty: ${t.quantitySold} | Method: ${t.paymentMethod} | Date: ${DateFormat.yMd().format(t.transactionDate)}"),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Total: ${t.totalAmount.toStringAsFixed(2)}"),
          if (t.createsObligation)
            Text("Outstanding: ${outstanding.toStringAsFixed(2)}",
                style: TextStyle(
                    color: outstanding > 0 ? Colors.red : Colors.green)),
        ],
      ),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProjectSaleTransactionDetailScreen(transaction: t))),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }
}
