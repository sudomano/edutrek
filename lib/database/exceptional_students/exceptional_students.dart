import 'package:hive/hive.dart';

part 'exceptional_students.g.dart'; // Required for code generation

@HiveType(typeId: 51) // Unique identifier for Hive
class ExceptionalStudents extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  String? exceptionId; // to be unique must use UUID

  @HiveField(2)
  String? exceptionName; // e.g staff student exception  / scholarship student

  @HiveField(3)
  String? exceptionStatus; // active or not

  @HiveField(4)
  String? exceptionType; // amount or percentage

  @HiveField(5)
  String? exceptionFigure; // $5 / 5% depending on exception type

  @HiveField(6)
  bool? syncStatus; //  field to track sync status

  @HiveField(7)
  DateTime? lastModified; //  field to track when the class was last modified

  @HiveField(8)
  String? operationType; //  field for 'create', 'update', or 'delete'

  @HiveField(9)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(10)
  List<String>? terms; // stores a list of terms associated with the exception

  ExceptionalStudents({
    this.id,
    this.exceptionId,
    this.exceptionName,
    this.exceptionStatus,
    this.exceptionType,
    this.exceptionFigure,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.modifiedFields,
    List<String>? terms,
  }) : terms = terms ?? [];

  ExceptionalStudents copyWith({
    int? id,
    String? exceptionId,
    String? exceptionName,
    String? exceptionStatus,
    String? exceptionType,
    String? exceptionFigure,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    List<String>? modifiedFields,
    List<String>? terms,
  }) {
    return ExceptionalStudents(
      id: id ?? this.id,
      exceptionId: exceptionId ?? this.exceptionId,
      exceptionName: exceptionName ?? this.exceptionName,
      exceptionStatus: exceptionStatus ?? this.exceptionStatus,
      exceptionType: exceptionType ?? this.exceptionType,
      exceptionFigure: exceptionFigure ?? this.exceptionFigure,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      terms: terms ?? this.terms,
    );
  }
}
