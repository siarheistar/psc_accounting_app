// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000'; // FastAPI backend URL

  // Invoice methods
  static Future<List<Map<String, dynamic>>> getInvoices(
      String companyId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/invoices?company_id=$companyId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load invoices');
    }
  }

  static Future<Map<String, dynamic>> createInvoice(
      Map<String, dynamic> invoice) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invoices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(invoice),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create invoice');
    }
  }

  static Future<Map<String, dynamic>> updateInvoice(
      int id, Map<String, dynamic> invoice) async {
    final response = await http.put(
      Uri.parse('$baseUrl/invoices/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(invoice),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update invoice');
    }
  }

  static Future<void> deleteInvoice(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/invoices/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete invoice');
    }
  }

  // Expense methods
  static Future<List<Map<String, dynamic>>> getExpenses(
      String companyId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/expenses?company_id=$companyId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load expenses');
    }
  }

  static Future<Map<String, dynamic>> createExpense(
      Map<String, dynamic> expense) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(expense),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create expense');
    }
  }

  static Future<Map<String, dynamic>> updateExpense(
      int id, Map<String, dynamic> expense) async {
    final response = await http.put(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(expense),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update expense');
    }
  }

  static Future<void> deleteExpense(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/expenses/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete expense');
    }
  }

  // Bank statement methods
  static Future<List<Map<String, dynamic>>> getBankStatements() async {
    final response = await http.get(Uri.parse('$baseUrl/bank-statements'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load bank statements');
    }
  }

  static Future<Map<String, dynamic>> createBankStatement(
      Map<String, dynamic> statement) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bank-statements'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(statement),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create bank statement');
    }
  }

  // Health check
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Company methods
  static Future<List<Map<String, dynamic>>> getCompanies(
      String ownerEmail) async {
    print('🏢 [ApiService] Fetching companies for owner: $ownerEmail');
    print(
        '🌐 [ApiService] Sending GET request to: $baseUrl/companies?owner_email=$ownerEmail');

    final response = await http.get(
      Uri.parse('$baseUrl/companies?owner_email=$ownerEmail'),
    );

    print('📡 [ApiService] Response status: ${response.statusCode}');
    print('📋 [ApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final result = data.map((item) => item as Map<String, dynamic>).toList();
      print('✅ [ApiService] Found ${result.length} companies for $ownerEmail');
      return result;
    } else {
      print(
          '❌ [ApiService] Failed to load companies - Status: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Failed to load companies');
    }
  }

  static Future<Map<String, dynamic>> createCompany(
      Map<String, dynamic> company) async {
    print('🏢 [ApiService] Creating company with data: $company');

    // Build query parameters as the backend expects them
    final queryParams = <String, String>{
      'name': company['name']?.toString() ?? '',
      'owner_email': company['owner_email']?.toString() ?? '',
    };

    // Add optional parameters if they exist
    if (company['vat_number'] != null) {
      queryParams['vat_number'] = company['vat_number'].toString();
    }
    if (company['country'] != null) {
      queryParams['country'] = company['country'].toString();
    }
    if (company['currency'] != null) {
      queryParams['currency'] = company['currency'].toString();
    }

    final uri =
        Uri.parse('$baseUrl/companies').replace(queryParameters: queryParams);
    print('🌐 [ApiService] Sending POST request to: $uri');

    final response = await http.post(uri);

    print('📡 [ApiService] Response status: ${response.statusCode}');
    print('📋 [ApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      print('✅ [ApiService] Company created successfully: $result');
      return result;
    } else {
      print(
          '❌ [ApiService] Failed to create company - Status: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Failed to create company');
    }
  }

  static Future<Map<String, dynamic>> updateCompany(
      String companyId, Map<String, dynamic> company) async {
    print('🏢 [ApiService] Updating company $companyId with data: $company');

    final uri = Uri.parse('$baseUrl/companies/$companyId');
    print('🌐 [ApiService] Sending PUT request to: $uri');

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(company),
    );

    print('📡 [ApiService] Response status: ${response.statusCode}');
    print('📋 [ApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      print('✅ [ApiService] Company updated successfully: $result');
      return result;
    } else {
      print(
          '❌ [ApiService] Failed to update company - Status: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Failed to update company: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getCompany(String companyId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/companies/$companyId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load company');
    }
  }
}
