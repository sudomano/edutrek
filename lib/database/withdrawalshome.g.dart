// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'withdrawalshome.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WithdrawalAdapter extends TypeAdapter<Withdrawal> {
  @override
  final int typeId = 3;

  @override
  Withdrawal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Withdrawal(
      date: fields[0] as DateTime,
      amount: fields[1] as double,
      withdrawalPurpose: fields[2] as String,
      termId: fields[3] as String?,
      syncStatus: fields[4] as bool?,
      lastModified: fields[5] as DateTime?,
      operationType: fields[6] as String?,
      id: fields[7] as int?,
      withdrawalCode: fields[8] as String?,
      modifiedFields: (fields[9] as List?)?.cast<String>(),
      isDeleted: fields[10] as bool?,
      deletedAt: fields[11] as DateTime?,
      deletedBy: fields[12] as String?,
      deleteReason: fields[13] as String?,
      deletedSyncStatus: fields[14] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Withdrawal obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.withdrawalPurpose)
      ..writeByte(3)
      ..write(obj.termId)
      ..writeByte(4)
      ..write(obj.syncStatus)
      ..writeByte(5)
      ..write(obj.lastModified)
      ..writeByte(6)
      ..write(obj.operationType)
      ..writeByte(7)
      ..write(obj.id)
      ..writeByte(8)
      ..write(obj.withdrawalCode)
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
      other is WithdrawalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
