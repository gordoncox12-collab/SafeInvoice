import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../data/native_share.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../app_controller.dart';
import '../invoice_preview.dart';
import '../widgets.dart';

Future<void> shareInvoicePdf(
  BuildContext context,
  AppController app,
  Invoice invoice,
  String target,
) async {
  final outcome = await app.shareInvoice(invoice: invoice, target: target);
  if (!context.mounted) return;
  if (outcome.ok) {
    await showSnack(
      context,
      target == 'whatsapp'
          ? 'Opening WhatsApp with the invoice PDF attached'
          : 'Opening Email with the invoice PDF attached',
    );
  } else {
    await showSnack(context, outcome.message ?? 'Could not share the invoice PDF.');
  }
}

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key, this.filter});

  final String? filter;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final draftsOnly = filter == 'drafts';
    final visible = draftsOnly ? app.invoices.where((i) => i.savedForLater).toList() : app.invoices;
    return Scaffold(
      appBar: AppBar(title: Text(draftsOnly ? 'Saved for later' : 'Invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invoice/new'),
        icon: const Icon(Icons.add),
        label: const Text('Invoice'),
      ),
      body: app.invoices.isEmpty
          ? EmptyHint(
              icon: Icons.receipt_long_outlined,
              title: 'No invoices yet',
              body: app.customers.isEmpty
                  ? 'Add a customer first, then create an invoice with catalog line items, 15% VAT and a handwritten signature.'
                  : 'Create an invoice: pick a customer, add products from the catalog, then generate a PDF.',
              actionLabel: app.customers.isEmpty ? 'Add a customer' : 'Create invoice',
              onAction: () => context.push(app.customers.isEmpty ? '/customer-edit/new' : '/invoice/new'),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: !draftsOnly,
                        onSelected: (_) => context.go('/invoices'),
                      ),
                      FilterChip(
                        label: const Text('Saved for later'),
                        selected: draftsOnly,
                        onSelected: (_) => context.go('/invoices?filter=drafts'),
                      ),
                    ],
                  ),
                ),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No drafts saved for later. Use Save for later on an invoice.'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SearchableSelect<Invoice>(
                    label: 'Find invoice',
                    value: null,
                    items: visible,
                    placeholder: 'Tap to search and open',
                    searchHint: 'Search number or customer',
                    labelOf: (inv) => inv.number,
                    subtitleOf: (inv) {
                      final customer = app.customers.where((c) => c.id == inv.customerId).firstOrNull;
                      return '${customer?.name ?? 'Customer'} · ${Za.money(inv.total, inv.currency)} · ${niceEnum(inv.status)}';
                    },
                    onChanged: (inv) {
                      if (inv != null) context.push('/invoice-view/${inv.id}');
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SearchableSelect<Customer>(
                    label: 'Open customer',
                    value: null,
                    items: app.customers,
                    placeholder: 'Tap to search and open',
                    searchHint: 'Search customers',
                    labelOf: (c) => c.name,
                    subtitleOf: (c) => [c.email, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    onChanged: (c) {
                      if (c != null) context.push('/customer/${c.id}');
                    },
                  ),
                ),
                for (final inv in visible)
                  ListTile(
                    title: Text(inv.number),
                    subtitle: Text(
                      '${app.customers.where((c) => c.id == inv.customerId).firstOrNull?.name ?? 'Customer'} · ${Za.date(inv.issueDate)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Za.money(inv.total, inv.currency)),
                        StatusChip(inv.status),
                      ],
                    ),
                    onTap: () => context.push('/invoice-view/${inv.id}'),
                  ),
              ],
            ),
    );
  }
}

class InvoiceEditScreen extends StatefulWidget {
  const InvoiceEditScreen({super.key, required this.id, this.initialCustomerId});

  final String id;
  final String? initialCustomerId;

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  Invoice? invoice;
  List<InvoiceLineItem> items = [];
  bool bump = false;
  bool loaded = false;
  final notes = TextEditingController();
  final terms = TextEditingController(text: 'Payment due within 30 days.');
  final discountAmount = TextEditingController(text: '0');
  final discountPercent = TextEditingController(text: '0');
  final vatPercent = TextEditingController(text: '15');
  final currency = TextEditingController(text: 'ZAR');
  String? customerId;
  String? templateId;
  InvoiceStatus status = InvoiceStatus.draft;
  PaymentOption? paymentMethod;
  final paymentNote = TextEditingController();
  late int issueDate;
  late int dueDate;

