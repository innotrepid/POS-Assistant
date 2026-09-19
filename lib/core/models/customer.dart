class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? location;
  final String? customerType;
  final double? creditLimit;
  final String? notes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.location,
    this.customerType,
    this.creditLimit,
    this.notes,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'location': location,
      'customer_type': customerType,
      'credit_limit': creditLimit,
      'notes': notes,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      location: map['location'] as String?,
      customerType: map['customer_type'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      active: (map['active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
