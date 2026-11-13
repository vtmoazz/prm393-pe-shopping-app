import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../utils/revenue.dart';
import '../widgets/cart_actions.dart';
import '../widgets/decor.dart';
import '../widgets/product_image.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final _search = TextEditingController(
    text: context.read<ProductProvider>().query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, size: 36),
        title: const Text('Log out'),
        content: const Text('Do you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = provider.visibleProducts;
    final user = context.watch<AuthProvider>().user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: () => context.push('/products/new'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add product'),
        ),
        body: Column(
          children: [
            _Header(
              name: user?.fullName ?? '',
              productCount: products.length,
              onLogout: _confirmLogout,
              search: TextField(
                controller: _search,
                onChanged: provider.setQuery,
                decoration: InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search_rounded),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: provider.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            provider.setQuery('');
                          },
                        ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  for (final (sort, label, icon) in const [
                    (PriceSort.none, 'Featured', Icons.auto_awesome_rounded),
                    (
                      PriceSort.ascending,
                      'Price low → high',
                      Icons.trending_up_rounded,
                    ),
                    (
                      PriceSort.descending,
                      'Price high → low',
                      Icons.trending_down_rounded,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 18,
                          color: provider.sort == sort
                              ? Colors.white
                              : AppColors.violet,
                        ),
                        label: Text(label),
                        selected: provider.sort == sort,
                        onSelected: (_) => provider.setSort(sort),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                  ? const _EmptyResult()
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        itemCount: products.length,
                        itemBuilder: (context, index) => EntranceAnimation(
                          index: index,
                          child: _ProductCard(product: products[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.productCount,
    required this.onLogout,
    required this.search,
  });

  final String name;
  final int productCount;
  final VoidCallback onLogout;
  final Widget search;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.sunset,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: text.titleMedium?.copyWith(
                        color: AppColors.magenta,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $name 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$productCount ${productCount == 1 ? 'product' : 'products'} waiting for you',
                          style: text.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    tooltip: 'Revenue',
                    onPressed: () => context.push('/revenue'),
                    icon: const Icon(Icons.insights_rounded),
                  ),
                  const SizedBox(width: 6),
                  const Material(
                    color: Color(0x2EFFFFFF),
                    shape: CircleBorder(),
                    child: IconTheme(
                      data: IconThemeData(color: Colors.white),
                      child: CartIconButton(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GlassIconButton(
                    tooltip: 'Log out',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Find something\nyou will love',
                style: text.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.only(right: 8), child: search),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        shadowColor: AppColors.violet.withValues(alpha: 0.18),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.push('/products/${product.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Hero(
                  tag: 'product-image-${product.id}',
                  child: ProductImage(
                    source: product.image,
                    size: 104,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GradientText(
                              formatPrice(product.price),
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _AddButton(
                            onTap: () =>
                                addToCartWithFeedback(context, product),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add to cart',
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.add_shopping_cart_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GradientBadgeIcon(icon: Icons.search_off_rounded),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try another name',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
