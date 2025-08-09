import 'package:firebase_auth/firebase_auth.dart';
import '../context/simple_company_context.dart';
import '../services/api_service.dart';
import '../models/company.dart';

class CompanyContextTest {
  static Future<void> testCompanyContext() async {
    print('🧪 [CompanyContextTest] === STARTING COMPANY CONTEXT TEST ===');

    // 1. Check current state
    final currentCompany = SimpleCompanyContext.selectedCompany;
    print(
        '🧪 [CompanyContextTest] Current company: ${currentCompany?.name ?? 'null'}');
    print(
        '🧪 [CompanyContextTest] Has company: ${SimpleCompanyContext.hasSelectedCompany}');

    // 2. Check saved company ID
    final savedId = SimpleCompanyContext.getSavedCompanyId();
    print('🧪 [CompanyContextTest] Saved company ID: $savedId');

    // 3. If we have a saved ID but no current company, try to restore
    if (savedId != null && savedId.isNotEmpty && currentCompany == null) {
      print(
          '🧪 [CompanyContextTest] Found saved ID but no current company - attempting restore...');

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser?.email == null) {
          print('❌ [CompanyContextTest] No authenticated user');
          return;
        }

        final companies = await ApiService.getCompanies(currentUser!.email!);
        print('🧪 [CompanyContextTest] Loaded ${companies.length} companies');

        final savedCompanyMap = companies.firstWhere(
          (company) => company['id'].toString() == savedId,
          orElse: () => {},
        );

        if (savedCompanyMap.isNotEmpty) {
          final savedCompany = Company.fromJson(savedCompanyMap);
          SimpleCompanyContext.setSelectedCompany(savedCompany);
          print(
              '✅ [CompanyContextTest] Successfully restored: ${savedCompany.name}');
        } else {
          print(
              '❌ [CompanyContextTest] Saved company not found in user companies');
        }
      } catch (e) {
        print('❌ [CompanyContextTest] Error during restore: $e');
      }
    }

    // 4. Final state check
    final finalCompany = SimpleCompanyContext.selectedCompany;
    print(
        '🧪 [CompanyContextTest] Final company: ${finalCompany?.name ?? 'null'}');
    print('🧪 [CompanyContextTest] === END COMPANY CONTEXT TEST ===');
  }
}
