class VATRate {
  final int id;
  final String country;
  final String rateName;
  final double ratePercentage;
  final String? description;
  final bool isActive;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final DateTime? createdAt;

  VATRate({
    required this.id,
    required this.country,
    required this.rateName,
    required this.ratePercentage,
    this.description,
    this.isActive = true,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.createdAt,
  });

  factory VATRate.fromJson(Map<String, dynamic> json) {
    return VATRate(
      id: json['id'],
      country: json['country'],
      rateName: json['rate_name'],
      ratePercentage: _parseDouble(json['rate_percentage']),
      description: json['description'],
      isActive: json['is_active'] ?? true,
      effectiveFrom: DateTime.parse(json['effective_from']),
      effectiveUntil: json['effective_until'] != null
          ? DateTime.parse(json['effective_until'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    throw ArgumentError('Cannot parse $value as double');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country': country,
      'rate_name': rateName,
      'rate_percentage': ratePercentage,
      'description': description,
      'is_active': isActive,
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_until': effectiveUntil?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class ExpenseCategory {
  final int id;
  final String categoryName;
  final String categoryType;
  final int? defaultVatRateId;
  final bool supportsBusinessUsage;
  final double defaultBusinessUsage;
  final bool requiresReceipt;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;

  ExpenseCategory({
    required this.id,
    required this.categoryName,
    required this.categoryType,
    this.defaultVatRateId,
    this.supportsBusinessUsage = false,
    this.defaultBusinessUsage = 100.0,
    this.requiresReceipt = true,
    this.description,
    this.isActive = true,
    this.createdAt,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'],
      categoryName: json['category_name'],
      categoryType: json['category_type'],
      defaultVatRateId: json['default_vat_rate_id'],
      supportsBusinessUsage: json['supports_business_usage'] ?? false,
      defaultBusinessUsage:
          (json['default_business_usage'] as num?)?.toDouble() ?? 100.0,
      requiresReceipt: json['requires_receipt'] ?? true,
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': categoryName,
      'category_type': categoryType,
      'default_vat_rate_id': defaultVatRateId,
      'supports_business_usage': supportsBusinessUsage,
      'default_business_usage': defaultBusinessUsage,
      'requires_receipt': requiresReceipt,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class BusinessUsageOption {
  final int id;
  final double percentage;
  final String label;
  final String? description;
  final bool isDefault;

  BusinessUsageOption({
    required this.id,
    required this.percentage,
    required this.label,
    this.description,
    this.isDefault = false,
  });

  factory BusinessUsageOption.fromJson(Map<String, dynamic> json) {
    return BusinessUsageOption(
      id: json['id'],
      percentage: (json['percentage'] as num).toDouble(),
      label: json['label'],
      description: json['description'],
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'percentage': percentage,
      'label': label,
      'description': description,
      'is_default': isDefault,
    };
  }
}

class ExpenseCategoryData {
  final List<ExpenseCategory> categories;
  final List<VATRate> vatRates;
  final List<BusinessUsageOption> businessUsageOptions;

  ExpenseCategoryData({
    required this.categories,
    required this.vatRates,
    required this.businessUsageOptions,
  });

  factory ExpenseCategoryData.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryData(
      categories: (json['categories'] as List)
          .map((e) => ExpenseCategory.fromJson(e))
          .toList(),
      vatRates:
          (json['vat_rates'] as List).map((e) => VATRate.fromJson(e)).toList(),
      businessUsageOptions: (json['business_usage_options'] as List)
          .map((e) => BusinessUsageOption.fromJson(e))
          .toList(),
    );
  }
}

class VATCalculation {
  final double netAmount;
  final double vatRatePercentage;
  final double vatAmount;
  final double grossAmount;
  final double? deductibleAmount;
  final double? businessUsagePercentage;

  VATCalculation({
    required this.netAmount,
    required this.vatRatePercentage,
    required this.vatAmount,
    required this.grossAmount,
    this.deductibleAmount,
    this.businessUsagePercentage,
  });

  factory VATCalculation.fromJson(Map<String, dynamic> json) {
    return VATCalculation(
      netAmount: (json['net_amount'] as num).toDouble(),
      vatRatePercentage: (json['vat_rate_percentage'] as num).toDouble(),
      vatAmount: (json['vat_amount'] as num).toDouble(),
      grossAmount: (json['gross_amount'] as num).toDouble(),
      deductibleAmount: (json['deductible_amount'] as num?)?.toDouble(),
      businessUsagePercentage:
          (json['business_usage_percentage'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'net_amount': netAmount,
      'vat_rate_percentage': vatRatePercentage,
      'vat_amount': vatAmount,
      'gross_amount': grossAmount,
      'deductible_amount': deductibleAmount,
      'business_usage_percentage': businessUsagePercentage,
    };
  }
}

class EnhancedExpense {
  final String id;
  final String companyId;
  final DateTime expenseDate;
  final String description;
  final double netAmount;
  final double vatAmount;
  final double grossAmount;
  final String? supplierName;
  final double businessUsagePercentage;
  final double deductibleAmount;
  final String expenseType;
  final double? eworkerDays;
  final double? eworkerRate;
  final double? mileageKm;
  final double? mileageRate;
  final String? notes;
  final bool receiptRequired;
  final bool paid;
  final DateTime? createdAt;
  final String? categoryName;
  final String? vatRateName;
  final double? vatRatePercentage;

  EnhancedExpense({
    required this.id,
    required this.companyId,
    required this.expenseDate,
    required this.description,
    required this.netAmount,
    required this.vatAmount,
    required this.grossAmount,
    this.supplierName,
    this.businessUsagePercentage = 100.0,
    required this.deductibleAmount,
    this.expenseType = 'general',
    this.eworkerDays,
    this.eworkerRate,
    this.mileageKm,
    this.mileageRate,
    this.notes,
    this.receiptRequired = true,
    this.paid = false,
    this.createdAt,
    this.categoryName,
    this.vatRateName,
    this.vatRatePercentage,
  });

  factory EnhancedExpense.fromJson(Map<String, dynamic> json) {
    return EnhancedExpense(
      id: json['id'],
      companyId: json['company_id'],
      expenseDate: DateTime.parse(json['expense_date']),
      description: json['description'],
      netAmount: (json['net_amount'] as num).toDouble(),
      vatAmount: (json['vat_amount'] as num).toDouble(),
      grossAmount: (json['gross_amount'] as num).toDouble(),
      supplierName: json['supplier_name'],
      businessUsagePercentage:
          (json['business_usage_percentage'] as num?)?.toDouble() ?? 100.0,
      deductibleAmount: (json['deductible_amount'] as num).toDouble(),
      expenseType: json['expense_type'] ?? 'general',
      eworkerDays: (json['eworker_days'] as num?)?.toDouble(),
      eworkerRate: (json['eworker_rate'] as num?)?.toDouble(),
      mileageKm: (json['mileage_km'] as num?)?.toDouble(),
      mileageRate: (json['mileage_rate'] as num?)?.toDouble(),
      notes: json['notes'],
      receiptRequired: json['receipt_required'] ?? true,
      paid: json['paid'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      categoryName: json['category_name'],
      vatRateName: json['vat_rate_name'],
      vatRatePercentage: (json['vat_rate_percentage'] as num?)?.toDouble(),
    );
  }
}

class EWorkerPeriod {
  final String id;
  final String companyId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalDays;
  final double dailyRate;
  final double totalAmount;
  final String status;
  final DateTime? createdAt;

  EWorkerPeriod({
    required this.id,
    required this.companyId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalDays,
    required this.dailyRate,
    required this.totalAmount,
    this.status = 'draft',
    this.createdAt,
  });

  factory EWorkerPeriod.fromJson(Map<String, dynamic> json) {
    return EWorkerPeriod(
      id: json['id'],
      companyId: json['company_id'],
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
      totalDays: (json['total_days'] as num).toDouble(),
      dailyRate: (json['daily_rate'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class VATSummary {
  final String companyId;
  final String periodStart;
  final String periodEnd;
  final double totalSales;
  final double totalOutputVat;
  final double totalPurchases;
  final double totalInputVat;
  final double netVatDue;

  VATSummary({
    required this.companyId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalSales,
    required this.totalOutputVat,
    required this.totalPurchases,
    required this.totalInputVat,
    required this.netVatDue,
  });

  factory VATSummary.fromJson(Map<String, dynamic> json) {
    return VATSummary(
      companyId: json['company_id'],
      periodStart: json['period_start'],
      periodEnd: json['period_end'],
      totalSales: (json['total_sales'] as num).toDouble(),
      totalOutputVat: (json['total_output_vat'] as num).toDouble(),
      totalPurchases: (json['total_purchases'] as num).toDouble(),
      totalInputVat: (json['total_input_vat'] as num).toDouble(),
      netVatDue: (json['net_vat_due'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'period_start': periodStart,
      'period_end': periodEnd,
      'total_sales': totalSales,
      'total_output_vat': totalOutputVat,
      'total_purchases': totalPurchases,
      'total_input_vat': totalInputVat,
      'net_vat_due': netVatDue,
    };
  }
}
