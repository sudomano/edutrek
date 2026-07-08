// lib/services/connectivity_monitor.dart
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityMonitor {
  static final ConnectivityMonitor _instance = ConnectivityMonitor._internal();
  factory ConnectivityMonitor() => _instance;
  ConnectivityMonitor._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isConnected = false;
  bool _isVerifying = false;

  // List of URLs to test - using your existing domain if available
  List<String> _testUrls = [];

  final List<void Function(bool)> _listeners = [];
  Timer? _verificationTimer;

  void initialize({String? domainName, List<String>? customUrls}) {
    // Use provided domain or fallback to common URLs
    if (domainName != null && domainName.isNotEmpty && domainName != "null") {
      _testUrls = [
        'http://$domainName',
        'https://www.google.com',
        'https://www.cloudflare.com',
      ];
    } else {
      _testUrls = [
        'https://www.google.com',
        'https://www.cloudflare.com',
        'https://www.microsoft.com',
      ];
    }

    // Start monitoring
    _startMonitoring();
  }

  void _startMonitoring() {
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // Check if any result is connected
      final isConnected =
          results.any((result) => result != ConnectivityResult.none);

      if (isConnected) {
        _verifyInternetAccess();
      } else {
        _updateConnectionStatus(false);
      }
    });

    // Initial check
    _verifyInternetAccess();

    // Periodic verification (every 30 seconds)
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _verifyInternetAccess(),
    );
  }

  Future<void> _verifyInternetAccess() async {
    if (_isVerifying) return;
    _isVerifying = true;

    try {
      bool hasInternet = false;

      for (String url in _testUrls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {'User-Agent': 'Mozilla/5.0'},
          ).timeout(const Duration(seconds: 5));

          // Any response (even error) means we have connectivity
          if (response.statusCode >= 200 && response.statusCode < 500) {
            hasInternet = true;
            break;
          }
        } catch (_) {
          // Try next URL
          continue;
        }
      }

      _updateConnectionStatus(hasInternet);
    } catch (_) {
      _updateConnectionStatus(false);
    } finally {
      _isVerifying = false;
    }
  }

  void _updateConnectionStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      for (var listener in _listeners) {
        listener(connected);
      }
    }
  }

  void addListener(void Function(bool) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(bool) listener) {
    _listeners.remove(listener);
  }

  bool get isConnected => _isConnected;

  Future<bool> checkConnectivity() async {
    await _verifyInternetAccess();
    return _isConnected;
  }

  void dispose() {
    _verificationTimer?.cancel();
    _listeners.clear();
  }
}
