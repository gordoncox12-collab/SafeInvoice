import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:safeinvoice/ui/app_controller.dart';
import 'package:safeinvoice/ui/screens/invoice_screens.dart';
import 'package:safeinvoice/ui/screens/shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en_ZA');
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('safeinvoice-widget-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<AppController> controllerWith({required bool customer, required bool product}) async {
    final storage = LocalStorage(tmp);
    final database = await AppDatabase.open(p.join(tmp.path, 'safeinvoice.db'));
    final repo = InvoiceRepository(
      db: database.db,
      storage: storage,
      excel: ExcelService(),
      pdf: InvoicePdfService(storage),
    );
    final now = Za.nowMillis();
    await repo.saveBusiness(
      Business(
        id: 'b1',
        name: 'Cox Electrical',
        email: 'books@example.com',
        phone: '0210000000',
        addressLine1: '1 Main Rd',
        city: 'Cape Town',
        province: 'Western Cape',
        postalCode: '8001',
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (product) {
      await repo.saveProduct(
        Product(
          id: 'p1',
          businessId: 'b1',
          name: 'Call-out',
          description: 'First hour',
          unitPrice: 850,
          taxable: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    if (customer) {
      await repo.saveCustomer(
        Customer(
          id: 'c1',
          businessId: 'b1',
          name: 'Acme Workshops',
          email: 'acme@example.com',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final controller = AppController(repo);
    await controller.bootstrap();
    return controller;
  }

  testWidgets('home checklist covers business → products → customer → invoice', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await tester.runAsync(() => controllerWith(customer: true, product: true));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller!,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Get ready to invoice'), findsOneWidget);
    expect(find.text('2. Add products'), findsOneWidget);
    expect(find.text('3. Add a customer'), findsOneWidget);
    expect(find.text('4. Create an invoice'), findsOneWidget);
    expect(find.text('New invoice', skipOffstage: false), findsWidgets);
    expect(find.text('New product', skipOffstage: false), findsWidgets);
    expect(find.text('New customer', skipOffstage: false), findsWidgets);
  });

  testWidgets('invoice editor shows customer and product dropdowns', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await tester.runAsync(() => controllerWith(customer: true, product: true));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller!,
        child: MaterialApp(
          locale: const Locale('en', 'ZA'),
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'ZA'), Locale('en')],
          home: const InvoiceEditScreen(id: 'new'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Acme Workshops'), findsOneWidget);
    expect(find.text('Custom line (type below)'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save invoice'), findsOneWidget);
    await tester.tap(find.text('Custom line (type below)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Call-out'), findsWidgets);
    await tester.tap(find.text('Call-out').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Call-out'), findsWidgets);
  });

  testWidgets('create invoice from dropdowns via controller does not throw', (tester) async {
    final controller = await tester.runAsync(() => controllerWith(customer: true, product: true));
    expect(controller, isNotNull);
    final now = Za.nowMillis();
    final product = controller!.products.single;
    final customer = controller.customers.single;
    final line = InvoiceLineItem(
      id: 'l1',
      invoiceId: 'inv-ui',
      position: 0,
      description: '',
    ).applyProduct(product);

    await tester.runAsync(() async {
      await controller.saveInvoice(
        invoice: Invoice(
          id: 'inv-ui',
          businessId: controller.business!.id,
          customerId: customer.id,
          number: 'INV-2026-0001',
          status: InvoiceStatus.draft,
          issueDate: now,
          dueDate: Za.plusDays(now, 30),
          createdAt: now,
          updatedAt: now,
        ),
        items: [line],
        bumpNumber: true,
      );
    });

    expect(controller.invoices, isNotEmpty);
    expect(controller.invoices.single.customerId, customer.id);
    expect(controller.invoices.single.total, closeTo(977.5, 0.001));
    expect(controller.customers, isNotEmpty);
    expect(controller.products, isNotEmpty);
  });

  testWidgets('saving without a customer shows an error instead of crashing', (tester) async {
    final controller = await tester.runAsync(() => controllerWith(customer: false, product: true));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller!,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  try {
                    await controller.saveInvoice(
                      invoice: Invoice(
                        id: 'inv-bad',
                        businessId: 'b1',
                        customerId: '',
                        number: 'INV-2026-0001',
                        status: InvoiceStatus.draft,
                        issueDate: Za.todayMillis(),
                        dueDate: Za.plusDays(Za.todayMillis(), 30),
                        createdAt: Za.nowMillis(),
                        updatedAt: Za.nowMillis(),
                      ),
                      items: [
                        InvoiceLineItem(
                          id: 'l1',
                          invoiceId: 'inv-bad',
                          position: 0,
                          description: 'Work',
                        ),
                      ],
                      bumpNumber: true,
                    );
                  } on InvoiceSaveException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
                child: const Text('Force save'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Force save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('customer'), findsOneWidget);
    expect(controller.invoices, isEmpty);
  });
}
