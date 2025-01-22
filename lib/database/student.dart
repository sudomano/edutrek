import 'package:hive/hive.dart';

part 'student.g.dart';

@HiveType(typeId: 0)
class Student extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String surname;

  @HiveField(2)
  String regNumber;

  @HiveField(3)
  String class_;

  @HiveField(4)
  String gender;

  @HiveField(5)
  DateTime age;

  @HiveField(6)
  String phoneNumber;

  @HiveField(7)
  String paymentStatus;

  @HiveField(8)
  bool isPresent;

  @HiveField(9)
  List<DateTime> presentDates;

  @HiveField(10)
  List<DateTime> absentDates;

  @HiveField(11)
  String? termId; // Nullable termId

  @HiveField(12)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(13)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(14)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(15)
  int? id; // New field for unique identifier

  // New fields to add
  @HiveField(16)
  String? physicalAddress;

  @HiveField(17)
  String? formerSchool;

  @HiveField(18)
  String? religion;

  @HiveField(19)
  String? denomination;

  @HiveField(20)
  String? studentIdNumber; // Student identification number

  @HiveField(21)
  String? nationalIdNumber;

  @HiveField(22)
  String? nationality;

  @HiveField(23)
  String? district;

  @HiveField(24)
  String? previousSchoolPerformanceResults;

  @HiveField(25)
  String? enrollmentStatus; // Active, Inactive, Graduated, etc.

  // Additional optional fields

  @HiveField(28)
  String? emergencyContactName;

  @HiveField(29)
  String? emergencyContactNumber;

  @HiveField(30)
  String? healthStauts;

  @HiveField(31)
  String? healthDetailedInformation;
  @HiveField(32)
  List<String>? modifiedFields; // Tracks fields that were modified

  Student({
    required this.name,
    required this.surname,
    required this.regNumber,
    required this.class_,
    required this.gender,
    required this.age,
    required this.phoneNumber,
    required this.paymentStatus,
    this.isPresent = true,
    List<DateTime>? presentDates,
    List<DateTime>? absentDates,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
    this.physicalAddress,
    this.formerSchool,
    this.religion,
    this.denomination,
    this.studentIdNumber,
    this.nationalIdNumber,
    this.nationality,
    this.district,
    this.previousSchoolPerformanceResults,
    this.enrollmentStatus,
    this.emergencyContactName,
    this.emergencyContactNumber,
    this.healthStauts,
    this.healthDetailedInformation,
    this.modifiedFields,
  })  : presentDates = presentDates ?? [],
        absentDates = absentDates ?? [];

  Student copyWith({
    String? name,
    String? surname,
    String? regNumber,
    String? class_,
    String? gender,
    DateTime? age,
    String? phoneNumber,
    String? paymentStatus,
    bool? isPresent,
    List<DateTime>? presentDates,
    List<DateTime>? absentDates,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    String? physicalAddress,
    String? formerSchool,
    String? religion,
    String? denomination,
    String? studentIdNumber,
    String? nationalIdNumber,
    String? nationality,
    String? district,
    String? previousSchoolPerformanceResults,
    String? enrollmentStatus,
    String? emergencyContactName,
    String? emergencyContactNumber,
    String? healthStauts,
    String? healthDetailedInformation,
    List<String>? modifiedFields,
  }) {
    return Student(
      name: name ?? this.name,
      surname: surname ?? this.surname,
      regNumber: regNumber ?? this.regNumber,
      class_: class_ ?? this.class_,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isPresent: isPresent ?? this.isPresent,
      presentDates: presentDates ?? this.presentDates,
      absentDates: absentDates ?? this.absentDates,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      physicalAddress: physicalAddress ?? this.physicalAddress,
      formerSchool: formerSchool ?? this.formerSchool,
      religion: religion ?? this.religion,
      denomination: denomination ?? this.denomination,
      studentIdNumber: studentIdNumber ?? this.studentIdNumber,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      nationality: nationality ?? this.nationality,
      district: district ?? this.district,
      previousSchoolPerformanceResults: previousSchoolPerformanceResults ??
          this.previousSchoolPerformanceResults,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactNumber:
          emergencyContactNumber ?? this.emergencyContactNumber,
      healthStauts: healthStauts ?? this.healthStauts,
      healthDetailedInformation:
          healthDetailedInformation ?? this.healthDetailedInformation,
      modifiedFields: modifiedFields ?? this.modifiedFields,
    );
  }
}
