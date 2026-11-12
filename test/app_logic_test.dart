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
      expect(products.visibleProducts, hasLength(5));

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
      await cart.attachUser(auth.user!.id);

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
  });
}
