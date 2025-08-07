import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../screens/main/main_home_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> signInWithGoogle(BuildContext context,
      {bool forceAccountSelection = true}) async {
    try {
      if (kIsWeb) {
        // 🌐 Web Sign-in with FORCED account selection
        final googleProvider = GoogleAuthProvider();

        if (forceAccountSelection) {
          // These parameters force Google to show account selection
          googleProvider.setCustomParameters({
            'prompt': 'select_account', // Forces account selection screen
            'login_hint': '', // Clear any login hints
          });
        }

        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // 📱 Mobile Sign-in with forced account selection
        GoogleSignIn googleSignIn;

        if (forceAccountSelection) {
          // Create a new GoogleSignIn instance to ensure clean state
          googleSignIn = GoogleSignIn(
            // Clear any cached account selection
            forceCodeForRefreshToken: true,
          );

          // Ensure we're completely signed out first
          if (await googleSignIn.isSignedIn()) {
            await googleSignIn.disconnect();
            await googleSignIn.signOut();
          }
        } else {
          googleSignIn = GoogleSignIn();
        }

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled the sign-in
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled')),
          );
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // ✅ Success - Navigate to home screen
      final user = FirebaseAuth.instance.currentUser;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as ${user?.email}'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainHomeScreen()),
      );
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Alternative sign-in method for switching accounts
  Future<void> signInWithAccountSelection(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (kIsWeb) {
        // For web, redirect to Google with specific parameters
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'prompt':
              'select_account consent', // Forces both account selection and consent
          'access_type': 'offline',
          'include_granted_scopes': 'true',
        });

        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // For mobile, ensure complete logout first
        final googleSignIn = GoogleSignIn();

        // Force complete logout
        try {
          await googleSignIn.disconnect();
        } catch (e) {
          debugPrint('Disconnect error (expected): $e');
        }

        try {
          await googleSignIn.signOut();
        } catch (e) {
          debugPrint('SignOut error: $e');
        }

        // Small delay to ensure logout is processed
        await Future.delayed(const Duration(milliseconds: 500));

        // Now sign in fresh
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          Navigator.pop(context); // Hide loading
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // Hide loading
      Navigator.pop(context);

      // Navigate to home
      final user = FirebaseAuth.instance.currentUser;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as ${user?.email}'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainHomeScreen()),
      );
    } catch (e) {
      // Hide loading
      Navigator.pop(context);

      debugPrint('❌ Account Selection Sign-In Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or title
              Icon(
                Icons.account_circle,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),

              Text(
                'Welcome',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),

              Text(
                'Sign in to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 48),

              // Regular sign in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      signInWithGoogle(context, forceAccountSelection: false),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sign in with account selection (for switching accounts)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => signInWithAccountSelection(context),
                  icon: const Icon(Icons.switch_account),
                  label: const Text('Choose Different Account'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Help text
              Text(
                'Having trouble switching accounts?\nTry "Choose Different Account" button',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
