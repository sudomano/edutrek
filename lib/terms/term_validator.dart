import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/serializers/term_serializer.dart';

Future<Map<String, dynamic>> validateAndInsertTerm(
  Map<String, dynamic> termData,
  Box<Terms> termBox,
) async {
  final incomingTermId = termData['termId']?.toString().trim();
  final incomingTermName =
      termData['termName']?.toString().toLowerCase().trim();

  final incomingStatus = termData['status']?.toString().trim().toLowerCase();
  final incomingIsActive = termData['isActive'];

  final activeTerms = termBox.values.any((s) {
    final storedStatus = s.status.toString().trim().toLowerCase();
    final storedIsActive = s.isActive;
    return storedStatus == incomingStatus?.toLowerCase() ||
        storedIsActive == incomingIsActive;
  });

  // ✅ Check for duplicates
  final duplicate = termBox.values.any((s) {
    final storedCode = s.termId.toString().trim();
    final storedName = s.termName.toString().toLowerCase().trim();
    return storedCode == incomingTermId?.toLowerCase() ||
        storedName == incomingTermName;
  });

  if (duplicate) {
    return {
      "termId": incomingTermId,
      "termName": incomingTermName,
      "status": "skipped",
      "reason":
          "Duplicate termId or termName already exists. You can modify it or create a new one."
    };
  }
  if (activeTerms) {
    return {
      "incomingStatus": incomingStatus,
      "incomingIsActive": incomingIsActive,
      "status": "skipped",
      "reason":
          "An Active Term Exists, Please Close it down to Start a new Term"
    };
  }

  try {
    final term = termsFromJson(termData);
    await termBox.put(term.termId, term);
    return {
      "termId": incomingTermId,
      "termName": incomingTermName,
      "status": "success",
      "message": "Terms inserted successfully"
    };
  } catch (e) {
    return {
      "termId": incomingTermId,
      "termName": incomingTermName,
      "status": "failed",
      "reason": "Deserialization or processing error",
      "details": e.toString()
    };
  }
}
