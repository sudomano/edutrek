// lib/utils/windows_printer_helper.dart
import 'dart:io';
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

  // Print ESC/POS bytes to Windows printer
  static Future<void> printToWindowsPrinter(
    String printerName,
    List<int> escposBytes,
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

      // For Windows, we need to send the ESC/POS bytes directly
      // Since directPrintPdf expects PDF, we'll create a simple PDF wrapper
      // that contains the ESC/POS commands as a note, but for actual ESC/POS
      // printers, you may need to use a different approach.

      // Option 1: Create a PDF receipt (fallback - works on all printers)
      await _printAsPdf(selectedPrinter, escposBytes);

      // Option 2: For true ESC/POS support on Windows, uncomment below
      // Requires dart:ffi and win32 package
      // await _printRawBytes(selectedPrinter.name, escposBytes);
    } catch (e) {
      debugPrint("   ❌ Error printing: $e");
      rethrow;
    }
  }

  // Print as PDF (fallback method that works on all printers)
  static Future<void> _printAsPdf(
      Printer printer, List<int> escposBytes) async {
    // Create a PDF document that displays the receipt content
    final pdf = pw.Document();

    // Convert ESC/POS bytes to readable text for PDF
    final receiptText = _extractTextFromEscpos(escposBytes);

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

  // Extract text from ESC/POS bytes (simple implementation)
  static String _extractTextFromEscpos(List<int> bytes) {
    // ESC/POS commands are in the range 0x00-0x1F
    // Printable characters are 0x20-0x7E
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

  // Raw ESC/POS printing using Windows API (advanced)
  // This requires win32 package and platform channel implementation
  static Future<void> _printRawBytes(
      String printerName, List<int> bytes) async {
    // This would require a platform channel implementation
    // For now, we'll use the PDF fallback
    throw UnimplementedError(
        'Raw ESC/POS printing on Windows requires platform channel implementation.\n'
        'Falling back to PDF printing mode.');
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
