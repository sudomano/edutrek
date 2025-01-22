import 'package:flutter/material.dart';

class CenteredFormContainer extends StatelessWidget {
  final Widget child;
  final String title;

  const CenteredFormContainer({
    Key? key,
    required this.child,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.0, // Adjust font size
              fontWeight: FontWeight.normal, // Bold font
              color: Colors.white, // Title color
              letterSpacing: 1.2, // Slight letter spacing for elegance
            ),
          ),
        ),
        backgroundColor: const Color.fromARGB(
            255, 38, 140, 191), // Optional: Customize AppBar background color
        elevation: 4.0,
        // Optional: Add a subtle shadow
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }
}



/*  


  return CenteredFormContainer(
      title: 'Add',
      child: Form(
      
      */ 