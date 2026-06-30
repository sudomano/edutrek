// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_lock.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdLockAdapter extends TypeAdapter<IdLock> {
  @override
  final int typeId = 104;

  @override
  IdLock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdLock(
      isLocked: fields[0] as bool,
      lockedAt: fields[1] as DateTime?,
      lockedByClientId: fields[2] as String?,
      lockedForCount: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, IdLock obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.isLocked)
      ..writeByte(1)
      ..write(obj.lockedAt)
      ..writeByte(2)
      ..write(obj.lockedByClientId)
      ..writeByte(3)
      ..write(obj.lockedForCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdLockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
