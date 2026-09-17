import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeinvoice/domain/models.dart';
import 'package:safeinvoice/ui/theme.dart';
import 'package:safeinvoice/ui/widgets.dart';

void main() {
  testWidgets('status chips and palettes render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: safeInvoiceTheme(
          mode: ThemeModeOption.light,
          accent: AccentPalette.forest,
          platformBrightness: Brightness.light,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              StatusChip(InvoiceStatus.draft),
              StatusChip(InvoiceStatus.paid),
              StatusChip(InvoiceStatus.overdue),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(palettes.length, 8);
  });
}
