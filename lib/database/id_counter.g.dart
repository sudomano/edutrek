// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_counter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdCounterAdapter extends TypeAdapter<IdCounter> {
  @override
  final int typeId = 107;

  @override
  IdCounter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdCounter(
      lastAssignedId: fields[0] as int,
      lastUpdated: fields[1] as DateTime?,
      totalIdsAssigned: fields[2] as int,
      lastClientId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IdCounter obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.lastAssignedId)
      ..writeByte(1)
      ..write(obj.lastUpdated)
      ..writeByte(2)
      ..write(obj.totalIdsAssigned)
      ..writeByte(3)
      ..write(obj.lastClientId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdCounterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
