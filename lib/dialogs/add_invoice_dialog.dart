import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../models/vat_models.dart';
import '../services/database_service.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../widgets/gross_vat_calculator_widget.dart';

class AddInvoiceDialog extends StatefulWidget {
  const AddInvoiceDialog({super.key});

  @override
  State<AddInvoiceDialog> createState() => _AddInvoiceDialogState();
}

class _AddInvoiceDialogState extends State<AddInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _grossAmountController = TextEditingController();
  final _netAmountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'pending'; // Add status field
  bool _isSaving = false; // Add saving state to prevent double submission
  
  // VAT-related fields
  VATRate? _selectedVATRate;
  VATCalculation? _vatCalculation;
  List<VATRate> _vatRates = [];
  bool _isLoadingVATRates = true;

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _grossAmountController.dispose();
    _netAmountController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadVATRates();
    _generateInvoiceNumber();
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

  Future<void> _loadVATRates() async {
    print('🧾 [AddInvoiceDialog] Starting VAT rates loading...');
    try {
      final rates = await VATService.getVATRates(country: 'Ireland', activeOnly: true);
      print('🧾 [AddInvoiceDialog] Received ${rates.length} VAT rates');
      
      setState(() {
        _vatRates = rates;
        _isLoadingVATRates = false;
        // Set default VAT rate (Standard rate)
        _selectedVATRate = rates.isNotEmpty 
            ? rates.firstWhere(
                (rate) => rate.rateName.toLowerCase().contains('standard'),
                orElse: () => rates.first,
              )
            : null;
      });
      
      print('🧾 [AddInvoiceDialog] Selected default VAT rate: ${_selectedVATRate?.rateName} (${_selectedVATRate?.ratePercentage}%)');
    } catch (e) {
      setState(() => _isLoadingVATRates = false);
      print('❌ [AddInvoiceDialog] Error loading VAT rates: $e');
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '\$'; // Default fallback
  }

  void _onVATCalculationChanged(VATCalculation? calculation) {
    setState(() {
      _vatCalculation = calculation;
      // Update net amount field when VAT calculation changes
      if (calculation != null) {
        _netAmountController.text = calculation.netAmount.toStringAsFixed(2);
      } else {
        _netAmountController.clear();
      }
    });
  }

  double? _getGrossAmount() {
    final text = _grossAmountController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _generateInvoiceNumber() {
    // Generate invoice number based on current date
    final now = DateTime.now();
    final invoiceNumber =
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    _invoiceNumberController.text = invoiceNumber;
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
      final grossAmount = double.parse(_grossAmountController.text);
      final netAmount = _vatCalculation?.netAmount ?? grossAmount;
      
      final invoice = Invoice(
        id: '',
        invoiceNumber: _invoiceNumberController.text,
        clientName: _clientNameController.text,
        amount: grossAmount, // Use gross amount for compatibility
        description: _descriptionController.text,
        date: _selectedDate, // Invoice issue date (optional parameter)
        dueDate: _selectedDate.add(const Duration(days: 30)),
        status: _selectedStatus, // Use selected status
        createdAt: DateTime.now(),
        // VAT fields
        vatRateId: _selectedVATRate?.id,
        netAmount: _vatCalculation?.netAmount ?? netAmount,
        vatAmount: _vatCalculation?.vatAmount,
        grossAmount: _vatCalculation?.grossAmount ?? grossAmount,
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
                // Gross Amount and VAT Rate Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _grossAmountController,
                        decoration: InputDecoration(
                          labelText: 'Gross Amount (inc VAT)',
                          border: const OutlineInputBorder(),
                          prefixText: _getCurrencySymbol(),
                          helperText: 'Total amount including VAT',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => setState(() {}), // Trigger rebuild for VAT calculation
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _isLoadingVATRates
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<VATRate>(
                              value: _selectedVATRate,
                              decoration: const InputDecoration(
                                labelText: 'VAT Rate',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.percent),
                                helperText: 'Ireland VAT rate',
                              ),
                              items: _vatRates
                                  .map((rate) => DropdownMenuItem(
                                        value: rate,
                                        child: Text('${rate.rateName} (${rate.ratePercentage}%)'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedVATRate = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Select VAT rate';
                                }
                                return null;
                              },
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Net Amount Field (Read-only, calculated from VAT)
                TextFormField(
                  controller: _netAmountController,
                  decoration: InputDecoration(
                    labelText: 'Net Amount (ex VAT)',
                    border: const OutlineInputBorder(),
                    prefixText: _getCurrencySymbol(),
                    helperText: 'Calculated automatically from gross amount',
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  readOnly: true,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                GrossVATCalculatorWidget(
                  grossAmount: _getGrossAmount(),
                  selectedVATRate: _selectedVATRate,
                  businessUsagePercentage: 100.0, // Invoices are always 100% business
                  onCalculationChanged: _onVATCalculationChanged,
                  isLoading: _isLoadingVATRates,
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
