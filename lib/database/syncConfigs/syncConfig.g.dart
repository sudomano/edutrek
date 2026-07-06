// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'syncConfig.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DomainRecordAdapter extends TypeAdapter<DomainRecord> {
  @override
  final int typeId = 39;

  @override
  DomainRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DomainRecord(
      domainName: fields[0] as String?,
      areDomainsActive: fields[1] as bool?,
      syncStatus: fields[2] as bool?,
      operationType: fields[3] as String?,
      lastModified: fields[4] as DateTime?,
      modifiedFields: (fields[5] as List?)?.cast<String>(),
      isDeleted: fields[6] as bool?,
      deletedAt: fields[7] as DateTime?,
      deletedBy: fields[8] as String?,
      deleteReason: fields[9] as String?,
      deletedSyncStatus: fields[10] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, DomainRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.domainName)
      ..writeByte(1)
      ..write(obj.areDomainsActive)
      ..writeByte(2)
      ..write(obj.syncStatus)
      ..writeByte(3)
      ..write(obj.operationType)
      ..writeByte(4)
      ..write(obj.lastModified)
      ..writeByte(5)
      ..write(obj.modifiedFields)
      ..writeByte(6)
      ..write(obj.isDeleted)
      ..writeByte(7)
      ..write(obj.deletedAt)
      ..writeByte(8)
      ..write(obj.deletedBy)
      ..writeByte(9)
      ..write(obj.deleteReason)
      ..writeByte(10)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DomainRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
