// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_daily_activity_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyActivityAdapter extends TypeAdapter<DailyActivity> {
  @override
  final int typeId = 26;

  @override
  DailyActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyActivity(
      projectDailyActiviyCode: fields[0] as String,
      projectCode: fields[1] as String,
      date: fields[2] as DateTime,
      type: fields[3] as String,
      description: fields[4] as String,
      amount: fields[5] as double,
      syncStatus: fields[6] as bool?,
      lastModified: fields[7] as DateTime?,
      operationType: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyActivity obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.projectDailyActiviyCode)
      ..writeByte(1)
      ..write(obj.projectCode)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.syncStatus)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.operationType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyActivityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
