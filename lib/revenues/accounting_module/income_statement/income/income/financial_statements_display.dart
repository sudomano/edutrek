import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'financial_item_entry_form.dart';

class FinancialStatementsDisplay extends StatefulWidget {
  const FinancialStatementsDisplay({super.key});

  @override
  _FinancialStatementsDisplayState createState() =>
      _FinancialStatementsDisplayState();
}

class _FinancialStatementsDisplayState
    extends State<FinancialStatementsDisplay> {
  final _financialBox = Hive.box('financial_box');
  List<List<Map<String, dynamic>>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history =
          _financialBox.values.cast<List<Map<String, dynamic>>>().toList();
    });
  }

  void _editEntry(List<Map<String, dynamic>> entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialItemEntryForm(
          navigateToHistory: () {
            Navigator.pop(context);
            _loadHistory();
          },
          initialData: {
            'date': entry.first['timestamp'],
            'items': {
              'INCOME': {},
              'EXPENDITURE': {},
            },
            'totalIncome': entry
                .where((item) => item['category'] == 'INCOME')
                .fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
            'totalExpenditure': entry
                .where((item) => item['category'] == 'EXPENDITURE')
                .fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)),
          },
        ),
      ),
    ).then((_) => _loadHistory());
  }

  void _shareEntry(List<Map<String, dynamic>> entry) {
    String content = 'Statement of Income and Expenditure\n\n';
    for (var item in entry) {
      content +=
          'Category: ${item['category']}, Subcategory: ${item['subcategory']}, Description: ${item['description']}, Amount: \$${item['amount']}\n';
    }
    content +=
        '\nTotal Income: \$${entry.where((item) => item['category'] == 'INCOME').fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0))}\n';
    content +=
        'Total Expenditure: \$${entry.where((item) => item['category'] == 'EXPENDITURE').fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0))}';

    Share.share(content);
  }

  void _printEntry(List<Map<String, dynamic>> entry) async {
    final pdf = pw.Document();

    double totalIncome = entry
        .where((item) => item['category'] == 'INCOME')
        .fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    double totalExpenditure = entry
        .where((item) => item['category'] == 'EXPENDITURE')
        .fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    double surplusOrDeficit = totalIncome - totalExpenditure;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Statement of Income and Expenditure',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              ...entry.map((item) {
                return pw.Text(
                  '${item['category']} > ${item['subcategory']} - ${item['description']}: \$${item['amount']}',
                  style: pw.TextStyle(fontSize: 18),
                );
              }),
              pw.SizedBox(height: 20),
              pw.Text('Total Income: \$${totalIncome.toStringAsFixed(2)}'),
              pw.Text(
                  'Total Expenditure: \$${totalExpenditure.toStringAsFixed(2)}'),
              pw.Text(
                'Surplus/Deficit: \$${surplusOrDeficit.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: surplusOrDeficit >= 0
                      ? PdfColor(0, 0.5, 0)
                      : PdfColor(0.5, 0, 0),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Statements History'),
      ),
      body: ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final entry = _history[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text('Statement Date: ${entry.first['timestamp']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Total Income: \$${entry.where((item) => item['category'] == 'INCOME').fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)).toStringAsFixed(2)}'),
                  Text(
                      'Total Expenditure: \$${entry.where((item) => item['category'] == 'EXPENDITURE').fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0)).toStringAsFixed(2)}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _editEntry(entry)),
                  IconButton(
                      icon: Icon(Icons.share),
                      onPressed: () => _shareEntry(entry)),
                  IconButton(
                      icon: Icon(Icons.print),
                      onPressed: () => _printEntry(entry)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
