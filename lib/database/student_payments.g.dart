// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_payments.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentPaymentAdapter extends TypeAdapter<StudentPayment> {
  @override
  final int typeId = 2;

  @override
  StudentPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentPayment(
      studentName: fields[0] as String,
      studentSurname: fields[1] as String,
      studentClass: fields[2] as String,
      phoneNumber: fields[3] as String,
      paymentPurpose: fields[4] as String,
      amountToPay: fields[5] as double,
      paymentDate: fields[6] as DateTime,
      termId: fields[7] as String?,
      syncStatus: fields[8] as bool?,
      lastModified: fields[9] as DateTime?,
      operationType: fields[10] as String?,
      id: fields[11] as int?,
      receiptNumber: fields[13] as String?,
      studentRegNumber: fields[12] as String?,
      modifiedFields: (fields[14] as List?)?.cast<String>(),
      username: fields[15] as String?,
      role: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StudentPayment obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.studentName)
      ..writeByte(1)
      ..write(obj.studentSurname)
      ..writeByte(2)
      ..write(obj.studentClass)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.paymentPurpose)
      ..writeByte(5)
      ..write(obj.amountToPay)
      ..writeByte(6)
      ..write(obj.paymentDate)
      ..writeByte(7)
      ..write(obj.termId)
      ..writeByte(8)
      ..write(obj.syncStatus)
      ..writeByte(9)
      ..write(obj.lastModified)
      ..writeByte(10)
      ..write(obj.operationType)
      ..writeByte(11)
      ..write(obj.id)
      ..writeByte(12)
      ..write(obj.studentRegNumber)
      ..writeByte(13)
      ..write(obj.receiptNumber)
      ..writeByte(14)
      ..write(obj.modifiedFields)
      ..writeByte(15)
      ..write(obj.username)
      ..writeByte(16)
      ..write(obj.role);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
