// lib/pages/expenses_page.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<dynamic> expenses = [];
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      loadExpenses(user!.uid);
    }
  }

  Future<void> loadExpenses(String userId) async {
    try {
      final data = await ApiService.getExpenses(userId);
      setState(() {
        expenses = data;
      });
    } catch (e) {
      print('Error loading expenses: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: expenses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.money_off),
                    title: Text('Category: ${expense['category']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${expense['expense_date']}'),
                        Text('Amount: €${expense['amount']}'),
                        Text('VAT: €${expense['vat_amount']}'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