  @override
  void initState() {
    super.initState();
    issueDate = Za.todayMillis();
    dueDate = Za.plusDays(issueDate, 30);
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppController>();
    final biz = app.business;
    if (widget.id == 'new') {
      if (biz == null) return;
      final pair = app.repo.nextInvoiceNumber(biz);
      invoice = Invoice(
        id: Za.newId(),
        businessId: biz.id,
        customerId: app.customers.firstOrNull?.id ?? '',
        number: pair.$1,
        status: InvoiceStatus.draft,
        issueDate: issueDate,
        dueDate: dueDate,
        currency: biz.defaultCurrency,
        vatPercent: biz.defaultVatPercent,
        terms: terms.text,
        createdAt: Za.nowMillis(),
        updatedAt: Za.nowMillis(),
      );
      customerId = invoice!.customerId.isEmpty ? widget.initialCustomerId : invoice!.customerId;
      if (customerId == null || app.customers.every((c) => c.id != customerId)) {
        customerId = widget.initialCustomerId ?? app.customers.firstOrNull?.id;
      }
      currency.text = biz.defaultCurrency;
      vatPercent.text = trimNum(biz.defaultVatPercent);
      templateId = app.templates.where((t) => t.isDefault).firstOrNull?.id;
      items = [
        InvoiceLineItem(id: Za.newId(), invoiceId: invoice!.id, position: 0, description: ''),
      ];
      bump = true;
    } else {
      final details = await app.repo.getInvoiceDetails(widget.id);
      if (details != null) {
        invoice = details.invoice;
        items = [...details.items];
        customerId = details.invoice.customerId;
        templateId = details.invoice.templateId;
        status = details.invoice.status;
        issueDate = details.invoice.issueDate;
        dueDate = details.invoice.dueDate;
        notes.text = details.invoice.notes ?? '';
        terms.text = details.invoice.terms ?? '';
        discountAmount.text = trimNum(details.invoice.discountAmount);
        discountPercent.text = trimNum(details.invoice.discountPercent);
        vatPercent.text = trimNum(details.invoice.vatPercent);
        currency.text = details.invoice.currency;
        paymentMethod = details.invoice.paymentMethod;
        paymentNote.text = details.invoice.paymentNote ?? '';
      }
    }
    setState(() => loaded = true);
  }

  @override
  void dispose() {
    notes.dispose();
    terms.dispose();
    discountAmount.dispose();
    discountPercent.dispose();
    vatPercent.dispose();
    currency.dispose();
    paymentNote.dispose();
    super.dispose();
  }

