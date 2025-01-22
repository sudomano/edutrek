import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/admin/purpose_home_screen.dart';
import 'package:zitf_system/all_payments/payments_home.dart';
import 'package:zitf_system/classes/classes_home.dart';
import 'package:zitf_system/registers/registershome.dart';
import 'package:zitf_system/revenues/accounts_vs_incomes_home.dart';
import 'package:zitf_system/revenues/expenditures/expenditures_home.dart';
import 'package:zitf_system/school_info/school_home.dart';
import 'package:zitf_system/student_management/create_students/student_home.dart';
import 'package:zitf_system/teachers/teachers_creations/create_teachers_Home/teachers_options.dart';
import 'package:zitf_system/teachers/teachers_payments/all_payments/payment_purpose/teacher_payments_purpose_home.dart';
import 'package:zitf_system/terms/manage_terms.dart';
import 'package:zitf_system/auth/userdb.dart';

class CustomDrawerAdmin extends StatelessWidget {
  final User? loggedInUser;

  CustomDrawerAdmin({Key? key, required this.loggedInUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAdmin = loggedInUser?.role.toLowerCase() == 'admin';
    final isSecretary = loggedInUser?.role.toLowerCase() == 'secretary';
    final isTeacher = loggedInUser?.role.toLowerCase() == 'teacher';

    final isAccounttant = loggedInUser?.role.toLowerCase() == 'accountant';
    final isSubAdmin = loggedInUser?.role.toLowerCase() == 'sub-admin';

    const EdgeInsets.only(left: 48.0); // Adjust the left padding

    return Center(
      child: Drawer(
        child: Container(
          color: const Color.fromRGBO(
              240, 240, 240, 1), // Background color for the entire drawer

          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 250,
            ),
            child: IntrinsicWidth(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 100,
                    child: DrawerHeader(
                      decoration: const BoxDecoration(
                        color: Color.fromRGBO(1, 120, 131, 1),
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${loggedInUser?.username ?? "User"}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${loggedInUser?.role ?? "Role"}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Back Button
                  ListTile(
                    leading:
                        const Icon(Icons.arrow_back, color: Colors.blueAccent),
                    title: Text(
                      'Back',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.0,
                        fontWeight: FontWeight.normal,
                        color: const Color.fromARGB(255, 0, 0, 0),
                        letterSpacing: 1.2,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer and go back
                    },
                  ),
                  const Divider(),
                  if (isAdmin || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.info,
                      text: 'School Information',
                      target: const SchoolHomeScreen(),
                    ),
                  if (isAdmin || isSecretary || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.date_range,
                      text: 'School Terms',
                      target: const ManageTermsScreen(),
                    ),
                  if (isAdmin || isSecretary || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.class_,
                      text: 'School Classes',
                      target: const ClassesHomeScreen(),
                    ),
                  if (isAdmin || isSecretary || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.school,
                      text: 'School Students',
                      target: const CreateStudents(),
                    ),
                  if (isAdmin || isSecretary || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.payment,
                      text: 'Student Payment Purposes',
                      target: const Createpayments(),
                    ),
                  if (isAdmin || isSecretary || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.attach_money,
                      text: ' Student Payments',
                      target: const PurposeHome(),
                    ),
                  if (isAdmin || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.work_outline,
                      text: 'Staff Payment Purposes',
                      target: const CreateTeacherPaymentsPurposeScreen(),
                    ),
                  if (isAdmin || isSubAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.person,
                      text: 'School Staff Payments',
                      target: const CreateTeachersoption(),
                    ),
                  if (isAdmin || isSubAdmin || isAccounttant)
                    _buildDrawerItem(
                      context,
                      icon: Icons.account_balance_wallet,
                      text: 'Incomes',
                      target: const AccountsVsIncomesHome(),
                    ),
                  if (isAdmin || isSubAdmin || isAccounttant)
                    _buildDrawerItem(
                      context,
                      icon: Icons.money_off,
                      text: 'Expenditures',
                      target: const ExpendituresHome(),
                    ),
                  if (isAdmin || isSecretary || isSubAdmin || isTeacher)
                    _buildDrawerItem(
                      context,
                      icon: Icons.fact_check,
                      text: 'Registers',
                      target: const RegistersHomeScreen(),
                    ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.home,
                    text: 'Home',
                    target: const HomeScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Widget target,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13.0, // Adjust font size
          fontWeight: FontWeight.normal, // Font weight
          color: const Color.fromARGB(255, 0, 0, 0), // Title color
          letterSpacing: 1.2, // Slight letter spacing for elegance
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => target),
        );
      },
    );
  }
}
