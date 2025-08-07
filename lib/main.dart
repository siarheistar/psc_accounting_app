import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/company/company_selection_screen.dart';
import 'screens/main/main_home_screen.dart';
import 'models/company.dart';
import 'context/simple_company_context.dart';
import 'services/navigation_manager.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSC Accounting',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is logged in, show company selection
          return const CompanyContextWrapper();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}

class CompanyContextWrapper extends StatefulWidget {
  const CompanyContextWrapper({super.key});

  @override
  State<CompanyContextWrapper> createState() => _CompanyContextWrapperState();
}

class _CompanyContextWrapperState extends State<CompanyContextWrapper> {
  bool _showCompanySelection = true;
  bool _hasSelectedCompany = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCompanyState();
  }

  Future<void> _initializeCompanyState() async {
    print('🏢 CompanyContextWrapper: Initializing company state...');

    // Check browser storage for saved company
    final savedCompanyId = NavigationManager.getSelectedCompanyId();

    if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
      print(
          '🏢 Found saved company ID: $savedCompanyId, attempting to restore...');

      try {
        // Get current user email from Firebase Auth
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser?.email == null) {
          throw Exception('No authenticated user found');
        }

        // Try to load the company from backend
        final companies = await ApiService.getCompanies(currentUser!.email!);

        final savedCompanyMap = companies.firstWhere(
          (company) => company['id'].toString() == savedCompanyId,
          orElse: () => throw Exception('Company not found'),
        );

        // Convert map to Company object using fromJson
        final savedCompany = Company.fromJson(savedCompanyMap);

        // Restore company to context
        SimpleCompanyContext.setSelectedCompany(savedCompany);
        print('🏢 Successfully restored company: ${savedCompany.name}');

        setState(() {
          _showCompanySelection = false;
          _hasSelectedCompany = true;
          _isInitializing = false;
        });
      } catch (e) {
        print('🏢 Error restoring saved company: $e');
        // Clear invalid saved company ID
        NavigationManager.clearNavigationState();

        setState(() {
          _showCompanySelection = true;
          _hasSelectedCompany = false;
          _isInitializing = false;
        });
      }
    } else {
      print('🏢 No saved company found, showing company selection');
      setState(() {
        _showCompanySelection = true;
        _hasSelectedCompany = false;
        _isInitializing = false;
      });
    }
  }

  void _onCompanySelected(Company company) {
    print('🏢 Company selected: ${company.name}! Navigating to HomePage...');
    SimpleCompanyContext.setSelectedCompany(company);
    setState(() {
      _showCompanySelection = false;
      _hasSelectedCompany = true;
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading company...'),
            ],
          ),
        ),
      );
    }

    // Check current state each time build is called
    final hasCompany = SimpleCompanyContext.hasSelectedCompany;

    print(
        '🏢 CompanyContextWrapper build - hasCompany: $hasCompany, showCompanySelection: $_showCompanySelection, hasSelectedCompany: $_hasSelectedCompany');

    if (!hasCompany) {
      print('🏢 No company in context, showing CompanySelectionScreen');
      return CompanySelectionScreen(
        onCompanySelected: _onCompanySelected,
      );
    }

    print('🏢 Company exists in context, showing MainHomeScreen');
    return const MainHomeScreen();
  }
}

// // main.dart
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'auth/auth_gate.dart';
// import 'pages/invoices_page.dart';
// import '../pages/expenses_page.dart';
// import '../pages/payslips_page.dart';
// // import 'pages/reports_page.dart'; // Removed because the file does not exist
// import 'firebase_options.dart';


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   runApp(const MyApp());
// }
// // void main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //   await Firebase.initializeApp(
// //     options: DefaultFirebaseOptions.currentPlatform,
// //   );
// //   runApp(const MyApp());
// // }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'PSC Accounting App',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const AuthGate(),
//     );
//   }
// }