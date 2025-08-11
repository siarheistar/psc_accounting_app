import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../models/company.dart';
import '../services/api_service.dart';

class EditCompanyDialog extends StatefulWidget {
  const EditCompanyDialog({super.key});

  @override
  State<EditCompanyDialog> createState() => _EditCompanyDialogState();
}

class _EditCompanyDialogState extends State<EditCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _vatNumberController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _ownerEmailController;
  String _selectedCountry = 'Estonia';
  String _selectedCurrency = 'EUR';
  String _selectedSubscriptionPlan = 'free';
  String _selectedStatus = 'active';
  bool _isLoading = false;

  final List<Map<String, String>> _countries = [
    {'code': 'EE', 'name': 'Estonia', 'currency': 'EUR'},
    {'code': 'LV', 'name': 'Latvia', 'currency': 'EUR'},
    {'code': 'LT', 'name': 'Lithuania', 'currency': 'EUR'},
    {'code': 'FI', 'name': 'Finland', 'currency': 'EUR'},
    {'code': 'SE', 'name': 'Sweden', 'currency': 'SEK'},
    {'code': 'NO', 'name': 'Norway', 'currency': 'NOK'},
    {'code': 'DK', 'name': 'Denmark', 'currency': 'DKK'},
    {'code': 'DE', 'name': 'Germany', 'currency': 'EUR'},
    {'code': 'FR', 'name': 'France', 'currency': 'EUR'},
    {'code': 'ES', 'name': 'Spain', 'currency': 'EUR'},
    {'code': 'IT', 'name': 'Italy', 'currency': 'EUR'},
    {'code': 'NL', 'name': 'Netherlands', 'currency': 'EUR'},
    {'code': 'BE', 'name': 'Belgium', 'currency': 'EUR'},
    {'code': 'AT', 'name': 'Austria', 'currency': 'EUR'},
    {'code': 'CH', 'name': 'Switzerland', 'currency': 'CHF'},
    {'code': 'GB', 'name': 'United Kingdom', 'currency': 'GBP'},
    {'code': 'IE', 'name': 'Ireland', 'currency': 'EUR'},
    {'code': 'US', 'name': 'United States', 'currency': 'USD'},
    {'code': 'CA', 'name': 'Canada', 'currency': 'CAD'},
    {'code': 'AU', 'name': 'Australia', 'currency': 'AUD'},
    {'code': 'JP', 'name': 'Japan', 'currency': 'JPY'},
  ];

  final List<Map<String, String>> _subscriptionPlans = [
    {'id': 'free', 'name': 'Free Plan'},
    {'id': 'basic', 'name': 'Basic Plan'},
    {'id': 'premium', 'name': 'Premium Plan'},
    {'id': 'enterprise', 'name': 'Enterprise Plan'},
  ];

  final List<Map<String, String>> _statuses = [
    {'id': 'active', 'name': 'Active'},
    {'id': 'inactive', 'name': 'Inactive'},
    {'id': 'suspended', 'name': 'Suspended'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeFromCompany();
  }

  void _initializeFromCompany() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany != null) {
      _nameController = TextEditingController(text: selectedCompany.name);
      _vatNumberController =
          TextEditingController(text: selectedCompany.vatNumber ?? '');
      _phoneController = TextEditingController(text: selectedCompany.phone);
      _addressController = TextEditingController(text: selectedCompany.address);
      _ownerEmailController =
          TextEditingController(text: selectedCompany.ownerEmail);

      // Check if the company's country exists in our list
      final companyCountry = selectedCompany.country ?? 'Estonia';
      final countryExists = _countries.any((c) => c['name'] == companyCountry);

      _selectedCountry = countryExists ? companyCountry : 'Estonia';
      _selectedCurrency = selectedCompany.currency ?? 'EUR';
      _selectedSubscriptionPlan =
          'free'; // Default since not in Company model yet
      _selectedStatus = 'active'; // Default since not in Company model yet

      print(
          '🏢 [EditCompanyDialog] Company country: $companyCountry, exists in list: $countryExists, selected: $_selectedCountry');
    } else {
      _nameController = TextEditingController();
      _vatNumberController = TextEditingController();
      _phoneController = TextEditingController();
      _addressController = TextEditingController();
      _ownerEmailController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vatNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  void _onCountryChanged(String? country) {
    if (country != null) {
      setState(() {
        _selectedCountry = country;
        // Auto-update currency based on country
        final countryData = _countries.firstWhere(
          (c) => c['name'] == country,
          orElse: () => {'currency': 'EUR'},
        );
        _selectedCurrency = countryData['currency'] ?? 'EUR';
      });
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      // Create updated company data
      final updatedCompanyData = {
        'id': selectedCompany.id,
        'name': _nameController.text.trim(),
        'country': _selectedCountry,
        'currency': _selectedCurrency,
        'vat_number': _vatNumberController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'owner_email': _ownerEmailController.text.trim(),
        'subscription_plan': _selectedSubscriptionPlan,
        'status': _selectedStatus,
        'is_demo': selectedCompany.isDemo,
      };

      print('🏢 Updating company: $updatedCompanyData');

      // Call the API to update the company in the database
      final apiResult = await ApiService.updateCompany(
          selectedCompany.id.toString(), updatedCompanyData);

      print('✅ Company updated successfully: $apiResult');

      // Update the local context with the new data
      final updatedCompany = Company(
        id: selectedCompany.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: selectedCompany.email,
        ownerEmail: _ownerEmailController.text.trim(),
        createdAt: selectedCompany.createdAt,
        isDemo: selectedCompany.isDemo,
        country: _selectedCountry,
        currency: _selectedCurrency,
        vatNumber: _vatNumberController.text.trim(),
      );

      SimpleCompanyContext.setSelectedCompany(updatedCompany);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to update company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update company: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.business,
                      color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Edit Company',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Basic Information Section
                      _buildSectionHeader('Company Information'),
                      const SizedBox(height: 16),

                      // Company Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Company Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Owner Email
                      TextFormField(
                        controller: _ownerEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Owner Email *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Owner email is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-\s\(\)]')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Business Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Location & Tax Information Section
                      _buildSectionHeader('Location & Tax Information'),
                      const SizedBox(height: 16),

                      // Country Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Country *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.public),
                        ),
                        items: _countries.map((country) {
                          return DropdownMenuItem<String>(
                            value: country['name'],
                            child: Text(country['name']!),
                          );
                        }).toList(),
                        onChanged: _onCountryChanged,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Country is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Currency Display (auto-filled based on country)
                      TextFormField(
                        initialValue: _selectedCurrency,
                        decoration: InputDecoration(
                          labelText: 'Currency',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixText: CurrencyUtils.getCurrencySymbol(
                              _selectedCurrency),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        readOnly: true,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),

                      // VAT Number
                      TextFormField(
                        controller: _vatNumberController,
                        decoration: const InputDecoration(
                          labelText: 'VAT Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long),
                          hintText: 'Enter VAT registration number',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Business Information Section
                      _buildSectionHeader('Business Information'),
                      const SizedBox(height: 16),

                      // Subscription Plan
                      DropdownButtonFormField<String>(
                        value: _selectedSubscriptionPlan,
                        decoration: const InputDecoration(
                          labelText: 'Subscription Plan',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.card_membership),
                        ),
                        items: _subscriptionPlans.map((plan) {
                          return DropdownMenuItem<String>(
                            value: plan['id'],
                            child: Text(plan['name']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubscriptionPlan = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Company Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business_center),
                        ),
                        items: _statuses.map((status) {
                          return DropdownMenuItem<String>(
                            value: status['id'],
                            child: Text(status['name']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }
}
