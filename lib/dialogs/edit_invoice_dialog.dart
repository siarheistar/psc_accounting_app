import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../services/database_service.dart';
import '../context/simple_company_context.dart';

class EditInvoiceDialog extends StatefulWidget {
  final Invoice invoice;

  const EditInvoiceDialog({super.key, required this.invoice});

  @override
  State<EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  bool _isUpdating = false;
  String _selectedStatus = 'pending'; // Add status field

  @override
  void initState() {
    super.initState();
    print('🧾 [EditInvoiceDialog] === INITIALIZING EDIT DIALOG ===');
    print('🧾 [EditInvoiceDialog] Received invoice data:');
    print('🧾 [EditInvoiceDialog] - ID: ${widget.invoice.id}');
    print(
        '🧾 [EditInvoiceDialog] - Invoice Number: ${widget.invoice.invoiceNumber}');
    print('🧾 [EditInvoiceDialog] - Client: ${widget.invoice.clientName}');
    print('🧾 [EditInvoiceDialog] - Amount: ${widget.invoice.amount}');
    print(
        '🧾 [EditInvoiceDialog] - Description: ${widget.invoice.description}');
    print('🧾 [EditInvoiceDialog] - Date: ${widget.invoice.date}');
    print('🧾 [EditInvoiceDialog] - Due Date: ${widget.invoice.dueDate}');
    print('🧾 [EditInvoiceDialog] - Status: ${widget.invoice.status}');
    print('🧾 [EditInvoiceDialog] - Created At: ${widget.invoice.createdAt}');

    _initializeCompanyContext();
    _initializeControllers();

    print('🧾 [EditInvoiceDialog] === EDIT DIALOG INITIALIZED ===');
  }

  void _initializeControllers() {
    _invoiceNumberController =
        TextEditingController(text: widget.invoice.invoiceNumber);
    _clientNameController =
        TextEditingController(text: widget.invoice.clientName);
    _amountController =
        TextEditingController(text: widget.invoice.amount.toString());
    _descriptionController =
        TextEditingController(text: widget.invoice.description);
    _selectedDate = widget.invoice.dueDate;

    // Initialize status with validation to ensure it matches dropdown options
    final validStatuses = ['draft', 'pending', 'paid', 'overdue', 'cancelled'];
    _selectedStatus = validStatuses.contains(widget.invoice.status)
        ? widget.invoice.status
        : 'pending'; // Default to pending if status is invalid

    print(
        '🧾 [EditInvoiceDialog] Status initialized: ${widget.invoice.status} -> $_selectedStatus');
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  void _initializeCompanyContext() {
    print('🔍 [DEBUG] === COMPANY CONTEXT INITIALIZATION (EDIT INVOICE) ===');

    final selectedCompany = SimpleCompanyContext.selectedCompany;
    print('🔍 [DEBUG] SimpleCompanyContext.selectedCompany: $selectedCompany');
    print(
        '🔍 [DEBUG] SimpleCompanyContext.hasSelectedCompany: ${SimpleCompanyContext.hasSelectedCompany}');

    if (selectedCompany != null) {
      print(
          '🔍 [DEBUG] Company found - ID: ${selectedCompany.id}, Name: ${selectedCompany.name}, Demo: ${selectedCompany.isDemo}');

      final dbService = DatabaseService();
      dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );

      print('🔍 [DEBUG] DatabaseService context after setting:');
      print('🔍 [DEBUG] - currentCompanyId: ${dbService.currentCompanyId}');
      print('🔍 [DEBUG] - hasCompanyContext: ${dbService.hasCompanyContext}');
      print('🔍 [DEBUG] - isDemoMode: ${dbService.isDemoMode}');

      print('✅ [DEBUG] Company context successfully set!');
    } else {
      print('❌ [DEBUG] No company found in SimpleCompanyContext!');
    }

    print(
        '🔍 [DEBUG] === END COMPANY CONTEXT INITIALIZATION (EDIT INVOICE) ===');
  }

