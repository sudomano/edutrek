import 'package:hive/hive.dart';

part 'payment_method_model.g.dart';

@HiveType(typeId: 70)
class PaymentMethod extends HiveObject {
  @HiveField(0)
  String? paymentMethodCode;

  @HiveField(1)
  String? methodType;
  // cash | mobile_money | bank_transfer | card | cheque | voucher | other

  @HiveField(2)
  double? amount;

  @HiveField(3)
  String? currency;

  // ---------- OPTIONAL DETAILS ----------
  @HiveField(4)
  String? provider;

  @HiveField(5)
  String? reference;

  @HiveField(6)
  String? phoneNumber;

  @HiveField(7)
  String? accountNumber;

  @HiveField(8)
  String? accountName;

  @HiveField(9)
  DateTime? paymentDate;

  // ---------- AUDIT ----------
  @HiveField(10)
  bool? isReversed;

  @HiveField(11)
  DateTime? lastModified;

  @HiveField(12)
  String? operationType; // create | update | delete

  @HiveField(13)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(14)
  List<String>? modifiedFields; // Tracks fields that were modified

  PaymentMethod({
    this.paymentMethodCode,
    this.methodType,
    this.amount,
    this.currency,
    this.provider,
    this.reference,
    this.phoneNumber,
    this.accountNumber,
    this.accountName,
    this.paymentDate,
    this.isReversed,
    this.lastModified,
    this.operationType,
    this.syncStatus,
    this.modifiedFields,
  });

  /// ---------- SAFE DEFAULTS ----------
  double get safeAmount => amount ?? 0.0;
  String get safeCurrency => currency ?? 'USD';
  bool get safeIsReversed => isReversed ?? false;
  String get safeMethodType => methodType ?? 'cash';

  /// ---------- COPY WITH ----------
  PaymentMethod copyWith({
    String? paymentMethodCode,
    String? methodType,
    double? amount,
    String? currency,
    String? provider,
    String? reference,
    String? phoneNumber,
    String? accountNumber,
    String? accountName,
    DateTime? paymentDate,
    bool? isReversed,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
    bool? syncStatus,
  }) {
    return PaymentMethod(
      paymentMethodCode: paymentMethodCode ?? this.paymentMethodCode,
      methodType: methodType ?? this.methodType,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      provider: provider ?? this.provider,
      reference: reference ?? this.reference,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      paymentDate: paymentDate ?? this.paymentDate,
      isReversed: isReversed ?? this.isReversed,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// ---------- SERIALIZATION (OPTIONAL BUT GOLD) ----------
  Map<String, dynamic> toMap() {
    return {
      'paymentMethodCode': paymentMethodCode,
      'methodType': methodType,
      'amount': amount,
      'currency': currency,
      'provider': provider,
      'reference': reference,
      'phoneNumber': phoneNumber,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'paymentDate': paymentDate?.toIso8601String(),
      'isReversed': isReversed,
      'lastModified': lastModified?.toIso8601String(),
      'operationType': operationType,
      'syncStatus': syncStatus,
      'modifiedFields': modifiedFields,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      paymentMethodCode: map['paymentMethodCode'],
      methodType: map['methodType'],
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency'],
      provider: map['provider'],
      reference: map['reference'],
      phoneNumber: map['phoneNumber'],
      accountNumber: map['accountNumber'],
      accountName: map['accountName'],
      paymentDate: map['paymentDate'] != null
          ? DateTime.tryParse(map['paymentDate'])
          : null,
      isReversed: map['isReversed'],
      lastModified: map['lastModified'] != null
          ? DateTime.tryParse(map['lastModified'])
          : null,
      operationType: map['operationType'],
      syncStatus: map['syncStatus'],
      modifiedFields: List<String>.from(map['modifiedFields'] ?? []),
    );
  }
}
