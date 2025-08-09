import 'package:flutter/material.dart';
import '../models/accounting_models.dart';
import '../services/database_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import 'add_employee_dialog.dart';
import 'edit_employee_dialog.dart';

class ManageEmployeesDialog extends StatefulWidget {
  const ManageEmployeesDialog({super.key});

  @override
  State<ManageEmployeesDialog> createState() => _ManageEmployeesDialogState();
}

class _ManageEmployeesDialogState extends State<ManageEmployeesDialog> {
  final DatabaseService _dbService = DatabaseService();
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _error;

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency);
    }
    return '€'; // Default to Euro
  }

  @override
  void initState() {
    super.initState();
    _initializeCompanyContext();
    _loadEmployees();
  }

  void _initializeCompanyContext() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );
      debugPrint(
          '👥 ManageEmployeesDialog: Set company context - ID: ${selectedCompany.id}, Demo: ${selectedCompany.isDemo}');
    } else {
      debugPrint('👥 ManageEmployeesDialog: No company context available');
    }
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employees = await _dbService.getEmployeesList();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addEmployee() async {
    final newEmployee = await showDialog<Employee>(
      context: context,
      builder: (context) => const AddEmployeeDialog(),
    );

    if (newEmployee != null) {
      await _loadEmployees();
      _showSnackBar('Employee added successfully!');
    }
  }

  Future<void> _editEmployee(Employee employee) async {
    // Check if this is a payroll-extracted employee
    if (employee.id.startsWith('payroll_')) {
      _showSnackBar(
        'Cannot edit this employee. Employees from payroll data are read-only.',
        isError: true,
      );
      return;
    }

    final updatedEmployee = await showDialog<Employee>(
      context: context,
      builder: (context) => EditEmployeeDialog(employee: employee),
    );

    if (updatedEmployee != null) {
      await _loadEmployees();
      _showSnackBar('Employee updated successfully!');
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete employee "${employee.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteEmployee(employee.id);
        await _loadEmployees();
        _showSnackBar('Employee deleted successfully!');
      } catch (e) {
        _showSnackBar('Failed to delete employee: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF10B981)),
                const SizedBox(width: 12),
                const Text(
                  'Manage Employees',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addEmployee,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Employee'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error loading employees: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadEmployees,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _employees.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No employees found',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add your first employee to get started.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _addEmployee,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Employee'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _employees.length,
                              itemBuilder: (context, index) {
                                final employee = _employees[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF10B981),
                                      child: Text(
                                        employee.name.isNotEmpty
                                            ? employee.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            employee.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (employee.id.startsWith('payroll_'))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withOpacity(0.2),
                                              border: Border.all(
                                                  color: Colors.orange),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'From Payroll',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (employee.position != null)
                                          Text(
                                              'Position: ${employee.position}'),
                                        if (employee.email != null)
                                          Text('Email: ${employee.email}'),
                                        if (employee.baseSalary != null)
                                          Text(
                                              'Base Salary: ${_getCurrencySymbol()}${employee.baseSalary!.toStringAsFixed(2)}'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!employee.isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'INACTIVE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'edit':
                                                _editEmployee(employee);
                                                break;
                                              case 'delete':
                                                _deleteEmployee(employee);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) {
                                            // Check if this is a payroll-extracted employee
                                            final isPayrollEmployee = employee
                                                .id
                                                .startsWith('payroll_');

                                            return [
                                              PopupMenuItem(
                                                value: 'edit',
                                                enabled: !isPayrollEmployee,
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.edit,
                                                    color: isPayrollEmployee
                                                        ? Colors.grey
                                                        : Colors.blue,
                                                  ),
                                                  title: Text(
                                                    isPayrollEmployee
                                                        ? 'Edit (Read-only)'
                                                        : 'Edit',
                                                    style: TextStyle(
                                                      color: isPayrollEmployee
                                                          ? Colors.grey
                                                          : null,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                enabled: !isPayrollEmployee,
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.delete,
                                                    color: isPayrollEmployee
                                                        ? Colors.grey
                                                        : Colors.red,
                                                  ),
                                                  title: Text(
                                                    isPayrollEmployee
                                                        ? 'Delete (Read-only)'
                                                        : 'Delete',
                                                    style: TextStyle(
                                                      color: isPayrollEmployee
                                                          ? Colors.grey
                                                          : null,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                            ];
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_employees.length} employee(s) total',
                  style: const TextStyle(color: Colors.grey),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
