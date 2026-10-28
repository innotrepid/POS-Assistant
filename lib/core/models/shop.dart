/// A shop is an isolated business unit with its own SQLite file.
class Shop {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;

  const Shop({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastOpenedAt,
  });

  /// Safe fragment for on-disk filenames (alphanumeric only).
  String get safeId => id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  /// Database file for this shop: mercate_<safeId>.db
  String get dbFileName => 'mercate_$safeId.db';

  Shop copyWith({
    String? name,
    DateTime? lastOpenedAt,
  }) {
    return Shop(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'last_opened_at': lastOpenedAt?.toIso8601String(),
    };
  }

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastOpenedAt: map['last_opened_at'] != null
          ? DateTime.tryParse(map['last_opened_at'] as String)
          : null,
    );
  }
}
