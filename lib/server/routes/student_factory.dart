import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/reusable_codes/serializers/students_serializer.dart';

final _uuid = Uuid();

Student createStudentFromClientJson({
  required Map<String, dynamic> json,
  required Box<Student> studentsBox,
}) {
  final name = json['name']?.toString().toLowerCase();
  final surname = json['surname']?.toString().toLowerCase();
  final className = json['class']?.toString().toLowerCase();
  final gender = json['gender']?.toString().toLowerCase();
  final studentIdNumber = json['studentIdNumber']?.toString().toLowerCase();

  // -------------------------------
  // 🔐 Duplicate detection
  // -------------------------------
  final duplicateStudent = studentsBox.values.any((s) =>
      s.name == name &&
      s.surname == surname &&
      s.class_.toLowerCase() == className &&
      s.gender.toLowerCase() == gender);

  if (duplicateStudent) {
    throw Exception('Student with same name, surname, class and gender exists');
  }

  if (studentIdNumber != null && studentIdNumber.isNotEmpty) {
    final duplicateId = studentsBox.values.any(
      (s) => s.studentIdNumber?.toLowerCase() == studentIdNumber,
    );

    if (duplicateId) {
      throw Exception('Student registration number already exists');
    }
  }

  // -------------------------------
  // 🆔 Server authority fields
  // -------------------------------
  json['id'] = studentsBox.isEmpty
      ? 1
      : studentsBox.values
              .map((s) => s.id ?? 0)
              .reduce((a, b) => a > b ? a : b) +
          1;

  json['regNumber'] ??= _uuid.v4();
  json['syncStatus'] = true;
  json['lastModified'] = DateTime.now().toIso8601String();
  json['operationType'] = 'create';

  return studentsFromJson(json);
}
