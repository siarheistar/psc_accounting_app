/// Invoice Numbering Utility
/// Provides consistent invoice number generation across the app

class InvoiceNumbering {
  /// Generate a sequential invoice number based on current date and time
  /// Format: INV-YYYYMMDD-NNNNN (where NNNNN is a 5-digit sequence based on timestamp)
  static String generateInvoiceNumber() {
    final now = DateTime.now();

    // Create date portion: YYYYMMDD
    final datePortion = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    // Create sequence portion from time components for uniqueness
    // Use hour + minute + second + millisecond to create a 5-digit number
    final sequencePortion = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${(now.second + (now.millisecond / 1000)).floor().toString().padLeft(1, '0')}';

    return 'INV-$datePortion-$sequencePortion';
  }

  /// Generate an invoice number with custom prefix
  /// Format: PREFIX-YYYYMMDD-NNNNN
  static String generateInvoiceNumberWithPrefix(String prefix) {
    final now = DateTime.now();

    final datePortion = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    final sequencePortion = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${(now.second + (now.millisecond / 1000)).floor().toString().padLeft(1, '0')}';

    return '$prefix-$datePortion-$sequencePortion';
  }

  /// Validate if an invoice number follows the expected format
  static bool isValidInvoiceNumber(String invoiceNumber) {
    // Regular expression to match INV-YYYYMMDD-NNNNN format
    final regex = RegExp(r'^[A-Z]+-\d{8}-\d{5}$');
    return regex.hasMatch(invoiceNumber);
  }

  /// Extract date from invoice number
  static DateTime? getDateFromInvoiceNumber(String invoiceNumber) {
    try {
      if (!isValidInvoiceNumber(invoiceNumber)) return null;

      final parts = invoiceNumber.split('-');
      if (parts.length != 3) return null;

      final datePart = parts[1]; // YYYYMMDD
      final year = int.parse(datePart.substring(0, 4));
      final month = int.parse(datePart.substring(4, 6));
      final day = int.parse(datePart.substring(6, 8));

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Get a human-readable format of the invoice number
  static String formatInvoiceNumberForDisplay(String invoiceNumber) {
    try {
      final date = getDateFromInvoiceNumber(invoiceNumber);
      if (date == null) return invoiceNumber;

      final parts = invoiceNumber.split('-');
      final prefix = parts[0];
      final sequence = parts[2];

      return '$prefix ${date.day}/${date.month}/${date.year} #$sequence';
    } catch (e) {
      return invoiceNumber;
    }
  }

  /// Generate next invoice number based on existing invoice numbers
  /// This ensures sequential numbering within the same day
  static String generateNextInvoiceNumber(List<String> existingNumbers) {
    final now = DateTime.now();
    final datePortion = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    // Find all invoice numbers for today
    final todayNumbers = existingNumbers
        .where((number) => number.contains(datePortion))
        .toList();

    if (todayNumbers.isEmpty) {
      // First invoice of the day
      return 'INV-$datePortion-00001';
    }

    // Find the highest sequence number for today
    int maxSequence = 0;
    for (final number in todayNumbers) {
      try {
        final parts = number.split('-');
        if (parts.length == 3) {
          final sequence = int.parse(parts[2]);
          if (sequence > maxSequence) {
            maxSequence = sequence;
          }
        }
      } catch (e) {
        // Ignore invalid formats
      }
    }

    // Generate next sequence number
    final nextSequence = (maxSequence + 1).toString().padLeft(5, '0');
    return 'INV-$datePortion-$nextSequence';
  }
}
