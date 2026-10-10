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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('en_ZA');
  });

  setUp(() => tmp = Directory.systemTemp.createTempSync('si-26-'));
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

  Future<Invoice> addInvoice(
    InvoiceRepository r, {
    required String id,
    required String number,
    required double unit,
    required int issueDate,
    String status = 'sent',
  }) {
    return r.saveInvoice(
      invoice: Invoice(
        id: id,
        businessId: 'b1',
        customerId: 'c1',
        number: number,
        status: status == 'sent' ? InvoiceStatus.sent : InvoiceStatus.draft,
        issueDate: issueDate,
        dueDate: issueDate + 86400000,
        createdAt: issueDate,
        updatedAt: issueDate,
      ),
      items: [
        InvoiceLineItem(id: 'l-$id', invoiceId: id, position: 0, description: 'Work', quantity: 1, unitPrice: unit),
      ],
      bumpNumber: true,
    );
  }

  test('pay outstanding allocates oldest-first and persists payments', () async {
    final r = await repo();
    final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await r.saveBusiness(Business(id: 'b1', name: 'Cox Electrical', createdAt: now, updatedAt: now));
    await r.saveCustomer(Customer(id: 'c1', businessId: 'b1', name: 'Acme', createdAt: now, updatedAt: now));
    final older = await addInvoice(r, id: 'old', number: 'INV-2026-0001', unit: 200, issueDate: now);
    final newer = await addInvoice(
      r,
      id: 'new',
      number: 'INV-2026-0002',
      unit: 300,
      issueDate: now + 86400000 * 10,
    );
    expect(older.total, closeTo(230, 0.001));
    expect(newer.total, closeTo(345, 0.001));

    final created = await r.payOutstanding(
      businessId: 'b1',
      customerId: 'c1',
      amount: 300,
      method: 'EFT',
      occurredAt: now + 86400000 * 20,
    );
    expect(created.length, 2);
    expect((await r.getInvoice('old'))!.status, InvoiceStatus.paid);
    expect((await r.getInvoice('new'))!.status, InvoiceStatus.partiallyPaid);
    final txs = await r.transactions('b1');
    expect(InvoiceBalance.paidToward(txs, 'old'), closeTo(230, 0.001));
    expect(InvoiceBalance.paidToward(txs, 'new'), closeTo(70, 0.001));
    expect(customerOutstandingFor(await r.invoices('b1'), txs, 'c1'), closeTo(275, 0.001));
  });

  test('pay outstanding against one invoice does not touch newer invoices', () async {
    final r = await repo();
    final now = DateTime(2026, 2, 1).millisecondsSinceEpoch;
    await r.saveBusiness(Business(id: 'b1', name: 'Cox Electrical', createdAt: now, updatedAt: now));
    await r.saveCustomer(Customer(id: 'c1', businessId: 'b1', name: 'Acme', createdAt: now, updatedAt: now));
    await addInvoice(r, id: 'old', number: 'INV-2026-0001', unit: 200, issueDate: now);
    await addInvoice(r, id: 'new', number: 'INV-2026-0002', unit: 300, issueDate: now + 1000);
    await r.payOutstanding(
      businessId: 'b1',
      customerId: 'c1',
      amount: 50,
      method: 'Cash',
      invoiceId: 'new',
    );
    final txs = await r.transactions('b1');
    expect(InvoiceBalance.paidToward(txs, 'old'), 0);
    expect(InvoiceBalance.paidToward(txs, 'new'), closeTo(50, 0.001));
    expect((await r.getInvoice('old'))!.status, InvoiceStatus.sent);
    expect((await r.getInvoice('new'))!.status, InvoiceStatus.partiallyPaid);
  });
}
