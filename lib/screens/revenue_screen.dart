import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
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
    final orders = filterOrders(context.watch<CartProvider>().orders, _period, _date);
    final total = totalRevenue(orders);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Revenue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total revenue · $_periodLabel',
                      style: TextStyle(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(formatPrice(total),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          )),
                  Text('${orders.length} order(s)',
                      style: TextStyle(color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<RevenuePeriod>(
              segments: const [
                ButtonSegment(value: RevenuePeriod.all, label: Text('All')),
                ButtonSegment(value: RevenuePeriod.day, label: Text('Day')),
                ButtonSegment(value: RevenuePeriod.month, label: Text('Month')),
                ButtonSegment(value: RevenuePeriod.year, label: Text('Year')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
          ),
          if (_period != RevenuePeriod.all) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(_periodLabel),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Orders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No orders in this period')),
            )
          else
            for (final order in orders)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text('Order #${order.id}'),
                  subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)} · ${order.itemCount} item(s)'),
                  trailing: Text(formatPrice(order.total),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
        ],
      ),
    );
  }
}
