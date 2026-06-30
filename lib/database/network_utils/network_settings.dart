import 'package:hive/hive.dart';

part 'network_settings.g.dart';

@HiveType(typeId: 80)
class NetworkSettings {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  String? hostIpAddress;

  @HiveField(2)
  String? gateway;

  @HiveField(3)
  String? deviceMacAddress;

  @HiveField(4)
  String? networkDeviceMacAddress;

  @HiveField(5)
  String? networkName;

  @HiveField(6)
  DateTime? lastUpdated;

  @HiveField(7)
  bool isActive = false;

  NetworkSettings({
    this.id,
    this.hostIpAddress,
    this.gateway,
    this.deviceMacAddress,
    this.networkDeviceMacAddress,
    this.networkName,
    this.lastUpdated,
    this.isActive = true,
  });

  // Copy with method for updates
  NetworkSettings copyWith({
    String? id,
    String? hostIpAddress,
    String? gateway,
    String? deviceMacAddress,
    String? networkDeviceMacAddress,
    String? networkName,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    return NetworkSettings(
      id: id ?? this.id,
      hostIpAddress: hostIpAddress ?? this.hostIpAddress,
      gateway: gateway ?? this.gateway,
      deviceMacAddress: deviceMacAddress ?? this.deviceMacAddress,
      networkDeviceMacAddress:
          networkDeviceMacAddress ?? this.networkDeviceMacAddress,
      networkName: networkName ?? this.networkName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostIpAddress': hostIpAddress,
      'gateway': gateway,
      'deviceMacAddress': deviceMacAddress,
      'networkDeviceMacAddress': networkDeviceMacAddress,
      'networkName': networkName,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory NetworkSettings.fromJson(Map<String, dynamic> json) {
    return NetworkSettings(
      id: json['id'],
      hostIpAddress: json['hostIpAddress'],
      gateway: json['gateway'],
      deviceMacAddress: json['deviceMacAddress'],
      networkDeviceMacAddress: json['networkDeviceMacAddress'],
      networkName: json['networkName'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      isActive: json['isActive'],
    );
  }
}
