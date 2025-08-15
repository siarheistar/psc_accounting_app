import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/simple_company_context.dart';
import '../widgets/copyright_footer.dart';

class SimpleCompanySelectionPage extends StatefulWidget {
  final VoidCallback onCompanySelected;

  const SimpleCompanySelectionPage({
    super.key,
    required this.onCompanySelected,
  });

  @override
  State<SimpleCompanySelectionPage> createState() =>
      _SimpleCompanySelectionPageState();
}

class _SimpleCompanySelectionPageState
    extends State<SimpleCompanySelectionPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Company'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.displayName ?? user?.email ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Select or create a company to continue',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),

            // Demo Company Option
            Card(
              child: ListTile(
                leading: const Icon(Icons.business, color: Colors.blue),
                title: const Text('Demo Company'),
                subtitle: const Text('Try the app with sample data'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _isLoading ? null : () => _selectDemoCompany(),
              ),
            ),
            const SizedBox(height: 16),

            // Create New Company Option
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_business, color: Colors.green),
                title: const Text('Create New Company'),
                subtitle: const Text('Set up your company profile'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _isLoading ? null : () => _createNewCompany(),
              ),
            ),
            const SizedBox(height: 16),

            // Join Existing Company Option
            Card(
              child: ListTile(
                leading: const Icon(Icons.group_add, color: Colors.orange),
                title: const Text('Join Existing Company'),
                subtitle: const Text('Use an invitation code'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _isLoading ? null : () => _joinExistingCompany(),
              ),
            ),

            const Spacer(),

            // Copyright footer
            const CopyrightFooter(),

            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  void _selectDemoCompany() {
    setState(() {
      _isLoading = true;
    });

    // Simulate some loading time
    Future.delayed(const Duration(seconds: 1), () {
      // Set up demo company context
      SimpleCompanyContext().setCompanyContext(
        companyId: 'demo-company-1',
        companyName: 'Demo Company',
        companyType: 'demo',
      );

      widget.onCompanySelected();
    });
  }

  void _createNewCompany() {
    _showCreateCompanyDialog();
  }

  void _joinExistingCompany() {
    _showJoinCompanyDialog();
  }

  void _showCreateCompanyDialog() {
    final TextEditingController companyNameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                hintText: 'Enter your company name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Company Email',
                hintText: 'Enter company email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (companyNameController.text.isNotEmpty) {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });

                // Simulate company creation
                Future.delayed(const Duration(seconds: 2), () {
                  // Set up created company context
                  SimpleCompanyContext().setCompanyContext(
                    companyId:
                        'created-${DateTime.now().millisecondsSinceEpoch}',
                    companyName: companyNameController.text,
                    companyType: 'created',
                  );

                  widget.onCompanySelected();
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinCompanyDialog() {
    final TextEditingController inviteCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Existing Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invitation Code',
                hintText: 'Enter the invitation code',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask your company administrator for the invitation code.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (inviteCodeController.text.isNotEmpty) {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });

                // Simulate joining company
                Future.delayed(const Duration(seconds: 2), () {
                  // Set up joined company context
                  SimpleCompanyContext().setCompanyContext(
                    companyId: 'joined-${inviteCodeController.text}',
                    companyName: 'Joined Company',
                    companyType: 'joined',
                  );

                  widget.onCompanySelected();
                });
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
