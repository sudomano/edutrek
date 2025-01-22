import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/database/accounting_module_models/account_type.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';

import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/revenues/accounting_module/general_ledger/transactional_entries/account_entries_table/create_acccout_entries.dart';
import 'package:zitf_system/revenues/accounting_module/general_ledger/transactional_entries/account_entries_table/delete_account_entries.dart';
import 'package:zitf_system/revenues/accounting_module/general_ledger/transactional_entries/account_entries_table/update_account_entries.dart';
import 'package:zitf_system/revenues/accounting_module/general_ledger/transactional_entries/account_entries_table/view_account_entries.dart';
import 'package:zitf_system/revenues/accounting_module/general_ledger/transactional_entries/asset_entries/create_asset_entries.dart';
import 'package:zitf_system/revenues/accounting_module/general_ledger/transactional_entries/asset_entries/view_asset_entries.dart';

class AssetEntriesHome extends StatefulWidget {
  const AssetEntriesHome({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<AssetEntriesHome> {
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

    return Scaffold(
      appBar: const CustomAppBar(title: 'Assets'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLargeScreen = constraints.maxWidth >= 600;
          // Adjust crossAxisCount based on screen width
          int crossAxisCount = 2; // Default 2 items per row
          double crossAxisSpacing = 16.0;

          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 4;
            crossAxisSpacing = 10.0;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 4;
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
                      'Assets Entries',
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
                                icon: Icons.view_agenda,
                                text: 'View Asset',
                                target: ViewAssetEntries(),
                                isLargeScreen: true,
                              ),
                              ElevatedCard(
                                icon: Icons.add,
                                text: 'Add Asset',
                                target: AssetAcquisitionForm(),
                                isLargeScreen: true,
                              ),

                              _buildElevatedCardWithDialog(
                                context,
                                icon: Icons.update,
                                text: 'Update Asset',
                                isLargeScreen: true,
                              ),
                              const ElevatedCard(
                                icon: Icons.delete,
                                text: 'Delete Asset',
                                target: DeleteAccountScreen(),
                                isLargeScreen: true,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              // Elevated cards with icons

                              const ElevatedCard(
                                icon: Icons.view_agenda,
                                text: 'View Asset ',
                                target: ViewAssetEntries(),
                                isLargeScreen: false,
                              ),
                              ElevatedCard(
                                icon: Icons.add,
                                text: 'Add Asset ',
                                target: AssetAcquisitionForm(),
                                isLargeScreen: false,
                              ),

                              _buildElevatedCardWithDialog(
                                context,
                                icon: Icons.update,
                                text: 'Update Asset ',
                                isLargeScreen: false,
                              ),
                              const ElevatedCard(
                                icon: Icons.delete,
                                text: 'Delete Asset ',
                                target: DeleteAccountScreen(),
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

Widget _buildElevatedCardWithDialog(
  BuildContext context, {
  required IconData icon,
  required String text,
  bool isLargeScreen = false, // Flag to check screen size
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
      child: Card(
        elevation: 4.0,
        color: isLargeScreen
            ? Colors.white
            : Colors.blueGrey[50], // Background color for large screens
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () async {
            final Box<Account> box = Hive.box<Account>('account');
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(
                    'Select Account to Update',
                    style: GoogleFonts.montserrat(
                        fontSize: isLargeScreen ? 18 : 20,
                        fontWeight: FontWeight.bold),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: box.length,
                      itemBuilder: (context, index) {
                        final currentClass = box.getAt(index);
                        return ListTile(
                          title: Text(
                            currentClass!.accountName.toString(),
                            style: GoogleFonts.montserrat(
                              fontSize: isLargeScreen ? 14 : 16,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UpdateAccountScreen(index: index),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            constraints: isLargeScreen
                ? const BoxConstraints(minWidth: 400, maxWidth: 400)
                : null,
            padding: const EdgeInsets.all(16.0),
            child: isLargeScreen
                // For large screens, icon above the text
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 30, // Larger icon size for large screens
                        color: Colors.blue.shade800,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                // For smaller screens, icon next to the text
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 30,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
