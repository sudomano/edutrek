import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Custom fonts
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/main.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/custom_drawer_admin.dart';
import 'package:zitf_system/reusable_codes/custom_drawers/retrieve_logged_user_helper.dart';
import 'package:zitf_system/reusable_codes/footer/footer.dart';
import 'package:zitf_system/reusable_codes/school_logo/school_logo.dart';
import 'package:zitf_system/reusable_codes/widget_builders/build_elevated_card.dart';
import 'package:zitf_system/student_payments/delete_paid_student.dart';
import 'package:zitf_system/student_payments/make_student_payment.dart';
import 'package:zitf_system/student_payments/receipt_history_page.dart';
import 'package:zitf_system/student_payments/update_student_payments.dart';
import 'package:zitf_system/student_payments/view_all_paid_students.dart';

class MakePayment extends StatefulWidget {
  const MakePayment({super.key});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MakePayment> {
  int _selectedIndex = 0;
  DeviceRole? _deviceRole;

  @override
  void initState() {
    super.initState();
    _getDeviceRole();
  }

  Future<void> _getDeviceRole() async {
    final role = await getDeviceRole();
    setState(() {
      _deviceRole = role;
    });
  }

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

    // User role checks
    final admin = loggedInUser?.role.toLowerCase() == 'admin';
    final secretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final teacher = loggedInUser?.role.toLowerCase() == 'teacher';
    final accountant = loggedInUser?.role.toLowerCase() == 'accountant';
    final subadmin = loggedInUser?.role.toLowerCase() == 'sub-admin';
    final administration = loggedInUser.role.toLowerCase() == 'administration';

    // CONDITIONAL: Check if device is client - if so, hide view/update/delete
    final isClient = _deviceRole == DeviceRole.client;
    final isHost = _deviceRole == DeviceRole.host;

    // Determine what permissions to show based on role AND device type
    final bool canCreatePayments =
        (admin || administration || secretary || subadmin);
    final bool canViewPayments =
        (admin || administration || secretary || subadmin) && !isClient;
    final bool canReprintReceipts = (admin || administration) && !isClient;
    final bool canUpdatePayments = (admin || administration) && !isClient;
    final bool canDeletePayments = admin && !isClient;

    // Special case: If device is client, only show limitFed functionality
    // For clients, we might want to show only view if they have permission
    final bool showLimitedView =
        isClient && (!admin || !administration || !secretary || !subadmin);

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
                          crossAxisCount = 5;
                        } else if (constraints.maxWidth >= 1000) {
                          crossAxisCount = 5;
                        } else if (constraints.maxWidth >= 800) {
                          crossAxisCount = 5;
                        } else if (constraints.maxWidth >= 600) {
                          crossAxisCount = 5;
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
                                ? const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(255, 255, 255, 1),
                                      Color.fromARGB(255, 255, 255, 255)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(255, 255, 255, 1),
                                      Color.fromARGB(255, 255, 255, 255)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  buildFutureSchoolsWidget(
                                      isLargeScreen: isLargeScreen),

                                  // If device is client, show a message about limited access
                                  if (isClient && !isHost)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.orange[300]!),
                                        ),
                                        child: const Column(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: Colors.orange,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Client Mode - Limited Access',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'You are connected as a client. Some features may be restricted.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  isLargeScreen
                                      ? GridView.count(
                                          crossAxisCount: crossAxisCount,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          crossAxisSpacing: crossAxisSpacing,
                                          padding: const EdgeInsets.all(8),
                                          children: [
                                            // CONDITIONAL: Show payment creation - only if not client
                                            if (canCreatePayments)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'New Student Payment',
                                                target: MakePaymentScreen(),
                                                isLargeScreen: true,
                                              ),

                                            // CONDITIONAL: Show view payments - only if not client
                                            if (canViewPayments)
                                              const ElevatedCard(
                                                icon: Icons.list,
                                                text: 'View Student Payments',
                                                target:
                                                    ViewAllStudentPayments(),
                                                isLargeScreen: true,
                                              ),

                                            // CONDITIONAL: Show reprint receipts - only if not client
                                            if (canReprintReceipts)
                                              const ElevatedCard(
                                                icon: Icons.print,
                                                text: 'Re-Print Receipts',
                                                target: ReceiptHistoryPage(),
                                                isLargeScreen: true,
                                              ),

                                            // CONDITIONAL: Show update payments - only if not client
                                            if (canUpdatePayments)
                                              const ElevatedCard(
                                                icon: Icons.update,
                                                text: 'Update Student Payments',
                                                target: UpdatePaymentScreen(),
                                                isLargeScreen: true,
                                              ),

                                            // CONDITIONAL: Show delete payments - only if not client
                                            if (canDeletePayments)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Student Payments',
                                                target:
                                                    DeletePaidStudentBySurname(),
                                                isLargeScreen: true,
                                              ),

                                            // CONDITIONAL: If client and has view permission, show limited view
                                            if (showLimitedView)
                                              const ElevatedCard(
                                                icon: Icons.visibility,
                                                text:
                                                    'View Payments (Read Only)',
                                                target:
                                                    ViewAllStudentPayments(),
                                                isLargeScreen: true,
                                              ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            // CONDITIONAL: Show payment creation - only if not client
                                            if (canCreatePayments)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'New Student Payment',
                                                target: MakePaymentScreen(),
                                                isLargeScreen: false,
                                              ),

                                            // CONDITIONAL: Show view payments - only if not client
                                            if (canViewPayments)
                                              const ElevatedCard(
                                                icon: Icons.list,
                                                text: 'View Student Payments',
                                                target:
                                                    ViewAllStudentPayments(),
                                                isLargeScreen: false,
                                              ),

                                            // CONDITIONAL: Show reprint receipts - only if not client
                                            if (canReprintReceipts)
                                              const ElevatedCard(
                                                icon: Icons.print,
                                                text: 'Re-Print Receipts',
                                                target: ReceiptHistoryPage(),
                                                isLargeScreen: false,
                                              ),

                                            // CONDITIONAL: Show update payments - only if not client
                                            if (canUpdatePayments)
                                              const ElevatedCard(
                                                icon: Icons.update,
                                                text: 'Update Student Payments',
                                                target: UpdatePaymentScreen(),
                                                isLargeScreen: false,
                                              ),

                                            // CONDITIONAL: Show delete payments - only if not client
                                            if (canDeletePayments)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Student Payments',
                                                target:
                                                    DeletePaidStudentBySurname(),
                                                isLargeScreen: false,
                                              ),

                                            // CONDITIONAL: If client and has view permission, show limited view
                                            if (showLimitedView)
                                              const ElevatedCard(
                                                icon: Icons.visibility,
                                                text:
                                                    'View Payments (Read Only)',
                                                target:
                                                    ViewAllStudentPayments(),
                                                isLargeScreen: false,
                                              ),

                                            // Home button - always shown
                                            if (admin ||
                                                administration ||
                                                secretary ||
                                                subadmin)
                                              const ElevatedCard(
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