  MoneyTotals get totals => Money.totals(
        lineTotals: items.map((i) => Money.lineTotal(i.quantity, i.unitPrice)).toList(),
        taxable: items.map((i) => i.taxable).toList(),
        discountAmount: double.tryParse(discountAmount.text) ?? 0,
        discountPercent: double.tryParse(discountPercent.text) ?? 0,
        vatPercent: double.tryParse(vatPercent.text) ?? 15,
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    if (!loaded || invoice == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (app.customers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('New invoice')),
        body: EmptyHint(
          icon: Icons.people_outline,
          title: 'Add a customer first',
          body: 'Invoices are stored in a per-customer folder on this device. Add a customer, then come back to invoice them.',
          actionLabel: 'Add customer',
          onAction: () => context.push('/customer-edit/new'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(invoice!.number),
        actions: [
          TextButton(onPressed: () => _save(), child: const Text('Save', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SearchableSelect<Customer>(
            label: 'Customer',
            value: app.customers.where((c) => c.id == customerId).firstOrNull,
            items: app.customers,
            searchHint: 'Search customers',
            labelOf: (c) => c.name,
            subtitleOf: (c) => [c.email, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            onChanged: (c) => setState(() => customerId = c?.id),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Issue date'),
                  subtitle: Text(Za.date(issueDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.fromMillisecondsSinceEpoch(issueDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => issueDate = picked.millisecondsSinceEpoch);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(Za.date(dueDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.fromMillisecondsSinceEpoch(dueDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => dueDate = picked.millisecondsSinceEpoch);
                  },
                ),
              ),
            ],
          ),
          SearchableSelect<InvoiceStatus>(
            label: 'Status',
            value: status,
            items: InvoiceStatus.values,
            searchHint: 'Search status',
            labelOf: niceEnum,
            onChanged: (v) => setState(() => status = v ?? status),
          ),
          const SizedBox(height: 12),
          if (app.templates.isNotEmpty)
            SearchableSelect<InvoiceTemplate>(
              label: 'Template',
              value: app.templates.where((t) => t.id == templateId).firstOrNull ??
                  app.templates.where((t) => t.isDefault).firstOrNull ??
                  app.templates.first,
              items: app.templates,
              searchHint: 'Search templates',
              labelOf: (t) => t.name,
              subtitleOf: (t) => niceEnum(t.layout),
              onChanged: (t) => setState(() => templateId = t?.id),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Line items', style: Theme.of(context).textTheme.titleMedium)),
              if (app.products.isEmpty)
                TextButton(
                  onPressed: () => context.push('/product/new'),
                  child: const Text('Add products'),
                ),
            ],
          ),
          if (app.products.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tip: save products in the catalog, then pick them from the dropdown on each line.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (var i = 0; i < items.length; i++) _lineEditor(i),
          TextButton.icon(
            onPressed: () => setState(() {
              items.add(InvoiceLineItem(
                id: Za.newId(),
                invoiceId: invoice!.id,
                position: items.length,
                description: '',
              ));
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add line'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: discountAmount, decoration: const InputDecoration(labelText: 'Discount R'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: discountPercent, decoration: const InputDecoration(labelText: 'Discount %'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: vatPercent, decoration: const InputDecoration(labelText: 'VAT %'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: currency, decoration: const InputDecoration(labelText: 'Currency'))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Subtotal ${Za.money(totals.subtotal, currency.text)}'),
          if (totals.discount > 0) Text('Discount ${Za.money(totals.discount, currency.text)}'),
          Text('VAT ${Za.money(totals.vat, currency.text)}'),
          Text('Total ${Za.money(totals.total, currency.text)}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Payment options', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in PaymentOption.values)
                ChoiceChip(
                  label: Text(paymentOptionLabel(option)),
                  selected: paymentMethod == option,
                  onSelected: (on) => setState(() => paymentMethod = on ? option : null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: paymentNote,
            decoration: const InputDecoration(labelText: 'Payment note'),
          ),
          const SizedBox(height: 12),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
          const SizedBox(height: 8),
          TextField(controller: terms, decoration: const InputDecoration(labelText: 'Terms'), maxLines: 2),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => _save(), child: const Text('Save invoice')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _save(forLater: true),
            icon: const Icon(Icons.bookmark_outline),
            label: const Text('Save for later'),
          ),
        ],
      ),
    );
  }

  Widget _lineEditor(int index) {
    final app = context.watch<AppController>();
    final item = items[index];
    final selectedProduct = app.products.where((p) => p.id == item.productId).firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SearchableSelect<Product>(
              label: 'Product',
              value: selectedProduct,
              items: app.products,
              includeNone: true,
              noneLabel: 'Custom line (type below)',
              searchHint: 'Search catalog',
              labelOf: (p) => p.name,
              subtitleOf: (p) =>
                  '${Za.money(p.unitPrice, currency.text.isEmpty ? 'ZAR' : currency.text)}${p.taxable ? ' · VAT' : ' · no VAT'}',
              onChanged: (p) {
                if (p == null) {
                  setState(() => items[index] = item.copyWith(clearProduct: true));
                  return;
                }
                setState(() => items[index] = item.applyProduct(p));
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('desc-${item.id}-${item.productId ?? 'custom'}-${item.description}'),
              initialValue: item.description,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (v) => items[index] = items[index].copyWith(description: v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('qty-${item.id}'),
                    initialValue: trimNum(item.quantity),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      items[index] = items[index].copyWith(quantity: double.tryParse(v) ?? 0);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('price-${item.id}-${item.productId ?? 'custom'}-${item.unitPrice}'),
                    initialValue: trimNum(item.unitPrice),
                    decoration: const InputDecoration(labelText: 'Unit price'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      items[index] = items[index].copyWith(unitPrice: double.tryParse(v) ?? 0);
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  onPressed: items.length == 1 ? null : () => setState(() => items.removeAt(index)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('VAT on this line'),
              value: item.taxable,
              onChanged: (v) => setState(() => items[index] = items[index].copyWith(taxable: v)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({bool forLater = false}) async {
    final app = context.read<AppController>();
    final cid = customerId?.trim() ?? '';
    if (cid.isEmpty || app.customers.every((c) => c.id != cid)) {
      await showSnack(context, 'Select a customer before saving.');
      return;
    }
    var lines = [
      for (var i = 0; i < items.length; i++) items[i].copyWith(position: i),
    ];
    final hasLine = lines.any(
      (i) => i.description.trim().isNotEmpty || (i.productId != null && i.productId!.trim().isNotEmpty),
    );
    if (!hasLine) {
      if (!forLater) {
        await showSnack(context, 'Add a product or a description on at least one line.');
        return;
      }
      lines = [
        InvoiceLineItem(
          id: lines.isEmpty ? Za.newId() : lines.first.id,
          invoiceId: invoice!.id,
          position: 0,
          description: 'Draft — add line items',
        ),
      ];
    }
    try {
      final saved = await app.saveInvoice(
        invoice: invoice!.copyWith(
          customerId: cid,
          status: forLater ? InvoiceStatus.draft : status,
          issueDate: issueDate,
          dueDate: dueDate,
          issuedAt: Za.combineDateWithNow(issueDate),
          currency: currency.text.trim().isEmpty ? 'ZAR' : currency.text.trim().toUpperCase(),
          vatPercent: double.tryParse(vatPercent.text) ?? 15,
          discountAmount: double.tryParse(discountAmount.text) ?? 0,
          discountPercent: double.tryParse(discountPercent.text) ?? 0,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          terms: terms.text.trim().isEmpty ? null : terms.text.trim(),
          templateId: templateId,
          paymentMethod: paymentMethod,
          paymentNote: paymentNote.text.trim().isEmpty ? null : paymentNote.text.trim(),
        ),
        items: lines,
        bumpNumber: bump,
      );
      bump = false;
      invoice = saved;
      if (!mounted) return;
      await showSnack(
        context,
        forLater ? 'Saved ${saved.number} for later' : 'Saved ${saved.number}',
      );
      if (!mounted) return;
      context.go(forLater ? '/invoices' : '/invoice-view/${saved.id}');
    } catch (e, st) {
      debugPrint('Invoice create/save failed: $e\n$st');
      if (!mounted) return;
      final message = e is InvoiceSaveException
          ? e.message
          : 'Could not save the invoice. Check the customer and line items, then try again.';
      await showSnack(context, message);
    }
  }
}

class InvoiceViewScreen extends StatelessWidget {
  const InvoiceViewScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final invoice = app.invoices.where((i) => i.id == id).firstOrNull;
    if (invoice == null) {
      return const Scaffold(body: Center(child: Text('Invoice not found')));
    }
    final customer = app.customers.where((c) => c.id == invoice.customerId).firstOrNull;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(invoice.number),
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/invoice/${invoice.id}')),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Payment options'),
              Tab(text: 'Share'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InvoiceOverviewTab(invoice: invoice, customer: customer, onAddImage: _addImage, onPasteImage: _pasteImage, onPay: _pay),
            _InvoicePaymentTab(invoice: invoice),
            _InvoiceShareTab(invoice: invoice, customer: customer),
          ],
        ),
      ),
    );
  }

  Future<void> _addImage(BuildContext context, AppController app, Invoice invoice) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      final file = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (file?.files.single.bytes == null) return;
      await app.addInvoiceImage(invoice, file!.files.single.bytes!, file.files.single.name);
    } else {
      await app.addInvoiceImage(invoice, await picked.readAsBytes(), picked.name);
    }
    if (context.mounted) await showSnack(context, 'Picture attached');
  }

  Future<void> _pasteImage(BuildContext context, AppController app, Invoice invoice) async {
    final bytes = await NativeShare.clipboardImage();
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) await showSnack(context, 'No image on the clipboard');
      return;
    }
    await app.addInvoiceImage(invoice, bytes, 'pasted.png');
    if (context.mounted) await showSnack(context, 'Pasted picture onto invoice');
  }

  Future<void> _pay(BuildContext context, AppController app, Invoice invoice) async {
    final amount = TextEditingController(text: trimNum(invoice.total));
    final method = TextEditingController(text: 'EFT');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: method, decoration: const InputDecoration(labelText: 'Method')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await app.recordPayment(
        invoice: invoice,
        amount: double.tryParse(amount.text) ?? invoice.total,
        method: method.text.trim().isEmpty ? 'EFT' : method.text.trim(),
      );
    }
    amount.dispose();
    method.dispose();
  }
}

class _InvoiceOverviewTab extends StatelessWidget {
  const _InvoiceOverviewTab({
    required this.invoice,
    required this.customer,
    required this.onAddImage,
    required this.onPasteImage,
    required this.onPay,
  });

  final Invoice invoice;
  final Customer? customer;
  final Future<void> Function(BuildContext, AppController, Invoice) onAddImage;
  final Future<void> Function(BuildContext, AppController, Invoice) onPasteImage;
  final Future<void> Function(BuildContext, AppController, Invoice) onPay;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(customer?.name ?? '', style: Theme.of(context).textTheme.titleMedium)),
            StatusChip(invoice.status),
          ],
        ),
        if (invoice.savedForLater)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Saved for later — reopen to finish and send.', style: Theme.of(context).textTheme.bodySmall),
          ),
        Text('Issued ${Za.dateTime(invoice.displayIssuedAt)}'),
        Text('Due ${Za.date(invoice.dueDate)}'),
        if (invoice.generatedAt != null) Text('Generated ${Za.dateTime(invoice.generatedAt!)}'),
        const SizedBox(height: 8),
        Text(Za.money(invoice.total, invoice.currency), style: Theme.of(context).textTheme.headlineSmall),
        Text('Subtotal ${Za.money(invoice.subtotal, invoice.currency)} · VAT ${Za.money(invoice.vatAmount, invoice.currency)}'),
        if (invoice.paymentMethod != null) ...[
          const SizedBox(height: 8),
          Text('Payment ${paymentOptionLabel(invoice.paymentMethod!)}'),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                final file = await app.generatePdf(invoice.id);
                if (context.mounted) {
                  await showSnack(context, file == null ? 'Could not build PDF' : 'PDF saved as ${file.path.split('/').last}');
                }
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/invoice-preview/${invoice.id}'),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/signature/${invoice.id}'),
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Authorised signature'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/signature/${invoice.id}?kind=pod'),
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('Customer delivery signature'),
            ),
            OutlinedButton.icon(
              onPressed: () => onAddImage(context, app, invoice),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Insert picture'),
            ),
            OutlinedButton.icon(
              onPressed: () => onPasteImage(context, app, invoice),
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste picture'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<InvoiceStatus>(
          initialValue: invoice.status,
          decoration: const InputDecoration(labelText: 'Update status'),
          items: [
            for (final s in InvoiceStatus.values) DropdownMenuItem(value: s, child: Text(niceEnum(s))),
          ],
          onChanged: (s) {
            if (s != null) app.setInvoiceStatus(invoice.id, s);
          },
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => onPay(context, app, invoice),
          child: const Text('Record payment'),
        ),
        const SizedBox(height: 12),
        if (invoice.signaturePath != null)
          _SignatureThumb(label: 'Authorised signature (stamped on the PDF)', path: invoice.signaturePath!),
        if (invoice.podSignaturePath != null) ...[
          const SizedBox(height: 12),
          _SignatureThumb(label: 'Received by / Delivery receipt', path: invoice.podSignaturePath!),
        ],
        TextButton(
          onPressed: () async {
            await app.deleteInvoice(invoice);
            if (context.mounted) context.go('/invoices');
          },
          child: const Text('Delete invoice'),
        ),
      ],
    );
  }
}

