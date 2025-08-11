import 'package:flutter/material.dart';
import '../models/vat_models.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';

class VATCalculatorWidget extends StatefulWidget {
  final double? netAmount;
  final VATRate? selectedVATRate;
  final double? businessUsagePercentage;
  final Function(VATCalculation?) onCalculationChanged;
  final bool isLoading;

  const VATCalculatorWidget({
    super.key,
    this.netAmount,
    this.selectedVATRate,
    this.businessUsagePercentage = 100.0,
    required this.onCalculationChanged,
    this.isLoading = false,
  });

  @override
  State<VATCalculatorWidget> createState() => _VATCalculatorWidgetState();
}

class _VATCalculatorWidgetState extends State<VATCalculatorWidget> {
  VATCalculation? _calculation;
  bool _isCalculating = false;

  @override
  void didUpdateWidget(VATCalculatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.netAmount != oldWidget.netAmount ||
        widget.selectedVATRate != oldWidget.selectedVATRate ||
        widget.businessUsagePercentage != oldWidget.businessUsagePercentage) {
      _calculateVAT();
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '€';
  }

  Future<void> _calculateVAT() async {
    if (widget.netAmount == null || 
        widget.selectedVATRate == null || 
        widget.netAmount! <= 0) {
      setState(() {
        _calculation = null;
      });
      widget.onCalculationChanged(null);
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final calculation = await VATService.calculateVAT(
        netAmount: widget.netAmount!,
        vatRateId: widget.selectedVATRate!.id,
        businessUsagePercentage: widget.businessUsagePercentage ?? 100.0,
      );

      setState(() {
        _calculation = calculation;
        _isCalculating = false;
      });
      widget.onCalculationChanged(calculation);
    } catch (e) {
      setState(() {
        _calculation = null;
        _isCalculating = false;
      });
      widget.onCalculationChanged(null);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VAT calculation failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_calculation == null && !_isCalculating) {
      return const SizedBox.shrink();
    }

    if (_isCalculating || widget.isLoading) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text('Calculating VAT...'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'VAT Calculation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (widget.selectedVATRate != null)
                  Chip(
                    label: Text(
                      widget.selectedVATRate!.rateName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue[50],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildCalculationRow(
              'Net Amount:',
              '${_getCurrencySymbol()}${_calculation!.netAmount.toStringAsFixed(2)}',
            ),
            
            _buildCalculationRow(
              'VAT (${_calculation!.vatRatePercentage.toStringAsFixed(1)}%):',
              '${_getCurrencySymbol()}${_calculation!.vatAmount.toStringAsFixed(2)}',
            ),
            
            const Divider(height: 20),
            
            _buildCalculationRow(
              'Gross Amount:',
              '${_getCurrencySymbol()}${_calculation!.grossAmount.toStringAsFixed(2)}',
              isBold: true,
            ),
            
            if (_calculation!.deductibleAmount != null && 
                widget.businessUsagePercentage != 100.0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Usage: ${widget.businessUsagePercentage?.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildCalculationRow(
                      'Deductible VAT:',
                      '${_getCurrencySymbol()}${_calculation!.deductibleAmount!.toStringAsFixed(2)}',
                      textColor: const Color(0xFF16A34A),
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
            
            if (widget.businessUsagePercentage != null && 
                widget.businessUsagePercentage! < 100.0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                         size: 16, 
                         color: Colors.amber[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Partial business usage applied to VAT calculation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value, {
    bool isBold = false,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}