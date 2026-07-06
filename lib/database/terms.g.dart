// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terms.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TermsAdapter extends TypeAdapter<Terms> {
  @override
  final int typeId = 21;

  @override
  Terms read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Terms(
      termId: fields[0] as String,
      termName: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime?,
      isActive: fields[4] as bool,
      status: fields[5] as String,
      syncStatus: fields[6] as bool?,
      lastModified: fields[7] as DateTime?,
      operationType: fields[8] as String?,
      id: fields[9] as int?,
      modifiedFields: (fields[10] as List?)?.cast<String>(),
      isDeleted: fields[11] as bool?,
      deletedAt: fields[12] as DateTime?,
      deletedBy: fields[13] as String?,
      deleteReason: fields[14] as String?,
      deletedSyncStatus: fields[15] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Terms obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.termId)
      ..writeByte(1)
      ..write(obj.termName)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.syncStatus)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.operationType)
      ..writeByte(9)
      ..write(obj.id)
      ..writeByte(10)
      ..write(obj.modifiedFields)
      ..writeByte(11)
      ..write(obj.isDeleted)
      ..writeByte(12)
      ..write(obj.deletedAt)
      ..writeByte(13)
      ..write(obj.deletedBy)
      ..writeByte(14)
      ..write(obj.deleteReason)
      ..writeByte(15)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TermsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
