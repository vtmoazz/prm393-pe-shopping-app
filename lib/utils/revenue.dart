import 'package:intl/intl.dart';

import '../models/models.dart';

enum RevenuePeriod { all, day, month, year }

final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

String formatPrice(num value) => _currency.format(value);

/// Keeps the orders that fall in the same day / month / year as [date].
List<OrderRecord> filterOrders(
  List<OrderRecord> orders,
  RevenuePeriod period,
  DateTime date,
) {
  bool matches(DateTime d) => switch (period) {
        RevenuePeriod.all => true,
        RevenuePeriod.year => d.year == date.year,
        RevenuePeriod.month => d.year == date.year && d.month == date.month,
        RevenuePeriod.day => d.year == date.year && d.month == date.month && d.day == date.day,
      };
  return orders.where((o) => matches(o.createdAt)).toList();
}

double totalRevenue(Iterable<OrderRecord> orders) =>
    orders.fold(0, (sum, o) => sum + o.total);
