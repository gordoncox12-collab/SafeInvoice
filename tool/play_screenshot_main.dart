// Play Console screenshot host. Not the release entrypoint — run with:
//   flutter run -t tool/play_screenshot_main.dart --dart-define=PLAY_SHOT=home
// Sample books stay on the emulator only and are not compiled into the store AAB.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/domain/balance.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:safeinvoice/ui/app_controller.dart';
import 'package:safeinvoice/ui/invoice_preview.dart';
import 'package:safeinvoice/ui/outstanding.dart';
import 'package:safeinvoice/ui/screens/customer_screens.dart';
import 'package:safeinvoice/ui/screens/excel_settings_screens.dart';
import 'package:safeinvoice/ui/screens/invoice_screens.dart';
import 'package:safeinvoice/ui/screens/shell.dart';
import 'package:safeinvoice/ui/theme.dart';

const _shot = String.fromEnvironment('PLAY_SHOT', defaultValue: 'home');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_ZA');
  final repo = await InvoiceRepository.open();
  await _seedPlayBooks(repo);
  final controller = AppController(repo);
  await controller.bootstrap();
  runApp(PlayScreenshotApp(controller: controller, shot: _shot));
}

class PlayScreenshotApp extends StatelessWidget {
  const PlayScreenshotApp({super.key, required this.controller, required this.shot});

  final AppController controller;
  final String shot;

  @override
  Widget build(BuildContext context) {
    final base = safeInvoiceTheme(
      mode: ThemeModeOption.light,
      accent: AccentPalette.forest,
      platformBrightness: Brightness.light,
    );
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        locale: const Locale('en', 'ZA'),
        supportedLocales: const [Locale('en', 'ZA'), Locale('en')],
        debugShowCheckedModeBanner: false,
        theme: base,
        home: _shotHome(controller, shot),
      ),
    );
  }
}

Widget _shotHome(AppController controller, String shot) {
  final customer = controller.customers.single;
  final now = DateTime(2026, 10, 10, 9).millisecondsSinceEpoch;
  switch (shot) {
    case 'editor':
      return const InvoiceEditScreen(id: 'new', initialCustomerId: 'c1');
    case 'unpaid':
      return const OutstandingScreen();
    case 'pay':
      final unpaid = controller.unpaidOrders(customerId: 'c1');
      return Scaffold(
        appBar: AppBar(title: const Text('Pay outstanding')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PayOutstandingForm(
              customerName: 'Acme Workshops',
              remaining: controller.customerOutstanding('c1'),
              currency: 'ZAR',
              amount: TextEditingController(text: '300'),
              method: PaymentOption.eft,
              occurredAt: now,
              reference: TextEditingController(),
              allocations: allocateOldestFirst(unpaid, 300),
              invoices: {for (final o in unpaid) o.invoice.id: o.invoice},
              onAmountChanged: () {},
              onMethod: (_) {},
              onDate: (_) {},
            ),
          ],
        ),
      );
    case 'pdf':
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice preview')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InvoicePaperPreview(
              business: controller.business!,
              customer: customer,
              invoice: controller.invoices.firstWhere((i) => i.id == 'inv1'),
              items: const [
                InvoiceLineItem(
                  id: 'l1',
                  invoiceId: 'inv1',
                  position: 0,
                  description: 'Call-out — First hour',
                  quantity: 2,
                  unitPrice: 850,
                ),
              ],
              amountPaid: 500,
              unpaidOrders: controller.unpaidOrders(customerId: 'c1', excludeInvoiceId: 'inv1'),
            ),
          ],
        ),
      );
    case 'customer':
      return const CustomerDetailScreen(id: 'c1');
    case 'invoices':
      return const InvoiceListScreen(filter: 'outstanding');
    case 'settings':
      return const SettingsScreen();
    case 'home':
    default:
      return const HomeScreen();
  }
}

Future<void> _seedPlayBooks(InvoiceRepository repo) async {
  final existing = await repo.businesses();
  if (existing.any((b) => b.id == 'b1')) return;
  final now = DateTime(2026, 10, 10, 9).millisecondsSinceEpoch;
  final older = DateTime(2026, 8, 1).millisecondsSinceEpoch;
  await repo.saveBusiness(
    Business(
      id: 'b1',
      name: 'Cox Electrical',
      email: 'bookings@example.com',
      phone: '0210000000',
      addressLine1: '1 Main Road',
      city: 'Cape Town',
      defaultCurrency: 'ZAR',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repo.saveCustomer(
    Customer(
      id: 'c1',
      businessId: 'b1',
      name: 'Acme Workshops',
      email: 'acme@example.com',
      phone: '0820000000',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repo.saveProduct(
    Product(
      id: 'p1',
      businessId: 'b1',
      name: 'Call-out — First hour',
      unitPrice: 850,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repo.saveInvoice(
    invoice: Invoice(
      id: 'inv0',
      businessId: 'b1',
      customerId: 'c1',
      number: 'INV-2026-0000',
      status: InvoiceStatus.sent,
      issueDate: older,
      dueDate: Za.plusDays(older, 30),
      createdAt: older,
      updatedAt: older,
    ),
    items: const [
      InvoiceLineItem(id: 'l0', invoiceId: 'inv0', position: 0, description: 'Rewire board', quantity: 1, unitPrice: 400),
    ],
    bumpNumber: true,
  );
  await repo.saveInvoice(
    invoice: Invoice(
      id: 'inv1',
      businessId: 'b1',
      customerId: 'c1',
      number: 'INV-2026-0001',
      status: InvoiceStatus.sent,
      issueDate: now,
      dueDate: Za.plusDays(now, 30),
      createdAt: now,
      updatedAt: now,
    ),
    items: const [
      InvoiceLineItem(
        id: 'l1',
        invoiceId: 'inv1',
        position: 0,
        description: 'Call-out — First hour',
        quantity: 2,
        unitPrice: 850,
        productId: 'p1',
      ),
    ],
    bumpNumber: true,
  );
  await repo.recordPayment(invoice: (await repo.getInvoice('inv1'))!, amount: 500, method: 'EFT');
}
