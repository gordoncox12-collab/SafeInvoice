import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/domain/balance.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en_ZA');
  });

  setUp(() => tmp = Directory.systemTemp.createTempSync('si-25-'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
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

  Future<Invoice> seedInvoice(InvoiceRepository r, {String id = 'inv1', String number = 'INV-2026-0001'}) async {
    final now = Za.nowMillis();
    await r.saveBusiness(Business(id: 'b1', name: 'Cox Electrical', createdAt: now, updatedAt: now));
    await r.saveCustomer(
      Customer(id: 'c1', businessId: 'b1', name: 'Acme', createdAt: now, updatedAt: now),
    );
    return r.saveInvoice(
      invoice: Invoice(
        id: id,
        businessId: 'b1',
        customerId: 'c1',
        number: number,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: Za.plusDays(now, 30),
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        InvoiceLineItem(id: 'l-$id', invoiceId: id, position: 0, description: 'Call-out', quantity: 1, unitPrice: 1000),
      ],
      bumpNumber: true,
    );
  }

  test('partial payments persist and update paid / outstanding / status', () async {
    final r = await repo();
    final saved = await seedInvoice(r);
    expect(saved.total, closeTo(1150, 0.001));

    await r.recordPayment(
      invoice: saved,
      amount: 400,
      method: 'EFT',
      occurredAt: DateTime(2026, 9, 20).millisecondsSinceEpoch,
    );
    var loaded = await r.getInvoice('inv1');
    expect(loaded!.status, InvoiceStatus.partiallyPaid);
    var details = await r.getInvoiceDetails('inv1');
    expect(details!.payments.length, 1);
    expect(details.payments.single.amount, closeTo(400, 0.001));
    expect(details.payments.single.method, 'EFT');
    var balance = InvoiceBalance.of(loaded, details.payments);
    expect(balance.amountPaid, closeTo(400, 0.001));
    expect(balance.invoiceOutstanding, closeTo(750, 0.001));

    await r.recordPayment(invoice: loaded, amount: 750, method: 'Cash');
    loaded = await r.getInvoice('inv1');
    details = await r.getInvoiceDetails('inv1');
    expect(loaded!.status, InvoiceStatus.paid);
    balance = InvoiceBalance.of(loaded, details!.payments);
    expect(balance.amountPaid, closeTo(1150, 0.001));
    expect(balance.invoiceOutstanding, 0);
  });

  test('brought forward persists and increases document balance due', () async {
    final r = await repo();
    await seedInvoice(r);
    final existing = (await r.getInvoice('inv1'))!;
    await r.saveInvoice(
      invoice: existing.copyWith(broughtForward: 250, status: InvoiceStatus.sent),
      items: [
        InvoiceLineItem(id: 'l-inv1', invoiceId: 'inv1', position: 0, description: 'Call-out', quantity: 1, unitPrice: 1000),
      ],
      bumpNumber: false,
    );
    final loaded = await r.getInvoice('inv1');
    expect(loaded!.broughtForward, closeTo(250, 0.001));
    await r.recordPayment(invoice: loaded, amount: 100, method: 'Cash');
    final details = await r.getInvoiceDetails('inv1');
    final balance = InvoiceBalance.of((await r.getInvoice('inv1'))!, details!.payments);
    expect(balance.amountDue, closeTo(1400, 0.001));
    expect(balance.documentOutstanding, closeTo(1300, 0.001));
    expect(balance.invoiceOutstanding, closeTo(1050, 0.001));
    expect((await r.getInvoice('inv1'))!.status, InvoiceStatus.partiallyPaid);
  });

  test('customer outstanding sums remaining invoice totals', () async {
    final r = await repo();
    final first = await seedInvoice(r);
    await r.recordPayment(invoice: first, amount: 150, method: 'EFT');
    final now = Za.nowMillis();
    await r.saveInvoice(
      invoice: Invoice(
        id: 'inv2',
        businessId: 'b1',
        customerId: 'c1',
        number: 'INV-2026-0002',
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: Za.plusDays(now, 30),
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        InvoiceLineItem(id: 'l2', invoiceId: 'inv2', position: 0, description: 'Parts', quantity: 1, unitPrice: 200),
      ],
      bumpNumber: true,
    );
    final invoices = await r.invoices('b1');
    final txs = await r.transactions('b1');
    expect(customerOutstandingFor(invoices, txs, 'c1'), closeTo(1230, 0.001));
    expect(booksOutstandingFor(invoices, txs), closeTo(1230, 0.001));
  });
}
