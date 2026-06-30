// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_assignment_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdAssignmentLogAdapter extends TypeAdapter<IdAssignmentLog> {
  @override
  final int typeId = 108;

  @override
  IdAssignmentLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdAssignmentLog(
      id: fields[0] as int,
      assignedAt: fields[1] as DateTime?,
      assignedByClientId: fields[2] as String,
      paymentReceiptNumber: fields[3] as String?,
      isUsed: fields[4] as bool,
      usedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, IdAssignmentLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assignedAt)
      ..writeByte(2)
      ..write(obj.assignedByClientId)
      ..writeByte(3)
      ..write(obj.paymentReceiptNumber)
      ..writeByte(4)
      ..write(obj.isUsed)
      ..writeByte(5)
      ..write(obj.usedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdAssignmentLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
