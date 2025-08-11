import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../services/database_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';

class AddInvoiceDialog extends StatefulWidget {
  const AddInvoiceDialog({super.key});

  @override
  State<AddInvoiceDialog> createState() => _AddInvoiceDialogState();
}

class _AddInvoiceDialogState extends State<AddInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'pending'; // Add status field
  bool _isSaving = false; // Add saving state to prevent double submission

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    // Removed _generateInvoiceNumber() - backend will generate the invoice number
  }

  void _initializeCompanyContext() {
    print('🔍 [DEBUG] === COMPANY CONTEXT INITIALIZATION ===');

    // Check if SimpleCompanyContext has a selected company
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    print('🔍 [DEBUG] SimpleCompanyContext.selectedCompany: $selectedCompany');
    print(
        '🔍 [DEBUG] SimpleCompanyContext.hasSelectedCompany: ${SimpleCompanyContext.hasSelectedCompany}');

    if (selectedCompany != null) {
      print(
          '🔍 [DEBUG] Company found - ID: ${selectedCompany.id}, Name: ${selectedCompany.name}, Demo: ${selectedCompany.isDemo}');

      // Set company context in DatabaseService
      final dbService = DatabaseService();
      dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );

      // Verify the context was set
      print('🔍 [DEBUG] DatabaseService context after setting:');
      print('🔍 [DEBUG] - currentCompanyId: ${dbService.currentCompanyId}');
      print('🔍 [DEBUG] - hasCompanyContext: ${dbService.hasCompanyContext}');
      print('🔍 [DEBUG] - isDemoMode: ${dbService.isDemoMode}');

      print('✅ [DEBUG] Company context successfully set!');
    } else {
      print('❌ [DEBUG] No company found in SimpleCompanyContext!');
      print('🔍 [DEBUG] This means either:');
      print('🔍 [DEBUG] 1. User never selected a company');
      print('🔍 [DEBUG] 2. Company context was cleared');
      print('🔍 [DEBUG] 3. Navigation/routing issue');

      // Try to restore from browser storage
      final savedCompanyId = SimpleCompanyContext.getSavedCompanyId();
      print('🔍 [DEBUG] Checking saved company ID: $savedCompanyId');

      if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
        print(
            '⚠️ [DEBUG] Found saved company ID but no context - this indicates a restoration issue');
        print('🔍 [DEBUG] Main app should have restored this on startup');
        print(
            '🔍 [DEBUG] This suggests the static context was lost or not properly initialized');
      } else {
        print(
            '❌ [DEBUG] No saved company ID found - user needs to select a company');
      }
    }

    print('🔍 [DEBUG] === END COMPANY CONTEXT INITIALIZATION ===');
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '\$'; // Default fallback
  }

  Future<void> _saveInvoice() async {
    // Prevent double submission
    if (_isSaving) {
      print(
          '🧾 [AddInvoiceDialog] Save already in progress, ignoring duplicate request');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    print('🧾 [AddInvoiceDialog] === STARTING INVOICE SAVE ===');
    setState(() => _isSaving = true);

    // Pre-save company context verification
    final preCheckCompany = SimpleCompanyContext.selectedCompany;
    final dbService = DatabaseService();

    if (preCheckCompany == null || !dbService.hasCompanyContext) {
      // Re-initialize company context
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany != null) {
        dbService.setCompanyContext(
          selectedCompany.id.toString(),
          isDemoMode: selectedCompany.isDemo,
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Company Context Error'),
              content: const Text(
                  'No company context set. Please select a company first.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    try {
      print('🧾 [AddInvoiceDialog] Creating invoice object...');
      final invoice = Invoice(
        id: '',
        invoiceNumber:
            '', // Backend will generate the invoice number based on ID
        clientName: _clientNameController.text,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: _selectedDate, // Invoice issue date (optional parameter)
        dueDate: _selectedDate.add(const Duration(days: 30)),
        status: _selectedStatus, // Use selected status
        createdAt: DateTime.now(),
      );

      print('🧾 [AddInvoiceDialog] Calling insertInvoice...');
      await dbService.insertInvoice(invoice);

      print('🧾 [AddInvoiceDialog] Invoice save completed successfully');

      // Success - close dialog and return to parent
      if (mounted) {
        print('🧾 [AddInvoiceDialog] Widget still mounted, closing dialog...');
        Navigator.of(context).pop(
            null); // Return null to indicate success but no further processing needed
        print('🧾 [AddInvoiceDialog] Dialog closed successfully');
      } else {
        print(
            '🧾 [AddInvoiceDialog] Widget no longer mounted, skipping dialog close');
      }
    } catch (e) {
      print('❌ [AddInvoiceDialog] Error in _saveInvoice: $e');
      print('❌ [AddInvoiceDialog] Error type: ${e.runtimeType}');

      // Only show error dialog if we're still mounted and haven't navigated away
      if (mounted) {
        print('🧾 [AddInvoiceDialog] Showing error dialog...');
        // Use a slight delay to avoid Navigator assertion issues
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invoice Save Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to save invoice:'),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        print(
            '🧾 [AddInvoiceDialog] Widget not mounted, skipping error dialog');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Invoice'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _clientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a client name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: const OutlineInputBorder(),
                    prefixText: _getCurrencySymbol(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStatus = newValue;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a status';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _selectDate,
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveInvoice, // Disable when saving
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
