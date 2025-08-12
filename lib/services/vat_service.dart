import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../models/vat_models.dart';

class VATService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Get VAT rates for a specific country
  static Future<List<VATRate>> getVATRates({
    String country = 'Ireland',
    bool activeOnly = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/vat/rates').replace(queryParameters: {
        'country': country,
        'active_only': activeOnly.toString(),
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => VATRate.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load VAT rates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading VAT rates: $e');
      return [];
    }
  }

  /// Get expense categories with VAT rates and business usage options
  static Future<ExpenseCategoryData> getExpenseCategories() async {
    try {
      final uri = Uri.parse('$baseUrl/vat/expense-categories');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ExpenseCategoryData.fromJson(data);
      } else {
        throw Exception(
            'Failed to load expense categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading expense categories: $e');
      return ExpenseCategoryData(
        categories: [],
        vatRates: [],
        businessUsageOptions: [],
      );
    }
  }

  /// Calculate VAT amounts
  static Future<VATCalculation?> calculateVAT({
    required double netAmount,
    int? vatRateId,
    double? vatRatePercentage,
    double businessUsagePercentage = 100.0,
  }) async {
    try {
      final queryParams = <String, String>{
        'net_amount': netAmount.toString(),
        'business_usage_percentage': businessUsagePercentage.toString(),
      };

      if (vatRateId != null) {
        queryParams['vat_rate_id'] = vatRateId.toString();
      }
      if (vatRatePercentage != null) {
        queryParams['vat_rate_percentage'] = vatRatePercentage.toString();
      }

      final uri = Uri.parse('$baseUrl/vat/calculate')
          .replace(queryParameters: queryParams);
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return VATCalculation.fromJson(data);
      } else {
        throw Exception('Failed to calculate VAT: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating VAT: $e');
      return null;
    }
  }

  /// Calculate VAT amounts from gross amount (reverse calculation)
  static Future<VATCalculation?> calculateVATFromGross({
    required double grossAmount,
    int? vatRateId,
    double? vatRatePercentage,
    double businessUsagePercentage = 100.0,
  }) async {
    try {
      final queryParams = <String, String>{
        'gross_amount': grossAmount.toString(),
        'business_usage_percentage': businessUsagePercentage.toString(),
      };

      if (vatRateId != null) {
        queryParams['vat_rate_id'] = vatRateId.toString();
      }
      if (vatRatePercentage != null) {
        queryParams['vat_rate_percentage'] = vatRatePercentage.toString();
      }

      final uri = Uri.parse('$baseUrl/vat/calculate-from-gross')
          .replace(queryParameters: queryParams);
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return VATCalculation.fromJson(data);
      } else {
        // If backend doesn't support gross-to-net, calculate locally
        return _calculateVATFromGrossLocally(
          grossAmount: grossAmount,
          vatRatePercentage: vatRatePercentage ?? 0.0,
          businessUsagePercentage: businessUsagePercentage,
        );
      }
    } catch (e) {
      print('Error calculating VAT from gross: $e');
      // Fallback to local calculation
      return _calculateVATFromGrossLocally(
        grossAmount: grossAmount,
        vatRatePercentage: vatRatePercentage ?? 0.0,
        businessUsagePercentage: businessUsagePercentage,
      );
    }
  }

  /// Local calculation when backend doesn't support gross-to-net
  static VATCalculation _calculateVATFromGrossLocally({
    required double grossAmount,
    required double vatRatePercentage,
    double businessUsagePercentage = 100.0,
  }) {
    // Formula: net = gross / (1 + vat_rate/100)
    // VAT = gross - net
    final netAmount = grossAmount / (1 + vatRatePercentage / 100);
    final vatAmount = grossAmount - netAmount;
    final deductibleAmount = vatAmount * businessUsagePercentage / 100;

    return VATCalculation(
      netAmount: netAmount,
      vatAmount: vatAmount,
      grossAmount: grossAmount,
      vatRatePercentage: vatRatePercentage,
      businessUsagePercentage: businessUsagePercentage,
      deductibleAmount: deductibleAmount,
    );
  }

  /// Create enhanced expense
  static Future<Map<String, dynamic>?> createEnhancedExpense({
    required String companyId,
    required String expenseDate,
    required String description,
    required double netAmount,
    int? categoryId,
    int? vatRateId,
    String? supplierName,
    double businessUsagePercentage = 100.0,
    String expenseType = 'general',
    double? eworkerDays,
    double? eworkerRate,
    double? mileageKm,
    String? notes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/expenses/enhanced');

      final body = {
        'company_id': companyId,
        'expense_date': expenseDate,
        'description': description,
        'net_amount': netAmount,
        'category_id': categoryId,
        'vat_rate_id': vatRateId,
        'supplier_name': supplierName,
        'business_usage_percentage': businessUsagePercentage,
        'expense_type': expenseType,
        'eworker_days': eworkerDays,
        'eworker_rate': eworkerRate,
        'mileage_km': mileageKm,
        'notes': notes,
      };

      // Remove null values
      body.removeWhere((key, value) => value == null);

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to create expense: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Error creating enhanced expense: $e');
      rethrow;
    }
  }

  /// Get enhanced expenses for a company
  static Future<List<EnhancedExpense>> getEnhancedExpenses(
      String companyId) async {
    try {
      final uri = Uri.parse('$baseUrl/expenses/enhanced/$companyId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EnhancedExpense.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load enhanced expenses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading enhanced expenses: $e');
      return [];
    }
  }

  /// Create e-worker period
  static Future<Map<String, dynamic>?> createEWorkerPeriod({
    required String companyId,
    required String periodStart,
    required String periodEnd,
    required double totalDays,
    required double dailyRate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/eworker/period');

      final body = {
        'company_id': companyId,
        'period_start': periodStart,
        'period_end': periodEnd,
        'total_days': totalDays,
        'daily_rate': dailyRate,
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to create e-worker period: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Error creating e-worker period: $e');
      rethrow;
    }
  }

  /// Get e-worker periods for a company
  static Future<List<EWorkerPeriod>> getEWorkerPeriods(String companyId) async {
    try {
      final uri = Uri.parse('$baseUrl/eworker/periods/$companyId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EWorkerPeriod.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load e-worker periods: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading e-worker periods: $e');
      return [];
    }
  }

  /// Get VAT summary for a company in a period
  static Future<VATSummary?> getVATSummary({
    required String companyId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/vat/summary/$companyId')
          .replace(queryParameters: {
        'start_date': startDate,
        'end_date': endDate,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return VATSummary.fromJson(data);
      } else {
        throw Exception('Failed to load VAT summary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading VAT summary: $e');
      return null;
    }
  }
}
