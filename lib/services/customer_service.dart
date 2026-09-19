import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/models/customer.dart';

class CustomerService {
  CustomerService({
    AppDatabase? database,
    Uuid? uuid,
  }) : _database = database ?? AppDatabase.instance,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? location,
    String? notes,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Customer name is required.');
    }

    final now = DateTime.now();
    final customer = Customer(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone?.trim(),
      location: location?.trim(),
      notes: notes?.trim(),
      active: true,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _database.database;
    await db.insert('customers', customer.toMap());
    return customer;
  }

  Future<Customer?> getCustomer(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<List<Customer>> getAllCustomers({bool activeOnly = true}) async {
    final db = await _database.database;
    final rows = await db.query(
      'customers',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _database.database;
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'customers',
      where: 'active = 1 AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: [q, q],
      orderBy: 'name ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }
}
