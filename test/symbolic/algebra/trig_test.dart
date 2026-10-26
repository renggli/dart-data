import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('expandTrig', () {
    test('expands angle-addition and subtraction formulas', () {
      check(Expr.parse('sin(x + y)').expandTrig().toString())
          .equals('cos(x) * sin(y) + cos(y) * sin(x)');
      check(Expr.parse('cos(x + y)').expandTrig().toString())
          .equals('cos(x) * cos(y) - sin(x) * sin(y)');
      check(Expr.parse('tan(x + y)').expandTrig().toString())
          .equals('(tan(x) + tan(y)) / (1 - tan(x) * tan(y))');
      check(Expr.parse('sinh(x + y)').expandTrig().toString())
          .equals('sinh(x) * cosh(y) + sinh(y) * cosh(x)');
      check(Expr.parse('cosh(x + y)').expandTrig().toString())
          .equals('sinh(x) * sinh(y) + cosh(x) * cosh(y)');
      check(Expr.parse('tanh(x + y)').expandTrig().toString())
          .equals('(tanh(x) + tanh(y)) / (1 + tanh(x) * tanh(y))');

      // 3-term angle addition triggers n-ary sublist splitting
      check(Expr.parse('sin(x + y + z)').expandTrig()).isNotNull();
      check(Expr.parse('cos(x + y + z)').expandTrig()).isNotNull();
      check(Expr.parse('tan(x + y + z)').expandTrig()).isNotNull();
      check(Expr.parse('sinh(x + y + z)').expandTrig()).isNotNull();
      check(Expr.parse('cosh(x + y + z)').expandTrig()).isNotNull();
      check(Expr.parse('tanh(x + y + z)').expandTrig()).isNotNull();
    });

    test('expands multiple-angle expressions via De Moivre formulas', () {
      check(Expr.parse('sin(2 * x)').expandTrig().toString())
          .equals('2 * cos(x) * sin(x)');
      check(Expr.parse('cos(2 * x)').expandTrig().toString())
          .equals('cos(x) ^ 2 - sin(x) ^ 2');
      check(Expr.parse('sin(3 * x)').expandTrig().toString())
          .equals('-sin(x) ^ 3 + 3 * cos(x) ^ 2 * sin(x)');
      check(Expr.parse('tan(2 * x)').expandTrig().toString())
          .equals('2 * tan(x) / (1 - tan(x) ^ 2)');
      check(Expr.parse('sinh(2 * x)').expandTrig().toString())
          .equals('2 * sinh(x) * cosh(x)');
      check(Expr.parse('cosh(2 * x)').expandTrig().toString())
          .equals('sinh(x) ^ 2 + cosh(x) ^ 2');
      check(Expr.parse('tanh(2 * x)').expandTrig().toString())
          .equals('2 * tanh(x) / (1 + tanh(x) ^ 2)');
    });
  });

  group('simplifyTrig', () {
    test('simplifies Pythagorean, quotient, double-angle, and product-to-sum identities', () {
      check(Expr.parse('sin(x)^2 + cos(x)^2').simplifyTrig())
          .equals(IntegerNumber.one);
      check(Expr.parse('tan(x) * cos(x)').simplifyTrig().toString())
          .equals('sin(x)');
      check(Expr.parse('sin(x) / cos(x)').simplifyTrig().toString())
          .equals('tan(x)');
      check(Expr.parse('sinh(x) / cosh(x)').simplifyTrig().toString())
          .equals('tanh(x)');
      check(Expr.parse('1 + tan(x)^2').simplifyTrig().toString())
          .equals('cos(x) ^ (-2)');
      check(Expr.parse('2 * sin(x) * cos(x)').simplifyTrig().toString())
          .equals('sin(2 * x)');
      check(Expr.parse('cos(x)^2 - sin(x)^2').simplifyTrig().toString())
          .equals('cos(2 * x)');
      check(Expr.parse('cosh(x)^2 + sinh(x)^2').simplifyTrig().toString())
          .equals('cosh(2 * x)');
      check(Expr.parse('2 * sinh(x) * cosh(x)').simplifyTrig().toString())
          .equals('sinh(2 * x)');
      check(
        Expr.parse('sin(x) * cos(y) + cos(x) * sin(y)')
            .simplifyTrig()
            .toString(),
      ).equals('sin(x + y)');
      check(
        Expr.parse('cos(x) * cos(y) - sin(x) * sin(y)')
            .simplifyTrig()
            .toString(),
      ).equals('cos(x + y)');
      check(
        Expr.parse('sinh(x) * cosh(y) + cosh(x) * sinh(y)')
            .simplifyTrig()
            .toString(),
      ).equals('sinh(x + y)');
      check(
        Expr.parse('cosh(x) * cosh(y) + sinh(x) * sinh(y)')
            .simplifyTrig()
            .toString(),
      ).equals('cosh(x + y)');

      // Product-to-sum pairs with reverse structural order
      check(Expr.parse('cos(y) * cos(x)').simplifyTrig().toString())
          .equals('1/2 * cos(x + y) + 1/2 * cos(x - y)');
      check(Expr.parse('sin(y) * sin(x)').simplifyTrig().toString())
          .equals('-1/2 * cos(x + y) + 1/2 * cos(x - y)');
      check(Expr.parse('cosh(y) * cosh(x)').simplifyTrig().toString())
          .equals('1/2 * cosh(x + y) + 1/2 * cosh(x - y)');
      check(Expr.parse('sinh(y) * sinh(x)').simplifyTrig().toString())
          .equals('1/2 * cosh(x + y) - 1/2 * cosh(x - y)');
    });
  });

  group('rewrite (exp, trig, sinCos)', () {
    test('rewrites between trigonometric and exponential forms', () {
      final euler = Expr.parse('cos(x) + i * sin(x)');
      check(euler.rewrite(RewriteTarget.exp).toString()).equals('exp(i * x)');

      final sinX = Expr.parse('sin(x)');
      check(sinX.rewrite(RewriteTarget.exp).rewrite(RewriteTarget.trig))
          .equals(sinX);

      final cosX = Expr.parse('cos(x)');
      check(cosX.rewrite(RewriteTarget.exp).rewrite(RewriteTarget.trig))
          .equals(cosX);

      final coshX = Expr.parse('cosh(x)');
      check(coshX.rewrite(RewriteTarget.exp).toString())
          .equals('1/2 * exp(x) + 1/2 * exp(-x)');

      final sinhX = Expr.parse('sinh(x)');
      check(sinhX.rewrite(RewriteTarget.exp).toString())
          .equals('1/2 * exp(x) - 1/2 * exp(-x)');

      final expComplex = Expr.parse('exp(a + i * b)');
      check(expComplex.rewrite(RewriteTarget.trig).toString())
          .equals('exp(a) * cos(b) + i * exp(a) * sin(b)');

      final tanSum = Expr.parse('tan(x) + tanh(y)');
      check(tanSum.rewrite(RewriteTarget.sinCos).toString())
          .equals('sinh(y) / cosh(y) + sin(x) / cos(x)');

      final tanExp = Expr.parse('tan(x)').rewrite(RewriteTarget.exp);
      check(tanExp.rewrite(RewriteTarget.trig).simplifyTrig().toString())
          .equals('tan(x)');

      final tanhExp = Expr.parse('tanh(x)').rewrite(RewriteTarget.exp);
      check(tanhExp.evaluate({'x': 0.5}))
          .isCloseTo(Expr.parse('tanh(x)').evaluate({'x': 0.5}), 1e-12);

      check(Expr.parse('exp(x)').rewrite(RewriteTarget.trig).toString())
          .equals('exp(x)');

      // Unmatched powers in _foldMulToTan
      check(Expr.parse('sin(x)^2 * cos(y)').simplifyTrig().toString())
          .equals('cos(y) * sin(x) ^ 2');
      check(Expr.parse('sinh(x)^2 * cosh(y)').simplifyTrig().toString())
          .equals('sinh(x) ^ 2 * cosh(y)');

      // Assumptions propagation in expandTrig, simplifyTrig, rewrite
      check(
        Expr.parse('sin(2 * sqrt(x^2))')
            .expandTrig(assumptions: Assumptions.positive)
            .toString(),
      ).equals('2 * cos(x) * sin(x)');
      check(
        Expr.parse('2 * sin(sqrt(x^2)) * cos(sqrt(x^2))')
            .simplifyTrig(assumptions: Assumptions.positive)
            .toString(),
      ).equals('sin(2 * x)');
      check(
        Expr.parse('tan(sqrt(x^2))')
            .rewrite(RewriteTarget.sinCos, assumptions: Assumptions.positive)
            .toString(),
      ).equals('sin(x) / cos(x)');

      // Multi-factor integer multiple in expandTrig (sin(2 * x * y))
      check(Expr.parse('sin(2 * x * y)').expandTrig().toString())
          .equals('2 * cos(x * y) * sin(x * y)');

      // Reverse structural order in product-to-sum contractions (cos(y)*cos(x), sin(y)*sin(x), cosh(y)*cosh(x), sinh(y)*sinh(x))
      const xVar = Variable('x');
      const yVar = Variable('y');
      check(Mul([Cos(yVar), Cos(xVar)]).simplifyTrig().toString())
          .contains('cos');
      check(Mul([Sin(yVar), Sin(xVar)]).simplifyTrig().toString())
          .contains('cos');
      check(Mul([Cosh(yVar), Cosh(xVar)]).simplifyTrig().toString())
          .contains('cosh');
      check(Mul([Sinh(yVar), Sinh(xVar)]).simplifyTrig().toString())
          .contains('cosh');
    });
  });
}
