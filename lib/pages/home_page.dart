import 'dart:html' as html; // Only used for Web
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../services/api_config.dart';

import '../services/database_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../pages/invoices_page.dart';
import '../pages/expenses_page.dart';
import '../pages/payroll_page.dart';
import '../pages/bank_statements_page.dart';
import '../models/accounting_models.dart';
import '../dialogs/add_invoice_dialog.dart';
import '../dialogs/add_expense_dialog.dart';
import '../dialogs/add_payroll_dialog.dart';
import '../dialogs/add_bank_statement_dialog.dart';
import '../dialogs/edit_invoice_dialog.dart';
import '../dialogs/edit_expense_dialog.dart';
import '../dialogs/edit_payroll_dialog.dart';
import '../dialogs/edit_bank_statement_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _dbService = DatabaseService();

  // Data state
  List<Invoice> _invoices = [];
  List<Expense> _expenses = [];
  List<PayrollEntry> _payrollEntries = [];
  List<BankStatement> _bankStatements = [];
  Map<String, dynamic> _metrics = {};

  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadDashboardData();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '🏠 HomePage: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('🏠 HomePage: No company context available');
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    return CurrencyUtils.getCurrencySymbol(selectedCompany?.currency);
  }

  /// Helper function to decode Unicode filename strings
  String _decodeFilename(String filename) {
    try {
      debugPrint('🔍 _decodeFilename input: $filename');
      debugPrint('🔍 Input runes: ${filename.runes.toList()}');

      // First check if it contains Unicode escape sequences like \u0421
      if (filename.contains(r'\u')) {
        // Convert Unicode escape sequences to actual characters
        String decoded = filename;
        final unicodePattern = RegExp(r'\\u([0-9A-Fa-f]{4})');
        decoded = decoded.replaceAllMapped(unicodePattern, (match) {
          final hexCode = match.group(1)!;
          final charCode = int.parse(hexCode, radix: 16);
          return String.fromCharCode(charCode);
        });
        debugPrint('🔍 Decoded from escape sequences: $decoded');
        return decoded;
      }

      // Try URL decoding if it contains percent encoding
      if (filename.contains('%')) {
        final decoded = Uri.decodeComponent(filename);
        debugPrint('🔍 Decoded from URL encoding: $decoded');
        return decoded;
      }

      // If it looks like it has replacement characters, try to fix encoding issues
      if (filename.contains('�') || filename.contains('Ð')) {
        debugPrint('🔍 Detected potential encoding issues');
        // Try to re-encode as Latin-1 and decode as UTF-8
        try {
          final bytes = latin1.encode(filename);
          final decoded = utf8.decode(bytes);
          debugPrint('🔍 Re-encoded and decoded: $decoded');
          return decoded;
        } catch (e) {
          debugPrint('🔍 Re-encoding failed: $e');
        }
      }

      // Return as-is if no special encoding detected
      debugPrint('🔍 Returning filename as-is: $filename');
      return filename;
    } catch (e) {
      debugPrint('🔍 Failed to decode filename: $filename, error: $e');
      return filename; // Return original if decoding fails
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🏠 === LOADING DASHBOARD DATA ===');
      debugPrint('🏠 Company Context: ${_dbService.currentCompanyId}');
      debugPrint('🏠 Demo Mode: ${_dbService.isDemoMode}');

      // Load all data in parallel
      final results = await Future.wait([
        _dbService.getInvoices(),
        _dbService.getExpenses(),
        _dbService.getPayrollEntries(),
        _dbService.getBankStatements(),
        _dbService.getDashboardMetrics(),
      ]);

      setState(() {
        _invoices = results[0] as List<Invoice>;
        _expenses = results[1] as List<Expense>;
        _payrollEntries = results[2] as List<PayrollEntry>;
        _bankStatements = results[3] as List<BankStatement>;
        _metrics = results[4] as Map<String, dynamic>;
        _isLoading = false;
      });

      debugPrint('🏠 === DASHBOARD DATA LOADED ===');
      debugPrint('🏠 Invoices: ${_invoices.length}');
      debugPrint('🏠 Expenses: ${_expenses.length}');
      debugPrint('🏠 Payroll: ${_payrollEntries.length}');
      debugPrint('🏠 Bank Statements: ${_bankStatements.length}');
      debugPrint(
          '🏠 Total Income: \$${_metrics['invoices']?['total_invoice_amount'] ?? 0}');
      debugPrint(
          '🏠 Total Expenses: \$${_metrics['expenses']?['total_expense_amount'] ?? 0}');
    } catch (e) {
      debugPrint('🏠 === DASHBOARD ERROR ===');
      debugPrint('🏠 Error: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddInvoiceDialog() async {
    final result = await showDialog<Invoice>(
      context: context,
      builder: (context) => const AddInvoiceDialog(),
    );

    // The dialog handles the invoice creation internally
    // If result is null, it means the operation was completed successfully
    // If result is not null, it would be an Invoice object (for future use)
    if (result == null) {
      // Dialog was closed after successful save - refresh the dashboard
      print(
          '🏠 [HomePage] Invoice dialog closed successfully, refreshing dashboard...');
      await _loadDashboardData();
    } else {
      // This branch would be used if we ever return an Invoice object instead of null
      print(
          '🏠 [HomePage] Invoice dialog returned invoice object: ${result.invoiceNumber}');
      await _loadDashboardData();
    }
  }

  void _showAddExpenseDialog() async {
    final expense = await showDialog<Expense>(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    );

    if (expense != null) {
      // Dialog has already handled the insertion, just refresh the data
      debugPrint('🏠 ✅ Expense created successfully, refreshing data');
      _showSnackBar('Expense created successfully!');
      await _loadDashboardData();
    }
  }

  void _showAddPayrollDialog() async {
    final payroll = await showDialog<PayrollEntry>(
      context: context,
      builder: (context) => const AddPayrollDialog(),
    );

    if (payroll == null) {
      debugPrint('🏠 ✅ Payroll entry created successfully, refreshing data');
      // Dialog handled the insertion, just refresh the data
      await _loadDashboardData();
    } else {
      debugPrint(
          '🏠 ⚠️ Unexpected: Dialog returned payroll object instead of null');
    }
  }

  void _showAddBankStatementDialog() async {
    final bankStatement = await showDialog<BankStatement>(
      context: context,
      builder: (context) => const AddBankStatementDialog(),
    );

    if (bankStatement != null) {
      debugPrint('📊 Bank statement created: ${bankStatement.description}');
      await _loadDashboardData(); // Refresh data
    }
  }

  // PDF options and upload functionality

  void _showPDFOptions(String entityType, String entityId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('File Attachments - ${entityType.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Upload File'),
              subtitle: const Text('Attach a document (PDF, images, etc.)'),
              onTap: () {
                Navigator.pop(context);
                _uploadPDF(entityType, entityId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.green),
              title: const Text('View Attachments'),
              subtitle: const Text('See all attached files'),
              onTap: () {
                Navigator.pop(context);
                _viewPDFAttachments(entityType, entityId);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPDF(String entityType, String entityId) async {
    try {
      if (kIsWeb) {
        // Web file picker - accept multiple file types
        final input = html.FileUploadInputElement()
          ..accept = '.pdf,.doc,.docx,.txt,.png,.jpg,.jpeg,.xls,.xlsx';
        input.click();

        input.onChange.listen((e) async {
          final files = input.files;
          if (files!.isEmpty) return;

          final file = files[0];

          // Validate file size (25MB limit)
          if (file.size > 25 * 1024 * 1024) {
            _showSnackBar('File too large. Maximum size is 25MB.',
                isError: true);
            return;
          }

          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((e) async {
            try {
              final bytes = reader.result as List<int>;
              await _uploadPDFToServer(entityType, entityId, file.name, bytes);
              _showSnackBar('File uploaded successfully!');
            } catch (e) {
              _showSnackBar('Failed to upload file: $e', isError: true);
            }
          });
        });
      } else {
        // Mobile file picker - allow various file types
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowedExtensions: null, // Allow all file types
        );

        if (result != null && result.files.single.bytes != null) {
          final file = result.files.single;

          // Validate file size
          if (file.size > 25 * 1024 * 1024) {
            _showSnackBar('File too large. Maximum size is 25MB.',
                isError: true);
            return;
          }

          await _uploadPDFToServer(
              entityType, entityId, file.name, file.bytes!);
          _showSnackBar('File uploaded successfully!');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to upload file: $e', isError: true);
    }
  }

  Future<void> _uploadPDFToServer(String entityType, String entityId,
      String filename, List<int> bytes) async {
    debugPrint('📎 === NEW ATTACHMENT UPLOAD ===');
    debugPrint('📎 Entity Type: $entityType');
    debugPrint('📎 Entity ID: $entityId');
    debugPrint('📎 Company ID: ${_dbService.currentCompanyId}');
    debugPrint('📎 Filename: $filename');
    debugPrint('📎 File Size: ${bytes.length} bytes');

    try {
      // Use the new multipart form upload to the refactored attachment system
      final uri = Uri.parse('${ApiConfig.baseUrl}/attachments/upload').replace(
        queryParameters: {
          'entity_type': entityType,
          'entity_id': entityId,
          'company_id': _dbService.currentCompanyId ?? '1',
        },
      );

      debugPrint('📎 Upload URL: $uri');

      final request = http.MultipartRequest('POST', uri);

      // Add the file as multipart form data (no base64 encoding needed!)
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      // Add description as form field
      request.fields['description'] = 'Uploaded from PSC Accounting App';

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
      });

      debugPrint('📎 Sending multipart request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📎 === UPLOAD RESPONSE ===');
      debugPrint('📎 Status Code: ${response.statusCode}');
      debugPrint('📎 Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('📎 === UPLOAD FAILED ===');
        debugPrint('📎 Status: ${response.statusCode}');
        debugPrint('📎 Error: ${response.body}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      debugPrint('📎 === UPLOAD SUCCESS ===');
      debugPrint('📎 File successfully uploaded to local storage');
    } catch (e) {
      debugPrint('📎 === UPLOAD ERROR ===');
      debugPrint('📎 Exception: $e');
      rethrow;
    }
  }

  void _viewPDFAttachments(String entityType, String entityId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF Attachments - ${entityType.toUpperCase()}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPDFAttachments(entityType, entityId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final attachments = snapshot.data ?? [];

              if (attachments.isEmpty) {
                return const Center(child: Text('No file attachments found'));
              }

              return ListView.builder(
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final attachment = attachments[index];
                  final rawFilename = attachment['original_filename'] ??
                      attachment['filename'] ??
                      'Unknown';

                  // Decode the filename to handle Unicode characters properly
                  final filename = _decodeFilename(rawFilename);

                  debugPrint('🔍 Raw filename: $rawFilename');
                  debugPrint('🔍 Decoded filename: $filename');
                  debugPrint('🔍 Filename length: ${filename.length}');
                  debugPrint(
                      '🔍 First few chars: ${filename.length > 0 ? filename.substring(0, filename.length.clamp(0, 10)) : 'empty'}');

                  // Determine file icon based on file extension
                  IconData fileIcon = Icons.description;
                  Color iconColor = Colors.grey;

                  if (filename.toLowerCase().endsWith('.pdf')) {
                    fileIcon = Icons.picture_as_pdf;
                    iconColor = Colors.red;
                  } else if (filename
                      .toLowerCase()
                      .contains(RegExp(r'\.(jpg|jpeg|png|gif)$'))) {
                    fileIcon = Icons.image;
                    iconColor = Colors.blue;
                  } else if (filename
                      .toLowerCase()
                      .contains(RegExp(r'\.(doc|docx)$'))) {
                    fileIcon = Icons.description;
                    iconColor = Colors.blue[800]!;
                  } else if (filename
                      .toLowerCase()
                      .contains(RegExp(r'\.(xls|xlsx)$'))) {
                    fileIcon = Icons.table_chart;
                    iconColor = Colors.green;
                  } else if (filename.toLowerCase().endsWith('.txt')) {
                    fileIcon = Icons.text_snippet;
                    iconColor = Colors.grey[700]!;
                  }

                  return ListTile(
                    leading: Icon(fileIcon, color: iconColor),
                    title: Text(filename),
                    subtitle: Text(attachment['file_size_human'] ??
                        '${(attachment['file_size'] ?? 0) ~/ 1024} KB'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadPDF(attachment['id']),
                          tooltip: 'Download',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deletePDF(attachment['id'].toString(), filename),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getPDFAttachments(
      String entityType, String entityId) async {
    try {
      // Use the new attachment listing endpoint
      final url =
          Uri.parse('${ApiConfig.baseUrl}/attachments/$entityType/$entityId');
      final response = await http.get(
        url.replace(queryParameters: {
          'company_id': _dbService.currentCompanyId ?? '1'
        }),
        headers: {
          'Accept': 'application/json',
          'Accept-Charset': 'utf-8',
        },
      );

      debugPrint('📎 === GET ATTACHMENTS ===');
      debugPrint('📎 URL: $url');
      debugPrint('📎 Status: ${response.statusCode}');
      debugPrint('📎 Response body length: ${response.body.length}');
      debugPrint('📎 Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        // Explicitly decode as UTF-8
        final responseBody = utf8.decode(response.bodyBytes);
        final dynamic responseData = json.decode(responseBody);

        // New attachment system returns an object with attachments array
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('attachments')) {
          final List<dynamic> attachments = responseData['attachments'] ?? [];
          debugPrint('📎 Found ${attachments.length} attachments');
          return attachments.cast<Map<String, dynamic>>();
        } else if (responseData is List) {
          // Fallback for old format
          debugPrint(
              '📎 Found ${responseData.length} attachments (old format)');
          return responseData.cast<Map<String, dynamic>>();
        } else {
          debugPrint('📎 Unexpected response format: $responseData');
          return [];
        }
      } else {
        debugPrint('📎 Failed to fetch attachments: ${response.statusCode}');
        throw Exception('Failed to fetch attachments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📎 Error fetching attachments: $e');
      return [];
    }
  }

  Future<void> _downloadPDF(int documentId) async {
    try {
      debugPrint('📥 === STARTING ATTACHMENT DOWNLOAD ===');
      debugPrint('📥 Attachment ID: $documentId');

      // Use the new attachment download endpoint
      final url =
          Uri.parse('${ApiConfig.baseUrl}/attachments/download/$documentId');
      final response = await http.get(
        url.replace(queryParameters: {
          'company_id': _dbService.currentCompanyId ?? '1'
        }),
      );

      debugPrint('📥 Download Status: ${response.statusCode}');
      debugPrint('📥 Content-Type: ${response.headers['content-type']}');
      debugPrint('📥 All headers: ${response.headers}');

      if (response.statusCode == 200) {
        // Get filename from Content-Disposition header or use default
        String filename = 'attachment';
        final contentDisposition = response.headers['content-disposition'];
        debugPrint('📥 Content-Disposition (exact): $contentDisposition');

        // Try alternative header keys (case variations)
        final altContentDisposition = response.headers['Content-Disposition'] ??
            response.headers['CONTENT-DISPOSITION'] ??
            response.headers['content-Disposition'];
        debugPrint(
            '📥 Alternative Content-Disposition: $altContentDisposition');

        final actualContentDisposition =
            contentDisposition ?? altContentDisposition;

        if (actualContentDisposition != null) {
          debugPrint('📥 Using Content-Disposition: $actualContentDisposition');

          // Try RFC 5987 encoding first (filename*=UTF-8''encoded_name)
          final rfc5987Match = RegExp(r"filename\*=UTF-8''([^;]+)")
              .firstMatch(actualContentDisposition);
          if (rfc5987Match != null) {
            final encodedFilename = rfc5987Match.group(1) ?? '';
            try {
              filename = Uri.decodeComponent(encodedFilename);
              debugPrint('📥 Decoded RFC 5987 filename: $filename');
            } catch (e) {
              debugPrint('📥 Failed to decode RFC 5987 filename: $e');
              // Fallback to simple quoted filename
              final simpleMatch = RegExp(r'filename="([^"]+)"')
                  .firstMatch(actualContentDisposition);
              if (simpleMatch != null) {
                filename = simpleMatch.group(1) ?? filename;
              }
            }
          } else {
            // Fallback to simple quoted filename
            final simpleMatch = RegExp(r'filename="([^"]+)"')
                .firstMatch(actualContentDisposition);
            if (simpleMatch != null) {
              filename = simpleMatch.group(1) ?? filename;
            }
          }

          // Apply Unicode decoding to handle special characters properly
          filename = _decodeFilename(filename);
        } else {
          debugPrint('📥 No Content-Disposition header found!');
        }
        debugPrint('📥 Final decoded filename: $filename');

        if (kIsWeb) {
          // Web download - direct file streaming with proper MIME type
          final bytes = response.bodyBytes;
          final mimeType =
              response.headers['content-type'] ?? 'application/octet-stream';

          debugPrint('📥 Creating blob with MIME type: $mimeType');
          debugPrint('📥 File size: ${bytes.length} bytes');

          // Create blob with explicit MIME type
          final blob = html.Blob([bytes], mimeType);
          final url = html.Url.createObjectUrlFromBlob(blob);

          // Force download by using attachment disposition
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = filename
            ..setAttribute('type', mimeType);

          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          html.Url.revokeObjectUrl(url);

          debugPrint('📥 === DOWNLOAD SUCCESS ===');
          debugPrint('📥 File downloaded: $filename (${bytes.length} bytes)');
          _showSnackBar('File downloaded successfully: $filename');
        } else {
          _showSnackBar('Download feature available on web only');
        }
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📥 === DOWNLOAD ERROR ===');
      debugPrint('📥 Exception: $e');
      _showSnackBar('Failed to download file: $e', isError: true);
    }
  }

  Future<void> _deletePDF(String attachmentId, String filename) async {
    try {
      debugPrint('🗑️ === DELETE ATTACHMENT ===');
      debugPrint('🗑️ Attachment ID: $attachmentId');
      debugPrint('🗑️ Filename: $filename');

      // Show confirmation dialog
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Delete Attachment'),
            content: Text(
                'Are you sure you want to delete "$filename"?\n\nThis action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        debugPrint('🗑️ Delete cancelled by user');
        return;
      }

      await _dbService.deleteAttachment(attachmentId);

      debugPrint('🗑️ Attachment deleted successfully');
      _showSnackBar('Attachment "$filename" deleted successfully!');

      // Close the PDF viewer dialog and refresh attachments
      if (mounted) {
        Navigator.of(context).pop();
        // Optionally refresh the dashboard data
        await _loadDashboardData();
      }
    } catch (e) {
      debugPrint('🗑️ === DELETE ERROR ===');
      debugPrint('🗑️ Exception: $e');
      _showSnackBar('Failed to delete attachment: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
    }
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context, bool isDemoMode, User? user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth < 1024;
    
    return PreferredSize(
      preferredSize: Size.fromHeight(isSmallScreen ? 56 : 64),
      child: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        toolbarHeight: isSmallScreen ? 56 : 64,
        title: _buildAppBarTitle(isDemoMode, isSmallScreen),
        actions: _buildAppBarActions(isDemoMode, user, isSmallScreen, isMediumScreen),
        flexibleSpace: isSmallScreen ? null : Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(bool isDemoMode, bool isSmallScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_balance,
          color: isDemoMode ? Colors.orange : Colors.blue,
          size: isSmallScreen ? 20 : 24,
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Flexible(
          child: Text(
            isSmallScreen 
              ? 'PSC Accounting'
              : (isDemoMode ? 'PSC Accounting - Demo' : 'PSC Accounting'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 16 : 18,
              color: isDemoMode ? Colors.orange : const Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions(bool isDemoMode, User? user, bool isSmallScreen, bool isMediumScreen) {
    final actions = <Widget>[];
    
    if (isSmallScreen) {
      // Mobile: Show only essential actions + overflow menu
      actions.addAll([
        _buildActionButton(
          icon: Icons.receipt_long,
          tooltip: 'Add Invoice',
          onPressed: _getAddAction(() => _showAddInvoiceDialog()),
          isDemoMode: isDemoMode,
          isCompact: true,
        ),
        _buildActionButton(
          icon: Icons.money_off,
          tooltip: 'Add Expense', 
          onPressed: _getAddAction(() => _showAddExpenseDialog()),
          isDemoMode: isDemoMode,
          isCompact: true,
        ),
        _buildOverflowMenu(isDemoMode, user),
      ]);
    } else if (isMediumScreen) {
      // Tablet: Show most actions, some in overflow
      actions.addAll([
        _buildActionButton(
          icon: Icons.receipt_long,
          tooltip: 'Add Invoice',
          onPressed: _getAddAction(() => _showAddInvoiceDialog()),
          isDemoMode: isDemoMode,
        ),
        _buildActionButton(
          icon: Icons.money_off,
          tooltip: 'Add Expense',
          onPressed: _getAddAction(() => _showAddExpenseDialog()),
          isDemoMode: isDemoMode,
        ),
        _buildActionButton(
          icon: Icons.person,
          tooltip: 'Add Payroll',
          onPressed: _getAddAction(() => _showAddPayrollDialog()),
          isDemoMode: isDemoMode,
        ),
        _buildOverflowMenu(isDemoMode, user),
      ]);
    } else {
      // Desktop: Show all actions
      actions.addAll([
        _buildActionButton(
          icon: Icons.receipt_long,
          tooltip: 'Add Invoice',
          onPressed: _getAddAction(() => _showAddInvoiceDialog()),
          isDemoMode: isDemoMode,
        ),
        _buildActionButton(
          icon: Icons.money_off,
          tooltip: 'Add Expense',
          onPressed: _getAddAction(() => _showAddExpenseDialog()),
          isDemoMode: isDemoMode,
        ),
        _buildActionButton(
          icon: Icons.person,
          tooltip: 'Add Payroll',
          onPressed: _getAddAction(() => _showAddPayrollDialog()),
          isDemoMode: isDemoMode,
        ),
        _buildActionButton(
          icon: Icons.account_balance,
          tooltip: 'Add Bank Statement',
          onPressed: _getAddAction(() => _showAddBankStatementDialog()),
          isDemoMode: isDemoMode,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.info_outline,
          tooltip: 'Company Info',
          onPressed: () => _showCompanyInfo(),
          isDemoMode: isDemoMode,
        ),
        _buildUserAvatar(isDemoMode, user),
      ]);
    }
    
    return actions;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDemoMode,
    bool isCompact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isDemoMode ? Colors.orange : Colors.blue,
          size: isCompact ? 20 : 24,
        ),
        tooltip: tooltip,
        constraints: BoxConstraints(
          minWidth: isCompact ? 36 : 44,
          minHeight: isCompact ? 36 : 44,
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(bool isDemoMode, User? user) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: isDemoMode ? Colors.orange : Colors.blue,
      ),
      tooltip: 'More options',
      onSelected: (value) {
        switch (value) {
          case 'payroll':
            _getAddAction(() => _showAddPayrollDialog())();
            break;
          case 'bank':
            _getAddAction(() => _showAddBankStatementDialog())();
            break;
          case 'info':
            _showCompanyInfo();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'payroll',
          child: ListTile(
            leading: Icon(Icons.person),
            title: Text('Add Payroll'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'bank',
          child: ListTile(
            leading: Icon(Icons.account_balance),
            title: Text('Add Bank Statement'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Company Info'),
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(bool isDemoMode, User? user) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: isDemoMode ? Colors.orange : Colors.blue,
        child: user?.photoURL != null
            ? ClipOval(
                child: Image.network(
                  user!.photoURL!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              )
            : Text(
                user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  VoidCallback _getAddAction(VoidCallback action) {
    return _dbService.isDemoMode
        ? () => _showSnackBar(
            'Demo mode - Create a real company to add transactions',
            isError: true)
        : action;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDemoMode = _dbService.isDemoMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildResponsiveAppBar(context, isDemoMode, user),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildDashboard(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive padding based on screen size
        final padding = constraints.maxWidth < 600
            ? const EdgeInsets.all(16)
            : constraints.maxWidth < 1200
                ? const EdgeInsets.all(24)
                : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);

        final spacing = constraints.maxWidth < 600 ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              _buildWelcomeSection(),
              SizedBox(height: spacing),

              // Quick Overview title
              Text(
                'Quick Overview',
                style: TextStyle(
                  fontSize: constraints.maxWidth < 600 ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: constraints.maxWidth < 600 ? 8 : 12),

              // Metrics cards with responsive spacing
              _buildMetricsCards(),
              SizedBox(height: constraints.maxWidth < 600 ? 24 : 32),

              // Responsive data tabs
              _buildDataTabs(),
              SizedBox(height: constraints.maxWidth < 600 ? 12 : 16),

              // Tab content
              _buildTabContent(),

              // Bottom padding for mobile navigation
              SizedBox(height: constraints.maxWidth < 600 ? 80 : 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    final isDemoMode = _dbService.isDemoMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDemoMode
                  ? [Colors.orange, Colors.deepOrange]
                  : [Colors.blue, Colors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeContent(isDemoMode, user, isSmallScreen),
                    const SizedBox(height: 16),
                    Center(child: _buildWelcomeIcon(isDemoMode, isSmallScreen)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                        child: _buildWelcomeContent(
                            isDemoMode, user, isSmallScreen)),
                    _buildWelcomeIcon(isDemoMode, isSmallScreen),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWelcomeContent(bool isDemoMode, User? user, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDemoMode ? 'Demo Dashboard' : 'Welcome back!',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isDemoMode
              ? 'Exploring sample data - ${user?.displayName ?? 'User'}'
              : 'Hello, ${user?.displayName?.split(' ').first ?? 'User'}!',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 13 : 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isDemoMode
              ? 'This is demonstration data only'
              : 'Here\'s what\'s happening with your finances.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 11 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeIcon(bool isDemoMode, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isDemoMode ? Icons.preview : Icons.dashboard,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Map<String, double> _calculateInvoiceVATMetrics() {
    double grossTotal = 0.0;
    double netTotal = 0.0;
    double vatTotal = 0.0;
    int count = 0;

    for (final invoice in _invoices) {
      count++;
      if (invoice.grossAmount != null &&
          invoice.netAmount != null &&
          invoice.vatAmount != null) {
        grossTotal += invoice.grossAmount!;
        netTotal += invoice.netAmount!;
        vatTotal += invoice.vatAmount!;
      } else {
        // Fallback to using the basic amount as gross
        grossTotal += invoice.amount;
        netTotal += invoice.amount; // Assume no VAT if data not available
      }
    }

    return {
      'grossTotal': grossTotal,
      'netTotal': netTotal,
      'vatTotal': vatTotal,
      'count': count.toDouble(),
    };
  }

  Map<String, double> _calculateExpenseVATMetrics() {
    double grossTotal = 0.0;
    double netTotal = 0.0;
    double vatTotal = 0.0;
    int count = 0;

    for (final expense in _expenses) {
      count++;
      if (expense.grossAmount != null &&
          expense.netAmount != null &&
          expense.vatAmount != null) {
        grossTotal += expense.grossAmount!;
        netTotal += expense.netAmount!;
        vatTotal += expense.vatAmount!;
      } else {
        // Fallback to using the basic amount as gross
        grossTotal += expense.amount;
        netTotal += expense.amount; // Assume no VAT if data not available
      }
    }

    return {
      'grossTotal': grossTotal,
      'netTotal': netTotal,
      'vatTotal': vatTotal,
      'count': count.toDouble(),
    };
  }

  Widget _buildMetricsCards() {
    // Calculate VAT-aware metrics from local data
    final invoiceMetrics = _calculateInvoiceVATMetrics();
    final expenseMetrics = _calculateExpenseVATMetrics();
    final netProfit =
        invoiceMetrics['grossTotal']! - expenseMetrics['grossTotal']!;
    final totalVATCollected =
        invoiceMetrics['vatTotal']! - expenseMetrics['vatTotal']!;

    final metrics = [
      {
        'title': 'Invoice Income',
        'value':
            '${_getCurrencySymbol()}${invoiceMetrics['grossTotal']!.toStringAsFixed(2)}',
        'subtitle':
            'Net: ${_getCurrencySymbol()}${invoiceMetrics['netTotal']!.toStringAsFixed(2)} | VAT: ${_getCurrencySymbol()}${invoiceMetrics['vatTotal']!.toStringAsFixed(2)}',
        'change': '+${invoiceMetrics['count']!.toInt()} invoices',
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
      {
        'title': 'Total Expenses',
        'value':
            '${_getCurrencySymbol()}${expenseMetrics['grossTotal']!.toStringAsFixed(2)}',
        'subtitle':
            'Net: ${_getCurrencySymbol()}${expenseMetrics['netTotal']!.toStringAsFixed(2)} | VAT: ${_getCurrencySymbol()}${expenseMetrics['vatTotal']!.toStringAsFixed(2)}',
        'change': '+${expenseMetrics['count']!.toInt()} expenses',
        'icon': Icons.trending_down,
        'color': Colors.red,
      },
      {
        'title': 'Net Profit',
        'value': '${_getCurrencySymbol()}${netProfit.toStringAsFixed(2)}',
        'subtitle': 'Revenue minus expenses',
        'change': netProfit >= 0 ? 'Profit' : 'Loss',
        'icon': Icons.account_balance_wallet,
        'color': netProfit >= 0 ? Colors.blue : Colors.red,
      },
      {
        'title': 'VAT Position',
        'value':
            '${_getCurrencySymbol()}${totalVATCollected.toStringAsFixed(2)}',
        'subtitle': totalVATCollected >= 0 ? 'VAT to pay' : 'VAT reclaimable',
        'change':
            totalVATCollected >= 0 ? 'Owed to revenue' : 'Due from revenue',
        'icon': Icons.receipt_long,
        'color': totalVATCollected >= 0 ? Colors.orange : Colors.blue,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive column count based on screen width
        int crossAxisCount;
        double childAspectRatio;

        if (constraints.maxWidth < 600) {
          // Mobile: 1-2 columns
          crossAxisCount = constraints.maxWidth < 400 ? 1 : 2;
          childAspectRatio = constraints.maxWidth < 400 ? 3.5 : 3.2;
        } else if (constraints.maxWidth < 900) {
          // Small tablets: 2-3 columns
          crossAxisCount = 2;
          childAspectRatio = 3.0;
        } else if (constraints.maxWidth < 1200) {
          // Large tablets: 3 columns
          crossAxisCount = 3;
          childAspectRatio = 2.8;
        } else {
          // Desktop: 4 columns
          crossAxisCount = 4;
          childAspectRatio = 2.6;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metric['title'] as String,
                          style: TextStyle(
                            fontSize: crossAxisCount >= 4 ? 10 : 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        metric['icon'] as IconData,
                        size: crossAxisCount >= 4 ? 16 : 18,
                        color: metric['color'] as Color,
                      ),
                    ],
                  ),
                  SizedBox(height: crossAxisCount >= 4 ? 4 : 6),
                  Flexible(
                    child: Text(
                      metric['value'] as String,
                      style: TextStyle(
                        fontSize: crossAxisCount >= 4 ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (metric.containsKey('subtitle'))
                    Flexible(
                      child: Text(
                        metric['subtitle'] as String,
                        style: TextStyle(
                          fontSize: crossAxisCount >= 4 ? 7 : 8,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: crossAxisCount >= 4 ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    metric['change'] as String,
                    style: TextStyle(
                      fontSize: crossAxisCount >= 4 ? 9 : 10,
                      color: metric['color'] as Color,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDataTabs() {
    final tabs = ['Invoices', 'Expenses', 'Payroll', 'Bank Statements'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _selectedTabIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: index == 0 ? const Radius.circular(12) : Radius.zero,
                    right: index == tabs.length - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildInvoicesList();
      case 1:
        return _buildExpensesList();
      case 2:
        return _buildPayrollList();
      case 3:
        return _buildBankStatementsList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return _buildEmptyState(
          'No invoices found', 'Create your first invoice to get started');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Invoices (${_invoices.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const InvoicesPage(),
                  ),
                );
                // If invoices were modified, refresh dashboard
                if (result == true) {
                  print(
                      '🔄 [HomePage] Invoices were modified, refreshing dashboard...');
                  await _loadDashboardData();
                }
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._invoices
            .take(5)
            .map((invoice) => _buildInvoiceCard(invoice))
            .toList(),
      ],
    );
  }

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return _buildEmptyState(
          'No expenses found', 'Track your first expense to get started');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Expenses (${_expenses.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ExpensesPage(),
                  ),
                );
                // If expenses were modified, refresh dashboard
                if (result == true) {
                  print(
                      '🔄 [HomePage] Expenses were modified, refreshing dashboard...');
                  await _loadDashboardData();
                }
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._expenses
            .take(5)
            .map((expense) => _buildExpenseCard(expense))
            .toList(),
      ],
    );
  }

  Widget _buildPayrollList() {
    if (_payrollEntries.isEmpty) {
      return _buildEmptyState(
          'No payroll entries found', 'Add your first payroll entry');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Payroll (${_payrollEntries.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PayrollPage(),
                ),
              ),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._payrollEntries
            .take(5)
            .map((entry) => _buildPayrollCard(entry))
            .toList(),
      ],
    );
  }

  Widget _buildBankStatementsList() {
    if (_bankStatements.isEmpty) {
      return _buildEmptyState(
          'No bank statements found', 'Import your first bank statement');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Bank Statements (${_bankStatements.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BankStatementsPage(),
                ),
              ),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._bankStatements
            .take(5)
            .map((statement) => _buildBankStatementCard(statement))
            .toList(),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(invoice.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt,
              size: 18,
              color: _getStatusColor(invoice.status),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.clientName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInvoiceVATBreakdown(invoice),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(invoice.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      invoice.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: _getStatusColor(invoice.status),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showPDFOptions('invoice', invoice.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showEditDeleteOptions('invoice', invoice),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              size: 18,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  expense.category,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildExpenseVATBreakdown(expense),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showPDFOptions('expense', expense.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditDeleteOptions('expense', expense),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollCard(PayrollEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  entry.employeeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.period,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Net Pay',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_getCurrencySymbol()}${entry.netPay.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  if (entry.grossPay > entry.netPay)
                    Text(
                      'Gross: ${_getCurrencySymbol()}${entry.grossPay.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showPDFOptions('payroll', entry.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditDeleteOptions('payroll', entry),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankStatementCard(BankStatement statement) {
    final isCredit = statement.amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCredit ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  statement.description,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  statement.transactionType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isCredit ? 'CREDIT' : 'DEBIT',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isCredit ? '+' : '-'}${_getCurrencySymbol()}${statement.amount.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ${_getCurrencySymbol()}${statement.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () =>
                        _showPDFOptions('bank_statement', statement.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        _showEditDeleteOptions('bank_statement', statement),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDeleteOptions(String entityType, dynamic entity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${entityType.toUpperCase()} Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit'),
              subtitle: Text('Modify this ${entityType.toLowerCase()}'),
              onTap: () {
                Navigator.pop(context);
                _editEntity(entityType, entity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              subtitle: Text('Remove this ${entityType.toLowerCase()}'),
              onTap: () {
                Navigator.pop(context);
                _deleteEntity(entityType, entity);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _editEntity(String entityType, dynamic entity) async {
    switch (entityType) {
      case 'invoice':
        final updatedInvoice = await showDialog<Invoice>(
          context: context,
          builder: (context) => EditInvoiceDialog(invoice: entity as Invoice),
        );
        if (updatedInvoice != null) {
          print('🏠 [HomePage] Invoice updated, refreshing dashboard data');
          await _loadDashboardData();
        }
        break;

      case 'expense':
        final updatedExpense = await showDialog<Expense>(
          context: context,
          builder: (context) => EditExpenseDialog(expense: entity as Expense),
        );
        if (updatedExpense != null) {
          _showSnackBar('Expense updated successfully!');
          await _loadDashboardData();
        }
        break;

      case 'payroll':
        final updatedPayrollEntry = await showDialog<PayrollEntry>(
          context: context,
          builder: (context) =>
              EditPayrollDialog(payrollEntry: entity as PayrollEntry),
        );
        if (updatedPayrollEntry != null) {
          _showSnackBar('Payroll entry updated successfully!');
          await _loadDashboardData();
        }
        break;

      case 'bank_statement':
        final updatedBankStatement = await showDialog<BankStatement>(
          context: context,
          builder: (context) =>
              EditBankStatementDialog(bankStatement: entity as BankStatement),
        );
        if (updatedBankStatement != null) {
          _showSnackBar('Bank statement updated successfully!');
          await _loadDashboardData();
        }
        break;
    }
  }

  void _deleteEntity(String entityType, dynamic entity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete this ${entityType.toLowerCase()}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        switch (entityType) {
          case 'invoice':
            await _dbService.deleteInvoice((entity as Invoice).id);
            _showSnackBar('Invoice deleted successfully!');
            break;
          case 'expense':
            await _dbService.deleteExpense((entity as Expense).id);
            _showSnackBar('Expense deleted successfully!');
            break;
          case 'payroll':
            await _dbService.deletePayrollEntry((entity as PayrollEntry).id);
            _showSnackBar('Payroll entry deleted successfully!');
            break;
          case 'bank_statement':
            await _dbService.deleteBankStatement((entity as BankStatement).id);
            _showSnackBar('Bank statement deleted successfully!');
            break;
        }
        await _loadDashboardData();
      } catch (e) {
        _showSnackBar('Failed to delete ${entityType.toLowerCase()}: $e',
            isError: true);
      }
    }
  }

  void _showCompanyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Company Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company ID: ${_dbService.currentCompanyId ?? 'None'}'),
            Text('Demo Mode: ${_dbService.isDemoMode}'),
            Text('Context Set: ${_dbService.hasCompanyContext}'),
            const SizedBox(height: 16),
            const Text('Data Summary:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Invoices: ${_invoices.length}'),
            Text('Expenses: ${_expenses.length}'),
            Text('Payroll Entries: ${_payrollEntries.length}'),
            Text('Bank Statements: ${_bankStatements.length}'),
            const SizedBox(height: 16),
            const Text('Financial Summary:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
                'Total Income: ${_getCurrencySymbol()}${(_metrics['invoices']?['total_invoice_amount'] ?? 0).toStringAsFixed(2)}'),
            Text(
                'Total Expenses: ${_getCurrencySymbol()}${(_metrics['expenses']?['total_expense_amount'] ?? 0).toStringAsFixed(2)}'),
            Text(
                'Net Profit: ${_getCurrencySymbol()}${(_metrics['net_profit'] ?? 0).toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!_dbService.isDemoMode)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadDashboardData();
              },
              child: const Text('Refresh Data'),
            ),
        ],
      ),
    );
  }

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
      default:
        return Colors.blue;
    }
  }

  Widget _buildInvoiceVATBreakdown(Invoice invoice) {
    // Check if we have VAT data
    final bool hasVATData = invoice.grossAmount != null &&
        invoice.netAmount != null &&
        invoice.vatAmount != null;

    if (hasVATData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'TOTAL',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          // Gross Amount (Total)
          Text(
            '${_getCurrencySymbol()}${invoice.grossAmount!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          // Net/VAT breakdown in smaller text
          Text(
            'Net: ${_getCurrencySymbol()}${invoice.netAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            'VAT: ${_getCurrencySymbol()}${invoice.vatAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    } else {
      // Fallback to original simple amount display
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'AMOUNT',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_getCurrencySymbol()}${invoice.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildExpenseVATBreakdown(Expense expense) {
    // Check if we have VAT data
    final bool hasVATData = expense.grossAmount != null &&
        expense.netAmount != null &&
        expense.vatAmount != null;

    if (hasVATData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'TOTAL',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          // Gross Amount (Total)
          Text(
            '${_getCurrencySymbol()}${expense.grossAmount!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          // Net/VAT breakdown in smaller text
          Text(
            'Net: ${_getCurrencySymbol()}${expense.netAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            'VAT: ${_getCurrencySymbol()}${expense.vatAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          // VAT Rate if available
          if (expense.vatRate != null)
            Text(
              '(${expense.vatRate!.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      );
    } else {
      // Fallback to original simple amount display
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'AMOUNT',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_getCurrencySymbol()}${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
        ],
      );
    }
  }
}
