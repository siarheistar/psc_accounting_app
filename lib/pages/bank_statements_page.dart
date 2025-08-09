import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/accounting_models.dart';
import '../context/simple_company_context.dart';
import '../dialogs/edit_bank_statement_dialog.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class BankStatementsPage extends StatefulWidget {
  const BankStatementsPage({super.key});

  @override
  State<BankStatementsPage> createState() => _BankStatementsPageState();
}

class _BankStatementsPageState extends State<BankStatementsPage> {
  final DatabaseService _dbService = DatabaseService();
  List<BankStatement> _bankStatements = [];
  List<BankStatement> _filteredBankStatements = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadBankStatements();
    _searchController.addListener(_filterBankStatements);
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '🏦 BankStatementsPage: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('🏦 BankStatementsPage: No company context available');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBankStatements() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final bankStatements = await _dbService.getBankStatements();

      if (mounted) {
        setState(() {
          _bankStatements = bankStatements;
          _filteredBankStatements = bankStatements;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading bank statements: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to load bank statements: $e', isError: true);
      }
    }
  }

  void _filterBankStatements() {
    if (!mounted) return;

    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredBankStatements = _bankStatements.where((statement) {
        return statement.description.toLowerCase().contains(searchTerm) ||
            statement.transactionType.toLowerCase().contains(searchTerm);
      }).toList();
    });
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

  // Attachment upload function
  Future<void> _uploadBankStatementAttachment(
      BankStatement bankStatement) async {
    try {
      debugPrint(
          '📄 Starting bank statement attachment upload for statement: ${bankStatement.id}');

      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.multiple = false;
      uploadInput.accept = '.pdf,.doc,.docx,.jpg,.jpeg,.png,.xlsx,.xls,.txt';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) return;

        final file = files[0];
        debugPrint('📄 Selected file: ${file.name}, size: ${file.size}');

        try {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);

          reader.onLoadEnd.listen((e) async {
            try {
              final Uint8List fileBytes = reader.result as Uint8List;
              debugPrint(
                  '📄 File read complete, bytes length: ${fileBytes.length}');

              // Use the correct upload endpoint format matching expenses page
              final uri =
                  Uri.parse('http://localhost:8000/attachments/upload').replace(
                queryParameters: {
                  'entity_type': 'bank_statement',
                  'entity_id': bankStatement.id.toString(),
                  'company_id': _dbService.currentCompanyId ?? '1',
                },
              );

              debugPrint('📄 Upload URL: $uri');

              final request = http.MultipartRequest('POST', uri);

              // Add the file as multipart form data
              request.files.add(
                http.MultipartFile.fromBytes(
                  'file',
                  fileBytes,
                  filename: file.name,
                ),
              );

              // Add description as form field
              request.fields['description'] =
                  'Uploaded from PSC Accounting App';

              debugPrint('📄 Sending multipart request...');
              final streamedResponse = await request.send();
              final response = await http.Response.fromStream(streamedResponse);

              debugPrint('📄 Upload response status: ${response.statusCode}');
              debugPrint('📄 Upload response body: ${response.body}');

              if (response.statusCode == 200) {
                final responseData = jsonDecode(response.body);
                debugPrint('📄 Upload successful: $responseData');
                _showSnackBar('File uploaded successfully!');
              } else {
                debugPrint(
                    '📄 Upload failed with status: ${response.statusCode}');
                debugPrint('📄 Error response: ${response.body}');
                _showSnackBar('Failed to upload file: ${response.statusCode}',
                    isError: true);
              }
            } catch (e) {
              debugPrint('📄 Error in file upload: $e');
              _showSnackBar('Error uploading file: $e', isError: true);
            }
          });
        } catch (e) {
          debugPrint('📄 Error reading file: $e');
          _showSnackBar('Error reading file: $e', isError: true);
        }
      });
    } catch (e) {
      debugPrint('📄 Error in upload process: $e');
      _showSnackBar('Error initiating upload: $e', isError: true);
    }
  }

  // View attachments function
  Future<void> _viewBankStatementAttachments(
      BankStatement bankStatement) async {
    try {
      debugPrint(
          '📄 Fetching bank statement attachments for statement: ${bankStatement.id}');

      final uri = Uri.parse(
              'http://localhost:8000/attachments/bank_statement/${bankStatement.id}')
          .replace(
        queryParameters: {
          'company_id': _dbService.currentCompanyId ?? '1',
        },
      );

      final response = await http.get(uri);

      debugPrint('📄 Attachments response status: ${response.statusCode}');
      debugPrint('📄 Attachments response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> attachments = responseData['attachments'] ?? [];
        debugPrint('📄 Found ${attachments.length} attachments');

        if (attachments.isEmpty) {
          _showSnackBar('No attachments found for this bank statement');
          return;
        }

        _showAttachmentsDialog(bankStatement, attachments);
      } else {
        debugPrint('📄 Failed to fetch attachments: ${response.statusCode}');
        _showSnackBar('Failed to fetch attachments: ${response.statusCode}',
            isError: true);
      }
    } catch (e) {
      debugPrint('📄 Error fetching attachments: $e');
      _showSnackBar('Error fetching attachments: $e', isError: true);
    }
  }

  // Show attachments dialog
  void _showAttachmentsDialog(
      BankStatement bankStatement, List<dynamic> attachments) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Attachments for ${bankStatement.description}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                final filename = _decodeFilename(
                    attachment['original_filename'] ??
                        attachment['filename'] ??
                        'Unknown file');
                final fileSize = attachment['file_size'] ?? 0;
                final uploadDate =
                    attachment['upload_date'] ?? attachment['created_at'] ?? '';

                return ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(filename),
                  subtitle: Text(
                      'Size: ${_formatFileSize(fileSize)}\nUploaded: ${_formatDate(uploadDate)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () =>
                            _downloadAttachment(attachment['id'], filename),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _deleteAttachment(attachment['id'], filename),
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

  // Download attachment function
  Future<void> _downloadAttachment(int attachmentId, String filename) async {
    try {
      debugPrint(
          '📄 Downloading attachment: $attachmentId, filename: $filename');

      final response = await http.get(
        Uri.parse('http://localhost:8000/attachments/$attachmentId/download'),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = filename;

        anchor.click();
        html.Url.revokeObjectUrl(url);

        _showSnackBar('File downloaded successfully!');
      } else {
        debugPrint('📄 Download failed: ${response.statusCode}');
        _showSnackBar('Failed to download file: ${response.statusCode}',
            isError: true);
      }
    } catch (e) {
      debugPrint('📄 Error downloading file: $e');
      _showSnackBar('Error downloading file: $e', isError: true);
    }
  }

  // Delete attachment function
  Future<void> _deleteAttachment(int attachmentId, String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Attachment'),
          content: Text('Are you sure you want to delete "$filename"?'),
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
        debugPrint('📄 Deleting attachment: $attachmentId');

        final response = await http.delete(
          Uri.parse('http://localhost:8000/attachments/$attachmentId'),
        );

        if (response.statusCode == 200) {
          _showSnackBar('Attachment deleted successfully!');
          Navigator.of(context).pop(); // Close attachments dialog
        } else {
          debugPrint('📄 Delete failed: ${response.statusCode}');
          _showSnackBar('Failed to delete attachment: ${response.statusCode}',
              isError: true);
        }
      } catch (e) {
        debugPrint('📄 Error deleting attachment: $e');
        _showSnackBar('Error deleting attachment: $e', isError: true);
      }
    }
  }

  // Helper function to decode filename with Unicode support
  String _decodeFilename(String filename) {
    try {
      debugPrint('📄 Decoding filename: $filename');

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
        debugPrint('📄 Decoded from escape sequences: $decoded');
        return decoded;
      }

      // Try URL decoding if it contains percent encoding
      if (filename.contains('%')) {
        final decoded = Uri.decodeComponent(filename);
        debugPrint('📄 Decoded from URL encoding: $decoded');
        return decoded;
      }

      // If it looks like it has replacement characters, try to fix encoding issues
      if (filename.contains('�') || filename.contains('Ð')) {
        debugPrint('📄 Detected potential encoding issues');
        // Try to re-encode as Latin-1 and decode as UTF-8
        try {
          final bytes = latin1.encode(filename);
          final decoded = utf8.decode(bytes);
          debugPrint('📄 Re-encoded and decoded: $decoded');
          return decoded;
        } catch (e) {
          debugPrint('📄 Re-encoding failed: $e');
        }
      }

      // Return as-is if no special encoding detected
      debugPrint('📄 Returning filename as-is: $filename');
      return filename;
    } catch (e) {
      debugPrint('📄 Failed to decode filename: $filename, error: $e');
      return filename; // Return original if decoding fails
    }
  } // Helper function to format file size

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Helper function to format date
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bank Statements'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header and controls
          Container(
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bank statements...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          // Bank statements list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredBankStatements.isEmpty
                      ? const Center(
                          child: Text(
                            'No bank statements found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredBankStatements.length,
                          itemBuilder: (context, index) {
                            final statement = _filteredBankStatements[index];
                            return _buildBankStatementCard(statement);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankStatementCard(BankStatement statement) {
    final isCredit = statement.transactionType.toLowerCase() == 'credit';

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
          // Header row with description and transaction type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  statement.description,
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
                  color: isCredit
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statement.transactionType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Amount and date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${statement.transactionDate.day}/${statement.transactionDate.month}/${statement.transactionDate.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
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
                    '${isCredit ? '+' : '-'}\$${statement.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Balance
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${statement.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
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
                onPressed: () => _editBankStatement(statement),
              ),
              _buildActionButton(
                icon: Icons.attach_file,
                label: 'Add Attachment',
                color: Colors.green,
                onPressed: () => _uploadBankStatementAttachment(statement),
              ),
              _buildActionButton(
                icon: Icons.visibility,
                label: 'View Attachments',
                color: Colors.orange,
                onPressed: () => _viewBankStatementAttachments(statement),
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Delete',
                color: Colors.red,
                onPressed: () => _deleteBankStatement(statement),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editBankStatement(BankStatement statement) {
    debugPrint(
        '🏦 [BankStatementsPage] Edit bank statement clicked for: ${statement.description}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditBankStatementDialog(bankStatement: statement);
      },
    ).then((_) {
      debugPrint(
          '🏦 [BankStatementsPage] Edit dialog closed, refreshing statements...');
      _loadBankStatements();
    });
  }

  void _deleteBankStatement(BankStatement statement) async {
    // Ensure company context is set before attempting delete
    _initializeCompanyContext();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Bank Statement'),
          content: Text(
              'Are you sure you want to delete bank statement: ${statement.description}?'),
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
        debugPrint('🗑️ === DELETE BANK STATEMENT ===');
        debugPrint('🗑️ Statement ID: ${statement.id}');
        debugPrint('🗑️ Description: ${statement.description}');
        debugPrint('🗑️ Company Context: ${_dbService.currentCompanyId}');
        debugPrint('🗑️ Demo Mode: ${_dbService.isDemoMode}');

        await _dbService.deleteBankStatement(statement.id);
        _loadBankStatements();

        debugPrint('🗑️ Bank statement deleted successfully');
        _showSnackBar('Bank statement deleted successfully');
      } catch (e) {
        debugPrint('🗑️ Error deleting bank statement: $e');
        _showSnackBar('Failed to delete bank statement: $e', isError: true);
      }
    }
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
}
