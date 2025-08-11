import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../models/vat_models.dart';
import '../services/database_service.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../widgets/vat_calculator_widget.dart';

class AddEnhancedInvoiceDialog extends StatefulWidget {
  const AddEnhancedInvoiceDialog({super.key});

  @override
  State<AddEnhancedInvoiceDialog> createState() => _AddEnhancedInvoiceDialogState();
}

class _AddEnhancedInvoiceDialogState extends State<AddEnhancedInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  final _clientNameController = TextEditingController();
  final _netAmountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'pending';
  VATRate? _selectedVATRate;
  VATCalculation? _vatCalculation;

  List<VATRate> _vatRates = [];
  bool _isLoadingVATRates = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadVATRates();
  }

  @override
  void dispose() {
    _netAmountController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '💰 AddEnhancedInvoiceDialog: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('💰 AddEnhancedInvoiceDialog: No company context available');
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '€';
  }

  Future<void> _loadVATRates() async {
    try {
      final rates = await VATService.getVATRates(country: 'Ireland', activeOnly: true);
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
    } catch (e) {
      setState(() => _isLoadingVATRates = false);
      _showErrorSnackBar('Failed to load VAT rates: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onVATCalculationChanged(VATCalculation? calculation) {
    setState(() {
      _vatCalculation = calculation;
    });
  }

  double? _getNetAmount() {
    final text = _netAmountController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _saveInvoice() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final netAmount = double.parse(_netAmountController.text.trim());
      final vatAmount = _vatCalculation?.vatAmount ?? 0.0;
      final totalAmount = netAmount + vatAmount;

      final invoice = Invoice(
        id: '0', // Will be assigned by backend
        clientName: _clientNameController.text.trim(),
        amount: totalAmount, // Use gross amount for compatibility
        date: _selectedDate,
        dueDate: _selectedDate.add(const Duration(days: 30)), // Set due date 30 days from invoice date
        description: _descriptionController.text.trim(),
        status: _selectedStatus,
        invoiceNumber: '', // Will be assigned by backend
        createdAt: DateTime.now(),
      );

      debugPrint('💰 [AddEnhancedInvoiceDialog] Starting invoice save...');
      debugPrint('💰 Net: ${_getCurrencySymbol()}${netAmount.toStringAsFixed(2)}');
      debugPrint('💰 VAT: ${_getCurrencySymbol()}${vatAmount.toStringAsFixed(2)}');
      debugPrint('💰 Total: ${_getCurrencySymbol()}${totalAmount.toStringAsFixed(2)}');

      await _dbService.insertInvoice(invoice);
      debugPrint('💰 [AddEnhancedInvoiceDialog] Invoice save completed successfully');

      if (mounted) {
        Navigator.of(context).pop(invoice);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enhanced invoice created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('💰 [AddEnhancedInvoiceDialog] Error saving invoice: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Invoice Creation Failed'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Error Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      e.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Enhanced Invoice',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _clientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Client Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter client name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description/Services',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _netAmountController,
                              decoration: InputDecoration(
                                labelText: 'Net Amount (ex VAT)',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.euro),
                                prefixText: _getCurrencySymbol(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              onChanged: (_) => setState(() {}), // Trigger rebuild for VAT calculation
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter amount';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid amount';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'Amount must be > 0';
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

                      VATCalculatorWidget(
                        netAmount: _getNetAmount(),
                        selectedVATRate: _selectedVATRate,
                        businessUsagePercentage: 100.0, // Invoices are always 100% business
                        onCalculationChanged: _onVATCalculationChanged,
                        isLoading: _isLoadingVATRates,
                      ),

                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Invoice Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'sent', child: Text('Sent')),
                          DropdownMenuItem(value: 'paid', child: Text('Paid')),
                          DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                        ],
                        onChanged: (value) => setState(() => _selectedStatus = value!),
                      ),

                      if (_vatCalculation != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  'Invoice Summary',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Amount:'),
                                    Text('${_getCurrencySymbol()}${_vatCalculation!.netAmount.toStringAsFixed(2)}'),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('VAT (${_vatCalculation!.vatRatePercentage}%):'),
                                    Text('${_getCurrencySymbol()}${_vatCalculation!.vatAmount.toStringAsFixed(2)}'),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      '${_getCurrencySymbol()}${_vatCalculation!.grossAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const Divider(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Create Invoice'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}