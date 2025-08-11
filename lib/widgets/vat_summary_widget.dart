import 'package:flutter/material.dart';
import '../models/vat_models.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';

class VATSummaryWidget extends StatelessWidget {
  final VATSummary summary;
  final bool showDetails;
  final VoidCallback? onViewDetails;

  const VATSummaryWidget({
    super.key,
    required this.summary,
    this.showDetails = true,
    this.onViewDetails,
  });

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '€';
  }

  Color _getVATDueColor() {
    if (summary.netVatDue > 0) return Colors.red[600]!;
    if (summary.netVatDue < 0) return Colors.green[600]!;
    return Colors.grey[600]!;
  }

  String _getVATDueLabel() {
    if (summary.netVatDue > 0) return 'VAT Owed to Revenue';
    if (summary.netVatDue < 0) return 'VAT Refund Due';
    return 'No VAT Due';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildPeriodInfo(),
            const SizedBox(height: 20),
            
            if (showDetails) ...[
              _buildSalesSection(),
              const SizedBox(height: 16),
              _buildPurchasesSection(),
              const SizedBox(height: 20),
            ],
            
            _buildNetVATDue(),
            
            if (onViewDetails != null && !showDetails) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: onViewDetails,
                  child: const Text('View Details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.account_balance, color: Colors.blue[700], size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'VAT Summary Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Text(
            'Ireland',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Period: ${summary.periodStart} to ${summary.periodEnd}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Sales & Output VAT', Icons.trending_up, Colors.green),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildAmountRow(
                'Total Sales:',
                summary.totalSales,
                isSubtle: true,
              ),
              const SizedBox(height: 4),
              _buildAmountRow(
                'Output VAT:',
                summary.totalOutputVat,
                textColor: Colors.green[700],
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPurchasesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Purchases & Input VAT', Icons.trending_down, Colors.blue),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildAmountRow(
                'Total Purchases:',
                summary.totalPurchases,
                isSubtle: true,
              ),
              const SizedBox(height: 4),
              _buildAmountRow(
                'Input VAT:',
                summary.totalInputVat,
                textColor: Colors.blue[700],
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetVATDue() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getVATDueColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getVATDueColor().withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                summary.netVatDue > 0 ? Icons.payment : 
                summary.netVatDue < 0 ? Icons.account_balance_wallet : 
                Icons.check_circle,
                color: _getVATDueColor(),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getVATDueLabel(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getVATDueColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net VAT Amount:',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '${_getCurrencySymbol()}${summary.netVatDue.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getVATDueColor(),
                ),
              ),
            ],
          ),
          
          if (summary.netVatDue != 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      summary.netVatDue > 0
                          ? 'This amount needs to be paid to Revenue by the due date'
                          : 'This amount should be claimed as a refund from Revenue',
                      style: TextStyle(
                        fontSize: 11,
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isSubtle = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isSubtle ? Colors.grey[600] : textColor,
            fontSize: isSubtle ? 12 : 14,
          ),
        ),
        Text(
          '${_getCurrencySymbol()}${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isSubtle ? Colors.grey[600] : textColor,
            fontSize: isSubtle ? 12 : 14,
          ),
        ),
      ],
    );
  }
}