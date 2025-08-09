import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/company.dart';
import '../services/api_service.dart';
import '../utils/currency_utils.dart';

class CreateCompanyDialog extends StatefulWidget {
  const CreateCompanyDialog({super.key});

  @override
  State<CreateCompanyDialog> createState() => _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends State<CreateCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _ownerEmailController = TextEditingController();

  String _selectedCountry = 'Ireland';
  String _selectedCurrency = 'EUR';
  String _selectedSubscriptionPlan = 'free';
  bool _isLoading = false;

  final List<Map<String, String>> _countries = [
    {'code': 'IE', 'name': 'Ireland', 'currency': 'EUR'},
    {'code': 'GB', 'name': 'United Kingdom', 'currency': 'GBP'},
    {'code': 'US', 'name': 'United States', 'currency': 'USD'},
    {'code': 'DE', 'name': 'Germany', 'currency': 'EUR'},
    {'code': 'FR', 'name': 'France', 'currency': 'EUR'},
    {'code': 'ES', 'name': 'Spain', 'currency': 'EUR'},
    {'code': 'IT', 'name': 'Italy', 'currency': 'EUR'},
    {'code': 'NL', 'name': 'Netherlands', 'currency': 'EUR'},
    {'code': 'BE', 'name': 'Belgium', 'currency': 'EUR'},
    {'code': 'AT', 'name': 'Austria', 'currency': 'EUR'},
    {'code': 'CH', 'name': 'Switzerland', 'currency': 'CHF'},
    {'code': 'CA', 'name': 'Canada', 'currency': 'CAD'},
    {'code': 'AU', 'name': 'Australia', 'currency': 'AUD'},
    {'code': 'JP', 'name': 'Japan', 'currency': 'JPY'},
    {'code': 'SE', 'name': 'Sweden', 'currency': 'SEK'},
    {'code': 'NO', 'name': 'Norway', 'currency': 'NOK'},
    {'code': 'DK', 'name': 'Denmark', 'currency': 'DKK'},
    {'code': 'FI', 'name': 'Finland', 'currency': 'EUR'},
    {'code': 'EE', 'name': 'Estonia', 'currency': 'EUR'},
    {'code': 'LV', 'name': 'Latvia', 'currency': 'EUR'},
    {'code': 'LT', 'name': 'Lithuania', 'currency': 'EUR'},
  ];

  final List<Map<String, String>> _subscriptionPlans = [
    {
      'id': 'free',
      'name': 'Free Plan',
      'description': 'Basic features for small businesses'
    },
    {
      'id': 'basic',
      'name': 'Basic Plan',
      'description': 'Enhanced features for growing businesses'
    },
    {
      'id': 'premium',
      'name': 'Premium Plan',
      'description': 'Full features for established businesses'
    },
    {
      'id': 'enterprise',
      'name': 'Enterprise Plan',
      'description': 'Custom solutions for large organizations'
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vatNumberController.dispose();
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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateVatNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // VAT number is optional
    }

    // Basic VAT number validation based on country
    final vat = value.trim().toUpperCase();
    switch (_selectedCountry) {
      case 'Ireland':
        if (!RegExp(r'^IE[0-9]{7}[A-Z]{1,2}$').hasMatch(vat)) {
          return 'Irish VAT format: IE1234567T or IE1234567TW';
        }
        break;
      case 'United Kingdom':
        if (!RegExp(r'^GB[0-9]{9}$|^GB[0-9]{12}$').hasMatch(vat)) {
          return 'UK VAT format: GB123456789 or GB123456789123';
        }
        break;
      case 'Germany':
        if (!RegExp(r'^DE[0-9]{9}$').hasMatch(vat)) {
          return 'German VAT format: DE123456789';
        }
        break;
      case 'France':
        if (!RegExp(r'^FR[A-Z0-9]{2}[0-9]{9}$').hasMatch(vat)) {
          return 'French VAT format: FRXX123456789';
        }
        break;
      default:
        // Basic check for other countries - at least 5 characters
        if (vat.length < 5) {
          return 'VAT number must be at least 5 characters';
        }
    }
    return null;
  }

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final companyData = {
        'name': _nameController.text.trim(),
        'owner_email': _ownerEmailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'country': _selectedCountry,
        'currency': _selectedCurrency,
        'vat_number': _vatNumberController.text.trim().isEmpty
            ? null
            : _vatNumberController.text.trim(),
        'subscription_plan': _selectedSubscriptionPlan,
        'is_demo': false,
        'status': 'active',
      };

      print('🏢 Creating company: $companyData');

      final result = await ApiService.createCompany(companyData);

      print('✅ Company created successfully: $result');

      // Create Company object from result
      final newCompany = Company(
        id: result['id'].toString(),
        name: result['name'] ?? companyData['name']!,
        address: result['address'] ?? companyData['address']!,
        phone: result['phone'] ?? companyData['phone']!,
        email: result['email'] ?? '',
        ownerEmail: result['owner_email'] ?? companyData['owner_email']!,
        createdAt: DateTime.parse(
            result['created_at'] ?? DateTime.now().toIso8601String()),
        isDemo: result['is_demo'] ?? false,
        country: result['country'] ?? companyData['country']!,
        currency: result['currency'] ?? companyData['currency']!,
        vatNumber: result['vat_number'],
      );

      if (mounted) {
        Navigator.of(context).pop(newCompany);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to create company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create company: $e'),
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
                  'Create New Company',
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
                          hintText: 'Enter your company name',
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Company name is required';
                          }
                          if (value!.trim().length < 2) {
                            return 'Company name must be at least 2 characters';
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
                          hintText: 'Enter owner email address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: 'Enter company phone number',
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
                          hintText: 'Enter complete business address',
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
                          labelText: 'VAT Registration Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long),
                          hintText: 'Enter VAT number (optional)',
                        ),
                        validator: _validateVatNumber,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 24),

                      // Subscription Information Section
                      _buildSectionHeader('Subscription Plan'),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(plan['name']!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  plan['description']!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubscriptionPlan = value!;
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
                  onPressed: _isLoading ? null : _createCompany,
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
                      : const Text('Create Company'),
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
