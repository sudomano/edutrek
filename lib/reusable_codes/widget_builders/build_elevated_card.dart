import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ElevatedCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget target;
  final bool isLargeScreen;

  const ElevatedCard({
    Key? key,
    required this.icon,
    required this.text,
    required this.target,
    this.isLargeScreen = false, // Flag to check screen size
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => target),
              );
            },
            child: Container(
              constraints: isLargeScreen
                  ? const BoxConstraints(
                      minWidth: 400,
                      maxWidth: 400) // Fixed width for large screens
                  : null,
              padding: const EdgeInsets.all(16.0),
              child: isLargeScreen
                  // For large screens, icon above the text
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 20, // Larger icon size for large screens
                          color: isLargeScreen
                              ? Colors.blue.shade800
                              : Colors.blueAccent,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: GoogleFonts.montserrat(
                            fontSize: isLargeScreen ? 12 : 14,
                            fontWeight: isLargeScreen
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: isLargeScreen
                                ? Colors.black
                                : Colors.blueGrey[900],
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
                          size: 20, // Smaller icon for small screens
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
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
}
