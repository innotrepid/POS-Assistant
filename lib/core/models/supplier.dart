class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? location;
  final String? notes;
  /// Product names this supplier usually brings (for receive-goods shortcuts).
  final List<String> supplies;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.location,
    this.notes,
    this.supplies = const [],
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'location': location,
      'notes': notes,
      'supplies': supplies.join('|'),
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    final raw = map['supplies'] as String? ?? map['categories'] as String? ?? '';
    final list = raw
        .split(RegExp(r'[|,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      supplies: list,
      active: (map['active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
