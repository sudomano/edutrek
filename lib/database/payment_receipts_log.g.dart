// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_receipts_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentLogAdapter extends TypeAdapter<PaymentLog> {
  @override
  final int typeId = 55;

  @override
  PaymentLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentLog(
      receiptNumber: fields[0] as int,
      studentName: fields[1] as String,
      className: fields[2] as String,
      dateTime: fields[3] as String,
      receiptLines: (fields[4] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      parentName: fields[5] as String?,
      parentPhone: fields[6] as String?,
      isReprint: fields[7] as bool?,
      originalReceiptNumber: fields[8] as String?,
      reprintCount: fields[9] as int?,
      syncStatus: fields[10] as bool?,
      lastModified: fields[11] as DateTime?,
      operationType: fields[12] as String?,
      logId: fields[13] as String?,
      modifiedFields: (fields[14] as List?)?.cast<String>(),
      isDeleted: fields[15] as bool?,
      deletedAt: fields[16] as DateTime?,
      deletedBy: fields[17] as String?,
      deleteReason: fields[18] as String?,
      deletedSyncStatus: fields[19] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentLog obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.receiptNumber)
      ..writeByte(1)
      ..write(obj.studentName)
      ..writeByte(2)
      ..write(obj.className)
      ..writeByte(3)
      ..write(obj.dateTime)
      ..writeByte(4)
      ..write(obj.receiptLines)
      ..writeByte(5)
      ..write(obj.parentName)
      ..writeByte(6)
      ..write(obj.parentPhone)
      ..writeByte(7)
      ..write(obj.isReprint)
      ..writeByte(8)
      ..write(obj.originalReceiptNumber)
      ..writeByte(9)
      ..write(obj.reprintCount)
      ..writeByte(10)
      ..write(obj.syncStatus)
      ..writeByte(11)
      ..write(obj.lastModified)
      ..writeByte(12)
      ..write(obj.operationType)
      ..writeByte(13)
      ..write(obj.logId)
      ..writeByte(14)
      ..write(obj.modifiedFields)
      ..writeByte(15)
      ..write(obj.isDeleted)
      ..writeByte(16)
      ..write(obj.deletedAt)
      ..writeByte(17)
      ..write(obj.deletedBy)
      ..writeByte(18)
      ..write(obj.deleteReason)
      ..writeByte(19)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
