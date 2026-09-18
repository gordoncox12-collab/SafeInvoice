import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../data/native_share.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../app_controller.dart';
import '../widgets.dart';

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
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
                  child: SearchableSelect<Invoice>(
                    label: 'Find invoice',
                    value: null,
                    items: app.invoices,
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
                for (final inv in app.invoices)
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
          TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(color: Colors.white))),
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
          DropdownButtonFormField<InvoiceStatus>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final s in InvoiceStatus.values)
                DropdownMenuItem(value: s, child: Text(niceEnum(s))),
            ],
            onChanged: (v) => setState(() => status = v ?? status),
          ),
          const SizedBox(height: 12),
          if (app.templates.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: templateId ?? app.templates.first.id,
              decoration: const InputDecoration(labelText: 'Template'),
              items: [
                for (final t in app.templates) DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => templateId = v),
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
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
          const SizedBox(height: 8),
          TextField(controller: terms, decoration: const InputDecoration(labelText: 'Terms'), maxLines: 2),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save invoice')),
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
                setState(() {
                  items[index] = item.copyWith(
                    productId: p.id,
                    description: p.description == null || p.description!.isEmpty ? p.name : '${p.name} — ${p.description}',
                    unitPrice: p.unitPrice,
                    taxable: p.taxable,
                  );
                });
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

  Future<void> _save() async {
    final app = context.read<AppController>();
    final cid = customerId ?? app.customers.first.id;
    final saved = await app.saveInvoice(
      invoice: invoice!.copyWith(
        customerId: cid,
        status: status,
        issueDate: issueDate,
        dueDate: dueDate,
        currency: currency.text.trim().isEmpty ? 'ZAR' : currency.text.trim().toUpperCase(),
        vatPercent: double.tryParse(vatPercent.text) ?? 15,
        discountAmount: double.tryParse(discountAmount.text) ?? 0,
        discountPercent: double.tryParse(discountPercent.text) ?? 0,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        terms: terms.text.trim().isEmpty ? null : terms.text.trim(),
        templateId: templateId,
      ),
      items: [
        for (var i = 0; i < items.length; i++) items[i].copyWith(position: i),
      ],
      bumpNumber: bump,
    );
    bump = false;
    invoice = saved;
    if (!mounted) return;
    await showSnack(context, 'Saved ${saved.number}');
    if (!mounted) return;
    context.go('/invoice-view/${saved.id}');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.number),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/invoice/${invoice.id}')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text(customer?.name ?? '', style: Theme.of(context).textTheme.titleMedium)),
              StatusChip(invoice.status),
            ],
          ),
          Text('${Za.date(invoice.issueDate)} · due ${Za.date(invoice.dueDate)}'),
          const SizedBox(height: 8),
          Text(Za.money(invoice.total, invoice.currency), style: Theme.of(context).textTheme.headlineSmall),
          Text('Subtotal ${Za.money(invoice.subtotal, invoice.currency)} · VAT ${Za.money(invoice.vatAmount, invoice.currency)}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final file = await app.generatePdf(invoice.id);
                  if (context.mounted) {
                    await showSnack(context, file == null ? 'Could not build PDF' : 'PDF saved in customer invoices folder');
                  }
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generate PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/signature/${invoice.id}'),
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Signature'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addImage(context, app, invoice),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Insert picture'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pasteImage(context, app, invoice),
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste picture'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Share receipt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(context, app, invoice, 'email'),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _share(context, app, invoice, 'whatsapp'),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
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
            onPressed: () => _pay(context, app, invoice),
            child: const Text('Record payment'),
          ),
          const SizedBox(height: 12),
          if (invoice.signaturePath != null) const Text('Handwritten signature is on file and will stamp the PDF.'),
          TextButton(
            onPressed: () async {
              await app.deleteInvoice(invoice);
              if (context.mounted) context.go('/invoices');
            },
            child: const Text('Delete invoice'),
          ),
        ],
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

  Future<void> _share(BuildContext context, AppController app, Invoice invoice, String target) async {
    var file = invoice.pdfPath == null ? null : app.repo.storage.resolve(invoice.pdfPath!);
    if (file == null || !file.existsSync()) {
      file = await app.generatePdf(invoice.id);
    }
    if (file == null) {
      if (context.mounted) await showSnack(context, 'Generate the PDF first');
      return;
    }
    final customer = app.customers.where((c) => c.id == invoice.customerId).firstOrNull;
    await app.shareFile(
      file: file,
      title: 'Invoice ${invoice.number}',
      body: 'Please find invoice ${invoice.number} from ${app.business?.name ?? 'SafeInvoice'}.',
      email: customer?.email,
      target: target,
    );
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

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key, required this.id});

  final String id;

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
        title: const Text('Handwritten signature'),
        actions: [
          IconButton(onPressed: controller.clear, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sign in the box. This image is stamped onto the invoice PDF.'),
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
                final Uint8List? bytes = await controller.toPngBytes();
                if (bytes == null || !mounted) return;
                final app = context.read<AppController>();
                final invoice = app.invoices.where((i) => i.id == widget.id).firstOrNull;
                if (invoice == null) return;
                await app.saveSignature(invoice, bytes);
                if (!mounted) return;
                await showSnack(context, 'Signature saved');
                if (!mounted) return;
                context.pop();
              },
              child: const Text('Stamp on invoice'),
            ),
          ),
        ],
      ),
    );
  }
}
