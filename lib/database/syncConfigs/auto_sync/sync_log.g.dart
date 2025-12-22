// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncLogAdapter extends TypeAdapter<SyncLog> {
  @override
  final int typeId = 50;

  @override
  SyncLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncLog(
      timestamp: fields[0] as String,
      model: fields[1] as String,
      id: fields[2] as String,
      error: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SyncLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.model)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.error);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
