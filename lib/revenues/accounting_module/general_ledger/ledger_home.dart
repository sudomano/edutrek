import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/admin/home_screen.dart';

import 'package:zitf_system/export_import_backup_data/export.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/revenues/revenues_home.dart';

class GeneralLedger extends StatelessWidget {
  const GeneralLedger({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedInUser = getLoggedInUser();

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'General Ledger',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.normal),
            textAlign: TextAlign.center, // Custom font
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home,
                size: 30, color: Colors.blue), // Edit admin information
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            },
          ),
        ],
        backgroundColor: Color.fromARGB(255, 234, 251, 253),
      ),
      //************* */
      // Add the drawer (sidebar)
      drawer: CustomDrawerAdmin(
        loggedInUser: loggedInUser,
      ), // Use the custom drawer here
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth >= 600;
          // Adjust crossAxisCount based on screen width
          int crossAxisCount = 2; // Default 2 items per row
          double crossAxisSpacing = 16.0;

          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 5;
            crossAxisSpacing = 10.0;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 5;
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
                    Text(
                      'General Ledger Records ',
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

                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Assets',
                                target: RevenuesHome(),
                                isLargeScreen: true,
                              ),
                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Liabilities',
                                target: RevenuesHome(),
                                isLargeScreen: true,
                              ),
                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Revenues',
                                target: RevenuesHome(),
                                isLargeScreen: true,
                              ),
                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Expenses',
                                target: RevenuesHome(),
                                isLargeScreen: true,
                              ),
                              ElevatedCard(
                                icon: Icons.money_off,
                                text: 'Equity ',
                                target: ExportClassesPages(),
                                isLargeScreen: true,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              // Elevated cards with icons

                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Assets',
                                target: RevenuesHome(),
                                isLargeScreen: false,
                              ),
                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Liabilities',
                                target: RevenuesHome(),
                                isLargeScreen: false,
                              ),
                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Revenues',
                                target: RevenuesHome(),
                                isLargeScreen: false,
                              ),
                              const ElevatedCard(
                                icon: Icons.money,
                                text: 'Expenses',
                                target: RevenuesHome(),
                                isLargeScreen: false,
                              ),
                              ElevatedCard(
                                icon: Icons.money_off,
                                text: 'Equity',
                                target: ExportClassesPages(),
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
    );
  }
}
