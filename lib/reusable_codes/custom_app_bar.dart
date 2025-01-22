import 'package:flutter/material.dart';
import 'package:zitf_system/admin/home_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14.0, // Adjust font size
            fontWeight: FontWeight.normal, // Font weight
            color: Colors.white, // Title color
            letterSpacing: 1.2, // Slight letter spacing for elegance
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.home,
              size: 30,
              color:
                  Color.fromARGB(255, 255, 255, 255)), // Edit admin information
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
        ),
      ],
      backgroundColor:
          const Color.fromARGB(255, 38, 140, 191), // AppBar background color
      elevation: 4.0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}


/*

       appBar: const CustomAppBar(title: 'AppBar'),



*/