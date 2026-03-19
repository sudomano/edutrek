// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'packaging_level.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PackagingLevelAdapter extends TypeAdapter<PackagingLevel> {
  @override
  final int typeId = 67;

  @override
  PackagingLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PackagingLevel.single;
      case 1:
        return PackagingLevel.pack;
      case 2:
        return PackagingLevel.carton;
      case 3:
        return PackagingLevel.batch;
      default:
        return PackagingLevel.single;
    }
  }

  @override
  void write(BinaryWriter writer, PackagingLevel obj) {
    switch (obj) {
      case PackagingLevel.single:
        writer.writeByte(0);
        break;
      case PackagingLevel.pack:
        writer.writeByte(1);
        break;
      case PackagingLevel.carton:
        writer.writeByte(2);
        break;
      case PackagingLevel.batch:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackagingLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
