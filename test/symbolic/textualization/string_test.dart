import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('String textualization and presentation rules', () {
    test('preserves input order before simplify and sorts in increasing degree after simplify', () {
      final raw = Expr.parse('x^2 - 3*x + 1');
      check(raw.toString()).equals('x ^ 2 - 3 * x + 1');

      final simplified = raw.simplify();
      check(simplified.toString()).equals('1 - 3 * x + x ^ 2');
    });

    test('renders subtraction, negation, division, sqrt, and complex numbers cleanly', () {
      check(Expr.parse('a - b').toString()).equals('a - b');
      check(Expr.parse('-x').toString()).equals('-x');
      check(Expr.parse('a / b').toString()).equals('a / b');
      check(Expr.parse('sqrt(x)').toString()).equals('sqrt(x)');
      check(Expr.parse('(2 + 3*i)').simplify().toString()).equals('2 + 3 * i');
      check(Expr.parse('(2 - i)').simplify().toString()).equals('2 - i');
      check(Expr.parse('-i').simplify().toString()).equals('-i');
    });

    test('round-trip guarantee Expr.parse(e.toString()) == e', () {
      const inputs = [
        '0',
        '1',
        '-42',
        '3 / 7',
        '-5 / 12',
        '0.25',
        'pi',
        'e',
        'i',
        '2 + 3 * i',
        '1 - i',
        'x + y - z',
        '2 * x ^ 2 - 3 * x + 1',
        '(x + 1) / (x - 1)',
        'sqrt(1 + x ^ 2)',
        'e ^ (-x ^ 2 / 2)',
        'sin(x) + cos(2 * x)',
        'ln(x) + atan(x)',
        'lambertw(x)',
        'lambertw(x, -1)',
        'erf(x) - erfc(x)',
        'gamma(x) + beta(x, 2)',
        '1 + x + x ^ 2 / 2 + O(x ^ 3)',
      ];

      for (final src in inputs) {
        final e1 = Expr.parse(src);
        final rendered1 = e1.toString();
        final reparsed1 = Expr.parse(rendered1);
        check(reparsed1).equals(e1);

        final e2 = e1.simplify();
        final rendered2 = e2.toString();
        final reparsed2 = Expr.parse(rendered2).simplify();
        check(reparsed2).equals(e2);
      }
    });
  });
}
