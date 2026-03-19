import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';

class ReceiptBuilder {
  static String buildParentSms({
    required School schoolInfo,
    required List<ProjectSaleTransaction> transactions,
    required Student? student,
    required String receiptCode,
    required DateTime receiptDate,
    required String currency,
    required Map<String, String> projectLookup,
    required Map<String, String> itemLookup,
  }) {
    final buffer = StringBuffer();

    double totalPaid = 0;
    double totalOutstanding = 0;

    for (final tx in transactions) {
      totalPaid += tx.amountPaid;
      totalOutstanding +=
          (tx.totalAmount - tx.amountPaid).clamp(0, double.infinity);
    }

    final schoolName = schoolInfo.schoolName ?? "SCHOOL";
    final parentName =
        student?.paymentStatus ?? "Parent"; // or your parentName field
    final studentName =
        "${student?.name ?? ''} ${student?.surname ?? ''}".trim();

    buffer.writeln("$schoolName");
    buffer.writeln("");
    buffer.writeln("Dear ${parentName.toUpperCase()},");
    buffer.writeln("");
    buffer.writeln("$studentName has paid for project items.");
    for (final tx in transactions) {
      final projectName = projectLookup[tx.projectCode] ?? 'Unknown Project';
      final itemName = itemLookup[tx.projectItemCode] ?? 'Unknown Item';

      totalPaid += tx.amountPaid;

      buffer.writeln("$projectName - $itemName");
      buffer.writeln("Paid: ${tx.amountPaid.toStringAsFixed(2)} $currency");
    }

    if (totalOutstanding > 0) {
      buffer.writeln(
          "Outstanding: ${totalOutstanding.toStringAsFixed(2)} $currency");
    }

    buffer.writeln("");
    buffer.writeln("Receipt #: $receiptCode");
    buffer
        .writeln("Date: ${DateFormat('yyyy-MM-dd HH:mm').format(receiptDate)}");
    buffer.writeln("");
    buffer.writeln("Thank you.");

    return buffer.toString().trim();
  }

  static String buildAdminSms({
    required School schoolInfo,
    required List<ProjectSaleTransaction> transactions,
    required Student? student,
    required String receiptCode,
    required DateTime receiptDate,
    required String cashier,
    required String currency,
    required Map<String, String> projectLookup,
    required Map<String, String> itemLookup,
  }) {
    final buffer = StringBuffer();

    double totalPaid = 0;

    final studentName =
        "${student?.name ?? ''} ${student?.surname ?? ''}".trim();

    buffer.writeln("${schoolInfo.schoolName}");
    buffer.writeln("PROJECT PAYMENT ALERT");
    buffer.writeln("");

    buffer.writeln("Student: $studentName");
    buffer.writeln("Class: ${student?.class_ ?? ''}");
    buffer.writeln("");

    for (final tx in transactions) {
      final projectName = projectLookup[tx.projectCode] ?? 'Unknown Project';
      final itemName = itemLookup[tx.projectItemCode] ?? 'Unknown Item';

      totalPaid += tx.amountPaid;

      buffer.writeln("$projectName - $itemName");
      buffer.writeln("Paid: ${tx.amountPaid.toStringAsFixed(2)} $currency");
    }

    buffer.writeln("");
    buffer.writeln("Receipt #: $receiptCode");
    buffer.writeln("Cashier: ${cashier.toUpperCase()}");
    buffer
        .writeln("Date: ${DateFormat('yyyy-MM-dd HH:mm').format(receiptDate)}");

    return buffer.toString().trim();
  }

  static List<LineText> fromJson(List<Map<String, dynamic>> json) {
    return json.map((e) {
      return LineText(
        type: e["type"],
        content: e["content"],
        align: e["align"],
        linefeed: e["linefeed"],
        fontZoom: e["fontZoom"],
        weight: e["weight"],
      );
    }).toList();
  }

