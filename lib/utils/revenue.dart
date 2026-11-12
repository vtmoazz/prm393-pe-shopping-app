import 'package:intl/intl.dart';

import '../models/models.dart';

enum RevenuePeriod { all, day, month, year }

final _currency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

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
    RevenuePeriod.day =>
      d.year == date.year && d.month == date.month && d.day == date.day,
  };
  return orders.where((o) => matches(o.createdAt)).toList();
}

double totalRevenue(Iterable<OrderRecord> orders) =>
    orders.fold(0, (sum, o) => sum + o.total);

/// One bar of the revenue chart.
typedef RevenueBucket = ({String label, double value});

/// Splits the orders of [period] into chart bars: hours of the day, days of
/// the month, months of the year, or one bar per year for all time.
List<RevenueBucket> revenueBuckets(
  List<OrderRecord> orders,
  RevenuePeriod period,
  DateTime date,
) {
  final inPeriod = filterOrders(orders, period, date);
  double sumWhere(bool Function(DateTime d) test) =>
      totalRevenue(inPeriod.where((o) => test(o.createdAt)));

  switch (period) {
    case RevenuePeriod.day:
      return [
        for (var h = 0; h < 24; h++)
          (label: '${h}h', value: sumWhere((d) => d.hour == h)),
      ];
    case RevenuePeriod.month:
      final days = DateTime(date.year, date.month + 1, 0).day;
      return [
        for (var day = 1; day <= days; day++)
          (label: '$day', value: sumWhere((d) => d.day == day)),
      ];
    case RevenuePeriod.year:
      return [
        for (var m = 1; m <= 12; m++)
          (label: 'T$m', value: sumWhere((d) => d.month == m)),
      ];
    case RevenuePeriod.all:
      final years = inPeriod.map((o) => o.createdAt.year).toSet().toList()
        ..sort();
      return [
        for (final y in years)
          (label: '$y', value: sumWhere((d) => d.year == y)),
      ];
  }
}
