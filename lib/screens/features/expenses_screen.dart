import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../context/simple_company_context.dart';
import '../../services/refresh_notifier.dart';
import '../../models/accounting_models.dart';
import '../../dialogs/edit_expense_dialog.dart';
import '../../utils/currency_utils.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<dynamic> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExpenses();

    // Listen for refresh notifications
    RefreshNotifier().addListener(_onRefreshNotification);
  }

  @override
  void dispose() {
    RefreshNotifier().removeListener(_onRefreshNotification);
    super.dispose();
  }

  void _onRefreshNotification() {
    print('💰 [ExpensesScreen] Received refresh notification');
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    print(
        '💰 Loading expenses for company: ${selectedCompany.name} (${selectedCompany.id})');
    try {
      final data = await ApiService.getExpenses(selectedCompany.id);
      print('✅ Received ${data.length} expenses from API');
      setState(() {
        expenses = data;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading expenses: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e')),
        );
      }
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    return CurrencyUtils.getCurrencySymbol(selectedCompany?.currency);
  }

  Future<void> _createExpense() async {
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

                  await ApiService.createExpense(expense);
                  Navigator.of(context).pop(true);
                } catch (e) {
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
      loadExpenses(); // Refresh the list
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'office':
        return Colors.blue;
      case 'software':
        return Colors.purple;
      case 'meals':
        return Colors.orange;
      case 'utilities':
        return Colors.green;
      case 'travel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'office':
        return Icons.business;
      case 'software':
        return Icons.computer;
      case 'meals':
        return Icons.restaurant;
      case 'utilities':
        return Icons.power;
      case 'travel':
        return Icons.flight;
      default:
        return Icons.receipt;
    }
  }

  Future<void> _editExpense(dynamic expense) async {
    print('💰 [ExpensesScreen] === STARTING EXPENSE EDIT ===');
    print(
        '💰 [ExpensesScreen] Expense: ${expense['description']} (ID: ${expense['id']})');

    try {
      // Convert the expense data to Expense object
      final expenseObj = Expense(
        id: expense['id'].toString(),
        date: expense['date'] != null
            ? DateTime.tryParse(expense['date']) ?? DateTime.now()
            : DateTime.now(),
        description: expense['description'] ?? '',
        category: expense['category'] ?? 'Other',
        amount: (expense['amount'] as num?)?.toDouble() ?? 0.0,
        status: expense['status'] ?? 'pending',
        notes: expense['notes'],
      );

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => EditExpenseDialog(expense: expenseObj),
      );

      if (result == true) {
        print(
            '💰 [ExpensesScreen] Expense edit completed successfully, refreshing list...');
        await loadExpenses(); // Refresh the list

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [ExpensesScreen] Error editing expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(dynamic expense) async {
    print('🗑️ [ExpensesScreen] === STARTING EXPENSE DELETE ===');
    print(
        '🗑️ [ExpensesScreen] Expense: ${expense['description']} (ID: ${expense['id']})');

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this expense?'),
            const SizedBox(height: 8),
            Text('Description: ${expense['description'] ?? 'N/A'}'),
            Text('Category: ${expense['category'] ?? 'N/A'}'),
            Text('Amount: ${_getCurrencySymbol()}${expense['amount'] ?? 0}'),
            Text('Date: ${expense['date'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = DatabaseService();

        // Set company context
        final selectedCompany = SimpleCompanyContext.selectedCompany;
        if (selectedCompany != null) {
          dbService.setCompanyContext(
            selectedCompany.id.toString(),
            isDemoMode: selectedCompany.isDemo,
          );
        }

        await dbService.deleteExpense(expense['id'].toString());

        print(
            '🗑️ [ExpensesScreen] Expense deleted successfully, refreshing list...');
        await loadExpenses(); // Refresh the list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ [ExpensesScreen] Error deleting expense: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, size: 28, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (!isLoading)
                  Text(
                    '${expenses.length} total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first expense to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Navigate to add expense
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Expense'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadExpenses,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: expenses.length,
                          itemBuilder: (context, index) {
                            final expense = expenses[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getCategoryColor(expense['category']),
                                  child: Icon(
                                    _getCategoryIcon(expense['category']),
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  expense['description'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Date: ${expense['date']}'),
                                    Text(
                                        'Amount: ${_getCurrencySymbol()}${expense['amount']}'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(
                                                expense['category'])
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getCategoryColor(
                                              expense['category']),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        expense['category']
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getCategoryColor(
                                              expense['category']),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'edit':
                                        await _editExpense(expense);
                                        break;
                                      case 'delete':
                                        await _deleteExpense(expense);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Edit'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            color: Colors.red),
                                        title: Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "expenses_fab",
        onPressed: _createExpense,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
