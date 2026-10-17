import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Taylor polynomial expansion', () {
    test('taylorSeries around 0 and non-zero expansion points', () {
      final sinTaylor = Expr.parse('sin(x)').taylorSeries('x', order: 5);
      check(sinTaylor.toString()).equals('x - 1/6 * x ^ 3 + 1/120 * x ^ 5');

      final lnTaylor = Expr.parse('ln(x)')
          .taylorSeries('x', around: 1, order: 3);
      check(lnTaylor.evaluate({'x': 1.1}))
          .isCloseTo(0.1 - 0.01 / 2 + 0.001 / 3, 1e-12);
    });
  });
}
