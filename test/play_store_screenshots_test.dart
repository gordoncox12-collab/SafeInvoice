import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/domain/balance.dart';
import 'package:safeinvoice/domain/legal.dart';
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const playShotDir = '/workspace/play/store/phone';
const artifactsPlay = '/opt/cursor/artifacts/play';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en_ZA');
    final fontDir = '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts';
    await ui.loadFontFromList(File(p.join(fontDir, 'Roboto-Regular.ttf')).readAsBytesSync(), fontFamily: 'Roboto');
    await ui.loadFontFromList(File(p.join(fontDir, 'Roboto-Bold.ttf')).readAsBytesSync(), fontFamily: 'Roboto');
    await ui.loadFontFromList(File(p.join(fontDir, 'MaterialIcons-Regular.otf')).readAsBytesSync(), fontFamily: 'MaterialIcons');
    Directory(playShotDir).createSync(recursive: true);
    Directory(artifactsPlay).createSync(recursive: true);
  });

  setUp(() => tmp = Directory.systemTemp.createTempSync('si-play-'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final boundary = tester.renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final data = bytes!.buffer.asUint8List();
      File(p.join(playShotDir, '$name.png')).writeAsBytesSync(data);
      File(p.join(artifactsPlay, '$name.png')).writeAsBytesSync(data);
    });
  }

  Widget framed(Widget home, AppController controller) {
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
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
        ),
        home: RepaintBoundary(child: home),
      ),
    );
  }

  testWidgets('Play listing does not ship sample data and privacy URL is public https', (tester) async {
    expect(privacyPolicyUrl.startsWith('https://'), isTrue);
    expect(privacyPolicyUrl.contains('privacy-policy'), isTrue);
    final appData = Directory('lib');
    expect(File(p.join(appData.path, 'demo.dart')).existsSync(), isFalse);
  });

  testWidgets('capture Play phone screenshots from sample books that are not shipped', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppController controller;
    late Customer customer;
    final now = DateTime(2026, 10, 10, 9).millisecondsSinceEpoch;
    await tester.runAsync(() async {
    final storage = LocalStorage(tmp);
    final database = await AppDatabase.open(p.join(tmp.path, 'safeinvoice.db'));
    final repo = InvoiceRepository(
      db: database.db,
      storage: storage,
      excel: ExcelService(),
      pdf: InvoicePdfService(storage),
    );
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
    final older = DateTime(2026, 8, 1).millisecondsSinceEpoch;
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
      items: [
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
      items: [
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
    controller = AppController(repo);
    await controller.bootstrap();
    customer = controller.customers.single;
    });

    await tester.pumpWidget(framed(const HomeScreen(), controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await capture(tester, '01_home_outstanding');

    await tester.pumpWidget(framed(const InvoiceEditScreen(id: 'new', initialCustomerId: 'c1'), controller));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump();
    await capture(tester, '02_editor_auto_outstanding');

    await tester.pumpWidget(framed(const OutstandingScreen(), controller));
    await tester.pump();
    await capture(tester, '03_unpaid_orders');

    final unpaid = controller.unpaidOrders(customerId: 'c1');
    final amount = TextEditingController(text: '300');
    final reference = TextEditingController();
    addTearDown(amount.dispose);
    addTearDown(reference.dispose);
    await tester.pumpWidget(
      framed(
        Scaffold(
          appBar: AppBar(title: const Text('Pay outstanding')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PayOutstandingForm(
                customerName: 'Acme Workshops',
                remaining: controller.customerOutstanding('c1'),
                currency: 'ZAR',
                amount: amount,
                method: PaymentOption.eft,
                occurredAt: now,
                reference: reference,
                allocations: allocateOldestFirst(unpaid, 300),
                invoices: {for (final o in unpaid) o.invoice.id: o.invoice},
                onAmountChanged: () {},
                onMethod: (_) {},
                onDate: (_) {},
              ),
            ],
          ),
        ),
        controller,
      ),
    );
    await tester.pump();
    await capture(tester, '04_pay_outstanding');

    await tester.pumpWidget(
      framed(
        Scaffold(
          appBar: AppBar(title: const Text('Invoice preview')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InvoicePaperPreview(
                business: controller.business!,
                customer: customer,
                invoice: controller.invoices.firstWhere((i) => i.id == 'inv1'),
                items: [
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
        ),
        controller,
      ),
    );
    await tester.pump();
    await capture(tester, '05_pdf_preview');

    await tester.pumpWidget(framed(const CustomerDetailScreen(id: 'c1'), controller));
    await tester.pump();
    await capture(tester, '06_customer_outstanding');

    await tester.pumpWidget(framed(const InvoiceListScreen(filter: 'outstanding'), controller));
    await tester.pump();
    await capture(tester, '07_invoice_list');

    await tester.pumpWidget(framed(const SettingsScreen(), controller));
    await tester.pump();
    expect(find.text('Privacy policy'), findsOneWidget);
    await capture(tester, '08_settings_privacy');
  });
}
