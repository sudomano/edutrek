import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSettingsPage extends StatefulWidget {
  const DeviceSettingsPage({Key? key}) : super(key: key);

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  bool _termAggregation = false; // Default value
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _termAggregation = prefs.getBool('termAggregation') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateTermAggregation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termAggregation', value);
    setState(() {
      _termAggregation = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? '✅ Term aggregation enabled' : '❌ Term aggregation disabled',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Settings',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: const Text(
              'Enable Term Aggregation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'When enabled, term payments will be aggregated across all terms.',
            ),
            trailing: Switch(
              value: _termAggregation,
              activeColor: Colors.green,
              onChanged: _updateTermAggregation,
            ),
          ),
        ),
      ),
    );
  }
}
