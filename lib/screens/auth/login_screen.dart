import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../context/simple_company_context.dart';
import '../../models/company.dart';
import '../../services/database_service.dart' as db_service;
import '../main/main_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // For web, use Firebase Auth's built-in Google provider
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Add scopes if needed
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Force account selection by adding prompt parameter
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      // Use signInWithPopup for web
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      print('Error signing in with Google: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: $e')),
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

  Future<void> _chooseDifferentAccount() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Sign out first to clear current session
      await FirebaseAuth.instance.signOut();

      // Small delay to ensure signout is complete
      await Future.delayed(const Duration(milliseconds: 500));

      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Force account selection
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      print('Error choosing different account: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch account: $e')),
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

  Future<void> _signInWithDemoCompany() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Set up demo company context without requiring Firebase authentication
      final demoCompany = Company(
        id: 'demo-company-1',
        name: 'Demo Company',
        address: '123 Demo Street, Demo City, DC 12345',
        phone: '+1 (555) 123-4567',
        email: 'demo@pscaccounting.com',
        ownerEmail: 'demo@example.com',
        createdAt: DateTime.now(),
        isDemo: true,
        country: 'United States',
        currency: 'USD',
        vatNumber: 'DEMO123456789',
      );
      
      SimpleCompanyContext.setSelectedCompany(demoCompany);
      
      // Also set the database service context for demo mode
      final dbService = db_service.DatabaseService();
      dbService.setCompanyContext(demoCompany.id, isDemoMode: true);

      // Small delay to show loading state
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        // Show welcome message and trigger navigation to main app
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Demo Mode! Exploring with sample data.'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Use a small delay to let the context update, then trigger auth state update
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Force a rebuild of the entire app by triggering a state change
        // This is a workaround to make the AuthWrapper rebuild
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainHomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error signing in with demo company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to access demo mode: $e')),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlue],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'PSC Accounting',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your business finances',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 64,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(_isLoading
                                  ? 'Signing in...'
                                  : 'Sign in with Google'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed:
                                _isLoading ? null : _chooseDifferentAccount,
                            child: const Text('Choose Different Account'),
                          ),
                          const SizedBox(height: 20),
                          // Demo Company Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Demo Company Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _signInWithDemoCompany,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.preview, color: Colors.white),
                              label: Text(
                                _isLoading 
                                    ? 'Entering Demo...' 
                                    : 'Try Demo Mode',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Explore with sample data - no account required',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Having trouble switching accounts?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Copyright Footer
                  Text(
                    '© ${DateTime.now().year} Siarhei Staravoitau. All rights reserved.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
