import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:safeinvoice/domain/legal.dart';

void main() {
  test('Play listing does not ship sample data and privacy URL is public https', () {
    expect(privacyPolicyUrl.startsWith('https://'), isTrue);
    expect(privacyPolicyUrl.contains('privacy-policy'), isTrue);
    expect(privacyPolicyUrl.startsWith('https://raw.githubusercontent.com/'), isTrue);
    expect(File('lib/demo.dart').existsSync(), isFalse);
    expect(File('docs/privacy-policy.md').existsSync(), isTrue);
    expect(File('docs/privacy-policy.md').readAsStringSync(), contains('does not collect'));
  });

  test('Play store graphics meet Console size rules', () {
    final icon = File('play/store/icon-512.png');
    final feature = File('play/store/feature-graphic-1024x500.png');
    expect(icon.existsSync(), isTrue);
    expect(feature.existsSync(), isTrue);
    expect(_pngSize(icon), (512, 512));
    expect(_pngSize(feature), (1024, 500));

    final shots = Directory('play/store/phone')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(shots.length, inInclusiveRange(4, 8));
    for (final shot in shots) {
      final size = _pngSize(shot);
      expect(size.$1, inInclusiveRange(320, 3840));
      expect(size.$2, inInclusiveRange(320, 3840));
      expect(shot.lengthSync(), greaterThan(20 * 1024));
    }
  });
}

(int, int) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length < 24 || bytes[0] != 0x89 || bytes[1] != 0x50) {
    fail('${p.basename(file.path)} is not a PNG');
  }
  final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  return (width, height);
}
