// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_payment_purpose.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeacherPaymentsPurposesAdapter
    extends TypeAdapter<TeacherPaymentsPurposes> {
  @override
  final int typeId = 11;

  @override
  TeacherPaymentsPurposes read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeacherPaymentsPurposes(
      id: fields[0] as int,
      paymentPurpose: fields[1] as String,
      purposeAmount: fields[2] as double,
      termId: fields[3] as String?,
      syncStatus: fields[4] as bool?,
      lastModified: fields[5] as DateTime?,
      operationType: fields[6] as String?,
      associatedStaff: (fields[7] as List?)?.cast<String>(),
      purposeCode: fields[8] as String?,
      modifiedFields: (fields[9] as List?)?.cast<String>(),
      isDeleted: fields[10] as bool?,
      deletedAt: fields[11] as DateTime?,
      deletedBy: fields[12] as String?,
      deleteReason: fields[13] as String?,
      deletedSyncStatus: fields[14] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, TeacherPaymentsPurposes obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.paymentPurpose)
      ..writeByte(2)
      ..write(obj.purposeAmount)
      ..writeByte(3)
      ..write(obj.termId)
      ..writeByte(4)
      ..write(obj.syncStatus)
      ..writeByte(5)
      ..write(obj.lastModified)
      ..writeByte(6)
      ..write(obj.operationType)
      ..writeByte(7)
      ..write(obj.associatedStaff)
      ..writeByte(8)
      ..write(obj.purposeCode)
      ..writeByte(9)
      ..write(obj.modifiedFields)
      ..writeByte(10)
      ..write(obj.isDeleted)
      ..writeByte(11)
      ..write(obj.deletedAt)
      ..writeByte(12)
      ..write(obj.deletedBy)
      ..writeByte(13)
      ..write(obj.deleteReason)
      ..writeByte(14)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherPaymentsPurposesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
