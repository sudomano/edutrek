// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reprint_project_receipt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReceiptSnapshotAdapter extends TypeAdapter<ReceiptSnapshot> {
  @override
  final int typeId = 79;

  @override
  ReceiptSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReceiptSnapshot(
      receiptCode: fields[0] as String,
      receiptDate: fields[1] as DateTime,
      cashier: fields[2] as String,
      totalExpected: fields[3] as double,
      totalPaid: fields[4] as double,
      amountReceived: fields[5] as double,
      change: fields[6] as double,
      currency: fields[7] as String,
      receiptLinesJson: (fields[8] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      isReprint: fields[9] as bool,
      studentName: fields[10] as String,
      studentClass: fields[11] as String?,
      syncStatus: fields[12] as bool?,
      lastModified: fields[13] as DateTime?,
      operationType: fields[14] as String?,
      modifiedFields: (fields[15] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReceiptSnapshot obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.receiptCode)
      ..writeByte(1)
      ..write(obj.receiptDate)
      ..writeByte(2)
      ..write(obj.cashier)
      ..writeByte(3)
      ..write(obj.totalExpected)
      ..writeByte(4)
      ..write(obj.totalPaid)
      ..writeByte(5)
      ..write(obj.amountReceived)
      ..writeByte(6)
      ..write(obj.change)
      ..writeByte(7)
      ..write(obj.currency)
      ..writeByte(8)
      ..write(obj.receiptLinesJson)
      ..writeByte(9)
      ..write(obj.isReprint)
      ..writeByte(10)
      ..write(obj.studentName)
      ..writeByte(11)
      ..write(obj.studentClass)
      ..writeByte(12)
      ..write(obj.syncStatus)
      ..writeByte(13)
      ..write(obj.lastModified)
      ..writeByte(14)
      ..write(obj.operationType)
      ..writeByte(15)
      ..write(obj.modifiedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
