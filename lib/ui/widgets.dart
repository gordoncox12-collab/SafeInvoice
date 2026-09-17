import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/money.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.currency = 'ZAR', this.style});

  final double amount;
  final String currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(Za.money(amount, currency), style: style);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvoiceStatus.draft => ('Draft', Colors.blueGrey),
      InvoiceStatus.sent => ('Sent', Colors.blue),
      InvoiceStatus.paid => ('Paid', Colors.green),
      InvoiceStatus.overdue => ('Overdue', Colors.red),
      InvoiceStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.shade400),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  return Future.value();
}

String niceEnum(Enum value) {
  final raw = value.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}');
  final s = raw.trim();
  return s[0].toUpperCase() + s.substring(1);
}
