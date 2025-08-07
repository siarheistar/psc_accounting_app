import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/database_service.dart';
import '../models/accounting_models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _dbService = DatabaseService();

  // Data state
  List<Invoice> _invoices = [];
  List<Expense> _expenses = [];
  List<PayrollEntry> _payrollEntries = [];
  List<BankStatement> _bankStatements = [];
  Map<String, dynamic> _metrics = {};

  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🏠 === LOADING DASHBOARD DATA ===');
      debugPrint('🏠 Company Context: ${_dbService.currentCompanyId}');
      debugPrint('🏠 Demo Mode: ${_dbService.isDemoMode}');

      // Load all data in parallel
      final results = await Future.wait([
        _dbService.getInvoices(),
        _dbService.getExpenses(),
        _dbService.getPayrollEntries(),
        _dbService.getBankStatements(),
        _dbService.getDashboardMetrics(),
      ]);

      setState(() {
        _invoices = results[0] as List<Invoice>;
        _expenses = results[1] as List<Expense>;
        _payrollEntries = results[2] as List<PayrollEntry>;
        _bankStatements = results[3] as List<BankStatement>;
        _metrics = results[4] as Map<String, dynamic>;
        _isLoading = false;
      });

      debugPrint('🏠 === DASHBOARD DATA LOADED ===');
      debugPrint('🏠 Invoices: ${_invoices.length}');
      debugPrint('🏠 Expenses: ${_expenses.length}');
      debugPrint('🏠 Payroll: ${_payrollEntries.length}');
      debugPrint('🏠 Bank Statements: ${_bankStatements.length}');
      debugPrint('🏠 Total Income: \$${_metrics['total_income'] ?? 0}');
      debugPrint('🏠 Total Expenses: \$${_metrics['total_expenses'] ?? 0}');
    } catch (e) {
      debugPrint('🏠 === DASHBOARD ERROR ===');
      debugPrint('🏠 Error: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addSampleTransaction() async {
    if (_dbService.isDemoMode) {
      _showSnackBar(
          'Cannot add transactions in demo mode. Create a real company first.',
          isError: true);
      return;
    }

    try {
      debugPrint('💰 === ADDING SAMPLE TRANSACTION ===');

      final invoice = Invoice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        invoiceNumber:
            'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        clientName:
            'Sample Client ${DateTime.now().hour}:${DateTime.now().minute}',
        amount:
            (500 + (DateTime.now().millisecondsSinceEpoch % 2000)).toDouble(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: 'Pending',
        description: 'Sample invoice created from dashboard',
        createdAt: DateTime.now(),
      );

      await _dbService.insertInvoice(invoice);

      _showSnackBar('Sample invoice created successfully!');

      // Reload dashboard data
      await _loadDashboardData();
    } catch (e) {
      debugPrint('💰 === TRANSACTION ERROR ===');
      debugPrint('💰 Error: $e');
      _showSnackBar('Failed to create transaction: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDemoMode = _dbService.isDemoMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Icon(
              Icons.account_balance,
              color: isDemoMode ? Colors.orange : Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isDemoMode ? 'PSC Accounting - Demo' : 'PSC Accounting',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDemoMode ? Colors.orange : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        actions: [
          // Company info button
          IconButton(
            onPressed: () => _showCompanyInfo(),
            icon: Icon(
              Icons.info_outline,
              color: isDemoMode ? Colors.orange : Colors.blue,
            ),
          ),
          // Period selector
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'This Month',
              style: TextStyle(fontSize: 12),
            ),
          ),
          // User profile
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: isDemoMode ? Colors.orange : Colors.blue,
              child: user?.photoURL != null
                  ? ClipOval(
                      child: Image.network(
                        user!.photoURL!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            user.displayName?.substring(0, 1).toUpperCase() ??
                                'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildDashboard(),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Debug panel (only in debug mode)
          _buildDebugPanel(),

          // Welcome section
          _buildWelcomeSection(),
          const SizedBox(height: 24),

          // Metrics cards
          _buildMetricsCards(),
          const SizedBox(height: 24),

          // Quick actions
          if (!_dbService.isDemoMode) ...[
            _buildQuickActions(),
            const SizedBox(height: 24),
          ],

          // Data tabs
          _buildDataTabs(),
          const SizedBox(height: 16),

          // Tab content
          _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🐛 DEBUG INFO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text('Company ID: ${_dbService.currentCompanyId ?? "NULL"}'),
          Text('Demo Mode: ${_dbService.isDemoMode}'),
          Text('Has Context: ${_dbService.hasCompanyContext}'),
          const SizedBox(height: 8),
          Text('Invoices: ${_invoices.length}'),
          Text('Expenses: ${_expenses.length}'),
          Text('Payroll: ${_payrollEntries.length}'),
          Text('Bank Statements: ${_bankStatements.length}'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              // Test DB connection
              final connected = await _dbService.testConnection();
              _showSnackBar(
                connected ? 'DB Connected!' : 'DB Connection Failed',
                isError: !connected,
              );
            },
            child: const Text('Test DB Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    final isDemoMode = _dbService.isDemoMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDemoMode
              ? [Colors.orange, Colors.deepOrange]
              : [Colors.blue, Colors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDemoMode ? 'Demo Dashboard' : 'Dashboard Overview',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isDemoMode
                      ? 'Exploring sample data'
                      : 'Welcome back, ${user?.displayName?.split(' ').first ?? 'User'}!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDemoMode
                      ? 'This is demonstration data only'
                      : 'Here\'s what\'s happening with your finances.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDemoMode ? Icons.preview : Icons.dashboard,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    final metrics = [
      {
        'title': 'Total Income',
        'value': '\$${(_metrics['total_income'] ?? 0).toStringAsFixed(2)}',
        'change': '+12.5%',
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
      {
        'title': 'Total Expenses',
        'value': '\$${(_metrics['total_expenses'] ?? 0).toStringAsFixed(2)}',
        'change': '-8.2%',
        'icon': Icons.trending_down,
        'color': Colors.red,
      },
      {
        'title': 'Net Profit',
        'value': '\$${(_metrics['net_profit'] ?? 0).toStringAsFixed(2)}',
        'change': '+25.8%',
        'icon': Icons.account_balance_wallet,
        'color': Colors.blue,
      },
      {
        'title': 'Pending Invoices',
        'value': '${_metrics['pending_invoices'] ?? 0}',
        'change': '+3',
        'icon': Icons.receipt,
        'color': Colors.orange,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric['title'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    metric['icon'] as IconData,
                    size: 20,
                    color: metric['color'] as Color,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                metric['value'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                metric['change'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: metric['color'] as Color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Add Transaction',
                  Icons.add,
                  Colors.blue,
                  _addSampleTransaction,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Import PDF',
                  Icons.upload_file,
                  Colors.green,
                  () => _showSnackBar('PDF import feature coming soon!'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTabs() {
    final tabs = ['Invoices', 'Expenses', 'Payslips', 'Bank Statements'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _selectedTabIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: index == 0 ? const Radius.circular(12) : Radius.zero,
                    right: index == tabs.length - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildInvoicesList();
      case 1:
        return _buildExpensesList();
      case 2:
        return _buildPayrollList();
      case 3:
        return _buildBankStatementsList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return _buildEmptyState(
          'No invoices found', 'Create your first invoice to get started');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Invoices (${_invoices.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  _showSnackBar('View all invoices feature coming soon!'),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._invoices
            .take(5)
            .map((invoice) => _buildInvoiceCard(invoice))
            .toList(),
      ],
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(invoice.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.receipt,
              size: 16,
              color: _getStatusColor(invoice.status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  invoice.clientName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\${invoice.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(invoice.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  invoice.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(invoice.status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return _buildEmptyState(
          'No expenses found', 'Track your first expense to get started');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Expenses (${_expenses.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ..._expenses
            .take(5)
            .map((expense) => _buildExpenseCard(expense))
            .toList(),
      ],
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.money_off,
              size: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  expense.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollList() {
    if (_payrollEntries.isEmpty) {
      return _buildEmptyState(
          'No payroll entries found', 'Add your first payroll entry');
    }

    return Column(
      children:
          _payrollEntries.map((entry) => _buildPayrollCard(entry)).toList(),
    );
  }

  Widget _buildPayrollCard(PayrollEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.person,
              size: 16,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.employeeName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.period,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\${entry.netPay.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankStatementsList() {
    if (_bankStatements.isEmpty) {
      return _buildEmptyState(
          'No bank statements found', 'Import your first bank statement');
    }

    return Column(
      children: _bankStatements
          .map((statement) => _buildBankStatementCard(statement))
          .toList(),
    );
  }

  Widget _buildBankStatementCard(BankStatement statement) {
    final isCredit = statement.amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isCredit ? Icons.add : Icons.remove,
              size: 16,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statement.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statement.transactionType,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}\${statement.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              Text(
                'Bal: \${statement.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    if (_dbService.isDemoMode) {
      return FloatingActionButton(
        heroTag: "old_home_demo_fab",
        onPressed: () => _showSnackBar(
            'Demo mode - Create a real company to add transactions',
            isError: true),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.preview, color: Colors.white),
      );
    }

    return FloatingActionButton(
      heroTag: "old_home_add_fab",
      onPressed: _addSampleTransaction,
      backgroundColor: Colors.blue,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showCompanyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Company Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company ID: ${_dbService.currentCompanyId ?? 'None'}'),
            Text('Demo Mode: ${_dbService.isDemoMode}'),
            Text('Context Set: ${_dbService.hasCompanyContext}'),
            const SizedBox(height: 16),
            const Text('Data Summary:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Invoices: ${_invoices.length}'),
            Text('Expenses: ${_expenses.length}'),
            Text('Payroll Entries: ${_payrollEntries.length}'),
            Text('Bank Statements: ${_bankStatements.length}'),
            const SizedBox(height: 16),
            const Text('Financial Summary:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
                'Total Income: \$${(_metrics['total_income'] ?? 0).toStringAsFixed(2)}'),
            Text(
                'Total Expenses: \$${(_metrics['total_expenses'] ?? 0).toStringAsFixed(2)}'),
            Text(
                'Net Profit: \$${(_metrics['net_profit'] ?? 0).toStringAsFixed(2)}'),
            Text('Pending Invoices: ${_metrics['pending_invoices'] ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!_dbService.isDemoMode)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadDashboardData();
              },
              child: const Text('Refresh Data'),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
      case 'sent':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
