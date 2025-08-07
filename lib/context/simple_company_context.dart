import '../models/company.dart';
import '../services/navigation_manager.dart';

class SimpleCompanyContext {
  static Company? _selectedCompany;

  static Company? get selectedCompany {
    print(
        '🔍 [SimpleCompanyContext] selectedCompany getter called - current company: ${_selectedCompany?.name ?? 'null'} (ID: ${_selectedCompany?.id ?? 'null'})');
    return _selectedCompany;
  }

  static void setSelectedCompany(Company company) {
    _selectedCompany = company;
    // Save to browser storage for persistence
    NavigationManager.saveSelectedCompanyId(company.id);
    print(
        '🏢 [SimpleCompanyContext] Company selected: ${company.name} (ID: ${company.id})');
  }

  static void clearSelectedCompany() {
    _selectedCompany = null;
    // Clear from browser storage
    NavigationManager.clearNavigationState();
    print('🗑️ [SimpleCompanyContext] Company context cleared');
  }

  static bool get hasSelectedCompany {
    final hasCompany = _selectedCompany != null;
    print('🔍 [SimpleCompanyContext] hasSelectedCompany check: $hasCompany');
    return hasCompany;
  }

  // Method to restore company context from storage
  static String? getSavedCompanyId() {
    final savedId = NavigationManager.getSelectedCompanyId();
    print('📖 [SimpleCompanyContext] getSavedCompanyId: $savedId');
    return savedId;
  }
}
