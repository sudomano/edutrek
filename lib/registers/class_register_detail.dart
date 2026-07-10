import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/pdf_global_codes/pdf_preview_util.dart';
import 'package:zitf_system/registers/mark.dart';

/// Detailed, single-class register view reached by tapping a class on the
/// summary screen. Shows the register status for a specific date up top,
/// plus the full per-student present/absent history below, and lets a host
/// admin correct records or jump straight into marking/updating this class.
class ClassRegisterDetailScreen extends StatefulWidget {
  final String className;
  final List<Student> allStudents;
  final bool isHost;
  final bool isAdmin;
  final DateTime initialDate;

  const ClassRegisterDetailScreen({
    super.key,
    required this.className,
    required this.allStudents,
    required this.isHost,
    required this.isAdmin,
    required this.initialDate,
  });

  @override
  State<ClassRegisterDetailScreen> createState() =>
      _ClassRegisterDetailScreenState();
}

class _ClassRegisterDetailScreenState extends State<ClassRegisterDetailScreen> {
  late DateTime _checkDate;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _selectedStudentName;

  late List<Student> _classStudents;
  List<Student> _filteredStudents = [];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _checkDate = widget.initialDate;
    _classStudents = widget.allStudents
        .where((s) => s.class_.toLowerCase() == widget.className.toLowerCase())
        .toList();
    _applyFilters();
  }

  void _applyFilters() {
    List<Student> filtered = List.from(_classStudents);

    if (_selectedStartDate != null && _selectedEndDate != null) {
      final startDate = _selectedStartDate!;
      final endDate = _selectedEndDate!.add(const Duration(days: 1));
      filtered = filtered.where((student) {
        final allDates = [...student.presentDates, ...student.absentDates];
        return allDates
            .any((date) => date.isAfter(startDate) && date.isBefore(endDate));
      }).toList();
    }

    if (_selectedStudentName != null && _selectedStudentName!.isNotEmpty) {
      final query = _selectedStudentName!.toLowerCase();
      filtered = filtered.where((student) {
        final fullName = '${student.name} ${student.surname}'.toLowerCase();
        return fullName.contains(query);
      }).toList();
    }

    filtered.sort((a, b) => a.surname.compareTo(b.surname));

    setState(() => _filteredStudents = filtered);
  }

  void _resetFilters() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
      _selectedStudentName = null;
    });
    _applyFilters();
  }

  void _deleteStudentAttendanceHistory(Student student) {
    if (!widget.isHost || !widget.isAdmin) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student Attendance'),
        content: Text(
            'Are you sure you want to delete all attendance records for ${student.name} ${student.surname}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              student.presentDates.clear();
              student.absentDates.clear();
              student.save();
              _applyFilters();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ Deleted attendance for ${student.name} ${student.surname}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteAllAttendanceForClass() {
    if (!widget.isHost || !widget.isAdmin) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Attendance'),
        content: Text(
            'Are you sure you want to delete all attendance records for class "${widget.className}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (var student in _classStudents) {
                student.presentDates.clear();
                student.absentDates.clear();
                student.save();
              }
              _applyFilters();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ Deleted attendance for ${_classStudents.length} students in ${widget.className}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showDetailedAttendance(Student student, bool isPresent) {
    final dates = isPresent ? student.presentDates : student.absentDates;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isPresent ? '✅ Present Dates' : '❌ Absent Dates',
          style: TextStyle(color: isPresent ? Colors.green : Colors.red),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: min(400.0, dates.length * 60.0 + 20.0),
          child: dates.isEmpty
              ? const Center(child: Text('No dates recorded'))
              : ListView.builder(
                  itemCount: dates.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: Icon(
                      isPresent ? Icons.check_circle : Icons.cancel,
                      color: isPresent ? Colors.green : Colors.red,
                    ),
                    title: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(dates[index])),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final headers = [
      'Student Name',
      'Surname',
      'Total Days',
      'Present',
      'Absent',
      'Attendance %'
    ];

    final data = _filteredStudents.map((student) {
      final totalDays =
          student.presentDates.length + student.absentDates.length;
      final presentDays = student.presentDates.length;
      final absentDays = student.absentDates.length;
      final attendancePercentage =
          totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

      return [
        student.name,
        student.surname,
        '$totalDays',
        '$presentDays',
        '$absentDays',
        '${attendancePercentage.toStringAsFixed(2)}%',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Text('${widget.className} - Attendance Report',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerStyle:
                pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.black),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final presentToday = _classStudents
        .where((s) => s.presentDates.any((d) => _isSameDay(d, _checkDate)))
        .toList();
    final absentToday = _classStudents
        .where((s) => s.absentDates.any((d) => _isSameDay(d, _checkDate)))
        .toList();
    final wasMarkedOnCheckDate =
        presentToday.isNotEmpty || absentToday.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar, color: Colors.white),
            tooltip: 'Mark / Update Register',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MarkAttendanceScreen(initialClassName: widget.className),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: _filteredStudents.isEmpty
                ? null
                : () async {
                    final pdfBytes = await _generatePdf();
                    final confirmSave =
                        await PDFPreviewUtil.showPDFPreview(context, pdfBytes);
                    if (confirmSave) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'PDF preview closed - use share/print from the preview to save.')),
                      );
                    }
                  },
          ),
          if (widget.isHost && widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete All Attendance for Class',
              onPressed: _deleteAllAttendanceForClass,
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Register status for a specific date
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: wasMarkedOnCheckDate
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: wasMarkedOnCheckDate
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      wasMarkedOnCheckDate
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: wasMarkedOnCheckDate
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        wasMarkedOnCheckDate
                            ? '✅ Marked on ${DateFormat('EEEE, d MMMM yyyy').format(_checkDate)} - ${presentToday.length} present, ${absentToday.length} absent'
                            : '❌ Not marked on ${DateFormat('EEEE, d MMMM yyyy').format(_checkDate)}',
                        style: TextStyle(
                          color: wasMarkedOnCheckDate
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _checkDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() => _checkDate = picked);
                        }
                      },
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ✅ Filter row (name search + date range for the detail table)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by student name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _selectedStudentName = value;
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Reset Filters',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_filteredStudents.isEmpty)
                const Expanded(
                  child: Center(child: Text('No students found.')),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.resolveWith(
                          (states) => Colors.grey.shade200,
                        ),
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Surname')),
                          DataColumn(label: Text('Total Days')),
                          DataColumn(label: Text('Present')),
                          DataColumn(label: Text('Absent')),
                          DataColumn(label: Text('Attendance %')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredStudents.map((student) {
                          final totalDays = student.presentDates.length +
                              student.absentDates.length;
                          final presentDays = student.presentDates.length;
                          final absentDays = student.absentDates.length;
                          final attendancePercentage = totalDays > 0
                              ? (presentDays / totalDays) * 100
                              : 0.0;

                          return DataRow(cells: [
                            DataCell(Text(student.name)),
                            DataCell(Text(student.surname)),
                            DataCell(Text('$totalDays')),
                            DataCell(
                              InkWell(
                                onTap: () =>
                                    _showDetailedAttendance(student, true),
                                child: Text(
                                  '$presentDays',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () =>
                                    _showDetailedAttendance(student, false),
                                child: Text(
                                  '$absentDays',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${attendancePercentage.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: attendancePercentage >= 80
                                      ? Colors.green
                                      : attendancePercentage >= 60
                                          ? Colors.orange
                                          : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              widget.isHost && widget.isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      onPressed: () =>
                                          _deleteStudentAttendanceHistory(
                                              student),
                                      tooltip: 'Delete Attendance History',
                                    )
                                  : const SizedBox(),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
