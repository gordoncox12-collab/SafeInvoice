import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../app_controller.dart';
import '../widgets.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customer-edit/new'),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Customer'),
      ),
      body: app.customers.isEmpty
          ? EmptyHint(
              icon: Icons.people_outline,
              title: 'No customers',
              body: 'Add a customer to create their invoices, receipts, Excel, images and notes folders.',
              actionLabel: 'Add customer',
              onAction: () => context.push('/customer-edit/new'),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SearchableSelect<Customer>(
                    label: 'Find customer',
                    value: null,
                    items: app.customers,
                    placeholder: 'Tap to search and open',
                    searchHint: 'Search name, email or phone',
                    labelOf: (c) => c.name,
                    subtitleOf: (c) =>
                        [c.email, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    onChanged: (c) {
                      if (c != null) context.push('/customer/${c.id}');
                    },
                  ),
                ),
                for (final c in app.customers)
                  ListTile(
                    title: Text(c.name),
                    subtitle: Text(
                      [c.email, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: Text('${app.invoices.where((inv) => inv.customerId == c.id).length} inv'),
                    onTap: () => context.push('/customer/${c.id}'),
                  ),
              ],
            ),
    );
  }
}

class CustomerEditScreen extends StatefulWidget {
  const CustomerEditScreen({super.key, required this.id});

