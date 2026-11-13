import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'data/app_database.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();

  final auth = AuthProvider(db, prefs);
  final products = ProductProvider(db);
  final cart = CartProvider(db);

  auth.addListener(() {
    products.setViewer(auth.user);
    cart.attachUser(auth.user);
  });
  await auth.tryAutoLogin();
  await products.load();

  runApp(ShopApp(auth: auth, products: products, cart: cart));
}

class ShopApp extends StatefulWidget {
  const ShopApp({
    super.key,
    required this.auth,
    required this.products,
    required this.cart,
  });

  final AuthProvider auth;
  final ProductProvider products;
  final CartProvider cart;

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  late final _router = buildRouter(widget.auth, widget.products);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.products),
        ChangeNotifierProvider.value(value: widget.cart),
      ],
      child: MaterialApp.router(
        title: 'PRM393 Shop',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
      ),
    );
  }
}
