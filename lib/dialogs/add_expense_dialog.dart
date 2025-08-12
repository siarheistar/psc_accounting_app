import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../models/vat_models.dart';
import '../services/database_service.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../widgets/gross_vat_calculator_widget.dart';

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  // Form controllers
  final _descriptionController = TextEditingController();
  final _grossAmountController = TextEditingController();
  final _netAmountController = TextEditingController();
  final _notesController = TextEditingController();

  // Form values
  String? _selectedCategory;
  DateTime _expenseDate = DateTime.now();
  String _status = 'Pending';

  // Data lists
  List<String> _categories = [];
  final List<String> _statusOptions = [
    'Pending',
    'Approved',
    'Rejected',
    'Review'
  ];

  bool _isLoading = true;
  bool _isSaving = false; // Add saving state to prevent double submission
  
  // VAT-related fields
  VATRate? _selectedVATRate;
  VATCalculation? _vatCalculation;
  List<VATRate> _vatRates = [];
  bool _isLoadingVATRates = true;

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadData();
    _loadVATRates();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '💰 AddExpenseDialog: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('💰 AddExpenseDialog: No company context available');
    }
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
      print('Error loading VAT rates: $e');
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

  @override
  void dispose() {
    _descriptionController.dispose();
    _grossAmountController.dispose();
    _netAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _dbService.getExpenseCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectExpenseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    // Prevent double submission
    if (_isSaving) {
      debugPrint(
          '💰 [AddExpenseDialog] Save already in progress, ignoring duplicate request');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      _showErrorSnackBar('Please select a category');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });

    try {
      final grossAmount = double.parse(_grossAmountController.text.trim());
      final netAmount = _vatCalculation?.netAmount ?? grossAmount;
      
      final expense = Expense(
        id: '0', // Will be assigned by backend
        date: _expenseDate,
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        amount: grossAmount, // Use gross amount for compatibility
        status: _status,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        // VAT fields
        vatRate: _selectedVATRate?.ratePercentage,
        vatAmount: _vatCalculation?.vatAmount,
        netAmount: _vatCalculation?.netAmount ?? netAmount,
        grossAmount: _vatCalculation?.grossAmount ?? grossAmount,
      );

      debugPrint('💰 [AddExpenseDialog] Starting expense save...');
      await _dbService.insertExpense(expense);
      debugPrint('💰 [AddExpenseDialog] Expense save completed successfully');

      if (mounted) {
        Navigator.of(context).pop(expense);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('💰 [AddExpenseDialog] Error saving expense: $e');
      if (mounted) {
        // Show detailed error dialog instead of snackbar
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Expense Creation Failed'),
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
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Fixed header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long,
                            color: Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        const Text(
                          'Add New Expense',
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

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a description';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Category Selection
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _categories
                                  .map((category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      ))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedCategory = value),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category';
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
                                      prefixIcon: const Icon(Icons.attach_money),
                                      prefixText: _getCurrencySymbol(),
                                      helperText: 'Total amount including VAT',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                    onChanged: (_) => setState(() {}), // Trigger rebuild for VAT calculation
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter an amount';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Please enter a valid amount';
                                      }
                                      if (double.parse(value) <= 0) {
                                        return 'Amount must be greater than 0';
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
                                prefixIcon: const Icon(Icons.receipt_long),
                                prefixText: _getCurrencySymbol(),
                                helperText: 'Calculated automatically from gross amount',
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              readOnly: true,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 16),
                            
                            // VAT Calculator
                            GrossVATCalculatorWidget(
                              grossAmount: _getGrossAmount(),
                              selectedVATRate: _selectedVATRate,
                              businessUsagePercentage: 100.0, // Default to 100% for expenses
                              onCalculationChanged: _onVATCalculationChanged,
                              isLoading: _isLoadingVATRates,
                            ),
                            const SizedBox(height: 16),

                            // Expense Date
                            InkWell(
                              onTap: _selectExpenseDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expense Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_expenseDate.day}/${_expenseDate.month}/${_expenseDate.year}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.flag),
                              ),
                              items: _statusOptions
                                  .map((status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _status = value!),
                            ),
                            const SizedBox(height: 16),

                            // Notes (Optional)
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.notes),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Fixed footer with buttons
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
                          onPressed: _isSaving
                              ? null
                              : _saveExpense, // Disable when saving
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
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
                              : const Text('Save Expense'),
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
