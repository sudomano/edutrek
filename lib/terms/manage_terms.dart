import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/edutrek_pic/edutrek_pic.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/terms/delete_term.dart';
import 'package:zitf_system/terms/search_term.dart';
import 'package:zitf_system/terms/term_options.dart';
import 'package:zitf_system/terms/term_switcher.dart';
import 'package:zitf_system/terms/update_term.dart';
import 'package:zitf_system/terms/view_term.dart';

class ManageTermsScreen extends StatefulWidget {
  const ManageTermsScreen({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<ManageTermsScreen> {
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
      appBar: const CustomAppBar(title: 'Terms Management'),
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
                          crossAxisCount = 6;
                        } else if (constraints.maxWidth >= 1000) {
                          crossAxisCount = 5;
                        } else if (constraints.maxWidth >= 800) {
                          crossAxisCount = 4;
                        } else if (constraints.maxWidth >= 600) {
                          crossAxisCount = 4;
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
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(253, 253, 253, 1),
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
                                      ? Center(
                                          child: GridView.count(
                                            crossAxisCount: crossAxisCount,
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            crossAxisSpacing: crossAxisSpacing,
                                            padding: const EdgeInsets.all(8),
                                            children: [
                                              if (admin ||
                                                  secretary ||
                                                  subadmin)
                                                ElevatedCard(
                                                  icon: Icons.swap_horiz,
                                                  text: 'Switch Terms',
                                                  target: TermSwitcher(),
                                                  isLargeScreen: true,
                                                ),
                                              if (admin || subadmin)
                                                const ElevatedCard(
                                                  icon: Icons.calendar_today,
                                                  text: 'Create New Term',
                                                  target: TermOptionsScreen(),
                                                  isLargeScreen: true,
                                                ),
                                              if (admin ||
                                                  secretary ||
                                                  subadmin)
                                                const ElevatedCard(
                                                  icon: Icons.view_list,
                                                  text: 'View All Terms',
                                                  target: ViewTermsScreen(),
                                                  isLargeScreen: true,
                                                ),
                                              if (admin || subadmin)
                                                buildElevatedCardWithDialog(
                                                  context,
                                                  icon: Icons.update,
                                                  text: 'Update Term',
                                                  isLargeScreen: true,
                                                ),
                                              if (admin || subadmin)
                                                const ElevatedCard(
                                                  icon: Icons.delete,
                                                  text: 'Delete Term',
                                                  target: DeleteTermScreen(),
                                                  isLargeScreen: true,
                                                ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            const SizedBox(height: 4),
                                            if (admin || secretary || subadmin)
                                              ElevatedCard(
                                                icon: Icons.swap_horiz,
                                                text: 'Switch Terms',
                                                target: TermSwitcher(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin || subadmin)
                                              const ElevatedCard(
                                                icon: Icons.calendar_today,
                                                text: 'Create New Term',
                                                target: TermOptionsScreen(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin || secretary || subadmin)
                                              const ElevatedCard(
                                                icon: Icons.view_list,
                                                text: 'View All Terms',
                                                target: ViewTermsScreen(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin || subadmin)
                                              buildElevatedCardWithDialog(
                                                context,
                                                icon: Icons.update,
                                                text: 'Update Term',
                                                isLargeScreen: false,
                                              ),
                                            if (admin || subadmin)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Term',
                                                target: DeleteTermScreen(),
                                                isLargeScreen: false,
                                              ),
                                            if (admin || secretary || subadmin)
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

// Centralized function for building elevated cards with dialog
Widget buildElevatedCardWithDialog(
  BuildContext context, {
  required IconData icon,
  required String text,
  bool isLargeScreen = false, // Flag to check screen size
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
      child: Card(
        elevation: 4,
        color: isLargeScreen ? Colors.white : Colors.blueGrey[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () async {
            final Box<Terms> box = Hive.box<Terms>('terms');
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Center(
                    child: Text(
                      'Select Term to Update',
                      style: GoogleFonts.montserrat(
                        fontSize: isLargeScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                            currentClass!.termId,
                            style: GoogleFonts.montserrat(
                              fontSize: isLargeScreen ? 14 : 14,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UpdateTermScreen(index: index),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
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
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: const Color.fromARGB(255, 0, 43, 92),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: const Color.fromARGB(255, 0, 43, 92),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 0, 0, 0),
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
