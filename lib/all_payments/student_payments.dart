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

    // Determine device mode
    final isClient = _deviceRole == DeviceRole.client;
    final isHost = _deviceRole == DeviceRole.host;

    // Permissions based on role (device no longer restricts viewing)
    final bool canCreatePayments =
        (admin || administration || secretary || subadmin);
    final bool canViewPayments =
        (admin || administration || secretary || subadmin);
    final bool canReprintReceipts = (admin || administration);
    final bool canUpdatePayments = (admin || administration);
    final bool canDeletePayments = admin;

    // Show a subtle indicator for client mode instead of a warning banner
    final bool isClientMode = isClient;

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
                        int crossAxisCount = 2;
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

                                  // ✅ PROFESSIONAL CLIENT MODE INDICATOR
                                  if (isClientMode && !isHost)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.shade200,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.devices,
                                              size: 18,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Client Mode',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                                Text(
                                                  'Connected to host server',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Connected',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                                            // New Payment - always shown for authorized roles
                                            if (canCreatePayments)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'New Student Payment',
                                                target: MakePaymentScreen(),
                                                isLargeScreen: true,
                                              ),

                                            // View Payments - always shown for authorized roles
                                            if (canViewPayments)
                                              const ElevatedCard(
                                                icon: Icons.list,
                                                text: 'View Student Payments',
                                                target:
                                                    ViewAllStudentPayments(),
                                                isLargeScreen: true,
                                              ),

                                            // Re-print Receipts
                                            if (canReprintReceipts)
                                              const ElevatedCard(
                                                icon: Icons.print,
                                                text: 'Re-Print Receipts',
                                                target: ReceiptHistoryPage(),
                                                isLargeScreen: true,
                                              ),

                                            // Update Payments
                                            if (canUpdatePayments)
                                              const ElevatedCard(
                                                icon: Icons.update,
                                                text: 'Update Student Payments',
                                                target: UpdatePaymentScreen(),
                                                isLargeScreen: true,
                                              ),

                                            // Delete Payments
                                            if (canDeletePayments)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Student Payments',
                                                target:
                                                    DeletePaidStudentBySurname(),
                                                isLargeScreen: true,
                                              ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            // New Payment
                                            if (canCreatePayments)
                                              const ElevatedCard(
                                                icon: Icons.person_add,
                                                text: 'New Student Payment',
                                                target: MakePaymentScreen(),
                                                isLargeScreen: false,
                                              ),

                                            // View Payments
                                            if (canViewPayments)
                                              const ElevatedCard(
                                                icon: Icons.list,
                                                text: 'View Student Payments',
                                                target:
                                                    ViewAllStudentPayments(),
                                                isLargeScreen: false,
                                              ),

                                            // Re-print Receipts
                                            if (canReprintReceipts)
                                              const ElevatedCard(
                                                icon: Icons.print,
                                                text: 'Re-Print Receipts',
                                                target: ReceiptHistoryPage(),
                                                isLargeScreen: false,
                                              ),

                                            // Update Payments
                                            if (canUpdatePayments)
                                              const ElevatedCard(
                                                icon: Icons.update,
                                                text: 'Update Student Payments',
                                                target: UpdatePaymentScreen(),
                                                isLargeScreen: false,
                                              ),

                                            // Delete Payments
                                            if (canDeletePayments)
                                              const ElevatedCard(
                                                icon: Icons.delete,
                                                text: 'Delete Student Payments',
                                                target:
                                                    DeletePaidStudentBySurname(),
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
