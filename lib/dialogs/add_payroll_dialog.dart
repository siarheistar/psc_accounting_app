import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../services/database_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';

class AddPayrollDialog extends StatefulWidget {
  const AddPayrollDialog({super.key});

  @override
  State<AddPayrollDialog> createState() => _AddPayrollDialogState();
}

class _AddPayrollDialogState extends State<AddPayrollDialog> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  // Form controllers
  final _grossPayController = TextEditingController();
  final _deductionsController = TextEditingController();
  final _netPayController = TextEditingController();

  // Form values
  String? _selectedEmployee;
  String _period = '';
  DateTime _payDate = DateTime.now();

  // Data lists
  List<String> _employees = [];
  List<String> _periodOptions = [];

  bool _isLoading = true;
  bool _isSaving = false; // Add saving state to prevent double submission

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadData();
    _setCurrentPeriod();

    // Add listeners to calculate net pay automatically
    _grossPayController.addListener(_calculateNetPay);
    _deductionsController.addListener(_calculateNetPay);
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '👥 AddPayrollDialog: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('👥 AddPayrollDialog: No company context available');
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '\$'; // Default fallback
  }

  @override
  void dispose() {
    _grossPayController.dispose();
    _deductionsController.dispose();
    _netPayController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final employees = await _dbService.getEmployees();
      debugPrint('👥 Raw employees from database: $employees');

      setState(() {
        // Remove duplicates and ensure unique employee names
        _employees = employees.toSet().toList();
        debugPrint('👥 Processed unique employees: $_employees');
        debugPrint('👥 Selected employee: $_selectedEmployee');
        debugPrint(
            '👥 Is selected employee in list: ${_employees.contains(_selectedEmployee)}');

        // Reset selected employee if it's not in the list
        if (_selectedEmployee != null &&
            !_employees.contains(_selectedEmployee)) {
          debugPrint('👥 Resetting selected employee as it\'s not in the list');
          _selectedEmployee = null;
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Data Loading Failed', 'Failed to load data: $e');
    }
  }

  void _setCurrentPeriod() {
    final now = DateTime.now();
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    // Generate period options for current year and previous year
    _periodOptions = [];
    final currentYear = now.year;
    final previousYear = currentYear - 1;

    // Add previous year months
    for (final month in monthNames) {
      _periodOptions.add('$month $previousYear');
    }

    // Add current year months
    for (final month in monthNames) {
      _periodOptions.add('$month $currentYear');
    }

    _period = '${monthNames[now.month - 1]} ${now.year}';

    // Ensure the period is valid (exists in options)
    if (!_periodOptions.contains(_period)) {
      _period = _periodOptions
          .last; // Default to last option if current period not found
    }
  }

  void _calculateNetPay() {
    final grossPay = double.tryParse(_grossPayController.text) ?? 0.0;
    final deductions = double.tryParse(_deductionsController.text) ?? 0.0;
    final netPay = grossPay - deductions;

    _netPayController.text = netPay.toStringAsFixed(2);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
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
                  message,
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

  Future<void> _selectPayDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _payDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _payDate) {
      setState(() {
        _payDate = picked;
      });
    }
  }

  Future<void> _savePayrollEntry() async {
    // Prevent double submission
    if (_isSaving) {
      debugPrint(
          '👥 [AddPayrollDialog] Save already in progress, ignoring duplicate request');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployee == null) {
      _showErrorDialog('Validation Error', 'Please select an employee');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });

    try {
      debugPrint('👥 === SAVING PAYROLL ENTRY ===');
      debugPrint('👥 Employee: $_selectedEmployee');
      debugPrint('👥 Period: $_period');
      debugPrint('👥 Gross Pay: ${_grossPayController.text.trim()}');

      final payrollEntry = PayrollEntry(
        id: '0', // Will be assigned by backend
        period: _period,
        employeeName: _selectedEmployee!,
        grossPay: double.parse(_grossPayController.text.trim()),
        deductions: double.parse(_deductionsController.text.trim()),
        netPay: double.parse(_netPayController.text.trim()),
        payDate: _payDate,
      );

      await _dbService.insertPayrollEntry(payrollEntry);

      debugPrint('👥 ✅ Payroll entry saved successfully');

      if (mounted) {
        // Return null to indicate successful completion without the object
        // This prevents the home page from trying to insert it again
        Navigator.of(context).pop(null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payroll entry created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('👥 === DIALOG INSERT ERROR ===');
      debugPrint('👥 Exception: $e');
      if (mounted) {
        String errorTitle = 'Payroll Creation Failed';
        String errorMessage = e.toString();

        // Parse common error types for user-friendly messages
        if (errorMessage.contains('exceeds maximum allowed value') ||
            errorMessage
                .contains('Amount value exceeds the maximum allowed limit')) {
          errorTitle = 'Amount Too Large';
          errorMessage =
              'The entered amount is too large. Please enter an amount less than €99,999,999.99';
        } else if (errorMessage.contains('numeric field overflow')) {
          errorTitle = 'Invalid Amount';
          errorMessage =
              'The amount entered is too large for the system. Please enter a smaller amount.';
        } else if (errorMessage.contains('Connection refused') ||
            errorMessage.contains('No host specified') ||
            errorMessage.contains('Network is unreachable')) {
          errorTitle = 'Connection Error';
          errorMessage =
              'Unable to connect to the server. Please check your internet connection and try again.';
        } else if (errorMessage.contains('Server error') ||
            errorMessage.contains('500')) {
          errorTitle = 'Server Error';
          errorMessage =
              'A server error occurred. Please try again in a few moments.';
        } else if (errorMessage.contains('required')) {
          errorTitle = 'Missing Information';
          errorMessage = 'Please fill in all required fields and try again.';
        }

        // Show detailed error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Flexible(child: Text(errorTitle)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Technical Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
        constraints:
            const BoxConstraints(maxHeight: 800), // Add height constraint
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                // Make it scrollable for smaller screens
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        const Text(
                          'Add New Payroll Entry',
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
                    const SizedBox(height: 24),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Employee Selection
                          DropdownButtonFormField<String>(
                            value: _employees.contains(_selectedEmployee)
                                ? _selectedEmployee
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Employee',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: _employees
                                .map((employee) => DropdownMenuItem(
                                      value: employee,
                                      child: Text(employee),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedEmployee = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select an employee';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Period Selection
                          DropdownButtonFormField<String>(
                            value: _periodOptions.contains(_period)
                                ? _period
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Pay Period',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.date_range),
                            ),
                            items: _periodOptions
                                .map((period) => DropdownMenuItem(
                                      value: period,
                                      child: Text(period),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _period = value!),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a pay period';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Gross Pay
                          TextFormField(
                            controller: _grossPayController,
                            decoration: InputDecoration(
                              labelText: 'Gross Pay',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.attach_money),
                              prefixText: _getCurrencySymbol(),
                              helperText:
                                  'Maximum: ${_getCurrencySymbol()}99,999,999.99',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                              // Limit input length to prevent overflow
                              LengthLimitingTextInputFormatter(
                                  12), // 99999999.99 = 11 chars max
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter gross pay';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null) {
                                return 'Please enter a valid amount';
                              }
                              if (amount <= 0) {
                                return 'Gross pay must be greater than 0';
                              }
                              if (amount > 99999999.99) {
                                return 'Amount exceeds maximum limit of ${_getCurrencySymbol()}99,999,999.99';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Deductions
                          TextFormField(
                            controller: _deductionsController,
                            decoration: InputDecoration(
                              labelText: 'Deductions',
                              border: const OutlineInputBorder(),
                              prefixIcon:
                                  const Icon(Icons.remove_circle_outline),
                              prefixText: _getCurrencySymbol(),
                              helperText:
                                  'Tax, insurance, pension, etc. Max: ${_getCurrencySymbol()}99,999,999.99',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                              LengthLimitingTextInputFormatter(12),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter deductions (enter 0 if none)';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null) {
                                return 'Please enter a valid amount';
                              }
                              if (amount < 0) {
                                return 'Deductions cannot be negative';
                              }
                              if (amount > 99999999.99) {
                                return 'Amount exceeds maximum limit of ${_getCurrencySymbol()}99,999,999.99';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Net Pay (Auto-calculated)
                          TextFormField(
                            controller: _netPayController,
                            decoration: InputDecoration(
                              labelText: 'Net Pay',
                              border: const OutlineInputBorder(),
                              prefixIcon:
                                  const Icon(Icons.account_balance_wallet),
                              prefixText: _getCurrencySymbol(),
                              helperText: 'Automatically calculated',
                            ),
                            readOnly: true,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Pay Date
                          InkWell(
                            onTap: _selectPayDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Pay Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                '${_payDate.day}/${_payDate.month}/${_payDate.year}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Summary Card
                    ValueListenableBuilder(
                      valueListenable: _grossPayController,
                      builder: (context, grossValue, child) {
                        return ValueListenableBuilder(
                          valueListenable: _deductionsController,
                          builder: (context, deductionsValue, child) {
                            return ValueListenableBuilder(
                              valueListenable: _netPayController,
                              builder: (context, netValue, child) {
                                final grossText = grossValue.text.isEmpty
                                    ? '0.00'
                                    : grossValue.text;
                                final deductionsText =
                                    deductionsValue.text.isEmpty
                                        ? '0.00'
                                        : deductionsValue.text;
                                final netText = netValue.text.isEmpty
                                    ? '0.00'
                                    : netValue.text;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Payroll Summary',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Gross Pay:'),
                                          Text(
                                              '${_getCurrencySymbol()}$grossText'),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Deductions:'),
                                          Text(
                                              '-${_getCurrencySymbol()}$deductionsText'),
                                        ],
                                      ),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Net Pay:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${_getCurrencySymbol()}$netText',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
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
                              : _savePayrollEntry, // Disable when saving
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
                              : const Text('Save Payroll Entry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
