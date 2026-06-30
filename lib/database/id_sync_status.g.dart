// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_sync_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdSyncStatusAdapter extends TypeAdapter<IdSyncStatus> {
  @override
  final int typeId = 105;

  @override
  IdSyncStatus read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdSyncStatus(
      deviceId: fields[0] as String,
      lastSyncedId: fields[1] as int,
      lastSyncTime: fields[2] as DateTime?,
      pendingIdsCount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, IdSyncStatus obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.lastSyncedId)
      ..writeByte(2)
      ..write(obj.lastSyncTime)
      ..writeByte(3)
      ..write(obj.pendingIdsCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdSyncStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
