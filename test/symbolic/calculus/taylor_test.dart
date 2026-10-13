import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');

  group('TaylorExtension - Maclaurin series around 0', () {
    test('Exp(x) order 2', () {
      final taylorExp = const Exp(x).taylorSeries('x', order: 2);
      final fn = taylorExp.toFunction1D('x');
      for (final t in [-0.2, 0.0, 0.2]) {
        check(fn(t)).isCloseTo(math.exp(t), 1e-2);
      }
    });

    test('Sin(x) and Cos(x) Maclaurin series', () {
      final taylorSin = const Sin(x).taylorSeries('x', order: 3);
      final sinFn = taylorSin.toFunction1D('x');
      for (final t in [-0.3, 0.0, 0.3]) {
        check(sinFn(t)).isCloseTo(math.sin(t), 1e-3);
      }

      final taylorCos = const Cos(x).taylorSeries('x', order: 4);
      final cosFn = taylorCos.toFunction1D('x');
      for (final t in [-0.3, 0.0, 0.3]) {
        check(cosFn(t)).isCloseTo(math.cos(t), 1e-3);
      }
    });

    test('Tan(x), Sinh(x), Cosh(x), Atan(x), Asin(x)', () {
      // 1. Tan(x) order 3: x + (1/3) x^3
      const exprTan = Tan(x);
      final taylorTan = exprTan.taylorSeries('x', order: 3);
      final taylorTanFn = taylorTan.toFunction1D('x');
      final tanFn = exprTan.toFunction1D('x');
      for (final t in [-0.3, -0.1, 0.0, 0.1, 0.3]) {
        check(taylorTanFn(t)).isCloseTo(tanFn(t), 1e-3);
      }

      // 2. Sinh(x) order 3: x + (1/6) x^3
      const exprSinh = Sinh(x);
      final taylorSinh = exprSinh.taylorSeries('x', order: 3);
      final taylorSinhFn = taylorSinh.toFunction1D('x');
      final sinhFn = exprSinh.toFunction1D('x');
      for (final t in [-0.4, -0.2, 0.0, 0.2, 0.4]) {
        check(taylorSinhFn(t)).isCloseTo(sinhFn(t), 1e-4);
      }

      // 3. Cosh(x) order 4: 1 + (1/2) x^2 + (1/24) x^4
      const exprCosh = Cosh(x);
      final taylorCosh = exprCosh.taylorSeries('x', order: 4);
      final taylorCoshFn = taylorCosh.toFunction1D('x');
      final coshFn = exprCosh.toFunction1D('x');
      for (final t in [-0.5, -0.2, 0.0, 0.2, 0.5]) {
        check(taylorCoshFn(t)).isCloseTo(coshFn(t), 1e-4);
      }

      // 4. Atan(x) order 3: x - (1/3) x^3
      const exprAtan = Atan(x);
      final taylorAtan = exprAtan.taylorSeries('x', order: 3);
      final taylorAtanFn = taylorAtan.toFunction1D('x');
      final atanFn = exprAtan.toFunction1D('x');
      for (final t in [-0.3, -0.1, 0.0, 0.1, 0.3]) {
        check(taylorAtanFn(t)).isCloseTo(atanFn(t), 1e-3);
      }

      // 5. Asin(x) order 3: x + (1/6) x^3
      const exprAsin = Asin(x);
      final taylorAsin = exprAsin.taylorSeries('x', order: 3);
      final taylorAsinFn = taylorAsin.toFunction1D('x');
      final asinFn = exprAsin.toFunction1D('x');
      for (final t in [-0.3, -0.1, 0.0, 0.1, 0.3]) {
        check(taylorAsinFn(t)).isCloseTo(asinFn(t), 1e-3);
      }
    });
  });

  group('TaylorExtension - Taylor series around non-zero point', () {
    test('Pow(x, 1/2) around a = 1, order 2', () {
      const exprSqrt = Pow(x, RationalNumber(1, 2));
      final taylorSqrt = exprSqrt.taylorSeries('x', around: 1, order: 2);
      final taylorSqrtFn = taylorSqrt.toFunction1D('x');
      final sqrtFn = exprSqrt.toFunction1D('x');

      for (final t in [0.85, 0.95, 1.0, 1.05, 1.15]) {
        check(taylorSqrtFn(t)).isCloseTo(sqrtFn(t), 1e-3);
      }
    });
  });
}
