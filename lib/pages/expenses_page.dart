import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html; // Only used for Web
import 'dart:convert';
import '../services/database_service.dart';
import '../services/api_config.dart';
import '../models/accounting_models.dart';
import '../context/simple_company_context.dart';
import '../dialogs/add_expense_dialog.dart';
import '../dialogs/edit_expense_dialog.dart';
import '../utils/currency_utils.dart';
import '../widgets/copyright_footer.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  bool _dataWasModified = false; // Track if any data was modified

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadExpenses();
    _searchController.addListener(_filterExpenses);
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '💰 ExpensesPage: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('💰 ExpensesPage: No company context available');
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    return CurrencyUtils.getCurrencySymbol(selectedCompany?.currency);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final expenses = await _dbService.getExpenses();

      if (mounted) {
        setState(() {
          _expenses = expenses;
          _filteredExpenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading expenses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to load expenses: $e', isError: true);
      }
    }
  }

  void _filterExpenses() {
    if (!mounted) return;

    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredExpenses = _expenses.where((expense) {
        final matchesSearch =
            expense.description.toLowerCase().contains(searchTerm) ||
                expense.category.toLowerCase().contains(searchTerm) ||
                (expense.notes?.toLowerCase().contains(searchTerm) ?? false);

        final matchesStatus = _statusFilter == 'all' ||
            (_statusFilter == 'recorded' && expense.status == 'recorded') ||
            (_statusFilter == 'pending' && expense.status == 'pending');

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _showAddExpenseDialog() async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    );

    if (result != null) {
      debugPrint('💰 Expense dialog completed, refreshing expenses...');
      _dataWasModified = true; // Mark data as modified
      await _loadExpenses();
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

  // Attachment methods (updated to match working invoices_page.dart implementation)
  void _uploadExpenseAttachment(String expenseId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes != null) {
          // Validate file size
          if (bytes.length > 25 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('File too large. Maximum size is 25MB.')),
            );
            return;
          }

          await _uploadFileToServer('expense', expenseId, file.name, bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment uploaded successfully')),
          );
          _loadExpenses(); // Refresh data
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload attachment: $e')),
      );
    }
  }

  Future<void> _uploadFileToServer(String entityType, String entityId,
      String filename, List<int> bytes) async {
    print('📎 === NEW ATTACHMENT UPLOAD ===');
    print('📎 Entity Type: $entityType');
    print('📎 Entity ID: $entityId');
    print('📎 Company ID: ${_dbService.currentCompanyId}');
    print('📎 Filename: $filename');
    print('📎 File Size: ${bytes.length} bytes');

    try {
      // Use the new multipart form upload to the refactored attachment system
      final uri = Uri.parse('${ApiConfig.baseUrl}/attachments/upload').replace(
        queryParameters: {
          'entity_type': entityType,
          'entity_id': entityId,
          'company_id': _dbService.currentCompanyId ?? '1',
        },
      );

      print('📎 Upload URL: $uri');

      final request = http.MultipartRequest('POST', uri);

      // Add the file as multipart form data
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

      print('📎 Sending multipart request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📎 === UPLOAD RESPONSE ===');
      print('📎 Status Code: ${response.statusCode}');
      print('📎 Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('📎 === UPLOAD FAILED ===');
        print('📎 Status: ${response.statusCode}');
        print('📎 Error: ${response.body}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      print('📎 === UPLOAD SUCCESS ===');
      print('📎 File successfully uploaded to local storage');
    } catch (e) {
      print('📎 === UPLOAD ERROR ===');
      print('📎 Error: $e');
      rethrow;
    }
  }

  void _viewExpenseAttachments(String expenseId) async {
    try {
      final attachments = await _getExpenseAttachments(expenseId);
      _showAttachmentsDialog(attachments, expenseId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attachments: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getExpenseAttachments(
      String expenseId) async {
    try {
      // Use the new attachment listing endpoint
      final url =
          Uri.parse('${ApiConfig.baseUrl}/attachments/expense/$expenseId');
      final response = await http.get(
        url.replace(queryParameters: {
          'company_id': _dbService.currentCompanyId ?? '1'
        }),
        headers: {
          'Accept': 'application/json',
          'Accept-Charset': 'utf-8',
        },
      );

      print('📎 === GET ATTACHMENTS ===');
      print('📎 URL: $url');
      print('📎 Status: ${response.statusCode}');
      print('📎 Response body length: ${response.body.length}');
      print('📎 Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        // Explicitly decode as UTF-8
        final responseBody = utf8.decode(response.bodyBytes);
        final dynamic responseData = json.decode(responseBody);

        // New attachment system returns an object with attachments array
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('attachments')) {
          final List<dynamic> attachments = responseData['attachments'] ?? [];
          print('📎 Found ${attachments.length} attachments');
          return attachments.cast<Map<String, dynamic>>();
        } else if (responseData is List) {
          // Fallback for old format
          print('📎 Found ${responseData.length} attachments (old format)');
          return responseData.cast<Map<String, dynamic>>();
        } else {
          print('📎 Unexpected response format: $responseData');
          return [];
        }
      } else {
        print('📎 Failed to fetch attachments: ${response.statusCode}');
        throw Exception('Failed to fetch attachments: ${response.statusCode}');
      }
    } catch (e) {
      print('📎 Error fetching attachments: $e');
      return [];
    }
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
          final utf8String = utf8.decode(bytes);
          debugPrint('🔍 Fixed encoding: $utf8String');
          return utf8String;
        } catch (e) {
          debugPrint('🔍 Encoding fix failed: $e');
        }
      }

      // Default: return as-is
      debugPrint('🔍 Returning unchanged: $filename');
      return filename;
    } catch (e) {
      debugPrint('🔍 Error in _decodeFilename: $e');
      return filename; // Fallback to original
    }
  }

  void _showAttachmentsDialog(List<dynamic> attachments, String expenseId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Expense Attachments'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: attachments.isEmpty
                ? const Center(child: Text('No attachments found'))
                : ListView.builder(
                    itemCount: attachments.length,
                    itemBuilder: (context, index) {
                      final attachment = attachments[index];
                      final rawFilename = attachment['original_filename'] ??
                          attachment['filename'] ??
                          'Unknown';

                      // Decode the filename to handle Unicode characters properly
                      final filename = _decodeFilename(rawFilename);

                      print('🔍 Raw filename: $rawFilename');
                      print('🔍 Decoded filename: $filename');

                      return ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(filename),
                        subtitle: Text(
                            'Uploaded: ${attachment['created_at']?.substring(0, 10) ?? 'Unknown'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _downloadAttachment(attachment),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteAttachment(
                                  attachment['id'].toString(), expenseId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _downloadAttachment(Map<String, dynamic> attachment) async {
    try {
      print('📥 === STARTING ATTACHMENT DOWNLOAD ===');
      print('📥 Attachment ID: ${attachment['id']}');

      // Use the new attachment download endpoint
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/attachments/download/${attachment['id']}');
      final response = await http.get(
        url.replace(queryParameters: {
          'company_id': _dbService.currentCompanyId ?? '1'
        }),
      );

      print('📥 Download Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Get filename from attachment data with proper decoding
        final rawFilename = attachment['original_filename'] ??
            attachment['filename'] ??
            'attachment';
        String filename = _decodeFilename(rawFilename);

        final contentDisposition = response.headers['content-disposition'];
        if (contentDisposition != null) {
          final filenameMatch =
              RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
          if (filenameMatch != null) {
            filename = _decodeFilename(filenameMatch.group(1) ?? filename);
          }
        }

        final bytes = response.bodyBytes;

        // Create blob and download for web
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = filename;
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        print('📥 === DOWNLOAD SUCCESS ===');
        print('📥 File downloaded: $filename (${bytes.length} bytes)');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File downloaded successfully: $filename')),
        );
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      print('📥 === DOWNLOAD ERROR ===');
      print('📥 Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file: $e')),
      );
    }
  }

  void _deleteAttachment(String attachmentId, String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Attachment'),
          content: const Text(
              'Are you sure you want to delete this attachment?\n\nThis action cannot be undone.'),
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

    if (confirmed == true) {
      try {
        print('🗑️ === DELETE ATTACHMENT ===');
        print('🗑️ Attachment ID: $attachmentId');

        await _dbService.deleteAttachment(attachmentId);

        print('🗑️ Attachment deleted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted successfully')),
        );

        // Close attachments dialog and refresh
        Navigator.of(context).pop();
        _viewExpenseAttachments(expenseId); // Refresh attachments dialog
      } catch (e) {
        print('🗑️ === DELETE ERROR ===');
        print('🗑️ Exception: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete attachment: $e')),
        );
      }
    }
  }

  void _editExpense(Expense expense) {
    print('💰 [ExpensesPage] Edit expense clicked for: ${expense.description}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditExpenseDialog(expense: expense);
      },
    ).then((_) {
      print('💰 [ExpensesPage] Edit dialog closed, refreshing expenses...');
      _dataWasModified = true; // Mark data as modified
      _loadExpenses();
    });
  }

  void _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Expense'),
          content: Text(
              'Are you sure you want to delete this expense: ${expense.description}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final company = SimpleCompanyContext.selectedCompany;
        if (company == null) return;

        await _dbService.deleteExpense(expense.id);
        _dataWasModified = true; // Mark data as modified
        _loadExpenses();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Expenses'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(_dataWasModified);
          },
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header and controls
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Search and filter row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search expenses...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF3B82F6)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: InputDecoration(
                          labelText: 'Filter',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(
                              value: 'recorded', child: Text('Recorded')),
                          DropdownMenuItem(
                              value: 'pending', child: Text('Pending')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value!;
                          });
                          _filterExpenses();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddExpenseDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Expenses list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredExpenses.isEmpty
                      ? const Center(
                          child: Text(
                            'No expenses found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: _filteredExpenses.length,
                                itemBuilder: (context, index) {
                                  final expense = _filteredExpenses[index];
                                  return _buildExpenseCard(expense);
                                },
                              ),
                            ),
                            const CopyrightFooter(showBackground: true),
                          ],
                        ),
            ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with description and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  expense.description,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(expense.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expense.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(expense.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Amount and category
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expense.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildVATBreakdown(expense),
            ],
          ),
          const SizedBox(height: 12),
          // Notes and Date
          Row(
            children: [
              if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expense.notes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.edit,
                label: 'Edit',
                color: Colors.blue,
                onPressed: () => _editExpense(expense),
              ),
              _buildActionButton(
                icon: Icons.attach_file,
                label: 'Add Attachment',
                color: Colors.green,
                onPressed: () => _uploadExpenseAttachment(expense.id),
              ),
              _buildActionButton(
                icon: Icons.visibility,
                label: 'View Attachments',
                color: Colors.orange,
                onPressed: () => _viewExpenseAttachments(expense.id),
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onPressed: () => _deleteExpense(expense),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'recorded':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildVATBreakdown(Expense expense) {
    // Check if we have VAT data
    final bool hasVATData = expense.grossAmount != null && expense.netAmount != null && expense.vatAmount != null;
    
    if (hasVATData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Amount Breakdown',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Gross Amount (Total)
          Text(
            '${_getCurrencySymbol()}${expense.grossAmount!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          // Net Amount
          Text(
            'Net: ${_getCurrencySymbol()}${expense.netAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          // VAT Amount
          Text(
            'VAT: ${_getCurrencySymbol()}${expense.vatAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          // VAT Rate if available
          if (expense.vatRate != null)
            Text(
              '(${expense.vatRate!.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
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
            'Amount',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_getCurrencySymbol()}${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      );
    }
  }
}
