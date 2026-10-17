import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/src/symbolic/solver/trigonometric.dart';
import 'package:data/symbolic.dart';
import 'package:test/test.dart';

Expr _piFrac(int num, int den) =>
    (RationalNumber(num, den) * Constant.pi).simplify();

void main() {
  group('invertSin', () {
    test('solves sin(x) = c for all exact special values', () {
      const x = Variable('x');
      check(Expr.parse('sin(x)').solve('x'))
          .unorderedEquals([IntegerNumber.zero, Constant.pi]);
      check(Expr.parse('sin(x) - 1').solve('x')).deepEquals([_piFrac(1, 2)]);
      check(Expr.parse('sin(x) + 1').solve('x')).deepEquals([_piFrac(3, 2)]);
      check(Expr.parse('sin(x) - 1/2').solve('x'))
          .unorderedEquals([_piFrac(1, 6), _piFrac(5, 6)]);
      check(Expr.parse('sin(x) + 1/2').solve('x'))
          .unorderedEquals([_piFrac(7, 6), _piFrac(11, 6)]);
      check((Sin(x) - Expr.parse('sqrt(2)/2')).solve('x'))
          .unorderedEquals([_piFrac(1, 4), _piFrac(3, 4)]);
      check((Sin(x) + Expr.parse('sqrt(2)/2')).solve('x'))
          .unorderedEquals([_piFrac(5, 4), _piFrac(7, 4)]);
      check((Sin(x) - Expr.parse('sqrt(3)/2')).solve('x'))
          .unorderedEquals([_piFrac(1, 3), _piFrac(2, 3)]);
      check((Sin(x) + Expr.parse('sqrt(3)/2')).solve('x'))
          .unorderedEquals([_piFrac(4, 3), _piFrac(5, 3)]);
    });

    test(
      'handles out-of-range, general constants, and composite arguments',
      () {
        check(Expr.parse('sin(x) - 2').solve('x')).isEmpty();
        check(Expr.parse('sin(x) + 2').solve('x')).isEmpty();
        check((Sin(const Variable('x')) - Constant.pi).solve('x')).isEmpty();

        final gen = Expr.parse('sin(x) - 1/3').solve('x');
        check(gen.length).equals(2);
        for (final r in gen) {
          check(math.sin(r.evaluate())).isCloseTo(1.0 / 3.0, 1e-12);
        }

        // Composite linear argument
        final linComp = Expr.parse('sin(2*x + 1)').solve('x');
        check(linComp.length).equals(2);
        for (final r in linComp) {
          check(math.sin(2.0 * r.evaluate() + 1.0)).isCloseTo(0.0, 1e-12);
        }

        // Composite quadratic argument falling back to solveEquation
        final quadComp = invertSin(
          Expr.parse('x^2 - x'),
          IntegerNumber.one,
          'x',
        );
        check(quadComp.length).equals(2);
      },
    );
  });

  group('invertCos', () {
    test('solves cos(x) = c for all exact special values', () {
      const x = Variable('x');
      check(Expr.parse('cos(x)').solve('x'))
          .unorderedEquals([_piFrac(1, 2), _piFrac(3, 2)]);
      check(Expr.parse('cos(x) - 1').solve('x'))
          .deepEquals([IntegerNumber.zero]);
      check(Expr.parse('cos(x) + 1').solve('x')).deepEquals([Constant.pi]);
      check(Expr.parse('cos(x) - 1/2').solve('x'))
          .unorderedEquals([_piFrac(1, 3), _piFrac(5, 3)]);
      check(Expr.parse('cos(x) + 1/2').solve('x'))
          .unorderedEquals([_piFrac(2, 3), _piFrac(4, 3)]);
      check((Cos(x) - Expr.parse('sqrt(2)/2')).solve('x'))
          .unorderedEquals([_piFrac(1, 4), _piFrac(7, 4)]);
      check((Cos(x) + Expr.parse('sqrt(2)/2')).solve('x'))
          .unorderedEquals([_piFrac(3, 4), _piFrac(5, 4)]);
      check((Cos(x) - Expr.parse('sqrt(3)/2')).solve('x'))
          .unorderedEquals([_piFrac(1, 6), _piFrac(11, 6)]);
      check((Cos(x) + Expr.parse('sqrt(3)/2')).solve('x'))
          .unorderedEquals([_piFrac(5, 6), _piFrac(7, 6)]);
    });

    test(
      'handles out-of-range, general constants, and composite arguments',
      () {
        check(Expr.parse('cos(x) - 2').solve('x')).isEmpty();
        check(Expr.parse('cos(x) + 1.5').solve('x')).isEmpty();

        final gen = Expr.parse('cos(x) - 1/3').solve('x');
        check(gen.length).equals(2);
        for (final r in gen) {
          check(math.cos(r.evaluate())).isCloseTo(1.0 / 3.0, 1e-12);
        }

        // Composite quadratic argument falling back to solveEquation
        final quadComp = invertCos(
          Expr.parse('x^2 - x'),
          IntegerNumber.one,
          'x',
        );
        check(quadComp)
            .unorderedEquals([IntegerNumber.zero, IntegerNumber.one]);
      },
    );
  });

  group('invertTan', () {
    test('solves tan(x) = c for all exact special values', () {
      const x = Variable('x');
      check(Expr.parse('tan(x)').solve('x'))
          .unorderedEquals([IntegerNumber.zero, Constant.pi]);
      check(Expr.parse('tan(x) - 1').solve('x'))
          .unorderedEquals([_piFrac(1, 4), _piFrac(5, 4)]);
      check(Expr.parse('tan(x) + 1').solve('x'))
          .unorderedEquals([_piFrac(3, 4), _piFrac(7, 4)]);
      check((Tan(x) - Expr.parse('sqrt(3)/3')).solve('x'))
          .unorderedEquals([_piFrac(1, 6), _piFrac(7, 6)]);
      check((Tan(x) + Expr.parse('sqrt(3)/3')).solve('x'))
          .unorderedEquals([_piFrac(5, 6), _piFrac(11, 6)]);
      check((Tan(x) - Expr.parse('sqrt(3)')).solve('x'))
          .unorderedEquals([_piFrac(1, 3), _piFrac(4, 3)]);
      check((Tan(x) + Expr.parse('sqrt(3)')).solve('x'))
          .unorderedEquals([_piFrac(2, 3), _piFrac(5, 3)]);
    });

    test('handles general constants and composite arguments', () {
      final gen = Expr.parse('tan(x) - 2').solve('x');
      check(gen.length).equals(2);
      for (final r in gen) {
        check(math.tan(r.evaluate())).isCloseTo(2.0, 1e-12);
      }

      final quadComp = invertTan(
        Expr.parse('x^2 - x'),
        IntegerNumber.zero,
        'x',
      );
      check(quadComp.length).equals(4);
    });
  });
}
