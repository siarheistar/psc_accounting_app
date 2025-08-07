import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../services/database_service.dart';
import '../context/simple_company_context.dart';

class EditPayrollDialog extends StatefulWidget {
  final PayrollEntry payrollEntry;

  const EditPayrollDialog({super.key, required this.payrollEntry});

  @override
  State<EditPayrollDialog> createState() => _EditPayrollDialogState();
}

class _EditPayrollDialogState extends State<EditPayrollDialog> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  // Form controllers
  late final TextEditingController _grossPayController;
  late final TextEditingController _deductionsController;
  late final TextEditingController _netPayController;

  // Form values
  late String? _selectedEmployee;
  late String _period;
  late DateTime _payDate;

  // Data lists
  List<String> _employees = [];
  List<String> _periodOptions = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('💰 [EditPayrollDialog] === INITIALIZING EDIT DIALOG ===');
    print('💰 [EditPayrollDialog] Received payroll data:');
    print('💰 [EditPayrollDialog] - ID: ${widget.payrollEntry.id}');
    print(
        '💰 [EditPayrollDialog] - Employee: ${widget.payrollEntry.employeeName}');
    print('💰 [EditPayrollDialog] - Period: ${widget.payrollEntry.period}');
    print(
        '💰 [EditPayrollDialog] - Gross Pay: ${widget.payrollEntry.grossPay}');
    print(
        '💰 [EditPayrollDialog] - Deductions: ${widget.payrollEntry.deductions}');
    print('💰 [EditPayrollDialog] - Net Pay: ${widget.payrollEntry.netPay}');
    print('💰 [EditPayrollDialog] - Pay Date: ${widget.payrollEntry.payDate}');

    // Initialize period first before calling _setCurrentPeriod
    _period = widget.payrollEntry.period;
    _payDate = widget.payrollEntry.payDate ?? DateTime.now();

    _initializeCompanyContext();
    _loadData();
    _setCurrentPeriod();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '👥 EditPayrollDialog: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('👥 EditPayrollDialog: No company context available');
    }
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

        _isLoading = false;
      });

      // Initialize controllers after data is loaded
      _initializeControllers();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Data Loading Failed', 'Failed to load data: $e');

      // Use fallback data if loading fails
      _employees = ['John Demo', 'Sarah Demo', 'Mike Demo'];
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    _grossPayController =
        TextEditingController(text: widget.payrollEntry.grossPay.toString());
    _deductionsController =
        TextEditingController(text: widget.payrollEntry.deductions.toString());
    _netPayController =
        TextEditingController(text: widget.payrollEntry.netPay.toString());

    // Initialize employee with validation to ensure it matches dropdown options
    _selectedEmployee = _employees.contains(widget.payrollEntry.employeeName)
        ? widget.payrollEntry.employeeName
        : _employees.isNotEmpty
            ? _employees.first
            : null;

    // Add listeners to calculate net pay automatically
    _grossPayController.addListener(_calculateNetPay);
    _deductionsController.addListener(_calculateNetPay);

    print(
        '💰 [EditPayrollDialog] Employee initialized: ${widget.payrollEntry.employeeName} -> $_selectedEmployee');
    print('💰 [EditPayrollDialog] Period initialized: $_period');
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

  Future<void> _updatePayrollEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployee == null) {
      _showErrorDialog('Validation Error', 'Please select an employee');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedPayrollEntry = PayrollEntry(
        id: widget.payrollEntry.id,
        period: _period,
        employeeName: _selectedEmployee!,
        grossPay: double.parse(_grossPayController.text.trim()),
        deductions: double.parse(_deductionsController.text.trim()),
        netPay: double.parse(_netPayController.text.trim()),
        payDate: _payDate,
        employeeId: widget.payrollEntry.employeeId,
      );

      await _dbService.updatePayrollEntry(updatedPayrollEntry);

      if (mounted) {
        Navigator.of(context).pop(updatedPayrollEntry);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payroll entry updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Payroll Update Failed', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        const Text(
                          'Edit Payroll Entry',
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
                            decoration: const InputDecoration(
                              labelText: 'Gross Pay',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: '\$',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter gross pay';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid amount';
                              }
                              if (double.parse(value) <= 0) {
                                return 'Gross pay must be greater than 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Deductions
                          TextFormField(
                            controller: _deductionsController,
                            decoration: const InputDecoration(
                              labelText: 'Deductions',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.remove_circle_outline),
                              prefixText: '\$',
                              helperText: 'Tax, insurance, pension, etc.',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter deductions (enter 0 if none)';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid amount';
                              }
                              if (double.parse(value) < 0) {
                                return 'Deductions cannot be negative';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Net Pay (Auto-calculated)
                          TextFormField(
                            controller: _netPayController,
                            decoration: const InputDecoration(
                              labelText: 'Net Pay',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_balance_wallet),
                              prefixText: '\$',
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
                                          Text('\$$grossText'),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Deductions:'),
                                          Text('-\$$deductionsText'),
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
                                            '\$$netText',
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
                          onPressed: _updatePayrollEntry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Update Payroll Entry'),
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
