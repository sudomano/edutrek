import 'dart:ui';

import 'package:flutter/material.dart';
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

  @HiveField(11) // New field for priority flag
  int? priorityFlag; // 1 for top priority, 0 for less

// ✅ NEW: Deletion Fields
  @HiveField(12)
  bool? isDeleted; // Soft delete flag

  @HiveField(13)
  DateTime? deletedAt; // When deleted

  @HiveField(14)
  String? deletedBy; // Who deleted

  @HiveField(15)
  String? deleteReason; // Why deleted

  @HiveField(16)
  bool? deletedSyncStatus; // Track if deletion was synced

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
    this.priorityFlag = 0, // Default value for priorityFlag,
    List<String>? terms,
    // ✅ New deletion fields
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason,
    this.deletedSyncStatus = false,
  }) : terms = terms ?? [];

  // ✅ Helper: Mark user as deleted
  void markDeleted({
    required String deletedBy,
    String? reason,
  }) {
    isDeleted = true;
    deletedAt = DateTime.now();
    this.deletedBy = deletedBy;
    deleteReason = reason;
    syncStatus = false;
    deletedSyncStatus = false;
    operationType = 'delete';
    lastModified = DateTime.now();
    modifiedFields = [
      'isDeleted',
      'deletedAt',
      'deletedBy',
      'deleteReason',
      'deletedSyncStatus',
      'syncStatus',
      'operationType',
      'lastModified'
    ];
  }

  // ✅ Helper: Restore deleted user
  void restoreDeleted() {
    isDeleted = false;
    deletedAt = null;
    deletedBy = null;
    deleteReason = null;
    syncStatus = false;
    deletedSyncStatus = false;
    operationType = 'update';
    lastModified = DateTime.now();
    modifiedFields = ['isDeleted', 'deletedAt', 'deletedBy', 'deleteReason'];
  }

  // ✅ Helper: Check if user is deleted
  bool get isUserDeleted => isDeleted ?? false;

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
    int? priorityFlag,
    List<String>? terms,
    // ✅ Deletion fields
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deleteReason,
    bool? deletedSyncStatus,
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
      priorityFlag: priorityFlag ?? this.priorityFlag,
      // ✅ Include deletion fields
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deleteReason: deleteReason ?? this.deleteReason,
      deletedSyncStatus: deletedSyncStatus ?? this.deletedSyncStatus,
    );
  }

  // Helper method to check if it's a priority exception
  bool get isPriority => priorityFlag == 1;

  // Helper method to get priority label
  String get priorityLabel => priorityFlag == 1 ? ' Priority' : 'Normal';

  // Helper method to get priority color
  Color get priorityColor => priorityFlag == 1 ? Colors.red : Colors.grey;
}
