// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'school_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SchoolAdapter extends TypeAdapter<School> {
  @override
  final int typeId = 14;

  @override
  School read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return School(
      schoolName: fields[0] as String?,
      schoolAddress: fields[1] as String?,
      schoolPhoneNumber: fields[2] as String?,
      schoolEmail: fields[3] as String?,
      termId: fields[4] as String?,
      syncStatus: fields[5] as bool?,
      lastModified: fields[6] as DateTime?,
      operationType: fields[7] as String?,
      id: fields[8] as int?,
      schoolLogoPath: fields[9] as String?,
      schoolCode: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, School obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.schoolName)
      ..writeByte(1)
      ..write(obj.schoolAddress)
      ..writeByte(2)
      ..write(obj.schoolPhoneNumber)
      ..writeByte(3)
      ..write(obj.schoolEmail)
      ..writeByte(4)
      ..write(obj.termId)
      ..writeByte(5)
      ..write(obj.syncStatus)
      ..writeByte(6)
      ..write(obj.lastModified)
      ..writeByte(7)
      ..write(obj.operationType)
      ..writeByte(8)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.schoolLogoPath)
      ..writeByte(10)
      ..write(obj.schoolCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
