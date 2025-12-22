import 'package:hive/hive.dart';
import 'package:zitf_system/database/payment_purpose.dart';
import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/student_payments.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/main.dart';

class ArrearResult {
  final Map<String, double> arrearsDetails;
  final List<String> overdueTerms;

  ArrearResult({
    required this.arrearsDetails,
    required this.overdueTerms,
  });
}

class ArrearsService {
  final DeviceRole role;
  final List<Terms>? cachedServerTerms;
  final List<StudentPayment>? cachedServerStudentPayments;

  ArrearsService({
    required this.role,
    this.cachedServerTerms,
    this.cachedServerStudentPayments,
  });

  /// ✅ Main arrears checker
  Future<ArrearResult> checkArrears(
    Student student,
    PaymentPurpose selectedPurpose,
    Future<List<PaymentPurpose>> Function(String termId)
        fetchPaymentPurposesByTerm,
    double Function({
      required List<StudentPayment> studentPayments,
      required String termId,
      required String purposeName,
    }) sumPaymentsFromHive,
    double Function({
      required String termId,
      required String purposeName,
    }) sumPaymentsFromSession,
    double Function(
      double arrears,
      Student student,
      PaymentPurpose purpose,
      String termId,
    ) getAdjustedArrear,
  ) async {
    final Map<String, double> arrearsDetails = {};
    final List<String> overdueTerms = [];

    // 🔹 Load all terms
    final List<Terms> allTerms = role == DeviceRole.host
        ? Hive.box<Terms>('terms').values.toList()
        : cachedServerTerms ?? [];

    for (final term in allTerms) {
      // Only check terms the student is in
      if (!(student.terms?.contains(term.termId) ?? false)) continue;

      // 🔹 Fetch purposes for this term
      final termPurposes = await fetchPaymentPurposesByTerm(term.termId);

      // Find matching purpose by name
      final matchingPurpose = termPurposes.firstWhere(
        (p) =>
            p.paymentPurpose.toLowerCase() ==
            selectedPurpose.paymentPurpose.toLowerCase(),
        orElse: () => PaymentPurpose(
          paymentPurpose: 'N/A',
          associatedClasses: [],
          id: 0,
          purposeAmount: 0.0,
        ),
      );

      if (matchingPurpose.paymentPurpose == 'N/A') continue;

      // 🔹 Class validation
      final isClassMatch =
          matchingPurpose.associatedClasses?.contains(student.class_) ?? false;
      if (!isClassMatch) continue;

      // 🔹 Newcomer condition
      final isNewcomer = selectedPurpose.forNewcomersOnly == true;
      bool isNewcomerValid = true;

      if (isNewcomer) {
        final termStart = term.startDate;
        final termEnd = term.endDate;

        if (termEnd != null) {
          if (student.isNewComer != true ||
              student.isNewComerUntil == null ||
              termStart.isAfter(student.isNewComerUntil!) ||
              termEnd.isBefore(student.isNewComerFrom!)) {
            isNewcomerValid = false;
          }
        } else if (student.isNewComer != true ||
            student.isNewComerUntil == null ||
            termStart.isAfter(student.isNewComerUntil!)) {
          isNewcomerValid = false;
        }
      }

      if (!isNewcomerValid) continue;

      // 🔹 Payments
      final allStudentPayments = role == DeviceRole.host
          ? Hive.box<StudentPayment>('student_payments').values.toList()
          : cachedServerStudentPayments ?? [];

      final hivePaid = sumPaymentsFromHive(
        studentPayments: allStudentPayments,
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final sessionPaid = sumPaymentsFromSession(
        termId: term.termId,
        purposeName: selectedPurpose.paymentPurpose,
      );

      final totalPaid = hivePaid + sessionPaid;

      // 🔹 Arrears calculation
      double arrears = matchingPurpose.purposeAmount - totalPaid;
      arrears = getAdjustedArrear(
        arrears,
        student,
        matchingPurpose,
        term.termId,
      );

      if (arrears > 0) {
        overdueTerms.add(term.termId);
        arrearsDetails[term.termId] = arrears;
      }
    }

    return ArrearResult(
      arrearsDetails: arrearsDetails,
      overdueTerms: overdueTerms,
    );
  }
}
