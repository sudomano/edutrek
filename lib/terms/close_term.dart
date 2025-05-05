import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/withdrawalshome.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/global files/global_term_id.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

class CloseTermScreen extends StatefulWidget {
  const CloseTermScreen({Key? key}) : super(key: key);

  @override
  _CloseTermScreenState createState() => _CloseTermScreenState();
}

class _CloseTermScreenState extends State<CloseTermScreen> {
  String message = '';

  @override
  void initState() {
    super.initState();
    _closeTerm();
  }

  Future<void> _closeTerm() async {
    var termsBox = await Hive.openBox<Terms>('terms');
    var termRecords = termsBox.values.where(
      (term) => term.status == 'Opened',
    );

    if (termRecords.isNotEmpty) {
      var currentTerm = termRecords.first;
      globalTermId = currentTerm.termId;

      // Open all required boxes
      var studentsBox = await _getBoxIfNotOpen<Student>('students');
      var classesBox = await _getBoxIfNotOpen<Classes>('classes');
      var paymentPurposesBox =
          await _getBoxIfNotOpen<PaymentPurpose>('payment_purposes');
      var teacherPaymentsPurposesBox =
          await _getBoxIfNotOpen<TeacherPaymentsPurposes>(
              'teacher_payments_purposes');
      var teachersBox = await _getBoxIfNotOpen<Teachers>('teachers');
      var schoolBox = await _getBoxIfNotOpen<School>('school');
      var withdrawalsBox = await _getBoxIfNotOpen<Withdrawal>('withdrawals');
      var studentPaymentsBox =
          await _getBoxIfNotOpen<StudentPayment>('student_payments');
      var teacherPaymentsBox =
          await _getBoxIfNotOpen<TeacherPayment>('teacher_payments');

      // List of all opened boxes
      var boxes = [
        studentsBox,
        classesBox,
        paymentPurposesBox,
        teacherPaymentsPurposesBox,
        teachersBox,
        schoolBox,
        withdrawalsBox,
        studentPaymentsBox,
        teacherPaymentsBox,
      ];

      // Save records in all boxes where termId matches
      for (var box in boxes) {
        await _saveRecordsInBox(box, globalTermId!);
      }

      // Update term status to closed
      currentTerm.status = 'Closed';
      currentTerm.isActive = true;
      currentTerm.endDate = DateTime.now();

      await currentTerm.save();

      setState(() {
        message = 'The term with ID $globalTermId was closed successfully!';
      });
    } else {
      setState(() {
        message = 'There is no opened-active term to close.';
      });
    }
  }

  Future<Box<T>> _getBoxIfNotOpen<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    } else {
      return await Hive.openBox<T>(boxName);
    }
  }

  Future<void> _saveRecordsInBox<T>(Box<T> box, String termId) async {
    for (var key in box.keys) {
      var item = box.get(key);

      if (item is TermIdHolder && item.termId == termId) {
        // Save or process the record as necessary
        await box.put(key, item);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Close Term'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

abstract class TermIdHolder {
  String get termId;
}
