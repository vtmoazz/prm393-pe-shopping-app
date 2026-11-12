import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// SQLite storage for users, products, the per-user cart and orders.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _version = 1;

  /// Opens the app database. [path] lets tests use an in-memory database.
  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), 'prm393_shop.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        image TEXT
      )''');
    await db.execute('''
      CREATE TABLE cart_items(
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        quantity INTEGER NOT NULL,
        PRIMARY KEY (user_id, product_id)
      )''');
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        total REAL NOT NULL,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        product_name TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL
      )''');

    for (final product in _seedProducts) {
      await db.insert('products', product.toMap());
    }
  }

  static const _seedProducts = [
    Product(
      name: 'Wireless Headphones',
      description: 'Over-ear Bluetooth headphones with noise cancelling.',
      price: 1290000,
      image: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
    ),
    Product(
      name: 'Mechanical Keyboard',
      description: '87-key keyboard with hot-swappable switches.',
      price: 890000,
      image: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=400',
    ),
    Product(
      name: 'Smart Watch',
      description: 'Fitness tracking, heart rate and notifications.',
      price: 2150000,
      image: 'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=400',
    ),
    Product(
      name: 'USB-C Charger 65W',
      description: 'Fast GaN charger for laptop and phone.',
      price: 450000,
      image: 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=400',
    ),
    Product(
      name: 'Backpack',
      description: 'Water-resistant 15.6" laptop backpack.',
      price: 650000,
      image: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
    ),
  ];

  Future<void> close() => _db.close();

  // ---------- Users ----------

  Future<AppUser?> findUserByEmail(String email) async {
    final rows = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<int> insertUser(AppUser user) => _db.insert('users', user.toMap());

  // ---------- Products ----------

  Future<List<Product>> getProducts() async {
    final rows = await _db.query('products', orderBy: 'id DESC');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product product) => _db.insert('products', product.toMap());

  Future<void> updateProduct(Product product) =>
      _db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);

  Future<void> deleteProduct(int id) =>
      _db.delete('products', where: 'id = ?', whereArgs: [id]);

  // ---------- Cart ----------

  Future<List<CartItem>> getCart(int userId) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.quantity FROM cart_items c
      JOIN products p ON p.id = c.product_id
      WHERE c.user_id = ?
      ORDER BY p.name''', [userId]);
    return rows
        .map((r) => CartItem(product: Product.fromMap(r), quantity: r['quantity'] as int))
        .toList();
  }

  Future<void> addToCart(int userId, int productId, {int quantity = 1}) async {
    await _db.rawInsert('''
      INSERT INTO cart_items(user_id, product_id, quantity) VALUES(?, ?, ?)
      ON CONFLICT(user_id, product_id) DO UPDATE SET quantity = quantity + excluded.quantity''',
        [userId, productId, quantity]);
  }

  Future<void> setCartQuantity(int userId, int productId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(userId, productId);
      return;
    }
    await _db.update(
      'cart_items',
      {'quantity': quantity},
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
  }

  Future<void> removeFromCart(int userId, int productId) => _db.delete(
        'cart_items',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
      );

  /// Turns the user's cart into an order and empties the cart.
  /// Returns the new order id, or null when the cart is empty.
  Future<int?> checkout(int userId, {DateTime? at}) {
    return _db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT p.name, p.price, c.quantity FROM cart_items c
        JOIN products p ON p.id = c.product_id
        WHERE c.user_id = ?''', [userId]);
      if (rows.isEmpty) return null;

      final total = rows.fold<double>(
        0,
        (sum, r) => sum + (r['price'] as num).toDouble() * (r['quantity'] as int),
      );
      final orderId = await txn.insert('orders', {
        'user_id': userId,
        'total': total,
        'created_at': (at ?? DateTime.now()).toIso8601String(),
      });
      for (final r in rows) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'product_name': r['name'],
          'unit_price': r['price'],
          'quantity': r['quantity'],
        });
      }
      await txn.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
      return orderId;
    });
  }

  // ---------- Orders / revenue ----------

  Future<List<OrderRecord>> getOrders(int userId) async {
    final rows = await _db.rawQuery('''
      SELECT o.id, o.total, o.created_at, COALESCE(SUM(i.quantity), 0) AS item_count
      FROM orders o LEFT JOIN order_items i ON i.order_id = o.id
      WHERE o.user_id = ?
      GROUP BY o.id
      ORDER BY o.created_at DESC''', [userId]);
    return rows.map(OrderRecord.fromMap).toList();
  }
}
