import 'dart:io';
import 'dart:typed_data';
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
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:safeinvoice/ui/app_controller.dart';
import 'package:safeinvoice/ui/invoice_preview.dart';
import 'package:safeinvoice/ui/screens/invoice_screens.dart';
import 'package:safeinvoice/ui/screens/shell.dart';
import 'package:safeinvoice/ui/theme.dart';
import 'package:safeinvoice/ui/widgets.dart';
import 'package:signature/signature.dart' as sig;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const artifactsDir = '/opt/cursor/artifacts';

Future<void> _loadScreenshotFonts() async {
  final fontDir = '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts';
  await ui.loadFontFromList(
    File(p.join(fontDir, 'Roboto-Regular.ttf')).readAsBytesSync(),
    fontFamily: 'Roboto',
  );
  await ui.loadFontFromList(
    File(p.join(fontDir, 'Roboto-Bold.ttf')).readAsBytesSync(),
    fontFamily: 'Roboto',
  );
  await ui.loadFontFromList(
    File(p.join(fontDir, 'MaterialIcons-Regular.otf')).readAsBytesSync(),
    fontFamily: 'MaterialIcons',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en_ZA');
    await _loadScreenshotFonts();
    Directory(artifactsDir).createSync(recursive: true);
  });

  setUp(() => tmp = Directory.systemTemp.createTempSync('si-shot-'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<Uint8List> paintPng({required Color color, required String label}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 240, 90), Paint()..color = color);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(12, 28));
    final image = await recorder.endRecording().toImage(240, 90);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final boundary = tester.renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(p.join(artifactsDir, '$name.png')).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Widget framed(Widget home, AppController controller) {
    final base = safeInvoiceTheme(
      mode: ThemeModeOption.light,
      accent: AccentPalette.coral,
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
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
        ),
        home: RepaintBoundary(child: home),
      ),
    );
  }

  Future<InvoiceRepository> openRepo() async {
    final storage = LocalStorage(tmp);
    final database = await AppDatabase.open(p.join(tmp.path, 'safeinvoice.db'));
    return InvoiceRepository(
      db: database.db,
      storage: storage,
      excel: ExcelService(),
      pdf: InvoicePdfService(storage),
    );
  }

  Future<AppController> seed(
    WidgetTester tester, {
    required File logo,
    required File signature,
    bool withInvoice = true,
  }) async {
    final repo = await openRepo();
    final now = Za.nowMillis();
    var biz = Business(
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
    );
    await repo.saveBusiness(biz);
    biz = await repo.saveBusinessLogo(biz, await logo.readAsBytes(), 'logo.png');
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
    await repo.saveProduct(
      Product(
        id: 'p2',
        businessId: 'b1',
        name: 'Labour hour',
        description: 'Additional hour',
        unitPrice: 450,
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
    await repo.saveCustomer(
      Customer(
        id: 'c2',
        businessId: 'b1',
        name: 'Harbour Lights CC',
        email: 'ap@harbour.example',
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (withInvoice) {
      await repo.saveInvoice(
        invoice: Invoice(
          id: 'inv1',
          businessId: 'b1',
          customerId: 'c1',
          number: 'INV-2026-0001',
          status: InvoiceStatus.draft,
          issueDate: now,
          dueDate: Za.plusDays(now, 30),
          notes: 'Thank you for your business.',
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
      await repo.saveSignature((await repo.getInvoice('inv1'))!, await signature.readAsBytes());
    }
    final controller = AppController(repo);
    await controller.bootstrap();
    return controller;
  }

  testWidgets('capture Gordon screenshot set', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late File logo;
    late File signature;
    await tester.runAsync(() async {
      logo = File(p.join(tmp.path, 'logo.png'))..writeAsBytesSync(await paintPng(color: const Color(0xFF0D9488), label: 'LOGO'));
      signature = File(p.join(tmp.path, 'sig.png'))
        ..writeAsBytesSync(await paintPng(color: const Color(0xFF15201E), label: 'G. Cox'));
    });

    final controller = await tester.runAsync(
      () => seed(tester, logo: logo, signature: signature, withInvoice: false),
    );

    await tester.pumpWidget(framed(const HomeScreen(), controller!));
    await tester.pump();
    expect(find.text('Get ready to invoice'), findsOneWidget);
    await capture(tester, '01_home_onboarding_checklist');

    await tester.runAsync(() async {
      final now = Za.nowMillis();
      await controller.repo.saveInvoice(
        invoice: Invoice(
          id: 'inv1',
          businessId: 'b1',
          customerId: 'c1',
          number: 'INV-2026-0001',
          status: InvoiceStatus.draft,
          issueDate: now,
          dueDate: Za.plusDays(now, 30),
          notes: 'Thank you for your business.',
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
      await controller.repo.saveSignature(
        (await controller.repo.getInvoice('inv1'))!,
        await signature.readAsBytes(),
      );
      await controller.repo.savePodSignature(
        (await controller.repo.getInvoice('inv1'))!,
        await signature.readAsBytes(),
      );
      await controller.repo.setPaymentOption('inv1', PaymentOption.eft, note: 'Paid on collection');
      await controller.refresh();
    });

    await tester.pumpWidget(framed(const BusinessEditScreen(id: 'b1'), controller));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Change logo'), findsOneWidget);
    await capture(tester, '02_business_logo_change');

    await tester.pumpWidget(
      framed(
        Scaffold(
          appBar: AppBar(title: const Text('Products & customers')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchableSelect<Product>(
                label: 'Find product',
                value: null,
                items: controller.products,
                placeholder: 'Tap to search and open',
                searchHint: 'Search catalog',
                labelOf: (p) => p.name,
                subtitleOf: (p) =>
                    '${Za.money(p.unitPrice, 'ZAR')}${p.taxable ? ' · VAT' : ' · no VAT'}',
                onChanged: (_) {},
              ),
              for (final product in controller.products)
                ListTile(
                  title: Text(product.name),
                  subtitle: Text(product.description ?? ''),
                  trailing: Text(Za.money(product.unitPrice, 'ZAR')),
                ),
              const SizedBox(height: 16),
              SearchableSelect<Customer>(
                label: 'Find customer',
                value: null,
                items: controller.customers,
                placeholder: 'Tap to search and open',
                searchHint: 'Search name, email or phone',
                labelOf: (c) => c.name,
                subtitleOf: (c) =>
                    [c.email, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                onChanged: (_) {},
              ),
              for (final c in controller.customers)
                ListTile(
                  title: Text(c.name),
                  subtitle: Text(c.email ?? ''),
                ),
            ],
          ),
        ),
        controller,
      ),
    );
    await tester.pump();
    expect(find.text('Find product'), findsOneWidget);
    expect(find.text('Find customer'), findsOneWidget);
    expect(find.text('Call-out'), findsWidgets);
    expect(find.text('Acme Workshops'), findsWidgets);
    await capture(tester, '03_products_customer_dropdowns');

    await tester.pumpWidget(framed(const InvoiceEditScreen(id: 'inv1'), controller));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Acme Workshops'), findsWidgets);
    expect(find.textContaining('Call-out'), findsWidgets);
    await capture(tester, '04_invoice_editor_dropdowns');

    final padController = sig.SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFF15201E),
      exportBackgroundColor: Colors.white,
      points: [
        sig.Point(const Offset(24, 90), sig.PointType.tap, 1),
        sig.Point(const Offset(70, 40), sig.PointType.move, 1),
        sig.Point(const Offset(120, 100), sig.PointType.move, 1),
        sig.Point(const Offset(170, 50), sig.PointType.move, 1),
        sig.Point(const Offset(230, 95), sig.PointType.move, 1),
        sig.Point(const Offset(280, 70), sig.PointType.move, 1),
      ],
    );
    addTearDown(padController.dispose);
    await tester.pumpWidget(
      framed(
        Scaffold(
          appBar: AppBar(
            title: const Text('Handwritten signature'),
            actions: [IconButton(onPressed: padController.clear, icon: const Icon(Icons.refresh))],
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
                  child: sig.Signature(controller: padController, backgroundColor: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(onPressed: () {}, child: const Text('Stamp on invoice')),
              ),
            ],
          ),
        ),
        controller,
      ),
    );
    await tester.pump();
    await capture(tester, '05_signature_capture_pad');

    final invoice = controller.invoices.single;
    final customer = controller.customers.firstWhere((c) => c.id == invoice.customerId);
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
                invoice: invoice.copyWith(
                  paymentMethod: PaymentOption.eft,
                  paymentNote: 'Paid on collection',
                  issuedAt: invoice.displayIssuedAt,
                  generatedAt: invoice.generatedAt ?? invoice.displayIssuedAt,
                ),
                items: [
                  InvoiceLineItem(
                    id: 'l1',
                    invoiceId: invoice.id,
                    position: 0,
                    description: 'Call-out — First hour',
                    quantity: 2,
                    unitPrice: 850,
                  ),
                ],
                logoFile: controller.repo.storage.resolve(controller.business!.logoPath!),
                signatureFile: controller.repo.storage.resolve(invoice.signaturePath!),
                podSignatureFile: controller.repo.storage.resolve(invoice.podSignaturePath!),
              ),
            ],
          ),
        ),
        controller,
      ),
    );
    await tester.pump();
    expect(find.text('TAX INVOICE'), findsOneWidget);
    expect(find.text('Authorised signature'), findsOneWidget);
    await capture(tester, '06_invoice_pdf_preview_logo_signature');

    await tester.pumpWidget(framed(InvoiceViewScreen(id: invoice.id), controller));
    await tester.pump();
    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Share PDF by Email'), findsOneWidget);
    expect(find.text('Share PDF on WhatsApp'), findsOneWidget);
    await capture(tester, '07_share_email_whatsapp');
    expect(find.text('Open WhatsApp chat'), findsOneWidget);
    await capture(tester, '11_whatsapp_actions');

    await tester.tap(find.text('Payment options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Consignment stock'), findsOneWidget);
    await capture(tester, '08_payment_options_tab');

    await tester.pumpWidget(framed(const HomeScreen(), controller));
    await tester.pump();
    expect(find.text('Saved for later'), findsOneWidget);
    await capture(tester, '09_draft_for_later');

    await tester.pumpWidget(
      framed(
        SignatureScreen(id: invoice.id, kind: SignatureKind.pod),
        controller,
      ),
    );
    await tester.pump();
    expect(find.text('Delivery receipt signature'), findsOneWidget);
    await capture(tester, '10_pod_signature');

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
                invoice: controller.invoices.single.copyWith(
                  paymentMethod: PaymentOption.eft,
                  issuedAt: controller.invoices.single.displayIssuedAt,
                  generatedAt: controller.invoices.single.displayIssuedAt,
                ),
                items: [
                  InvoiceLineItem(
                    id: 'l1',
                    invoiceId: invoice.id,
                    position: 0,
                    description: 'Call-out — First hour',
                    quantity: 2,
                    unitPrice: 850,
                  ),
                ],
                logoFile: controller.repo.storage.resolve(controller.business!.logoPath!),
                signatureFile: controller.repo.storage.resolve(controller.invoices.single.signaturePath!),
                podSignatureFile: controller.repo.storage.resolve(controller.invoices.single.podSignaturePath!),
              ),
            ],
          ),
        ),
        controller,
      ),
    );
    await tester.pump();
    expect(find.textContaining('Issued'), findsOneWidget);
    expect(find.textContaining('SAST'), findsWidgets);
    await capture(tester, '12_timestamp_preview');
  });
}