  final String id;

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final name = TextEditingController();
  final contact = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final province = TextEditingController();
  final postal = TextEditingController();
  final vat = TextEditingController();
  final notes = TextEditingController();
  Customer? existing;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id != 'new') {
      existing = await context.read<AppController>().repo.getCustomer(widget.id);
      final c = existing;
      if (c != null) {
        name.text = c.name;
        contact.text = c.contactName ?? '';
        email.text = c.email ?? '';
        phone.text = c.phone ?? '';
        address.text = c.addressLine1 ?? '';
        city.text = c.city ?? '';
        province.text = c.province ?? '';
        postal.text = c.postalCode ?? '';
        vat.text = c.vatNumber ?? '';
        notes.text = c.notes ?? '';
      }
    }
    setState(() => loaded = true);
  }

  @override
  void dispose() {
    name.dispose();
    contact.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    city.dispose();
    province.dispose();
    postal.dispose();
    vat.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New customer' : 'Edit customer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
          const SizedBox(height: 10),
          TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact name')),
          const SizedBox(height: 10),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 10),
          TextField(controller: province, decoration: const InputDecoration(labelText: 'Province')),
          const SizedBox(height: 10),
          TextField(controller: postal, decoration: const InputDecoration(labelText: 'Postal code')),
          const SizedBox(height: 10),
          TextField(controller: vat, decoration: const InputDecoration(labelText: 'VAT number')),
          const SizedBox(height: 10),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save customer')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final app = context.read<AppController>();
    final biz = app.business;
    if (biz == null) return;
    if (name.text.trim().isEmpty) {
      await showSnack(context, 'Name is required');
      return;
    }
    final now = Za.nowMillis();
    final c = Customer(
      id: existing?.id ?? Za.newId(),
      businessId: biz.id,
      name: name.text.trim(),
      contactName: contact.text.trim().isEmpty ? null : contact.text.trim(),
      email: email.text.trim().isEmpty ? null : email.text.trim(),
      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      addressLine1: address.text.trim().isEmpty ? null : address.text.trim(),
      city: city.text.trim().isEmpty ? null : city.text.trim(),
      province: province.text.trim().isEmpty ? null : province.text.trim(),
      postalCode: postal.text.trim().isEmpty ? null : postal.text.trim(),
      vatNumber: vat.text.trim().isEmpty ? null : vat.text.trim(),
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await app.saveCustomer(c);
    if (mounted) context.go('/customer/${c.id}');
  }
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final customer = app.customers.where((c) => c.id == id).firstOrNull;
    if (customer == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }
    final invoices = app.invoices.where((i) => i.customerId == id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/customer-edit/$id')),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text([customer.email, customer.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
            subtitle: Text([customer.addressLine1, customer.city, customer.province].whereType<String>().where((s) => s.isNotEmpty).join(', ')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => context.push('/invoice/new?customer=${customer.id}'),
              icon: const Icon(Icons.add),
              label: const Text('Invoice this customer'),
            ),
          ),
          const ListTile(title: Text('Folders on this device')),
          for (final type in FolderType.values)
            ListTile(
              leading: Icon(_folderIcon(type)),
              title: Text(niceEnum(type)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/folder/$id/${type.wire}'),
            ),
          ListTile(
            leading: const Icon(Icons.post_add_outlined),
            title: const Text('Capture spreadsheet'),
            subtitle: const Text('Write rows into the Excel folder'),
            onTap: () => context.push('/sheet/$id'),
          ),
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('New note'),
            onTap: () => context.push('/note/$id/new'),
          ),
          const Divider(),
          const ListTile(title: Text('Invoices')),
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No invoices for this customer yet.'),
            )
          else
            for (final inv in invoices)
              ListTile(
                title: Text(inv.number),
                subtitle: Text(Za.money(inv.total, inv.currency)),
                trailing: StatusChip(inv.status),
                onTap: () => context.push('/invoice-view/${inv.id}'),
              ),
          TextButton(
            onPressed: () async {
              await app.deleteCustomer(customer);
              if (context.mounted) context.go('/customers');
            },
            child: const Text('Delete customer and folders'),
          ),
        ],
      ),
    );
  }

  IconData _folderIcon(FolderType type) => switch (type) {
        FolderType.invoices => Icons.picture_as_pdf_outlined,
        FolderType.receipts => Icons.receipt_outlined,
        FolderType.excel => Icons.table_chart_outlined,
        FolderType.images => Icons.image_outlined,
        FolderType.notes => Icons.notes_outlined,
      };
}

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.customerId, required this.type});

  final String customerId;
  final String type;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<FolderFile> files = [];

  FolderType get folderType => folderTypeFrom(widget.type);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await context.read<AppController>().repo.files(widget.customerId, folderType);
    setState(() => files = list);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final customer = app.customers.where((c) => c.id == widget.customerId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('${niceEnum(folderType)} · ${customer?.name ?? ''}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final picked = await FilePicker.platform.pickFiles(withData: true);
          final bytes = picked?.files.single.bytes;
          if (bytes == null || customer == null) return;
          await app.repo.importFile(
            businessId: customer.businessId,
            customerId: customer.id,
            type: folderType,
            bytes: bytes,
            displayName: picked!.files.single.name,
          );
          await _reload();
        },
        child: const Icon(Icons.add),
      ),
      body: files.isEmpty
          ? EmptyHint(
              icon: Icons.folder_open,
              title: 'Empty ${niceEnum(folderType).toLowerCase()} folder',
              body: 'Files are stored under this customer on the device.',
            )
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, i) {
                final f = files[i];
                return ListTile(
                  title: Text(f.displayName),
                  subtitle: Text('${f.mimeType} · ${(f.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final file = app.repo.storage.resolve(f.relativePath);
                      if (value == 'email') {
                        await app.shareFile(file: file, title: f.displayName, body: f.displayName, email: customer?.email, target: 'email');
                      } else if (value == 'whatsapp') {
                        await app.shareFile(file: file, title: f.displayName, body: f.displayName, target: 'whatsapp');
                      } else if (value == 'share') {
                        await app.shareFile(file: file, title: f.displayName, body: f.displayName);
                      } else if (value == 'delete') {
                        await app.repo.deleteFolderFile(f);
                        await _reload();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'email', child: Text('Email')),
                      PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                      PopupMenuItem(value: 'share', child: Text('Share')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, required this.customerId, required this.noteId});

  final String customerId;
  final String noteId;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  Note? existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.noteId != 'new') {
      existing = await context.read<AppController>().repo.getNote(widget.noteId);
      title.text = existing?.title ?? '';
      body.text = existing?.body ?? '';
    }
    setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: body,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final app = context.read<AppController>();
                final customer = await app.repo.getCustomer(widget.customerId);
                if (customer == null) return;
                final now = Za.nowMillis();
                await app.saveNote(
                  Note(
                    id: existing?.id ?? Za.newId(),
                    businessId: customer.businessId,
                    customerId: customer.id,
                    title: title.text.trim().isEmpty ? 'Note' : title.text.trim(),
                    body: body.text,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
                if (context.mounted) context.pop();
              },
              child: const Text('Save to notes folder'),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetCaptureScreen extends StatefulWidget {
  const SheetCaptureScreen({super.key, required this.customerId});

  final String customerId;

  @override
  State<SheetCaptureScreen> createState() => _SheetCaptureScreenState();
}

class _SheetCaptureScreenState extends State<SheetCaptureScreen> {
  final headers = TextEditingController(text: 'Date,Description,Amount,Notes');
  final rows = TextEditingController();
  bool csv = false;

  @override
  void dispose() {
    headers.dispose();
    rows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture spreadsheet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: headers, decoration: const InputDecoration(labelText: 'Headers (comma separated)')),
          const SizedBox(height: 12),
          TextField(
            controller: rows,
            decoration: const InputDecoration(labelText: 'Rows (one per line, comma separated)'),
            maxLines: 10,
          ),
          SwitchListTile(
            title: const Text('Save as CSV (otherwise xlsx)'),
            value: csv,
            onChanged: (v) => setState(() => csv = v),
          ),
          FilledButton(
            onPressed: () async {
              final app = context.read<AppController>();
              final customer = await app.repo.getCustomer(widget.customerId);
              if (customer == null) return;
              final headerList = headers.text.split(',').map((s) => s.trim()).toList();
              final rowList = rows.text
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .map((l) => l.split(',').map((s) => s.trim()).toList())
                  .toList();
              await app.repo.writeCaptureSheet(
                businessId: customer.businessId,
                customerId: customer.id,
                fileName: csv ? 'capture.csv' : 'capture.xlsx',
                headers: headerList,
                rows: rowList,
                csv: csv,
              );
              if (!mounted) return;
              await showSnack(context, 'Saved to Excel folder');
              if (!mounted) return;
              context.pop();
            },
            child: const Text('Save into customer Excel folder'),
          ),
        ],
      ),
    );
  }
}
