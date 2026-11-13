import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prm393_pe/data/app_database.dart';
import 'package:prm393_pe/models/models.dart';
import 'package:prm393_pe/providers/auth_provider.dart';
import 'package:prm393_pe/providers/cart_provider.dart';
import 'package:prm393_pe/providers/product_provider.dart';
import 'package:prm393_pe/utils/revenue.dart';
import 'package:prm393_pe/utils/validators.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  });

  tearDown(() => db.close());

  group('validators', () {
    test('email format', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('abc'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('student@fpt.edu.vn'), isNull);
    });

    test('password and confirm password', () {
      expect(validatePassword('123'), isNotNull);
      expect(validatePassword('123456'), isNull);
      expect(validateConfirmPassword('123457', '123456'), isNotNull);
      expect(validateConfirmPassword('123456', '123456'), isNull);
    });

    test('price', () {
      expect(validatePrice('abc'), isNotNull);
      expect(validatePrice('0'), isNotNull);
      expect(validatePrice('15000'), isNull);
    });
  });

  group('auth', () {
    test('register, reject duplicate, login and remember me', () async {
      final prefs = await SharedPreferences.getInstance();
      final auth = AuthProvider(db, prefs);

      expect(await auth.register('Nguyen Van A', 'a@test.com', 'secret1'), isNull);
      expect(await auth.register('Other', 'A@Test.com', 'secret2'), isNotNull);

      expect(await auth.login('a@test.com', 'wrong', rememberMe: false), isNotNull);
      expect(auth.isLoggedIn, isFalse);

      expect(await auth.login('a@test.com', 'secret1', rememberMe: true), isNull);
      expect(auth.user?.fullName, 'Nguyen Van A');
      expect(prefs.getString('remember_me_email'), 'a@test.com');

      // A fresh app start logs the remembered user back in.
      final restarted = AuthProvider(db, prefs);
      await restarted.tryAutoLogin();
      expect(restarted.isLoggedIn, isTrue);

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(prefs.getString('remember_me_email'), isNull);
    });

    test('password is stored hashed', () async {
      final auth = AuthProvider(db, await SharedPreferences.getInstance());
      await auth.register('B', 'b@test.com', 'secret1');
      final user = await db.findUserByEmail('b@test.com');
      expect(user!.passwordHash, isNot('secret1'));
      expect(user.passwordHash, hashPassword('secret1'));
    });
  });

  group('products', () {
    test('seeded list, search, sort and CRUD', () async {
      final products = ProductProvider(db);
      await products.load();
      expect(products.visibleProducts, hasLength(7));

      products.setQuery('watch');
      expect(products.visibleProducts.single.name, 'Smart Watch');
      products.setQuery('');

      products.setSort(PriceSort.ascending);
      final asc = products.visibleProducts.map((p) => p.price).toList();
      expect(asc, [...asc]..sort());
      products.setSort(PriceSort.descending);
      expect(products.visibleProducts.first.price, asc.last);

      await products.add(const Product(name: 'Mouse', description: 'Wireless', price: 200000));
      final mouse = products.visibleProducts.firstWhere((p) => p.name == 'Mouse');
      await products.update(mouse.copyWith(price: 250000));
      expect(products.findById(mouse.id!)!.price, 250000);
      await products.delete(mouse.id!);
      expect(products.findById(mouse.id!), isNull);
    });
  });

  group('cart and revenue', () {
    test('add, change quantity, checkout records an order', () async {
      final auth = AuthProvider(db, await SharedPreferences.getInstance());
      await auth.register('C', 'c@test.com', 'secret1');
      await auth.login('c@test.com', 'secret1', rememberMe: false);
      final products = ProductProvider(db);
      await products.load();
      final cart = CartProvider(db);
      await cart.attachUser(auth.user);

      final a = products.visibleProducts[0];
      final b = products.visibleProducts[1];
      await cart.add(a);
      await cart.add(a); // same product twice increases quantity
      await cart.add(b, quantity: 3);
      expect(cart.items, hasLength(2));
      expect(cart.itemCount, 5);

      await cart.setQuantity(b, 1);
      expect(cart.total, a.price * 2 + b.price);

      await cart.remove(b);
      expect(cart.items.single.product.id, a.id);

      final orderId = await cart.checkout();
      expect(orderId, isNotNull);
      expect(cart.items, isEmpty);
      expect(cart.orders.single.total, a.price * 2);
      expect(cart.orders.single.itemCount, 2);

      expect(await cart.checkout(), isNull, reason: 'empty cart cannot be checked out');
    });

    test('filter revenue by day, month and year', () {
      final orders = [
        OrderRecord(id: 1, total: 100, createdAt: DateTime(2026, 11, 12, 9), itemCount: 1),
        OrderRecord(id: 2, total: 200, createdAt: DateTime(2026, 11, 3), itemCount: 1),
        OrderRecord(id: 3, total: 400, createdAt: DateTime(2026, 5, 1), itemCount: 1),
        OrderRecord(id: 4, total: 800, createdAt: DateTime(2025, 11, 12), itemCount: 1),
      ];
      final day = DateTime(2026, 11, 12);
      expect(totalRevenue(filterOrders(orders, RevenuePeriod.all, day)), 1500);
      expect(totalRevenue(filterOrders(orders, RevenuePeriod.year, day)), 700);
      expect(totalRevenue(filterOrders(orders, RevenuePeriod.month, day)), 300);
      expect(totalRevenue(filterOrders(orders, RevenuePeriod.day, day)), 100);
    });

    test('revenue chart buckets', () {
      final orders = [
        OrderRecord(id: 1, total: 100, createdAt: DateTime(2026, 11, 12, 9), itemCount: 1),
        OrderRecord(id: 2, total: 50, createdAt: DateTime(2026, 11, 12, 9, 30), itemCount: 1),
        OrderRecord(id: 3, total: 200, createdAt: DateTime(2026, 11, 3), itemCount: 1),
        OrderRecord(id: 4, total: 400, createdAt: DateTime(2026, 5, 1), itemCount: 1),
        OrderRecord(id: 5, total: 800, createdAt: DateTime(2025, 11, 12), itemCount: 1),
      ];
      final day = DateTime(2026, 11, 12);

      final hours = revenueBuckets(orders, RevenuePeriod.day, day);
      expect(hours, hasLength(24));
      expect(hours[9].value, 150);

      final days = revenueBuckets(orders, RevenuePeriod.month, day);
      expect(days, hasLength(30));
      expect(days[2].value, 200);
      expect(days[11].value, 150);

      final months = revenueBuckets(orders, RevenuePeriod.year, day);
      expect(months, hasLength(12));
      expect(months[4].value, 400);
      expect(months[10].value, 350);

      final years = revenueBuckets(orders, RevenuePeriod.all, day);
      expect(years.map((b) => b.label), ['2025', '2026']);
      expect(years.map((b) => b.value), [800, 750]);
    });
  });

  group('marketplace roles', () {
    Future<AuthProvider> signIn(String email, String password) async {
      final auth = AuthProvider(db, await SharedPreferences.getInstance());
      expect(await auth.login(email, password, rememberMe: false), isNull);
      return auth;
    }

    test('seed accounts have the right roles and shops', () async {
      final admin = await signIn('admin@shop.com', 'admin123');
      expect(admin.user!.role, UserRole.admin);
      final official = await signIn('official@shop.com', 'seller123');
      expect(official.user!.isSeller, isTrue);
      expect(official.user!.shopName, 'Sunset Official');

      final products = ProductProvider(db);
      await products.load();
      expect(products.visibleProducts.every((p) => p.shopName != null), isTrue);
    });

    test('a seller only sees and manages products of their shop', () async {
      final tech = await signIn('tech@shop.com', 'seller123');
      final products = ProductProvider(db);
      await products.load();
      products.setViewer(tech.user);
      expect(products.visibleProducts, hasLength(2));
      expect(products.visibleProducts.every(tech.user!.canManage), isTrue);

      products.setViewer(null);
      final other = products.visibleProducts.firstWhere((p) => p.shopName == 'Sunset Official');
      expect(tech.user!.canManage(other), isFalse);
    });

    test('sales are split by shop for sellers and admin', () async {
      final customer = AuthProvider(db, await SharedPreferences.getInstance());
      await customer.register('Buyer', 'buyer@test.com', 'secret1');
      await customer.login('buyer@test.com', 'secret1', rememberMe: false);
      final products = ProductProvider(db);
      await products.load();
      final official = products.visibleProducts.firstWhere((p) => p.shopName == 'Sunset Official');
      final tech = products.visibleProducts.firstWhere((p) => p.shopName == 'Tech Corner');

      final cart = CartProvider(db);
      await cart.attachUser(customer.user);
      await cart.add(official, quantity: 2);
      await cart.add(tech);
      await cart.checkout();
      expect(cart.orders.single.total, official.price * 2 + tech.price);

      final techSeller = await signIn('tech@shop.com', 'seller123');
      final techCart = CartProvider(db);
      await techCart.attachUser(techSeller.user);
      expect(techCart.orders.single.total, tech.price);
      expect(techCart.orders.single.customerName, 'Buyer');
      expect(() => techCart.add(official), throwsStateError, reason: 'sellers have no cart');

      final admin = await signIn('admin@shop.com', 'admin123');
      final adminCart = CartProvider(db);
      await adminCart.attachUser(admin.user);
      expect(adminCart.orders.single.total, official.price * 2 + tech.price);
      final byShop = revenueByShop(adminCart.shopSales);
      expect(byShop.map((s) => s.shop).toSet(), {'Sunset Official', 'Tech Corner'});
      expect(byShop.fold<double>(0, (sum, s) => sum + s.total), official.price * 2 + tech.price);
    });

    test('register as seller, admin cannot be registered', () async {
      final auth = AuthProvider(db, await SharedPreferences.getInstance());
      expect(await auth.register('S', 's@test.com', 'secret1', role: UserRole.seller), isNotNull,
          reason: 'shop name required');
      expect(await auth.register('S', 's@test.com', 'secret1', role: UserRole.seller, shopName: 'S Store'), isNull);
      expect(await auth.register('X', 'x@test.com', 'secret1', role: UserRole.admin), isNotNull);
      final seller = await db.findUserByEmail('s@test.com');
      expect(seller!.role, UserRole.seller);
      expect(seller.shopName, 'S Store');
    });

    test('admin changes roles, but not their own', () async {
      final admin = await signIn('admin@shop.com', 'admin123');
      await admin.register('Cus', 'cus@test.com', 'secret1');
      final cus = (await admin.allUsers()).firstWhere((u) => u.email == 'cus@test.com');
      await admin.setRole(cus, UserRole.seller);
      final promoted = await db.findUserByEmail('cus@test.com');
      expect(promoted!.role, UserRole.seller);
      expect(promoted.shopName, "Cus's Shop");
      expect(() => admin.setRole(admin.user!, UserRole.customer), throwsStateError);

      final official = await signIn('official@shop.com', 'seller123');
      expect(() => official.allUsers(), throwsStateError);
    });

    test('a version 1 database keeps its data after upgrade', () async {
      final dir = await Directory.systemTemp.createTemp('prm393');
      final path = '${dir.path}/v1.db';
      final v1 = await databaseFactoryFfiNoIsolate.openDatabase(path, options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          await d.execute('CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL)');
          await d.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT NOT NULL, price REAL NOT NULL, image TEXT)');
          await d.execute('CREATE TABLE cart_items(user_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity INTEGER NOT NULL, PRIMARY KEY (user_id, product_id))');
          await d.execute('CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, total REAL NOT NULL, created_at TEXT NOT NULL)');
          await d.execute('CREATE TABLE order_items(id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL, product_name TEXT NOT NULL, unit_price REAL NOT NULL, quantity INTEGER NOT NULL)');
          await d.insert('users', {'full_name': 'Old', 'email': 'old@test.com', 'password_hash': hashPassword('secret1')});
          await d.insert('products', {'name': 'Old product', 'description': 'd', 'price': 10.0});
          await d.insert('orders', {'user_id': 1, 'total': 20.0, 'created_at': DateTime(2026, 1, 1).toIso8601String()});
          await d.insert('order_items', {'order_id': 1, 'product_name': 'Old product', 'unit_price': 10.0, 'quantity': 2});
        },
      ));
      await v1.close();

      final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfiNoIsolate);
      final old = await upgraded.findUserByEmail('old@test.com');
      expect(old!.role, UserRole.customer);
      expect(await upgraded.findUserByEmail('admin@shop.com'), isNotNull);
      final products = await upgraded.getProducts();
      expect(products.firstWhere((p) => p.name == 'Old product').shopName, 'Sunset Official');
      final sales = await upgraded.getShopSales();
      expect(sales.single.shopName, 'Sunset Official');
      expect(sales.single.total, 20);
      await upgraded.close();
      await dir.delete(recursive: true);
    });
  });
}
