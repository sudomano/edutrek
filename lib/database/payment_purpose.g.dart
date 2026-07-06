// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_purpose.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentPurposeAdapter extends TypeAdapter<PaymentPurpose> {
  @override
  final int typeId = 1;

  @override
  PaymentPurpose read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentPurpose(
      id: fields[0] as int,
      paymentPurpose: fields[1] as String,
      purposeAmount: fields[2] as double,
      termId: fields[3] as String?,
      syncStatus: fields[4] as bool?,
      lastModified: fields[5] as DateTime?,
      operationType: fields[6] as String?,
      associatedClasses: (fields[7] as List?)?.cast<String>(),
      purposeCode: fields[8] as String?,
      modifiedFields: (fields[9] as List?)?.cast<String>(),
      exceptions: (fields[10] as List?)?.cast<ExceptionalStudents>(),
      forNewcomersOnly: fields[11] as bool?,
      isDeleted: fields[12] as bool?,
      deletedAt: fields[13] as DateTime?,
      deletedBy: fields[14] as String?,
      deleteReason: fields[15] as String?,
      deletedSyncStatus: fields[16] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentPurpose obj) {
    writer
      ..writeByte(17)
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
      ..write(obj.associatedClasses)
      ..writeByte(8)
      ..write(obj.purposeCode)
      ..writeByte(9)
      ..write(obj.modifiedFields)
      ..writeByte(10)
      ..write(obj.exceptions)
      ..writeByte(11)
      ..write(obj.forNewcomersOnly)
      ..writeByte(12)
      ..write(obj.isDeleted)
      ..writeByte(13)
      ..write(obj.deletedAt)
      ..writeByte(14)
      ..write(obj.deletedBy)
      ..writeByte(15)
      ..write(obj.deleteReason)
      ..writeByte(16)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentPurposeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
