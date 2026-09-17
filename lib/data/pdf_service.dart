import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';
import '../domain/money.dart';
import 'local_storage.dart';

class InvoicePdfService {
  InvoicePdfService(this.storage);

  final LocalStorage storage;

  Future<File> generate({
    required InvoiceDetails details,
    required Business business,
    required Customer customer,
    required InvoiceTemplate? template,
    required File dest,
  }) async {
    await dest.parent.create(recursive: true);
    final primary = _pdfColor(template?.primaryColor ?? 0xFF0F766E);
    final accent = _pdfColor(template?.accentColor ?? 0xFFD4A017);
    final layout = template?.layout ?? TemplateLayout.classic;
    final compact =
        layout == TemplateLayout.compact || layout == TemplateLayout.minimal;
    final margin = switch (template?.marginPreset ?? MarginPreset.normal) {
      MarginPreset.tight => 24.0,
      MarginPreset.normal => 36.0,
      MarginPreset.wide => 52.0,
    };
    final logoAlign = template?.logoAlignment ?? LogoAlignment.left;
    final picturePlacement = template?.picturePlacement ?? PicturePlacement.afterItems;
    final headerBanner = template?.headerBanner ?? true;
    final showSignatureLine = template?.showSignatureLine ?? true;

    pw.ImageProvider? logo;
    pw.ImageProvider? headerImg;
    pw.ImageProvider? extraImg;
    pw.ImageProvider? signature;
    final attached = <pw.ImageProvider>[];

    Future<pw.ImageProvider?> load(String? path) async {
      if (path == null || path.isEmpty) return null;
      final file = storage.resolve(path);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    }

    logo = await load(template?.logoPath ?? business.logoPath);
    headerImg = await load(template?.headerImagePath);
    extraImg = await load(template?.extraImagePath);
    signature = await load(details.invoice.signaturePath);
    for (final img in details.images) {
      final loaded = await load(img.path);
      if (loaded != null) attached.add(loaded);
    }

    final invoice = details.invoice;
    final totals = Money.totals(
      lineTotals: details.items.map((i) => Money.lineTotal(i.quantity, i.unitPrice)).toList(),
      discountAmount: invoice.discountAmount,
      discountPercent: invoice.discountPercent,
      vatPercent: invoice.vatPercent,
    );
    final titleSize = switch (layout) {
      TemplateLayout.compact => 16.0,
      TemplateLayout.minimal => 18.0,
      TemplateLayout.letterhead => 20.0,
      _ => 22.0,
    };

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(margin, layout == TemplateLayout.letterhead ? 8 : margin, margin, 40),
        header: (context) {
          if (layout == TemplateLayout.letterhead) {
            return pw.Container(
              color: primary,
              padding: const pw.EdgeInsets.fromLTRB(16, 16, 16, 18),
              margin: pw.EdgeInsets.only(bottom: 16, left: -margin, right: -margin, top: -8),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        business.name,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: titleSize,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'TAX INVOICE  ${invoice.number}',
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
                          ),
                          pw.Text(
                            'Status ${invoice.status.wire}',
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Container(height: 4, color: accent, margin: const pw.EdgeInsets.only(top: 10)),
                ],
              ),
            );
          }
          if (headerBanner && layout != TemplateLayout.minimal) {
            return pw.Container(
              margin: pw.EdgeInsets.only(left: -margin, right: -margin, top: -margin + 8, bottom: 10),
              child: pw.Column(
                children: [
                  pw.Container(height: layout == TemplateLayout.modern ? 14 : 8, color: primary),
                  pw.Container(height: 4, color: accent),
                ],
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (context) {
          final footer = template?.footerText?.trim().isNotEmpty == true
              ? template!.footerText!
              : 'Generated offline by SafeInvoice  ·  ${business.name}';
          return pw.Column(
            children: [
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  footer.length > 90 ? footer.substring(0, 90) : footer,
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
              ),
              if (layout != TemplateLayout.minimal)
                pw.Container(
                  height: 8,
                  color: primary,
                  margin: pw.EdgeInsets.only(left: -margin, right: -margin, top: 8),
                ),
            ],
          );
        },
        build: (context) {
          final widgets = <pw.Widget>[];

          if (picturePlacement == PicturePlacement.header && headerImg != null) {
            widgets.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Image(headerImg, height: 52),
              ),
            );
          } else if (layout == TemplateLayout.modern && headerImg != null) {
            widgets.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Image(headerImg, height: 52),
              ),
            );
          }

          if (logo != null) {
            final logoWidget = pw.Image(logo, height: compact ? 36 : 48);
            widgets.add(
              pw.Align(
                alignment: switch (logoAlign) {
                  LogoAlignment.left => pw.Alignment.centerLeft,
                  LogoAlignment.center => pw.Alignment.center,
                  LogoAlignment.right => pw.Alignment.centerRight,
                },
                child: logoWidget,
              ),
            );
            widgets.add(pw.SizedBox(height: 8));
          }

          if (layout != TemplateLayout.letterhead) {
            final label = layout == TemplateLayout.minimal ? 'Invoice' : 'TAX INVOICE';
            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    business.name,
                    style: pw.TextStyle(
                      color: primary,
                      fontSize: titleSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        label,
                        style: pw.TextStyle(
                          color: primary,
                          fontSize: compact ? 14 : 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(invoice.number),
                      pw.Text(
                        'Status: ${invoice.status.wire}',
                        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          final bizLines = <String>[
            if (business.tradingName != null &&
                business.tradingName!.isNotEmpty &&
                business.tradingName != business.name)
              't/a ${business.tradingName}',
            if (business.addressLine1.isNotEmpty) business.addressLine1,
            [
              business.addressLine2,
              [business.city, business.province, business.postalCode]
                  .where((s) => s.isNotEmpty)
                  .join(' '),
            ].where((s) => s != null && s.toString().trim().isNotEmpty).join(' '),
            if (business.country.isNotEmpty) business.country,
            [
              if (business.phone.isNotEmpty) 'Tel ${business.phone}',
              if (business.email.isNotEmpty) business.email,
            ].join('  ·  '),
            if (business.vatNumber != null) 'VAT ${business.vatNumber}',
            if (business.registrationNumber != null) 'Reg ${business.registrationNumber}',
          ].where((s) => s.trim().isNotEmpty).toList();

          for (final line in bizLines) {
            widgets.add(
              pw.Text(line, style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
            );
          }
          widgets.add(pw.SizedBox(height: 10));

          if (layout != TemplateLayout.minimal) {
            widgets.add(
              pw.Container(
                color: primary,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(
                  'Bill to',
                  style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                ),
              ),
            );
          } else {
            widgets.add(
              pw.Text('Bill to', style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)),
            );
          }
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(
            pw.Text(customer.name, style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)),
          );
          for (final line in [
            if (customer.contactName != null) 'Attn: ${customer.contactName}',
            customer.addressLine1,
            [customer.city, customer.province, customer.postalCode]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(', '),
            customer.email,
            customer.phone,
            if (customer.vatNumber != null) 'VAT ${customer.vatNumber}',
          ].whereType<String>().where((s) => s.trim().isNotEmpty)) {
            widgets.add(pw.Text(line, style: const pw.TextStyle(fontSize: 10)));
          }

          widgets.add(pw.SizedBox(height: 10));
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Issue date  ${Za.date(invoice.issueDate)}'),
                pw.Text('Due date  ${Za.date(invoice.dueDate)}'),
                pw.Text(invoice.currency, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary)),
              ],
            ),
          );
          widgets.add(pw.SizedBox(height: 10));

          widgets.add(
            pw.TableHelper.fromTextArray(
              headerDecoration: pw.BoxDecoration(color: primary),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: pw.TextStyle(fontSize: compact ? 8.5 : 9.5),
              headerAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: const ['Description', 'Qty', 'Unit', 'Amount'],
              data: [
                for (final item in [...details.items]..sort((a, b) => a.position.compareTo(b.position)))
                  [
                    item.description,
                    trimNum(item.quantity),
                    Za.money(item.unitPrice, invoice.currency),
                    Za.money(Money.lineTotal(item.quantity, item.unitPrice), invoice.currency),
                  ],
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 12));
          widgets.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal', Za.money(totals.subtotal, invoice.currency)),
                    if (totals.discount > 0)
                      _totalRow('Discount', '- ${Za.money(totals.discount, invoice.currency)}'),
                    _totalRow('VAT ${trimNum(invoice.vatPercent)}%', Za.money(totals.vat, invoice.currency)),
                    pw.Container(
                      color: primary,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            Za.money(totals.total, invoice.currency),
                            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          void addPicture(pw.ImageProvider img, String label) {
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(pw.Text(label, style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(pw.Image(img, height: 120, fit: pw.BoxFit.contain));
          }

          if (picturePlacement == PicturePlacement.afterItems) {
            if (extraImg != null) addPicture(extraImg, 'Template image');
            for (final img in attached) {
              addPicture(img, 'Attached image');
            }
          }

          if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) {
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Text('Notes', style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Text(invoice.notes!));
          }
          if (invoice.terms != null && invoice.terms!.trim().isNotEmpty) {
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(pw.Text('Terms', style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Text(invoice.terms!));
          }

          if (template?.showBankDetails ?? true) {
            final bank = [
              business.bankName,
              if (business.bankAccountName != null) 'Account name: ${business.bankAccountName}',
              if (business.bankAccountNumber != null) 'Account no: ${business.bankAccountNumber}',
              if (business.bankBranchCode != null) 'Branch: ${business.bankBranchCode}',
            ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
            if (bank.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Text('Bank details', style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)),
              );
              for (final line in bank) {
                widgets.add(pw.Text(line));
              }
            }
          }

          widgets.add(pw.SizedBox(height: 14));
          widgets.add(
            pw.Text('Authorised signature', style: pw.TextStyle(color: primary, fontWeight: pw.FontWeight.bold)),
          );
          if (signature != null) {
            widgets.add(pw.Image(signature, width: 164, height: 54, fit: pw.BoxFit.contain));
          } else if (showSignatureLine) {
            widgets.add(pw.SizedBox(height: 28));
            widgets.add(pw.Container(width: 160, height: 1, color: PdfColors.grey600));
          }

          if (picturePlacement != PicturePlacement.afterItems) {
            if (extraImg != null && picturePlacement == PicturePlacement.footer) {
              addPicture(extraImg, 'Template image');
            }
            for (final img in attached) {
              addPicture(img, 'Attached image');
            }
          }

          return widgets;
        },
      ),
    );

    await dest.writeAsBytes(await doc.save(), flush: true);
    return dest;
  }

  pw.Widget _totalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(value)],
      ),
    );
  }

  PdfColor _pdfColor(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    return PdfColor(r, g, b);
  }
}
