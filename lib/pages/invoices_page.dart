import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  List<dynamic> invoices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      loadInvoices(user.uid);
    } else {
      print("User not logged in");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadInvoices(String userId) async {
    print('Loading invoices for userId: $userId');
    try {
      final data = await ApiService.getInvoices(userId);
      print('Received ${data.length} invoices from API');
      setState(() {
        invoices = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading invoices: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : invoices.isEmpty
              ? const Center(
                  child: Text(
                    'No invoices found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text('Client: ${invoice['client_name']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${invoice['date']}'),
                            Text('Amount: \$${invoice['amount']}'),
                            Text('Status: ${invoice['status']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// // lib/pages/invoices_page.dart
// import 'package:flutter/material.dart';
// import '../services/api_service.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class InvoicesPage extends StatefulWidget {
//   const InvoicesPage({super.key});

//   @override
//   State<InvoicesPage> createState() => _InvoicesPageState();
// }

// class _InvoicesPageState extends State<InvoicesPage> {
//   List<dynamic> invoices = [];
//   final user = FirebaseAuth.instance.currentUser;

//   @override
//   void initState() {
//     super.initState();
//     if (user != null) {
//       loadInvoices(user!.uid);
//     }
//   }

//   Future<void> loadInvoices(String userId) async {
//     try {
//       final data = await ApiService.getInvoices(userId);
//       setState(() {
//         invoices = data;
//       });
//     } catch (e) {
//       print('Error loading invoices: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Invoices')),
//       body: invoices.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: invoices.length,
//               itemBuilder: (context, index) {
//                 final invoice = invoices[index];
//                 return Card(
//                   margin:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   child: ListTile(
//                     leading: const Icon(Icons.receipt_long),
//                     title: Text('Client: ${invoice['client_name']}'),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Issue Date: ${invoice['issue_date']}'),
//                         Text('Total: €${invoice['total']}'),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }
