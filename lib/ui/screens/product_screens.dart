import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../app_controller.dart';
import '../widgets.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/product/new'),
        icon: const Icon(Icons.add),
        label: const Text('Product'),
      ),
      body: Column(
        children: [
          if (app.products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchableSelect<Product>(
                label: 'Find product',
                value: null,
                items: app.products,
                    placeholder: 'Tap to search and open',
                    searchHint: 'Search catalog',
                labelOf: (p) => p.name,
                subtitleOf: (p) =>
                    '${Za.money(p.unitPrice, app.business?.defaultCurrency ?? 'ZAR')}${p.taxable ? ' · VAT' : ' · no VAT'}',
                onChanged: (p) {
                  if (p != null) context.push('/product/${p.id}');
                },
              ),
            ),
          Expanded(
            child: app.products.isEmpty
                ? EmptyHint(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    body:
                        'Add catalog items with a name, unit price and optional VAT. Invoice lines can then be picked from this dropdown instead of typing.',
                    actionLabel: 'Add first product',
                    onAction: () => context.push('/product/new'),
                  )
                : ListView.builder(
                    itemCount: app.products.length,
                    itemBuilder: (context, i) {
                      final p = app.products[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          [
                            if (p.description != null && p.description!.isNotEmpty) p.description,
                            p.taxable ? 'VAT on' : 'No VAT',
                          ].join(' · '),
                        ),
                        trailing: Text(Za.money(p.unitPrice, app.business?.defaultCurrency ?? 'ZAR')),
                        onTap: () => context.push('/product/${p.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key, required this.id});

  final String id;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final unitPrice = TextEditingController(text: '0');
  bool taxable = true;
  Product? existing;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id != 'new') {
      existing = await context.read<AppController>().repo.getProduct(widget.id);
      final p = existing;
      if (p != null) {
        name.text = p.name;
        description.text = p.description ?? '';
        unitPrice.text = trimNum(p.unitPrice);
        taxable = p.taxable;
      }
    }
    setState(() => loaded = true);
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    unitPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New product' : 'Edit product'),
        actions: [
          if (existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await context.read<AppController>().deleteProduct(existing!);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: unitPrice,
            decoration: const InputDecoration(labelText: 'Unit price (ZAR)'),
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('VAT applies'),
            subtitle: const Text('Turn off for zero-rated or exempt items'),
            value: taxable,
            onChanged: (v) => setState(() => taxable = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save product')),
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
    await app.saveProduct(
      Product(
        id: existing?.id ?? Za.newId(),
        businessId: biz.id,
        name: name.text.trim(),
        description: description.text.trim().isEmpty ? null : description.text.trim(),
        unitPrice: double.tryParse(unitPrice.text) ?? 0,
        taxable: taxable,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) context.pop();
  }
}
