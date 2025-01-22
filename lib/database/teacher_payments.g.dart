// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_payments.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeacherPaymentAdapter extends TypeAdapter<TeacherPayment> {
  @override
  final int typeId = 12;

  @override
  TeacherPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeacherPayment(
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
      associatedStaff: (fields[12] as List?)?.cast<String>(),
      receiptNumber: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TeacherPayment obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.associatedStaff)
      ..writeByte(13)
      ..write(obj.receiptNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
