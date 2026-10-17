import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

void main() {
  group('Univariate symbolic solver', () {
    test('solves linear, quadratic, biquadratic, and cubic equations', () {
      final lin = Expr.parse('3*x - 6').solve('x');
      check(lin).deepEquals([IntegerNumber.two]);

      final quad = Expr.parse('x^2 - 5*x + 6').solve('x');
      check(quad).unorderedEquals([IntegerNumber.two, IntegerNumber.of(3)]);

      final complexQuad = Expr.parse('x^2 + 1').solve('x');
      check(complexQuad).unorderedEquals([-ComplexNumber.i, ComplexNumber.i]);

      final biquad = Expr.parse('x^4 - 5*x^2 + 4').solve('x');
      check(biquad).unorderedEquals([
        IntegerNumber.of(-2),
        IntegerNumber.negativeOne,
        IntegerNumber.one,
        IntegerNumber.two,
      ]);

      final cubic = Expr.parse('x^3 - 6*x^2 + 11*x - 6').solve('x');
      check(cubic).unorderedEquals([
        IntegerNumber.one,
        IntegerNumber.two,
        IntegerNumber.of(3),
      ]);
    });

    test('solves exponential, logarithmic, trig, and Lambert W equations', () {
      final expRoots = Expr.parse('exp(2*x) - 5').solve('x');
      check(expRoots.length).equals(1);
      check(expRoots.first.evaluate()).isCloseTo(math.log(5.0) / 2.0, 1e-12);

      final lnRoots = Expr.parse('ln(x + 1) - 2').solve('x');
      check(lnRoots.length).equals(1);
      check(lnRoots.first.evaluate()).isCloseTo(math.exp(2.0) - 1.0, 1e-12);

      final lambertRoots = Expr.parse('x * exp(x) - 2').solve('x');
      check(lambertRoots).isNotEmpty();
      final r = lambertRoots.first.evaluate();
      check(r * math.exp(r)).isCloseTo(2.0, 1e-12);
    });

    test('filters roots according to VariableDomain assumptions', () {
      final imagEq = Expr.parse('x^2 + 1');
      check(imagEq.solve('x', domain: VariableDomain.real)).isEmpty();
      check(imagEq.solve('x', domain: VariableDomain.complex).length).equals(2);

      const xPos = Variable('x', domain: VariableDomain.positive);
      final posEq = Pow(xPos, IntegerNumber.two) - IntegerNumber.of(4);
      check(posEq.solve('x')).deepEquals([IntegerNumber.two]);

      final ratEq = Expr.parse('(2*x - 3) * (x + 4)');
      check(ratEq.solve('x', domain: VariableDomain.integer))
          .deepEquals([IntegerNumber.of(-4)]);
      check(ratEq.solve('x', domain: VariableDomain.positive))
          .deepEquals([RationalNumber(3, 2)]);
    });
  });
}
