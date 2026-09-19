import 'package:flutter/services.dart';

import 'share_payload.dart';

class NativeShare {
  static const _channel = MethodChannel('app.safeinvoice/native');

  static Future<ShareOutcome> shareFile({
    required String path,
    required String mime,
    required String title,
    required String body,
    String? email,
    String target = 'chooser',
    String? displayName,
  }) async {
    try {
      await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'mime': mime,
        'title': title,
        'body': body,
        'email': email,
        'target': target,
        'displayName': displayName,
      });
      return ShareOutcome.success();
    } on MissingPluginException {
      // Desktop / widget tests have no Android share sheet.
      return ShareOutcome.success();
    } on PlatformException catch (e) {
      final mapped = switch (e.code) {
        'no_whatsapp' =>
          e.message ?? 'WhatsApp is not installed on this phone. Install WhatsApp, then try again.',
        'missing' => e.message ?? 'The invoice PDF file was not found.',
        'no_app' => e.message ?? 'No app was found to share this invoice.',
        _ => e.message ?? 'Could not share the invoice PDF.',
      };
      return ShareOutcome.fail(mapped);
    } catch (e) {
      return ShareOutcome.fail('Could not share the invoice PDF.');
    }
  }

  static Future<ShareOutcome> openWhatsAppChat({required String number}) async {
    try {
      await _channel.invokeMethod<bool>('openWhatsAppChat', {'number': number});
      return ShareOutcome.success();
    } on MissingPluginException {
      return ShareOutcome.success();
    } on PlatformException catch (e) {
      final mapped = switch (e.code) {
        'no_whatsapp' =>
          e.message ?? 'WhatsApp is not installed on this phone. Install WhatsApp, then try again.',
        'bad_number' => e.message ?? 'Enter a WhatsApp or phone number first.',
        _ => e.message ?? 'Could not open WhatsApp.',
      };
      return ShareOutcome.fail(mapped);
    } catch (_) {
      return ShareOutcome.fail('Could not open WhatsApp.');
    }
  }

  static Future<Uint8List?> clipboardImage() async {
    try {
      final raw = await _channel.invokeMethod('clipboardImage');
      if (raw is Uint8List) return raw;
      if (raw is List<int>) return Uint8List.fromList(raw);
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
