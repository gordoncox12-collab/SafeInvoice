import 'package:flutter/services.dart';

class NativeShare {
  static const _channel = MethodChannel('app.safeinvoice/native');

  static Future<void> shareFile({
    required String path,
    required String mime,
    required String title,
    required String body,
    String? email,
    String target = 'chooser',
  }) async {
    try {
      await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'mime': mime,
        'title': title,
        'body': body,
        'email': email,
        'target': target,
      });
    } on MissingPluginException {
      // Desktop/tests: no-op.
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
