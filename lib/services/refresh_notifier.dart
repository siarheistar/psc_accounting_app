import 'package:flutter/foundation.dart';

class RefreshNotifier extends ChangeNotifier {
  static final RefreshNotifier _instance = RefreshNotifier._internal();
  factory RefreshNotifier() => _instance;
  RefreshNotifier._internal();

  // Notify specific screens to refresh
  void notifyInvoicesRefresh() {
    print('📋 [RefreshNotifier] Notifying invoices screen to refresh');
    notifyListeners();
  }

  void notifyExpensesRefresh() {
    print('💰 [RefreshNotifier] Notifying expenses screen to refresh');
    notifyListeners();
  }

  void notifyDashboardRefresh() {
    print('🏠 [RefreshNotifier] Notifying dashboard to refresh');
    notifyListeners();
  }
}
