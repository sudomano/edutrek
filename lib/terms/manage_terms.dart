// screens/manage_terms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/main.dart';
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
import 'package:zitf_system/terms/terms_widgets_build_elevated_card.dart';
import 'package:zitf_system/terms/update_term.dart';
import 'package:zitf_system/terms/view_term.dart';

class ManageTermsScreen extends StatefulWidget {
  const ManageTermsScreen({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<ManageTermsScreen> {
  int _selectedIndex = 0;
  DeviceRole? _deviceRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceRole();
  }

  Future<void> _loadDeviceRole() async {
    final role = await getDeviceRole();
    setState(() {
      _deviceRole = role;
      _isLoading = false;
    });
  }

  void _handleItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    onItemTapped(context, index);
  }

  // ⭐ Helper: Check if device is Host (can perform CRUD operations)
  bool get _isHostDevice => _deviceRole == DeviceRole.host;

  // ⭐ Helper: Check if device is Client (read-only)
  bool get _isClientDevice => _deviceRole == DeviceRole.client;

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

    // ⭐ Check if user has write permissions (Admin or Administration)
    final bool canWrite = (admin || administration || subadmin || secretary);

    // ⭐ Device must be HOST for write operations
    final bool canPerformCRUD = _isHostDevice && canWrite;

    // Show loading indicator
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Terms Management',
        actions: [
          // ⭐ Show device role indicator in AppBar
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isHostDevice
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isHostDevice ? Icons.computer : Icons.phone_android,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isHostDevice ? 'HOST' : 'CLIENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // ⭐ Show current term in AppBar
          if (globalTermId != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Term Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
                    // ⭐ Show access warning for client devices
                    if (_isClientDevice)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.orange.shade100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '📌 Client Mode - View Only',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        bool isLargeScreen = constraints.maxWidth >= 500;
                        int crossAxisCount = 2;

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
                                : null,
                            gradient: isLargeScreen
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(253, 253, 253, 1),
                                      Color.fromARGB(255, 255, 255, 255)
                                    ],
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
                                            crossAxisSpacing: 16,
                                            padding: const EdgeInsets.all(8),
                                            children: _buildGridItems(
                                              admin,
                                              administration,
                                              secretary,
                                              subadmin,
                                              canPerformCRUD,
                                              isLargeScreen,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: _buildListItems(
                                            admin,
                                            administration,
                                            secretary,
                                            subadmin,
                                            canPerformCRUD,
                                            isLargeScreen,
                                          ),
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

  // ⭐ Build grid items with role-based access
  List<Widget> _buildGridItems(
    bool admin,
    bool administration,
    bool secretary,
    bool subadmin,
    bool canPerformCRUD,
    bool isLargeScreen,
  ) {
    final items = <Widget>[];

    // 1. SWITCH TERMS - Available to all authenticated users (Host & Client)
    if (admin || administration || secretary || subadmin) {
      items.add(
        ElevatedCard(
          icon: Icons.swap_horiz,
          text: 'Switch Terms',
          target: const TermSwitcher(),
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // 2. VIEW ALL TERMS - Available to all authenticated users (Host & Client)
    if (admin || administration || secretary || subadmin) {
      items.add(
        ElevatedCard(
          icon: Icons.view_list,
          text: 'View All Terms',
          target: const ViewTermsScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // ⭐ 3. CREATE NEW TERM - ONLY AVAILABLE ON HOST DEVICES
    if (canPerformCRUD && (admin || administration || subadmin)) {
      items.add(
        ElevatedCard(
          icon: Icons.calendar_today,
          text: 'Create New Term',
          target: const TermOptionsScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    } else if (_isClientDevice &&
        (admin || administration || secretary || subadmin)) {
      // Show disabled/read-only version for clients
      items.add(
        _buildDisabledCard(
          icon: Icons.calendar_today,
          text: 'Create New Term (Read-Only)',
          tooltip:
              'Create/Update/Delete operations are only available on Host devices',
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // ⭐ 4. UPDATE TERM - ONLY AVAILABLE ON HOST DEVICES
    if (canPerformCRUD && (admin || administration || subadmin)) {
      items.add(
        buildElevatedCardWithDialog(
          context,
          icon: Icons.update,
          text: 'Update Term',
          isLargeScreen: isLargeScreen,
        ),
      );
    } else if (_isClientDevice &&
        (admin || administration || secretary || subadmin)) {
      items.add(
        _buildDisabledCard(
          icon: Icons.update,
          text: 'Update Term (Read-Only)',
          tooltip:
              'Create/Update/Delete operations are only available on Host devices',
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // ⭐ 5. DELETE TERM - ONLY AVAILABLE ON HOST DEVICES
    if (canPerformCRUD && (admin || administration || subadmin)) {
      items.add(
        ElevatedCard(
          icon: Icons.delete,
          text: 'Delete Term',
          target: const DeleteTermScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    } else if (_isClientDevice &&
        (admin || administration || secretary || subadmin)) {
      items.add(
        _buildDisabledCard(
          icon: Icons.delete,
          text: 'Delete Term (Read-Only)',
          tooltip:
              'Create/Update/Delete operations are only available on Host devices',
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // 6. HOME - Available to all
    if (admin || administration || secretary || subadmin) {
      items.add(
        ElevatedCard(
          icon: Icons.home,
          text: 'Go to Home Page',
          target: const HomeScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    return items;
  }

  // ⭐ Build list items with role-based access
  List<Widget> _buildListItems(
    bool admin,
    bool administration,
    bool secretary,
    bool subadmin,
    bool canPerformCRUD,
    bool isLargeScreen,
  ) {
    final items = <Widget>[];

    items.add(const SizedBox(height: 4));

    // 1. SWITCH TERMS
    if (admin || administration || secretary || subadmin) {
      items.add(
        ElevatedCard(
          icon: Icons.swap_horiz,
          text: 'Switch Terms',
          target: const TermSwitcher(),
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // 2. VIEW ALL TERMS
    if (admin || administration || secretary || subadmin) {
      items.add(
        ElevatedCard(
          icon: Icons.view_list,
          text: 'View All Terms',
          target: const ViewTermsScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // ⭐ 3. CREATE NEW TERM - HOST ONLY
    if (canPerformCRUD && (admin || administration || subadmin)) {
      items.add(
        ElevatedCard(
          icon: Icons.calendar_today,
          text: 'Create New Term',
          target: const TermOptionsScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    } else if (_isClientDevice &&
        (admin || administration || secretary || subadmin)) {
      items.add(
        _buildDisabledCard(
          icon: Icons.calendar_today,
          text: 'Create New Term (Read-Only)',
          tooltip:
              'Create/Update/Delete operations are only available on Host devices',
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // ⭐ 4. UPDATE TERM - HOST ONLY
    if (canPerformCRUD && (admin || administration || subadmin)) {
      items.add(
        buildElevatedCardWithDialog(
          context,
          icon: Icons.update,
          text: 'Update Term',
          isLargeScreen: isLargeScreen,
        ),
      );
    } else if (_isClientDevice &&
        (admin || administration || secretary || subadmin)) {
      items.add(
        _buildDisabledCard(
          icon: Icons.update,
          text: 'Update Term (Read-Only)',
          tooltip:
              'Create/Update/Delete operations are only available on Host devices',
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // ⭐ 5. DELETE TERM - HOST ONLY
    if (canPerformCRUD && (admin || administration || subadmin)) {
      items.add(
        ElevatedCard(
          icon: Icons.delete,
          text: 'Delete Term',
          target: const DeleteTermScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    } else if (_isClientDevice &&
        (admin || administration || secretary || subadmin)) {
      items.add(
        _buildDisabledCard(
          icon: Icons.delete,
          text: 'Delete Term (Read-Only)',
          tooltip:
              'Create/Update/Delete operations are only available on Host devices',
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    // 6. HOME
    if (admin || administration || secretary || subadmin) {
      items.add(
        ElevatedCard(
          icon: Icons.home,
          text: 'Go to Home Page',
          target: const HomeScreen(),
          isLargeScreen: isLargeScreen,
        ),
      );
    }

    return items;
  }

  // ⭐ Build a disabled card for client devices
  Widget _buildDisabledCard({
    required IconData icon,
    required String text,
    required String tooltip,
    required bool isLargeScreen,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
        child: Card(
          elevation: 2,
          color: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Tooltip(
            message: tooltip,
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
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
