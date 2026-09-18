import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import '../domain/money.dart';
import 'database.dart';
import 'excel_service.dart';
import 'local_storage.dart';
import 'pdf_service.dart';

class InvoiceRepository {
  InvoiceRepository({
    required this.db,
    required this.storage,
    required this.excel,
    required this.pdf,
  });

  final Database db;
  final LocalStorage storage;
  final ExcelService excel;
  final InvoicePdfService pdf;

  static Future<InvoiceRepository> open() async {
    final storage = await LocalStorage.open();
    final database = await AppDatabase.open(AppDatabase.defaultPath(storage.root.path));
    return InvoiceRepository(
      db: database.db,
      storage: storage,
      excel: ExcelService(),
      pdf: InvoicePdfService(storage),
    );
  }

  Future<AppSettings> getSettings() async {
    final rows = await db.query('app_settings', where: 'id = 1');
    if (rows.isEmpty) return const AppSettings();
    return AppSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await db.insert(
      'app_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Business>> businesses() async {
    final rows = await db.query('businesses', orderBy: 'name COLLATE NOCASE');
    return rows.map(Business.fromMap).toList();
  }

  Future<Business?> getBusiness(String id) async {
    final rows = await db.query('businesses', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Business.fromMap(rows.first);
  }

  Future<void> saveBusiness(Business entity) async {
    final existing = await getBusiness(entity.id);
    storage.businessDir(entity.id);
    final saved = entity.copyWith(updatedAt: Za.nowMillis());
    await db.insert('businesses', saved.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final settings = await getSettings();
    if (settings.activeBusinessId == null) {
      await saveSettings(settings.copyWith(activeBusinessId: saved.id));
    }
    if (existing == null) {
      final templates = await this.templates(saved.id);
      if (templates.isEmpty) {
        final now = Za.nowMillis();
        await saveTemplate(
          InvoiceTemplate(
            id: Za.newId(),
            businessId: saved.id,
            name: 'Standard',
            isDefault: true,
            footerText: '${saved.name}  ·  invoices stored on this device',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  Future<void> deleteBusiness(Business entity) async {
    await db.delete('businesses', where: 'id = ?', whereArgs: [entity.id]);
    final dir = storage.businessDir(entity.id);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  Future<List<Customer>> customers(String businessId) async {
    final rows = await db.query(
      'customers',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<void> saveCustomer(Customer entity) async {
    storage.customerDir(entity.businessId, entity.id);
    for (final type in FolderType.values) {
      storage.folder(entity.businessId, entity.id, type);
    }
    await db.insert(
      'customers',
      entity.copyWith(updatedAt: Za.nowMillis()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomer(Customer entity) async {
    await db.delete('customers', where: 'id = ?', whereArgs: [entity.id]);
    final dir = storage.customerDir(entity.businessId, entity.id);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  Future<List<Product>> products(String businessId) async {
    final rows = await db.query(
      'products',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProduct(String id) async {
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<void> saveProduct(Product entity) async {
    await db.insert(
      'products',
      entity.copyWith(updatedAt: Za.nowMillis()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProduct(Product entity) async {
    await db.delete('products', where: 'id = ?', whereArgs: [entity.id]);
  }

  Future<List<Invoice>> invoices(String businessId) async {
    final rows = await db.query(
      'invoices',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'issueDate DESC, number DESC',
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> invoicesForCustomer(String customerId) async {
    final rows = await db.query(
      'invoices',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'issueDate DESC',
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<Invoice?> getInvoice(String id) async {
    final rows = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first);
  }

  Future<InvoiceDetails?> getInvoiceDetails(String id) async {
    final invoice = await getInvoice(id);
    if (invoice == null) return null;
    final items = await db.query(
      'invoice_line_items',
      where: 'invoiceId = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final images = await db.query(
      'invoice_images',
      where: 'invoiceId = ?',
      whereArgs: [id],
      orderBy: 'sortOrder ASC',
    );
    return InvoiceDetails(
      invoice: invoice,
      items: items.map(InvoiceLineItem.fromMap).toList(),
      images: images.map(InvoiceImage.fromMap).toList(),
    );
  }

  (String, int) nextInvoiceNumber(Business business) {
    final year = Za.currentYear();
    final seq = business.nextInvoiceNumber;
    final number = '${business.invoicePrefix}-$year-${seq.toString().padLeft(4, '0')}';
    return (number, seq + 1);
  }

  Future<Invoice> saveInvoice({
    required Invoice invoice,
    required List<InvoiceLineItem> items,
    required bool bumpNumber,
  }) async {
    final totals = Money.totals(
      lineTotals: items.map((i) => Money.lineTotal(i.quantity, i.unitPrice)).toList(),
      taxable: items.map((i) => i.taxable).toList(),
      discountAmount: invoice.discountAmount,
      discountPercent: invoice.discountPercent,
      vatPercent: invoice.vatPercent,
    );
    final saved = invoice.copyWith(
      subtotal: totals.subtotal,
      vatAmount: totals.vat,
      total: totals.total,
      updatedAt: Za.nowMillis(),
    );
    await db.insert('invoices', saved.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete('invoice_line_items', where: 'invoiceId = ?', whereArgs: [saved.id]);
    for (final item in items) {
      await db.insert(
        'invoice_line_items',
        item.copyWith().toMap()..['invoiceId'] = saved.id,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (bumpNumber) {
      final biz = await getBusiness(saved.businessId);
      if (biz != null) {
        await saveBusiness(biz.copyWith(nextInvoiceNumber: biz.nextInvoiceNumber + 1));
      }
    }
    return saved;
  }

  Future<void> deleteInvoice(Invoice invoice) async {
    await db.delete('invoices', where: 'id = ?', whereArgs: [invoice.id]);
  }

  Future<void> setStatus(String invoiceId, InvoiceStatus status) async {
    await db.update(
      'invoices',
      {'status': status.wire, 'updatedAt': Za.nowMillis()},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> markOverdue() async {
    final now = Za.todayMillis();
    final rows = await db.query('invoices', where: "status = 'SENT'");
    for (final row in rows) {
      final inv = Invoice.fromMap(row);
      if (inv.dueDate < now) {
        await setStatus(inv.id, InvoiceStatus.overdue);
      }
    }
  }

  Future<String> saveSignature(Invoice invoice, Uint8List pngBytes) async {
    final dir = storage.folder(invoice.businessId, invoice.customerId, FolderType.images);
    final file = storage.uniqueFile(dir, '${invoice.number}_signature.png');
    await storage.copyBytes(pngBytes, file);
    final rel = storage.relativeToRoot(file);
    await db.update(
      'invoices',
      {'signaturePath': rel, 'updatedAt': Za.nowMillis()},
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
    await indexFile(invoice.businessId, invoice.customerId, FolderType.images, file, 'image/png');
    return rel;
  }

  Future<InvoiceImage> addInvoiceImage(Invoice invoice, Uint8List bytes, String displayName) async {
    final dir = storage.folder(invoice.businessId, invoice.customerId, FolderType.images);
    final dest = storage.uniqueFile(dir, displayName.isEmpty ? 'image.jpg' : displayName);
    await storage.copyBytes(bytes, dest);
    final rel = storage.relativeToRoot(dest);
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM invoice_images WHERE invoiceId = ?', [invoice.id]),
        ) ??
        0;
    final entity = InvoiceImage(
      id: Za.newId(),
      invoiceId: invoice.id,
      path: rel,
      sortOrder: count,
    );
    await db.insert('invoice_images', entity.toMap());
    await indexFile(invoice.businessId, invoice.customerId, FolderType.images, dest, guessMime(displayName));
    return entity;
  }

  Future<File?> generatePdf(String invoiceId) async {
    final details = await getInvoiceDetails(invoiceId);
    if (details == null) return null;
    final business = await getBusiness(details.invoice.businessId);
    final customer = await getCustomer(details.invoice.customerId);
    if (business == null || customer == null) return null;
    InvoiceTemplate? template;
    if (details.invoice.templateId != null) {
      template = await getTemplate(details.invoice.templateId!);
    }
    template ??= await defaultTemplate(business.id);
    final dir = storage.folder(business.id, customer.id, FolderType.invoices);
    final dest = File(p.join(dir.path, '${details.invoice.number}.pdf'));
    await pdf.generate(
      details: details,
      business: business,
      customer: customer,
      template: template,
      dest: dest,
    );
    final rel = storage.relativeToRoot(dest);
    await db.update(
      'invoices',
      {'pdfPath': rel, 'updatedAt': Za.nowMillis()},
      where: 'id = ?',
      whereArgs: [details.invoice.id],
    );
    await indexFile(business.id, customer.id, FolderType.invoices, dest, 'application/pdf');
    return dest;
  }

  Future<void> recordPayment({
    required Invoice invoice,
    required double amount,
    required String method,
    String? reference,
  }) async {
    final tx = Txn(
      id: Za.newId(),
      businessId: invoice.businessId,
      customerId: invoice.customerId,
      invoiceId: invoice.id,
      type: TransactionType.payment,
      amount: amount,
      currency: invoice.currency,
      occurredAt: Za.nowMillis(),
      method: method,
      reference: reference,
      notes: 'Payment for ${invoice.number}',
      createdAt: Za.nowMillis(),
    );
    await saveTransaction(tx);
    if (amount >= invoice.total) {
      await setStatus(invoice.id, InvoiceStatus.paid);
    }
  }

  Future<List<Txn>> transactions(String businessId) async {
    final rows = await db.query(
      'transactions',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'occurredAt DESC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  Future<List<Txn>> customerTransactions(String customerId) async {
    final rows = await db.query(
      'transactions',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'occurredAt DESC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  Future<void> saveTransaction(Txn entity) async {
    await db.insert('transactions', entity.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    if (entity.receiptPath != null && entity.receiptPath!.isNotEmpty && entity.customerId != null) {
      final file = storage.resolve(entity.receiptPath!);
      if (file.existsSync()) {
        await indexFile(
          entity.businessId,
          entity.customerId!,
          FolderType.receipts,
          file,
          guessMime(file.path),
        );
      }
    }
  }

  Future<List<Note>> notes(String customerId) async {
    final rows = await db.query(
      'notes',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getNote(String id) async {
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<void> saveNote(Note entity) async {
    final saved = Note(
      id: entity.id,
      businessId: entity.businessId,
      customerId: entity.customerId,
      title: entity.title,
      body: entity.body,
      createdAt: entity.createdAt,
      updatedAt: Za.nowMillis(),
    );
    await db.insert('notes', saved.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    final dir = storage.folder(entity.businessId, entity.customerId, FolderType.notes);
    final safe = entity.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final cut = safe.length > 40 ? 40 : safe.length;
    final file = File(p.join(dir.path, '${safe.substring(0, cut)}.txt'));
    await file.writeAsString('${entity.title}\n\n${entity.body}\n');
    await indexFile(entity.businessId, entity.customerId, FolderType.notes, file, 'text/plain');
  }

  Future<void> deleteNote(Note entity) async {
    await db.delete('notes', where: 'id = ?', whereArgs: [entity.id]);
  }

  Future<List<FolderFile>> files(String customerId, FolderType type) async {
    final rows = await db.query(
      'folder_files',
      where: 'customerId = ? AND folderType = ?',
      whereArgs: [customerId, type.wire],
      orderBy: 'createdAt DESC',
    );
    return rows.map(FolderFile.fromMap).toList();
  }

  Future<List<FolderFile>> allFiles(String customerId) async {
    final rows = await db.query(
      'folder_files',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(FolderFile.fromMap).toList();
  }

  Future<FolderFile> importFile({
    required String businessId,
    required String customerId,
    required FolderType type,
    required Uint8List bytes,
    required String displayName,
  }) async {
    final dir = storage.folder(businessId, customerId, type);
    final dest = storage.uniqueFile(dir, displayName.isEmpty ? 'file' : displayName);
    await storage.copyBytes(bytes, dest);
    return indexFile(businessId, customerId, type, dest, guessMime(displayName));
  }

  Future<void> deleteFolderFile(FolderFile entity) async {
    final file = storage.resolve(entity.relativePath);
    if (file.existsSync()) file.deleteSync();
    await db.delete('folder_files', where: 'id = ?', whereArgs: [entity.id]);
  }

  Future<List<InvoiceTemplate>> templates(String businessId) async {
    final rows = await db.query(
      'invoice_templates',
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(InvoiceTemplate.fromMap).toList();
  }

  Future<InvoiceTemplate?> getTemplate(String id) async {
    final rows = await db.query('invoice_templates', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InvoiceTemplate.fromMap(rows.first);
  }

  Future<InvoiceTemplate?> defaultTemplate(String businessId) async {
    final rows = await db.query(
      'invoice_templates',
      where: 'businessId = ? AND isDefault = 1',
      whereArgs: [businessId],
    );
    if (rows.isEmpty) {
      final all = await templates(businessId);
      return all.isEmpty ? null : all.first;
    }
    return InvoiceTemplate.fromMap(rows.first);
  }

  Future<void> saveTemplate(InvoiceTemplate entity) async {
    if (entity.isDefault) {
      await db.update(
        'invoice_templates',
        {'isDefault': 0},
        where: 'businessId = ?',
        whereArgs: [entity.businessId],
      );
    }
    await db.insert(
      'invoice_templates',
      entity.copyWith(updatedAt: Za.nowMillis()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> saveTemplateBytes(String businessId, Uint8List bytes, String name, {bool logo = false}) async {
    final dir = logo ? storage.logosDir(businessId) : storage.templatesDir(businessId);
    final dest = storage.uniqueFile(dir, name);
    await storage.copyBytes(bytes, dest);
    return storage.relativeToRoot(dest);
  }

  Future<File> exportBusinessWorkbook(String businessId, File dest, {bool csv = false}) async {
    final biz = await getBusiness(businessId);
    if (biz == null) throw StateError('Missing business');
    final customerList = await customers(businessId);
    final invoiceList = await invoices(businessId);
    const customerHeaders = [
      'Name',
      'Contact',
      'Email',
      'Phone',
      'Address',
      'City',
      'Province',
      'Postal',
      'VAT',
      'Notes',
    ];
    final customerRows = [
      for (final c in customerList)
        [
          c.name,
          c.contactName ?? '',
          c.email ?? '',
          c.phone ?? '',
          c.addressLine1 ?? '',
          c.city ?? '',
          c.province ?? '',
          c.postalCode ?? '',
          c.vatNumber ?? '',
          c.notes ?? '',
        ],
    ];
    final productList = await products(businessId);
    const productHeaders = ['Name', 'Description', 'Unit price', 'VAT'];
    final productRows = [
      for (final p in productList)
        [
          p.name,
          p.description ?? '',
          p.unitPrice.toString(),
          p.taxable ? 'Yes' : 'No',
        ],
    ];
    const invoiceHeaders = [
      'Number',
      'Customer',
      'Status',
      'Issue date',
      'Due date',
      'Currency',
      'Subtotal',
      'VAT',
      'Total',
      'Notes',
    ];
    final invoiceRows = [
      for (final inv in invoiceList)
        [
          inv.number,
          customerList.where((c) => c.id == inv.customerId).firstOrNull?.name ?? '',
          inv.status.wire,
          Za.date(inv.issueDate),
          Za.date(inv.dueDate),
          inv.currency,
          inv.subtotal.toString(),
          inv.vatAmount.toString(),
          inv.total.toString(),
          inv.notes ?? '',
        ],
    ];
    if (csv) {
      return excel.writeCsv(dest, invoiceHeaders, invoiceRows);
    }
    return excel.writeWorkbook(dest, {
      'Invoices': (invoiceHeaders, invoiceRows),
      'Customers': (customerHeaders, customerRows),
      'Products': (productHeaders, productRows),
      'Business': (
        ['Field', 'Value'],
        [
          ['Name', biz.name],
          ['VAT', biz.vatNumber ?? ''],
          ['Email', biz.email],
          ['Phone', biz.phone],
          ['Currency', biz.defaultCurrency],
        ],
      ),
    });
  }

  Future<int> importCustomers(String businessId, Uint8List bytes, String displayName, Map<String, int> mapping) async {
    final parsed = excel.readAll(bytes, displayName);
    var count = 0;
    final now = Za.nowMillis();
    for (final row in parsed.$3) {
      final name = excel.cell(row, mapping, 'name');
      if (name.isEmpty) continue;
      await saveCustomer(
        Customer(
          id: Za.newId(),
          businessId: businessId,
          name: name,
          contactName: _blankToNull(excel.cell(row, mapping, 'contactName')),
          email: _blankToNull(excel.cell(row, mapping, 'email')),
          phone: _blankToNull(excel.cell(row, mapping, 'phone')),
          addressLine1: _blankToNull(excel.cell(row, mapping, 'addressLine1')),
          city: _blankToNull(excel.cell(row, mapping, 'city')),
          province: _blankToNull(excel.cell(row, mapping, 'province')),
          postalCode: _blankToNull(excel.cell(row, mapping, 'postalCode')),
          vatNumber: _blankToNull(excel.cell(row, mapping, 'vatNumber')),
          notes: _blankToNull(excel.cell(row, mapping, 'notes')),
          createdAt: now,
          updatedAt: now,
        ),
      );
      count++;
    }
    return count;
  }

  Future<int> importInvoiceLines(String businessId, Uint8List bytes, String displayName, Map<String, int> mapping) async {
    final customerList = await customers(businessId);
    final byName = {for (final c in customerList) c.name.toLowerCase(): c};
    final parsed = excel.readAll(bytes, displayName);
    final grouped = <String, List<List<String>>>{};
    for (final row in parsed.$3) {
      final key = excel.cell(row, mapping, 'number').isNotEmpty
          ? excel.cell(row, mapping, 'number')
          : '${excel.cell(row, mapping, 'customerName')}|${excel.cell(row, mapping, 'issueDate')}';
      grouped.putIfAbsent(key, () => []).add(row);
    }
    var count = 0;
    final now = Za.nowMillis();
    for (final group in grouped.values) {
      final first = group.first;
      final customerName = excel.cell(first, mapping, 'customerName');
      final customer = byName[customerName.toLowerCase()];
      if (customer == null) continue;
      final id = Za.newId();
      final items = [
        for (var idx = 0; idx < group.length; idx++)
          InvoiceLineItem(
            id: Za.newId(),
            invoiceId: id,
            position: idx,
            description: excel.cell(group[idx], mapping, 'description').isEmpty
                ? 'Imported line'
                : excel.cell(group[idx], mapping, 'description'),
            quantity: () {
              final q = excel.parseAmount(excel.cell(group[idx], mapping, 'quantity'));
              return q > 0 ? q : 1.0;
            }(),
            unitPrice: () {
              final unit = excel.parseAmount(excel.cell(group[idx], mapping, 'unitPrice'));
              return unit > 0 ? unit : excel.parseAmount(excel.cell(group[idx], mapping, 'total'));
            }(),
          ),
      ];
      final totals = Money.totals(
        lineTotals: items.map((i) => Money.lineTotal(i.quantity, i.unitPrice)).toList(),
      );
      final statusRaw = excel.cell(first, mapping, 'status');
      await saveInvoice(
        invoice: Invoice(
          id: id,
          businessId: businessId,
          customerId: customer.id,
          number: excel.cell(first, mapping, 'number').isEmpty ? 'IMP-${count + 1}' : excel.cell(first, mapping, 'number'),
          status: invoiceStatusFrom(statusRaw.isEmpty ? 'DRAFT' : statusRaw),
          issueDate: now,
          dueDate: Za.plusDays(now, 30),
          notes: _blankToNull(excel.cell(first, mapping, 'notes')),
          terms: 'Payment due within 30 days.',
          subtotal: totals.subtotal,
          vatAmount: totals.vat,
          total: totals.total,
          createdAt: now,
          updatedAt: now,
        ),
        items: items,
        bumpNumber: false,
      );
      count++;
    }
    return count;
  }

  Future<File> writeCaptureSheet({
    required String businessId,
    required String customerId,
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
    required bool csv,
  }) async {
    final dir = storage.folder(businessId, customerId, FolderType.excel);
    final dest = storage.uniqueFile(dir, fileName);
    final file = csv
        ? excel.writeCsv(dest, headers, rows)
        : excel.writeWorkbook(dest, {'Capture': (headers, rows)});
    await indexFile(
      businessId,
      customerId,
      FolderType.excel,
      file,
      csv
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    return file;
  }

  Future<String> attachReceipt({
    required String businessId,
    required String customerId,
    required Uint8List bytes,
    required String displayName,
  }) async {
    final dir = storage.folder(businessId, customerId, FolderType.receipts);
    final dest = storage.uniqueFile(dir, displayName.isEmpty ? 'receipt.jpg' : displayName);
    await storage.copyBytes(bytes, dest);
    await indexFile(businessId, customerId, FolderType.receipts, dest, guessMime(displayName));
    return storage.relativeToRoot(dest);
  }

  Future<FolderFile> indexFile(
    String businessId,
    String customerId,
    FolderType type,
    File file,
    String mime,
  ) async {
    final entity = FolderFile(
      id: Za.newId(),
      businessId: businessId,
      customerId: customerId,
      folderType: type,
      displayName: p.basename(file.path),
      mimeType: mime,
      relativePath: storage.relativeToRoot(file),
      sizeBytes: file.lengthSync(),
      createdAt: Za.nowMillis(),
    );
    await db.insert('folder_files', entity.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return entity;
  }

  String? _blankToNull(String value) => value.trim().isEmpty ? null : value.trim();
}
