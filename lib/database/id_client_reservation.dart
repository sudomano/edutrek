import 'package:hive/hive.dart';

part 'id_client_reservation.g.dart';

@HiveType(typeId: 109)
class ClientIdReservation extends HiveObject {
  @HiveField(0)
  String clientId;

  @HiveField(1)
  List<int> reservedIds;

  @HiveField(2)
  DateTime reservedAt;

  @HiveField(3)
  DateTime? expiresAt;

  @HiveField(4)
  bool isActive;

  ClientIdReservation({
    required this.clientId,
    required this.reservedIds,
    DateTime? reservedAt,
    this.expiresAt,
    this.isActive = true,
  }) : reservedAt = reservedAt ?? DateTime.now();
}
