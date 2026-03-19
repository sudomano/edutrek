// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_unit_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockUnitTypeAdapter extends TypeAdapter<StockUnitType> {
  @override
  final int typeId = 66;

  @override
  StockUnitType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StockUnitType.piece;
      case 1:
        return StockUnitType.weight;
      case 2:
        return StockUnitType.volume;
      default:
        return StockUnitType.piece;
    }
  }

  @override
  void write(BinaryWriter writer, StockUnitType obj) {
    switch (obj) {
      case StockUnitType.piece:
        writer.writeByte(0);
        break;
      case StockUnitType.weight:
        writer.writeByte(1);
        break;
      case StockUnitType.volume:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockUnitTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
