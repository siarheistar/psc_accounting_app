import 'package:flutter/foundation.dart';

// Invoice model
class Invoice {
  final String id;
  final String invoiceNumber;
  final String clientName;
  final double amount; // Legacy field - now contains gross amount
  final DateTime? date;
  final DateTime dueDate;
  final String status;
  final DateTime createdAt;
  final String? description;
  final String? clientId;
  // VAT-related fields matching database schema
  final int? vatRateId;
  final double? netAmount;
  final double? vatAmount;
  final double? grossAmount;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.amount,
    this.date,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.description,
    this.clientId,
    this.vatRateId,
    this.netAmount,
    this.vatAmount,
    this.grossAmount,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    try {
      return Invoice(
        id: json['id']?.toString() ?? '0',
        invoiceNumber: json['invoice_number']?.toString() ??
            'INV-${json['id'] ?? 'UNKNOWN'}',
        clientName: json['client_name']?.toString() ?? 'Unknown Client',
        // For legacy compatibility, use gross_amount or fallback to amount
        amount: double.tryParse(json['gross_amount']?.toString() ??
                json['amount']?.toString() ??
                '0') ??
            0.0,
        date: json['date'] != null || json['issue_date'] != null
            ? DateTime.parse(json['date'] ?? json['issue_date'])
            : DateTime.now(),
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'])
            : DateTime.now().add(const Duration(days: 30)),
        status: json['status']?.toString() ?? 'pending',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        description: json['description']?.toString(),
        clientId: json['client_id']?.toString(),
        // VAT-related fields - support both camelCase (API) and snake_case (legacy)
        vatRateId: json['vatRateId'] != null
            ? int.tryParse(json['vatRateId'].toString())
            : (json['vat_rate_id'] != null
                ? int.tryParse(json['vat_rate_id'].toString())
                : null),
        netAmount: json['netAmount'] != null
            ? double.tryParse(json['netAmount'].toString())
            : (json['net_amount'] != null
                ? double.tryParse(json['net_amount'].toString())
                : null),
        vatAmount: json['vatAmount'] != null
            ? double.tryParse(json['vatAmount'].toString())
            : (json['vat_amount'] != null
                ? double.tryParse(json['vat_amount'].toString())
                : null),
        grossAmount: json['grossAmount'] != null
            ? double.tryParse(json['grossAmount'].toString())
            : (json['gross_amount'] != null
                ? double.tryParse(json['gross_amount'].toString())
                : null),
      );
    } catch (e) {
      debugPrint('📄 Invoice.fromJson ERROR: $e');
      debugPrint('📄 Problematic JSON: $json');
      // Return a safe default invoice
      return Invoice(
        id: json['id']?.toString() ?? '0',
        invoiceNumber: 'INV-ERROR-${DateTime.now().millisecondsSinceEpoch}',
        clientName: 'Error Loading Client',
        amount: 0.0,
        date: DateTime.now(),
        dueDate: DateTime.now(),
        status: 'error',
        createdAt: DateTime.now(),
        description: 'Failed to parse invoice data',
        clientId: null,
        vatRateId: null,
        netAmount: null,
        vatAmount: null,
        grossAmount: null,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'client_name': clientName,
      'amount': amount, // Legacy field for compatibility
      'date': (date ?? createdAt).toIso8601String(),
      'issue_date': (date ?? createdAt).toIso8601String(), // For new schema
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'description': description,
      'client_id': clientId,
      // VAT-related fields
      'vat_rate_id': vatRateId,
      'net_amount': netAmount,
      'vat_amount': vatAmount,
      'gross_amount': grossAmount,
    };
  }
}

// Expense model
class Expense {
  final String id;
  final DateTime date;
  final String description;
  final String category;
  final double amount;
  final String status;
  final String? receipt;
  final String? notes;
  final double? vatRate; // Legacy field for backward compatibility
  final int? vatRateId; // New VAT rate ID field
  final double? vatAmount;
  final double? grossAmount;
  final double? netAmount;
  final DateTime? createdAt;

