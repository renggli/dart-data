import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Equality', () {
    test('NaturalEquality', () {
      const eq = NaturalEquality<String>();
      check(eq.isEqual('a', 'a')).isTrue();
      check(eq.isEqual('a', 'b')).isFalse();
      check(eq.isClose('a', 'a', 0.01)).isTrue();
      check(eq.isClose('a', 'b', 0.01)).isFalse();
      check(eq.hash('a')).equals('a'.hashCode);
    });

    test('NumericEquality', () {
      final eq = DataType.numeric.equality;
      check(eq.isEqual(1, 1.0)).isTrue();
      check(eq.isEqual(1, 2)).isFalse();
      check(eq.isClose(1.0, 1.005, 0.01)).isTrue();
      check(eq.isClose(1.0, 1.05, 0.01)).isFalse();
    });

    test('FloatEquality', () {
      final eq = DataType.float64.equality;
      check(eq.isEqual(2.5, 2.5)).isTrue();
      check(eq.isEqual(2.5, 2.6)).isFalse();
      check(eq.isClose(2.5, 2.501, 0.01)).isTrue();
      check(eq.isClose(2.5, 2.55, 0.01)).isFalse();
    });

    test('IntegerEquality', () {
      final eq = DataType.int64.equality;
      check(eq.isEqual(5, 5)).isTrue();
      check(eq.isEqual(5, 6)).isFalse();
      check(eq.isClose(5, 5, 0.01)).isTrue();
      check(eq.isClose(5, 6, 0.01)).isFalse();

      // NaN and negative epsilon
      check(eq.isClose(5, 5, double.nan)).isFalse();
      check(eq.isClose(5, 6, double.nan)).isFalse();
      check(eq.isClose(5, 5, -1.0)).isFalse();
      check(eq.isClose(5, 6, -1.0)).isFalse();

      // 64-bit integer overflow edge cases (VM-specific)
      const isVm = 1 is! double;
      if (isVm) {
        final a = int.parse('4611686018427387904'); // 2^62
        final b = int.parse('-4611686018427387904'); // -2^62
        check(eq.isClose(a, b, 0.0)).isFalse();
        check(eq.isClose(a, b, -1.0)).isFalse();
        check(eq.isClose(b, a, 0.0)).isFalse();
        check(eq.isClose(a, b, 1e20)).isTrue();

        final minInt = int.parse('-9223372036854775808');
        final maxInt = int.parse('9223372036854775807');
        check(eq.isClose(minInt, 0, 0.0)).isFalse();
        check(eq.isClose(0, minInt, 0.0)).isFalse();
        check(eq.isClose(maxInt, minInt, 0.0)).isFalse();
        check(eq.isClose(minInt, maxInt, 0.0)).isFalse();
        check(eq.isClose(minInt, minInt, 0.0)).isTrue();
        check(eq.isClose(maxInt, maxInt, 0.0)).isTrue();
      }
    });
  });
}
