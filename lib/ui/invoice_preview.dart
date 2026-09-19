import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/money.dart';
import 'widgets.dart';

/// On-device paper preview of the invoice that will be written to the PDF.
class InvoicePaperPreview extends StatelessWidget {
  const InvoicePaperPreview({
    super.key,
    required this.business,
    required this.customer,
    required this.invoice,
    required this.items,
    this.logoFile,
    this.signatureFile,
    this.podSignatureFile,
  });

  final Business business;
  final Customer customer;
  final Invoice invoice;
  final List<InvoiceLineItem> items;
  final File? logoFile;
  final File? signatureFile;
  final File? podSignatureFile;

  MoneyTotals get totals => Money.totals(
        lineTotals: items.map((i) => Money.lineTotal(i.quantity, i.unitPrice)).toList(),
        taxable: items.map((i) => i.taxable).toList(),
        discountAmount: invoice.discountAmount,
        discountPercent: invoice.discountPercent,
        vatPercent: invoice.vatPercent,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF15201E), fontSize: 13, height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (logoFile != null && logoFile!.existsSync())
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 88, maxHeight: 56),
                        child: DiskImage(logoFile!, height: 56),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      business.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TAX INVOICE', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                      Text(invoice.number),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (business.addressLine1.isNotEmpty) Text(business.addressLine1),
              if (business.email.isNotEmpty || business.phone.isNotEmpty)
                Text([business.email, business.phone].where((s) => s.isNotEmpty).join(' · ')),
              if (business.vatNumber != null) Text('VAT ${business.vatNumber}'),
              const SizedBox(height: 16),
              Text('Bill to', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (customer.email != null) Text(customer.email!),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 4,
                children: [
                  Text('Issued ${Za.dateTime(invoice.displayIssuedAt)}'),
                  Text('Due ${Za.date(invoice.dueDate)}'),
                  Text(invoice.currency, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              if (invoice.generatedAt != null) Text('Generated ${Za.dateTime(invoice.generatedAt!)}'),
              if (invoice.paymentMethod != null)
                Text(
                  'Payment ${paymentOptionLabel(invoice.paymentMethod!)}'
                  '${invoice.paymentNote != null && invoice.paymentNote!.trim().isNotEmpty ? ' · ${invoice.paymentNote}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 12),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.8),
                  1: FlexColumnWidth(0.8),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.8),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: theme.colorScheme.primary),
                    children: const [
                      _HeadCell('Description'),
                      _HeadCell('Qty', align: TextAlign.right),
                      _HeadCell('Unit', align: TextAlign.right),
                      _HeadCell('Amount', align: TextAlign.right),
                    ],
                  ),
                  for (final item in [...items]..sort((a, b) => a.position.compareTo(b.position)))
                    TableRow(
                      children: [
                        _Cell(item.description),
                        _Cell(trimNum(item.quantity), align: TextAlign.right),
                        _Cell(Za.money(item.unitPrice, invoice.currency), align: TextAlign.right),
                        _Cell(
                          Za.money(Money.lineTotal(item.quantity, item.unitPrice), invoice.currency),
                          align: TextAlign.right,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      _TotalRow('Subtotal', Za.money(totals.subtotal, invoice.currency)),
                      if (totals.discount > 0)
                        _TotalRow('Discount', '- ${Za.money(totals.discount, invoice.currency)}'),
                      _TotalRow('VAT ${trimNum(invoice.vatPercent)}%', Za.money(totals.vat, invoice.currency)),
                      _TotalRow('Total', Za.money(totals.total, invoice.currency), emphasize: true),
                    ],
                  ),
                ),
              ),
              if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Notes', style: theme.textTheme.titleSmall),
                Text(invoice.notes!),
              ],
              const SizedBox(height: 16),
              Text('Authorised signature', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (signatureFile != null && signatureFile!.existsSync())
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
                  child: DiskImage(signatureFile!, height: 72),
                )
              else
                Container(
                  width: 220,
                  height: 48,
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black54))),
                ),
              const SizedBox(height: 16),
              Text('Received by / Delivery receipt', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (podSignatureFile != null && podSignatureFile!.existsSync())
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
                  child: DiskImage(podSignatureFile!, height: 72),
                )
              else
                Container(
                  width: 220,
                  height: 48,
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black54))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(text, textAlign: align, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(text, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(child: Text(value, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
