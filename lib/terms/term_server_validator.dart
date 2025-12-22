import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';

Future<Map<String, dynamic>> validateAndInsertTermServer(
  Map<String, dynamic> termData,
  Box<Terms> termBox,
) async {
  final incomingStatus = termData['status']?.toString().trim().toLowerCase();
  final incomingIsActive = termData['isActive'];

  final activeTerms = termBox.values.any((s) {
    final storedStatus = s.status.toString().trim().toLowerCase();
    final storedIsActive = s.isActive;
    return storedStatus == incomingStatus?.toLowerCase() ||
        storedIsActive == incomingIsActive;
  });

  if (activeTerms) {
    return {
      "incomingStatus": incomingStatus,
      "incomingIsActive": incomingIsActive,
      "statuss": "skipped",
      "reason":
          "An Active Term Exists, Please Close it down to Start a new Term"
    };
  }
  try {
    final term = termsFromJson(termData);
    await termBox.put(term.termId, term);
    return {
      "status": incomingStatus,
      "isActive": incomingIsActive,
      "statuss": "success",
      "message": "Allowd to insert a new term"
    };
  } catch (e) {
    return {
      "status": incomingStatus,
      "isActive": incomingIsActive,
      "statuss": "failed",
      "reason": "Deserialization or processing error",
      "details": e.toString()
    };
  }
}
