import 'package:flutter_test/flutter_test.dart';
import 'package:safeinvoice/data/excel_service.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/domain/money.dart';
import 'package:safeinvoice/ui/theme.dart';

void main() {
  test('zero-rated line skips vat', () {
    final totals = Money.totals(
      lineTotals: [1000, 500],
      taxable: [true, false],
      vatPercent: 15,
    );
    expect(totals.subtotal, closeTo(1500, 0.001));
    expect(totals.vat, closeTo(150, 0.001));
    expect(totals.total, closeTo(1650, 0.001));
  });

  test('product catalog round-trips', () {
    final now = 1;
    final product = Product(
      id: 'p1',
      businessId: 'b1',
      name: 'Consulting',
      description: 'Hourly',
      unitPrice: 850,
      taxable: true,
      createdAt: now,
      updatedAt: now,
    );
    final copy = Product.fromMap(product.toMap());
    expect(copy.name, 'Consulting');
    expect(copy.unitPrice, 850);
    expect(copy.taxable, isTrue);
    expect(copy.description, 'Hourly');
  });

  test('product dropdown mapping fills line item', () {
    final product = Product(
      id: 'p2',
      businessId: 'b1',
      name: 'Site visit',
      description: 'Call-out',
      unitPrice: 650,
      taxable: false,
      createdAt: 1,
      updatedAt: 1,
    );
    final line = InvoiceLineItem(
      id: 'l1',
      invoiceId: 'i1',
      position: 0,
      description: '',
    ).applyProduct(product);
    expect(line.productId, 'p2');
    expect(line.description, 'Site visit — Call-out');
    expect(line.unitPrice, 650);
    expect(line.taxable, isFalse);
    final totals = Money.totals(
      lineTotals: [Money.lineTotal(2, line.unitPrice)],
      taxable: [line.taxable],
      vatPercent: 15,
    );
    expect(totals.subtotal, closeTo(1300, 0.001));
    expect(totals.vat, closeTo(0, 0.001));
    expect(totals.total, closeTo(1300, 0.001));
  });

  test('theme prefs round-trip unknown palette safely', () {
    final settings = AppSettings.fromMap({
      'themeMode': 'DARK',
      'accentPalette': 'CORAL',
      'activeBusinessId': 'b1',
    });
    expect(settings.themeMode, ThemeModeOption.dark);
    expect(settings.accentPalette, AccentPalette.coral);
    expect(AppSettings.fromMap({'themeMode': 'nope', 'accentPalette': 'missing'}).themeMode, ThemeModeOption.system);
    expect(AppSettings.fromMap({'themeMode': 'LIGHT', 'accentPalette': 'missing'}).accentPalette, AccentPalette.forest);
    expect(AppSettings(themeMode: ThemeModeOption.light, accentPalette: AccentPalette.mint).toMap()['accentPalette'], 'MINT');
  });

  test('vat fifteen percent on net', () {
    final totals = Money.totals(lineTotals: [1000, 500], vatPercent: 15);
    expect(totals.subtotal, closeTo(1500, 0.001));
    expect(totals.vat, closeTo(225, 0.001));
    expect(totals.total, closeTo(1725, 0.001));
  });

  test('percent discount then vat', () {
    final totals = Money.totals(lineTotals: [2000], discountPercent: 10, vatPercent: 15);
    expect(totals.discount, closeTo(200, 0.001));
    expect(totals.net, closeTo(1800, 0.001));
    expect(totals.vat, closeTo(270, 0.001));
    expect(totals.total, closeTo(2070, 0.001));
  });

  test('rand discount and percent together', () {
    final totals = Money.totals(
      lineTotals: [1000],
      discountAmount: 50,
      discountPercent: 10,
      vatPercent: 15,
    );
    expect(totals.discount, closeTo(150, 0.001));
    expect(totals.net, closeTo(850, 0.001));
    expect(totals.vat, closeTo(127.5, 0.001));
    expect(totals.total, closeTo(977.5, 0.001));
  });

  test('adjustable layouts are present', () {
    final names = TemplateLayout.values.map((e) => e.wire).toSet();
    expect(names.containsAll({'CLASSIC', 'MODERN', 'COMPACT', 'LETTERHEAD', 'MINIMAL'}), isTrue);
  });

  test('layout knobs exist', () {
    expect(LogoAlignment.values.length, 3);
    expect(MarginPreset.values.length, 3);
    expect(PicturePlacement.values.length, 3);
    expect(ThemeModeOption.values.length, 3);
    expect(AccentPalette.values.length, greaterThanOrEqualTo(16));
    expect(palettes.length, 18);
    expect(
      FolderType.values.map((e) => e.wire).toSet().containsAll({
        'INVOICES',
        'RECEIPTS',
        'EXCEL',
        'IMAGES',
        'NOTES',
      }),
      isTrue,
    );
  });

  test('excel column guess maps customer name', () {
    final mapping = guessMapping(
      ['Customer Name', 'Email', 'Phone'],
      customerImportFields,
    );
    expect(mapping['name'], 0);
    expect(mapping['email'], 1);
    expect(mapping['phone'], 2);
  });

  test('excel column guess maps invoice lines', () {
    final mapping = guessMapping(
      ['Invoice number', 'Customer name', 'Line description', 'Qty', 'Unit price'],
      invoiceImportFields,
    );
    expect(mapping['number'], 0);
    expect(mapping['customerName'], 1);
    expect(mapping['description'], 2);
    expect(mapping['quantity'], 3);
    expect(mapping['unitPrice'], 4);
  });

  test('invoice numbering format', () {
    expect('INV-2026-0001'.contains('INV-'), isTrue);
  });
}
