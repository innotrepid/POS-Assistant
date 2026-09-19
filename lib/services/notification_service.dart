import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';

class AppNotification {
  final String id;
  final String category;
  final String priority;
  final String title;
  final String body;
  final String? deepLink;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    this.deepLink,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      category: map['category'] as String,
      priority: map['priority'] as String? ?? 'info',
      title: map['title'] as String,
      body: map['body'] as String? ?? '',
      deepLink: map['deep_link'] as String?,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as String?,
      isRead: (map['is_read'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
    );
  }
}

class NotificationService {
  NotificationService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> push({
    required String category,
    required String title,
    required String body,
    String priority = 'info',
    String? deepLink,
    String? entityType,
    String? entityId,
    String? dedupeKey,
  }) async {
    final db = await _database.database;

    if (dedupeKey != null) {
      final existing = await db.query(
        'notifications',
        where: 'dedupe_key = ? AND is_read = 0',
        whereArgs: [dedupeKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await db.update(
          'notifications',
          {
            'title': title,
            'body': body,
            'priority': priority,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        return existing.first['id'] as String;
      }
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await db.insert('notifications', {
      'id': id,
      'category': category,
      'priority': priority,
      'title': title,
      'body': body,
      'deep_link': deepLink,
      'entity_type': entityType,
      'entity_id': entityId,
      'dedupe_key': dedupeKey,
      'is_read': 0,
      'created_at': now,
      'read_at': null,
    });
    return id;
  }

  /// Returns true only when a brand-new unread notification was inserted.
  Future<bool> pushIfNew({
    required String category,
    required String title,
    required String body,
    String priority = 'info',
    String? deepLink,
    String? entityType,
    String? entityId,
    required String dedupeKey,
  }) async {
    final db = await _database.database;
    final existing = await db.query(
      'notifications',
      where: 'dedupe_key = ? AND is_read = 0',
      whereArgs: [dedupeKey],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'notifications',
        {
          'title': title,
          'body': body,
          'priority': priority,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return false;
    }
    await push(
      category: category,
      title: title,
      body: body,
      priority: priority,
      deepLink: deepLink,
      entityType: entityType,
      entityId: entityId,
      dedupeKey: dedupeKey,
    );
    return true;
  }

  Future<void> markReadByDedupeKey(String dedupeKey) async {
    final db = await _database.database;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'read_at': DateTime.now().toIso8601String(),
      },
      where: 'dedupe_key = ? AND is_read = 0',
      whereArgs: [dedupeKey],
    );
  }

  Future<int> unreadCount() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE is_read = 0',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<AppNotification>> list({int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<void> markRead(String id) async {
    final db = await _database.database;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'read_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    final db = await _database.database;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'read_at': DateTime.now().toIso8601String(),
      },
      where: 'is_read = 0',
    );
  }
}
