import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Formal Laurent and Taylor PowerSeries', () {
    test('expands elementary and special functions with OrderTerm', () {
      final expSeries = Expr.parse('exp(x)').series('x', order: 4);
      check(expSeries.toString())
          .equals('1 + x + 1/2 * x ^ 2 + 1/6 * x ^ 3 + O(x^4)');

      final cosSeries = Expr.parse('cos(x)').series('x', order: 5);
      check(cosSeries.toString())
          .equals('1 - 1/2 * x ^ 2 + 1/24 * x ^ 4 + O(x^5)');

      final laurent = Expr.parse('sin(x) / x^2').series('x', order: 3);
      check(laurent.toString()).equals('1 / x - 1/6 * x + O(x^3)');
    });
  });
}
