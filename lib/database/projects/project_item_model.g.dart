// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectItemAdapter extends TypeAdapter<ProjectItem> {
  @override
  final int typeId = 25;

  @override
  ProjectItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectItem(
      projectItemCode: fields[0] as String,
      projectCode: fields[1] as String,
      name: fields[2] as String,
      amount: fields[3] as double,
      isStudentFee: fields[4] as bool,
      syncStatus: fields[5] as bool?,
      lastModified: fields[6] as DateTime?,
      operationType: fields[7] as String?,
      modifiedFields: (fields[8] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProjectItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.projectItemCode)
      ..writeByte(1)
      ..write(obj.projectCode)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.isStudentFee)
      ..writeByte(5)
      ..write(obj.syncStatus)
      ..writeByte(6)
      ..write(obj.lastModified)
      ..writeByte(7)
      ..write(obj.operationType)
      ..writeByte(8)
      ..write(obj.modifiedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
