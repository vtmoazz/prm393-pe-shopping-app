import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/validators.dart';

/// SQLite storage for the marketplace: accounts with roles, shops' products,
/// the customers' carts and orders.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// 1: single shop. 2: roles, seller-owned products, per-shop order lines.
  /// 3: affiliate codes and commissions.
  static const _version = 3;

  static const officialShopEmail = 'official@shop.com';

  /// Opens the app database. [path] lets tests use an in-memory database.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join(await dbFactory.getDatabasesPath(), 'prm393_shop.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
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
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'customer',
        shop_name TEXT,
        ref_code TEXT UNIQUE
      )''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        image TEXT,
        seller_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        commission_rate REAL NOT NULL DEFAULT 5
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
        created_at TEXT NOT NULL,
        affiliate_id INTEGER REFERENCES users(id) ON DELETE SET NULL
      )''');
    // seller_id has no foreign key so sales history outlives a deleted shop.
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        product_name TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        seller_id INTEGER,
        commission REAL NOT NULL DEFAULT 0
      )''');

    final sellers = await _seedAccounts(db);
    for (final product in _officialProducts) {
      await db.insert(
        'products',
        product.copyWith(sellerId: sellers.official).toMap(),
      );
    }
    for (final product in _techProducts) {
      await db.insert(
        'products',
        product.copyWith(sellerId: sellers.tech).toMap(),
      );
    }
    await _backfillRefCodes(db);
  }

  /// Turns a single-shop database into the marketplace without losing data:
  /// existing products and past sales go to the official shop.
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'customer'",
      );
      await db.execute('ALTER TABLE users ADD COLUMN shop_name TEXT');
      await db.execute(
        'ALTER TABLE products ADD COLUMN seller_id INTEGER '
        'REFERENCES users(id) ON DELETE CASCADE',
      );
      await db.execute('ALTER TABLE order_items ADD COLUMN seller_id INTEGER');

      final sellers = await _seedAccounts(db);
      await db.update('products', {
        'seller_id': sellers.official,
      }, where: 'seller_id IS NULL');
      await db.update('order_items', {
        'seller_id': sellers.official,
      }, where: 'seller_id IS NULL');
      for (final product in _techProducts) {
        // commission_rate arrives in version 3, below.
        await db.insert(
          'products',
          product.copyWith(sellerId: sellers.tech).toMap()
            ..remove('commission_rate'),
        );
      }
    }
    if (from < 3) {
      await db.execute('ALTER TABLE users ADD COLUMN ref_code TEXT');
      await db.execute('CREATE UNIQUE INDEX users_ref_code ON users(ref_code)');
      await db.execute(
        'ALTER TABLE products ADD COLUMN commission_rate REAL NOT NULL DEFAULT 5',
      );
      await db.execute(
        'ALTER TABLE orders ADD COLUMN affiliate_id INTEGER '
        'REFERENCES users(id) ON DELETE SET NULL',
      );
      await db.execute(
        'ALTER TABLE order_items ADD COLUMN commission REAL NOT NULL DEFAULT 0',
      );
      await _backfillRefCodes(db);
    }
  }

  static Future<void> _backfillRefCodes(Database db) async {
    final users = await db.query(
      'users',
      columns: ['id', 'email'],
      where: 'ref_code IS NULL',
    );
    for (final u in users) {
      await _assignRefCode(db, u['id'] as int, u['email'] as String);
    }
  }

  /// Gives a user their affiliate code: the letters of the email name plus
  /// the id, so codes are unique and still readable (lan@mail.com -> LAN5).
  static Future<void> _assignRefCode(
    DatabaseExecutor db,
    int id,
    String email,
  ) => db.update(
    'users',
    {'ref_code': refCodeFor(id, email)},
    where: 'id = ?',
    whereArgs: [id],
  );

  static String refCodeFor(int id, String email) {
    final letters = email
        .split('@')
        .first
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z]'), '');
    final prefix = letters.isEmpty
        ? 'USER'
        : letters.substring(0, letters.length.clamp(0, 6));
    return '$prefix$id';
  }

  /// Demo accounts for each role. Emails that already exist are kept as they
  /// are. Returns the ids of the two seed shops.
  static Future<({int official, int tech})> _seedAccounts(Database db) async {
    Future<int> ensure(AppUser user) async {
      final rows = await db.query(
        'users',
        columns: ['id'],
        where: 'email = ?',
        whereArgs: [user.email],
      );
      if (rows.isNotEmpty) return rows.first['id'] as int;
      return db.insert('users', user.toMap());
    }

    await ensure(
      AppUser(
        fullName: 'Platform Admin',
        email: 'admin@shop.com',
        passwordHash: hashPassword('admin123'),
        role: UserRole.admin,
      ),
    );
    final official = await ensure(
      AppUser(
        fullName: 'Sunset Team',
        email: officialShopEmail,
        passwordHash: hashPassword('seller123'),
        role: UserRole.seller,
        shopName: 'Sunset Official',
      ),
    );
    final tech = await ensure(
      AppUser(
        fullName: 'Tech Corner Team',
        email: 'tech@shop.com',
        passwordHash: hashPassword('seller123'),
        role: UserRole.seller,
        shopName: 'Tech Corner',
      ),
    );
    return (official: official, tech: tech);
  }

  static const _officialProducts = [
    Product(
      name: 'Wireless Headphones',
      description: 'Over-ear Bluetooth headphones with noise cancelling.',
      price: 1290000,
      image:
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
    ),
    Product(
      name: 'Mechanical Keyboard',
      description: '87-key keyboard with hot-swappable switches.',
      price: 890000,
      image:
          'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=400',
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
      image:
          'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=400',
    ),
    Product(
      name: 'Backpack',
      description: 'Water-resistant 15.6" laptop backpack.',
      price: 650000,
      image: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
    ),
  ];

  static const _techProducts = [
    Product(
      name: 'Gaming Mouse',
      description: 'Lightweight wireless mouse with a 26K DPI sensor.',
      price: 790000,
      image:
          'https://images.unsplash.com/photo-1527814050087-3793815479db?w=400',
    ),
    Product(
      name: 'Portable SSD 1TB',
      description: 'Pocket-size USB-C drive, up to 1050 MB/s.',
      price: 1890000,
      image:
          'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=400',
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

  Future<int> insertUser(AppUser user) async {
    final id = await _db.insert('users', user.toMap());
    await _assignRefCode(_db, id, user.email);
    return id;
  }

  Future<AppUser?> findUserByRefCode(String code) async {
    final rows = await _db.query(
      'users',
      where: 'ref_code = ?',
      whereArgs: [code.trim().toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getUsers() async {
    final rows = await _db.query('users', orderBy: 'role, full_name');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<void> updateUserRole(int userId, UserRole role, String? shopName) =>
      _db.update(
        'users',
        {'role': role.name, 'shop_name': shopName},
        where: 'id = ?',
        whereArgs: [userId],
      );

  // ---------- Products ----------

  Future<List<Product>> getProducts() async {
    final rows = await _db.rawQuery('''
      SELECT p.*, u.shop_name FROM products p
      LEFT JOIN users u ON u.id = p.seller_id
      ORDER BY p.id DESC''');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product product) =>
      _db.insert('products', product.toMap());

  Future<void> updateProduct(Product product) => _db.update(
    'products',
    product.toMap(),
    where: 'id = ?',
    whereArgs: [product.id],
  );

  Future<void> deleteProduct(int id) =>
      _db.delete('products', where: 'id = ?', whereArgs: [id]);

  // ---------- Cart ----------

  Future<List<CartItem>> getCart(int userId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT p.*, u.shop_name, c.quantity FROM cart_items c
      JOIN products p ON p.id = c.product_id
      LEFT JOIN users u ON u.id = p.seller_id
      WHERE c.user_id = ?
      ORDER BY p.name''',
      [userId],
    );
    return rows
        .map(
          (r) => CartItem(
            product: Product.fromMap(r),
            quantity: r['quantity'] as int,
          ),
        )
        .toList();
  }

  Future<void> addToCart(int userId, int productId, {int quantity = 1}) async {
    await _db.rawInsert(
      '''
      INSERT INTO cart_items(user_id, product_id, quantity) VALUES(?, ?, ?)
      ON CONFLICT(user_id, product_id) DO UPDATE SET quantity = quantity + excluded.quantity''',
      [userId, productId, quantity],
    );
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

  /// Turns the user's cart into an order and empties the cart. Each line keeps
  /// the selling shop so revenue can be split per shop.
  ///
  /// With an [affiliateCode], each line also records the commission owed to
  /// that affiliate at the product's current rate. The code must belong to
  /// another customer, otherwise this throws an [ArgumentError].
  /// Returns the new order id, or null when the cart is empty.
  Future<int?> checkout(
    int userId, {
    DateTime? at,
    String? affiliateCode,
  }) async {
    int? affiliateId;
    final code = affiliateCode?.trim() ?? '';
    if (code.isNotEmpty) {
      final affiliate = await findUserByRefCode(code);
      if (affiliate == null || !affiliate.isCustomer) {
        throw ArgumentError('Affiliate code $code does not exist');
      }
      if (affiliate.id == userId) {
        throw ArgumentError('You cannot use your own affiliate code');
      }
      affiliateId = affiliate.id;
    }
    return _db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT p.name, p.price, p.seller_id, p.commission_rate, c.quantity
        FROM cart_items c
        JOIN products p ON p.id = c.product_id
        WHERE c.user_id = ?''',
        [userId],
      );
      if (rows.isEmpty) return null;

      final total = rows.fold<double>(
        0,
        (sum, r) =>
            sum + (r['price'] as num).toDouble() * (r['quantity'] as int),
      );
      final orderId = await txn.insert('orders', {
        'user_id': userId,
        'total': total,
        'created_at': (at ?? DateTime.now()).toIso8601String(),
        'affiliate_id': affiliateId,
      });
      for (final r in rows) {
        final amount = (r['price'] as num).toDouble() * (r['quantity'] as int);
        final rate = (r['commission_rate'] as num).toDouble();
        await txn.insert('order_items', {
          'order_id': orderId,
          'product_name': r['name'],
          'unit_price': r['price'],
          'quantity': r['quantity'],
          'seller_id': r['seller_id'],
          'commission': affiliateId == null ? 0 : amount * rate / 100,
        });
      }
      await txn.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
      return orderId;
    });
  }

  // ---------- Orders / revenue ----------

  /// The orders a customer placed.
  Future<List<OrderRecord>> getOrders(int userId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT o.id, o.total, o.created_at, COALESCE(SUM(i.quantity), 0) AS item_count
      FROM orders o LEFT JOIN order_items i ON i.order_id = o.id
      WHERE o.user_id = ?
      GROUP BY o.id
      ORDER BY o.created_at DESC''',
      [userId],
    );
    return rows.map(OrderRecord.fromMap).toList();
  }

  /// Every order on the platform, with the customer's name.
  Future<List<OrderRecord>> getAllOrders() async {
    final rows = await _db.rawQuery('''
      SELECT o.id, o.total, o.created_at, u.full_name AS customer_name,
        COALESCE(SUM(i.quantity), 0) AS item_count,
        COALESCE(SUM(i.commission), 0) AS commission
      FROM orders o
      JOIN users u ON u.id = o.user_id
      LEFT JOIN order_items i ON i.order_id = o.id
      GROUP BY o.id
      ORDER BY o.created_at DESC''');
    return rows.map(OrderRecord.fromMap).toList();
  }

  /// One row per order and shop: what each shop sold in each order.
  /// [sellerId] limits the rows to one shop.
  Future<List<OrderRecord>> getShopSales({int? sellerId}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT o.id, o.created_at, c.full_name AS customer_name,
        COALESCE(s.shop_name, 'Closed shop') AS shop_name,
        SUM(i.unit_price * i.quantity) AS total,
        SUM(i.quantity) AS item_count, SUM(i.commission) AS commission
      FROM order_items i
      JOIN orders o ON o.id = i.order_id
      JOIN users c ON c.id = o.user_id
      LEFT JOIN users s ON s.id = i.seller_id
      ${sellerId == null ? '' : 'WHERE i.seller_id = ?'}
      GROUP BY o.id, i.seller_id
      ORDER BY o.created_at DESC''',
      [?sellerId],
    );
    return rows.map(OrderRecord.fromMap).toList();
  }

  // ---------- Affiliate ----------

  /// Orders placed with [affiliateId]'s code, with the commission each earned.
  Future<List<OrderRecord>> getReferredOrders(int affiliateId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT o.id, o.total, o.created_at, u.full_name AS customer_name,
        SUM(i.quantity) AS item_count, SUM(i.commission) AS commission
      FROM orders o
      JOIN users u ON u.id = o.user_id
      JOIN order_items i ON i.order_id = o.id
      WHERE o.affiliate_id = ?
      GROUP BY o.id
      ORDER BY o.created_at DESC''',
      [affiliateId],
    );
    return rows.map(OrderRecord.fromMap).toList();
  }

  /// Every affiliate who brought in an order, highest commission first.
  Future<List<AffiliateSummary>> getAffiliateSummaries() async {
    final rows = await _db.rawQuery('''
      SELECT a.full_name, a.ref_code, COUNT(DISTINCT o.id) AS orders,
        SUM(i.commission) AS commission
      FROM orders o
      JOIN users a ON a.id = o.affiliate_id
      JOIN order_items i ON i.order_id = o.id
      GROUP BY a.id
      ORDER BY commission DESC''');
    return [
      for (final r in rows)
        (
          name: r['full_name'] as String,
          code: r['ref_code'] as String? ?? '',
          orders: r['orders'] as int,
          commission: (r['commission'] as num).toDouble(),
        ),
    ];
  }
}
