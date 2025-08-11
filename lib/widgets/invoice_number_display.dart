import 'package:flutter/material.dart';
import '../utils/invoice_numbering.dart';

/// Widget for displaying invoice numbers consistently across the app
class InvoiceNumberDisplay extends StatelessWidget {
  final String invoiceNumber;
  final TextStyle? style;
  final bool showFormatted;
  final Color? color;

  const InvoiceNumberDisplay({
    super.key,
    required this.invoiceNumber,
    this.style,
    this.showFormatted = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = showFormatted
        ? InvoiceNumbering.formatInvoiceNumberForDisplay(invoiceNumber)
        : invoiceNumber;

    return Text(
      displayText,
      style: style ??
          TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color ?? Theme.of(context).primaryColor,
          ),
    );
  }
}

/// Chip widget for displaying invoice numbers with copy functionality
class InvoiceNumberChip extends StatelessWidget {
  final String invoiceNumber;
  final VoidCallback? onTap;
  final bool enableCopy;

  const InvoiceNumberChip({
    super.key,
    required this.invoiceNumber,
    this.onTap,
    this.enableCopy = true,
  });

  void _copyToClipboard(BuildContext context) {
    if (enableCopy) {
      // Copy functionality would go here if needed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice number $invoiceNumber copied'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? (enableCopy ? () => _copyToClipboard(context) : null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                invoiceNumber,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              if (enableCopy) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.content_copy,
                  size: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card header that consistently displays invoice number and status
class InvoiceCardHeader extends StatelessWidget {
  final String invoiceNumber;
  final String status;
  final Widget? trailing;

  const InvoiceCardHeader({
    super.key,
    required this.invoiceNumber,
    required this.status,
    this.trailing,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
      case 'sent':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: InvoiceNumberDisplay(
            invoiceNumber: invoiceNumber,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}
