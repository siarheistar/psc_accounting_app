class CurrencyUtils {
  static String getCurrencySymbol(String? currencyCode) {
    switch (currencyCode?.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'CHF':
        return 'CHF';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      default:
        return '€'; // Default to Euro
    }
  }

  static String formatAmount(double amount, String? currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static String getDefaultCurrencyForCountry(String country) {
    switch (country) {
      case 'Ireland':
      case 'Germany':
      case 'France':
      case 'Netherlands':
      case 'Belgium':
        return 'EUR';
      case 'United Kingdom':
        return 'GBP';
      case 'United States':
        return 'USD';
      default:
        return 'EUR';
    }
  }
}
