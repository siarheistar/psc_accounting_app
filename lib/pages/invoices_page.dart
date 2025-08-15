import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html; // Only used for Web
import 'dart:convert';
import 'dart:convert' show utf8, latin1, json;
import '../services/database_service.dart';
import '../services/api_config.dart';
import '../models/accounting_models.dart';
import '../context/simple_company_context.dart';
import '../dialogs/add_invoice_dialog.dart';
import '../dialogs/edit_invoice_dialog.dart';
import '../utils/currency_utils.dart';
import '../widgets/copyright_footer.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'all';
  bool _dataWasModified = false; // Track if any data was modified

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadInvoices();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '📄 InvoicesPage: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('📄 InvoicesPage: No company context available');
    }
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '\$'; // Default fallback
  }

  String _decodeFilename(String filename) {
    try {
      print('🔍 _decodeFilename input: $filename');
      print('🔍 Input runes: ${filename.runes.toList()}');

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
        print('🔍 Decoded from escape sequences: $decoded');
        return decoded;
      }

      // Try URL decoding if it contains percent encoding
      if (filename.contains('%')) {
        final decoded = Uri.decodeComponent(filename);
        print('🔍 Decoded from URL encoding: $decoded');
        return decoded;
      }

      // If it looks like it has replacement characters, try to fix encoding issues
      if (filename.contains('�') || filename.contains('Ð')) {
        print('🔍 Detected potential encoding issues');
        // Try to re-encode as Latin-1 and decode as UTF-8
        try {
          final bytes = latin1.encode(filename);
          final decoded = utf8.decode(bytes);
          print('🔍 Re-encoded and decoded: $decoded');
          return decoded;
        } catch (e) {
          print('🔍 Re-encoding failed: $e');
        }
      }

      // Return as-is if no special encoding detected
      print('🔍 Returning filename as-is: $filename');
      return filename;
    } catch (e) {
      print('🔍 Failed to decode filename: $filename, error: $e');
      return filename; // Return original if decoding fails
    }
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📄 Loading all invoices...');
      final invoices = await _dbService.getInvoices();
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
      debugPrint('📄 Loaded ${_invoices.length} invoices successfully');
    } catch (e) {
      debugPrint('📄 Error loading invoices: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Invoice> get _filteredInvoices {
    return _invoices.where((invoice) {
      final matchesSearch = invoice.clientName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          invoice.invoiceNumber
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _statusFilter == 'all' || invoice.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _showAddInvoiceDialog() async {
    final result = await showDialog<Invoice>(
      context: context,
      builder: (context) => const AddInvoiceDialog(),
    );

    if (result == null) {
      // Dialog completed successfully, refresh the invoices
      debugPrint('📄 Invoice dialog completed, refreshing invoices...');
      _dataWasModified = true; // Mark data as modified
      await _loadInvoices();
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

  // Attachment methods similar to home_page.dart
  void _uploadInvoiceAttachment(String invoiceId) async {
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

          await _uploadFileToServer('invoice', invoiceId, file.name, bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment uploaded successfully')),
          );
          _loadInvoices(); // Refresh data
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

  void _viewInvoiceAttachments(String invoiceId) async {
    try {
      final attachments = await _getInvoiceAttachments(invoiceId);
      _showAttachmentsDialog(attachments, invoiceId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attachments: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getInvoiceAttachments(
      String invoiceId) async {
    try {
      // Use the new attachment listing endpoint
      final url =
          Uri.parse('${ApiConfig.baseUrl}/attachments/invoice/$invoiceId');
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

  void _showAttachmentsDialog(List<dynamic> attachments, String invoiceId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invoice Attachments'),
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
                            'Uploaded: ${attachment['uploaded_at']?.substring(0, 10) ?? 'Unknown'}'),
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
                                  attachment['id'].toString(), invoiceId),
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

  void _deleteAttachment(String attachmentId, String invoiceId) async {
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
        _viewInvoiceAttachments(invoiceId); // Refresh attachments dialog
      } catch (e) {
        print('🗑️ === DELETE ERROR ===');
        print('🗑️ Exception: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete attachment: $e')),
        );
      }
    }
  }

  void _editInvoice(Invoice invoice) {
    print(
        '🧾 [InvoicesPage] Edit invoice clicked for: ${invoice.invoiceNumber}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditInvoiceDialog(invoice: invoice);
      },
    ).then((_) {
      print('🧾 [InvoicesPage] Edit dialog closed, refreshing invoices...');
      _dataWasModified = true; // Mark data as modified
      _loadInvoices();
    });
  }

  void _deleteInvoice(Invoice invoice) async {
    // Ensure company context is set before attempting delete
    _initializeCompanyContext();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Invoice'),
          content: Text(
              'Are you sure you want to delete invoice ${invoice.invoiceNumber}?'),
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
        print('🗑️ === DELETE INVOICE ===');
        print('🗑️ Invoice ID: ${invoice.id}');
        print('🗑️ Invoice Number: ${invoice.invoiceNumber}');
        print('🗑️ Company Context: ${_dbService.currentCompanyId}');
        print('🗑️ Demo Mode: ${_dbService.isDemoMode}');

        await _dbService.deleteInvoice(invoice.id);
        _dataWasModified = true; // Mark data as modified
        _loadInvoices();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted successfully')),
        );
      } catch (e) {
        print('🗑️ === DELETE ERROR ===');
        print('🗑️ Exception: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete invoice: $e')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isDemoMode = _dbService.isDemoMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(_dataWasModified);
          },
        ),
        title: Row(
          children: [
            Icon(
              Icons.receipt_long,
              color: isDemoMode ? Colors.orange : Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'All Invoices',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDemoMode ? Colors.orange : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        actions: [
          // Add Invoice button
          IconButton(
            onPressed: _dbService.isDemoMode
                ? () => _showSnackBar(
                    'Demo mode - Create a real company to add transactions',
                    isError: true)
                : () => _showAddInvoiceDialog(),
            icon: Icon(
              Icons.add,
              color: isDemoMode ? Colors.orange : Colors.blue,
            ),
            tooltip: 'Add Invoice',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildInvoicesView(),
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
              'Failed to Load Invoices',
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
              onPressed: _loadInvoices,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesView() {
    return Column(
      children: [
        // Search and filter header
        _buildSearchAndFilters(),
        // Invoices list
        Expanded(
          child: _filteredInvoices.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(child: _buildInvoicesList()),
                    const CopyrightFooter(showBackground: true),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search invoices by client name or number...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          // Status filter
          Row(
            children: [
              const Text(
                'Filter by status:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All'),
                      _buildFilterChip('pending', 'Pending'),
                      _buildFilterChip('paid', 'Paid'),
                      _buildFilterChip('overdue', 'Overdue'),
                      _buildFilterChip('draft', 'Draft'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _statusFilter = value;
          });
        },
        selectedColor: Colors.blue.withOpacity(0.2),
        checkmarkColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'all'
                  ? 'No invoices match your search'
                  : 'No invoices found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'all'
                  ? 'Try adjusting your search or filters'
                  : 'Create your first invoice to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty && _statusFilter == 'all') ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _dbService.isDemoMode
                    ? () => _showSnackBar(
                        'Demo mode - Create a real company to add transactions',
                        isError: true)
                    : () => _showAddInvoiceDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create First Invoice'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = _filteredInvoices[index];
        return _buildInvoiceCard(invoice);
      },
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with invoice number and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                invoice.invoiceNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(invoice.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  invoice.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(invoice.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Client and amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.clientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildVATBreakdown(invoice),
            ],
          ),
          const SizedBox(height: 12),
          // Dates
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issue Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.date != null
                          ? '${invoice.date!.day}/${invoice.date!.month}/${invoice.date!.year}'
                          : 'N/A',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (invoice.description != null &&
              invoice.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              invoice.description!,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.edit,
                label: 'Edit',
                color: Colors.blue,
                onPressed: () => _editInvoice(invoice),
              ),
              _buildActionButton(
                icon: Icons.attach_file,
                label: 'Add Attachment',
                color: Colors.green,
                onPressed: () => _uploadInvoiceAttachment(invoice.id),
              ),
              _buildActionButton(
                icon: Icons.visibility,
                label: 'View Attachments',
                color: Colors.orange,
                onPressed: () => _viewInvoiceAttachments(invoice.id),
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onPressed: () => _deleteInvoice(invoice),
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

  Widget _buildVATBreakdown(Invoice invoice) {
    // Check if we have VAT data
    final bool hasVATData = invoice.grossAmount != null && invoice.netAmount != null && invoice.vatAmount != null;
    
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
            '${_getCurrencySymbol()}${invoice.grossAmount!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          // Net Amount
          Text(
            'Net: ${_getCurrencySymbol()}${invoice.netAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          // VAT Amount
          Text(
            'VAT: ${_getCurrencySymbol()}${invoice.vatAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          // Note: VAT rate percentage not available in Invoice model
          // Only vatRateId is stored, would need separate lookup
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
            '${_getCurrencySymbol()}${invoice.amount.toStringAsFixed(2)}',
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
