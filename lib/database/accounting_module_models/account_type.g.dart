// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 22;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as int?,
      accountType: fields[1] as String?,
      accountSubType: fields[2] as String?,
      accountName: fields[3] as String?,
      accountCode: fields[4] as String?,
      operationType: fields[5] as String?,
      syncStatus: fields[6] as bool,
      lastModified: fields[7] as DateTime?,
      isALiquidAccount: fields[8] as bool?,
      modifiedFields: (fields[9] as List?)?.cast<String>(),
      isDeleted: fields[10] as bool?,
      deletedAt: fields[11] as DateTime?,
      deletedBy: fields[12] as String?,
      deleteReason: fields[13] as String?,
      deletedSyncStatus: fields[14] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountType)
      ..writeByte(2)
      ..write(obj.accountSubType)
      ..writeByte(3)
      ..write(obj.accountName)
      ..writeByte(4)
      ..write(obj.accountCode)
      ..writeByte(5)
      ..write(obj.operationType)
      ..writeByte(6)
      ..write(obj.syncStatus)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.isALiquidAccount)
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
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
