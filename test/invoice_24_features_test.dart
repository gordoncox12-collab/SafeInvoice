import 'dart:io';
import 'dart:ui' as ui;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/data/whatsapp.dart';
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

  setUp(() => tmp = Directory.systemTemp.createTempSync('si-24-'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('WhatsApp URL builder normalises ZA numbers', () {
    expect(normalizeWhatsAppDigits('082 123 4567'), '27821234567');
    expect(whatsappChatUrl('0821234567'), 'https://wa.me/27821234567');
    expect(whatsappChatUrl('+27 82 123 4567'), 'https://wa.me/27821234567');
    expect(customerWhatsAppNumber('0820000000', '0210000000'), '0820000000');
    expect(customerWhatsAppNumber(null, '0820000000'), '0820000000');
    expect(customerWhatsAppNumber(null, null), isNull);
    expect(() => whatsappChatUrl(''), throwsFormatException);
  });

  test('timestamp formatting includes time and SAST', () {
    final noon = DateTime(2026, 9, 18, 14, 32).millisecondsSinceEpoch;
    final stamp = Za.dateTime(noon);
    // en_ZA DateFormat uses "Sept"; other English locales use "Sep".
    expect(stamp, contains('18 Sep'));
    expect(stamp, contains('2026'));
    expect(stamp, contains('14:32'));
    expect(stamp, endsWith('SAST'));
    expect(Za.date(noon), contains('18 Sep'));
    expect(Za.date(noon), contains('2026'));
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

  Future<Invoice> seedInvoice(InvoiceRepository r, {InvoiceStatus status = InvoiceStatus.draft}) async {
    final now = Za.nowMillis();
    await r.saveBusiness(
      Business(id: 'b1', name: 'Cox Electrical', createdAt: now, updatedAt: now),
    );
    await r.saveCustomer(
      Customer(
        id: 'c1',
        businessId: 'b1',
        name: 'Acme',
        phone: '0821234567',
        whatsapp: '0821234567',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return r.saveInvoice(
      invoice: Invoice(
        id: 'inv1',
        businessId: 'b1',
        customerId: 'c1',
        number: 'INV-2026-0001',
        status: status,
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
  }

  test('draft-for-later persists as draft and reopens with lines', () async {
    final r = await repo();
    final saved = await seedInvoice(r);
    expect(saved.status, InvoiceStatus.draft);
    expect(saved.savedForLater, isTrue);
    expect(saved.issuedAt, isNotNull);
    final loaded = await r.getInvoice('inv1');
    expect(loaded!.savedForLater, isTrue);
    final details = await r.getInvoiceDetails('inv1');
    expect(details!.items.single.description, 'Call-out');
    final drafts = (await r.invoices('b1')).where((i) => i.savedForLater);
    expect(drafts.length, 1);
  });

  test('payment method persists on invoice and PDF text', () async {
    final r = await repo();
    await seedInvoice(r);
    await r.setPaymentOption('inv1', PaymentOption.consignmentStock, note: 'Hold until Friday');
    final loaded = await r.getInvoice('inv1');
    expect(loaded!.paymentMethod, PaymentOption.consignmentStock);
    expect(loaded.paymentNote, 'Hold until Friday');
    expect(paymentOptionLabel(loaded.paymentMethod!), 'Consignment stock');
    expect(paymentOptionWire(PaymentOption.swappedStock), 'SWAPPED_STOCK');
    expect(paymentOptionFrom('eft'), PaymentOption.eft);
    final pdf = await r.generatePdf('inv1');
    expect(pdf, isNotNull);
    final text = String.fromCharCodes(pdf!.readAsBytesSync());
    expect(text.contains('Consignment'), isTrue);
  });

  test('POD signature is stored and enlarges the PDF', () async {
    final r = await repo();
    await seedInvoice(r);
    final unsigned = await r.generatePdf('inv1');
    final unsignedSize = unsigned!.lengthSync();
    final invoice = (await r.getInvoice('inv1'))!;
    await r.savePodSignature(invoice, tinyPng);
    final signed = await r.generatePdf('inv1');
    expect(signed, isNotNull);
    expect((await r.getInvoice('inv1'))!.podSignaturePath, isNotNull);
    expect(signed!.lengthSync(), greaterThan(unsignedSize));
    final text = String.fromCharCodes(signed.readAsBytesSync());
    expect(text.contains('/Image'), isTrue);
  });

  test('archive writes a durable on-device PDF', () async {
    final r = await repo();
    await seedInvoice(r);
    final archived = await r.archiveInvoicePdf('inv1');
    expect(archived, isNotNull);
    expect(archived!.existsSync(), isTrue);
    expect(p.basename(archived.path), 'Invoice-INV-2026-0001.pdf');
    expect((await r.getInvoice('inv1'))!.savedToStoragePath, isNotNull);
    expect((await r.archivedInvoicePdfs('b1')).length, 1);
    expect((await r.getInvoice('inv1'))!.generatedAt, isNotNull);
  });
}
