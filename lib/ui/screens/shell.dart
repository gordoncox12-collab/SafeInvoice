import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../app_controller.dart';
import '../widgets.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get index {
    if (location.startsWith('/invoices')) return 1;
    if (location.startsWith('/customers')) return 2;
    if (location.startsWith('/more')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/invoices');
            case 2:
              context.go('/customers');
            case 3:
              context.go('/more');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Invoices'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postal = TextEditingController();
  final _vat = TextEditingController();
  final _prefix = TextEditingController(text: 'INV');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    _postal.dispose();
    _vat.dispose();
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your business')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'SafeInvoice keeps every invoice, receipt and spreadsheet on this device. No demo data.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Tester path after this screen: add products → add a customer → create an invoice (pick catalog items from the dropdown).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Business name *')),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 12),
          TextField(controller: _province, decoration: const InputDecoration(labelText: 'Province')),
          const SizedBox(height: 12),
          TextField(controller: _postal, decoration: const InputDecoration(labelText: 'Postal code')),
          const SizedBox(height: 12),
          TextField(controller: _vat, decoration: const InputDecoration(labelText: 'VAT number')),
          const SizedBox(height: 12),
          TextField(controller: _prefix, decoration: const InputDecoration(labelText: 'Invoice prefix')),
          const SizedBox(height: 8),
          Text('Currency defaults to ZAR. VAT defaults to 15%.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Create business'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      await showSnack(context, 'Business name is required');
      return;
    }
    setState(() => _saving = true);
    final now = Za.nowMillis();
    final controller = context.read<AppController>();
    await controller.saveBusiness(
      Business(
        id: Za.newId(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        addressLine1: _address.text.trim(),
        city: _city.text.trim(),
        province: _province.text.trim(),
        postalCode: _postal.text.trim(),
        vatNumber: _vat.text.trim().isEmpty ? null : _vat.text.trim(),
        invoicePrefix: _prefix.text.trim().isEmpty ? 'INV' : _prefix.text.trim().toUpperCase(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (mounted) context.go('/');
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final biz = app.business;
    final outstanding = app.invoices.where((i) => i.status == InvoiceStatus.sent || i.status == InvoiceStatus.overdue);
    final paid = app.invoices.where((i) => i.status == InvoiceStatus.paid);
    final overdue = app.invoices.where((i) => i.status == InvoiceStatus.overdue);
    return Scaffold(
      appBar: AppBar(
        title: Text(biz?.name ?? 'SafeInvoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('Offline books for ${biz?.name ?? 'your business'}', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (app.products.isEmpty || app.customers.isEmpty || app.invoices.isEmpty)
            _GettingStartedCard(app: app),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            padding: const EdgeInsets.all(12),
            children: [
              _StatCard(label: 'Invoices', value: '${app.invoices.length}', icon: Icons.receipt_long),
              _StatCard(label: 'Customers', value: '${app.customers.length}', icon: Icons.people),
              _StatCard(
                label: 'Outstanding',
                value: Za.money(outstanding.fold<double>(0, (a, b) => a + b.total), biz?.defaultCurrency ?? 'ZAR'),
                icon: Icons.pending_actions,
              ),
              _StatCard(
                label: 'Overdue',
                value: '${overdue.length}',
                icon: Icons.warning_amber,
              ),
            ],
          ),
          SectionCard(
            title: 'Quick actions',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/invoice/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New invoice'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/product/new'),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('New product'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/customer-edit/new'),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('New customer'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/excel'),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Recent invoices',
            trailing: TextButton(onPressed: () => context.go('/invoices'), child: const Text('See all')),
            child: app.invoices.isEmpty
                ? Text(
                    app.customers.isEmpty
                        ? 'Add a customer, then create an invoice from the catalog.'
                        : 'No invoices yet. Pick a customer and add line items from Products.',
                  )
                : Column(
                    children: [
                      for (final inv in app.invoices.take(6))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(inv.number),
                          subtitle: Text('${Za.date(inv.issueDate)} · ${Za.money(inv.total, inv.currency)}'),
                          trailing: StatusChip(inv.status),
                          onTap: () => context.push('/invoice-view/${inv.id}'),
                        ),
                    ],
                  ),
          ),
          SectionCard(
            title: 'Collected',
            child: Text(Za.money(paid.fold<double>(0, (a, b) => a + b.total), biz?.defaultCurrency ?? 'ZAR')),
          ),
        ],
      ),
    );
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Get ready to invoice',
      child: Column(
        children: [
          _StepTile(
            done: true,
            title: '1. Business profile',
            subtitle: app.business?.name ?? 'Created',
            onTap: () => context.push('/business/${app.business?.id ?? 'new'}'),
          ),
          _StepTile(
            done: app.products.isNotEmpty,
            title: '2. Add products',
            subtitle: app.products.isEmpty
                ? 'Name, unit price, optional VAT — then pick them on invoice lines'
                : '${app.products.length} in catalog',
            onTap: () => context.push(app.products.isEmpty ? '/product/new' : '/products'),
          ),
          _StepTile(
            done: app.customers.isNotEmpty,
            title: '3. Add a customer',
            subtitle: app.customers.isEmpty
                ? 'Needed before you can save an invoice'
                : '${app.customers.length} on this book',
            onTap: () => context.push(app.customers.isEmpty ? '/customer-edit/new' : '/customers'),
          ),
          _StepTile(
            done: app.invoices.isNotEmpty,
            title: '4. Create an invoice',
            subtitle: 'Dropdowns for customer and products, then PDF + signature',
            onTap: () => context.push('/invoice/new'),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.done,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Business profile'),
            subtitle: Text(app.business?.name ?? 'None'),
            onTap: () => context.push('/business/${app.business?.id ?? 'new'}'),
          ),
          if (app.businesses.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SearchableSelect<Business>(
                label: 'Active book',
                value: app.business,
                items: app.businesses,
                searchHint: 'Search businesses',
                labelOf: (b) => b.name,
                subtitleOf: (b) => b.vatNumber ?? b.email,
                onChanged: (b) {
                  if (b != null) app.setActiveBusiness(b.id);
                },
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add_business_outlined),
            title: const Text('Add another business'),
            onTap: () => context.push('/business/new'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Products catalog'),
            subtitle: Text(
              app.products.isEmpty
                  ? 'Name, price and VAT flag for invoice dropdowns'
                  : '${app.products.length} items',
            ),
            onTap: () => context.push('/products'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Excel import / export'),
            subtitle: const Text('xlsx, xls and CSV with column mapping'),
            onTap: () => context.push('/excel'),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Invoice templates'),
            subtitle: const Text('Layouts, colours, pictures'),
            onTap: () => context.push('/templates'),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('Transactions'),
            onTap: () => context.push('/transactions'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme settings'),
            subtitle: Text('${niceEnum(app.settings.themeMode)} · ${niceEnum(app.settings.accentPalette)}'),
            onTap: () => context.push('/settings'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Local only'),
            subtitle: Text('No backend. Books stay on this phone.'),
          ),
        ],
      ),
    );
  }
}

class BusinessEditScreen extends StatefulWidget {
  const BusinessEditScreen({super.key, required this.id});

  final String id;

  @override
  State<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends State<BusinessEditScreen> {
  late final TextEditingController name;
  late final TextEditingController trading;
  late final TextEditingController email;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController city;
  late final TextEditingController province;
  late final TextEditingController postal;
  late final TextEditingController vat;
  late final TextEditingController reg;
  late final TextEditingController bank;
  late final TextEditingController accountName;
  late final TextEditingController accountNo;
  late final TextEditingController branch;
  late final TextEditingController prefix;
  late final TextEditingController currency;
  late final TextEditingController vatPercent;
  Business? existing;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController();
    trading = TextEditingController();
    email = TextEditingController();
    phone = TextEditingController();
    address = TextEditingController();
    city = TextEditingController();
    province = TextEditingController();
    postal = TextEditingController();
    vat = TextEditingController();
    reg = TextEditingController();
    bank = TextEditingController();
    accountName = TextEditingController();
    accountNo = TextEditingController();
    branch = TextEditingController();
    prefix = TextEditingController(text: 'INV');
    currency = TextEditingController(text: 'ZAR');
    vatPercent = TextEditingController(text: '15');
    _load();
  }

  Future<void> _load() async {
    if (widget.id != 'new') {
      existing = await context.read<AppController>().repo.getBusiness(widget.id);
      final b = existing;
      if (b != null) {
        name.text = b.name;
        trading.text = b.tradingName ?? '';
        email.text = b.email;
        phone.text = b.phone;
        address.text = b.addressLine1;
        city.text = b.city;
        province.text = b.province;
        postal.text = b.postalCode;
        vat.text = b.vatNumber ?? '';
        reg.text = b.registrationNumber ?? '';
        bank.text = b.bankName ?? '';
        accountName.text = b.bankAccountName ?? '';
        accountNo.text = b.bankAccountNumber ?? '';
        branch.text = b.bankBranchCode ?? '';
        prefix.text = b.invoicePrefix;
        currency.text = b.defaultCurrency;
        vatPercent.text = trimNum(b.defaultVatPercent);
      }
    }
    setState(() => loaded = true);
  }

  @override
  void dispose() {
    for (final c in [
      name, trading, email, phone, address, city, province, postal, vat, reg,
      bank, accountName, accountNo, branch, prefix, currency, vatPercent,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New business' : 'Business profile'),
        actions: [
          if (existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await context.read<AppController>().deleteBusiness(existing!);
                if (context.mounted) context.go('/');
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
          const SizedBox(height: 10),
          TextField(controller: trading, decoration: const InputDecoration(labelText: 'Trading name')),
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
          TextField(controller: reg, decoration: const InputDecoration(labelText: 'Registration number')),
          const SizedBox(height: 10),
          TextField(controller: bank, decoration: const InputDecoration(labelText: 'Bank name')),
          const SizedBox(height: 10),
          TextField(controller: accountName, decoration: const InputDecoration(labelText: 'Account name')),
          const SizedBox(height: 10),
          TextField(controller: accountNo, decoration: const InputDecoration(labelText: 'Account number')),
          const SizedBox(height: 10),
          TextField(controller: branch, decoration: const InputDecoration(labelText: 'Branch code')),
          const SizedBox(height: 10),
          TextField(controller: prefix, decoration: const InputDecoration(labelText: 'Invoice prefix')),
          const SizedBox(height: 10),
          TextField(controller: currency, decoration: const InputDecoration(labelText: 'Default currency')),
          const SizedBox(height: 10),
          TextField(controller: vatPercent, decoration: const InputDecoration(labelText: 'Default VAT %'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      await showSnack(context, 'Name is required');
      return;
    }
    final now = Za.nowMillis();
    final base = existing;
    await context.read<AppController>().saveBusiness(
      Business(
        id: base?.id ?? Za.newId(),
        name: name.text.trim(),
        tradingName: trading.text.trim().isEmpty ? null : trading.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        addressLine1: address.text.trim(),
        city: city.text.trim(),
        province: province.text.trim(),
        postalCode: postal.text.trim(),
        vatNumber: vat.text.trim().isEmpty ? null : vat.text.trim(),
        registrationNumber: reg.text.trim().isEmpty ? null : reg.text.trim(),
        bankName: bank.text.trim().isEmpty ? null : bank.text.trim(),
        bankAccountName: accountName.text.trim().isEmpty ? null : accountName.text.trim(),
        bankAccountNumber: accountNo.text.trim().isEmpty ? null : accountNo.text.trim(),
        bankBranchCode: branch.text.trim().isEmpty ? null : branch.text.trim(),
        invoicePrefix: prefix.text.trim().isEmpty ? 'INV' : prefix.text.trim().toUpperCase(),
        defaultCurrency: currency.text.trim().isEmpty ? 'ZAR' : currency.text.trim().toUpperCase(),
        defaultVatPercent: double.tryParse(vatPercent.text) ?? 15,
        nextInvoiceNumber: base?.nextInvoiceNumber ?? 1,
        logoPath: base?.logoPath,
        createdAt: base?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) context.pop();
  }
}
