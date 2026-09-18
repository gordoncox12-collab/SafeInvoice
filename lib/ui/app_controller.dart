import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/native_share.dart';
import '../data/repository.dart';
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
    final saved = await repo.saveInvoice(invoice: invoice, items: items, bumpNumber: bumpNumber);
    await refresh();
    return saved;
  }

  Future<void> deleteInvoice(Invoice invoice) async {
    await repo.deleteInvoice(invoice);
    await refresh();
  }

  Future<void> setInvoiceStatus(String id, InvoiceStatus status) async {
    await repo.setStatus(id, status);
    await refresh();
  }

  Future<String> saveSignature(Invoice invoice, Uint8List png) async {
    final path = await repo.saveSignature(invoice, png);
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

  Future<void> shareFile({
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
