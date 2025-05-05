// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_student_payment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectStudentPaymentAdapter extends TypeAdapter<ProjectStudentPayment> {
  @override
  final int typeId = 27;

  @override
  ProjectStudentPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectStudentPayment(
      projectStudentPaymentCode: fields[0] as String,
      studentId: fields[1] as String,
      projectCode: fields[2] as String,
      itemId: fields[3] as String,
      amountPaid: fields[4] as double,
      balance: fields[5] as double,
      syncStatus: fields[6] as bool?,
      lastModified: fields[7] as DateTime?,
      operationType: fields[8] as String?,
      modifiedFields: (fields[9] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProjectStudentPayment obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.projectStudentPaymentCode)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.projectCode)
      ..writeByte(3)
      ..write(obj.itemId)
      ..writeByte(4)
      ..write(obj.amountPaid)
      ..writeByte(5)
      ..write(obj.balance)
      ..writeByte(6)
      ..write(obj.syncStatus)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.operationType)
      ..writeByte(9)
      ..write(obj.modifiedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectStudentPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
