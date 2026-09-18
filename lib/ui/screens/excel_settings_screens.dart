import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../data/excel_service.dart';
import '../../data/native_share.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../app_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class ExcelHubScreen extends StatefulWidget {
  const ExcelHubScreen({super.key});

  @override
  State<ExcelHubScreen> createState() => _ExcelHubScreenState();
}

class _ExcelHubScreenState extends State<ExcelHubScreen> {
  SheetPreview? preview;
  Uint8List? bytes;
  String fileName = '';
  Map<String, int> mapping = {};
  String mode = 'customers';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Excel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Import .xlsx, .xls or CSV. Map columns, then capture data into this book.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose spreadsheet'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _export(app, csv: false),
                  child: const Text('Export xlsx'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _export(app, csv: true),
                  child: const Text('Export CSV'),
                ),
              ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 16),
            Text('${preview!.fileName} · ${preview!.sheetName}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'customers', label: Text('Customers')),
                ButtonSegment(value: 'invoices', label: Text('Invoices')),
              ],
              selected: {mode},
              onSelectionChanged: (s) {
                setState(() {
                  mode = s.first;
                  mapping = guessMapping(
                    preview!.headers,
                    mode == 'customers' ? customerImportFields : invoiceImportFields,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            for (final field in (mode == 'customers' ? customerImportFields : invoiceImportFields))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<int>(
                  initialValue: () {
                    final mapped = mapping[field.$1] ?? -1;
                    if (mapped < 0 || mapped >= preview!.headers.length) return -1;
                    return mapped;
                  }(),
                  decoration: InputDecoration(labelText: field.$2),
                  items: [
                    const DropdownMenuItem(value: -1, child: Text('(skip)')),
                    for (var i = 0; i < preview!.headers.length; i++)
                      DropdownMenuItem(value: i, child: Text(preview!.headers[i].isEmpty ? 'Column ${i + 1}' : preview!.headers[i])),
                  ],
                  onChanged: (v) => setState(() => mapping[field.$1] = v ?? -1),
                ),
              ),
            FilledButton(
              onPressed: () async {
                final biz = app.business;
                if (biz == null || bytes == null) return;
                final count = mode == 'customers'
                    ? await app.repo.importCustomers(biz.id, bytes!, fileName, mapping)
                    : await app.repo.importInvoiceLines(biz.id, bytes!, fileName, mapping);
                await app.refresh();
                if (context.mounted) await showSnack(context, 'Imported $count ${mode == 'customers' ? 'customers' : 'invoices'}');
              },
              child: const Text('Import with this mapping'),
            ),
            const SizedBox(height: 12),
            Text('Preview', style: Theme.of(context).textTheme.titleSmall),
            for (final row in preview!.rows.take(8))
              Text(row.join(' | '), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      type: FileType.custom,
    );
    final file = picked?.files.single;
    if (file?.bytes == null) return;
    final excel = ExcelService();
    final p = excel.preview(file!.bytes!, file.name);
    setState(() {
      bytes = file.bytes;
      fileName = file.name;
      preview = p;
      mapping = guessMapping(p.headers, customerImportFields);
      mode = 'customers';
    });
  }

  Future<void> _export(AppController app, {required bool csv}) async {
    final biz = app.business;
    if (biz == null) return;
    final dir = await getTemporaryDirectory();
    final dest = File(p.join(dir.path, csv ? 'safeinvoice-export.csv' : 'safeinvoice-export.xlsx'));
    await app.repo.exportBusinessWorkbook(biz.id, dest, csv: csv);
    await app.shareFile(
      file: dest,
      title: 'SafeInvoice export',
      body: 'Offline export from ${biz.name}',
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final current = paletteOf(app.settings.accentPalette);
    return Scaffold(
      appBar: AppBar(title: const Text('Theme settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeModeOption>(
            segments: const [
              ButtonSegment(value: ThemeModeOption.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeModeOption.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeModeOption.system, label: Text('System'), icon: Icon(Icons.settings_suggest_outlined)),
            ],
            selected: {app.settings.themeMode},
            onSelectionChanged: (s) => app.setTheme(s.first),
          ),
          const SizedBox(height: 20),
          Text('Live preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${current.name} · ${niceEnum(app.settings.themeMode)} — tap a palette to see it immediately.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const ThemeLivePreview(),
          const SizedBox(height: 24),
          Text('Accent palettes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final palette in palettes)
                _PaletteSwatch(
                  palette: palette,
                  selected: app.settings.accentPalette == palette.key,
                  onTap: () => app.setAccent(palette.key),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Palettes tint the app, navigation and forms. Invoice PDF colours still come from the chosen template.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? palette.primary : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.primary, palette.secondary, palette.tertiary],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                palette.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Dot(palette.primary),
                  const SizedBox(width: 4),
                  _Dot(palette.secondary),
                  const SizedBox(width: 4),
                  _Dot(palette.tertiary),
                  const Spacer(),
                  if (selected) const Icon(Icons.check_circle, color: Colors.white, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70),
      ),
    );
  }
}

class TemplateListScreen extends StatelessWidget {
  const TemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice templates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/template/new'),
        child: const Icon(Icons.add),
      ),
      body: app.templates.isEmpty
          ? const EmptyHint(
              icon: Icons.dashboard_customize_outlined,
              title: 'No templates',
              body: 'A Standard template is created with each business.',
            )
          : ListView(
              children: [
                for (final t in app.templates)
                  ListTile(
                    title: Text(t.name),
                    subtitle: Text('${niceEnum(t.layout)} · ${niceEnum(t.marginPreset)} margins'),
                    trailing: t.isDefault ? const Chip(label: Text('Default')) : null,
                    onTap: () => context.push('/template/${t.id}'),
                  ),
              ],
            ),
    );
  }
}

class TemplateEditScreen extends StatefulWidget {
  const TemplateEditScreen({super.key, required this.id});

  final String id;

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  InvoiceTemplate? template;
  final name = TextEditingController();
  final footer = TextEditingController();
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppController>();
    final biz = app.business;
    if (widget.id == 'new') {
      template = InvoiceTemplate(
        id: Za.newId(),
        businessId: biz!.id,
        name: 'Custom',
        createdAt: Za.nowMillis(),
        updatedAt: Za.nowMillis(),
      );
    } else {
      template = await app.repo.getTemplate(widget.id);
    }
    name.text = template?.name ?? '';
    footer.text = template?.footerText ?? '';
    setState(() => loaded = true);
  }

  @override
  void dispose() {
    name.dispose();
    footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded || template == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = template!;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit template')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Template name'),
            onChanged: (v) => template = t.copyWith(name: v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TemplateLayout>(
            initialValue: t.layout,
            decoration: const InputDecoration(labelText: 'Layout'),
            items: [
              for (final l in TemplateLayout.values) DropdownMenuItem(value: l, child: Text(niceEnum(l))),
            ],
            onChanged: (v) => setState(() => template = t.copyWith(layout: v)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LogoAlignment>(
            initialValue: t.logoAlignment,
            decoration: const InputDecoration(labelText: 'Logo position'),
            items: [
              for (final l in LogoAlignment.values) DropdownMenuItem(value: l, child: Text(niceEnum(l))),
            ],
            onChanged: (v) => setState(() => template = t.copyWith(logoAlignment: v)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MarginPreset>(
            initialValue: t.marginPreset,
            decoration: const InputDecoration(labelText: 'Margins'),
            items: [
              for (final l in MarginPreset.values) DropdownMenuItem(value: l, child: Text(niceEnum(l))),
            ],
            onChanged: (v) => setState(() => template = t.copyWith(marginPreset: v)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PicturePlacement>(
            initialValue: t.picturePlacement,
            decoration: const InputDecoration(labelText: 'Picture placement'),
            items: [
              for (final l in PicturePlacement.values) DropdownMenuItem(value: l, child: Text(niceEnum(l))),
            ],
            onChanged: (v) => setState(() => template = t.copyWith(picturePlacement: v)),
          ),
          SwitchListTile(
            title: const Text('Default template'),
            value: t.isDefault,
            onChanged: (v) => setState(() => template = t.copyWith(isDefault: v)),
          ),
          SwitchListTile(
            title: const Text('Header banner'),
            value: t.headerBanner,
            onChanged: (v) => setState(() => template = t.copyWith(headerBanner: v)),
          ),
          SwitchListTile(
            title: const Text('Bank details'),
            value: t.showBankDetails,
            onChanged: (v) => setState(() => template = t.copyWith(showBankDetails: v)),
          ),
          SwitchListTile(
            title: const Text('Signature line'),
            value: t.showSignatureLine,
            onChanged: (v) => setState(() => template = t.copyWith(showSignatureLine: v)),
          ),
          TextField(
            controller: footer,
            decoration: const InputDecoration(labelText: 'Footer text'),
            onChanged: (v) => template = t.copyWith(footerText: v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(logo: true),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Logo'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickImage(header: true),
                icon: const Icon(Icons.panorama),
                label: const Text('Header picture'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickImage(),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Insert picture'),
              ),
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste picture'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final app = context.read<AppController>();
              await app.saveTemplate(
                    template!.copyWith(name: name.text.trim().isEmpty ? 'Template' : name.text.trim(), footerText: footer.text),
                  );
              if (!mounted) return;
              context.pop();
            },
            child: const Text('Save template'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage({bool logo = false, bool header = false}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    Uint8List? bytes = picked == null ? null : await picked.readAsBytes();
    var display = picked?.name ?? 'image.png';
    if (bytes == null) {
      final file = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      bytes = file?.files.single.bytes;
      display = file?.files.single.name ?? display;
    }
    if (bytes == null) return;
    final app = context.read<AppController>();
    final path = await app.repo.saveTemplateBytes(template!.businessId, bytes, display, logo: logo);
    setState(() {
      if (logo) {
        template = template!.copyWith(logoPath: path);
      } else if (header) {
        template = template!.copyWith(headerImagePath: path);
      } else {
        template = template!.copyWith(extraImagePath: path);
      }
    });
  }

  Future<void> _paste() async {
    final bytes = await NativeShare.clipboardImage();
    if (bytes == null) {
      if (!mounted) return;
      await showSnack(context, 'No image on the clipboard');
      return;
    }
    if (!mounted) return;
    final app = context.read<AppController>();
    final path = await app.repo.saveTemplateBytes(template!.businessId, bytes, 'pasted.png');
    setState(() => template = template!.copyWith(extraImagePath: path));
  }
}

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction/new'),
        child: const Icon(Icons.add),
      ),
      body: app.transactions.isEmpty
          ? const EmptyHint(
              icon: Icons.swap_vert,
              title: 'No transactions',
              body: 'Payments, refunds and receipts are stored locally per business.',
            )
          : ListView.builder(
              itemCount: app.transactions.length,
              itemBuilder: (context, i) {
                final tx = app.transactions[i];
                return ListTile(
                  title: Text('${niceEnum(tx.type)} · ${Za.money(tx.amount, tx.currency)}'),
                  subtitle: Text([tx.method, tx.reference, tx.notes].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
                  trailing: Text(Za.date(tx.occurredAt)),
                );
              },
            ),
    );
  }
}

class TransactionEditScreen extends StatefulWidget {
  const TransactionEditScreen({super.key});

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  TransactionType type = TransactionType.payment;
  final amount = TextEditingController();
  final method = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();
  String? customerId;
  String? invoiceId;

  @override
  void dispose() {
    amount.dispose();
    method.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('New transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<TransactionType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final t in TransactionType.values) DropdownMenuItem(value: t, child: Text(niceEnum(t))),
            ],
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          SearchableSelect<Customer>(
            label: 'Customer',
            value: app.customers.where((c) => c.id == customerId).firstOrNull,
            items: app.customers,
            includeNone: true,
            noneLabel: '(none)',
            searchHint: 'Search customers',
            labelOf: (c) => c.name,
            subtitleOf: (c) => [c.email, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            onChanged: (c) => setState(() {
              customerId = c?.id;
              if (invoiceId != null &&
                  app.invoices.where((i) => i.id == invoiceId && i.customerId == customerId).isEmpty) {
                invoiceId = null;
              }
            }),
          ),
          const SizedBox(height: 12),
          SearchableSelect<Invoice>(
            label: 'Invoice',
            value: app.invoices.where((i) => i.id == invoiceId).firstOrNull,
            items: [
              for (final inv in app.invoices)
                if (customerId == null || inv.customerId == customerId) inv,
            ],
            includeNone: true,
            noneLabel: '(none)',
            searchHint: 'Search invoices',
            labelOf: (inv) => inv.number,
            subtitleOf: (inv) =>
                '${Za.money(inv.total, inv.currency)} · ${niceEnum(inv.status)}',
            onChanged: (inv) => setState(() {
              invoiceId = inv?.id;
              if (inv != null) customerId = inv.customerId;
            }),
          ),
          const SizedBox(height: 12),
          TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: method, decoration: const InputDecoration(labelText: 'Method')),
          const SizedBox(height: 12),
          TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference')),
          const SizedBox(height: 12),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final biz = app.business;
              if (biz == null) return;
              if (!context.mounted) return;
              await app.saveTransaction(
                Txn(
                  id: Za.newId(),
                  businessId: biz.id,
                  customerId: customerId,
                  invoiceId: invoiceId,
                  type: type,
                  amount: double.tryParse(amount.text) ?? 0,
                  occurredAt: Za.nowMillis(),
                  method: method.text.trim().isEmpty ? null : method.text.trim(),
                  reference: reference.text.trim().isEmpty ? null : reference.text.trim(),
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                  createdAt: Za.nowMillis(),
                ),
              );
              if (context.mounted) context.pop();
            },
            child: const Text('Save transaction'),
          ),
        ],
      ),
    );
  }
}
