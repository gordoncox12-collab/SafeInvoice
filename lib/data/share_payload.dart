import 'dart:io';

import 'package:path/path.dart' as p;

const invoicePdfMime = 'application/pdf';

class ShareOutcome {
  const ShareOutcome._({required this.ok, this.message});

  final bool ok;
  final String? message;

  factory ShareOutcome.success() => const ShareOutcome._(ok: true);

  factory ShareOutcome.fail(String message) => ShareOutcome._(ok: false, message: message);
}

String invoicePdfFileName(String number) {
  final safe = number.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final n = safe.isEmpty ? 'invoice' : safe;
  return 'Invoice-$n.pdf';
}

/// Copy the invoice PDF into a share cache with a WhatsApp/Email-friendly name.
Future<File> stageInvoicePdfForShare({
  required File source,
  required Directory cacheDir,
  required String number,
}) async {
  if (!source.existsSync()) {
    throw FileSystemException('Invoice PDF is missing', source.path);
  }
  if (source.lengthSync() < 100) {
    throw FileSystemException('Invoice PDF is empty', source.path);
  }
  await cacheDir.create(recursive: true);
  final dest = File(p.join(cacheDir.path, invoicePdfFileName(number)));
  return source.copy(dest.path);
}
