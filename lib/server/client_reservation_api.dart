// api/client_reservation_api.dart
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:zitf_system/auth/userdb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/database/id_client_reservation.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/serializers/client_id_reservation_serializer.dart';

// Create reservation
Future<Map<String, dynamic>> createReservation({
  required String clientId,
  required List<int> ids,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final reservation = ClientIdReservation(
        clientId: clientId,
        reservedIds: ids,
        reservedAt: DateTime.now(),
        isActive: true,
      );

      final box = await Hive.openBox<ClientIdReservation>('id_reservations');
      await box.add(reservation);

      return {
        'success': true,
        'message': 'Reservation created',
        'reservation': clientIdReservationToJson(reservation),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  } else {
    try {
      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/reservations/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientId': clientId,
          'ids': ids,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// Get client reservations
Future<Map<String, dynamic>> getClientReservations(String clientId) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<ClientIdReservation>('id_reservations');
      final reservations = box.values
          .where((r) => r.clientId == clientId && r.isActive)
          .toList();

      return {
        'success': true,
        'reservations': clientIdReservationsToJson(reservations),
        'count': reservations.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  } else {
    try {
      final response = await http.get(
        Uri.parse('http://$hostIp:8080/api/reservations/client/$clientId'),
        headers: {'Content-Type': 'application/json'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// Use reserved ID
Future<Map<String, dynamic>> useReservedId({
  required String clientId,
  required int id,
}) async {
  final role = await getDeviceRole();
  final prefs = await SharedPreferences.getInstance();
  final hostIp = prefs.getString('host_ip') ?? '192.168.8.2';

  if (role == DeviceRole.host) {
    try {
      final box = await Hive.openBox<ClientIdReservation>('id_reservations');
      final reservations = box.values
          .where((r) => r.clientId == clientId && r.isActive)
          .toList();

      for (var reservation in reservations) {
        if (reservation.reservedIds.contains(id)) {
          reservation.reservedIds.remove(id);
          if (reservation.reservedIds.isEmpty) {
            reservation.isActive = false;
          }
          await reservation.save();

          return {
            'success': true,
            'message': 'ID $id used from reservation',
          };
        }
      }

      return {
        'success': false,
        'error': 'ID not found in reservation',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  } else {
    try {
      final response = await http.post(
        Uri.parse('http://$hostIp:8080/api/reservations/use'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientId': clientId,
          'id': id,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
