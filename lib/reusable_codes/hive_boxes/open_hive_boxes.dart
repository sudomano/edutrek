import 'package:hive/hive.dart';

/// Utility function to open a Hive box with error handling and logging.
/// Returns the opened box if successful, otherwise null.
Future<Box<T>?> openHiveBox<T>(String boxName) async {
  try {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<T>(boxName);
    }
    return Hive.box<T>(boxName);
  } catch (e) {
    // Log or handle the error as needed
    print('Error opening Hive box: $boxName. Error: $e');
    return null;
  }
}
