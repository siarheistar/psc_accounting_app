import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';

class AddEWorkerPeriodDialog extends StatefulWidget {
  const AddEWorkerPeriodDialog({super.key});

  @override
  State<AddEWorkerPeriodDialog> createState() => _AddEWorkerPeriodDialogState();
}

class _AddEWorkerPeriodDialogState extends State<AddEWorkerPeriodDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _totalDaysController = TextEditingController();
  final _dailyRateController = TextEditingController();
  
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodEnd = DateTime.now();
  double? _calculatedTotal;
  
  bool _isSaving = false;

  @override
  void dispose() {
    _totalDaysController.dispose();
    _dailyRateController.dispose();
    super.dispose();
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '€';
  }

  void _calculateTotal() {
    final days = double.tryParse(_totalDaysController.text);
    final rate = double.tryParse(_dailyRateController.text);
    
    if (days != null && rate != null) {
      setState(() {
        _calculatedTotal = days * rate;
      });
    } else {
      setState(() {
        _calculatedTotal = null;
      });
    }
  }

  Future<void> _selectPeriodStart() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _periodStart) {
      setState(() {
        _periodStart = picked;
        if (_periodStart.isAfter(_periodEnd)) {
          _periodEnd = _periodStart.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectPeriodEnd() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd,
      firstDate: _periodStart,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _periodEnd) {
      setState(() {
        _periodEnd = picked;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveEWorkerPeriod() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final result = await VATService.createEWorkerPeriod(
        companyId: selectedCompany.id.toString(),
        periodStart: _periodStart.toIso8601String(),
        periodEnd: _periodEnd.toIso8601String(),
        totalDays: double.parse(_totalDaysController.text),
        dailyRate: double.parse(_dailyRateController.text),
      );

      if (mounted && result != null) {
        Navigator.of(context).pop(result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-Worker period created successfully!'),
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
                Text('E-Worker Period Creation Failed'),
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
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.work, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  const Text(
                    'Add E-Worker Period',
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
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectPeriodStart,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Period Start',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.date_range),
                                ),
                                child: Text(
                                  '${_periodStart.day}/${_periodStart.month}/${_periodStart.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _selectPeriodEnd,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Period End',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.date_range),
                                ),
                                child: Text(
                                  '${_periodEnd.day}/${_periodEnd.month}/${_periodEnd.year}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _totalDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Total Days Worked',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          suffixText: 'days',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _calculateTotal(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter total days';
                          }
                          final days = double.tryParse(value);
                          if (days == null || days <= 0) {
                            return 'Please enter valid days';
                          }
                          if (days > 365) {
                            return 'Days cannot exceed 365';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _dailyRateController,
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
                        onChanged: (_) => _calculateTotal(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter daily rate';
                          }
                          final rate = double.tryParse(value);
                          if (rate == null || rate <= 0) {
                            return 'Please enter valid rate';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_calculatedTotal != null) ...[
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  'Period Summary',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Period Duration:'),
                                    Text('${_periodEnd.difference(_periodStart).inDays + 1} calendar days'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Working Days:'),
                                    Text('${_totalDaysController.text} days'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Daily Rate:'),
                                    Text('${_getCurrencySymbol()}${_dailyRateController.text}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Amount:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${_getCurrencySymbol()}${_calculatedTotal!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Card(
                        color: Colors.orange[50],
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'E-Worker Information',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• E-Worker periods track contracted work periods\n'
                                '• This is used for VAT calculations and reporting\n'
                                '• Ensure dates align with your contract terms',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
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
                    onPressed: _isSaving ? null : _saveEWorkerPeriod,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
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
                        : const Text('Save E-Worker Period'),
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