  Future<void> _updateInvoice() async {
    if (!_formKey.currentState!.validate() || _isUpdating) {
      print('❌ [EditInvoiceDialog] Form validation failed or already updating');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    print('🧾 [EditInvoiceDialog] === STARTING INVOICE UPDATE ===');
    print('🧾 [EditInvoiceDialog] Form values:');
    print('🧾 [EditInvoiceDialog] - Invoice ID: ${widget.invoice.id}');
    print(
        '🧾 [EditInvoiceDialog] - Invoice Number: ${_invoiceNumberController.text}');
    print(
        '🧾 [EditInvoiceDialog] - Client Name: ${_clientNameController.text}');
    print('🧾 [EditInvoiceDialog] - Amount: ${_amountController.text}');
    print(
        '🧾 [EditInvoiceDialog] - Description: ${_descriptionController.text}');
    print('🧾 [EditInvoiceDialog] - Due Date: $_selectedDate');

    final dbService = DatabaseService();
    final preCheckCompany = SimpleCompanyContext.selectedCompany;

    print('🧾 [EditInvoiceDialog] Company context check:');
    print('🧾 [EditInvoiceDialog] - preCheckCompany: $preCheckCompany');
    print(
        '🧾 [EditInvoiceDialog] - dbService.hasCompanyContext: ${dbService.hasCompanyContext}');
    print(
        '🧾 [EditInvoiceDialog] - dbService.currentCompanyId: ${dbService.currentCompanyId}');

    if (preCheckCompany == null || !dbService.hasCompanyContext) {
      print(
          '🧾 [EditInvoiceDialog] Company context missing, attempting to set...');
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany != null) {
        print(
            '🧾 [EditInvoiceDialog] Setting company context: ID=${selectedCompany.id}, Demo=${selectedCompany.isDemo}');
        dbService.setCompanyContext(
          selectedCompany.id.toString(),
          isDemoMode: selectedCompany.isDemo,
        );
        print(
            '🧾 [EditInvoiceDialog] Context set - hasContext: ${dbService.hasCompanyContext}');
      } else {
        print(
            '❌ [EditInvoiceDialog] No company available, showing error dialog');
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
                    Navigator.of(context).pop(); // Close error dialog
                    Navigator.of(context).pop(); // Close edit dialog
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() {
          _isUpdating = false;
        });
        return;
      }
    } else {
      print('✅ [EditInvoiceDialog] Company context already set properly');
    }

    try {
      print('🧾 [EditInvoiceDialog] Creating updated invoice object...');
      print(
          '🧾 [EditInvoiceDialog] Original invoice date: ${widget.invoice.date}');
      print(
          '🧾 [EditInvoiceDialog] Original invoice createdAt: ${widget.invoice.createdAt}');

      // Validate amount before parsing
      final amountText = _amountController.text.trim();
      final parsedAmount = double.tryParse(amountText);
      if (parsedAmount == null) {
        throw Exception('Invalid amount format: "$amountText"');
      }

      // Ensure date is never null - use createdAt as fallback
      final invoiceDate = widget.invoice.date ?? widget.invoice.createdAt;
      print('🧾 [EditInvoiceDialog] Using invoice date: $invoiceDate');

      final updatedInvoice = Invoice(
        id: widget.invoice.id,
        invoiceNumber: _invoiceNumberController.text.trim(),
        clientName: _clientNameController.text.trim(),
        amount: parsedAmount,
        description: _descriptionController.text.trim(),
        date: invoiceDate, // Ensure date is never null
        dueDate: _selectedDate,
        status: _selectedStatus, // Use selected status
        createdAt: widget.invoice.createdAt, // Keep original creation date
      );

      print('🧾 [EditInvoiceDialog] Updated invoice object created:');
      print('🧾 [EditInvoiceDialog] - ID: ${updatedInvoice.id}');
      print(
          '🧾 [EditInvoiceDialog] - Invoice Number: ${updatedInvoice.invoiceNumber}');
      print('🧾 [EditInvoiceDialog] - Client: ${updatedInvoice.clientName}');
      print('🧾 [EditInvoiceDialog] - Amount: ${updatedInvoice.amount}');
      print('🧾 [EditInvoiceDialog] - Date: ${updatedInvoice.date}');
      print('🧾 [EditInvoiceDialog] - Due Date: ${updatedInvoice.dueDate}');
      print('🧾 [EditInvoiceDialog] - Status: ${updatedInvoice.status}');

      print('🧾 [EditInvoiceDialog] Calling updateInvoice...');
      await dbService.updateInvoice(updatedInvoice);

      print('✅ [EditInvoiceDialog] Invoice update completed successfully');

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print(
            '🧾 [EditInvoiceDialog] Closing dialog and returning updated invoice');
        // Small delay to let the snackbar show
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pop(updatedInvoice); // Return the updated invoice
      }
    } catch (e) {
      print('❌ [EditInvoiceDialog] Error in _updateInvoice: $e');
      print('❌ [EditInvoiceDialog] Error type: ${e.runtimeType}');
      print('❌ [EditInvoiceDialog] Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          print('🧾 [EditInvoiceDialog] Showing error dialog to user');
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invoice Update Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to update invoice:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close error dialog
                    Navigator.of(context).pop(); // Close edit dialog
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
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
      title: const Text('Edit Invoice'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _invoiceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an invoice number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
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
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: 'draft',
                      child: Text('Draft'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'paid',
                      child: Text('Paid'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'overdue',
                      child: Text('Overdue'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
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
                        'Due Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
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
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateInvoice,
          child: _isUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
