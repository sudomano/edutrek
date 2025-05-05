import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/admin/home_screen.dart';
import 'package:zitf_system/admin/purpose_home_screen.dart';
import 'package:zitf_system/all_payments/payments_home.dart';
import 'package:zitf_system/classes/classes_home.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
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
    final currentTerm = globalTermId;

    return LayoutBuilder(builder: (context, constraints) {
      bool isLargeScreen = constraints.maxWidth >= 500;

      return Container(
        width: 50,
        color: const Color.fromRGBO(240, 240, 240, 1),
        child: Column(
          children: [
            Container(
              height: 50,
              color: const Color.fromARGB(255, 218, 218, 218),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      child: Text(
                        currentTerm?.toUpperCase() ?? "NO SELECTED TERM YET!",
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        loggedInUser?.role ?? "Role",
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: const Color.fromARGB(179, 0, 0, 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (isAdmin || isSubAdmin)
                        _drawerItem(context, Icons.info, 'School Info',
                            () => _navigate(context, const SchoolHomeScreen())),
                      const Divider(),
                      if (isAdmin || isSecretary || isSubAdmin)
                        _drawerItem(
                            context,
                            Icons.date_range,
                            'School Terms',
                            () =>
                                _navigate(context, const ManageTermsScreen())),
                      const Divider(),
                      if (isAdmin || isSecretary || isSubAdmin)
                        _drawerItem(
                            context,
                            Icons.class_,
                            'School Classes',
                            () =>
                                _navigate(context, const ClassesHomeScreen())),
                      const Divider(),
                      if (isAdmin || isSecretary || isSubAdmin)
                        _drawerItem(context, Icons.school, 'School Students',
                            () => _navigate(context, const CreateStudents())),
                      const Divider(),
                      if (isAdmin || isSecretary || isSubAdmin)
                        _drawerItem(context, Icons.payment, 'Student  Purposes',
                            () => _navigate(context, const Createpayments())),
                      const Divider(),
                      if (isAdmin || isSecretary || isSubAdmin)
                        _drawerItem(
                            context,
                            Icons.attach_money,
                            'Student Payments',
                            () => _navigate(context, const PurposeHome())),
                      const Divider(),
                      if (isAdmin || isSubAdmin)
                        _drawerItem(
                            context,
                            Icons.work_outline,
                            'Staff  Purposes',
                            () => _navigate(context,
                                const CreateTeacherPaymentsPurposeScreen())),
                      const Divider(),
                      if (isAdmin || isSubAdmin)
                        _drawerItem(
                            context,
                            Icons.person,
                            'Staff Payments',
                            () => _navigate(
                                context, const CreateTeachersoption())),
                      const Divider(),
                      if (isAdmin || isSubAdmin || isAccounttant)
                        _drawerItem(
                            context,
                            Icons.account_balance_wallet,
                            'Incomes',
                            () => _navigate(
                                context, const AccountsVsIncomesHome())),
                      const Divider(),
                      if (isAdmin || isSubAdmin || isAccounttant)
                        _drawerItem(context, Icons.money_off, 'Expenditures',
                            () => _navigate(context, const ExpendituresHome())),
                      const Divider(),
                      if (isAdmin || isSecretary || isSubAdmin || isTeacher)
                        _drawerItem(
                            context,
                            Icons.fact_check,
                            'Registers',
                            () => _navigate(
                                context, const RegistersHomeScreen())),
                      const Divider(),
                      _drawerItem(context, Icons.home, 'Home',
                          () => _navigate(context, const HomeScreen())),
                      const Divider(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _drawerItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
        leading: Icon(icon, color: Colors.blueAccent, size: 18),
        title: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 12.0,
              fontWeight: FontWeight.normal,
              color: const Color.fromARGB(255, 0, 0, 0),
              letterSpacing: 1.2,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
