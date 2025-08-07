import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../context/simple_company_context.dart';
import '../../services/refresh_notifier.dart';
import '../../models/accounting_models.dart';
import '../../dialogs/edit_invoice_dialog.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> invoices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadInvoices();

    // Listen for refresh notifications
    RefreshNotifier().addListener(_onRefreshNotification);
  }

  @override
  void dispose() {
    RefreshNotifier().removeListener(_onRefreshNotification);
    super.dispose();
  }

  void _onRefreshNotification() {
    print('📋 [InvoicesScreen] Received refresh notification');
    loadInvoices();
  }

  Future<void> loadInvoices() async {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    print(
        '📋 Loading invoices for company: ${selectedCompany.name} (${selectedCompany.id})');
    try {
      final data = await ApiService.getInvoices(selectedCompany.id);
      print('✅ Received ${data.length} invoices from API');
      setState(() {
        invoices = data;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading invoices: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load invoices: $e')),
        );
      }
    }
  }

  Future<void> _createInvoice() async {
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
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
                prefixText: '\$',
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

                  await ApiService.createInvoice(invoice);
                  Navigator.of(context).pop(true);
                } catch (e) {
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
      loadInvoices(); // Refresh the list
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _editInvoice(dynamic invoice) async {
    print('🧾 [InvoicesScreen] === STARTING INVOICE EDIT ===');
    print(
        '🧾 [InvoicesScreen] Invoice: ${invoice['invoice_number']} (ID: ${invoice['id']})');

    try {
      // Convert the invoice data to Invoice object
      final invoiceObj = Invoice(
        id: invoice['id'].toString(),
        invoiceNumber: invoice['invoice_number'] ?? 'N/A',
        clientName: invoice['client_name'] ?? '',
        amount: (invoice['amount'] as num?)?.toDouble() ?? 0.0,
        description: invoice['description'] ?? '',
        date: invoice['date'] != null
            ? DateTime.tryParse(invoice['date']) ?? DateTime.now()
            : DateTime.now(),
        dueDate: invoice['due_date'] != null
            ? DateTime.tryParse(invoice['due_date']) ?? DateTime.now()
            : DateTime.now(),
        status: invoice['status'] ?? 'draft',
        createdAt: invoice['created_at'] != null
            ? DateTime.tryParse(invoice['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => EditInvoiceDialog(invoice: invoiceObj),
      );

      if (result == true) {
        print(
            '🧾 [InvoicesScreen] Invoice edit completed successfully, refreshing list...');
        await loadInvoices(); // Refresh the list

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [InvoicesScreen] Error editing invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteInvoice(dynamic invoice) async {
    print('🗑️ [InvoicesScreen] === STARTING INVOICE DELETE ===');
    print(
        '🗑️ [InvoicesScreen] Invoice: ${invoice['client_name']} (ID: ${invoice['id']})');

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this invoice?'),
            const SizedBox(height: 8),
            Text('Client: ${invoice['client_name'] ?? 'N/A'}'),
            Text('Amount: \$${invoice['amount'] ?? 0}'),
            Text('Date: ${invoice['date'] ?? 'N/A'}'),
            Text('Status: ${invoice['status'] ?? 'N/A'}'),
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

        await dbService.deleteInvoice(invoice['id'].toString());

        print(
            '🗑️ [InvoicesScreen] Invoice deleted successfully, refreshing list...');
        await loadInvoices(); // Refresh the list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ [InvoicesScreen] Error deleting invoice: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete invoice: $e'),
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
                const Icon(Icons.receipt_long, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  'Invoices',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (!isLoading)
                  Text(
                    '${invoices.length} total',
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
                : invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No invoices found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first invoice to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _createInvoice,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Invoice'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = invoices[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getStatusColor(invoice['status']),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  'Client: ${invoice['client_name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Date: ${invoice['date']}'),
                                    Text('Amount: \$${invoice['amount']}'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _getStatusColor(invoice['status'])
                                                .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(
                                              invoice['status']),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        invoice['status']
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                              invoice['status']),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'edit':
                                        await _editInvoice(invoice);
                                        break;
                                      case 'delete':
                                        await _deleteInvoice(invoice);
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
        heroTag: "invoices_fab",
        onPressed: _createInvoice,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
