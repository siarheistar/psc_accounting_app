class Company {
  final String id; // Keep as String but convert from int
  final String name;
  final String address;
  final String phone;
  final String email;
  final String ownerEmail;
  final DateTime createdAt;
  final bool isDemo;
  final String? country;
  final String? currency;
  final String? vatNumber;

  Company({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.ownerEmail,
    required this.createdAt,
    required this.isDemo,
    this.country,
    this.currency,
    this.vatNumber,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id']?.toString() ?? '', // Convert int to String
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      ownerEmail: json['owner_email'] ?? '',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      isDemo: json['is_demo'] ?? false,
      country: json['country'],
      currency: json['currency'],
      vatNumber: json['vat_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'owner_email': ownerEmail,
      'created_at': createdAt.toIso8601String(),
      'is_demo': isDemo,
      'country': country,
      'currency': currency,
      'vat_number': vatNumber,
    };
  }

  @override
  String toString() {
    return 'Company(id: $id, name: $name, email: $email, isDemo: $isDemo)';
  }
}
