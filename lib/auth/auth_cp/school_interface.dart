// school_interface.dart
abstract class ISchool {
  String get name;
  String? get logoPath;
}

class DummySchool implements ISchool {
  @override
  final String name;
  @override
  final String? logoPath;

  DummySchool({required this.name, this.logoPath});
}

class School implements ISchool {
  @override
  final String name;
  @override
  final String? logoPath;
  final String? termId;

  School({required this.name, this.logoPath, this.termId});
}
