import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safeinvoice/data/database.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/data/local_storage.dart';
import 'package:safeinvoice/data/pdf_service.dart';
import 'package:safeinvoice/data/repository.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('safeinvoice-test-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

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

  Business business(String id) {
    final now = Za.nowMillis();
    return Business(
      id: id,
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
  }

  Customer customer(String id, String businessId) {
    final now = Za.nowMillis();
    return Customer(
      id: id,
      businessId: businessId,
      name: 'Acme Workshops',
      email: 'acme@example.com',
      createdAt: now,
      updatedAt: now,
    );
  }

  Product product(String id, String businessId) {
    final now = Za.nowMillis();
    return Product(
      id: id,
      businessId: businessId,
      name: 'Call-out',
      description: 'First hour',
      unitPrice: 850,
      taxable: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('business → product → customer → invoice with dropdown mapping does not throw', () async {
    final repo = await openRepo();
    await repo.saveBusiness(business('b1'));
    await repo.saveProduct(product('p1', 'b1'));
    await repo.saveCustomer(customer('c1', 'b1'));

    final catalog = await repo.products('b1');
    expect(catalog, isNotEmpty);
    final picked = catalog.first;

    final now = Za.nowMillis();
    final invoiceId = 'inv-1';
    final line = InvoiceLineItem(
      id: 'l1',
      invoiceId: invoiceId,
      position: 0,
      description: '',
    ).applyProduct(picked);

    final saved = await repo.saveInvoice(
      invoice: Invoice(
        id: invoiceId,
        businessId: 'b1',
        customerId: 'c1',
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

    expect(saved.number, 'INV-2026-0001');
    expect(saved.customerId, 'c1');
    expect(saved.subtotal, closeTo(850, 0.001));
    expect(saved.vatAmount, closeTo(127.5, 0.001));
    expect(saved.total, closeTo(977.5, 0.001));

    final customersAfter = await repo.customers('b1');
    expect(customersAfter.map((c) => c.id), contains('c1'));
    final productsAfter = await repo.products('b1');
    expect(productsAfter.map((p) => p.id), contains('p1'));
    final details = await repo.getInvoiceDetails(invoiceId);
    expect(details, isNotNull);
    expect(details!.items.single.productId, 'p1');
    expect(details.items.single.description, 'Call-out — First hour');

    final biz = await repo.getBusiness('b1');
    expect(biz!.nextInvoiceNumber, 2);

    final again = await repo.saveInvoice(
      invoice: saved.copyWith(notes: 'Follow-up'),
      items: details.items,
      bumpNumber: false,
    );
    expect(again.notes, 'Follow-up');
    expect((await repo.customers('b1')).length, 1);
    expect((await repo.invoices('b1')).length, 1);
  });

  test('bumping invoice number does not cascade-delete customers', () async {
    final repo = await openRepo();
    await repo.saveBusiness(business('b1'));
    await repo.saveCustomer(customer('c1', 'b1'));
    await repo.saveProduct(product('p1', 'b1'));
    final now = Za.nowMillis();
    await repo.saveInvoice(
      invoice: Invoice(
        id: 'inv-a',
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
        InvoiceLineItem(id: 'l1', invoiceId: 'inv-a', position: 0, description: 'Labour', quantity: 1, unitPrice: 100),
      ],
      bumpNumber: true,
    );
    await repo.saveInvoice(
      invoice: Invoice(
        id: 'inv-b',
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
        InvoiceLineItem(id: 'l2', invoiceId: 'inv-b', position: 0, description: 'Parts', quantity: 1, unitPrice: 200),
      ],
      bumpNumber: true,
    );
    expect((await repo.customers('b1')).length, 1);
    expect((await repo.invoices('b1')).length, 2);
    expect((await repo.getBusiness('b1'))!.nextInvoiceNumber, 3);
  });

  test('missing customer is a user-visible error, not a crash', () async {
    final repo = await openRepo();
    await repo.saveBusiness(business('b1'));
    final now = Za.nowMillis();
    expect(
      () => repo.saveInvoice(
        invoice: Invoice(
          id: 'inv-x',
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
          InvoiceLineItem(id: 'l1', invoiceId: 'inv-x', position: 0, description: 'Work'),
        ],
        bumpNumber: true,
      ),
      throwsA(isA<InvoiceSaveException>()),
    );
    expect(
      () => repo.saveInvoice(
        invoice: Invoice(
          id: 'inv-y',
          businessId: 'b1',
          customerId: 'missing',
          number: 'INV-2026-0001',
          status: InvoiceStatus.draft,
          issueDate: now,
          dueDate: Za.plusDays(now, 30),
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          InvoiceLineItem(id: 'l1', invoiceId: 'inv-y', position: 0, description: 'Work'),
        ],
        bumpNumber: false,
      ),
      throwsA(
        isA<InvoiceSaveException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          contains('customer'),
        ),
      ),
    );
  });

  test('empty line items are rejected', () async {
    final repo = await openRepo();
    await repo.saveBusiness(business('b1'));
    await repo.saveCustomer(customer('c1', 'b1'));
    final now = Za.nowMillis();
    expect(
      () => repo.saveInvoice(
        invoice: Invoice(
          id: 'inv-z',
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
          InvoiceLineItem(id: 'l1', invoiceId: 'inv-z', position: 0, description: '  '),
        ],
        bumpNumber: false,
      ),
      throwsA(isA<InvoiceSaveException>()),
    );
  });

  test('theme settings persist', () async {
    final repo = await openRepo();
    await repo.saveSettings(
      const AppSettings(themeMode: ThemeModeOption.dark, accentPalette: AccentPalette.coral),
    );
    final loaded = await repo.getSettings();
    expect(loaded.themeMode, ThemeModeOption.dark);
    expect(loaded.accentPalette, AccentPalette.coral);
  });

  test('v1 database upgrades to products without dropping invoices', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = p.join(tmp.path, 'legacy.db');
    final v1 = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE businesses (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, tradingName TEXT, registrationNumber TEXT,
  vatNumber TEXT, email TEXT NOT NULL, phone TEXT NOT NULL, addressLine1 TEXT NOT NULL,
  addressLine2 TEXT, city TEXT NOT NULL, province TEXT NOT NULL, postalCode TEXT NOT NULL,
  country TEXT NOT NULL, bankName TEXT, bankAccountName TEXT, bankAccountNumber TEXT,
  bankBranchCode TEXT, logoPath TEXT, defaultCurrency TEXT NOT NULL, defaultVatPercent REAL NOT NULL,
  invoicePrefix TEXT NOT NULL, nextInvoiceNumber INTEGER NOT NULL, createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL, isActive INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE customers (
  id TEXT PRIMARY KEY, businessId TEXT NOT NULL, name TEXT NOT NULL, contactName TEXT,
  email TEXT, phone TEXT, addressLine1 TEXT, city TEXT, province TEXT, postalCode TEXT,
  vatNumber TEXT, notes TEXT, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
  FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE invoices (
  id TEXT PRIMARY KEY, businessId TEXT NOT NULL, customerId TEXT NOT NULL, number TEXT NOT NULL,
  status TEXT NOT NULL, issueDate INTEGER NOT NULL, dueDate INTEGER NOT NULL, currency TEXT NOT NULL,
  vatPercent REAL NOT NULL, discountAmount REAL NOT NULL, discountPercent REAL NOT NULL,
  notes TEXT, terms TEXT, signaturePath TEXT, pdfPath TEXT, templateId TEXT,
  subtotal REAL NOT NULL, vatAmount REAL NOT NULL, total REAL NOT NULL,
  createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
  FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE invoice_line_items (
  id TEXT PRIMARY KEY, invoiceId TEXT NOT NULL, position INTEGER NOT NULL,
  description TEXT NOT NULL, quantity REAL NOT NULL, unitPrice REAL NOT NULL, taxable INTEGER NOT NULL,
  FOREIGN KEY (invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE invoice_images (
  id TEXT PRIMARY KEY, invoiceId TEXT NOT NULL, path TEXT NOT NULL, sortOrder INTEGER NOT NULL,
  FOREIGN KEY (invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY, businessId TEXT NOT NULL, customerId TEXT, invoiceId TEXT, type TEXT NOT NULL,
  amount REAL NOT NULL, currency TEXT NOT NULL, occurredAt INTEGER NOT NULL, method TEXT,
  reference TEXT, notes TEXT, receiptPath TEXT, createdAt INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE notes (
  id TEXT PRIMARY KEY, businessId TEXT NOT NULL, customerId TEXT NOT NULL, title TEXT NOT NULL,
  body TEXT NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE folder_files (
  id TEXT PRIMARY KEY, businessId TEXT NOT NULL, customerId TEXT NOT NULL, folderType TEXT NOT NULL,
  displayName TEXT NOT NULL, mimeType TEXT NOT NULL, relativePath TEXT NOT NULL,
  sizeBytes INTEGER NOT NULL, createdAt INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE invoice_templates (
  id TEXT PRIMARY KEY, businessId TEXT NOT NULL, name TEXT NOT NULL, isDefault INTEGER NOT NULL,
  primaryColor INTEGER NOT NULL, accentColor INTEGER NOT NULL, logoPath TEXT, layout TEXT NOT NULL,
  showBankDetails INTEGER NOT NULL, footerText TEXT, headerImagePath TEXT, extraImagePath TEXT,
  logoAlignment TEXT NOT NULL, marginPreset TEXT NOT NULL, picturePlacement TEXT NOT NULL,
  showSignatureLine INTEGER NOT NULL, headerBanner INTEGER NOT NULL, createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE app_settings (
  id INTEGER PRIMARY KEY, themeMode TEXT NOT NULL, accentPalette TEXT NOT NULL, activeBusinessId TEXT
)''');
        await db.insert('app_settings', {
          'id': 1,
          'themeMode': 'SYSTEM',
          'accentPalette': 'FOREST',
          'activeBusinessId': null,
        });
      },
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await v1.insert('businesses', business('b1').toMap());
    // v1 customers has no whatsapp column — insert a v1-shaped row.
    final customerRow = Map<String, Object?>.from(customer('c1', 'b1').toMap())..remove('whatsapp');
    await v1.insert('customers', customerRow);
    await v1.insert('invoices', {
      'id': 'old-inv',
      'businessId': 'b1',
      'customerId': 'c1',
      'number': 'INV-2026-0001',
      'status': 'DRAFT',
      'issueDate': now,
      'dueDate': now,
      'currency': 'ZAR',
      'vatPercent': 15,
      'discountAmount': 0,
      'discountPercent': 0,
      'notes': null,
      'terms': null,
      'signaturePath': null,
      'pdfPath': null,
      'templateId': null,
      'subtotal': 100,
      'vatAmount': 15,
      'total': 115,
      'createdAt': now,
      'updatedAt': now,
    });
    await v1.close();

    final upgraded = await AppDatabase.open(dbPath);
    final products = await upgraded.db.query('products');
    expect(products, isEmpty);
    final invoices = await upgraded.db.query('invoices');
    expect(invoices.single['id'], 'old-inv');
    expect(invoices.single['issuedAt'], now);
    final info = await upgraded.db.rawQuery('PRAGMA table_info(invoice_line_items)');
    expect(info.any((row) => row['name'] == 'productId'), isTrue);
    final customerInfo = await upgraded.db.rawQuery('PRAGMA table_info(customers)');
    expect(customerInfo.any((row) => row['name'] == 'whatsapp'), isTrue);
    final invoiceInfo = await upgraded.db.rawQuery('PRAGMA table_info(invoices)');
    expect(invoiceInfo.any((row) => row['name'] == 'paymentMethod'), isTrue);
    expect(invoiceInfo.any((row) => row['name'] == 'podSignaturePath'), isTrue);
    await upgraded.db.insert('customers', {
      ...customer('c2', 'b1').toMap(),
      'whatsapp': '0820000000',
    });
    final loaded = await upgraded.db.query('customers', where: 'id = ?', whereArgs: ['c2']);
    expect(loaded.single['whatsapp'], '0820000000');
    await upgraded.db.close();
  });
}
