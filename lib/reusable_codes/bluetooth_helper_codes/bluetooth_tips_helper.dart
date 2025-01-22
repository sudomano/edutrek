import 'package:flutter/material.dart';
import 'package:bluetooth_print/bluetooth_print.dart';

class BluetoothHelper {
  final BluetoothPrint bluetoothPrint =
      BluetoothPrint.instance; // Correct initialization
  bool _connected = false;

  // Callback for connection state changes
  void Function(bool isConnected, String message)? onConnectionStateChanged;

  /// Initializes Bluetooth functionality
  Future<void> initBluetooth() async {
    try {
      // Start scanning for devices with a timeout
      await bluetoothPrint.startScan(timeout: const Duration(seconds: 4));

      // Check if a Bluetooth connection already exists
      bool isConnected = await bluetoothPrint.isConnected ?? false;

      // Notify immediately if already connected
      if (isConnected) {
        _connected = true;
        _notifyConnectionState(true, 'Already connected to the printer');
        return;
      }

      // Listen for state changes
      bluetoothPrint.state.listen((state) {
        debugPrint('Bluetooth state: $state');
        switch (state) {
          case BluetoothPrint.CONNECTED:
            _connected = true;
            _notifyConnectionState(true, 'Connected successfully');
            break;
          case BluetoothPrint.DISCONNECTED:
            _connected = false;
            _notifyConnectionState(false, 'Disconnected successfully');
            break;
          default:
            debugPrint('Unhandled state: $state');
            break;
        }
      });

      // Update UI if not connected
      if (!_connected) {
        _notifyConnectionState(false, 'Not connected. Please select a device.');
      }
    } catch (e) {
      // Handle errors during initialization
      debugPrint('Error initializing Bluetooth: $e');
      _notifyConnectionState(
          false, 'Failed to initialize Bluetooth. Please try again.');
    } finally {
      // Stop scanning
      await bluetoothPrint.stopScan();
    }
  }

  /// Notifies the UI of connection state changes
  void _notifyConnectionState(bool isConnected, String message) {
    if (_connected != isConnected) {
      _connected = isConnected;
      onConnectionStateChanged?.call(isConnected, message);
    }
  }

  /// Verifies the connection status and updates the UI
  Future<void> verifyConnection() async {
    try {
      bool isConnected = await bluetoothPrint.isConnected ?? false;
      if (isConnected && !_connected) {
        _connected = true;
        _notifyConnectionState(true, 'Connected successfully');
      } else if (!isConnected && _connected) {
        _connected = false;
        _notifyConnectionState(false, 'Printer not connected');
      }
    } catch (e) {
      debugPrint('Error verifying connection: $e');
    }
  }

  /// Returns the current connection status
  bool get isConnected => _connected;
}