class _SignatureThumb extends StatelessWidget {
  const _SignatureThumb({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final file = context.read<AppController>().repo.storage.resolve(path);
    if (!file.existsSync()) {
      return Text('$label is on file but the image is missing. Capture it again.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.black26)),
          child: DiskImage(file, height: 72),
        ),
      ],
    );
  }
}

class _InvoicePaymentTab extends StatelessWidget {
  const _InvoicePaymentTab({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Payment options', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Choose how this invoice will be settled. The selection is stored on the invoice and printed on the PDF.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in PaymentOption.values)
              ChoiceChip(
                label: Text(paymentOptionLabel(option)),
                selected: invoice.paymentMethod == option,
                onSelected: (on) => app.setPaymentOption(
                  invoice,
                  on ? option : null,
                  note: invoice.paymentNote,
                ),
              ),
          ],
        ),
        if (invoice.paymentMethod != null)
          TextButton(
            onPressed: () => app.setPaymentOption(invoice, null),
            child: const Text('Clear payment option'),
          ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('pay-note-${invoice.id}-${invoice.paymentNote}'),
          initialValue: invoice.paymentNote ?? '',
          decoration: const InputDecoration(labelText: 'Payment note'),
          onFieldSubmitted: (v) => app.setPaymentOption(invoice, invoice.paymentMethod, note: v.trim().isEmpty ? null : v.trim()),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => InvoiceViewScreen(id: invoice.id)._pay(context, app, invoice),
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}

class _InvoiceShareTab extends StatelessWidget {
  const _InvoiceShareTab({required this.invoice, required this.customer});

