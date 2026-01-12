import 'package:hive/hive.dart';
import 'package:zitf_system/auth/userdb.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';

class HostSeed {
  static Future<void> run() async {
    await _seedTerms();
    await _seedAdminUser();
  }

  static Future<void> _seedTerms() async {
    final termsBox = Hive.box<Terms>('terms');
    // Search for an open term

    var openedTerms = termsBox.values.where((term) => term.status == 'Opened');
    Terms? openedTerm = openedTerms.isNotEmpty ? openedTerms.first : null;

    if (openedTerm != null) {
      globalTermId ??= openedTerm.termId;
      return;
    }

    // Terms box is empty, create a default term
    String defaultTermId = "defaultTermId";
    String defaultTermName = "Default Term";
    DateTime defaultStartDate = DateTime.now();
    int id = 1;

    Terms defaultTerm = Terms(
      id: id,
      termId: defaultTermId,
      termName: defaultTermName,
      startDate: defaultStartDate,
      isActive: false,
      status: 'Opened',
      operationType: 'create',
      syncStatus: false,
      lastModified: DateTime.now(),
    );

    // Set the global term ID

    // Save the default term in the box
    await termsBox.put(defaultTerm.termId, defaultTerm);
    globalTermId ??= defaultTermId;
  }

  static Future<void> _seedAdminUser() async {
    final userBox = Hive.box<User>('users');

    final adminExists = userBox.values.any((u) => u.role == 'admin');
    if (adminExists) return;

    await userBox.add(
      User(
        id: 1,
        username: 'SUDOMANOadmin',
        password: 'SUDOMANO@codedatapool@admin',
        role: 'admin',
        userCode: 'admin',
        phone: '0773309607',
        termId: 'defaultTermId',
        securityQuestions: ['good day', 'good year', 'good bank'],
        securityAnswers: ['SUDOMANO', '1961', 'STEWARD'],
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'create',
      ),
    );
  }
}
