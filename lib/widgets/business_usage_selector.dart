import 'package:flutter/material.dart';
import '../models/vat_models.dart';

class BusinessUsageSelector extends StatefulWidget {
  final List<BusinessUsageOption> options;
  final BusinessUsageOption? selectedOption;
  final Function(BusinessUsageOption?) onChanged;
  final String? label;
  final bool isRequired;

  const BusinessUsageSelector({
    super.key,
    required this.options,
    this.selectedOption,
    required this.onChanged,
    this.label = 'Business Usage',
    this.isRequired = false,
  });

  @override
  State<BusinessUsageSelector> createState() => _BusinessUsageSelectorState();
}

class _BusinessUsageSelectorState extends State<BusinessUsageSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BusinessUsageOption>(
          value: widget.selectedOption,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.business),
            helperText: 'Percentage of expense used for business purposes',
            helperMaxLines: 2,
          ),
          items: widget.options.map((option) {
            return DropdownMenuItem<BusinessUsageOption>(
              value: option,
              child: Row(
                children: [
                  Expanded(
                    child: Text(option.label),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPercentageColor(option.percentage),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${option.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: widget.onChanged,
          validator: widget.isRequired
              ? (value) {
                  if (value == null) {
                    return 'Please select business usage percentage';
                  }
                  return null;
                }
              : null,
        ),
        
        if (widget.selectedOption != null) ...[
          const SizedBox(height: 8),
          _buildUsageInfoCard(),
        ],
      ],
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage == 100) return Colors.green;
    if (percentage >= 75) return Colors.blue;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildUsageInfoCard() {
    final option = widget.selectedOption!;
    
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 6),
                Text(
                  'Business Usage: ${option.percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            
            if (option.description != null) ...[
              const SizedBox(height: 4),
              Text(
                option.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[600],
                ),
              ),
            ],
            
            if (option.percentage < 100) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, 
                             size: 14, 
                             color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Partial Business Usage',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only ${option.percentage.toStringAsFixed(0)}% of the VAT will be deductible for business purposes.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (option.percentage == 100) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, 
                         size: 14, 
                         color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Full business expense - 100% VAT deductible',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
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
}