  final Invoice invoice;
  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('WhatsApp', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Open a chat with this customer, or attach the full invoice PDF.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: customer == null
              ? null
              : () async {
                  final outcome = await app.openWhatsAppChat(customer!);
                  if (!context.mounted) return;
                  await showSnack(
                    context,
                    outcome.ok ? 'Opening WhatsApp chat' : (outcome.message ?? 'Could not open WhatsApp.'),
                  );
                },
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Open WhatsApp chat'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => shareInvoicePdf(context, app, invoice, 'whatsapp'),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Share PDF on WhatsApp'),
        ),
        const SizedBox(height: 16),
        Text('Email', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => shareInvoicePdf(context, app, invoice, 'email'),
          icon: const Icon(Icons.email_outlined),
          label: const Text('Share PDF by Email'),
        ),
        const SizedBox(height: 16),
        Text('Upload / save to storage', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Writes the PDF to the on-device invoice archive (offline). You can also save a copy through the system Files picker (SAF / Drive).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () async {
            final file = await app.archiveInvoicePdf(invoice);
            if (!context.mounted) return;
            await showSnack(
              context,
              file == null ? 'Could not save the invoice PDF' : 'Saved to storage: ${file.path.split('/').last}',
            );
          },
          icon: const Icon(Icons.save_alt),
          label: const Text('Save PDF to device storage'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final pdf = await app.generatePdf(invoice.id);
            if (pdf == null || !context.mounted) {
              if (context.mounted) await showSnack(context, 'Could not build the invoice PDF.');
              return;
            }
            try {
              final path = await FilePicker.platform.saveFile(
                dialogTitle: 'Save invoice PDF',
                fileName: pdf.uri.pathSegments.isEmpty ? 'Invoice.pdf' : pdf.uri.pathSegments.last,
                type: FileType.custom,
                allowedExtensions: const ['pdf'],
                bytes: await pdf.readAsBytes(),
              );
              if (!context.mounted) return;
              await showSnack(context, path == null ? 'Save cancelled' : 'Copied to $path');
            } catch (_) {
              if (context.mounted) await showSnack(context, 'Files picker is not available on this device.');
            }
          },
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Save to Files / Drive'),
        ),
        if (invoice.savedToStoragePath != null) ...[
          const SizedBox(height: 8),
          Text('Last archive: ${invoice.savedToStoragePath}', style: Theme.of(context).textTheme.bodySmall),
        ],
        if (app.business != null) ...[
          const SizedBox(height: 16),
          Text('Stored invoice PDFs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          FutureBuilder<List<File>>(
            future: app.repo.archivedInvoicePdfs(app.business!.id),
            builder: (context, snap) {
              final files = snap.data ?? const <File>[];
              if (files.isEmpty) {
                return Text(
                  'No archived PDFs yet. Use Save PDF to device storage.',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              return Column(
                children: [
                  for (final file in files.take(12))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last),
                      subtitle: Text(file.parent.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key, required this.id, this.kind = SignatureKind.authorised});

  final String id;
  final SignatureKind kind;

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final controller = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xFF15201E),
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind == SignatureKind.pod ? 'Delivery receipt signature' : 'Handwritten signature'),
        actions: [
          IconButton(onPressed: controller.clear, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.kind == SignatureKind.pod
                  ? 'Customer signs here. This is stamped as Received by / Delivery receipt.'
                  : 'Sign in the box. This authorised signature is stamped onto the invoice PDF.',
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              color: Colors.white,
              child: Signature(controller: controller, backgroundColor: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                if (controller.isEmpty) {
                  await showSnack(context, 'Draw a signature first.');
                  return;
                }
                final Uint8List? bytes = await controller.toPngBytes(width: 1000, height: 380);
                if (bytes == null || bytes.isEmpty || !mounted) {
                  await showSnack(context, 'Could not capture the signature. Try drawing it again.');
                  return;
                }
                final app = context.read<AppController>();
                final invoice = app.invoices.where((i) => i.id == widget.id).firstOrNull;
                if (invoice == null) return;
                if (widget.kind == SignatureKind.pod) {
                  await app.savePodSignature(invoice, bytes);
                } else {
                  await app.saveSignature(invoice, bytes);
                }
                if (!mounted) return;
                await showSnack(
                  context,
                  widget.kind == SignatureKind.pod
                      ? 'Delivery receipt stamped on the invoice PDF'
                      : 'Signature stamped on the invoice PDF',
                );
                if (!mounted) return;
                context.go('/invoice-preview/${invoice.id}');
              },
              child: const Text('Stamp on invoice'),
            ),
          ),
        ],
      ),
    );
  }
}

