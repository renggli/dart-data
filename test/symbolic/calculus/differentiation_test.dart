import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');

  group('DifferentiationExtension - elementary functions and rules', () {
    test('constant and variable rules', () {
      check(const RationalNumber(5).derivative('x'))
          .equals(RationalNumber.zero);
      check(y.derivative('x')).equals(RationalNumber.zero);
      check(x.derivative('x')).equals(RationalNumber.one);
      check((x * 3).derivative('x').simplify()).equals(const RationalNumber(3));
    });

    test('powers and polynomials', () {
      check(x.pow(2).derivative('x').simplify())
          .equals(const RationalNumber(2) * x);
      check(x.pow(3).derivative('x').simplify())
          .equals(const RationalNumber(3) * x.pow(2));
      check(
        (x.pow(3) + const RationalNumber(2) * x + 1).derivative('x').simplify(),
      ).equals(const RationalNumber(3) * x.pow(2) + 2);
    });

    test('transcendental functions', () {
      check(const Exp(x).derivative('x').simplify()).equals(const Exp(x));
      check(const Ln(x).derivative('x').simplify())
          .equals(const RationalNumber(1) / x);
      check(const Sin(x).derivative('x').simplify()).equals(const Cos(x));
      check(const Cos(x).derivative('x').simplify()).equals(-const Sin(x));
    });

    test('higher order derivatives', () {
      final expr = x.pow(4);
      check(expr.derivative('x', order: 1).simplify())
          .equals(const RationalNumber(4) * x.pow(3));
      check(expr.derivative('x', order: 2).simplify())
          .equals(const RationalNumber(12) * x.pow(2));
      check(expr.derivative('x', order: 3).simplify())
          .equals(const RationalNumber(24) * x);
      check(expr.derivative('x', order: 4).simplify())
          .equals(const RationalNumber(24));
      check(expr.derivative('x', order: 5).simplify())
          .equals(RationalNumber.zero);
    });

    test('higher order derivatives of canonical Pow', () {
      const sqrtX = Pow(x, RationalNumber(1, 2));

      // 1st derivative: (1/2) * x^(-1/2)
      final d1 = sqrtX.derivative('x', order: 1);
      check(d1.evaluate({'x': 4.0})).equals(0.25);

      // 2nd derivative: -(1/4) * x^(-3/2)
      final d2 = sqrtX.derivative('x', order: 2);
      check(d2.evaluate({'x': 4.0})).equals(-0.03125);

      // 3rd derivative: (3/8) * x^(-5/2)
      final d3 = sqrtX.derivative('x', order: 3);
      check(d3.evaluate({'x': 4.0})).equals(3.0 / 256.0);
    });
  });

  group('First-order derivative parity across fine sampling grids', () {
    test('Tan(x) on (-1.4, 1.4)', () {
      const exprTan = Tan(x);
      final symDTan = exprTan.derivative('x').toFunction1D('x');
      final numTan = exprTan.toFunction1D('x');
      for (var i = 0; i < 50; i++) {
        final t = -1.4 + (2.8 / 49.0) * i;
        final symVal = symDTan(t);
        final numVal = derivative(numTan, t, order: 1);
        final exact = 1.0 / (math.cos(t) * math.cos(t));
        check(symVal).isCloseTo(exact, 1e-9);
        check(numVal).isCloseTo(symVal, 1e-4);
      }
    });

    test('Asin(x) and Acos(x) on (-0.95, 0.95)', () {
      const exprAsin = Asin(x);
      final symDAsin = exprAsin.derivative('x').toFunction1D('x');
      final numAsin = exprAsin.toFunction1D('x');

      const exprAcos = Acos(x);
      final symDAcos = exprAcos.derivative('x').toFunction1D('x');
      final numAcos = exprAcos.toFunction1D('x');

      for (var i = 0; i < 50; i++) {
        final t = -0.95 + (1.9 / 49.0) * i;
        final symAsinVal = symDAsin(t);
        final numAsinVal = derivative(numAsin, t, order: 1);
        final exactAsin = 1.0 / math.sqrt(1.0 - t * t);
        check(symAsinVal).isCloseTo(exactAsin, 1e-9);
        check(numAsinVal).isCloseTo(symAsinVal, 1e-4);

        final symAcosVal = symDAcos(t);
        final numAcosVal = derivative(numAcos, t, order: 1);
        final exactAcos = -1.0 / math.sqrt(1.0 - t * t);
        check(symAcosVal).isCloseTo(exactAcos, 1e-9);
        check(numAcosVal).isCloseTo(symAcosVal, 1e-4);
      }
    });

    test('Atan(x) on (-5.0, 5.0)', () {
      const exprAtan = Atan(x);
      final symDAtan = exprAtan.derivative('x').toFunction1D('x');
      final numAtan = exprAtan.toFunction1D('x');
      for (var i = 0; i < 50; i++) {
        final t = -5.0 + (10.0 / 49.0) * i;
        final symVal = symDAtan(t);
        final numVal = derivative(numAtan, t, order: 1);
        final exact = 1.0 / (1.0 + t * t);
        check(symVal).isCloseTo(exact, 1e-9);
        check(numVal).isCloseTo(symVal, 1e-4);
      }
    });

    test('Hyperbolics: Sinh, Cosh, Tanh on (-4.0, 4.0)', () {
      const exprSinh = Sinh(x);
      final symDSinh = exprSinh.derivative('x').toFunction1D('x');
      final numSinh = exprSinh.toFunction1D('x');

      const exprCosh = Cosh(x);
      final symDCosh = exprCosh.derivative('x').toFunction1D('x');
      final numCosh = exprCosh.toFunction1D('x');

      const exprTanh = Tanh(x);
      final symDTanh = exprTanh.derivative('x').toFunction1D('x');
      final numTanh = exprTanh.toFunction1D('x');

      for (var i = 0; i < 50; i++) {
        final t = -4.0 + (8.0 / 49.0) * i;

        final exactSinh = (math.exp(t) + math.exp(-t)) / 2.0;
        check(symDSinh(t)).isCloseTo(exactSinh, 1e-9);
        check(derivative(numSinh, t, order: 1)).isCloseTo(symDSinh(t), 1e-4);

        final exactCosh = (math.exp(t) - math.exp(-t)) / 2.0;
        check(symDCosh(t)).isCloseTo(exactCosh, 1e-9);
        check(derivative(numCosh, t, order: 1)).isCloseTo(symDCosh(t), 1e-4);

        final ch = (math.exp(t) + math.exp(-t)) / 2.0;
        final exactTanh = 1.0 / (ch * ch);
        check(symDTanh(t)).isCloseTo(exactTanh, 1e-9);
        check(derivative(numTanh, t, order: 1)).isCloseTo(symDTanh(t), 1e-4);
      }
    });

    test('Abs(x), Sqrt(x), and Log(2, x)', () {
      const exprAbs = Abs(x);
      final symDAbs = exprAbs.derivative('x').toFunction1D('x');
      final numAbs = exprAbs.toFunction1D('x');
      for (var i = 0; i < 25; i++) {
        final posT = 0.1 + (4.9 / 24.0) * i;
        check(symDAbs(posT)).isCloseTo(1.0, 1e-9);
        check(derivative(numAbs, posT, order: 1)).isCloseTo(1.0, 1e-4);

        final negT = -5.0 + (4.9 / 24.0) * i;
        check(symDAbs(negT)).isCloseTo(-1.0, 1e-9);
        check(derivative(numAbs, negT, order: 1)).isCloseTo(-1.0, 1e-4);
      }

      const exprSqrt = Pow(x, RationalNumber(1, 2));
      final symDSqrt = exprSqrt.derivative('x').toFunction1D('x');
      final numSqrt = exprSqrt.toFunction1D('x');
      for (var i = 0; i < 50; i++) {
        final t = 0.1 + (19.9 / 49.0) * i;
        final symVal = symDSqrt(t);
        final exact = 1.0 / (2.0 * math.sqrt(t));
        check(symVal).isCloseTo(exact, 1e-9);
        check(derivative(numSqrt, t, order: 1)).isCloseTo(symVal, 1e-4);
      }

      const exprLog = Log(RationalNumber(2), x);
      final symDLog = exprLog.derivative('x').toFunction1D('x');
      final numLog = exprLog.toFunction1D('x');
      for (var i = 0; i < 50; i++) {
        final t = 0.1 + (9.9 / 49.0) * i;
        final symVal = symDLog(t);
        final exact = 1.0 / (t * math.ln2);
        check(symVal).isCloseTo(exact, 1e-9);
        check(derivative(numLog, t, order: 1)).isCloseTo(symVal, 1e-4);
      }
    });
  });

  group('Second-order derivative parity across fine sampling grids', () {
    test('Tan, Sinh, Cosh, Atan, Sqrt second derivatives', () {
      const exprTan = Tan(x);
      final symD2Tan = exprTan.derivative('x', order: 2).toFunction1D('x');
      final numTan = exprTan.toFunction1D('x');
      for (var i = 0; i < 20; i++) {
        final t = -1.0 + (2.0 / 19.0) * i;
        final symVal = symD2Tan(t);
        final numVal = derivative(numTan, t, order: 2);
        final c = math.cos(t);
        final exact = (2.0 * math.sin(t)) / (c * c * c);
        check(symVal).isCloseTo(exact, 1e-9);
        check(numVal).isCloseTo(symVal, 1e-2);
      }

      const exprSinh = Sinh(x);
      final symD2Sinh = exprSinh.derivative('x', order: 2).toFunction1D('x');
      final numSinh = exprSinh.toFunction1D('x');
      for (var i = 0; i < 20; i++) {
        final t = -2.0 + (4.0 / 19.0) * i;
        final symVal = symD2Sinh(t);
        final numVal = derivative(numSinh, t, order: 2);
        final exact = (math.exp(t) - math.exp(-t)) / 2.0;
        check(symVal).isCloseTo(exact, 1e-9);
        check(numVal).isCloseTo(symVal, 1e-2);
      }

      const exprAtan = Atan(x);
      final symD2Atan = exprAtan.derivative('x', order: 2).toFunction1D('x');
      final numAtan = exprAtan.toFunction1D('x');
      for (var i = 0; i < 20; i++) {
        final t = -3.0 + (6.0 / 19.0) * i;
        final symVal = symD2Atan(t);
        final numVal = derivative(numAtan, t, order: 2);
        final denom = 1.0 + t * t;
        final exact = (-2.0 * t) / (denom * denom);
        check(symVal).isCloseTo(exact, 1e-9);
        check(numVal).isCloseTo(symVal, 1e-2);
      }

      const exprSqrt = Pow(x, RationalNumber(1, 2));
      final symD2Sqrt = exprSqrt.derivative('x', order: 2).toFunction1D('x');
      final numSqrt = exprSqrt.toFunction1D('x');
      for (var i = 0; i < 20; i++) {
        final t = 0.5 + (9.5 / 19.0) * i;
        final symVal = symD2Sqrt(t);
        final numVal = derivative(numSqrt, t, order: 2);
        final exact = -1.0 / (4.0 * math.pow(t, 1.5));
        check(symVal).isCloseTo(exact, 1e-9);
        check(numVal).isCloseTo(symVal, 1e-2);
      }
    });
  });

  group('Chain rule derivative parity on affine composite expressions', () {
    test('composite affine derivatives', () {
      final cases = <(Expr, double, double, double Function(double))>[
        (
          Tan((x * 2) + 1),
          -1.0,
          0.1,
          (t) => 2.0 / math.pow(math.cos(2.0 * t + 1.0), 2),
        ),
        (
          Asin((x * const RationalNumber(1, 2)) + const RationalNumber(1, 10)),
          -1.5,
          1.5,
          (t) => 0.5 / math.sqrt(1.0 - math.pow(0.5 * t + 0.1, 2)),
        ),
        (
          Atan((x * 3) - 1),
          -3.0,
          3.0,
          (t) => 3.0 / (1.0 + math.pow(3.0 * t - 1.0, 2)),
        ),
        (
          Sinh((x * 2) - 1),
          -1.5,
          1.5,
          (t) =>
              2.0 *
              (math.exp(2.0 * t - 1.0) + math.exp(-(2.0 * t - 1.0))) /
              2.0,
        ),
        (
          Tanh((x * 2) + 1),
          -2.0,
          2.0,
          (t) {
            final ch =
                (math.exp(2.0 * t + 1.0) + math.exp(-(2.0 * t + 1.0))) / 2.0;
            return 2.0 / (ch * ch);
          },
        ),
        (
          Pow((x * 2) + 3, const RationalNumber(1, 2)),
          -1.0,
          5.0,
          (t) => 2.0 / (2.0 * math.sqrt(2.0 * t + 3.0)),
        ),
      ];

      for (final (expr, minT, maxT, exactDeriv) in cases) {
        final symD = expr.derivative('x').toFunction1D('x');
        final numF = expr.toFunction1D('x');
        for (var i = 0; i < 20; i++) {
          final t = minT + ((maxT - minT) / 19.0) * i;
          final symVal = symD(t);
          final numVal = derivative(numF, t, order: 1);
          final exactVal = exactDeriv(t);
          check(symVal).isCloseTo(exactVal, 1e-9);
          check(numVal).isCloseTo(symVal, 1e-4);
        }
      }
    });
  });

  group('Singularity asymptotics and domain boundaries', () {
    test('singularity asymptotics for Tan near pi/2', () {
      const exprTan = Tan(x);
      final tanFn = exprTan.toFunction1D('x');
      final dTanFn = exprTan.derivative('x').toFunction1D('x');

      for (final eps in [1e-2, 1e-4, 1e-7, 1e-10]) {
        final pt = math.pi / 2.0 - eps;
        final val = tanFn(pt);
        check(val).isCloseTo(math.tan(pt), 1e-9);
        check(val.isFinite).isTrue();

        final dVal = dTanFn(pt);
        final c = math.cos(pt);
        check(dVal).isCloseTo(1.0 / (c * c), 1e-7);
        check(dVal.isFinite).isTrue();
      }
    });

    test('boundary conditions at x = 0 for Abs(x) and Pow(x, 1/2)', () {
      const exprAbs = Abs(x);
      check(exprAbs.evaluate({'x': 0.0})).equals(0.0);
      final dAbsVal = exprAbs.derivative('x').evaluate({'x': 0.0});
      check(dAbsVal.isNaN).isTrue();

      const exprSqrt = Pow(x, RationalNumber(1, 2));
      check(exprSqrt.evaluate({'x': 0.0})).equals(0.0);
      final dSqrtVal = exprSqrt.derivative('x').evaluate({'x': 0.0});
      check(dSqrtVal).equals(double.infinity);
    });

    test('out of domain evaluation produces NaN as per IEEE-754 semantics', () {
      const exprSqrt = Pow(x, RationalNumber(1, 2));
      check(exprSqrt.toFunction1D('x')(-1.0).isNaN).isTrue();

      const exprAsin = Asin(x);
      check(exprAsin.toFunction1D('x')(1.5).isNaN).isTrue();

      const exprAcos = Acos(x);
      check(exprAcos.toFunction1D('x')(1.5).isNaN).isTrue();
    });
  });
}
