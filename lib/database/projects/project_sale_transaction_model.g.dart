// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_sale_transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectSaleTransactionAdapter
    extends TypeAdapter<ProjectSaleTransaction> {
  @override
  final int typeId = 27;

  @override
  ProjectSaleTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProjectSaleTransaction(
      transactionCode: fields[0] as String,
      studentId: fields[1] as String,
      projectCode: fields[2] as String,
      projectItemCode: fields[3] as String,
      batchCode: fields[4] as String,
      sellUnitCode: fields[5] as String,
      sellUnitNameSnapshot: fields[6] as String,
      quantitySold: fields[7] as int,
      unitSellingPrice: fields[8] as double,
      totalAmount: fields[9] as double,
      baseUnitsPerSellUnit: fields[10] as double,
      totalBaseUnitsSold: fields[11] as double,
      baseUnit: fields[12] as String,
      baseUnitType: fields[13] as StockUnitType,
      transactionDate: fields[14] as DateTime,
      paymentMethod: fields[15] as String,
      reference: fields[16] as String,
      amountPaid: fields[26] as double,
      arrears: fields[27] as double,
      isDeleted: fields[21] as bool?,
      deletedAt: (fields[22] as List?)?.cast<DateTime>(),
      restoredAt: (fields[23] as List?)?.cast<DateTime>(),
      deletedByUsers: (fields[24] as List?)?.cast<String>(),
      restoredByUsers: (fields[25] as List?)?.cast<String>(),
      syncStatus: fields[17] as bool?,
      lastModified: fields[18] as DateTime?,
      operationType: fields[19] as String?,
      modifiedFields: (fields[20] as List?)?.cast<String>(),
      paymentMethodCode: fields[28] as String?,
      methodType: fields[29] as String?,
      amountPaidInPaymentMethod: fields[30] as double?,
      currency: fields[31] as String?,
      provider: fields[32] as String?,
      referenceNumber: fields[33] as String?,
      phoneNumber: fields[34] as String?,
      accountNumber: fields[36] as String?,
      accountName: fields[37] as String?,
      paymentDatetransacted: fields[38] as DateTime?,
      isReversed: fields[39] as bool?,
      lineTransactionCodes: (fields[40] as List?)?.cast<String>(),
      financialType: fields[41] as String,
      parentTransactionCode: fields[42] as String?,
      affectsStock: fields[43] as bool,
      createsObligation: fields[44] as bool,
      settlesObligation: fields[45] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectSaleTransaction obj) {
    writer
      ..writeByte(45)
      ..writeByte(0)
      ..write(obj.transactionCode)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.projectCode)
      ..writeByte(3)
      ..write(obj.projectItemCode)
      ..writeByte(4)
      ..write(obj.batchCode)
      ..writeByte(5)
      ..write(obj.sellUnitCode)
      ..writeByte(6)
      ..write(obj.sellUnitNameSnapshot)
      ..writeByte(7)
      ..write(obj.quantitySold)
      ..writeByte(8)
      ..write(obj.unitSellingPrice)
      ..writeByte(9)
      ..write(obj.totalAmount)
      ..writeByte(10)
      ..write(obj.baseUnitsPerSellUnit)
      ..writeByte(11)
      ..write(obj.totalBaseUnitsSold)
      ..writeByte(12)
      ..write(obj.baseUnit)
      ..writeByte(13)
      ..write(obj.baseUnitType)
      ..writeByte(14)
      ..write(obj.transactionDate)
      ..writeByte(15)
      ..write(obj.paymentMethod)
      ..writeByte(16)
      ..write(obj.reference)
      ..writeByte(17)
      ..write(obj.syncStatus)
      ..writeByte(18)
      ..write(obj.lastModified)
      ..writeByte(19)
      ..write(obj.operationType)
      ..writeByte(20)
      ..write(obj.modifiedFields)
      ..writeByte(21)
      ..write(obj.isDeleted)
      ..writeByte(22)
      ..write(obj.deletedAt)
      ..writeByte(23)
      ..write(obj.restoredAt)
      ..writeByte(24)
      ..write(obj.deletedByUsers)
      ..writeByte(25)
      ..write(obj.restoredByUsers)
      ..writeByte(26)
      ..write(obj.amountPaid)
      ..writeByte(27)
      ..write(obj.arrears)
      ..writeByte(28)
      ..write(obj.paymentMethodCode)
      ..writeByte(29)
      ..write(obj.methodType)
      ..writeByte(30)
      ..write(obj.amountPaidInPaymentMethod)
      ..writeByte(31)
      ..write(obj.currency)
      ..writeByte(32)
      ..write(obj.provider)
      ..writeByte(33)
      ..write(obj.referenceNumber)
      ..writeByte(34)
      ..write(obj.phoneNumber)
      ..writeByte(36)
      ..write(obj.accountNumber)
      ..writeByte(37)
      ..write(obj.accountName)
      ..writeByte(38)
      ..write(obj.paymentDatetransacted)
      ..writeByte(39)
      ..write(obj.isReversed)
      ..writeByte(40)
      ..write(obj.lineTransactionCodes)
      ..writeByte(41)
      ..write(obj.financialType)
      ..writeByte(42)
      ..write(obj.parentTransactionCode)
      ..writeByte(43)
      ..write(obj.affectsStock)
      ..writeByte(44)
      ..write(obj.createsObligation)
      ..writeByte(45)
      ..write(obj.settlesObligation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectSaleTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
