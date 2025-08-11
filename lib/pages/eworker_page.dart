import 'package:flutter/material.dart';
import '../models/vat_models.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../dialogs/add_eworker_period_dialog.dart';
import '../dialogs/add_enhanced_expense_dialog.dart';
import '../utils/currency_utils.dart';

class EWorkerPage extends StatefulWidget {
  const EWorkerPage({super.key});

  @override
  State<EWorkerPage> createState() => _EWorkerPageState();
}

class _EWorkerPageState extends State<EWorkerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<EWorkerPeriod> _eworkerPeriods = [];
  List<EnhancedExpense> _eworkerExpenses = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '€';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final periods = await VATService.getEWorkerPeriods(selectedCompany.id.toString());
      final expenses = await VATService.getEnhancedExpenses(selectedCompany.id.toString());
      
      // Filter expenses to only show e-worker related ones
      final eworkerExpenses = expenses.where((expense) => 
        expense.expenseType == 'eworker' || 
        expense.eworkerDays != null ||
        expense.eworkerRate != null
      ).toList();

      setState(() {
        _eworkerPeriods = periods;
        _eworkerExpenses = eworkerExpenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load e-worker data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _showAddEWorkerPeriodDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AddEWorkerPeriodDialog(),
    );

    if (result != null) {
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-Worker period added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showAddEWorkerExpenseDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AddEnhancedExpenseDialog(),
    );

    if (result != null) {
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-Worker expense added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  double _getTotalPeriodAmount() {
    return _eworkerPeriods.fold(0.0, (sum, period) => sum + period.totalAmount);
  }

  double _getTotalExpenseAmount() {
    return _eworkerExpenses.fold(0.0, (sum, expense) => sum + expense.grossAmount);
  }

  Widget _buildPeriodsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_eworkerPeriods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No E-Worker Periods',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first e-worker period to get started',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddEWorkerPeriodDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add E-Worker Period'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildPeriodsSummary(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _eworkerPeriods.length,
            itemBuilder: (context, index) {
              final period = _eworkerPeriods[index];
              return _buildPeriodCard(period);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodsSummary() {
    final totalAmount = _getTotalPeriodAmount();
    final activePeriods = _eworkerPeriods.where((p) => p.status != 'draft').length;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-Worker Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Total Periods: ${_eworkerPeriods.length}'),
                      const SizedBox(width: 16),
                      Text('Active: $activePeriods'),
                      const Spacer(),
                      Text(
                        'Total: ${_getCurrencySymbol()}${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodCard(EWorkerPeriod period) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(period.status),
          child: const Icon(Icons.work, color: Colors.white),
        ),
        title: Text(
          '${_formatDate(period.periodStart)} - ${_formatDate(period.periodEnd)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${period.totalDays} days at ${_getCurrencySymbol()}${period.dailyRate}/day'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(period.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    period.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Text(
          '${_getCurrencySymbol()}${period.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_eworkerExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No E-Worker Expenses',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first e-worker expense to get started',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddEWorkerExpenseDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add E-Worker Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildExpensesSummary(),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _eworkerExpenses.length,
            itemBuilder: (context, index) {
              final expense = _eworkerExpenses[index];
              return _buildExpenseCard(expense);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesSummary() {
    final totalAmount = _getTotalExpenseAmount();
    final totalVAT = _eworkerExpenses.fold(0.0, (sum, expense) => sum + expense.vatAmount);

    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.red[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-Worker Expenses Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Total Expenses: ${_eworkerExpenses.length}'),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('VAT: ${_getCurrencySymbol()}${totalVAT.toStringAsFixed(2)}'),
                          Text(
                            'Total: ${_getCurrencySymbol()}${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(EnhancedExpense expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: const Icon(Icons.work, color: Colors.white),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDate(expense.expenseDate)),
            if (expense.eworkerDays != null) ...[
              const SizedBox(height: 4),
              Text('${expense.eworkerDays} days at ${_getCurrencySymbol()}${expense.eworkerRate}/day'),
            ],
            if (expense.supplierName != null) ...[
              const SizedBox(height: 4),
              Text('Supplier: ${expense.supplierName}'),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_getCurrencySymbol()}${expense.grossAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (expense.vatAmount > 0) ...[
              Text(
                'VAT: ${_getCurrencySymbol()}${expense.vatAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.work),
            SizedBox(width: 8),
            Text('E-Worker Management'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today), text: 'Periods'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Expenses'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildPeriodsTab(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildExpensesTab(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEWorkerPeriodDialog();
          } else {
            _showAddEWorkerExpenseDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Add Period' : 'Add Expense'),
        backgroundColor: _tabController.index == 0 
            ? const Color(0xFF3B82F6) 
            : const Color(0xFFEF4444),
      ),
    );
  }
}