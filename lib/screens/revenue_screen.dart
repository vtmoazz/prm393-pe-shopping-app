import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/revenue.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  RevenuePeriod _period = RevenuePeriod.all;
  DateTime _date = DateTime.now();

  String get _periodLabel => switch (_period) {
    RevenuePeriod.all => 'All time',
    RevenuePeriod.day => DateFormat('dd/MM/yyyy').format(_date),
    RevenuePeriod.month => DateFormat('MM/yyyy').format(_date),
    RevenuePeriod.year => DateFormat('yyyy').format(_date),
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final role = context.watch<AuthProvider>().user?.role ?? UserRole.customer;
    final allOrders = cart.orders;
    final orders = filterOrders(allOrders, _period, _date);
    final shops = role == UserRole.admin
        ? revenueByShop(filterOrders(cart.shopSales, _period, _date))
        : const <ShopRevenue>[];
    final total = totalRevenue(orders);
    final buckets = revenueBuckets(allOrders, _period, _date);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (role) {
          UserRole.customer => 'My orders',
          UserRole.seller => 'Shop sales',
          UserRole.admin => 'Platform revenue',
        }),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _TotalCard(
            title: role == UserRole.customer ? 'Total spent' : 'Total revenue',
            label: _periodLabel,
            total: total,
            orderCount: orders.length,
            average: orders.isEmpty ? 0 : total / orders.length,
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (period, label) in const [
                  (RevenuePeriod.all, 'All'),
                  (RevenuePeriod.day, 'Day'),
                  (RevenuePeriod.month, 'Month'),
                  (RevenuePeriod.year, 'Year'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _period == period,
                      onSelected: (_) => setState(() => _period = period),
                    ),
                  ),
              ],
            ),
          ),
          if (_period != RevenuePeriod.all) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(_periodLabel),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _BarChart(buckets: buckets),
          if (role == UserRole.admin) ...[
            const SizedBox(height: 22),
            Text(
              'Revenue by shop',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (shops.isEmpty)
              const Text(
                'No shop sales in this period',
                style: TextStyle(color: AppColors.muted),
              )
            else
              _ShopBreakdown(shops: shops),
          ],
          const SizedBox(height: 22),
          Text(
            'Orders',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No orders in this period',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            for (final order in orders)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.violet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id}',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (order.customerName != null)
                            Text(
                              'by ${order.customerName}',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.violet,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            '${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)} · ${order.itemCount} item(s)',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatPrice(order.total),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.title,
    required this.label,
    required this.total,
    required this.orderCount,
    required this.average,
  });

  final String title;
  final String label;
  final double total;
  final int orderCount;
  final double average;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget stat(String title, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: text.labelSmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.sunset,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.magenta.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_graph_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '$title · $label',
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              formatPrice(value),
              style: text.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('Orders', '$orderCount'),
              const SizedBox(width: 10),
              stat('Avg. order', formatPrice(average)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopBreakdown extends StatelessWidget {
  const _ShopBreakdown({required this.shops});

  final List<ShopRevenue> shops;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final best = shops.first.total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (final shop in shops)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: AppColors.violet,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shop.shop,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        formatPrice(shop.total),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: best == 0 ? 0 : shop.total / best,
                      minHeight: 8,
                      backgroundColor: AppColors.canvas,
                      color: AppColors.violet,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${shop.orders} order(s)',
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.buckets});

  final List<RevenueBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxValue = buckets.fold<double>(
      0,
      (m, b) => b.value > m ? b.value : m,
    );
    // Show at most about 8 labels so the axis stays readable.
    final labelEvery = (buckets.length / 8).ceil().clamp(1, 99);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: buckets.isEmpty || maxValue == 0
                ? const Center(
                    child: Text(
                      'No revenue to chart yet',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < buckets.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: buckets.length > 16 ? 1 : 4,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Tooltip(
                                  message:
                                      '${buckets[i].label}: ${formatPrice(buckets[i].value)}',
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 40,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: buckets[i].value / maxValue,
                                      ),
                                      duration: Duration(
                                        milliseconds: 500 + 20 * i,
                                      ),
                                      curve: Curves.easeOutBack,
                                      builder: (context, f, _) => Container(
                                        height: 4 + 112 * f.clamp(0, 1.2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          gradient: buckets[i].value > 0
                                              ? const LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    AppColors.violet,
                                                    AppColors.coral,
                                                  ],
                                                )
                                              : null,
                                          color: buckets[i].value > 0
                                              ? null
                                              : AppColors.canvas,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 14,
                                  child: i % labelEvery == 0
                                      ? FittedBox(
                                          child: Text(
                                            buckets[i].label,
                                            style: text.labelSmall?.copyWith(
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
