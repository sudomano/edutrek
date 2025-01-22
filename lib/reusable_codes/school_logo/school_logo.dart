import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/school_info.dart';

Future<List<School>> fetchSchools() async {
  final box = await Hive.openBox<School>('school');
  try {
    return box.values.where((schoolItem) => schoolItem.termId != null).toList();
  } finally {}
}

Widget buildFutureSchoolsWidget({required bool isLargeScreen}) {
  return FutureBuilder<List<School>>(
    future: fetchSchools(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return const Center(
          child: Text(
            "No Schools Yet",
            style: TextStyle(color: Colors.red),
          ),
        );
      } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        return Column(
          children: snapshot.data!.map((schoolItem) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: schoolItem.schoolLogoPath != null
                  ? Image.file(
                      File(schoolItem.schoolLogoPath!),
                      width: isLargeScreen ? 150 : 300,
                      height: isLargeScreen ? 120 : 250,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
            );
          }).toList(),
        );
      } else {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                size: 80,
                color: Colors.blueAccent,
              ),
              SizedBox(height: 16),
              Text(
                'Home Page',
                style: TextStyle(
                  fontSize: 26,
                  fontStyle: FontStyle.normal,
                  color: Color.fromARGB(255, 36, 32, 32),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    },
  );
}

/*

  final isLargeScreen = MediaQuery.of(context).size.width > 600; // Example threshold


 const SizedBox(
                      height: 5,
                    ),
                    buildFutureSchoolsWidget(isLargeScreen: isLargeScreen),
                    const SizedBox(
                      height: 10,
                    ),

 */