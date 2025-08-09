import 'package:flutter/material.dart';
import '../../context/simple_company_context.dart';
import '../../dialogs/manage_employees_dialog.dart';
import '../../dialogs/edit_company_dialog.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedCompany = SimpleCompanyContext.selectedCompany;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 32,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Administration',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage company settings and employees',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Company Information Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.business,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Company Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedCompany != null) ...[
                      _buildInfoRow('Company Name', selectedCompany.name),
                      _buildInfoRow(
                          'Currency', selectedCompany.currency ?? 'EUR'),
                      _buildInfoRow(
                          'Country', selectedCompany.country ?? 'Not set'),
                      _buildInfoRow(
                          'VAT Number', selectedCompany.vatNumber ?? 'Not set'),
                      _buildInfoRow('Status',
                          selectedCompany.isDemo ? 'Demo Mode' : 'Live Mode'),
                    ] else
                      const Text('No company selected'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: selectedCompany != null ? _editCompany : null,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Company'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Employee Management Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Employee Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Manage employee records, salaries, and payroll information.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _manageEmployees,
                      icon: const Icon(Icons.manage_accounts),
                      label: const Text('Manage Employees'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // System Information Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'System Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('App Version', '1.0.0'),
                    _buildInfoRow('Database', 'PostgreSQL'),
                    _buildInfoRow('Backend API', 'FastAPI'),
                    _buildInfoRow(
                        'Company ID', selectedCompany?.id.toString() ?? 'N/A'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editCompany() {
    showDialog(
      context: context,
      builder: (context) => const EditCompanyDialog(),
    ).then((_) {
      // Refresh the screen after company edit
      setState(() {});
    });
  }

  void _manageEmployees() {
    showDialog(
      context: context,
      builder: (context) => const ManageEmployeesDialog(),
    );
  }
}
