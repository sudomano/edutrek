import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

class BluetoothHelper {
  final BluetoothPrint bluetoothPrint = BluetoothPrint.instance;
  StreamSubscription<int>? _bluetoothStateSubscription;
  StreamSubscription<List<BluetoothDevice>>? _scanSubscription;
  bool _connected = false;
  bool _isScanning = false;

  bool get isConnected => _connected;

  void Function(bool isConnected, String message)? onConnectionStateChanged;

  Future<void> initBluetooth() async {
    debugPrint("🔄 Initializing Bluetooth...");

    if (!await _isBluetoothEnabled()) {
      _updateConnectionState(false, 'Bluetooth is OFF. Please enable it.');
      return;
    }

    if (_connected) {
      _updateConnectionState(true, 'Already connected to printer');
      return;
    }

    _bluetoothStateSubscription?.cancel();
    _bluetoothStateSubscription = bluetoothPrint.state.listen((int state) {
      debugPrint('🔄 Bluetooth state: $state');

      if (state == BluetoothPrint.CONNECTED) {
        _updateConnectionState(true, 'Connected to printer');
      } else if (state == BluetoothPrint.DISCONNECTED) {
        _updateConnectionState(false, 'Printer disconnected');
      } else {
        debugPrint('⚠️ Unknown Bluetooth state: $state');
      }
    });

    if (_isScanning) {
      debugPrint("⚠️ Scan already in progress. Stopping previous scan.");
      await bluetoothPrint.stopScan();
      _isScanning = false;
    }

    _isScanning = true;
    List<BluetoothDevice> devices = [];

    try {
      debugPrint("🔍 Starting Bluetooth scan...");
      await bluetoothPrint.startScan(timeout: const Duration(seconds: 5));

      _scanSubscription?.cancel();
      _scanSubscription = bluetoothPrint.scanResults.listen((result) {
        devices = result;
      });

      // Wait dynamically for scan results instead of using a fixed delay
      await Future.delayed(const Duration(seconds: 5));
      _scanSubscription?.cancel();

      if (devices.isNotEmpty) {
        debugPrint("✅ Found ${devices.length} device(s). Connecting...");
        await connectToPrinter(devices.first);
      } else {
        debugPrint("❌ No printers found.");
        _updateConnectionState(false, 'No printers found');
      }
    } catch (e) {
      debugPrint("❌ Error during Bluetooth scan: $e");
    } finally {
      _isScanning = false;
      try {
        await bluetoothPrint.stopScan();
      } catch (e) {
        debugPrint("⚠️ Error stopping scan (already stopped?): $e");
      }
    }
  }

  Future<void> connectToPrinter(BluetoothDevice device) async {
    debugPrint("🔗 Attempting to connect to printer: ${device.name}");

    try {
      await bluetoothPrint.connect(device);
      _updateConnectionState(true, 'Connected to ${device.name}');
      debugPrint("✅ Successfully connected to ${device.name}");
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _updateConnectionState(false, 'Failed to connect to printer');
    }
  }

  Future<void> resetBluetooth() async {
    debugPrint("🔄 Resetting Bluetooth...");

    _bluetoothStateSubscription?.cancel();
    _bluetoothStateSubscription = null;

    try {
      await bluetoothPrint.disconnect();
    } catch (e) {
      debugPrint("⚠️ Error disconnecting Bluetooth: $e");
    }

    _updateConnectionState(false, 'Bluetooth reset. Please reconnect.');

    await Future.delayed(const Duration(seconds: 5));
    await initBluetooth();
  }

  Future<void> verifyConnection() async {
    try {
      bool currentlyConnected = (await bluetoothPrint.isConnected) ?? false;
      if (currentlyConnected != _connected) {
        _updateConnectionState(currentlyConnected,
            currentlyConnected ? 'Printer connected' : 'Printer disconnected');
      }
    } catch (e) {
      debugPrint('❌ Error verifying connection: $e');
      _updateConnectionState(false, 'Error verifying connection');
    }
  }

  Future<bool> _isBluetoothEnabled() async {
    try {
      int? state = await bluetoothPrint.state.firstWhere(
        (s) =>
            s == BluetoothPrint.CONNECTED || s == BluetoothPrint.DISCONNECTED,
        orElse: () => BluetoothPrint.DISCONNECTED,
      );
      return state != BluetoothPrint.DISCONNECTED;
    } catch (e) {
      debugPrint('❌ Error checking Bluetooth state: $e');
      return false;
    }
  }

  void _updateConnectionState(bool isConnected, String message) {
    if (_connected != isConnected) {
      _connected = isConnected;
      onConnectionStateChanged?.call(_connected, message);
      debugPrint('🔔 Connection State Changed: $message');
    }
  }

  void dispose() {
    _bluetoothStateSubscription?.cancel();
    _scanSubscription?.cancel();
    bluetoothPrint.stopScan();
    _connected = false;
  }
}
