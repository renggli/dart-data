import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:test/test.dart';

void main() {
  group('Symbolic compiler', () {
    test('toFunction1D and toComplexFunction1D evaluate accurately', () {
      final f = Expr.parse('x^3 - 2*x + 1').toFunction1D('x');
      check(f(2.0)).equals(5.0);

      final cf = Expr.parse('exp(i * x)').toComplexFunction1D('x');
      final val = cf(const Complex(0.0));
      check(val.a).isCloseTo(1.0, 1e-12);
      check(val.b).isCloseTo(0.0, 1e-12);
    });

    test('toVectorFunction, compile, and compileTensorKernel evaluate multivariable expressions', () {
      final expr = Expr.parse('x^2 + 2*y');
      final vfn = expr.toVectorFunction(['x', 'y']);
      check(vfn(Vector.fromList([3.0, 4.0]))).equals(17.0);

      final cfn = expr.compile(['x', 'y']);
      check(cfn([3.0, 4.0])).equals(17.0);

      final kernel = expr.compileTensorKernel(['x', 'y']);
      final out = Float64List(2);
      kernel([
        Float64List.fromList([1.0, 3.0]),
        Float64List.fromList([2.0, 4.0]),
      ], out);
      check(out[0]).equals(5.0);
      check(out[1]).equals(17.0);
    });

    test(
      'BytecodeEvaluator performs Common Subexpression Elimination (CSE)',
      () {
        final sub = Expr.parse('sin(x^2 + 3*x + 1)');
        final expr = sub + Pow(sub, IntegerNumber.two) + Cos(sub);

        final optEval = expr.compileBytecode(variables: ['x'], optimize: true);
        final unoptEval = expr.compileBytecode(
          variables: ['x'],
          optimize: false,
        );

        check(optEval.registerCount).isGreaterThan(0);
        check(unoptEval.registerCount).equals(0);
        check(optEval.instructions.length)
            .isLessThan(unoptEval.instructions.length);

        for (final xVal in [-1.5, 0.0, 0.75, 2.5]) {
          final expected = expr.evaluate({'x': xVal});
          check(optEval.evaluate1D(xVal)).isCloseTo(expected, 1e-12);
          check(unoptEval.evaluate1D(xVal)).isCloseTo(expected, 1e-12);
          check(optEval.evaluateMap({'x': xVal})).isCloseTo(expected, 1e-12);
          check(optEval.evaluateComplex1D(Complex(xVal)).a)
              .isCloseTo(expected, 1e-12);
        }
      },
    );

    test(
      'BytecodeEvaluator evaluates Piecewise and definite Integral nodes',
      () {
        final pw = Expr.parse('piecewise(x < 0, -2*x, x^2)')
            .compileBytecode(variables: ['x']);
        check(pw.evaluate1D(-3.0)).equals(6.0);
        check(pw.evaluate1D(4.0)).equals(16.0);

        final integralExpr = Integral(
          Expr.parse('t^2'),
          't',
          lower: IntegerNumber.zero,
          upper: const Variable('x'),
        );
        final intEval = integralExpr.compileBytecode(variables: ['x']);
        check(intEval.evaluate1D(3.0)).isCloseTo(9.0, 1e-12);
      },
    );
  });
}
