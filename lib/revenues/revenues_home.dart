import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/all_payments/filter_payments.dart';
import 'package:zitf_system/arrears_and_prepayments/arrears_and_prepayments.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/revenues/expenditures/expenditures_home.dart';
import 'package:zitf_system/revenues/incomes/revenue_filter.dart';
import 'package:zitf_system/revenues/incomes/summarised_incomes.dart';

class RevenuesHome extends StatefulWidget {
  const RevenuesHome({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<RevenuesHome> {
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
    final administration = loggedInUser.role.toLowerCase() == 'administration';

    return Scaffold(
      appBar: const CustomAppBar(title: 'Incomes and Expenditures'),

      // Use the custom drawer here

      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (constraints.maxWidth >= 500)
                SizedBox(
                  width: 250,
                  child: CustomDrawerAdmin(loggedInUser: loggedInUser),
                ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        bool isLargeScreen = constraints.maxWidth >= 500;
                        // Adjust crossAxisCount based on screen width
                        int crossAxisCount = 2; // Default 2 items per row
                        double crossAxisSpacing = 16.0;

                        if (constraints.maxWidth >= 1200) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 1000) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 800) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 600) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 400) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 300) {
                          crossAxisCount = 2;
                        } else {
                          crossAxisCount = 1;
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: isLargeScreen
                                ? const Color.fromRGBO(255, 255, 255, 1)
                                : null, // Set white background for large screens
                            gradient: isLargeScreen
                                ? const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(255, 255, 255, 1),
                                      Color.fromARGB(255, 255, 255, 255)
                                    ], // Gradient colors for small screens
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(255, 255, 255, 1),
                                      Color.fromARGB(255, 255, 255, 255)
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
                                  buildFutureSchoolsWidget(
                                      isLargeScreen: isLargeScreen),
                                  isLargeScreen
                                      ? GridView.count(
                                          crossAxisCount: crossAxisCount,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          crossAxisSpacing: crossAxisSpacing,
                                          padding: const EdgeInsets.all(8),
                                          children: [
                                            // Elevated cards with icons
                                            if (admin ||
                                                administration ||
                                                subadmin ||
                                                accountant)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'Summerised Incomes',
                                                target: SummarizedIncomes(),
                                                isLargeScreen: true,
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin ||
                                                accountant)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'Detailed Incomes',
                                                //target: ViewAllRevenuesFilter(),
                                                target:
                                                    StudentsArrearsStatementScreen(),
                                                isLargeScreen: true,
                                              ),

                                            const ElevatedCard(
                                              icon: Icons.people,
                                              text: 'Expenditures',
                                              target: ExpendituresHome(),
                                              isLargeScreen: true,
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            if (admin ||
                                                administration ||
                                                subadmin) // Elevated cards with icons
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'Summerised Incomes',
                                                target: SummarizedIncomes(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin ||
                                                administration ||
                                                subadmin)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'Detailed Incomes',
                                                target: ViewAllRevenuesFilter(),
                                                isLargeScreen: false,
                                              ),
                                            const ElevatedCard(
                                              icon: Icons.people,
                                              text: 'Expenditures',
                                              target: ExpendituresHome(),
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
                      }),
                    ),
                  ],
                ),
              ),
            ],
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
