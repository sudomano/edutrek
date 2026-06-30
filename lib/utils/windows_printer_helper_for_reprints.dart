// lib/utils/windows_printer_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class WindowsPrinterHelper {
  // Get list of available Windows printers
  static Future<List<String>> getAvailablePrinters() async {
    try {
      final printers = await Printing.listPrinters();
      final availablePrinters =
          printers.where((p) => p.isAvailable).map((p) => p.name).toList();

      return availablePrinters;
    } catch (e) {
      debugPrint("❌ Error getting printers: $e");
      return [];
    }
  }

  // 🆕 Print LineText objects directly (for receipt history and reprint)
  static Future<void> printLineTextToWindowsPrinter(
    String printerName,
    List<LineText> lines,
  ) async {
    // Generate plain text from LineText objects
    StringBuffer textBuffer = StringBuffer();

    for (var line in lines) {
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

    await printToWindowsPrinter(printerName, bytes);
  }

  // 🆕 Print raw text to Windows printer
  static Future<void> printTextToWindowsPrinter(
    String printerName,
    String text,
  ) async {
    final bytes = utf8.encode(text);
    await printToWindowsPrinter(printerName, bytes);
  }

  // Print ESC/POS bytes to Windows printer
  static Future<void> printToWindowsPrinter(
    String printerName,
    List<int> bytes,
  ) async {
    try {
      // Get the printer object
      final printers = await Printing.listPrinters();
      final selectedPrinter = printers.firstWhere(
        (p) => p.name == printerName,
        orElse: () => throw Exception('Printer not found: $printerName'),
      );

      if (!selectedPrinter.isAvailable) {
        throw Exception('Printer is not available');
      }

      // For Windows, create a PDF wrapper with the content
      await _printAsPdf(selectedPrinter, bytes);
    } catch (e) {
      debugPrint("   ❌ Error printing: $e");
      rethrow;
    }
  }

  // Print as PDF (fallback method that works on all printers)
  static Future<void> _printAsPdf(Printer printer, List<int> bytes) async {
    // Create a PDF document that displays the receipt content
    final pdf = pw.Document();

    // Convert bytes to readable text for PDF
    final receiptText = _extractTextFromBytes(bytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 10),
              ...receiptText.split('\n').map((line) {
                return pw.Text(
                  line,
                  style: pw.TextStyle(fontSize: 10),
                );
              }).toList(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Printed: ${DateTime.now()}',
                style: pw.TextStyle(fontSize: 8),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    await Printing.directPrintPdf(
      printer: printer,
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // Extract text from bytes
  static String _extractTextFromBytes(List<int> bytes) {
    String result = '';
    for (var byte in bytes) {
      if (byte >= 32 && byte <= 126) {
        result += String.fromCharCode(byte);
      } else if (byte == 10) {
        result += '\n';
      }
    }
    return result;
  }

  // Test printer connectivity
  static Future<bool> testConnectivity(String printerName) async {
    try {
      final printers = await Printing.listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name == printerName,
        orElse: () => throw Exception('Printer not found'),
      );

      final isAvailable = printer.isAvailable;

      return isAvailable;
    } catch (e) {
      debugPrint("   ❌ Connectivity test failed: $e");
      return false;
    }
  }

  // Print test page
  static Future<void> printTestPage(String printerName) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Test Print',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Printer: $printerName'),
                pw.Text('Date: ${DateTime.now()}'),
                pw.SizedBox(height: 20),
                pw.Text(
                    'If you can read this, your printer is working correctly!'),
                pw.SizedBox(height: 20),
                pw.Text(
                    'This is a test page from the School Management System.'),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final printers = await Printing.listPrinters();
    final printer = printers.firstWhere((p) => p.name == printerName);

    await Printing.directPrintPdf(
      printer: printer,
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Test_Page_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
