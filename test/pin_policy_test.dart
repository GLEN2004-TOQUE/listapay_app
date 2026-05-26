import 'package:flutter_test/flutter_test.dart';
import 'package:ListaPay/core/security/pin_policy.dart';

void main() {
  group('PinPolicy', () {
    test('accepts valid 6-digit PIN', () {
      expect(PinPolicy.validateNewPin('482917'), isNull);
    });

    test('rejects short PIN', () {
      expect(PinPolicy.validateNewPin('1234'), isNotNull);
    });

    test('rejects blocked PIN', () {
      expect(PinPolicy.validateNewPin('123456'), isNotNull);
    });

    test('rejects all-same-digit PIN', () {
      expect(PinPolicy.validateNewPin('555555'), isNotNull);
    });
  });
}
