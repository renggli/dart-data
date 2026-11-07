import 'package:checks/checks.dart';
import 'package:data/src/symbolic/calculus/product.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  const k = Variable('k');
  const n = Variable('n');

  group('computeProduct', () {
    test('factorial product', () {
      final res = computeProduct(k, 'k', IntegerNumber.one, n);
      check(res).equals(Factorial(n));
    });

    test('telescoping product', () {
      final res = computeProduct(
        (k + IntegerNumber.one) / k,
        'k',
        IntegerNumber.one,
        n,
      );
      check(res.toString()).equals('1 + n');
    });

    test('infinite Wallis product', () {
      final expr =
          (IntegerNumber.of(4) * k * k) /
          (IntegerNumber.of(4) * k * k - IntegerNumber.one);
      final res = computeProduct(
        expr,
        'k',
        IntegerNumber.one,
        Constant.infinity,
      );
      check(res.toString()).equals('1/2 * pi');
    });

    test('concrete integer product', () {
      final res = computeProduct(
        k,
        'k',
        IntegerNumber.one,
        IntegerNumber.of(5),
      );
      check(res).equals(IntegerNumber.of(120));
    });
  });
}
