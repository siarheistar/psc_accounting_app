import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../models/company.dart';
import '../../context/simple_company_context.dart';

class CompanySelectionScreen extends StatefulWidget {
  final Function(Company) onCompanySelected;

  const CompanySelectionScreen({
    Key? key,
    required this.onCompanySelected,
  }) : super(key: key);

  @override
  State<CompanySelectionScreen> createState() => _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends State<CompanySelectionScreen> {
  List<Company> companies = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final companiesData = await ApiService.getCompanies(user.email!);
        final userCompanies =
            companiesData.map((data) => Company.fromJson(data)).toList();
        setState(() {
          companies = userCompanies;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'User not authenticated';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load companies: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _showCreateCompanyDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController vatController = TextEditingController();
    String selectedCountry = 'Ireland';
    String selectedCurrency = 'EUR';

    final result = await showDialog<Company>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Company'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company Name *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your company name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: vatController,
                      decoration: const InputDecoration(
                        labelText: 'VAT Number',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., IE1234567T (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCountry,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Ireland', child: Text('Ireland')),
                        DropdownMenuItem(
                            value: 'United Kingdom',
                            child: Text('United Kingdom')),
                        DropdownMenuItem(
                            value: 'United States',
                            child: Text('United States')),
                        DropdownMenuItem(
                            value: 'Germany', child: Text('Germany')),
                        DropdownMenuItem(
                            value: 'France', child: Text('France')),
                        DropdownMenuItem(
                            value: 'Netherlands', child: Text('Netherlands')),
                        DropdownMenuItem(
                            value: 'Belgium', child: Text('Belgium')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCountry = value!;
                          // Auto-update currency based on country
                          switch (value) {
                            case 'Ireland':
                            case 'Germany':
                            case 'France':
                            case 'Netherlands':
                            case 'Belgium':
                              selectedCurrency = 'EUR';
                              break;
                            case 'United Kingdom':
                              selectedCurrency = 'GBP';
                              break;
                            case 'United States':
                              selectedCurrency = 'USD';
                              break;
                            default:
                              selectedCurrency = 'EUR';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                        DropdownMenuItem(value: 'CHF', child: Text('CHF')),
                        DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                        DropdownMenuItem(value: 'AUD', child: Text('AUD')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCurrency = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Company name is required')),
                      );
                      return;
                    }

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        print(
                            '🏢 [CompanySelection] Creating company for user: ${user.email}');

                        final companyData = {
                          'name': nameController.text.trim(),
                          'owner_email': user.email!,
                          'country': selectedCountry,
                          'currency': selectedCurrency,
                        };

                        // Add VAT number if provided
                        if (vatController.text.trim().isNotEmpty) {
                          companyData['vat_number'] = vatController.text.trim();
                        }

                        print(
                            '📋 [CompanySelection] Company data prepared: $companyData');

                        final newCompanyData =
                            await ApiService.createCompany(companyData);

                        print(
                            '✅ [CompanySelection] Company created, received data: $newCompanyData');

                        final newCompany = Company.fromJson(newCompanyData);

                        print(
                            '🎉 [CompanySelection] Company object created: ${newCompany.toString()}');

                        Navigator.of(context).pop(newCompany);
                      } else {
                        print(
                            '❌ [CompanySelection] No authenticated user found');
                      }
                    } catch (e) {
                      print('💥 [CompanySelection] Error creating company: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create company: $e')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        companies.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Company'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigation will be handled by the auth stream in main.dart
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCompanies,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : companies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.business,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No companies found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first company to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showCreateCompanyDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Company'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Companies (${companies.length})',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              ElevatedButton.icon(
                                onPressed: _showCreateCompanyDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('New Company'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: companies.length,
                            itemBuilder: (context, index) {
                              final company = companies[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    child: Text(
                                      company.name.isNotEmpty
                                          ? company.name
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    company.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (company.address.isNotEmpty)
                                        Text(company.address),
                                      if (company.email.isNotEmpty)
                                        Text(
                                          company.email,
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    SimpleCompanyContext.setSelectedCompany(
                                        company);
                                    widget.onCompanySelected(company);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
