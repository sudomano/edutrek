import 'package:hive/hive.dart';

part 'userdb.g.dart'; //

@HiveType(typeId: 8)
class User extends HiveObject {
  @HiveField(0)
  late String username;

  @HiveField(1)
  late String password;

  @HiveField(2)
  late String role; // e.g., 'admin' or 'secretary'

  @HiveField(3)
  late List<String> securityQuestions = [];

  @HiveField(4)
  late List<String> securityAnswers = [];

  @HiveField(5)
  late String phone;

  @HiveField(6)
  String? termId; // Nullable termId

  @HiveField(7)
  bool? syncStatus; // Nullable field to track sync status

  @HiveField(8)
  DateTime? lastModified; // Nullable field to track last modification time

  @HiveField(9)
  String? operationType; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(10)
  int? id;

  @HiveField(11)
  bool? isLogged = false;

  @HiveField(12)
  String? userCode; // Nullable field for 'create', 'update', or 'delete'

  @HiveField(13)
  List<String>? modifiedFields; // Tracks fields that were modified

  @HiveField(14)
  String? email;

  // ✅ NEW: Fields for teacher class assignment
  @HiveField(15)
  List<String>? assignedClasses; // List of class names assigned to teacher

  @HiveField(16)
  bool? isActive = true; // Whether the user account is active

  @HiveField(17)
  DateTime? createdAt; // When the account was created
// ✅ NEW: Deletion Fields
  @HiveField(18)
  bool? isDeleted; // Soft delete flag

  @HiveField(19)
  DateTime? deletedAt; // When deleted

  @HiveField(20)
  String? deletedBy; // Who deleted

  @HiveField(21)
  String? deleteReason; // Why deleted

  @HiveField(22)
  bool? deletedSyncStatus; // Track if deletion was synced
  User({
    required this.username,
    required this.password,
    required this.role,
    required this.securityQuestions,
    required this.securityAnswers,
    required this.phone,
    this.termId,
    this.syncStatus,
    this.lastModified,
    this.operationType,
    this.id,
    this.isLogged,
    this.userCode,
    this.modifiedFields,
    this.email,
    this.assignedClasses, // ✅ New field
    this.isActive = true, // ✅ New field with default
    this.createdAt, // ✅ New field
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason,
    this.deletedSyncStatus = false,
  });
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
    modifiedFields = ['isDeleted', 'deletedAt', 'deletedBy', 'deleteReason'];
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
  User copyWith({
    String? username,
    String? password,
    String? role,
    List<String>? securityQuestions,
    List<String>? securityAnswers,
    String? phone,
    String? termId,
    bool? syncStatus,
    DateTime? lastModified,
    String? operationType,
    int? id,
    bool? isLogged = false,
    String? userCode,
    List<String>? modifiedFields,
    String? email,
    List<String>? assignedClasses,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return User(
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      securityQuestions: securityQuestions ?? this.securityQuestions,
      securityAnswers: securityAnswers ?? this.securityAnswers,
      phone: phone ?? this.phone,
      termId: termId ?? this.termId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModified: lastModified ?? this.lastModified,
      operationType: operationType ?? this.operationType,
      id: id ?? this.id,
      isLogged: isLogged ?? this.isLogged,
      userCode: userCode ?? this.userCode,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      email: email ?? this.email,
      assignedClasses: assignedClasses ?? this.assignedClasses,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ✅ Helper method to check if user is a teacher
  bool get isTeacher => role.toLowerCase() == 'teacher';

  // ✅ Helper method to check if user has a specific class
  bool hasClass(String className) {
    if (assignedClasses == null) return false;
    return assignedClasses!.contains(className);
  }

  // ✅ Helper method to assign a class
  void assignClass(String className) {
    if (assignedClasses == null) {
      assignedClasses = [];
    }
    if (!assignedClasses!.contains(className)) {
      assignedClasses!.add(className);
    }
  }

  // ✅ Helper method to remove a class
  void removeClass(String className) {
    if (assignedClasses != null) {
      assignedClasses!.remove(className);
    }
  }

  // ✅ Helper method to get class count
  int get classCount => assignedClasses?.length ?? 0;
}
