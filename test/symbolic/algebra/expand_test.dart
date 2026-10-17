import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Algebraic expansion', () {
    test('distributes products over sums and expands integer powers', () {
      final e1 = Expr.parse('(x + 1)^3').expand();
      check(e1.toString()).equals('1 + 3 * x + 3 * x ^ 2 + x ^ 3');

      final e2 = Expr.parse('(x - y) * (x + y)').expand();
      check(e2.toString()).equals('x ^ 2 - y ^ 2');

      final e3 = Expr.parse('(x + y + 1)^2').expand();
      check(e3.evaluate({'x': 2.0, 'y': 3.0})).equals(36.0);
    });

    test(
      'expands expressions inside function arguments and negative powers',
      () {
        final trig = Expr.parse('sin((x + 1)^2)').expand();
        check(trig.toString()).equals('sin(1 + 2 * x + x ^ 2)');

        final negPow = Expr.parse('(x + 1)^(-2)').expand();
        check(negPow.evaluate({'x': 1.0})).equals(0.25);
      },
    );
  });
}
