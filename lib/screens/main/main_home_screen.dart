import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../context/simple_company_context.dart';
import '../../services/navigation_manager.dart';
import '../../pages/home_page.dart';
import '../features/invoices_screen.dart';
import '../features/expenses_screen.dart';
import '../../dialogs/manage_employees_dialog.dart';
import '../admin/admin_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const HomePage(),
      InvoicesScreen(),
      ExpensesScreen(),
    ];

    // Restore the last selected tab from browser storage with bounds checking
    int savedIndex = NavigationManager.getCurrentTab();
    _selectedIndex =
        (savedIndex >= 0 && savedIndex < _pages.length) ? savedIndex : 0;
    print(
        '🏠 [MainHomeScreen] Initialized with tab index: $_selectedIndex (saved was: $savedIndex)');
  }

  void _onItemTapped(int index) {
    // Add bounds checking
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });

      // Save the current tab to browser storage
      NavigationManager.saveCurrentTab(index);
      print('📱 [MainHomeScreen] Switched to tab: $index');
    } else {
      print('⚠️ [MainHomeScreen] Invalid tab index: $index, ignoring');
    }
  }

  void _handleCompanyChange() {
    // Clear company context
    SimpleCompanyContext.clearSelectedCompany();
    // Force navigation back to company selection by popping all routes
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _handleAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
  }

  void _handleLogout() async {
    SimpleCompanyContext.clearSelectedCompany();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCompany = SimpleCompanyContext.selectedCompany;

    // This should not happen if navigation is correct, but just in case
    if (!SimpleCompanyContext.hasSelectedCompany) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PSC Accounting'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No Company Selected',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please select a company to continue.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleCompanyChange,
                child: const Text('Back to Company Selection'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedCompany?.name ?? 'PSC Accounting'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (selectedCompany?.isDemo == true)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'change_company':
                  _handleCompanyChange();
                  break;
                case 'admin':
                  _handleAdmin();
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_company',
                child: ListTile(
                  leading: Icon(Icons.business),
                  title: Text('Change Company'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'admin',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('Admin'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Invoices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Expenses',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
