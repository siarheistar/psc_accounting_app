import 'package:flutter/foundation.dart';

/// Centralized API configuration.
///
/// Use --dart-define=API_BASE_URL=https://your-backend.example.com when building
/// for production. Defaults to localhost for development (web/mobile).
class ApiConfig {
  // Build-time override. Example:
  // flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;

    // Development defaults
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else {
      // Android emulator loopback
      return 'http://10.0.2.2:8000';
    }
  }
}
