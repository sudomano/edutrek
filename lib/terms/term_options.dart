import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/terms/close_term.dart';
import 'package:zitf_system/terms/create_term.dart';

class TermOptionsScreen extends StatelessWidget {
  const TermOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Term Option'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth >= 600;
          // Adjust crossAxisCount based on screen width
          int crossAxisCount = 2; // Default 2 items per row
          double crossAxisSpacing = 16.0;

          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 2;
            crossAxisSpacing = 10.0;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 2;
            crossAxisSpacing = 1.0;
          } else if (constraints.maxWidth >= 600) {
            crossAxisCount = 2;
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
                    Text(
                      'Create Terms',
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
                            children: const [
                              ElevatedCard(
                                icon: Icons.calendar_today,
                                text: 'Start New Term',
                                target: CreateTermScreen(),
                                isLargeScreen: true,
                              ),
                              ElevatedCard(
                                icon: Icons.view_list,
                                text: 'Close Term',
                                target: CloseTermScreen(),
                                isLargeScreen: true,
                              ),
                            ],
                          )
                        : const Column(
                            children: [
                              ElevatedCard(
                                icon: Icons.calendar_today,
                                text: 'Start New Term',
                                target: CreateTermScreen(),
                                isLargeScreen: false,
                              ),
                              ElevatedCard(
                                icon: Icons.view_list,
                                text: 'Close Term',
                                target: CloseTermScreen(),
                                isLargeScreen: false,
                              ),
                              ElevatedCard(
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
    );
  }
}
