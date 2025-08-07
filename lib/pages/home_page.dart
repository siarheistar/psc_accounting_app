import 'dart:html' as html; // Only used for Web
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../services/database_service.dart';
import '../context/simple_company_context.dart';
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

  void _showAddDialog() {
    if (_dbService.isDemoMode) {
      _showSnackBar(
          'Cannot add transactions in demo mode. Create a real company first.',
          isError: true);
      return;
    }

    switch (_selectedTabIndex) {
      case 0:
        _showAddInvoiceDialog();
        break;
      case 1:
        _showAddExpenseDialog();
        break;
      case 2:
        _showAddPayrollDialog();
        break;
      case 3:
        _showAddBankStatementDialog();
        break;
      default:
        _addSampleTransaction();
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
      try {
        await _dbService.insertExpense(expense);
        _showSnackBar('Expense created successfully!');
        await _loadDashboardData();
      } catch (e) {
        _showSnackBar('Failed to create expense: $e', isError: true);
      }
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
        title: Text('PDF Attachments - ${entityType.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Upload PDF'),
              subtitle: const Text('Attach a PDF document'),
              onTap: () {
                Navigator.pop(context);
                _uploadPDF(entityType, entityId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.green),
              title: const Text('View Attachments'),
              subtitle: const Text('See all attached PDFs'),
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
        // Web file picker
        final input = html.FileUploadInputElement()..accept = '.pdf';
        input.click();

        input.onChange.listen((e) async {
          final files = input.files;
          if (files!.isEmpty) return;

          final file = files[0];
          if (!file.name.toLowerCase().endsWith('.pdf')) {
            _showSnackBar('Please select a PDF file', isError: true);
            return;
          }

          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((e) async {
            try {
              final bytes = reader.result as List<int>;
              await _uploadPDFToServer(entityType, entityId, file.name, bytes);
              _showSnackBar('PDF uploaded successfully!');
            } catch (e) {
              _showSnackBar('Failed to upload PDF: $e', isError: true);
            }
          });
        });
      } else {
        // Mobile file picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.bytes != null) {
          final file = result.files.single;
          await _uploadPDFToServer(
              entityType, entityId, file.name, file.bytes!);
          _showSnackBar('PDF uploaded successfully!');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to upload PDF: $e', isError: true);
    }
  }

  Future<void> _uploadPDFToServer(String entityType, String entityId,
      String filename, List<int> bytes) async {
    debugPrint('📎 === PDF UPLOAD ATTEMPT ===');
    debugPrint('📎 Entity Type: $entityType');
    debugPrint('📎 Entity ID: $entityId');
    debugPrint('📎 Company ID: ${_dbService.currentCompanyId}');
    debugPrint('📎 Filename: $filename');
    debugPrint('📎 File Size: ${bytes.length} bytes');

    // Backend expects all parameters as query parameters
    final queryParams = {
      'entity_type': entityType,
      'entity_id': entityId,
      'company_id': _dbService.currentCompanyId ?? '1',
      'filename': filename,
      'file_data':
          base64Encode(bytes), // Convert bytes to base64 for query param
    };

    final url = Uri.parse('http://localhost:8000/documents/upload')
        .replace(queryParameters: queryParams);
    debugPrint('📎 Upload URL: $url');

    debugPrint('📎 Request query params: $queryParams');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      debugPrint('📎 === UPLOAD RESPONSE ===');
      debugPrint('📎 Status Code: ${response.statusCode}');
      debugPrint('📎 Response Headers: ${response.headers}');
      debugPrint('📎 Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('📎 === UPLOAD FAILED ===');
        debugPrint('📎 Status: ${response.statusCode}');
        debugPrint('📎 Error: ${response.body}');
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      debugPrint('📎 === UPLOAD SUCCESS ===');
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
                return const Center(child: Text('No PDF attachments found'));
              }

              return ListView.builder(
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final attachment = attachments[index];
                  return ListTile(
                    leading:
                        const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(attachment['filename'] ?? 'Unknown'),
                    subtitle:
                        Text('${(attachment['file_size'] ?? 0) ~/ 1024} KB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadPDF(attachment['id']),
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
      final url =
          Uri.parse('http://localhost:8000/documents/$entityType/$entityId');
      final response = await http.get(
        url.replace(queryParameters: {
          'company_id': _dbService.currentCompanyId ?? '1'
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch attachments');
      }
    } catch (e) {
      debugPrint('Error fetching PDF attachments: $e');
      return [];
    }
  }

  Future<void> _downloadPDF(int documentId) async {
    try {
      debugPrint('📥 === STARTING PDF DOWNLOAD ===');
      debugPrint('📥 Document ID: $documentId');

      final data = await _dbService.downloadAttachment(documentId);

      final filename = data['filename'];
      final fileData = data['file_data'];

      if (filename == null || fileData == null) {
        throw Exception(
            'Invalid download response: missing filename or file_data');
      }

      if (kIsWeb) {
        // Web download
        final bytes = base64.decode(fileData);
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

        debugPrint('📥 === DOWNLOAD SUCCESS ===');
        debugPrint('📥 File downloaded: $filename');
        _showSnackBar('PDF downloaded successfully!');
      } else {
        _showSnackBar('Download feature available on web only');
      }
    } catch (e) {
      debugPrint('📥 === DOWNLOAD ERROR ===');
      debugPrint('📥 Exception: $e');
      _showSnackBar('Failed to download PDF: $e', isError: true);
    }
  }

  Future<void> _addSampleTransaction() async {
    if (_dbService.isDemoMode) {
      _showSnackBar(
          'Cannot add transactions in demo mode. Create a real company first.',
          isError: true);
      return;
    }

    try {
      debugPrint('💰 === ADDING SAMPLE TRANSACTION ===');

      final invoice = Invoice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        invoiceNumber:
            'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        clientName:
            'Sample Client ${DateTime.now().hour}:${DateTime.now().minute}',
        amount:
            (500 + (DateTime.now().millisecondsSinceEpoch % 2000)).toDouble(),
        date: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: 'Pending',
        description: 'Sample invoice created from dashboard',
        createdAt: DateTime.now(),
      );

      await _dbService.insertInvoice(invoice);

      _showSnackBar('Sample invoice created successfully!');

      // Reload dashboard data
      await _loadDashboardData();
    } catch (e) {
      debugPrint('💰 === TRANSACTION ERROR ===');
      debugPrint('💰 Error: $e');
      _showSnackBar('Failed to create transaction: $e', isError: true);
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDemoMode = _dbService.isDemoMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Icon(
              Icons.account_balance,
              color: isDemoMode ? Colors.orange : Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isDemoMode ? 'PSC Accounting - Demo' : 'PSC Accounting',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDemoMode ? Colors.orange : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        actions: [
          // Company info button
          IconButton(
            onPressed: () => _showCompanyInfo(),
            icon: Icon(
              Icons.info_outline,
              color: isDemoMode ? Colors.orange : Colors.blue,
            ),
          ),
          // Period selector
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'This Month',
              style: TextStyle(fontSize: 12),
            ),
          ),
          // User profile
          Padding(
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
                            user.displayName?.substring(0, 1).toUpperCase() ??
                                'U',
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : Stack(
                  children: [
                    _buildDashboard(),
                    _buildCustomFloatingAction(),
                  ],
                ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          _buildWelcomeSection(),
          const SizedBox(height: 24),

          // Quick Overview title
          const Text(
            'Quick Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          // Metrics cards
          _buildMetricsCards(),
          const SizedBox(height: 24),

          // Data tabs
          _buildDataTabs(),
          const SizedBox(height: 16),

          // Tab content
          _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    final isDemoMode = _dbService.isDemoMode;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDemoMode ? 'Demo Dashboard' : 'Welcome back!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isDemoMode
                      ? 'Exploring sample data - ${user?.displayName ?? 'User'}'
                      : 'Hello, ${user?.displayName?.split(' ').first ?? 'User'}!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDemoMode
                      ? 'This is demonstration data only'
                      : 'Here\'s what\'s happening with your finances.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDemoMode ? Icons.preview : Icons.dashboard,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    // Use backend API metrics instead of local calculations
    final totalIncome =
        (_metrics['invoices']?['total_invoice_amount'] ?? 0).toDouble();
    final totalExpenses =
        (_metrics['expenses']?['total_expense_amount'] ?? 0).toDouble();
    final netProfit = (_metrics['net_profit'] ?? 0).toDouble();
    final pendingInvoices = (_metrics['invoices']?['pending_invoices'] ?? 0);
    final totalInvoices = (_metrics['invoices']?['total_invoices'] ?? 0);

    final metrics = [
      {
        'title': 'Total Income',
        'value': '\$${totalIncome.toStringAsFixed(2)}',
        'change': '+$totalInvoices invoices',
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
      {
        'title': 'Total Expenses',
        'value': '\$${totalExpenses.toStringAsFixed(2)}',
        'change': '+${_expenses.length} expenses',
        'icon': Icons.trending_down,
        'color': Colors.red,
      },
      {
        'title': 'Net Profit',
        'value': '\$${netProfit.toStringAsFixed(2)}',
        'change': netProfit >= 0 ? 'Profit' : 'Loss',
        'icon': Icons.account_balance_wallet,
        'color': netProfit >= 0 ? Colors.blue : Colors.red,
      },
      {
        'title': 'Pending Invoices',
        'value': '$pendingInvoices',
        'change': 'of $totalInvoices total',
        'icon': Icons.receipt,
        'color': Colors.orange,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Container(
          padding: const EdgeInsets.all(16),
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
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric['title'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    metric['icon'] as IconData,
                    size: 18,
                    color: metric['color'] as Color,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                metric['value'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                metric['change'] as String,
                style: TextStyle(
                  fontSize: 10,
                  color: metric['color'] as Color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
              onPressed: () =>
                  _showSnackBar('View all invoices feature coming soon!'),
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

  Widget _buildInvoiceCard(Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(invoice.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.receipt,
              size: 16,
              color: _getStatusColor(invoice.status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  invoice.clientName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${invoice.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(invoice.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      invoice.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(invoice.status),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showPDFOptions('invoice', invoice.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        size: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showEditDeleteOptions('invoice', invoice),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 12,
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

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return _buildEmptyState(
          'No expenses found', 'Track your first expense to get started');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Expenses (${_expenses.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ..._expenses
            .take(5)
            .map((expense) => _buildExpenseCard(expense))
            .toList(),
      ],
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.money_off,
              size: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  expense.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                '\$${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showPDFOptions('expense', expense.id),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.attach_file,
                    size: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showEditDeleteOptions('expense', expense),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollList() {
    if (_payrollEntries.isEmpty) {
      return _buildEmptyState(
          'No payroll entries found', 'Add your first payroll entry');
    }

    return Column(
      children:
          _payrollEntries.map((entry) => _buildPayrollCard(entry)).toList(),
    );
  }

  Widget _buildPayrollCard(PayrollEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.person,
              size: 16,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.employeeName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.period,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                '\$${entry.netPay.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showPDFOptions('payroll', entry.id),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.attach_file,
                    size: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showEditDeleteOptions('payroll', entry),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankStatementsList() {
    if (_bankStatements.isEmpty) {
      return _buildEmptyState(
          'No bank statements found', 'Import your first bank statement');
    }

    return Column(
      children: _bankStatements
          .map((statement) => _buildBankStatementCard(statement))
          .toList(),
    );
  }

  Widget _buildBankStatementCard(BankStatement statement) {
    final isCredit = statement.amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isCredit ? Icons.add : Icons.remove,
              size: 16,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statement.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statement.transactionType,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}\$${statement.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bal: \$${statement.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () =>
                        _showPDFOptions('bank_statement', statement.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.attach_file,
                        size: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () =>
                        _showEditDeleteOptions('bank_statement', statement),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 12,
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

  Widget _buildCustomFloatingAction() {
    return Positioned(
      right: 20,
      bottom: 100, // Position higher to avoid overlap with list items
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: "home_custom_fab",
          onPressed: _dbService.isDemoMode
              ? () => _showSnackBar(
                  'Demo mode - Create a real company to add transactions',
                  isError: true)
              : _showAddDialog,
          backgroundColor: _dbService.isDemoMode ? Colors.orange : Colors.blue,
          child: Icon(
            _dbService.isDemoMode ? Icons.preview : Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    );
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
                'Total Income: \$${(_metrics['invoices']?['total_invoice_amount'] ?? 0).toStringAsFixed(2)}'),
            Text(
                'Total Expenses: \$${(_metrics['expenses']?['total_expense_amount'] ?? 0).toStringAsFixed(2)}'),
            Text(
                'Net Profit: \$${(_metrics['net_profit'] ?? 0).toStringAsFixed(2)}'),
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
}
