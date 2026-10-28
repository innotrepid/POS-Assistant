class Shop {
  final String id;
  final String name;
  final String profileId;
  final DateTime createdAt;

  const Shop({
    required this.id,
    required this.name,
    required this.profileId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'profile_id': profileId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Shop',
      profileId: map['profile_id'] as String? ?? 'mamaMboga',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
