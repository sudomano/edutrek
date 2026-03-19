import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> resolveHivePath() async {
  late final String baseDir;

  if (Platform.isWindows) {
    baseDir = Platform.environment['APPDATA']!;
  } else if (Platform.isMacOS || Platform.isLinux) {
    baseDir = Platform.environment['HOME']!;
  } else {
    throw UnsupportedError('resolveHivePath called on unsupported platform');
  }

  final exeName = Platform.resolvedExecutable
      .split(Platform.pathSeparator)
      .last
      .replaceAll('.exe', '');

  final hivePath = p.join(baseDir, 'Edutrek', exeName);

  final dir = Directory(hivePath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  return hivePath;
}