  Expense({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.status,
    this.receipt,
    this.notes,
    this.vatRate,
    this.vatRateId,
    this.vatAmount,
    this.grossAmount,
    this.netAmount,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'].toString(),
      // Use actual database field names
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      // Use actual database field name
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      // Set a default status since API doesn't provide it
      status: 'recorded',
      receipt: json['receipt'],
      notes: json['notes'],
      vatRate: json['vat_rate'] != null
          ? double.tryParse(json['vat_rate'].toString())
          : null,
      vatRateId: json['vat_rate_id'] != null
          ? int.tryParse(json['vat_rate_id'].toString())
          : null,
      vatAmount: json['vat_amount'] != null
          ? double.tryParse(json['vat_amount'].toString())
          : null,
      grossAmount: json['gross_amount'] != null
          ? double.tryParse(json['gross_amount'].toString())
          : null,
      netAmount: json['net_amount'] != null
          ? double.tryParse(json['net_amount'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
      'category': category,
      'amount': amount,
      'status': status,
      'receipt': receipt,
      'notes': notes,
      'vat_rate': vatRate,
      'vat_rate_id': vatRateId,
      'vat_amount': vatAmount,
      'gross_amount': grossAmount,
      'net_amount': netAmount,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

// PayrollEntry model
class PayrollEntry {
  final String id;
  final String period;
  final String employeeName;
  final double grossPay;
  final double deductions;
  final double netPay;
  final DateTime? payDate;
  final String? employeeId;

  PayrollEntry({
    required this.id,
    required this.period,
    required this.employeeName,
    required this.grossPay,
    required this.deductions,
    required this.netPay,
    this.payDate,
    this.employeeId,
  });

  factory PayrollEntry.fromJson(Map<String, dynamic> json) {
    return PayrollEntry(
      id: json['id'].toString(),
      period: json['period'] ?? '',
      employeeName: json['employee_name'] ?? '',
      grossPay: double.tryParse(json['gross_pay'].toString()) ?? 0.0,
      deductions: double.tryParse(json['deductions'].toString()) ?? 0.0,
      netPay: double.tryParse(json['net_pay'].toString()) ?? 0.0,
      payDate:
          json['pay_date'] != null ? DateTime.parse(json['pay_date']) : null,
      employeeId: json['employee_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period': period,
      'employee_name': employeeName,
      'gross_pay': grossPay,
      'deductions': deductions,
      'net_pay': netPay,
      'pay_date': payDate?.toIso8601String(),
      'employee_id': employeeId,
    };
  }
}

// Employee model
class Employee {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final String? position;
  final String? department;
  final double? baseSalary;
  final DateTime? hireDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Employee({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.position,
    this.department,
    this.baseSalary,
    this.hireDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      email: json['email'],
      phoneNumber: json['phone_number'],
      position: json['position'],
      department: json['department'],
      baseSalary: json['base_salary'] != null
          ? double.tryParse(json['base_salary'].toString())
          : null,
      hireDate:
          json['hire_date'] != null ? DateTime.parse(json['hire_date']) : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'position': position,
      'department': department,
      'base_salary': baseSalary,
      'hire_date': hireDate?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// BankStatement model
class BankStatement {
  final String id;
  final DateTime transactionDate;
  final String description;
  final String transactionType;
  final double amount;
  final double balance;
  final String? reference;
  final bool? reconciled;

  BankStatement({
    required this.id,
    required this.transactionDate,
    required this.description,
    required this.transactionType,
    required this.amount,
    required this.balance,
    this.reference,
    this.reconciled,
  });

  factory BankStatement.fromJson(Map<String, dynamic> json) {
    return BankStatement(
      id: json['id'].toString(),
      transactionDate: DateTime.parse(json['transaction_date']),
      description: json['description'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      balance: double.tryParse(json['balance'].toString()) ?? 0.0,
      reference: json['reference'],
      reconciled: json['reconciled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_date': transactionDate.toIso8601String(),
      'description': description,
      'transaction_type': transactionType,
      'amount': amount,
      'balance': balance,
      'reference': reference,
      'reconciled': reconciled,
    };
  }
}

// Company model
class Company {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    required this.createdAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Attachment model
class Attachment {
  final String id;
  final String filename;
  final String fileType;
  final String fileData; // Base64 encoded
  final DateTime uploadedAt;
  final String? relatedType; // 'invoice', 'expense', etc.
  final String? relatedId;

  Attachment({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.fileData,
    required this.uploadedAt,
    this.relatedType,
    this.relatedId,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'].toString(),
      filename: json['filename'] ?? '',
      fileType: json['file_type'] ?? '',
      fileData: json['file_data'] ?? '',
      uploadedAt: DateTime.parse(json['uploaded_at']),
      relatedType: json['related_type'],
      relatedId: json['related_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'file_type': fileType,
      'file_data': fileData,
      'uploaded_at': uploadedAt.toIso8601String(),
      'related_type': relatedType,
      'related_id': relatedId,
    };
  }
}

// User model
class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? role;
  final DateTime createdAt;
  final bool isActive;

  AppUser({
    required this.id,
    required this.email,
    this.name,
    this.role,
    required this.createdAt,
    this.isActive = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      email: json['email'] ?? '',
      name: json['name'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}

// Reconciliation model
class Reconciliation {
  final String id;
  final String bankStatementId;
  final String? invoiceId;
  final String? expenseId;
  final DateTime reconciledAt;
  final String reconciledBy;
  final String? notes;

  Reconciliation({
    required this.id,
    required this.bankStatementId,
    this.invoiceId,
    this.expenseId,
    required this.reconciledAt,
    required this.reconciledBy,
    this.notes,
  });

  factory Reconciliation.fromJson(Map<String, dynamic> json) {
    return Reconciliation(
      id: json['id'].toString(),
      bankStatementId: json['bank_statement_id'].toString(),
      invoiceId: json['invoice_id']?.toString(),
      expenseId: json['expense_id']?.toString(),
      reconciledAt: DateTime.parse(json['reconciled_at']),
      reconciledBy: json['reconciled_by'] ?? '',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_statement_id': bankStatementId,
      'invoice_id': invoiceId,
      'expense_id': expenseId,
      'reconciled_at': reconciledAt.toIso8601String(),
      'reconciled_by': reconciledBy,
      'notes': notes,
    };
  }
}

// VAT Return model
class VatReturn {
  final String id;
  final String period;
  final double vatOwed;
  final double vatReclaimed;
  final double netVat;
  final String status;
  final DateTime? submittedAt;
  final DateTime createdAt;

  VatReturn({
    required this.id,
    required this.period,
    required this.vatOwed,
    required this.vatReclaimed,
    required this.netVat,
    required this.status,
    this.submittedAt,
    required this.createdAt,
  });

  factory VatReturn.fromJson(Map<String, dynamic> json) {
    return VatReturn(
      id: json['id'].toString(),
      period: json['period'] ?? '',
      vatOwed: double.tryParse(json['vat_owed'].toString()) ?? 0.0,
      vatReclaimed: double.tryParse(json['vat_reclaimed'].toString()) ?? 0.0,
      netVat: double.tryParse(json['net_vat'].toString()) ?? 0.0,
      status: json['status'] ?? '',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period': period,
      'vat_owed': vatOwed,
      'vat_reclaimed': vatReclaimed,
      'net_vat': netVat,
      'status': status,
      'submitted_at': submittedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
