import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeinvoice/domain/legal.dart';

void main() {
  test('privacy policy is a public https page in this repo', () {
    expect(privacyPolicyUrl, startsWith('https://'));
    expect(privacyPolicyUrl, contains('privacy-policy'));
    expect(File('docs/privacy-policy.html').existsSync(), isTrue);
    expect(File('docs/privacy-policy.md').existsSync(), isTrue);
    final html = File('docs/privacy-policy.html').readAsStringSync();
    final markdown = File('docs/privacy-policy.md').readAsStringSync();
    expect(html.contains('does not collect'), isTrue);
    expect(html.contains('offline'), isTrue);
    expect(markdown.contains('does not collect'), isTrue);
    expect(privacyPolicyUrl, contains('raw.githubusercontent.com'));
    expect(privacyPolicyUrl, contains('/main/docs/privacy-policy.md'));
  });
}