  static List<LineText> buildReceipt({
    required School schoolInfo,
    required List<ProjectSaleTransaction> transactions,
    required Student? student,
    required String receiptCode,
    required DateTime receiptDate,
    required String cashier,
    required String currency,
    required double amountReceived,
    required Map<String, String> projectLookup,
    required Map<String, String> itemLookup,
  }) {
    final List<LineText> list = [];

    double totalExpected = 0;
    double totalPaid = 0;

    // ===============================
    // HEADER
    // ===============================
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'PROJECT RECEIPT',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      fontZoom: 1,
      weight: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolName?.toUpperCase() ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      fontZoom: 2,
      weight: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolAddress?.toUpperCase() ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolPhoneNumber ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: schoolInfo.schoolEmail ?? "",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // ---------------------- STUDENT INFO ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "RECEIVED FROM",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      weight: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content:
          "Name: ${student?.name.toUpperCase() ?? ""} ${student?.surname.toUpperCase() ?? ""}",
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "Class: ${student?.class_.toUpperCase() ?? ""}",
      align: LineText.ALIGN_LEFT,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "PAYMENTS FOR",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
      weight: 1,
    ));

    list.add(_divider());

    // ===============================
    // ITEM LINES
    // ===============================

    for (final tx in transactions) {
      totalExpected += tx.totalAmount;
      totalPaid += tx.amountPaid;
      final projectName = projectLookup[tx.projectCode] ?? 'Unknown Project';

      final itemName = itemLookup[tx.projectItemCode] ?? 'Unknown Item';

      final isSettlement = tx.settlesObligation == true;
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: projectName.toUpperCase(),
        align: LineText.ALIGN_CENTER,
        weight: 1,
        linefeed: 1,
      ));

      // 🔹 ITEM NAME
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: isSettlement
            ? 'ARREARS SETTLEMENT - $itemName'
            : itemName.toUpperCase(),
        linefeed: 1,
      ));

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Qty: ${tx.quantitySold}  }',
        linefeed: 1,
      ));

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Total: ${tx.totalAmount.toStringAsFixed(2)} $currency',
        linefeed: 1,
      ));

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Paid: ${tx.amountPaid.toStringAsFixed(2)} $currency',
        linefeed: 1,
      ));

      final outstanding =
          (tx.totalAmount - tx.amountPaid).clamp(0, double.infinity);

      if (outstanding > 0) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'Outstanding: ${outstanding.toStringAsFixed(2)} $currency',
          linefeed: 1,
        ));
      }

      if (isSettlement && tx.parentTransactionCode != null) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'Linked Sale: ${tx.parentTransactionCode}',
          linefeed: 1,
        ));
      }

      list.add(_divider());
    }

    // ===============================
    // TOTALS
    // ===============================

    final totalOutstanding =
        (totalExpected - totalPaid).clamp(0, double.infinity);

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TOTAL EXPECTED: ${totalExpected.toStringAsFixed(2)} $currency',
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TOTAL PAID: ${totalPaid.toStringAsFixed(2)} $currency',
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content:
          'TOTAL OUTSTANDING: ${totalOutstanding.toStringAsFixed(2)} $currency',
      weight: 1,
      linefeed: 1,
    ));

    list.add(_divider());

    // ===============================
    // PAYMENT SUMMARY
    // ===============================

    final paymentMethod =
        transactions.isNotEmpty ? transactions.first.paymentMethod : '';

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Payment Method: $paymentMethod',
      linefeed: 1,
    ));

    if (transactions.isNotEmpty) {
      final tx = transactions.first;

      if (tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'Reference: ${tx.referenceNumber}',
          linefeed: 1,
        ));
      }

      if (tx.phoneNumber != null) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'Phone: ${tx.phoneNumber}',
          linefeed: 1,
        ));
      }

      if (tx.accountNumber != null) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'Account: ${tx.accountNumber}',
          linefeed: 1,
        ));
      }

      if (tx.provider != null) {
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'Provider: ${tx.provider}',
          linefeed: 1,
        ));
      }
    }
    final change = amountReceived - totalPaid;
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content:
          'AMOUNT RECEIVED: ${amountReceived.toStringAsFixed(2)} $currency',
      weight: 1,
      linefeed: 1,
    ));

    if (change > 0) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'CHANGE: ${change.toStringAsFixed(2)} $currency',
        weight: 1,
        linefeed: 1,
      ));
    }

    list.add(_divider());
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // ---------------------- RECEIPT FOOTER ----------------------
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "RECEIVED ON",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content:
          "Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}",
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "PAYMENT CAPTURED BY",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "Cashier: ${cashier.toUpperCase()}",
      align: LineText.ALIGN_RIGHT,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '***********************************************',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: "RECEIPT NO.",
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: receiptCode,
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ));

    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Thank You!',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    return list;
  }

  static LineText _divider() {
    return LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      linefeed: 1,
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static List<Map<String, dynamic>> toJson(List<LineText> lines) {
    return lines.map((line) {
      return {
        "type": line.type,
        "content": line.content,
        "align": line.align,
        "linefeed": line.linefeed,
        "fontZoom": line.fontZoom,
        "weight": line.weight,
      };
    }).toList();
  }
}
