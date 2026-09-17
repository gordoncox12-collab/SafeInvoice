import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open(String dbPath) async {
    final database = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE businesses (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  tradingName TEXT,
  registrationNumber TEXT,
  vatNumber TEXT,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  addressLine1 TEXT NOT NULL,
  addressLine2 TEXT,
  city TEXT NOT NULL,
  province TEXT NOT NULL,
  postalCode TEXT NOT NULL,
  country TEXT NOT NULL,
  bankName TEXT,
  bankAccountName TEXT,
  bankAccountNumber TEXT,
  bankBranchCode TEXT,
  logoPath TEXT,
  defaultCurrency TEXT NOT NULL,
  defaultVatPercent REAL NOT NULL,
  invoicePrefix TEXT NOT NULL,
  nextInvoiceNumber INTEGER NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  isActive INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  businessId TEXT NOT NULL,
  name TEXT NOT NULL,
  contactName TEXT,
  email TEXT,
  phone TEXT,
  addressLine1 TEXT,
  city TEXT,
  province TEXT,
  postalCode TEXT,
  vatNumber TEXT,
  notes TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE
)''');
        await db.execute('CREATE INDEX idx_customers_biz ON customers(businessId)');
        await db.execute('''
CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  businessId TEXT NOT NULL,
  customerId TEXT NOT NULL,
  number TEXT NOT NULL,
  status TEXT NOT NULL,
  issueDate INTEGER NOT NULL,
  dueDate INTEGER NOT NULL,
  currency TEXT NOT NULL,
  vatPercent REAL NOT NULL,
  discountAmount REAL NOT NULL,
  discountPercent REAL NOT NULL,
  notes TEXT,
  terms TEXT,
  signaturePath TEXT,
  pdfPath TEXT,
  templateId TEXT,
  subtotal REAL NOT NULL,
  vatAmount REAL NOT NULL,
  total REAL NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE CASCADE
)''');
        await db.execute('CREATE INDEX idx_invoices_biz ON invoices(businessId)');
        await db.execute('CREATE INDEX idx_invoices_cust ON invoices(customerId)');
        await db.execute('''
CREATE TABLE invoice_line_items (
  id TEXT PRIMARY KEY,
  invoiceId TEXT NOT NULL,
  position INTEGER NOT NULL,
  description TEXT NOT NULL,
  quantity REAL NOT NULL,
  unitPrice REAL NOT NULL,
  taxable INTEGER NOT NULL,
  FOREIGN KEY (invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
)''');
        await db.execute('CREATE INDEX idx_items_inv ON invoice_line_items(invoiceId)');
        await db.execute('''
CREATE TABLE invoice_images (
  id TEXT PRIMARY KEY,
  invoiceId TEXT NOT NULL,
  path TEXT NOT NULL,
  sortOrder INTEGER NOT NULL,
  FOREIGN KEY (invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  businessId TEXT NOT NULL,
  customerId TEXT,
  invoiceId TEXT,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  occurredAt INTEGER NOT NULL,
  method TEXT,
  reference TEXT,
  notes TEXT,
  receiptPath TEXT,
  createdAt INTEGER NOT NULL,
  FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  businessId TEXT NOT NULL,
  customerId TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE folder_files (
  id TEXT PRIMARY KEY,
  businessId TEXT NOT NULL,
  customerId TEXT NOT NULL,
  folderType TEXT NOT NULL,
  displayName TEXT NOT NULL,
  mimeType TEXT NOT NULL,
  relativePath TEXT NOT NULL,
  sizeBytes INTEGER NOT NULL,
  createdAt INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE invoice_templates (
  id TEXT PRIMARY KEY,
  businessId TEXT NOT NULL,
  name TEXT NOT NULL,
  isDefault INTEGER NOT NULL,
  primaryColor INTEGER NOT NULL,
  accentColor INTEGER NOT NULL,
  logoPath TEXT,
  layout TEXT NOT NULL,
  showBankDetails INTEGER NOT NULL,
  footerText TEXT,
  headerImagePath TEXT,
  extraImagePath TEXT,
  logoAlignment TEXT NOT NULL,
  marginPreset TEXT NOT NULL,
  picturePlacement TEXT NOT NULL,
  showSignatureLine INTEGER NOT NULL,
  headerBanner INTEGER NOT NULL,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  FOREIGN KEY (businessId) REFERENCES businesses(id) ON DELETE CASCADE
)''');
        await db.execute('''
CREATE TABLE app_settings (
  id INTEGER PRIMARY KEY,
  themeMode TEXT NOT NULL,
  accentPalette TEXT NOT NULL,
  activeBusinessId TEXT
)''');
        await db.insert('app_settings', {
          'id': 1,
          'themeMode': 'SYSTEM',
          'accentPalette': 'FOREST',
          'activeBusinessId': null,
        });
      },
    );
    return AppDatabase._(database);
  }

  static String defaultPath(String supportDir) => p.join(supportDir, 'safeinvoice.db');
}
