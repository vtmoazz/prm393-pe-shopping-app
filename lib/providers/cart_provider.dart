import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/models.dart';

/// Cart and order history of the logged-in user.
class CartProvider extends ChangeNotifier {
  CartProvider(this._db);

  final AppDatabase _db;

  int? _userId;
  List<CartItem> _items = [];
  List<OrderRecord> _orders = [];

  List<CartItem> get items => _items;
  List<OrderRecord> get orders => _orders;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get total => _items.fold(0, (sum, i) => sum + i.subtotal);

  /// Switches the cart to [userId] (null after logout).
  Future<void> attachUser(int? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    await refresh();
  }

  Future<void> refresh() async {
    final id = _userId;
    _items = id == null ? [] : await _db.getCart(id);
    _orders = id == null ? [] : await _db.getOrders(id);
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

  int _requireUser() {
    final id = _userId;
    if (id == null) throw StateError('No user is logged in');
    return id;
  }
}
