import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/revenue.dart';
import '../widgets/decor.dart';
import '../widgets/product_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _confirmRemove(BuildContext context, CartItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.remove_shopping_cart_outlined, size: 36),
        title: const Text('Remove item'),
        content: Text('Remove ${item.product.name} from the cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await context.read<CartProvider>().remove(item.product);
    messenger.showSnackBar(
      SnackBar(content: Text('Removed ${item.product.name}')),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final total = cart.total;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.payments_outlined, size: 36),
        title: const Text('Checkout'),
        content: Text(
          'Pay ${formatPrice(total)} for ${cart.itemCount} item(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
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
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GradientBadgeIcon(icon: Icons.check_rounded),
              const SizedBox(height: 18),
              Text(
                'Order #$orderId placed',
                style: Theme.of(ctx).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thank you! Your order is on its way.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              GradientText(
                formatPrice(total),
                style: Theme.of(ctx).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/revenue');
                      },
                      child: const Text('View revenue'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ),
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(label: Text('${cart.itemCount} item(s)')),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GradientBadgeIcon(
                      icon: Icons.shopping_bag_outlined,
                      size: 110,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Your cart is empty',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Good things are waiting on the shelf.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 220,
                      child: GradientButton(
                        label: 'Browse products',
                        icon: Icons.storefront_rounded,
                        onPressed: () => context.go('/products'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return EntranceAnimation(
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        ProductImage(
                          source: item.product.image,
                          size: 84,
                          radius: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _confirmRemove(context, item),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${formatPrice(item.product.price)} each',
                                style: text.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: GradientText(
                                      formatPrice(item.subtotal),
                                      style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _Stepper(
                                    quantity: item.quantity,
                                    onMinus: item.quantity > 1
                                        ? () => cart.setQuantity(
                                            item.product,
                                            item.quantity - 1,
                                          )
                                        : () => _confirmRemove(context, item),
                                    onPlus: () => cart.setQuantity(
                                      item.product,
                                      item.quantity + 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                decoration: BoxDecoration(
                  gradient: AppColors.night,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: text.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            formatPrice(cart.total),
                            style: text.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: GradientButton(
                        label: 'Checkout',
                        icon: Icons.lock_rounded,
                        onPressed: () => _checkout(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String tip,
      VoidCallback onTap, {
      bool filled = false,
    }) => Tooltip(
      message: tip,
      child: Material(
        color: filled ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Decrease', onMinus),
          SizedBox(
            width: 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          button(Icons.add_rounded, 'Increase', onPlus, filled: true),
        ],
      ),
    );
  }
}
