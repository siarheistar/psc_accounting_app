import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../services/database_service.dart';
import '../context/simple_company_context.dart';

class EditBankStatementDialog extends StatefulWidget {
  final BankStatement bankStatement;

  const EditBankStatementDialog({super.key, required this.bankStatement});

  @override
  State<EditBankStatementDialog> createState() =>
      _EditBankStatementDialogState();
}

class _EditBankStatementDialogState extends State<EditBankStatementDialog> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  // Form controllers
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;

  // Form values
  late String _selectedType;
  late DateTime _selectedDate;
  bool _isLoading = false;

  // Data lists
  final List<String> _typeOptions = ['deposit', 'withdrawal', 'transfer'];

  @override
  void initState() {
    super.initState();
    print('🏦 [EditBankStatementDialog] === INITIALIZING EDIT DIALOG ===');
    print('🏦 [EditBankStatementDialog] Received bank statement data:');
    print('🏦 [EditBankStatementDialog] - ID: ${widget.bankStatement.id}');
    print(
        '🏦 [EditBankStatementDialog] - Description: ${widget.bankStatement.description}');
    print(
        '🏦 [EditBankStatementDialog] - Type: ${widget.bankStatement.transactionType}');
    print(
        '🏦 [EditBankStatementDialog] - Amount: ${widget.bankStatement.amount}');
    print(
        '🏦 [EditBankStatementDialog] - Date: ${widget.bankStatement.transactionDate}');
    print(
        '🏦 [EditBankStatementDialog] - Reference: ${widget.bankStatement.reference}');

    _initializeCompanyContext();
    _initializeControllers();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '🏦 EditBankStatementDialog: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('🏦 EditBankStatementDialog: No company context available');
    }
  }

  void _initializeControllers() {
    _descriptionController =
        TextEditingController(text: widget.bankStatement.description);
    _amountController =
        TextEditingController(text: widget.bankStatement.amount.toString());
    _referenceController =
        TextEditingController(text: widget.bankStatement.reference ?? '');

    // Initialize transaction type with validation to ensure it matches dropdown options
    _selectedType = _typeOptions
            .contains(widget.bankStatement.transactionType.toLowerCase())
        ? widget.bankStatement.transactionType.toLowerCase()
        : 'deposit'; // Default to 'deposit' if type is not in the list

    _selectedDate = widget.bankStatement.transactionDate;

    print(
        '🏦 [EditBankStatementDialog] Type initialized: ${widget.bankStatement.transactionType} -> $_selectedType');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _updateBankStatement() async {
    if (!_formKey.currentState!.validate()) return;

    print(
        '🏦 [EditBankStatementDialog] === STARTING BANK STATEMENT UPDATE ===');

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

    setState(() => _isLoading = true);

    try {
      print(
          '🏦 [EditBankStatementDialog] Creating updated bank statement object...');
      print(
          '🏦 [EditBankStatementDialog] Original bank statement ID: ${widget.bankStatement.id}');
      print('🏦 [EditBankStatementDialog] Form values:');
      print(
          '🏦 [EditBankStatementDialog] - Description: ${_descriptionController.text}');
      print('🏦 [EditBankStatementDialog] - Type: $_selectedType');
      print('🏦 [EditBankStatementDialog] - Amount: ${_amountController.text}');
      print('🏦 [EditBankStatementDialog] - Date: $_selectedDate');
      print(
          '🏦 [EditBankStatementDialog] - Reference: ${_referenceController.text}');

      final updatedBankStatement = BankStatement(
        id: widget.bankStatement.id,
        transactionDate: _selectedDate,
        description: _descriptionController.text,
        transactionType: _selectedType,
        amount: double.parse(_amountController.text),
        balance: widget.bankStatement.balance, // Keep existing balance
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        reconciled: widget.bankStatement.reconciled,
      );

      print(
          '🏦 [EditBankStatementDialog] Updated bank statement object created:');
      print('🏦 [EditBankStatementDialog] - ID: ${updatedBankStatement.id}');
      print(
          '🏦 [EditBankStatementDialog] - Description: ${updatedBankStatement.description}');
      print(
          '🏦 [EditBankStatementDialog] - Type: ${updatedBankStatement.transactionType}');
      print(
          '🏦 [EditBankStatementDialog] - Amount: ${updatedBankStatement.amount}');
      print(
          '🏦 [EditBankStatementDialog] - JSON: ${updatedBankStatement.toJson()}');

      print('🏦 [EditBankStatementDialog] Calling updateBankStatement...');
      await dbService.updateBankStatement(updatedBankStatement);

      print(
          '🏦 [EditBankStatementDialog] Bank statement update completed successfully');

      // Use a slight delay before navigation to avoid Navigator lock issues
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        Navigator.of(context)
            .pop(updatedBankStatement); // Return updated bank statement object
      }
    } catch (e) {
      print('❌ [EditBankStatementDialog] Error in _updateBankStatement: $e');
      print('❌ [EditBankStatementDialog] Error type: ${e.runtimeType}');

      // Add delay before showing error dialog to avoid Navigator conflicts
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted && Navigator.of(context).canPop()) {
        try {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Bank Statement Update Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to update bank statement:'),
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
              '❌ [EditBankStatementDialog] Navigation error showing dialog: $navError');
          // If we can't show the dialog, just pop the main dialog
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('Edit Bank Statement'),
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
      title: const Text('Edit Bank Statement'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date and Type Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction Date',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _typeOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a type';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
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

                // Amount and Reference Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Reference (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
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
          onPressed: _updateBankStatement,
          child: const Text('Update'),
        ),
      ],
    );
  }
}
