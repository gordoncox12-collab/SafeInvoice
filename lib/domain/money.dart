import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Za {
  static const localeName = 'en_ZA';
  static const timeZone = 'Africa/Johannesburg';

  static final DateFormat _date = DateFormat('dd MMM yyyy', localeName);
  static final NumberFormat _zar = NumberFormat.currency(
    locale: localeName,
    symbol: 'R',
    decimalDigits: 2,
  );

  static String newId() => _uuid.v4();

  static int nowMillis() => DateTime.now().millisecondsSinceEpoch;

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static int todayMillis() => today().millisecondsSinceEpoch;

  static int plusDays(int epochMillis, int days) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    return DateTime(d.year, d.month, d.day).add(Duration(days: days)).millisecondsSinceEpoch;
  }

  static String date(int epochMillis) {
    return _date.format(DateTime.fromMillisecondsSinceEpoch(epochMillis));
  }

  static String money(double amount, [String currency = 'ZAR']) {
    if (currency == 'ZAR') return _zar.format(amount);
    return NumberFormat.currency(locale: localeName, name: currency, decimalDigits: 2)
        .format(amount);
  }

  static int currentYear() => DateTime.now().year;
}

class MoneyTotals {
  const MoneyTotals({
    required this.subtotal,
    required this.discount,
    required this.net,
    required this.vat,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double net;
  final double vat;
  final double total;
}

class Money {
  static double round(double value) =>
      double.parse(value.toStringAsFixed(2));

  static double lineTotal(double quantity, double unitPrice) =>
      round(quantity * unitPrice);

  static MoneyTotals totals({
    required List<double> lineTotals,
    double discountAmount = 0,
    double discountPercent = 0,
    double vatPercent = 15,
  }) {
    final subtotal = round(lineTotals.fold<double>(0, (a, b) => a + b));
    final discount = round(discountAmount + subtotal * discountPercent / 100.0);
    final net = round((subtotal - discount).clamp(0, double.infinity));
    final vat = round(net * vatPercent / 100.0);
    final total = round(net + vat);
    return MoneyTotals(
      subtotal: subtotal,
      discount: discount,
      net: net,
      vat: vat,
      total: total,
    );
  }
}

String trimNum(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return Money.round(value).toString();
}
