import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
      final eq = DataType.int32.equality;
      check(eq.isEqual(5, 5)).isTrue();
      check(eq.isEqual(5, 6)).isFalse();
      check(eq.isClose(5, 5, 0.01)).isTrue();
      check(eq.isClose(5, 6, 0.01)).isFalse();
    });
  });
}
