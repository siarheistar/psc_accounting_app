import 'package:flutter/material.dart';
import '../context/simple_company_context.dart';
import 'vat_reports_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assessment),
            SizedBox(width: 8),
            Text('Reports & Analytics'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildReportCategories(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, size: 32, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Reports & Analytics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      if (selectedCompany != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          selectedCompany.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Generate comprehensive reports and analytics for your business. Track financial performance, VAT obligations, and business insights.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCategories(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Reports',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // VAT & Tax Reports
        _buildReportCategory(
          title: 'VAT & Tax Reports',
          icon: Icons.account_balance,
          color: Colors.green,
          reports: [
            ReportItem(
              title: 'VAT Summary Report',
              description: 'Comprehensive VAT calculations, input/output VAT, and net amounts due',
              icon: Icons.receipt_long,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VATReportsPage()),
              ),
              featured: true,
            ),
            ReportItem(
              title: 'VAT Returns Preparation',
              description: 'Prepare data for VAT return filing (Coming Soon)',
              icon: Icons.description,
              onTap: () => _showComingSoon(context, 'VAT Returns'),
              enabled: false,
            ),
            ReportItem(
              title: 'Business Usage Analysis',
              description: 'Analyze business vs personal expense usage (Coming Soon)',
              icon: Icons.business,
              onTap: () => _showComingSoon(context, 'Business Usage Analysis'),
              enabled: false,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Financial Reports
        _buildReportCategory(
          title: 'Financial Reports',
          icon: Icons.trending_up,
          color: Colors.blue,
          reports: [
            ReportItem(
              title: 'Profit & Loss Statement',
              description: 'Income and expense summary for specified periods (Coming Soon)',
              icon: Icons.trending_up,
              onTap: () => _showComingSoon(context, 'P&L Statement'),
              enabled: false,
            ),
            ReportItem(
              title: 'Cash Flow Report',
              description: 'Track cash inflows and outflows (Coming Soon)',
              icon: Icons.account_balance_wallet,
              onTap: () => _showComingSoon(context, 'Cash Flow Report'),
              enabled: false,
            ),
            ReportItem(
              title: 'Invoice Aging Report',
              description: 'Outstanding invoices and payment tracking (Coming Soon)',
              icon: Icons.schedule,
              onTap: () => _showComingSoon(context, 'Invoice Aging'),
              enabled: false,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // E-Worker Reports
        _buildReportCategory(
          title: 'E-Worker Reports',
          icon: Icons.work,
          color: Colors.purple,
          reports: [
            ReportItem(
              title: 'E-Worker Period Summary',
              description: 'Summary of all e-worker periods and earnings (Coming Soon)',
              icon: Icons.calendar_today,
              onTap: () => _showComingSoon(context, 'E-Worker Summary'),
              enabled: false,
            ),
            ReportItem(
              title: 'E-Worker Expense Report',
              description: 'Detailed breakdown of e-worker related expenses (Coming Soon)',
              icon: Icons.receipt,
              onTap: () => _showComingSoon(context, 'E-Worker Expenses'),
              enabled: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCategory({
    required String title,
    required IconData icon,
    required Color color,
    required List<ReportItem> reports,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...reports.map((report) => _buildReportItem(report)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(ReportItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.enabled 
              ? (item.featured ? Colors.green : Colors.blue) 
              : Colors.grey[300],
          child: Icon(
            item.icon,
            color: item.enabled ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: item.enabled ? null : Colors.grey[600],
                ),
              ),
            ),
            if (item.featured) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else if (!item.enabled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.description,
            style: TextStyle(
              fontSize: 12,
              color: item.enabled ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ),
        trailing: item.enabled 
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: item.enabled ? item.onTap : null,
        enabled: item.enabled,
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upcoming, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: Text('$feature will be available in a future update. Stay tuned!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ReportItem {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool featured;

  ReportItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.featured = false,
  });
}