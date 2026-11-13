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
  List<OrderRecord> _referredOrders = [];
  List<AffiliateSummary> _affiliates = [];

  List<CartItem> get items => _items;

  /// Customer: orders placed. Seller: the shop's part of each order.
  /// Admin: every order.
  List<OrderRecord> get orders => _orders;

  /// Admin only: each shop's part of each order, for the per-shop breakdown.
  List<OrderRecord> get shopSales => _shopSales;

  /// Customer only: orders other customers placed with this user's code.
  List<OrderRecord> get referredOrders => _referredOrders;

  /// Admin only: every affiliate's results.
  List<AffiliateSummary> get affiliates => _affiliates;
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
    final isAdmin = user?.isAdmin == true;
    _shopSales = isAdmin ? await _db.getShopSales() : [];
    _affiliates = isAdmin ? await _db.getAffiliateSummaries() : [];
    _referredOrders = user != null && user.isCustomer
        ? await _db.getReferredOrders(user.id!)
        : [];
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
  /// Throws an [ArgumentError] when [affiliateCode] is not valid.
  Future<int?> checkout({String? affiliateCode}) async {
    final orderId = await _db.checkout(
      _requireUser(),
      affiliateCode: affiliateCode,
    );
    await refresh();
    return orderId;
  }

  /// Checks [code] before payment, so a typo never costs a paid order.
  /// Returns an error message, or null when the code can be used.
  Future<String?> validateAffiliateCode(String code) async {
    if (code.trim().isEmpty) return null;
    final affiliate = await _db.findUserByRefCode(code);
    if (affiliate == null || !affiliate.isCustomer) {
      return 'Affiliate code ${code.trim().toUpperCase()} does not exist';
    }
    if (affiliate.id == _requireUser()) {
      return 'You cannot use your own affiliate code';
    }
    return null;
  }

  /// Only customers shop; sellers and admins have no cart.
  int _requireUser() {
    final user = _user;
    if (user == null) throw StateError('No user is logged in');
    if (!user.isCustomer) throw StateError('Only customers have a cart');
    return user.id!;
  }
}
