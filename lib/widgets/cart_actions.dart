import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/cart_provider.dart';

/// Adds [product] to the cart and confirms with a SnackBar.
Future<void> addToCartWithFeedback(
  BuildContext context,
  Product product, {
  int quantity = 1,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await context.read<CartProvider>().add(product, quantity: quantity);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Added ${product.name} to cart'),
        action: SnackBarAction(
          label: 'VIEW CART',
          onPressed: () => context.push('/cart'),
        ),
      ),
    );
}

/// App bar cart icon with the number of items.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().itemCount;
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: const Color(0xFFFFC15E),
        textColor: const Color(0xFF1B1640),
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
