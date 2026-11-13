import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/models.dart';

enum PriceSort { none, ascending, descending }

class ProductProvider extends ChangeNotifier {
  ProductProvider(this._db);

  final AppDatabase _db;

  List<Product> _products = [];
  AppUser? _viewer;
  String _query = '';
  PriceSort _sort = PriceSort.none;
  bool _loading = false;

  bool get loading => _loading;
  String get query => _query;
  PriceSort get sort => _sort;

  /// Sets who is looking: a seller only sees the products of their shop.
  void setViewer(AppUser? user) {
    if (_viewer?.id == user?.id && _viewer?.role == user?.role) return;
    _viewer = user;
    notifyListeners();
  }

  /// Products after applying the role scope, search query and price sort.
  List<Product> get visibleProducts {
    final viewer = _viewer;
    final q = _query.trim().toLowerCase();
    final result = _products
        .where((p) => viewer?.isSeller != true || p.sellerId == viewer!.id)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case PriceSort.ascending:
        result.sort((a, b) => a.price.compareTo(b.price));
      case PriceSort.descending:
        result.sort((a, b) => b.price.compareTo(a.price));
      case PriceSort.none:
        break;
    }
    return result;
  }

  Product? findById(int id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _products = await _db.getProducts();
    _loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSort(PriceSort value) {
    _sort = value;
    notifyListeners();
  }

  Future<void> add(Product product) async {
    await _db.insertProduct(product);
    await load();
  }

  Future<void> update(Product product) async {
    await _db.updateProduct(product);
    await load();
  }

  Future<void> delete(int id) async {
    await _db.deleteProduct(id);
    await load();
  }
}
