// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NetworkSettingsAdapter extends TypeAdapter<NetworkSettings> {
  @override
  final int typeId = 80;

  @override
  NetworkSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NetworkSettings(
      id: fields[0] as String?,
      hostIpAddress: fields[1] as String?,
      gateway: fields[2] as String?,
      deviceMacAddress: fields[3] as String?,
      networkDeviceMacAddress: fields[4] as String?,
      networkName: fields[5] as String?,
      lastUpdated: fields[6] as DateTime?,
      isActive: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NetworkSettings obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.hostIpAddress)
      ..writeByte(2)
      ..write(obj.gateway)
      ..writeByte(3)
      ..write(obj.deviceMacAddress)
      ..writeByte(4)
      ..write(obj.networkDeviceMacAddress)
      ..writeByte(5)
      ..write(obj.networkName)
      ..writeByte(6)
      ..write(obj.lastUpdated)
      ..writeByte(7)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
