import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vat_models.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';

class AddEnhancedExpenseDialog extends StatefulWidget {
  const AddEnhancedExpenseDialog({super.key});

  @override
  State<AddEnhancedExpenseDialog> createState() => _AddEnhancedExpenseDialogState();
}

class _AddEnhancedExpenseDialogState extends State<AddEnhancedExpenseDialog> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController = TextEditingController();
  final _netAmountController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _eworkerDaysController = TextEditingController();
  final _eworkerRateController = TextEditingController();
  final _mileageKmController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  ExpenseCategory? _selectedCategory;
  VATRate? _selectedVATRate;
  BusinessUsageOption? _selectedBusinessUsage;
  String _expenseType = 'general';
  VATCalculation? _vatCalculation;

  ExpenseCategoryData? _categoryData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCalculatingVAT = false;

  final List<String> _expenseTypes = [
    'general',
    'eworker',
    'mileage',
    'office_supplies',
    'travel',
    'professional_services',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _netAmountController.dispose();
    _supplierNameController.dispose();
    _notesController.dispose();
    _eworkerDaysController.dispose();
    _eworkerRateController.dispose();
    _mileageKmController.dispose();
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
    try {
      final data = await VATService.getExpenseCategories();
      setState(() {
        _categoryData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load expense categories: $e');
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

  Future<void> _calculateVAT() async {
    if (_netAmountController.text.isEmpty || _selectedVATRate == null) return;

    setState(() => _isCalculatingVAT = true);

    try {
      final netAmount = double.parse(_netAmountController.text);
      final businessUsage = _selectedBusinessUsage?.percentage ?? 100.0;

      final calculation = await VATService.calculateVAT(
        netAmount: netAmount,
        vatRateId: _selectedVATRate!.id,
        businessUsagePercentage: businessUsage,
      );

      setState(() {
        _vatCalculation = calculation;
        _isCalculatingVAT = false;
      });
    } catch (e) {
      setState(() => _isCalculatingVAT = false);
      _showErrorSnackBar('Failed to calculate VAT: $e');
    }
  }

  void _onCategoryChanged(ExpenseCategory? category) {
    setState(() {
      _selectedCategory = category;
      if (category?.defaultVatRateId != null) {
        _selectedVATRate = _categoryData?.vatRates
            .firstWhere((rate) => rate.id == category!.defaultVatRateId);
      }
      _selectedBusinessUsage = _categoryData?.businessUsageOptions
          .firstWhere((option) => option.percentage == category?.defaultBusinessUsage,
              orElse: () => _categoryData!.businessUsageOptions.first);
    });
    _calculateVAT();
  }

  void _onVATRateChanged(VATRate? rate) {
    setState(() {
      _selectedVATRate = rate;
    });
    _calculateVAT();
  }

  void _onBusinessUsageChanged(BusinessUsageOption? usage) {
    setState(() {
      _selectedBusinessUsage = usage;
    });
    _calculateVAT();
  }

  void _onNetAmountChanged() {
    _calculateVAT();
  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;

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
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final result = await VATService.createEnhancedExpense(
        companyId: selectedCompany.id.toString(),
        expenseDate: _expenseDate.toIso8601String(),
        description: _descriptionController.text.trim(),
        netAmount: double.parse(_netAmountController.text.trim()),
        categoryId: _selectedCategory!.id,
        vatRateId: _selectedVATRate?.id,
        supplierName: _supplierNameController.text.trim().isEmpty 
            ? null 
            : _supplierNameController.text.trim(),
        businessUsagePercentage: _selectedBusinessUsage?.percentage ?? 100.0,
        expenseType: _expenseType,
        eworkerDays: _eworkerDaysController.text.isEmpty 
            ? null 
            : double.tryParse(_eworkerDaysController.text),
        eworkerRate: _eworkerRateController.text.isEmpty 
            ? null 
            : double.tryParse(_eworkerRateController.text),
        mileageKm: _mileageKmController.text.isEmpty 
            ? null 
            : double.tryParse(_mileageKmController.text),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      if (mounted && result != null) {
        Navigator.of(context).pop(result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enhanced expense created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  Widget _buildVATCalculationCard() {
    if (_vatCalculation == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VAT Calculation',
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
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('VAT (${_vatCalculation!.vatRatePercentage.toStringAsFixed(1)}%):'),
                Text('${_getCurrencySymbol()}${_vatCalculation!.vatAmount.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gross Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${_getCurrencySymbol()}${_vatCalculation!.grossAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_vatCalculation!.deductibleAmount != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Deductible Amount (${_selectedBusinessUsage?.percentage ?? 100}%):'),
                  Text('${_getCurrencySymbol()}${_vatCalculation!.deductibleAmount!.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTypeSpecificFields() {
    switch (_expenseType) {
      case 'eworker':
        return Column(
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _eworkerDaysController,
                    decoration: const InputDecoration(
                      labelText: 'E-Worker Days',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _eworkerRateController,
                    decoration: InputDecoration(
                      labelText: 'Daily Rate',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.euro),
                      prefixText: _getCurrencySymbol(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      case 'mileage':
        return Column(
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _mileageKmController,
              decoration: const InputDecoration(
                labelText: 'Mileage (km)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
                suffixText: 'km',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        const Text(
                          'Add Enhanced Expense',
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

                            DropdownButtonFormField<String>(
                              value: _expenseType,
                              decoration: const InputDecoration(
                                labelText: 'Expense Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: _expenseTypes
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type.replaceAll('_', ' ').toUpperCase()),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _expenseType = value!),
                            ),
                            const SizedBox(height: 16),

                            if (_categoryData != null) ...[
                              DropdownButtonFormField<ExpenseCategory>(
                                value: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: _categoryData!.categories
                                    .map((category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(category.categoryName),
                                        ))
                                    .toList(),
                                onChanged: _onCategoryChanged,
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a category';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<VATRate>(
                                value: _selectedVATRate,
                                decoration: const InputDecoration(
                                  labelText: 'VAT Rate',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.percent),
                                ),
                                items: _categoryData!.vatRates
                                    .map((rate) => DropdownMenuItem(
                                          value: rate,
                                          child: Text('${rate.rateName} (${rate.ratePercentage}%)'),
                                        ))
                                    .toList(),
                                onChanged: _onVATRateChanged,
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<BusinessUsageOption>(
                                value: _selectedBusinessUsage,
                                decoration: const InputDecoration(
                                  labelText: 'Business Usage',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.business),
                                ),
                                items: _categoryData!.businessUsageOptions
                                    .map((option) => DropdownMenuItem(
                                          value: option,
                                          child: Text('${option.label} (${option.percentage}%)'),
                                        ))
                                    .toList(),
                                onChanged: _onBusinessUsageChanged,
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: _netAmountController,
                              decoration: InputDecoration(
                                labelText: 'Net Amount',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.euro),
                                prefixText: _getCurrencySymbol(),
                                suffixIcon: _isCalculatingVAT
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              onChanged: (_) => _onNetAmountChanged(),
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
                            const SizedBox(height: 16),

                            _buildVATCalculationCard(),

                            TextFormField(
                              controller: _supplierNameController,
                              decoration: const InputDecoration(
                                labelText: 'Supplier Name (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.store),
                              ),
                            ),
                            const SizedBox(height: 16),

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

                            _buildExpenseTypeSpecificFields(),
                            const SizedBox(height: 16),

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
                          onPressed: _isSaving ? null : _saveExpense,
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
                              : const Text('Save Enhanced Expense'),
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