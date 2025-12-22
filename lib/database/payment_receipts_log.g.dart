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
    );
  }

  @override
  void write(BinaryWriter writer, PaymentLog obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.parentPhone);
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
