import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../domain/balance.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import 'app_controller.dart';
import 'widgets.dart';

Future<void> showPayOutstandingDialog(
  BuildContext context, {
  required String customerId,
  String? invoiceId,
}) async {
  final app = context.read<AppController>();
  final customer = app.customers.where((c) => c.id == customerId).firstOrNull;
  if (customer == null) return;
  final unpaid = app.unpaidOrders(customerId: customerId, excludeInvoiceId: null);
  final target = invoiceId == null ? unpaid : unpaid.where((o) => o.invoice.id == invoiceId).toList();
  if (target.isEmpty) {
    await showSnack(context, 'Nothing outstanding to pay.');
    return;
  }
  final currency = target.first.invoice.currency;
  final remaining = Money.round(target.fold<double>(0, (a, o) => a + o.balance.invoiceOutstanding));
  final amount = TextEditingController(text: trimNum(remaining));
  var method = PaymentOption.eft;
  var occurredAt = Za.nowMillis();
  final reference = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) {
        final parsed = double.tryParse(amount.text) ?? 0;
        final plan = allocateOldestFirst(target, parsed);
        return AlertDialog(
          title: Text(invoiceId == null ? 'Pay outstanding' : 'Pay this invoice'),
          content: SingleChildScrollView(
            child: PayOutstandingForm(
              customerName: customer.name,
              remaining: remaining,
              currency: currency,
              amount: amount,
              method: method,
              occurredAt: occurredAt,
              reference: reference,
              allocations: plan,
              invoices: {
                for (final o in target) o.invoice.id: o.invoice,
              },
              onAmountChanged: () => setLocal(() {}),
              onMethod: (v) => setLocal(() => method = v),
              onDate: (v) => setLocal(() => occurredAt = v),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record payment')),
          ],
        );
      },
    ),
  );
  if (ok == true) {
    final parsed = double.tryParse(amount.text) ?? 0;
    try {
      final made = await app.payOutstanding(
        customerId: customerId,
        amount: parsed,
        method: paymentOptionLabel(method),
        reference: reference.text.trim().isEmpty ? null : reference.text.trim(),
        occurredAt: occurredAt,
        invoiceId: invoiceId,
      );
      if (context.mounted) {
        await showSnack(context, 'Recorded ${made.length} payment${made.length == 1 ? '' : 's'}');
      }
    } catch (e) {
      if (context.mounted) {
        await showSnack(context, e is InvoiceSaveException ? e.message : 'Could not record the payment.');
      }
    }
  }
  amount.dispose();
  reference.dispose();
}

class PayOutstandingForm extends StatelessWidget {
  const PayOutstandingForm({
    super.key,
    required this.customerName,
    required this.remaining,
    required this.currency,
    required this.amount,
    required this.method,
    required this.occurredAt,
    required this.reference,
    required this.allocations,
    required this.invoices,
    required this.onAmountChanged,
    required this.onMethod,
    required this.onDate,
  });

  final String customerName;
  final double remaining;
  final String currency;
  final TextEditingController amount;
  final PaymentOption method;
  final int occurredAt;
  final TextEditingController reference;
  final List<PaymentAllocation> allocations;
  final Map<String, Invoice> invoices;
  final VoidCallback onAmountChanged;
  final ValueChanged<PaymentOption> onMethod;
  final ValueChanged<int> onDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(customerName, style: Theme.of(context).textTheme.titleSmall),
        OutstandingMoney(remaining, currency: currency, style: Theme.of(context).textTheme.titleMedium),
        Text('Oldest unpaid orders are settled first.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'Amount to allocate'),
          keyboardType: TextInputType.number,
          onChanged: (_) => onAmountChanged(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Payment date'),
          subtitle: Text(Za.date(occurredAt)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.fromMillisecondsSinceEpoch(occurredAt),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) onDate(picked.millisecondsSinceEpoch);
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in PaymentOption.values)
              ChoiceChip(
                label: Text(paymentOptionLabel(option)),
                selected: method == option,
                onSelected: (on) {
                  if (on) onMethod(option);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference (optional)')),
        if (allocations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Will apply to', style: Theme.of(context).textTheme.labelLarge),
          for (final a in allocations)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(invoices[a.invoiceId]?.number ?? a.invoiceId),
              trailing: OutstandingMoney(a.amount, currency: currency),
            ),
        ],
      ],
    );
  }
}

class UnpaidOrdersList extends StatelessWidget {
  const UnpaidOrdersList({
    super.key,
    required this.orders,
    this.currency = 'ZAR',
    this.customerNameOf,
    this.onPay,
    this.compact = false,
  });

  final List<UnpaidOrder> orders;
  final String currency;
  final String Function(Invoice)? customerNameOf;
  final void Function(UnpaidOrder order)? onPay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Text('No unpaid orders.', style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: [
        for (final order in orders)
          ListTile(
            contentPadding: compact ? EdgeInsets.zero : null,
            title: Text(
              customerNameOf == null
                  ? order.invoice.number
                  : '${order.invoice.number} · ${customerNameOf!(order.invoice)}',
            ),
            subtitle: Text(
              'Invoice ${Za.date(order.invoice.issueDate)} · due ${Za.date(order.invoice.dueDate)}'
              ' · total ${Za.money(order.invoice.total, order.invoice.currency)}'
              ' · paid ${Za.money(order.balance.amountPaid, order.invoice.currency)}',
            ),
            trailing: OutstandingMoney(order.balance.invoiceOutstanding, currency: order.invoice.currency),
            isThreeLine: true,
            onTap: () => context.push('/invoice-view/${order.invoice.id}'),
            onLongPress: onPay == null ? null : () => onPay!(order),
          ),
      ],
    );
  }
}

class OutstandingBanner extends StatelessWidget {
  const OutstandingBanner({
    super.key,
    required this.amount,
    required this.currency,
    this.label = 'Outstanding',
    this.onPay,
    this.onSeeAll,
  });

  final double amount;
  final String currency;
  final String label;
  final VoidCallback? onPay;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: outstandingCrimson.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: outstandingCrimson)),
            OutstandingMoney(amount, currency: currency, style: Theme.of(context).textTheme.headlineSmall),
            if (onPay != null || onSeeAll != null)
              Wrap(
                spacing: 8,
                children: [
                  if (onPay != null && amount > 0)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: outstandingCrimson),
                      onPressed: onPay,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pay outstanding'),
                    ),
                  if (onSeeAll != null)
                    TextButton(onPressed: onSeeAll, child: const Text('Unpaid orders')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
