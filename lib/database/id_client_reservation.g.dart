// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_client_reservation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientIdReservationAdapter extends TypeAdapter<ClientIdReservation> {
  @override
  final int typeId = 109;

  @override
  ClientIdReservation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClientIdReservation(
      clientId: fields[0] as String,
      reservedIds: (fields[1] as List).cast<int>(),
      reservedAt: fields[2] as DateTime?,
      expiresAt: fields[3] as DateTime?,
      isActive: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ClientIdReservation obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.clientId)
      ..writeByte(1)
      ..write(obj.reservedIds)
      ..writeByte(2)
      ..write(obj.reservedAt)
      ..writeByte(3)
      ..write(obj.expiresAt)
      ..writeByte(4)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientIdReservationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
