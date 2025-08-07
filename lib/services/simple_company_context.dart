import 'package:flutter/foundation.dart';

class SimpleCompanyContext {
  static final SimpleCompanyContext _instance =
      SimpleCompanyContext._internal();
  factory SimpleCompanyContext() => _instance;
  SimpleCompanyContext._internal();

  String? _companyId;
  String? _companyName;
  String? _companyType; // 'demo', 'created', 'joined'
  bool _isInitialized = false;

  bool get hasCompanyContext => _isInitialized && _companyId != null;
  bool get isDemoMode => _companyType == 'demo';
  String? get companyId => _companyId;
  String? get companyName => _companyName;
  String? get companyType => _companyType;

  void setCompanyContext({
    required String companyId,
    required String companyName,
    required String companyType,
  }) {
    _companyId = companyId;
    _companyName = companyName;
    _companyType = companyType;
    _isInitialized = true;

    if (kDebugMode) {
      print('🏢 Company context set: $companyName ($companyType)');
    }
  }

  void clearCompanyContext() {
    _companyId = null;
    _companyName = null;
    _companyType = null;
    _isInitialized = false;

    if (kDebugMode) {
      print('🏢 Company context cleared');
    }
  }
}
