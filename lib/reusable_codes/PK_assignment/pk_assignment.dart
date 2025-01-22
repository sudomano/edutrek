import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/classes.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/school_info.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/teacher_payment_purpose.dart';
import 'package:zitf_system/database/teacher_payments.dart';
import 'package:zitf_system/database/teachers.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/database/withdrawalshome.dart';

final uuid = Uuid();

Future<void> assignPrimaryKeysToModels() async {
  // Open all necessary boxes
  final teacherPaymentsPurposesBox =
      await Hive.openBox<TeacherPaymentsPurposes>('teacher_payments_purposes');
  final paymentPurposeBox =
      await Hive.openBox<PaymentPurpose>('payment_purposes');
  final classesBox = await Hive.openBox<Classes>('classes');
  final studentPaymentsBox =
      await Hive.openBox<StudentPayment>('student_payments');
  final teacherPaymentsBox =
      await Hive.openBox<TeacherPayment>('teacher_payments');
  final studentsBox = await Hive.openBox<Student>('students');
  final withdrawalsBox = await Hive.openBox<Withdrawal>('withdrawals');
  final usersBox = await Hive.openBox<User>('users');
  final teachersBox = await Hive.openBox<Teachers>('teachers');
  final schoolBox = await Hive.openBox<School>('school');
  final termsBox = await Hive.openBox<Terms>('terms');

  // Process each box
  await _processBox(teacherPaymentsPurposesBox, 'purposeCode');
  await _processBox(paymentPurposeBox, 'purposeCode');
  await _processBox(classesBox, 'classCode');
  await _processBox(studentPaymentsBox, 'receiptNumber');
  await _processBox(teacherPaymentsBox, 'receiptNumber');
  await _processBox(studentsBox, 'studentIdNumber');
  await _processBox(withdrawalsBox, 'withdrawalCode');
  await _processBox(usersBox, 'userCode');
  await _processBox(teachersBox, 'IdNumber');
  await _processBox(schoolBox, 'schoolCode');
  await _processBox(termsBox, 'termId');
}

Future<void> _processBox<T>(Box<T> box, String primaryKeyField) async {
  for (var key in box.keys) {
    final record = box.get(key);

    if (record != null) {
      final pkValue = _getPrimaryKeyValue(record, primaryKeyField);
      if (pkValue == null || pkValue.isEmpty) {
        // Generate a new UUID for the primary key
        final newPkValue = uuid.v4();

        // Update the record with the new primary key
        final updatedRecord =
            _setPrimaryKeyValue(record, primaryKeyField, newPkValue);
        await box.put(key, updatedRecord);
        print('Primary key updated for key: $key, new value: $newPkValue');
      }
    }
  }
}

dynamic _getPrimaryKeyValue(dynamic record, String primaryKeyField) {
  // Access primary key value based on model type
  if (record is TeacherPaymentsPurposes) {
    return record.purposeCode;
  } else if (record is PaymentPurpose) {
    return record.purposeCode;
  } else if (record is Classes) {
    return record.classCode;
  } else if (record is StudentPayment) {
    return record.receiptNumber;
  } else if (record is TeacherPayment) {
    return record.receiptNumber;
  } else if (record is Student) {
    return record.studentIdNumber;
  } else if (record is Withdrawal) {
    return record.withdrawalCode;
  } else if (record is User) {
    return record.userCode;
  } else if (record is Teachers) {
    return record.IdNumber;
  } else if (record is School) {
    return record.schoolCode;
  } else if (record is Terms) {
    return record.termId;
  }
  return null;
}

dynamic _setPrimaryKeyValue(
    dynamic record, String primaryKeyField, String newValue) {
  // Update primary key value based on model type
  if (record is TeacherPaymentsPurposes) {
    return record.copyWith(purposeCode: newValue);
  } else if (record is PaymentPurpose) {
    return record.copyWith(purposeCode: newValue);
  } else if (record is Classes) {
    return record.copyWith(classCode: newValue);
  } else if (record is StudentPayment) {
    return record.copyWith(receiptNumber: newValue);
  } else if (record is TeacherPayment) {
    return record.copyWith(receiptNumber: newValue);
  } else if (record is Student) {
    return record.copyWith(studentIdNumber: newValue);
  } else if (record is Withdrawal) {
    return record.copyWith(withdrawalCode: newValue);
  } else if (record is User) {
    return record.copyWith(userCode: newValue);
  } else if (record is Teachers) {
    return record.copyWith(IdNumber: newValue);
  } else if (record is School) {
    return record.copyWith(schoolCode: newValue);
  } else if (record is Terms) {
    return record.copyWith(termId: newValue);
  }
  return record;
}
