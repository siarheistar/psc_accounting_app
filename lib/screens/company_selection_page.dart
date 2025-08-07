import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../screens/main/main_home_screen.dart';
import 'company_creation_page.dart';

class CompanySelectionPage extends StatefulWidget {
  final VoidCallback? onCompanySelected;

  const CompanySelectionPage({
    super.key,
    this.onCompanySelected,
  });

  @override
  State<CompanySelectionPage> createState() => _CompanySelectionPageState();
}

class _CompanySelectionPageState extends State<CompanySelectionPage> {
  final DatabaseService _dbService = DatabaseService();
  List<UserCompanyAccess> _companies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserCompanies();
  }

  Future<void> _loadUserCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final companies = await _dbService.getUserCompanies();
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectCompany(UserCompanyAccess company) {
    // Set the company context
    _dbService.setCompanyContext(
      company.companyId.toString(),
      isDemoMode: company.isDemo,
    );

    // Navigate to home or call callback
    if (widget.onCompanySelected != null) {
      widget.onCompanySelected!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainHomeScreen()),
      );
    }
  }

  void _startDemo() {
    // Set demo mode
    _dbService.setCompanyContext(null, isDemoMode: true);

    // Navigate to home or call callback
    if (widget.onCompanySelected != null) {
      widget.onCompanySelected!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainHomeScreen()),
      );
    }
  }

  void _createNewCompany() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompanyCreationScreen(),
      ),
    );

    if (result == true) {
      // Company was created, reload the list
      _loadUserCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Icon(
                Icons.account_balance,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Welcome to PSC Accounting',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // User greeting
              Text(
                'Hello, ${user?.displayName ?? user?.email ?? 'User'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Content
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_errorMessage != null)
                _buildErrorWidget()
              else if (_companies.isEmpty)
                _buildNoCompaniesWidget()
              else
                _buildCompanyList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red[400],
        ),
        const SizedBox(height: 16),
        Text(
          'Failed to load companies',
          style: TextStyle(
            fontSize: 16,
            color: Colors.red[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loadUserCompanies,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildNoCompaniesWidget() {
    return Column(
      children: [
        Icon(
          Icons.business_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        const Text(
          'No companies found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get started by creating your first company or exploring with demo data',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),

        // Create company button
        ElevatedButton.icon(
          onPressed: _createNewCompany,
          icon: const Icon(Icons.add),
          label: const Text('Create New Company'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Demo button
        OutlinedButton.icon(
          onPressed: _startDemo,
          icon: const Icon(Icons.preview),
          label: const Text('Explore Demo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyList() {
    return Column(
      children: [
        const Text(
          'Select a company to continue',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),

        // Company list
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _companies.length,
            itemBuilder: (context, index) {
              final company = _companies[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      company.companyName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(company.companyName),
                  subtitle: Text('Role: ${company.role}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectCompany(company),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _createNewCompany,
              icon: const Icon(Icons.add),
              label: const Text('New Company'),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: _startDemo,
              icon: const Icon(Icons.preview),
              label: const Text('Demo Mode'),
            ),
          ],
        ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../services/database_service.dart';
// import 'company_creation_page.dart';
// import 'home_page.dart';

// class CompanySelectionPage extends StatefulWidget {
//   const CompanySelectionPage({super.key});

//   @override
//   State<CompanySelectionPage> createState() => _CompanySelectionPageState();
// }

// class _CompanySelectionPageState extends State<CompanySelectionPage> {
//   final DatabaseService _dbService = DatabaseService();
//   List<UserCompanyAccess> _companies = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   bool _isInitializing = false; // Prevent multiple initializations

//   @override
//   void initState() {
//     super.initState();
//     _initializeAndLoadCompanies();
//   }

//   Future<void> _initializeAndLoadCompanies() async {
//     // Prevent multiple simultaneous initializations
//     if (_isInitializing) {
//       debugPrint('⏳ Already initializing, skipping...');
//       return;
//     }

//     _isInitializing = true;

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       // Clear any existing context first
//       _dbService.clearContext();

//       // Initialize database service with current user
//       await _dbService.initializeWithCurrentUser();

//       // Load user's companies (don't auto-set demo mode here)
//       await _loadCompanies();
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to load companies: ${e.toString()}';
//         _isLoading = false;
//       });
//     } finally {
//       _isInitializing = false;
//     }
//   }

//   Future<void> _loadCompanies() async {
//     try {
//       final companies = await _dbService.getUserCompanies();
//       setState(() {
//         _companies = companies;
//         _isLoading = false;
//       });

//       // Debug output
//       debugPrint('📋 Loaded ${companies.length} companies for user');
//       for (var company in companies) {
//         debugPrint(
//             '   - ${company.companyName} (ID: ${company.companyId}, Demo: ${company.isDemo})');
//       }
//     } catch (e) {
//       debugPrint('❌ Error loading companies: $e');
//       setState(() {
//         _errorMessage = 'Failed to load companies: ${e.toString()}';
//         _isLoading = false;
//         // Don't set demo mode here - let user choose
//         _companies = [];
//       });
//     }
//   }

//   Future<void> _selectCompany(
//       int companyId, bool isDemoMode, String companyName) async {
//     try {
//       debugPrint('🏢 === SELECTING COMPANY ===');
//       debugPrint('🏢 Company ID: $companyId');
//       debugPrint('🏢 Company Name: $companyName');
//       debugPrint('🏢 Demo Mode: $isDemoMode');

//       // Set company context in database service
//       _dbService.setCompanyContext(companyId.toString(),
//           isDemoMode: isDemoMode);

//       debugPrint('🏢 Context set, navigating to dashboard...');

//       // Navigate to home page
//       if (mounted) {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (context) => const HomePage(),
//           ),
//         );
//       }
//     } catch (e) {
//       debugPrint('🏢 === SELECTION ERROR ===');
//       debugPrint('🏢 Exception: $e');
//       _showErrorSnackBar('Failed to select company: ${e.toString()}');
//     }
//   }

//   Future<void> _selectDemoMode() async {
//     try {
//       // Set demo mode context
//       _dbService.setCompanyContext('demo', isDemoMode: true);

//       // Navigate to home page
//       if (mounted) {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (context) => const HomePage(),
//           ),
//         );
//       }
//     } catch (e) {
//       _showErrorSnackBar('Failed to enter demo mode: ${e.toString()}');
//     }
//   }

//   Future<void> _navigateToCompanyCreation() async {
//     final result = await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) => const CompanyCreationScreen(),
//       ),
//     );

//     // If a company was created, the result should be the company object
//     if (result != null) {
//       try {
//         if (result is Map<String, dynamic>) {
//           // Company was created successfully
//           final companyData = result;
//           debugPrint('✅ Company created: ${companyData['name']}');

//           // Clear demo mode context
//           _dbService.clearContext();

//           // Re-initialize with current user
//           await _dbService.initializeWithCurrentUser();

//           // Set the new company as active
//           if (companyData['id'] != null) {
//             _dbService.setCompanyContext(companyData['id'].toString(),
//                 isDemoMode: false);

//             // Navigate to home page with the new company
//             if (mounted) {
//               Navigator.of(context).pushReplacement(
//                 MaterialPageRoute(
//                   builder: (context) => const HomePage(),
//                 ),
//               );
//             }
//             return;
//           }
//         } else if (result == true) {
//           // Fallback for old return value
//           debugPrint('✅ Company created (legacy return)');
//         }

//         // Fallback: reload companies and let user select
//         await _initializeAndLoadCompanies();
//       } catch (e) {
//         debugPrint('❌ Error handling company creation result: $e');
//         await _initializeAndLoadCompanies();
//       }
//     }
//   }

//   void _showErrorSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 4),
//         ),
//       );
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     }
//   }

//   Future<void> _signOut() async {
//     try {
//       // Clear database service context
//       _dbService.clearContext();

//       // Sign out from Firebase
//       await FirebaseAuth.instance.signOut();

//       if (mounted) {
//         // Navigate to login screen - adjust route as needed
//         Navigator.of(context).pushNamedAndRemoveUntil(
//           '/', // or '/auth' or whatever your login route is
//           (route) => false,
//         );
//       }
//     } catch (e) {
//       _showErrorSnackBar('Failed to sign out: ${e.toString()}');
//     }
//   }

//   Color _getRoleColor(String role) {
//     switch (role.toLowerCase()) {
//       case 'owner':
//         return const Color(0xFF10B981);
//       case 'admin':
//         return const Color(0xFF3B82F6);
//       case 'accountant':
//         return const Color(0xFF8B5CF6);
//       case 'viewer':
//         return const Color(0xFF64748B);
//       default:
//         return const Color(0xFF64748B);
//     }
//   }

//   String _getRoleDescription(String role) {
//     switch (role.toLowerCase()) {
//       case 'owner':
//         return 'Full access to all features';
//       case 'admin':
//         return 'Manage users and settings';
//       case 'accountant':
//         return 'Manage financial data';
//       case 'viewer':
//         return 'View-only access';
//       default:
//         return 'Limited access';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: const Color(0xFF1E293B),
//         title: const Text(
//           'Select Company',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         actions: [
//           PopupMenuButton<String>(
//             onSelected: (value) {
//               if (value == 'signout') _signOut();
//             },
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   CircleAvatar(
//                     radius: 16,
//                     backgroundColor: const Color(0xFF3B82F6),
//                     child: user?.photoURL != null
//                         ? ClipOval(
//                             child: Image.network(
//                               user!.photoURL!,
//                               width: 32,
//                               height: 32,
//                               fit: BoxFit.cover,
//                               errorBuilder: (context, error, stackTrace) {
//                                 return Text(
//                                   user.displayName
//                                           ?.substring(0, 1)
//                                           .toUpperCase() ??
//                                       'U',
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                     fontSize: 12,
//                                   ),
//                                 );
//                               },
//                             ),
//                           )
//                         : Text(
//                             user?.displayName?.substring(0, 1).toUpperCase() ??
//                                 'U',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                   ),
//                   const Icon(Icons.arrow_drop_down, size: 20),
//                 ],
//               ),
//             ),
//             itemBuilder: (context) => [
//               const PopupMenuItem(
//                 value: 'signout',
//                 child: Row(
//                   children: [
//                     Icon(Icons.logout, size: 16),
//                     SizedBox(width: 8),
//                     Text('Sign Out'),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _errorMessage != null
//               ? _buildErrorView()
//               : _buildCompanySelection(),
//     );
//   }

//   Widget _buildErrorView() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(
//               Icons.error_outline,
//               size: 64,
//               color: Colors.red,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Oops! Something went wrong',
//               style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                     fontWeight: FontWeight.bold,
//                     color: const Color(0xFF1E293B),
//                   ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               _errorMessage!,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 color: Color(0xFF64748B),
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 24),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _initializeAndLoadCompanies,
//                   icon: const Icon(Icons.refresh),
//                   label: const Text('Try Again'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF3B82F6),
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 TextButton.icon(
//                   onPressed: _selectDemoMode,
//                   icon: const Icon(Icons.preview),
//                   label: const Text('Try Demo'),
//                   style: TextButton.styleFrom(
//                     foregroundColor: const Color(0xFF3B82F6),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCompanySelection() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Welcome section
//           _buildWelcomeSection(),
//           const SizedBox(height: 32),

//           // Demo option
//           _buildDemoSection(),
//           const SizedBox(height: 24),

//           // User's companies
//           if (_companies.isNotEmpty) ...[
//             _buildCompaniesSection(),
//             const SizedBox(height: 24),
//           ] else if (!_isLoading && _errorMessage == null) ...[
//             // Show "no companies" message when not loading and no error
//             _buildNoCompaniesMessage(),
//             const SizedBox(height: 24),
//           ],

//           // Create new company
//           _buildCreateCompanySection(),

//           // Debug section (remove in production)
//           const SizedBox(height: 24),
//           _buildDebugSection(),
//         ],
//       ),
//     );
//   }

//   Widget _buildWelcomeSection() {
//     final user = FirebaseAuth.instance.currentUser;

//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.account_balance,
//                 color: Colors.white,
//                 size: 32,
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'PSC Accounting',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       'Welcome back, ${user?.displayName?.split(' ').first ?? 'User'}!',
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'Select a company to manage its accounting data, or try our demo to explore the features.',
//             style: TextStyle(
//               color: Colors.white70,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDemoSection() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.all(20),
//         leading: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF59E0B).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: const Icon(
//             Icons.preview,
//             color: Color(0xFFF59E0B),
//             size: 24,
//           ),
//         ),
//         title: const Text(
//           'Try Demo Mode',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         ),
//         subtitle: const Padding(
//           padding: EdgeInsets.only(top: 4),
//           child: Text(
//             'Explore all features with sample data. Perfect for testing before setting up your company.',
//             style: TextStyle(
//               color: Color(0xFF64748B),
//               fontSize: 14,
//             ),
//           ),
//         ),
//         trailing: const Icon(
//           Icons.arrow_forward_ios,
//           size: 16,
//           color: Color(0xFF64748B),
//         ),
//         onTap: _selectDemoMode,
//       ),
//     );
//   }

//   Widget _buildCompaniesSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Your Companies',
//           style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: const Color(0xFF1E293B),
//               ),
//         ),
//         const SizedBox(height: 16),
//         ...(_companies.map((company) => _buildCompanyCard(company)).toList()),
//       ],
//     );
//   }

//   Widget _buildCompanyCard(UserCompanyAccess company) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.all(20),
//         leading: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: company.isDemo
//                 ? const Color(0xFFF59E0B).withOpacity(0.1)
//                 : const Color(0xFF3B82F6).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Icon(
//             company.isDemo ? Icons.preview : Icons.business,
//             color: company.isDemo
//                 ? const Color(0xFFF59E0B)
//                 : const Color(0xFF3B82F6),
//             size: 24,
//           ),
//         ),
//         title: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 company.companyName,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//             if (company.isDemo)
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF59E0B).withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Text(
//                   'DEMO',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFFF59E0B),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         subtitle: Padding(
//           padding: const EdgeInsets.only(top: 4),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: _getRoleColor(company.role).withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   company.role.toUpperCase(),
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: _getRoleColor(company.role),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   _getRoleDescription(company.role),
//                   style: const TextStyle(
//                     color: Color(0xFF64748B),
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         trailing: const Icon(
//           Icons.arrow_forward_ios,
//           size: 16,
//           color: Color(0xFF64748B),
//         ),
//         onTap: () => _selectCompany(
//           company.companyId,
//           company.isDemo,
//           company.companyName,
//         ),
//       ),
//     );
//   }

//   Widget _buildCreateCompanySection() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.all(20),
//         leading: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: const Color(0xFF10B981).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: const Icon(
//             Icons.add_business,
//             color: Color(0xFF10B981),
//             size: 24,
//           ),
//         ),
//         title: const Text(
//           'Create New Company',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         ),
//         subtitle: const Padding(
//           padding: EdgeInsets.only(top: 4),
//           child: Text(
//             'Set up a new company profile and start managing your accounting data.',
//             style: TextStyle(
//               color: Color(0xFF64748B),
//               fontSize: 14,
//             ),
//           ),
//         ),
//         trailing: const Icon(
//           Icons.arrow_forward_ios,
//           size: 16,
//           color: Color(0xFF64748B),
//         ),
//         onTap: _navigateToCompanyCreation,
//       ),
//     );
//   }

//   Widget _buildNoCompaniesMessage() {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.blue[50],
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blue[200]!),
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.business_outlined,
//             size: 48,
//             color: Colors.blue[400],
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'No Companies Found',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF1E293B),
//             ),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'You don\'t have access to any companies yet. Create your first company or try our demo mode to explore the features.',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Color(0xFF64748B),
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDebugSection() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.grey[100],
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey[300]!),
//       ),
//       child: Column(
//         children: [
//           ListTile(
//             contentPadding: const EdgeInsets.all(20),
//             leading: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.orange.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Icon(
//                 Icons.bug_report,
//                 color: Colors.orange,
//                 size: 24,
//               ),
//             ),
//             title: const Text(
//               'Debug: Test API Connection',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             subtitle: const Padding(
//               padding: EdgeInsets.only(top: 4),
//               child: Text(
//                 'Test backend connection and check for companies',
//                 style: TextStyle(
//                   color: Color(0xFF64748B),
//                   fontSize: 14,
//                 ),
//               ),
//             ),
//             trailing: const Icon(
//               Icons.arrow_forward_ios,
//               size: 16,
//               color: Color(0xFF64748B),
//             ),
//             onTap: () async {
//               try {
//                 _showSuccessSnackBar('Testing connection...');
//                 final testResult = await _dbService.testConnection();
//                 if (testResult) {
//                   _showSuccessSnackBar('✅ Backend connection successful!');
//                   // Force reload companies
//                   await _initializeAndLoadCompanies();
//                 } else {
//                   _showErrorSnackBar('❌ Backend connection failed');
//                 }
//               } catch (e) {
//                 _showErrorSnackBar('❌ Test failed: $e');
//               }
//             },
//           ),
//           const Divider(height: 1),
//           ListTile(
//             contentPadding: const EdgeInsets.all(20),
//             leading: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blue.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Icon(
//                 Icons.refresh,
//                 color: Colors.blue,
//                 size: 24,
//               ),
//             ),
//             title: const Text(
//               'Force Refresh Companies',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             trailing: const Icon(
//               Icons.arrow_forward_ios,
//               size: 16,
//               color: Color(0xFF64748B),
//             ),
//             onTap: () {
//               _initializeAndLoadCompanies();
//               _showSuccessSnackBar('Refreshing companies...');
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Remove this class definition since it already exists in database_service.dart
