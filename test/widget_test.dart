import 'package:flutter_test/flutter_test.dart';

import 'package:beepainel/core/url_utils.dart';

void main() {
  group('UrlUtils', () {
    test('normalize adiciona https quando falta esquema', () {
      expect(UrlUtils.normalize('exemplo.com'), 'https://exemplo.com');
      expect(UrlUtils.normalize('http://x.com'), 'http://x.com');
    });

    test('isValid rejeita entradas inválidas', () {
      expect(UrlUtils.isValid('exemplo.com'), isTrue);
      expect(UrlUtils.isValid('https://painel.exemplo.com/x'), isTrue);
      expect(UrlUtils.isValid(''), isFalse);
      expect(UrlUtils.isValid('   '), isFalse);
    });

    test('sameOrigin compara scheme/host/port', () {
      expect(
        UrlUtils.sameOrigin('https://a.com/x', 'https://a.com/y'),
        isTrue,
      );
      expect(
        UrlUtils.sameOrigin('https://a.com', 'https://b.com'),
        isFalse,
      );
    });
  });
}
