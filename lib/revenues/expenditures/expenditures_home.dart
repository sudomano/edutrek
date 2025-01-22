import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts

import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/revenues/expenditures/expenditures.dart';
import 'package:zitf_system/revenues/expenditures/filter_expenditures.dart';
import 'package:zitf_system/revenues/expenditures/withdraw.dart';

class ExpendituresHome extends StatefulWidget {
  const ExpendituresHome({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<ExpendituresHome> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();
    final role = loggedInUser.role;
    final user = loggedInUser.username;
    final admin = loggedInUser?.role.toLowerCase() == 'admin';
    final secretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser?.role.toLowerCase() == 'teacher';

    final accountant = loggedInUser?.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser?.role.toLowerCase() == 'sub-admin';

    return Scaffold(
      appBar: const CustomAppBar(title: 'Withdrawals'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth >= 600;
          // Adjust crossAxisCount based on screen width
          int crossAxisCount = 2; // Default 2 items per row
          double crossAxisSpacing = 16.0;

          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 3;
            crossAxisSpacing = 10.0;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 3;
            crossAxisSpacing = 1.0;
          } else if (constraints.maxWidth >= 600) {
            crossAxisCount = 3;
            crossAxisSpacing = 4.0;
          } else {
            crossAxisCount = 1;
            crossAxisSpacing = 2.0;
          }
          return Container(
            decoration: BoxDecoration(
              color: isLargeScreen
                  ? Color.fromRGBO(0, 233, 254, 1)
                  : null, // Set white background for large screens
              gradient: isLargeScreen
                  ? null
                  : const LinearGradient(
                      colors: [
                        Color.fromRGBO(0, 233, 254, 1),
                        Color.fromARGB(255, 1, 80, 71)
                      ], // Gradient colors for small screens
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 5,
                    ),
                    buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      'Expenditure Home',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.normal,
                        color: const Color.fromARGB(
                            255, 0, 0, 0), // White text on gradient
                      ),
                      textAlign: TextAlign.center,
                    ),
                    isLargeScreen
                        ? GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: crossAxisSpacing,
                            padding: const EdgeInsets.all(8),
                            children: [
                              // Elevated cards with icons
                              ElevatedCard(
                                icon: Icons.attach_money,
                                text: 'Make A Withdrawals',
                                target: WithdrawalScreen(),
                                isLargeScreen: true,
                              ),
                              ElevatedCard(
                                icon: Icons.attach_money,
                                text: 'Update Withdrawals',
                                target: ViewWithdrawalsScreen(),
                                isLargeScreen: true,
                              ),
                              if (admin || accountant)
                                ElevatedCard(
                                  icon: Icons.attach_money,
                                  text: 'View Income and Expenditure Details',
                                  target: ViewWithdrawalsScreen1(),
                                  isLargeScreen: true,
                                ),
                            ],
                          )
                        : Column(
                            children: [
                              // Elevated cards with icons
                              ElevatedCard(
                                icon: Icons.attach_money,
                                text: 'Make A Withdrawals',
                                target: WithdrawalScreen(),
                                isLargeScreen: false,
                              ),
                              ElevatedCard(
                                icon: Icons.attach_money,
                                text: 'Update Withdrawals',
                                target: ViewWithdrawalsScreen(),
                                isLargeScreen: false,
                              ),
                              if (admin || accountant)
                                ElevatedCard(
                                  icon: Icons.attach_money,
                                  text: 'View Income and Expenditure Details',
                                  target: ViewWithdrawalsScreen1(),
                                  isLargeScreen: false,
                                ),
                              const ElevatedCard(
                                icon: Icons.home,
                                text: 'Go to Home Page',
                                target: HomeScreen(),
                                isLargeScreen: false,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: buildBottomNavigationBar(
        currentIndex: _selectedIndex,
        onItemTapped: _handleItemTapped,
      ),
    );
  }
}
