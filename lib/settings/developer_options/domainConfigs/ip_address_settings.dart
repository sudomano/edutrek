import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IpAddressSettings extends StatefulWidget {
  const IpAddressSettings({Key? key}) : super(key: key);

  @override
  State<IpAddressSettings> createState() => _IpAddressSettingsState();
}

class _IpAddressSettingsState extends State<IpAddressSettings> {
  final TextEditingController _ipController = TextEditingController();
  String? _currentIp;

  @override
  void initState() {
    super.initState();
    _loadIpAddress();
  }

  Future<void> _loadIpAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('host_ip');
    setState(() {
      _currentIp = ip;
      _ipController.text = ip ?? '';
    });
  }

  Future<void> _saveIpAddress() async {
    final newIp = _ipController.text.trim();

    if (newIp.isEmpty || !RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(newIp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Enter a valid IPv4 address.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host_ip', newIp);
    setState(() => _currentIp = newIp);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ IP Address updated to $newIp")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host IP Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const Text(
                  'Current Host IP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _currentIp ?? 'No IP saved yet.',
                  style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter Host IP (e.g. 192.168.137.1)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save IP Address'),
                  onPressed: _saveIpAddress,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("Restart App"),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
