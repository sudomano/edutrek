// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_batch_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductBatchAdapter extends TypeAdapter<ProductBatch> {
  @override
  final int typeId = 62;

  @override
  ProductBatch read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductBatch(
      batchCode: fields[0] as String?,
      productCode: fields[1] as String?,
      reference: fields[2] as String?,
      baseUnitType: fields[3] as StockUnitType?,
      baseUnit: fields[4] as String?,
      units: (fields[5] as List?)?.cast<BatchUnit>(),
      totalBaseUnits: fields[6] as double?,
      remainingBaseUnits: fields[7] as double?,
      totalBuyingCost: fields[8] as double?,
      purchaseDate: fields[9] as DateTime?,
      createdAt: fields[10] as DateTime?,
      syncStatus: fields[11] as bool?,
      lastModified: fields[12] as DateTime?,
      operationType: fields[13] as String?,
      modifiedFields: (fields[14] as List?)?.cast<String>(),
      baseUnitSize: fields[15] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductBatch obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.batchCode)
      ..writeByte(1)
      ..write(obj.productCode)
      ..writeByte(2)
      ..write(obj.reference)
      ..writeByte(3)
      ..write(obj.baseUnitType)
      ..writeByte(4)
      ..write(obj.baseUnit)
      ..writeByte(5)
      ..write(obj.units)
      ..writeByte(6)
      ..write(obj.totalBaseUnits)
      ..writeByte(7)
      ..write(obj.remainingBaseUnits)
      ..writeByte(8)
      ..write(obj.totalBuyingCost)
      ..writeByte(9)
      ..write(obj.purchaseDate)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.syncStatus)
      ..writeByte(12)
      ..write(obj.lastModified)
      ..writeByte(13)
      ..write(obj.operationType)
      ..writeByte(14)
      ..write(obj.modifiedFields)
      ..writeByte(15)
      ..write(obj.baseUnitSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductBatchAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
