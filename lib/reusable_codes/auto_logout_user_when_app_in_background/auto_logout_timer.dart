import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/auto_logout_timer/auto_logou_timer.dart';

class AutoLogoutSettingsScreen extends StatefulWidget {
  @override
  _AutoLogoutSettingsScreenState createState() =>
      _AutoLogoutSettingsScreenState();
}

class _AutoLogoutSettingsScreenState extends State<AutoLogoutSettingsScreen> {
  Box<AutoLogoutSettings>? settingsBox;
  int logoutTimeoutMinutes = 30; // default
  double sliderValue = 30; // For the slider display

  @override
  void initState() {
    super.initState();
    _openSettingsBox();
  }

  Future<void> _openSettingsBox() async {
    settingsBox =
        await Hive.openBox<AutoLogoutSettings>('auto_logout_settings');

    // If the box is empty or doesn't contain the key 'settings', initialize it.
    if (settingsBox!.isEmpty || !settingsBox!.containsKey('settings')) {
      await settingsBox!.put('settings', AutoLogoutSettings());
    }
    final settings = settingsBox!.get('settings');
    if (settings != null) {
      logoutTimeoutMinutes = settings.logoutTimeoutMinutes;
      sliderValue = logoutTimeoutMinutes.toDouble();
    }
    setState(() {});
  }

  Future<void> _saveSettings() async {
    // Check if the settingsBox is loaded.
    if (settingsBox == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings not loaded yet")),
      );
      return;
    }

    // Try to retrieve the settings.
    AutoLogoutSettings? settings = settingsBox!.get('settings');

    // If settings is null, initialize it with default values.
    if (settings == null) {
      settings = AutoLogoutSettings(logoutTimeoutMinutes: logoutTimeoutMinutes);
      await settingsBox!.put('settings', settings);
    } else {
      // Otherwise update the existing settings.
      settings.logoutTimeoutMinutes = logoutTimeoutMinutes;
      await settings.save();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auto Logout Settings"),
        centerTitle: true,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Set the auto-logout timeout (in minutes):",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Display a slider to choose the value.
                Slider(
                  value: sliderValue,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: "$sliderValue minute(s)",
                  onChanged: (newValue) {
                    setState(() {
                      sliderValue = newValue;
                      logoutTimeoutMinutes = newValue.round();
                    });
                  },
                ),
                Text(
                  "$logoutTimeoutMinutes minute(s)",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                /* ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save Settings",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                */
              ],
            ),
          ),
        ),
      ),
    );
  }
}
