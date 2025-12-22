import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceRole { host, client }

class DeveloperRoleSettingsScreen extends StatefulWidget {
  const DeveloperRoleSettingsScreen({Key? key}) : super(key: key);

  @override
  State<DeveloperRoleSettingsScreen> createState() =>
      _DeveloperRoleSettingsScreenState();
}

class _DeveloperRoleSettingsScreenState
    extends State<DeveloperRoleSettingsScreen> {
  DeviceRole? _currentRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = prefs.getString('device_role');

    if (roleString != null) {
      setState(() {
        _currentRole = DeviceRole.values.firstWhere(
          (r) => r.name == roleString,
          orElse: () => DeviceRole.client,
        );
      });
    }
  }

  Future<void> _updateRole(DeviceRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_role', role.name);
    setState(() {
      _currentRole = role;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device role updated to ${role.name.toUpperCase()}'),
      ),
    );
  }

  Widget _buildRoleCard(DeviceRole role) {
    final isSelected = _currentRole == role;
    final label = role == DeviceRole.host ? "HOST" : "CLIENT";

    return Card(
      color: isSelected ? Colors.green.shade100 : null,
      child: ListTile(
        leading: Icon(
          role == DeviceRole.host ? Icons.storage_rounded : Icons.phonelink,
          color: isSelected ? Colors.green : Colors.grey,
        ),
        title: Text(label),
        subtitle: Text("Set this device as a $label"),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: () => _updateRole(role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Role Settings'),
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
                  'Current Device Role',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text("current selection: $_currentRole"),
                const SizedBox(height: 16),
                _buildRoleCard(DeviceRole.host),
                const SizedBox(height: 10),
                _buildRoleCard(DeviceRole.client),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("Restart App"),
                  onPressed: () {
                    // Simulate restart by popping everything and going back to RoleSelectionScreen
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
