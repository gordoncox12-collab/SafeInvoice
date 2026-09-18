import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/native_share.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/data/share_payload.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Uint8List tinyPng;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en_ZA');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = const Color(0xFFCC2200));
    final image = await recorder.endRecording().toImage(16, 16);
    tinyPng = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  });

  setUp(() => tmp = Directory.systemTemp.createTempSync('si-pdf-'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('share helper names PDF Invoice-NUMBER.pdf with application/pdf', () {
    expect(invoicePdfFileName('INV-2026-0001'), 'Invoice-INV-2026-0001.pdf');
    expect(invoicePdfFileName('INV 2026/0001'), 'Invoice-INV_2026_0001.pdf');
    expect(invoicePdfMime, 'application/pdf');
  });

  test('stageInvoicePdfForShare copies bytes to a content-URI-friendly cache file', () async {
    final source = File(p.join(tmp.path, 'raw.pdf'));
    await source.writeAsBytes(List<int>.filled(200, 37), flush: true);
    final cache = Directory(p.join(tmp.path, 'share-cache'));
    final staged = await stageInvoicePdfForShare(
      source: source,
      cacheDir: cache,
      number: 'INV-2026-0001',
    );
    expect(staged.existsSync(), isTrue);
    expect(p.basename(staged.path), 'Invoice-INV-2026-0001.pdf');
    expect(staged.lengthSync(), 200);
  });

  Future<InvoiceRepository> repo() async {
    final storage = LocalStorage(tmp);
    final database = await AppDatabase.open(p.join(tmp.path, 'safeinvoice.db'));
    return InvoiceRepository(
      db: database.db,
      storage: storage,
      excel: ExcelService(),
      pdf: InvoicePdfService(storage),
    );
  }

  test('logo update persists and PDF writer embeds the image', () async {
    final r = await repo();
    final now = Za.nowMillis();
    var biz = Business(
      id: 'b1',
      name: 'Cox Electrical',
      email: 'books@example.com',
      createdAt: now,
      updatedAt: now,
    );
    await r.saveBusiness(biz);
    biz = await r.saveBusinessLogo(biz, tinyPng, 'logo.png');
    expect(biz.logoPath, isNotNull);
    final loaded = await r.getBusiness('b1');
    expect(loaded!.logoPath, biz.logoPath);
    expect(r.storage.resolve(loaded.logoPath!).existsSync(), isTrue);

    await r.saveCustomer(
      Customer(id: 'c1', businessId: 'b1', name: 'Acme', createdAt: now, updatedAt: now),
    );
    await r.saveInvoice(
      invoice: Invoice(
        id: 'inv1',
        businessId: 'b1',
        customerId: 'c1',
        number: 'INV-2026-0001',
        status: InvoiceStatus.draft,
        issueDate: now,
        dueDate: Za.plusDays(now, 30),
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        InvoiceLineItem(id: 'l1', invoiceId: 'inv1', position: 0, description: 'Call-out', quantity: 1, unitPrice: 850),
      ],
      bumpNumber: true,
    );
    final pdf = await r.generatePdf('inv1');
    expect(pdf, isNotNull);
    expect(p.basename(pdf!.path), 'Invoice-INV-2026-0001.pdf');
    final text = String.fromCharCodes(pdf.readAsBytesSync());
    expect(text.contains('/Image'), isTrue);
    expect(pdf.lengthSync(), greaterThan(1000));
  });

  test('PDF contains signature image when present', () async {
    final r = await repo();
    final now = Za.nowMillis();
    await r.saveBusiness(
      Business(id: 'b1', name: 'Cox Electrical', createdAt: now, updatedAt: now),
    );
    await r.saveCustomer(
      Customer(id: 'c1', businessId: 'b1', name: 'Acme', createdAt: now, updatedAt: now),
    );
    await r.saveInvoice(
      invoice: Invoice(
        id: 'inv1',
        businessId: 'b1',
        customerId: 'c1',
        number: 'INV-2026-0002',
        status: InvoiceStatus.draft,
        issueDate: now,
        dueDate: Za.plusDays(now, 30),
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        InvoiceLineItem(id: 'l1', invoiceId: 'inv1', position: 0, description: 'Labour', quantity: 2, unitPrice: 500),
      ],
      bumpNumber: false,
    );
    final unsigned = await r.generatePdf('inv1');
    final unsignedSize = unsigned!.lengthSync();
    final unsignedText = String.fromCharCodes(unsigned.readAsBytesSync());

    final invoice = (await r.getInvoice('inv1'))!;
    await r.saveSignature(invoice, tinyPng);
    final signed = await r.generatePdf('inv1');
    expect(signed, isNotNull);
    final signedBytes = signed!.readAsBytesSync();
    final signedText = String.fromCharCodes(signedBytes);
    expect(signedText.contains('/Image'), isTrue);
    expect(signedBytes.length, greaterThan(unsignedSize));
    expect(unsignedText.contains('TAX') || signedText.contains('Invoice') || signed.path.endsWith('.pdf'), isTrue);
  });

  testWidgets('NativeShare maps WhatsApp-missing and keeps application/pdf', (tester) async {
    const channel = MethodChannel('app.safeinvoice/native');
    MethodCall? seen;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      throw PlatformException(
        code: 'no_whatsapp',
        message: 'WhatsApp is not installed on this phone. Install WhatsApp, then try again.',
      );
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final outcome = await NativeShare.shareFile(
      path: p.join(tmp.path, 'Invoice-INV-2026-0001.pdf'),
      mime: invoicePdfMime,
      title: 'Invoice INV-2026-0001',
      body: 'Please find invoice INV-2026-0001',
      target: 'whatsapp',
      displayName: invoicePdfFileName('INV-2026-0001'),
    );
    expect(outcome.ok, isFalse);
    expect(outcome.message, contains('WhatsApp is not installed'));
    expect(seen!.method, 'shareFile');
    expect(seen!.arguments['mime'], invoicePdfMime);
    expect(seen!.arguments['displayName'], 'Invoice-INV-2026-0001.pdf');
    expect(seen!.arguments['target'], 'whatsapp');
  });

  testWidgets('NativeShare Email uses application/pdf and FileProvider path', (tester) async {
    const channel = MethodChannel('app.safeinvoice/native');
    MethodCall? seen;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final outcome = await NativeShare.shareFile(
      path: '/tmp/Invoice-INV-2026-0001.pdf',
      mime: invoicePdfMime,
      title: 'Invoice INV-2026-0001',
      body: 'Please find invoice INV-2026-0001',
      email: 'acme@example.com',
      target: 'email',
      displayName: 'Invoice-INV-2026-0001.pdf',
    );
    expect(outcome.ok, isTrue);
    expect(seen!.arguments['mime'], 'application/pdf');
    expect(seen!.arguments['email'], 'acme@example.com');
    expect(seen!.arguments['target'], 'email');
    expect(seen!.arguments['displayName'], 'Invoice-INV-2026-0001.pdf');
  });
}
