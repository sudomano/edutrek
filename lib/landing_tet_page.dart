import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LandingTestPage extends StatefulWidget {
  const LandingTestPage({super.key});

  @override
  State<LandingTestPage> createState() => _LandingTestPageState();
}

class _LandingTestPageState extends State<LandingTestPage> {
  String? username;
  String? role;
  String? userCode;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      username = prefs.getString('username');
      role = prefs.getString('role');
      userCode = prefs.getString('userCode');
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landing Test Page'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Login Successful 🎉',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text('Username: ${username ?? "null"}'),
            Text('Role: ${role ?? "null"}'),
            Text('User Code: ${userCode ?? "null"}'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
