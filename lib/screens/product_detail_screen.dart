import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/revenue.dart';
import '../widgets/cart_actions.dart';
import '../widgets/decor.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  Future<void> _confirmDelete() async {
    final provider = context.read<ProductProvider>();
    final product = provider.findById(widget.productId);
    if (product == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_rounded,
          size: 36,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: const Text('Delete product'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final cart = context.read<CartProvider>();
    await provider.delete(product.id!);
    await cart.refresh(); // the database also removed it from carts
    messenger.showSnackBar(SnackBar(content: Text('Deleted ${product.name}')));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final product = context.watch<ProductProvider>().findById(widget.productId);
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Product not found')),
      );
    }
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final user = context.watch<AuthProvider>().user;
    final canManage = user?.canManage(product) ?? false;
    final isCustomer = user?.isCustomer ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                Hero(
                  tag: 'product-image-${product.id}',
                  child: ProductImage(
                    source: product.image,
                    height: 380,
                    radius: 0,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6E1F4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          product.name,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.shopName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: AppColors.violet,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sold by ${product.shopName}',
                                style: text.titleSmall?.copyWith(
                                  color: AppColors.violet,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.sunset,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            formatPrice(product.price),
                            style: text.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            _Perk(
                              icon: Icons.local_shipping_outlined,
                              label: 'Fast delivery',
                            ),
                            SizedBox(width: 10),
                            _Perk(
                              icon: Icons.verified_outlined,
                              label: 'Genuine',
                            ),
                            SizedBox(width: 10),
                            _Perk(
                              icon: Icons.autorenew_rounded,
                              label: '7-day return',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Description',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: text.bodyLarge?.copyWith(
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: topInset + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GlassIconButton(
                    dark: true,
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  if (canManage) ...[
                    GlassIconButton(
                      dark: true,
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () =>
                          context.push('/products/${product.id}/edit'),
                    ),
                    const SizedBox(width: 8),
                    GlassIconButton(
                      dark: true,
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: _confirmDelete,
                    ),
                  ],
                  if (isCustomer)
                    const Material(
                      color: Color(0x47000000),
                      shape: CircleBorder(),
                      child: IconTheme(
                        data: IconThemeData(color: Colors.white),
                        child: CartIconButton(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: !isCustomer
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Row(
                      children: [
                        _QuantityPill(
                          quantity: _quantity,
                          onMinus: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          onPlus: () => setState(() => _quantity++),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GradientButton(
                            label: 'Add to cart',
                            icon: Icons.add_shopping_cart_rounded,
                            onPressed: () => addToCartWithFeedback(
                              context,
                              product,
                              quantity: _quantity,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.violet),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  const _QuantityPill({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}
