import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../utils/revenue.dart';
import '../widgets/product_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _confirmRemove(BuildContext context, CartItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item'),
        content: Text('Remove ${item.product.name} from the cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<CartProvider>().remove(item.product);
    messenger.showSnackBar(SnackBar(content: Text('Removed ${item.product.name}')));
  }

  Future<void> _checkout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final total = cart.total;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout'),
        content: Text('Pay ${formatPrice(total)} for ${cart.itemCount} item(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final orderId = await cart.checkout();
    if (!context.mounted || orderId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 12),
              Text('Order #$orderId placed', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Total: ${formatPrice(total)}'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/revenue');
                    },
                    child: const Text('View revenue'),
                  ),
                  FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_shopping_cart_outlined, size: 64),
                  const SizedBox(height: 12),
                  const Text('Your cart is empty'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.go('/products'),
                    child: const Text('Browse products'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ProductImage(source: item.product.image, size: 64),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(formatPrice(item.product.price)),
                              Text('Subtotal: ${formatPrice(item.subtotal)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Decrease',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: item.quantity > 1
                              ? () => cart.setQuantity(item.product, item.quantity - 1)
                              : () => _confirmRemove(context, item),
                        ),
                        Text('${item.quantity}', style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          tooltip: 'Increase',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => cart.setQuantity(item.product, item.quantity + 1),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmRemove(context, item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total'),
                          Text(formatPrice(cart.total),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  )),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _checkout(context),
                      icon: const Icon(Icons.payment),
                      label: const Text('Checkout'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
