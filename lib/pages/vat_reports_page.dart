import 'package:flutter/material.dart';
import '../models/vat_models.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../widgets/vat_summary_widget.dart';

class VATReportsPage extends StatefulWidget {
  const VATReportsPage({super.key});

  @override
  State<VATReportsPage> createState() => _VATReportsPageState();
}

class _VATReportsPageState extends State<VATReportsPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();
  VATSummary? _vatSummary;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVATSummary();
  }

  Future<void> _loadVATSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final summary = await VATService.getVATSummary(
        companyId: selectedCompany.id.toString(),
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
      );

      setState(() {
        _vatSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 730)), // 2 years ago
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
      await _loadVATSummary();
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      await _loadVATSummary();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(_formatDate(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(_formatDate(_endDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _loadVATSummary,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Loading...' : 'Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Period: ${(_endDate.difference(_startDate).inDays + 1)} days',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPeriodButtons() {
    return Row(
      children: [
        _buildQuickPeriodButton('Last 30 Days', 30),
        const SizedBox(width: 8),
        _buildQuickPeriodButton('Last 3 Months', 90),
        const SizedBox(width: 8),
        _buildQuickPeriodButton('Last 6 Months', 180),
        const SizedBox(width: 8),
        _buildQuickPeriodButton('Last Year', 365),
      ],
    );
  }

  Widget _buildQuickPeriodButton(String label, int days) {
    return TextButton(
      onPressed: () {
        setState(() {
          _endDate = DateTime.now();
          _startDate = _endDate.subtract(Duration(days: days));
        });
        _loadVATSummary();
      },
      child: Text(label),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load VAT Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVATSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading VAT Report...'),
        ],
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No VAT Data Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No transactions found for the selected period.\nTry adjusting the date range or add some transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Transactions'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _loadVATSummary,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Important Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              icon: Icons.info_outline,
              title: 'VAT Returns',
              description: 'VAT returns are typically filed bi-monthly or quarterly depending on your registration.',
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              icon: Icons.calendar_today,
              title: 'Due Dates',
              description: 'Ensure you file your VAT return by the 19th of the month following the return period.',
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              icon: Icons.account_balance,
              title: 'Payment',
              description: 'VAT payments are due at the same time as your return filing.',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assessment),
            SizedBox(width: 8),
            Text('VAT Reports'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadVATSummary,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSelector(),
            const SizedBox(height: 8),
            _buildQuickPeriodButtons(),
            const SizedBox(height: 24),
            
            if (_error != null)
              _buildErrorView()
            else if (_isLoading)
              _buildLoadingView()
            else if (_vatSummary == null)
              _buildNoDataView()
            else ...[
              VATSummaryWidget(
                summary: _vatSummary!,
                showDetails: true,
              ),
              const SizedBox(height: 24),
              _buildAdditionalInfo(),
            ],
          ],
        ),
      ),
    );
  }
}