class InvoicePreviewScreen extends StatefulWidget {
  const InvoicePreviewScreen({super.key, required this.id});

  final String id;

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  InvoiceDetails? details;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppController>();
    details = await app.repo.getInvoiceDetails(widget.id);
    if (mounted) setState(() => loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final invoice = app.invoices.where((i) => i.id == widget.id).firstOrNull;
    if (invoice == null) {
      return const Scaffold(body: Center(child: Text('Invoice not found')));
    }
    final customer = app.customers.where((c) => c.id == invoice.customerId).firstOrNull;
    final business = app.business;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice preview'),
        actions: [
          IconButton(
            tooltip: 'Email PDF',
            onPressed: () => shareInvoicePdf(context, app, invoice, 'email'),
            icon: const Icon(Icons.email_outlined),
          ),
          IconButton(
            tooltip: 'WhatsApp PDF',
            onPressed: () => shareInvoicePdf(context, app, invoice, 'whatsapp'),
            icon: const Icon(Icons.chat_outlined),
          ),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : details == null || business == null || customer == null
              ? const Center(child: Text('Could not load this invoice'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'This is the full invoice that Email and WhatsApp attach as a PDF.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    InvoicePaperPreview(
                      business: business,
                      customer: customer,
                      invoice: details!.invoice,
                      items: details!.items,
                      logoFile: () {
                        final template = app.templates.where((t) => t.id == invoice.templateId).firstOrNull ??
                            app.templates.where((t) => t.isDefault).firstOrNull;
                        final logoPath = template?.logoPath ?? business.logoPath;
                        if (logoPath == null) return null;
                        final f = app.repo.storage.resolve(logoPath);
                        return f.existsSync() ? f : null;
                      }(),
                      signatureFile: () {
                        if (invoice.signaturePath == null) return null;
                        final f = app.repo.storage.resolve(invoice.signaturePath!);
                        return f.existsSync() ? f : null;
                      }(),
                      podSignatureFile: () {
                        if (invoice.podSignaturePath == null) return null;
                        final f = app.repo.storage.resolve(invoice.podSignaturePath!);
                        return f.existsSync() ? f : null;
                      }(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => shareInvoicePdf(context, app, invoice, 'whatsapp'),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Share PDF on WhatsApp'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => shareInvoicePdf(context, app, invoice, 'email'),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Share PDF by Email'),
                    ),
                  ],
                ),
    );
  }
}

