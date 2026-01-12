import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> resolveHivePath() async {
  final exeName = Platform.resolvedExecutable
      .split(Platform.pathSeparator)
      .last
      .replaceAll('.exe', '');

  final baseDir = Platform.environment['APPDATA'] ?? '.';
  final hivePath = p.join(baseDir, 'Edutrek', exeName);

  final dir = Directory(hivePath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  return hivePath;
}
