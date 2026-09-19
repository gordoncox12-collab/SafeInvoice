import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/native_share.dart';
import '../data/repository.dart';
import '../data/share_payload.dart';
import '../data/whatsapp.dart';
import '../domain/models.dart';

class AppController extends ChangeNotifier {
  AppController(this.repo);

  final InvoiceRepository repo;

  bool ready = false;
  AppSettings settings = const AppSettings();
  List<Business> businesses = [];
  List<Customer> customers = [];
  List<Product> products = [];
  List<Invoice> invoices = [];
  List<Txn> transactions = [];
  List<InvoiceTemplate> templates = [];

  Business? get business {
    final id = settings.activeBusinessId;
    if (id == null) return businesses.firstOrNull;
    return businesses.where((b) => b.id == id).firstOrNull ?? businesses.firstOrNull;
  }

  Future<void> bootstrap() async {
    await repo.markOverdue();
    settings = await repo.getSettings();
    await refresh();
    ready = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    businesses = await repo.businesses();
    final biz = business;
    if (biz == null) {
      customers = [];
      products = [];
      invoices = [];
      transactions = [];
      templates = [];
    } else {
      customers = await repo.customers(biz.id);
      products = await repo.products(biz.id);
      invoices = await repo.invoices(biz.id);
      transactions = await repo.transactions(biz.id);
      templates = await repo.templates(biz.id);
      if (settings.activeBusinessId != biz.id) {
        settings = settings.copyWith(activeBusinessId: biz.id);
        await repo.saveSettings(settings);
      }
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeModeOption mode) async {
    settings = settings.copyWith(themeMode: mode);
    await repo.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setAccent(AccentPalette accent) async {
    settings = settings.copyWith(accentPalette: accent);
    await repo.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setActiveBusiness(String id) async {
    settings = settings.copyWith(activeBusinessId: id);
    await repo.saveSettings(settings);
    await refresh();
  }

  Future<void> saveBusiness(Business entity) async {
    await repo.saveBusiness(entity);
    await refresh();
  }

  Future<void> deleteBusiness(Business entity) async {
    await repo.deleteBusiness(entity);
    if (settings.activeBusinessId == entity.id) {
      settings = settings.copyWith(clearBusiness: true);
      await repo.saveSettings(settings);
    }
    await refresh();
  }

  Future<void> saveCustomer(Customer entity) async {
    await repo.saveCustomer(entity);
    await refresh();
  }

  Future<void> deleteCustomer(Customer entity) async {
    await repo.deleteCustomer(entity);
    await refresh();
  }

  Future<void> saveProduct(Product entity) async {
    await repo.saveProduct(entity);
    await refresh();
  }

  Future<void> deleteProduct(Product entity) async {
    await repo.deleteProduct(entity);
    await refresh();
  }

  Future<Invoice> saveInvoice({
    required Invoice invoice,
    required List<InvoiceLineItem> items,
    required bool bumpNumber,
  }) async {
    try {
      final saved = await repo.saveInvoice(invoice: invoice, items: items, bumpNumber: bumpNumber);
      await refresh();
      return saved;
    } catch (e, st) {
      debugPrint('AppController.saveInvoice failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteInvoice(Invoice invoice) async {
    await repo.deleteInvoice(invoice);
    await refresh();
  }

  Future<void> setInvoiceStatus(String id, InvoiceStatus status) async {
    await repo.setStatus(id, status);
    await refresh();
  }

  Future<String> savePodSignature(Invoice invoice, Uint8List png) async {
    final path = await repo.savePodSignature(invoice, png);
    try {
      await repo.generatePdf(invoice.id);
    } catch (e, st) {
      debugPrint('PDF regenerate after POD signature failed: $e\n$st');
    }
    await refresh();
    return path;
  }

  Future<void> setPaymentOption(Invoice invoice, PaymentOption? method, {String? note}) async {
    await repo.setPaymentOption(invoice.id, method, note: note);
    await refresh();
  }

  Future<File?> archiveInvoicePdf(Invoice invoice) async {
    final file = await repo.archiveInvoicePdf(invoice.id);
    await refresh();
    return file;
  }

  Future<ShareOutcome> openWhatsAppChat(Customer customer) async {
    final raw = customerWhatsAppNumber(customer.whatsapp, customer.phone);
    if (raw == null) {
      return ShareOutcome.fail('Add a WhatsApp or phone number on the customer profile first.');
    }
    try {
      whatsappChatUrl(raw);
    } on FormatException catch (e) {
      return ShareOutcome.fail(e.message);
    }
    return NativeShare.openWhatsAppChat(number: raw);
  }

  Future<String> saveSignature(Invoice invoice, Uint8List png) async {
    final path = await repo.saveSignature(invoice, png);
    try {
      await repo.generatePdf(invoice.id);
    } catch (e, st) {
      debugPrint('PDF regenerate after signature failed: $e\n$st');
    }
    await refresh();
    return path;
  }

  Future<void> addInvoiceImage(Invoice invoice, Uint8List bytes, String name) async {
    await repo.addInvoiceImage(invoice, bytes, name);
    await refresh();
  }

  Future<File?> generatePdf(String invoiceId) async {
    final file = await repo.generatePdf(invoiceId);
    await refresh();
    return file;
  }

  Future<void> recordPayment({
    required Invoice invoice,
    required double amount,
    required String method,
    String? reference,
  }) async {
    await repo.recordPayment(invoice: invoice, amount: amount, method: method, reference: reference);
    await refresh();
  }

  Future<void> saveTransaction(Txn tx) async {
    await repo.saveTransaction(tx);
    await refresh();
  }

  Future<void> saveNote(Note note) async {
    await repo.saveNote(note);
    await refresh();
  }

  Future<void> deleteNote(Note note) async {
    await repo.deleteNote(note);
    await refresh();
  }

  Future<void> saveTemplate(InvoiceTemplate template) async {
    await repo.saveTemplate(template);
    await refresh();
  }

  Future<void> saveBusinessLogo(Business business, Uint8List bytes, String displayName) async {
    await repo.saveBusinessLogo(business, bytes, displayName);
    await refresh();
  }

  Future<void> clearBusinessLogo(Business business) async {
    await repo.clearBusinessLogo(business);
    await refresh();
  }

  Future<ShareOutcome> shareInvoice({
    required Invoice invoice,
    required String target,
    Directory? cacheDir,
  }) async {
    try {
      final pdf = await generatePdf(invoice.id);
      if (pdf == null || !pdf.existsSync()) {
        return ShareOutcome.fail('Could not build the invoice PDF.');
      }
      final cache = cacheDir ?? await getTemporaryDirectory();
      final staged = await stageInvoicePdfForShare(
        source: pdf,
        cacheDir: cache,
        number: invoice.number,
      );
      final customer = customers.where((c) => c.id == invoice.customerId).firstOrNull;
      return await NativeShare.shareFile(
        path: staged.path,
        mime: invoicePdfMime,
        title: 'Invoice ${invoice.number}',
        body: 'Please find invoice ${invoice.number} from ${business?.name ?? 'SafeInvoice'}.',
        email: customer?.email,
        target: target,
        displayName: invoicePdfFileName(invoice.number),
      );
    } catch (e, st) {
      debugPrint('shareInvoice failed: $e\n$st');
      return ShareOutcome.fail('Could not share the invoice PDF. Try generating it again.');
    }
  }

  Future<ShareOutcome> shareFile({
    required File file,
    required String title,
    required String body,
    String? email,
    String target = 'chooser',
  }) {
    return NativeShare.shareFile(
      path: file.path,
      mime: _mime(file.path),
      title: title,
      body: body,
      email: email,
      target: target,
      displayName: file.uri.pathSegments.isEmpty ? null : file.uri.pathSegments.last,
    );
  }

  String _mime(String path) {
    final n = path.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (n.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }
}
