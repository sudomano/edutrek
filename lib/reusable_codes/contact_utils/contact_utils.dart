import 'dart:io';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/student.dart'; // adjust path
import 'package:flutter_contacts/flutter_contacts.dart';

/// Save a single parent contact.
/// - Uses paymentStatus + class_ for displayName
/// - If conflict (same name), appends student firstname.
Future<void> saveParentContact(Student student) async {
  if (!Platform.isAndroid) return; // Only Android for now

  if (!await FlutterContacts.requestPermission()) return;

  // Build base name from parent info
  String baseName = '${student.paymentStatus} - ${student.class_}';
  String finalName = baseName;

  // Check for duplicates in existing contacts
  final existing = await FlutterContacts.getContacts(
    withProperties: true,
  );

  bool conflict = existing.any((c) =>
      c.displayName.toLowerCase().trim() == baseName.toLowerCase().trim());

  if (conflict) {
    finalName = '$baseName (${student.name})';
  }

  // Create or update contact
  final contact = Contact()
    ..name.first = finalName
    ..phones = [Phone(student.phoneNumber)];

  await contact.insert();
  print("✅ Contact saved: $finalName (${student.phoneNumber})");
}

/// Bulk sync all parents from Hive (override duplicates).
Future<void> syncAllParentsToPhoneBook() async {
  if (!Platform.isAndroid) return;

  if (!await FlutterContacts.requestPermission()) return;

  final box = await Hive.openBox<Student>('students');
  final students = box.values.toList();

  for (var student in students) {
    String finalName = '${student.paymentStatus} - ${student.class_}';

    // If already exists, remove old before inserting new
    final existing = await FlutterContacts.getContacts(withProperties: true);
    for (var c in existing) {
      if (c.displayName.toLowerCase().trim() ==
          finalName.toLowerCase().trim()) {
        await c.delete(); // overwrite with updated info
      }
    }

    final contact = Contact()
      ..name.first = finalName
      ..phones = [Phone(student.phoneNumber)];

    await contact.insert();
    print("🔄 Synced: $finalName (${student.phoneNumber})");
  }
}
