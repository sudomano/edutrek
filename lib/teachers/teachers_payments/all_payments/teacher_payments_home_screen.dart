import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/teachers/teachers_payments/all_payments/filter_payments.dart';
import 'package:zitf_system/teachers/teachers_payments/all_payments/payment_purpose/teacher_payments_purpose_home.dart';
import 'package:zitf_system/teachers/teachers_payments/all_payments/teacher_payments_home.dart';

class TeacherPaymentsScreenHome extends StatefulWidget {
  const TeacherPaymentsScreenHome({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<TeacherPaymentsScreenHome> {
  int _selectedIndex = 0;

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index); // Use the navigation logic
  }

  @override
  Widget build(BuildContext context) {
    getLoggedInUser();
    final loggedInUser = getLoggedInUser();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Payments'),
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
                                          children: const [
                                            // Elevated cards with icons
                                            ElevatedCard(
                                              icon: Icons.person_add,
                                              text:
                                                  'Create Purposes For Staff Payments',
                                              target:
                                                  CreateTeacherPaymentsPurposeScreen(),
                                              isLargeScreen: true,
                                            ),

                                            ElevatedCard(
                                              icon: Icons.attach_money,
                                              text: 'Make Payments For Staff',
                                              //textAlign: TextAlign.center,
                                              target: MakeTeacherPayment(),
                                              isLargeScreen: true,
                                            ),
                                            ElevatedCard(
                                              icon: Icons.people,
                                              text: 'Detailed Staff Payments ',
                                              target: ViewByScreens(),
                                              isLargeScreen: true,
                                            ),
                                          ],
                                        )
                                      : const Column(
                                          children: [
                                            // Elevated cards with icons
                                            ElevatedCard(
                                              icon: Icons.person_add,
                                              text:
                                                  'Create Purposes For Staff Payments',
                                              target:
                                                  CreateTeacherPaymentsPurposeScreen(),
                                              isLargeScreen: false,
                                            ),

                                            ElevatedCard(
                                              icon: Icons.attach_money,
                                              text: 'Make Payments For  Staff',
                                              //textAlign: TextAlign.center,
                                              target: MakeTeacherPayment(),
                                              isLargeScreen: false,
                                            ),
                                            ElevatedCard(
                                              icon: Icons.people,
                                              text: 'Ditailed Staff Payments ',
                                              target: ViewByScreens(),
                                              isLargeScreen: false,
                                            ),
                                            ElevatedCard(
                                              icon: Icons.payment,
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
