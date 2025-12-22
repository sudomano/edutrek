import 'package:flutter/material.dart';

Widget buildBottomNavigationBar({
  required int currentIndex,
  required Function(int) onItemTapped,
}) {
  return BottomNavigationBar(
    type: BottomNavigationBarType.fixed,
    items: const <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.work_history),
        label: 'Projects',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.switch_right_rounded),
        label: 'Terms',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outlined),
        label: 'Profile',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.sync_lock_outlined),
        label: 'Backup',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.backup),
        label: 'Data Sync',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ],
    currentIndex: currentIndex,
    selectedItemColor: const Color(0xFF4CAF50),
    onTap: onItemTapped,
  );
}

void onItemTapped(BuildContext context, int index) {
  switch (index) {
    case 0:
      Navigator.pushNamed(context, '/home');
      break;

    case 1:
      Navigator.pushNamed(context, '/projects');
      break;
    case 2:
      Navigator.pushNamed(context, '/term_switch');
      break;
    case 3:
      Navigator.pushNamed(context, '/profile');
      break;
    case 4:
      Navigator.pushNamed(context, '/backup');
      break;
    case 5:
      Navigator.pushNamed(context, '/sync');
      break;
    case 6:
      Navigator.pushNamed(context, '/settings');
      break;
    default:
      break;
  }
}
/* 


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }





bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),


*/
