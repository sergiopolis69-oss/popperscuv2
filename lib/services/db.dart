// versión 3, con upgrades
...
return await openDatabase(
  path,
  version: 3,
  onCreate: _onCreate,
  onUpgrade: _onUpgrade,
);

Future _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE products(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      sku TEXT,
      cost_price REAL NOT NULL DEFAULT 0,
      sale_price REAL NOT NULL DEFAULT 0,
      stock INTEGER NOT NULL,
      category TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE customers(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT, email TEXT, notes TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE sales(
      id TEXT PRIMARY KEY,
      customer_id TEXT,
      total REAL NOT NULL,
      discount REAL NOT NULL,
      payment_method TEXT NOT NULL,
      profit REAL NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE sale_items(
      id TEXT PRIMARY KEY,
      sale_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      price REAL NOT NULL,
      cost_at_sale REAL NOT NULL DEFAULT 0,
      line_discount REAL NOT NULL DEFAULT 0,
      subtotal REAL NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE inventory_movements(
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      type TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      reason TEXT,
      ref_sale_id TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);');
}

Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE sale_items ADD COLUMN line_discount REAL NOT NULL DEFAULT 0;');
    try { await db.execute('ALTER TABLE sale_items ADD COLUMN subtotal REAL NOT NULL DEFAULT 0;'); } catch (_) {}
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);');
  }
  if (oldVersion < 3) {
    try { await db.execute('ALTER TABLE products ADD COLUMN cost_price REAL NOT NULL DEFAULT 0;'); } catch (_) {}
    try { await db.execute('ALTER TABLE products ADD COLUMN sale_price REAL NOT NULL DEFAULT 0;'); } catch (_) {}
    try { await db.execute('ALTER TABLE sales ADD COLUMN profit REAL NOT NULL DEFAULT 0;'); } catch (_) {}
    try { await db.execute('ALTER TABLE sale_items ADD COLUMN cost_at_sale REAL NOT NULL DEFAULT 0;'); } catch (_) {}
  }
}
