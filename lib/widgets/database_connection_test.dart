import 'package:flutter/material.dart';
import '../services/database_service.dart';

class DatabaseConnectionTest extends StatefulWidget {
  const DatabaseConnectionTest({super.key});

  @override
  State<DatabaseConnectionTest> createState() => _DatabaseConnectionTestState();
}

class _DatabaseConnectionTestState extends State<DatabaseConnectionTest> {
  final DatabaseService _dbService = DatabaseService();
  bool? _isConnected;
  String _message = 'Testing connection...';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final connected = await _dbService.testConnection();
      setState(() {
        _isConnected = connected;
        _message = connected 
            ? '✅ Database connection successful!' 
            : '❌ Database connection failed';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _message = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Database Connection Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isConnected == null)
              const CircularProgressIndicator()
            else
              Icon(
                _isConnected! ? Icons.check_circle : Icons.error,
                size: 48,
                color: _isConnected! ? Colors.green : Colors.red,
              ),
            const SizedBox(height: 8),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isConnected == null 
                    ? null 
                    : (_isConnected! ? Colors.green : Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}