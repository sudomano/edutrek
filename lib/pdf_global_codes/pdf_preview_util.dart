import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class PDFPreviewUtil {
  // Function to display a preview of the generated PDF
  static Future<bool> showPDFPreview(
      BuildContext context, Uint8List pdfBytes) async {
    // Set orientation to portrait mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    bool? result = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('PDF Preview'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height *
                    0.7, // Set a fixed height
                child: PdfPreview(
                  build: (format) => pdfBytes,
                  allowSharing: true,
                  allowPrinting: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                /*TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save PDF'),
                ),*/
              ],
            );
          },
        ) ??
        false;

    // Reset orientation to allow both portrait and landscape after closing the PDF
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return result;
  }
}
