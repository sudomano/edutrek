// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_range.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdRangeAdapter extends TypeAdapter<IdRange> {
  @override
  final int typeId = 106;

  @override
  IdRange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdRange(
      startId: fields[0] as int,
      endId: fields[1] as int,
      assignedTo: fields[2] as String,
      assignedAt: fields[3] as DateTime?,
      isFullyUsed: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, IdRange obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.startId)
      ..writeByte(1)
      ..write(obj.endId)
      ..writeByte(2)
      ..write(obj.assignedTo)
      ..writeByte(3)
      ..write(obj.assignedAt)
      ..writeByte(4)
      ..write(obj.isFullyUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdRangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
