import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:safeinvoice/ui/app.dart';
import 'package:safeinvoice/ui/app_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('safeinvoice-widget-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<AppController> seededController() async {
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
    final controller = AppController(repo);
    await controller.bootstrap();
    return controller;
  }

  testWidgets('home checklist then invoice save via dropdown mapping does not throw', (tester) async {
    final controller = await seededController();
    await tester.pumpWidget(SafeInvoiceApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Get ready to invoice'), findsOneWidget);
    expect(find.text('2. Add products'), findsOneWidget);
    expect(find.text('3. Add a customer'), findsOneWidget);
    expect(find.text('4. Create an invoice'), findsOneWidget);

    await tester.tap(find.text('New invoice'));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Product'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Call-out — First hour');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save invoice'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.invoices, isNotEmpty);
    expect(controller.customers, isNotEmpty);
    expect(controller.products, isNotEmpty);
    expect(controller.invoices.single.customerId, 'c1');
    expect(controller.invoices.single.total, greaterThan(0));
    expect(find.textContaining('Saved'), findsOneWidget);
  });

  testWidgets('saving without a customer shows an error instead of crashing', (tester) async {
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
        createdAt: now,
        updatedAt: now,
      ),
    );
    final controller = AppController(repo);
    await controller.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
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
                        issueDate: now,
                        dueDate: Za.plusDays(now, 30),
                        createdAt: now,
                        updatedAt: now,
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
    await tester.tap(find.text('Force save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('customer'), findsOneWidget);
    expect(controller.invoices, isEmpty);
  });
}
