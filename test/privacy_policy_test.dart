import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeinvoice/domain/legal.dart';

void main() {
  test('privacy policy is a public https page in this repo', () {
    expect(privacyPolicyUrl, startsWith('https://'));
    expect(privacyPolicyUrl, contains('privacy-policy'));
    expect(File('docs/privacy-policy.html').existsSync(), isTrue);
    final html = File('docs/privacy-policy.html').readAsStringSync();
    expect(html.contains('does not collect'), isTrue);
    expect(html.contains('offline'), isTrue);
  });
}
