import 'dart:html' as html;

class NavigationManager {
  static const String _tabIndexKey = 'currentTabIndex';
  static const String _companyIdKey = 'selectedCompanyId';

  // Save current tab index to browser storage
  static void saveCurrentTab(int tabIndex) {
    try {
      html.window.localStorage[_tabIndexKey] = tabIndex.toString();
      print('💾 [NavigationManager] Saved tab index: $tabIndex');
    } catch (e) {
      print('❌ [NavigationManager] Failed to save tab index: $e');
    }
  }

  // Get current tab index from browser storage
  static int getCurrentTab() {
    try {
      final savedIndex = html.window.localStorage[_tabIndexKey];
      if (savedIndex != null) {
        final index = int.tryParse(savedIndex) ?? 0;
        print('📖 [NavigationManager] Retrieved tab index: $index');
        return index;
      }
    } catch (e) {
      print('❌ [NavigationManager] Failed to retrieve tab index: $e');
    }
    return 0; // Default to dashboard
  }

  // Save selected company ID
  static void saveSelectedCompanyId(String companyId) {
    try {
      html.window.localStorage[_companyIdKey] = companyId;
      print('💾 [NavigationManager] Saved company ID: $companyId');
    } catch (e) {
      print('❌ [NavigationManager] Failed to save company ID: $e');
    }
  }

  // Get selected company ID
  static String? getSelectedCompanyId() {
    try {
      final companyId = html.window.localStorage[_companyIdKey];
      print('📖 [NavigationManager] Retrieved company ID: $companyId');
      return companyId;
    } catch (e) {
      print('❌ [NavigationManager] Failed to retrieve company ID: $e');
      return null;
    }
  }

  // Clear navigation state
  static void clearNavigationState() {
    try {
      html.window.localStorage.remove(_tabIndexKey);
      html.window.localStorage.remove(_companyIdKey);
      print('🗑️ [NavigationManager] Cleared navigation state');
    } catch (e) {
      print('❌ [NavigationManager] Failed to clear navigation state: $e');
    }
  }
}
