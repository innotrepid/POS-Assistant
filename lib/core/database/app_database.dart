import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase.memory() {
    final db = AppDatabase._();
    db._useMemory = true;
    return db;
  }

  Database? _database;
  bool _useMemory = false;

  static const int schemaVersion = 3;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    if (_useMemory) {
      return openDatabase(
        inMemoryDatabasePath,
        version: schemaVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'pos_assistant.db');

    return openDatabase(
      path,
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
        location TEXT,
        customer_type TEXT,
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
        total REAL NOT NULL
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
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        previous_value TEXT,
        new_value TEXT,
        reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        due_at TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_product ON stock_movements(product_id)',
    );
    await db.execute('CREATE INDEX idx_sales_customer ON sales(customer_id)');
    await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
    await db.execute(
      'CREATE INDEX idx_debtors_customer ON debtor_transactions(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_creditors_supplier ON creditor_transactions(supplier_id)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_created ON expenses(created_at)',
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN track_batches INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN has_expiry INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
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
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_created ON expenses(created_at)',
      );
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> transaction(
    Future<void> Function(Transaction txn) action,
  ) async {
    final db = await database;
    await db.transaction(action);
  }
}
