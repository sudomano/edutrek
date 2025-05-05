// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_logou_timer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AutoLogoutSettingsAdapter extends TypeAdapter<AutoLogoutSettings> {
  @override
  final int typeId = 38;

  @override
  AutoLogoutSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AutoLogoutSettings(
      logoutTimeoutMinutes: fields[0] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AutoLogoutSettings obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.logoutTimeoutMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoLogoutSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
