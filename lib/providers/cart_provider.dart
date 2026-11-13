import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/models.dart';

/// Cart and orders of the logged-in account, seen through its role:
/// a customer's own orders, a seller's shop sales, or every platform order.
class CartProvider extends ChangeNotifier {
  CartProvider(this._db);

  final AppDatabase _db;

  AppUser? _user;
  List<CartItem> _items = [];
  List<OrderRecord> _orders = [];
  List<OrderRecord> _shopSales = [];

  List<CartItem> get items => _items;

  /// Customer: orders placed. Seller: the shop's part of each order.
  /// Admin: every order.
  List<OrderRecord> get orders => _orders;

  /// Admin only: each shop's part of each order, for the per-shop breakdown.
  List<OrderRecord> get shopSales => _shopSales;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get total => _items.fold(0, (sum, i) => sum + i.subtotal);

  /// Switches to [user] (null after logout).
  Future<void> attachUser(AppUser? user) async {
    if (_user?.id == user?.id && _user?.role == user?.role) return;
    _user = user;
    await refresh();
  }

  Future<void> refresh() async {
    final user = _user;
    _items = user != null && user.isCustomer ? await _db.getCart(user.id!) : [];
    _orders = switch (user?.role) {
      null => [],
      UserRole.customer => await _db.getOrders(user!.id!),
      UserRole.seller => await _db.getShopSales(sellerId: user!.id),
      UserRole.admin => await _db.getAllOrders(),
    };
    _shopSales = user?.isAdmin == true ? await _db.getShopSales() : [];
    notifyListeners();
  }

  Future<void> add(Product product, {int quantity = 1}) async {
    await _db.addToCart(_requireUser(), product.id!, quantity: quantity);
    await refresh();
  }

  Future<void> setQuantity(Product product, int quantity) async {
    await _db.setCartQuantity(_requireUser(), product.id!, quantity);
    await refresh();
  }

  Future<void> remove(Product product) async {
    await _db.removeFromCart(_requireUser(), product.id!);
    await refresh();
  }

  /// Returns the new order id, or null when the cart was empty.
  Future<int?> checkout() async {
    final orderId = await _db.checkout(_requireUser());
    await refresh();
    return orderId;
  }

  /// Only customers shop; sellers and admins have no cart.
  int _requireUser() {
    final user = _user;
    if (user == null) throw StateError('No user is logged in');
    if (!user.isCustomer) throw StateError('Only customers have a cart');
    return user.id!;
  }
}
