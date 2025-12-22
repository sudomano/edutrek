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
  });

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
    );
  }
}
