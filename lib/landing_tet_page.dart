import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zitf_system/auth/userdb.dart';

class HomeLandingSection extends StatelessWidget {
  final User loggedInUser;
  final bool isLargeScreen;

  const HomeLandingSection({
    super.key,
    required this.loggedInUser,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back 👋',
                style: GoogleFonts.poppins(
                  fontSize: isLargeScreen ? 22 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loggedInUser.username,
                style: GoogleFonts.poppins(
                  fontSize: isLargeScreen ? 18 : 15,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Chip(
                label: Text(
                  loggedInUser.role.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blue,
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 6),
              Text(
                'You are successfully logged in.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
