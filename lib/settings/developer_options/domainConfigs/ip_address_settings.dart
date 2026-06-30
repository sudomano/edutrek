import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/network_utils/network_settings.dart';

class IpAddressSettings extends StatefulWidget {
  const IpAddressSettings({Key? key}) : super(key: key);

  @override
  State<IpAddressSettings> createState() => _IpAddressSettingsState();
}

class _IpAddressSettingsState extends State<IpAddressSettings> {
  NetworkSettings? _activeNetwork;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveNetwork();
  }

  Future<void> _loadActiveNetwork() async {
    try {
      final box = await Hive.openBox<NetworkSettings>('network_settings_box');

      NetworkSettings? activeNetwork;

      for (final network in box.values) {
        if (network.isActive == true) {
          activeNetwork = network;
          break;
        }
      }

      setState(() {
        _activeNetwork = activeNetwork;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading active network: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value.isEmpty ? 'Not Available' : value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Network Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: _activeNetwork == null
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No Active Network Found',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No active network configuration exists in the system.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.wifi,
                                        size: 60,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _activeNetwork?.networkName ??
                                            'Unknown Network',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'ACTIVE NETWORK',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildInfoTile(
                                icon: Icons.lan,
                                title: 'Host IP Address',
                                value: _activeNetwork?.hostIpAddress ?? '',
                              ),
                              _buildInfoTile(
                                icon: Icons.router,
                                title: 'Gateway',
                                value: _activeNetwork?.gateway ?? '',
                              ),
                              _buildInfoTile(
                                icon: Icons.memory,
                                title: 'Device MAC Address',
                                value: _activeNetwork?.deviceMacAddress ?? '',
                              ),
                              _buildInfoTile(
                                icon: Icons.settings_ethernet,
                                title: 'Network Device MAC Address',
                                value:
                                    _activeNetwork?.networkDeviceMacAddress ??
                                        '',
                              ),
                              _buildInfoTile(
                                icon: Icons.access_time,
                                title: 'Last Updated',
                                value: _activeNetwork?.lastUpdated != null
                                    ? _activeNetwork!.lastUpdated.toString()
                                    : '',
                              ),
                              const SizedBox(height: 30),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text(
                                  'Refresh Network Information',
                                ),
                                onPressed: _loadActiveNetwork,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
    );
  }
}
