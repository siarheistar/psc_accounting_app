import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../context/simple_company_context.dart';
import '../../services/api_service.dart';
import '../../services/refresh_notifier.dart';
import '../../utils/currency_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final selectedCompany = SimpleCompanyContext.selectedCompany;
      final companyId = selectedCompany?.id;

      if (companyId == null) {
        return;
      }

      // Fetch data from API
      final invoices = await ApiService.getInvoices(companyId);
      final expenses = await ApiService.getExpenses(companyId);

      // Calculate totals
      final totalInvoices = invoices.length;
      final totalInvoiceAmount = invoices.fold<double>(
          0.0, (sum, invoice) => sum + (invoice['amount'] ?? 0.0));

      final totalExpenses = expenses.length;
      final totalExpenseAmount = expenses.fold<double>(
          0.0, (sum, expense) => sum + (expense['amount'] ?? 0.0));

      final pendingInvoices =
          invoices.where((invoice) => invoice['status'] == 'pending').toList();
      final pendingAmount = pendingInvoices.fold<double>(
          0.0, (sum, invoice) => sum + (invoice['amount'] ?? 0.0));

      setState(() {
        _dashboardData = {
          'totalInvoices': totalInvoices,
          'totalInvoiceAmount': totalInvoiceAmount,
          'totalExpenses': totalExpenses,
          'totalExpenseAmount': totalExpenseAmount,
          'pendingInvoices': pendingInvoices.length,
          'pendingAmount': pendingAmount,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    return CurrencyUtils.getCurrencySymbol(selectedCompany?.currency);
  }

  Future<void> _showCreateInvoiceDialog() async {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany == null) return;

    final clientNameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedStatus = 'pending';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: clientNameController,
              decoration: const InputDecoration(
                labelText: 'Client Name',
                hintText: 'Enter client name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
                prefixText: '${_getCurrencySymbol()} ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
              ),
              items: ['pending', 'paid', 'overdue']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) => selectedStatus = value ?? 'pending',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (clientNameController.text.isNotEmpty &&
                  amountController.text.isNotEmpty) {
                try {
                  final invoice = {
                    'company_id': selectedCompany.id,
                    'client_name': clientNameController.text,
                    'amount': double.parse(amountController.text),
                    'date': DateTime.now().toIso8601String().split('T')[0],
                    'status': selectedStatus,
                  };

                  print('🧾 Creating invoice: $invoice');
                  await ApiService.createInvoice(invoice);
                  print('✅ Invoice created successfully');
                  Navigator.of(context).pop(true);
                } catch (e) {
                  print('❌ Failed to create invoice: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create invoice: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      print(
          '✅ Invoice created, refreshing dashboard and notifying other screens');
      _loadDashboardData(); // Refresh the dashboard
      RefreshNotifier().notifyInvoicesRefresh(); // Notify invoices screen
      RefreshNotifier().notifyDashboardRefresh(); // Notify dashboard
    }
  }

  Future<void> _showCreateExpenseDialog() async {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany == null) return;

    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter expense description',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
                prefixText: '${_getCurrencySymbol()} ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Enter category (e.g., Office, Travel, Equipment)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isNotEmpty &&
                  amountController.text.isNotEmpty &&
                  categoryController.text.isNotEmpty) {
                try {
                  final expense = {
                    'company_id': selectedCompany.id,
                    'description': descriptionController.text,
                    'amount': double.parse(amountController.text),
                    'date': DateTime.now().toIso8601String().split('T')[0],
                    'category': categoryController.text,
                  };

                  print('💰 Creating expense: $expense');
                  await ApiService.createExpense(expense);
                  print('✅ Expense created successfully');
                  Navigator.of(context).pop(true);
                } catch (e) {
                  print('❌ Failed to create expense: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create expense: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      print(
          '✅ Expense created, refreshing dashboard and notifying other screens');
      _loadDashboardData(); // Refresh the dashboard
      RefreshNotifier().notifyExpensesRefresh(); // Notify expenses screen
      RefreshNotifier().notifyDashboardRefresh(); // Notify dashboard
    }
  }

  void _navigateToTab(int tabIndex) {
    // Find the MainHomeScreen state and update its selected index
    final mainScreenState =
        context.findAncestorStateOfType<State<StatefulWidget>>();
    if (mainScreenState != null &&
        mainScreenState.widget.runtimeType
            .toString()
            .contains('MainHomeScreen')) {
      // Add bounds checking - we now have 3 tabs (0, 1, 2)
      if (tabIndex >= 0 && tabIndex < 3) {
        (mainScreenState as dynamic).setState(() {
          (mainScreenState as dynamic)._selectedIndex = tabIndex;
        });
        print('🏠 [Dashboard] Navigated to tab: $tabIndex');
      } else {
        print(
            '⚠️ [Dashboard] Invalid tab index: $tabIndex, ignoring navigation');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          user?.displayName ?? user?.email ?? 'User',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (selectedCompany?.isDemo == true)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Text(
                              'Demo Mode',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh, size: 24),
                    tooltip: 'Refresh Data',
                  ),
                  const Icon(Icons.dashboard, size: 40, color: Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Stats
          Text(
            'Quick Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  context,
                  'Total Invoices',
                  '${_dashboardData['totalInvoices'] ?? 0}',
                  Icons.receipt_long,
                  Colors.blue,
                  '${_getCurrencySymbol()}${(_dashboardData['totalInvoiceAmount'] ?? 0.0).toStringAsFixed(2)}',
                  onTap: () => _navigateToTab(1), // Navigate to invoices
                ),
                _buildStatCard(
                  context,
                  'Total Expenses',
                  '${_dashboardData['totalExpenses'] ?? 0}',
                  Icons.shopping_cart,
                  Colors.green,
                  '${_getCurrencySymbol()}${(_dashboardData['totalExpenseAmount'] ?? 0.0).toStringAsFixed(2)}',
                  onTap: () => _navigateToTab(2), // Navigate to expenses
                ),
                _buildStatCard(
                  context,
                  'Pending Invoices',
                  '${_dashboardData['pendingInvoices'] ?? 0}',
                  Icons.schedule,
                  Colors.orange,
                  '${_getCurrencySymbol()}${(_dashboardData['pendingAmount'] ?? 0.0).toStringAsFixed(2)}',
                  onTap: () => _navigateToTab(1), // Navigate to invoices
                ),
                _buildStatCard(
                  context,
                  'Company',
                  selectedCompany?.name ?? 'Unknown',
                  Icons.business,
                  Colors.purple,
                  selectedCompany?.isDemo == true ? 'Demo Data' : 'Live Data',
                ),
              ],
            ),
          ), // Quick Actions
          const SizedBox(height: 16),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateInvoiceDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateExpenseDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String count,
    IconData icon,
    Color color,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    Widget cardChild = Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: cardChild,
      );
    }

    return cardChild;
  }
}
