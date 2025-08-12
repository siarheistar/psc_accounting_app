import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../models/vat_models.dart';
import '../services/database_service.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../widgets/gross_vat_calculator_widget.dart';

class EditExpenseDialog extends StatefulWidget {
  final Expense expense;

  const EditExpenseDialog({super.key, required this.expense});

  @override
  State<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<EditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _grossAmountController;
  late final TextEditingController _netAmountController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isLoading = true;

  List<String> _categories = [];
  
  // VAT-related fields
  VATRate? _selectedVATRate;
  VATCalculation? _vatCalculation;
  List<VATRate> _vatRates = [];
  bool _isLoadingVATRates = true;

  @override
  void initState() {
    super.initState();
    print('💰 [EditExpenseDialog] === INITIALIZING EDIT DIALOG ===');
    print('💰 [EditExpenseDialog] Received expense data:');
    print('💰 [EditExpenseDialog] - ID: ${widget.expense.id}');
    print(
        '💰 [EditExpenseDialog] - Description: ${widget.expense.description}');
    print('💰 [EditExpenseDialog] - Category: ${widget.expense.category}');
    print('💰 [EditExpenseDialog] - Amount: ${widget.expense.amount}');
    print('💰 [EditExpenseDialog] - Date: ${widget.expense.date}');
    print('💰 [EditExpenseDialog] - Status: ${widget.expense.status}');
    print('💰 [EditExpenseDialog] - Notes: ${widget.expense.notes}');
    _initializeCompanyContext();
    _loadData();
    _loadVATRates();
  }

  Future<void> _loadData() async {
    try {
      final dbService = DatabaseService();
      final categories = await dbService.getExpenseCategories();

      setState(() {
        _categories = categories;
        _isLoading = false;
      });

      // Initialize controllers after categories are loaded
      _initializeControllers();
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ [EditExpenseDialog] Error loading categories: $e');
      // Use fallback categories if loading fails
      _categories = [
        'Office',
        'Technology',
        'Meals',
        'Travel',
        'Marketing',
        'Utilities',
        'Professional Services',
        'Supplies',
        'Other'
      ];
      _initializeControllers();
    }
  }

  Future<void> _loadVATRates() async {
    try {
      final rates = await VATService.getVATRates(country: 'Ireland', activeOnly: true);
      setState(() {
        _vatRates = rates;
        _isLoadingVATRates = false;
        // Try to set VAT rate based on existing expense VAT rate
        if (widget.expense.vatRate != null) {
          _selectedVATRate = rates.firstWhere(
            (rate) => rate.ratePercentage == widget.expense.vatRate,
            orElse: () => rates.isNotEmpty ? rates.first : VATRate(id: 0, country: '', rateName: '', ratePercentage: 0, effectiveFrom: DateTime.now()),
          );
        }
      });
    } catch (e) {
      setState(() => _isLoadingVATRates = false);
      print('Error loading VAT rates: $e');
    }
  }

  void _initializeControllers() {
    _descriptionController =
        TextEditingController(text: widget.expense.description);
    // Use gross amount if available, otherwise use the legacy amount field
    _grossAmountController = TextEditingController(
        text: (widget.expense.grossAmount ?? widget.expense.amount).toString());
    // Initialize net amount from existing expense data
    _netAmountController = TextEditingController(
        text: (widget.expense.netAmount ?? widget.expense.amount).toString());
    _notesController = TextEditingController(text: widget.expense.notes ?? '');

    // Initialize category with validation to ensure it matches dropdown options
    _selectedCategory = _categories.contains(widget.expense.category)
        ? widget.expense.category
        : 'Other'; // Default to 'Other' if category is not in the list

    _selectedDate = widget.expense.date;

    print(
        '💰 [EditExpenseDialog] Category initialized: ${widget.expense.category} -> $_selectedCategory');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _grossAmountController.dispose();
    _netAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeCompanyContext() {
    print('🔍 [DEBUG] === COMPANY CONTEXT INITIALIZATION (EDIT EXPENSE) ===');

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
        '🔍 [DEBUG] === END COMPANY CONTEXT INITIALIZATION (EDIT EXPENSE) ===');
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
      }
    });
  }

  double? _getGrossAmount() {
    final text = _grossAmountController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    print('💰 [EditExpenseDialog] === STARTING EXPENSE UPDATE ===');

    final dbService = DatabaseService();
    final preCheckCompany = SimpleCompanyContext.selectedCompany;

    if (preCheckCompany == null || !dbService.hasCompanyContext) {
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
      print('💰 [EditExpenseDialog] Creating updated expense object...');
      print('💰 [EditExpenseDialog] Original expense ID: ${widget.expense.id}');
      print('💰 [EditExpenseDialog] Form values:');
      print(
          '💰 [EditExpenseDialog] - Description: ${_descriptionController.text}');
      print('💰 [EditExpenseDialog] - Category: $_selectedCategory');
      print('💰 [EditExpenseDialog] - Gross Amount: ${_grossAmountController.text}');
      print('💰 [EditExpenseDialog] - Date: $_selectedDate');
      print('💰 [EditExpenseDialog] - Notes: ${_notesController.text}');

      final grossAmount = double.parse(_grossAmountController.text);
      final netAmount = _vatCalculation?.netAmount ?? grossAmount;

      final updatedExpense = Expense(
        id: widget.expense.id,
        date: _selectedDate,
        description: _descriptionController.text,
        category: _selectedCategory,
        amount: grossAmount, // Use gross amount for legacy compatibility
        status: widget.expense.status, // Keep existing status
        notes: _notesController.text,
        // VAT fields
        vatRate: _selectedVATRate?.ratePercentage,
        vatAmount: _vatCalculation?.vatAmount,
        netAmount: _vatCalculation?.netAmount ?? netAmount,
        grossAmount: _vatCalculation?.grossAmount ?? grossAmount,
      );

      print('💰 [EditExpenseDialog] Updated expense object created:');
      print('💰 [EditExpenseDialog] - ID: ${updatedExpense.id}');
      print(
          '💰 [EditExpenseDialog] - Description: ${updatedExpense.description}');
      print('💰 [EditExpenseDialog] - Category: ${updatedExpense.category}');
      print('💰 [EditExpenseDialog] - Amount: ${updatedExpense.amount}');
      print('💰 [EditExpenseDialog] - JSON: ${updatedExpense.toJson()}');

      print('💰 [EditExpenseDialog] Calling updateExpense...');
      await dbService.updateExpense(updatedExpense);

      print('💰 [EditExpenseDialog] Expense update completed successfully');

      // Use a slight delay before navigation to avoid Navigator lock issues
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        Navigator.of(context)
            .pop(updatedExpense); // Return updated expense object
      }
    } catch (e) {
      print('❌ [EditExpenseDialog] Error in _updateExpense: $e');
      print('❌ [EditExpenseDialog] Error type: ${e.runtimeType}');

      // Add delay before showing error dialog to avoid Navigator conflicts
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted && Navigator.of(context).canPop()) {
        try {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Expense Update Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to update expense:'),
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
        } catch (navError) {
          print(
              '❌ [EditExpenseDialog] Navigation error showing dialog: $navError');
          // If we can't show the dialog, just pop the main dialog
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
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
    if (_isLoading) {
      return const AlertDialog(
        title: Text('Edit Expense'),
        content: SizedBox(
          width: 400,
          height: 200,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Edit Expense'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
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
                  businessUsagePercentage: 100.0, // Default to 100% for expenses
                  onCalculationChanged: _onVATCalculationChanged,
                  isLoading: _isLoadingVATRates,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(), // Return null to indicate cancellation
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateExpense,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
