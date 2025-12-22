// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exceptional_students.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExceptionalStudentsAdapter extends TypeAdapter<ExceptionalStudents> {
  @override
  final int typeId = 51;

  @override
  ExceptionalStudents read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExceptionalStudents(
      id: fields[0] as int?,
      exceptionId: fields[1] as String?,
      exceptionName: fields[2] as String?,
      exceptionStatus: fields[3] as String?,
      exceptionType: fields[4] as String?,
      exceptionFigure: fields[5] as String?,
      syncStatus: fields[6] as bool?,
      lastModified: fields[7] as DateTime?,
      operationType: fields[8] as String?,
      modifiedFields: (fields[9] as List?)?.cast<String>(),
      terms: (fields[10] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ExceptionalStudents obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.exceptionId)
      ..writeByte(2)
      ..write(obj.exceptionName)
      ..writeByte(3)
      ..write(obj.exceptionStatus)
      ..writeByte(4)
      ..write(obj.exceptionType)
      ..writeByte(5)
      ..write(obj.exceptionFigure)
      ..writeByte(6)
      ..write(obj.syncStatus)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.operationType)
      ..writeByte(9)
      ..write(obj.modifiedFields)
      ..writeByte(10)
      ..write(obj.terms);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExceptionalStudentsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
