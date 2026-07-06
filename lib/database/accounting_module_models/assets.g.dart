// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assets.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AssetAdapter extends TypeAdapter<Asset> {
  @override
  final int typeId = 23;

  @override
  Asset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Asset(
      id: fields[0] as int?,
      assetName: fields[1] as String?,
      assetType: fields[2] as String?,
      assetSubType: fields[36] as String?,
      assetCode: fields[3] as String?,
      assetSerialNo: fields[37] as String?,
      acquisitionDate: fields[4] as DateTime?,
      acquisitionCost: fields[5] as double?,
      acquisitionMethod: fields[38] as String?,
      department: fields[6] as String?,
      location: fields[7] as String?,
      depreciationRate: fields[8] as double?,
      depreciationMethod: fields[9] as String?,
      lastDepreciationDate: fields[10] as DateTime?,
      accumulatedDepreciation: fields[11] as double?,
      bookValue: fields[12] as double?,
      isImpaired: fields[13] as bool?,
      impairmentLoss: fields[14] as double?,
      revaluationDate: fields[15] as DateTime?,
      revaluationAmount: fields[16] as double?,
      lastMaintenanceDate: fields[17] as DateTime?,
      maintenanceCost: fields[18] as double?,
      maintenanceDescription: fields[19] as String?,
      capitalImprovementCost: fields[20] as double?,
      capitalImprovementDescription: fields[21] as String?,
      disposalDate: fields[22] as DateTime?,
      disposalProceeds: fields[23] as double?,
      disposalReason: fields[24] as String?,
      gainOrLossOnDisposal: fields[25] as double?,
      isLeased: fields[26] as bool?,
      leaseType: fields[27] as String?,
      leaseStartDate: fields[28] as DateTime?,
      leaseEndDate: fields[29] as DateTime?,
      leasePaymentAmount: fields[30] as double?,
      lastAuditDate: fields[31] as DateTime?,
      syncStatus: fields[32] as bool?,
      notes: fields[33] as String?,
      createdAt: fields[34] as DateTime?,
      lastModified: fields[35] as DateTime?,
      operationType: fields[39] as String?,
      usefulLife: fields[40] as String?,
      hasDebitBalance: fields[41] as bool?,
      hasCreditBalance: fields[42] as bool?,
      option: fields[43] as String?,
      modifiedFields: (fields[44] as List?)?.cast<String>(),
      isDeleted: fields[45] as bool?,
      deletedAt: fields[46] as DateTime?,
      deletedBy: fields[47] as String?,
      deleteReason: fields[48] as String?,
      deletedSyncStatus: fields[49] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Asset obj) {
    writer
      ..writeByte(50)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assetName)
      ..writeByte(2)
      ..write(obj.assetType)
      ..writeByte(36)
      ..write(obj.assetSubType)
      ..writeByte(3)
      ..write(obj.assetCode)
      ..writeByte(37)
      ..write(obj.assetSerialNo)
      ..writeByte(4)
      ..write(obj.acquisitionDate)
      ..writeByte(5)
      ..write(obj.acquisitionCost)
      ..writeByte(38)
      ..write(obj.acquisitionMethod)
      ..writeByte(6)
      ..write(obj.department)
      ..writeByte(7)
      ..write(obj.location)
      ..writeByte(8)
      ..write(obj.depreciationRate)
      ..writeByte(9)
      ..write(obj.depreciationMethod)
      ..writeByte(10)
      ..write(obj.lastDepreciationDate)
      ..writeByte(11)
      ..write(obj.accumulatedDepreciation)
      ..writeByte(12)
      ..write(obj.bookValue)
      ..writeByte(13)
      ..write(obj.isImpaired)
      ..writeByte(14)
      ..write(obj.impairmentLoss)
      ..writeByte(15)
      ..write(obj.revaluationDate)
      ..writeByte(16)
      ..write(obj.revaluationAmount)
      ..writeByte(17)
      ..write(obj.lastMaintenanceDate)
      ..writeByte(18)
      ..write(obj.maintenanceCost)
      ..writeByte(19)
      ..write(obj.maintenanceDescription)
      ..writeByte(20)
      ..write(obj.capitalImprovementCost)
      ..writeByte(21)
      ..write(obj.capitalImprovementDescription)
      ..writeByte(22)
      ..write(obj.disposalDate)
      ..writeByte(23)
      ..write(obj.disposalProceeds)
      ..writeByte(24)
      ..write(obj.disposalReason)
      ..writeByte(25)
      ..write(obj.gainOrLossOnDisposal)
      ..writeByte(26)
      ..write(obj.isLeased)
      ..writeByte(27)
      ..write(obj.leaseType)
      ..writeByte(28)
      ..write(obj.leaseStartDate)
      ..writeByte(29)
      ..write(obj.leaseEndDate)
      ..writeByte(30)
      ..write(obj.leasePaymentAmount)
      ..writeByte(31)
      ..write(obj.lastAuditDate)
      ..writeByte(32)
      ..write(obj.syncStatus)
      ..writeByte(33)
      ..write(obj.notes)
      ..writeByte(34)
      ..write(obj.createdAt)
      ..writeByte(35)
      ..write(obj.lastModified)
      ..writeByte(39)
      ..write(obj.operationType)
      ..writeByte(40)
      ..write(obj.usefulLife)
      ..writeByte(41)
      ..write(obj.hasDebitBalance)
      ..writeByte(42)
      ..write(obj.hasCreditBalance)
      ..writeByte(43)
      ..write(obj.option)
      ..writeByte(44)
      ..write(obj.modifiedFields)
      ..writeByte(45)
      ..write(obj.isDeleted)
      ..writeByte(46)
      ..write(obj.deletedAt)
      ..writeByte(47)
      ..write(obj.deletedBy)
      ..writeByte(48)
      ..write(obj.deleteReason)
      ..writeByte(49)
      ..write(obj.deletedSyncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
