import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Shared meta DB (profile choice, shop name, PIN) +
/// one business DB per profile so data never leaks across types.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase.memory() {
    final db = AppDatabase._();
    db._useMemory = true;
    return db;
  }

  Database? _database;
  Database? _metaDatabase;
  bool _useMemory = false;
  String _profileId = 'duka';

  static const int schemaVersion = 7;

  String get activeProfileId => _profileId;

  int _generation = 0;
  int get generation => _generation;

  bool _profileLocked = false;

  Future<void> useProfile(String profileId) async {
    final id = profileId.trim().isEmpty ? 'duka' : profileId.trim();
    if (_profileId == id && _database != null && _profileLocked) {
      return;
    }
    if (_database != null) {
      try {
        await _database!.close();
      } catch (_) {}
      _database = null;
    }
    _profileId = id;
    _profileLocked = true;
    _generation++;
    _database = await _openProfileDatabase(_profileId);
  }

  Future<Database> get metaDatabase async {
    if (_metaDatabase != null) return _metaDatabase!;
    if (_useMemory) {
      _metaDatabase = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      );
      return _metaDatabase!;
    }
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'mercate_meta.db');
    _metaDatabase = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
    return _metaDatabase!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (!_profileLocked) {
      try {
        final meta = await metaDatabase;
        final rows = await meta.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['business_profile'],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final v = rows.first['value'] as String?;
          if (v != null && v.isNotEmpty) _profileId = v;
        }
      } catch (_) {}
      _profileLocked = true;
    }

    _database = await _openProfileDatabase(_profileId);
    return _database!;
  }

  Future<Database> _openProfileDatabase(String profileId) async {
    if (_useMemory) {
      return openDatabase(
        inMemoryDatabasePath,
        version: schemaVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );
    }

    final databasesPath = await getDatabasesPath();
    final safeId = profileId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final profilePath = join(databasesPath, 'mercate_' + safeId + '.db');

    return openDatabase(
      profilePath,
      version: schemaVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE businesses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        business_type TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'KES',
        opening_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        alternative_name TEXT,
        sku TEXT,
        barcode TEXT,
        category_id TEXT,
        brand TEXT,
        unit TEXT NOT NULL DEFAULT 'piece',
        selling_price REAL NOT NULL DEFAULT 0,
        cost_price REAL,
        wholesale_price REAL,
        minimum_stock REAL NOT NULL DEFAULT 0,
        reorder_quantity REAL NOT NULL DEFAULT 0,
        supplier_id TEXT,
        image_path TEXT,
        notes TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        track_batches INTEGER NOT NULL DEFAULT 0,
        has_expiry INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL,
        reference_id TEXT,
        reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        location TEXT,
        credit_limit REAL,
        notes TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL,
        sale_status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        refunded_quantity REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        sale_id TEXT,
        customer_id TEXT,
        supplier_id TEXT,
        payment_type TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debtor_transactions (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        sale_id TEXT,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        location TEXT,
        categories TEXT,
        payment_terms TEXT,
        credit_limit REAL,
        notes TEXT,
        supplies TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        reference TEXT,
        subtotal REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        expected_payment_date TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL,
        batch_id TEXT,
        expiry_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE creditor_transactions (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        purchase_id TEXT,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL,
        payment_method TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE day_closings (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL UNIQUE,
        opening_cash REAL NOT NULL DEFAULT 0,
        counted_cash REAL NOT NULL DEFAULT 0,
        counted_mpesa REAL NOT NULL DEFAULT 0,
        expected_cash REAL NOT NULL DEFAULT 0,
        expected_mpesa REAL NOT NULL DEFAULT 0,
        sales_total REAL NOT NULL DEFAULT 0,
        expenses_total REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'info',
        title TEXT NOT NULL,
        body TEXT,
        deep_link TEXT,
        entity_type TEXT,
        entity_id TEXT,
        dedupe_key TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        read_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        old_value TEXT,
        new_value TEXT,
        reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await _createCollectionTables(db);

    await db.execute(
      'CREATE INDEX idx_stock_movements_product ON stock_movements(product_id)',
    );
    await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute(
      'CREATE INDEX idx_debtor_customer ON debtor_transactions(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_creditor_supplier ON creditor_transactions(supplier_id)',
    );
    await db.execute(
      'CREATE INDEX idx_notifications_read ON notifications(is_read)',
    );
    await db.execute(
      'CREATE INDEX idx_payments_reference ON payments(reference)',
    );
  }

  Future<void> _createCollectionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS promises_to_pay (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        promised_date TEXT NOT NULL,
        amount REAL,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS communication_log (
        id TEXT PRIMARY KEY,
        party_type TEXT NOT NULL,
        party_id TEXT,
        party_name TEXT,
        channel TEXT NOT NULL,
        direction TEXT NOT NULL DEFAULT 'outbound',
        result TEXT,
        notes TEXT,
        related_promise_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_promises_customer ON promises_to_pay(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_promises_date ON promises_to_pay(promised_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comm_party ON communication_log(party_id)',
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN track_batches INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE products ADD COLUMN has_expiry INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS day_closings (
            id TEXT PRIMARY KEY,
            business_date TEXT NOT NULL UNIQUE,
            opening_cash REAL NOT NULL DEFAULT 0,
            counted_cash REAL NOT NULL DEFAULT 0,
            counted_mpesa REAL NOT NULL DEFAULT 0,
            expected_cash REAL NOT NULL DEFAULT 0,
            expected_mpesa REAL NOT NULL DEFAULT 0,
            sales_total REAL NOT NULL DEFAULT 0,
            expenses_total REAL NOT NULL DEFAULT 0,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notifications (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            priority TEXT NOT NULL DEFAULT 'info',
            title TEXT NOT NULL,
            body TEXT,
            deep_link TEXT,
            entity_type TEXT,
            entity_id TEXT,
            dedupe_key TEXT,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            read_at TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN refunded_quantity REAL NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN supplies TEXT');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      for (final sql in [
        "ALTER TABLE sales ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0",
        "ALTER TABLE sales ADD COLUMN balance REAL NOT NULL DEFAULT 0",
        "ALTER TABLE sales ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'unpaid'",
        "ALTER TABLE sales ADD COLUMN sale_status TEXT NOT NULL DEFAULT 'completed'",
        "ALTER TABLE sale_items ADD COLUMN unit_cost REAL",
        "ALTER TABLE payments ADD COLUMN sale_id TEXT",
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }
    if (oldVersion < 7) {
      await _createCollectionTables(db);
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    if (_metaDatabase != null) {
      await _metaDatabase!.close();
      _metaDatabase = null;
    }
  }

  Future<void> transaction(
    Future<void> Function(Transaction txn) action,
  ) async {
    final db = await database;
    await db.transaction(action);
  }
}
