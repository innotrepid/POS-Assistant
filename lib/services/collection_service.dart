import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/utils/money.dart';

class PromiseToPay {
  final String id;
  final String customerId;
  final DateTime promisedDate;
  final double? amount;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? customerName;
  final String? phone;

  const PromiseToPay({
    required this.id,
    required this.customerId,
    required this.promisedDate,
    this.amount,
    this.notes,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.customerName,
    this.phone,
  });

  bool get isOpen => status == 'open';
}

class CommunicationEntry {
  final String id;
  final String partyType;
  final String? partyId;
  final String? partyName;
  final String channel;
  final String direction;
  final String? result;
  final String? notes;
  final String? relatedPromiseId;
  final DateTime createdAt;

  const CommunicationEntry({
    required this.id,
    required this.partyType,
    this.partyId,
    this.partyName,
    required this.channel,
    required this.direction,
    this.result,
    this.notes,
    this.relatedPromiseId,
    required this.createdAt,
  });
}

/// Promise-to-pay + communication history (offline collection).
class CollectionService {
  CollectionService({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> recordPromise({
    required String customerId,
    required DateTime promisedDate,
    double? amount,
    String? notes,
  }) async {
    if (customerId.trim().isEmpty) {
      throw ArgumentError('Customer is required.');
    }
    final day = DateTime(
      promisedDate.year,
      promisedDate.month,
      promisedDate.day,
    );
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;
    await db.insert('promises_to_pay', {
      'id': id,
      'customer_id': customerId,
      'promised_date': day.toIso8601String().substring(0, 10),
      'amount': amount != null ? Money.round(amount) : null,
      'notes': notes?.trim(),
      'status': 'open',
      'created_at': now,
      'resolved_at': null,
    });
    await db.insert('audit_logs', {
      'id': _uuid.v4(),
      'action': 'promise_to_pay_recorded',
      'entity_type': 'customer',
      'entity_id': customerId,
      'new_value':
          'date=${day.toIso8601String().substring(0, 10)}, amount=$amount',
      'reason': notes?.trim(),
      'created_at': now,
    });
    return id;
  }

  Future<void> resolvePromise(String promiseId, {String status = 'kept'}) async {
    final db = await _database.database;
    await db.update(
      'promises_to_pay',
      {
        'status': status,
        'resolved_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [promiseId],
    );
  }

  Future<List<PromiseToPay>> listOpenPromises({DateTime? onOrBefore}) async {
    final db = await _database.database;
    String? until;
    if (onOrBefore != null) {
      until = DateTime(onOrBefore.year, onOrBefore.month, onOrBefore.day)
          .toIso8601String()
          .substring(0, 10);
    }
    final rows = await db.rawQuery(
      '''
      SELECT p.*, c.name AS customer_name, c.phone AS phone
      FROM promises_to_pay p
      LEFT JOIN customers c ON c.id = p.customer_id
      WHERE p.status = 'open'
        ${until != null ? 'AND p.promised_date <= ?' : ''}
      ORDER BY p.promised_date ASC
      LIMIT 50
      ''',
      until != null ? [until] : [],
    );
    return rows.map(_promiseFromRow).toList();
  }

  Future<List<PromiseToPay>> listPromisesForCustomer(String customerId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*, c.name AS customer_name, c.phone AS phone
      FROM promises_to_pay p
      LEFT JOIN customers c ON c.id = p.customer_id
      WHERE p.customer_id = ?
      ORDER BY p.promised_date DESC
      LIMIT 30
      ''',
      [customerId],
    );
    return rows.map(_promiseFromRow).toList();
  }

  Future<PromiseToPay?> latestOpenPromise(String customerId) async {
    final list = await listPromisesForCustomer(customerId);
    for (final p in list) {
      if (p.isOpen) return p;
    }
    return null;
  }

  Future<String> logCommunication({
    required String partyType,
    String? partyId,
    String? partyName,
    required String channel,
    String direction = 'outbound',
    String? result,
    String? notes,
    String? relatedPromiseId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;
    await db.insert('communication_log', {
      'id': id,
      'party_type': partyType,
      'party_id': partyId,
      'party_name': partyName?.trim(),
      'channel': channel,
      'direction': direction,
      'result': result?.trim(),
      'notes': notes?.trim(),
      'related_promise_id': relatedPromiseId,
      'created_at': now,
    });
    return id;
  }

  Future<List<CommunicationEntry>> recentCommunications({
    String? partyId,
    int limit = 40,
  }) async {
    final db = await _database.database;
    final rows = partyId == null
        ? await db.query(
            'communication_log',
            orderBy: 'created_at DESC',
            limit: limit,
          )
        : await db.query(
            'communication_log',
            where: 'party_id = ?',
            whereArgs: [partyId],
            orderBy: 'created_at DESC',
            limit: limit,
          );
    return rows.map((r) {
      return CommunicationEntry(
        id: r['id'] as String,
        partyType: r['party_type'] as String? ?? 'customer',
        partyId: r['party_id'] as String?,
        partyName: r['party_name'] as String?,
        channel: r['channel'] as String? ?? 'other',
        direction: r['direction'] as String? ?? 'outbound',
        result: r['result'] as String?,
        notes: r['notes'] as String?,
        relatedPromiseId: r['related_promise_id'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  PromiseToPay _promiseFromRow(Map<String, dynamic> r) {
    final dateStr = r['promised_date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    return PromiseToPay(
      id: r['id'] as String,
      customerId: r['customer_id'] as String,
      promisedDate: DateTime(date.year, date.month, date.day),
      amount: (r['amount'] as num?)?.toDouble(),
      notes: r['notes'] as String?,
      status: r['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
          DateTime.now(),
      resolvedAt: r['resolved_at'] != null
          ? DateTime.tryParse(r['resolved_at'] as String)
          : null,
      customerName: r['customer_name'] as String?,
      phone: r['phone'] as String?,
    );
  }
}
