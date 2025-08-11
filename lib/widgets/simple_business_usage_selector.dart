import 'package:flutter/material.dart';

class SimpleBusinessUsageSelector extends StatefulWidget {
  final double businessUsagePercentage;
  final Function(double) onChanged;

  const SimpleBusinessUsageSelector({
    super.key,
    required this.businessUsagePercentage,
    required this.onChanged,
  });

  @override
  State<SimpleBusinessUsageSelector> createState() => _SimpleBusinessUsageSelectorState();
}

class _SimpleBusinessUsageSelectorState extends State<SimpleBusinessUsageSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<double>(
          value: widget.businessUsagePercentage,
          decoration: const InputDecoration(
            labelText: 'Business Usage',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
            helperText: 'Percentage of expense used for business purposes',
          ),
          items: const [
            DropdownMenuItem(value: 100.0, child: Text('100% - Fully Business')),
            DropdownMenuItem(value: 75.0, child: Text('75% - Mostly Business')),
            DropdownMenuItem(value: 50.0, child: Text('50% - Half Business')),
            DropdownMenuItem(value: 25.0, child: Text('25% - Partly Business')),
            DropdownMenuItem(value: 0.0, child: Text('0% - Personal Only')),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.onChanged(value);
            }
          },
        ),
        
        if (widget.businessUsagePercentage < 100) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, 
                         size: 16, 
                         color: Colors.amber[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Partial Business Usage: ${widget.businessUsagePercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Only ${widget.businessUsagePercentage.toStringAsFixed(0)}% of this expense VAT will be deductible.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}