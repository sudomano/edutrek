import 'package:flutter/material.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/screens/network_settings/network_settings_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions; // ✅ Allow external actions

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions, // ✅ Optional
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      actions: [
        ...(actions ?? []), // ✅ Custom passed actions (if any)
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NetworkSettingsScreen()),
            );
          },
          tooltip: 'Network Settings',
        ),
        IconButton(
          icon: const Icon(
            Icons.home,
            size: 30,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
        ),
      ],
      backgroundColor: const Color.fromARGB(255, 38, 140, 191),
      elevation: 4.0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}



/*

       appBar: const CustomAppBar(title: 'AppBar'),



*/