import 'package:zitf_system/database/id_client_reservation.dart';

Map<String, dynamic> clientIdReservationToJson(
    ClientIdReservation reservation) {
  return {
    'clientId': reservation.clientId,
    'reservedIds': reservation.reservedIds,
    'reservedAt': reservation.reservedAt.toIso8601String(),
    'expiresAt': reservation.expiresAt?.toIso8601String(),
    'isActive': reservation.isActive,
  };
}

ClientIdReservation clientIdReservationFromJson(Map<String, dynamic> json) {
  return ClientIdReservation(
    clientId: json['clientId'] ?? '',
    reservedIds: List<int>.from(json['reservedIds'] ?? []),
    reservedAt: json['reservedAt'] != null
        ? DateTime.parse(json['reservedAt'])
        : DateTime.now(),
    expiresAt:
        json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    isActive: json['isActive'] ?? true,
  );
}

List<ClientIdReservation> clientIdReservationsFromJson(List<dynamic> jsonList) {
  return jsonList
      .map((json) =>
          clientIdReservationFromJson(Map<String, dynamic>.from(json)))
      .toList();
}

List<Map<String, dynamic>> clientIdReservationsToJson(
    List<ClientIdReservation> reservations) {
  return reservations
      .map((reservation) => clientIdReservationToJson(reservation))
      .toList();
}

// Specialized methods
Map<String, dynamic> clientIdReservationStatusToJson(
    ClientIdReservation reservation) {
  return {
    'clientId': reservation.clientId,
    'reservedCount': reservation.reservedIds.length,
    'reservedIds': reservation.reservedIds.take(10).toList(),
    'isActive': reservation.isActive,
    'expiresAt': reservation.expiresAt?.toIso8601String(),
    'remaining': reservation.reservedIds.length,
  };
}
