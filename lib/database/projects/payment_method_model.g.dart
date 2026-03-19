// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_method_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentMethodAdapter extends TypeAdapter<PaymentMethod> {
  @override
  final int typeId = 70;

  @override
  PaymentMethod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentMethod(
      paymentMethodCode: fields[0] as String?,
      methodType: fields[1] as String?,
      amount: fields[2] as double?,
      currency: fields[3] as String?,
      provider: fields[4] as String?,
      reference: fields[5] as String?,
      phoneNumber: fields[6] as String?,
      accountNumber: fields[7] as String?,
      accountName: fields[8] as String?,
      paymentDate: fields[9] as DateTime?,
      isReversed: fields[10] as bool?,
      lastModified: fields[11] as DateTime?,
      operationType: fields[12] as String?,
      syncStatus: fields[13] as bool?,
      modifiedFields: (fields[14] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, PaymentMethod obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.paymentMethodCode)
      ..writeByte(1)
      ..write(obj.methodType)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.provider)
      ..writeByte(5)
      ..write(obj.reference)
      ..writeByte(6)
      ..write(obj.phoneNumber)
      ..writeByte(7)
      ..write(obj.accountNumber)
      ..writeByte(8)
      ..write(obj.accountName)
      ..writeByte(9)
      ..write(obj.paymentDate)
      ..writeByte(10)
      ..write(obj.isReversed)
      ..writeByte(11)
      ..write(obj.lastModified)
      ..writeByte(12)
      ..write(obj.operationType)
      ..writeByte(13)
      ..write(obj.syncStatus)
      ..writeByte(14)
      ..write(obj.modifiedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
