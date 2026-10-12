import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Compiler - compileTensorKernel Execution', () {
    test('linearized arithmetic kernel', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = 3 * x^2 - 2 * y + 5
      final expr =
          const RationalNumber(3) * x.pow(const RationalNumber(2)) -
          const RationalNumber(2) * y +
          const RationalNumber(5);
      final kernel = expr.compileTensorKernel(['x', 'y']);

      final xBuf = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final yBuf = Float64List.fromList([10.0, 20.0, 30.0, 40.0]);
      final out = Float64List(4);

      kernel([xBuf, yBuf], out);

      // x=1, y=10: 3(1) - 20 + 5 = -12
      // x=2, y=20: 3(4) - 40 + 5 = -23
      // x=3, y=30: 3(9) - 60 + 5 = -28
      // x=4, y=40: 3(16) - 80 + 5 = -27
      check(out.toList()).deepEquals([-12.0, -23.0, -28.0, -27.0]);
    });

    test('kernel with transcendentals and negation', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = sin(x) + cos(y) - exp(-x) + ln(y)
      final expr = const Sin(x) + const Cos(y) - Exp(-x) + const Ln(y);
      final kernel = expr.compileTensorKernel(['x', 'y']);

      const n = 100;
      final xBuf = Float64List(n);
      final yBuf = Float64List(n);
      final out = Float64List(n);

      for (var i = 0; i < n; i++) {
        xBuf[i] = (i + 1) * 0.1;
        yBuf[i] = (i + 1) * 0.2;
      }

      kernel([xBuf, yBuf], out);

      for (var i = 0; i < n; i++) {
        final expected =
            math.sin(xBuf[i]) +
            math.cos(yBuf[i]) -
            math.exp(-xBuf[i]) +
            math.log(yBuf[i]);
        check(out[i]).isCloseTo(expected, 1e-12);
      }
    });

    test('large scale vector buffer evaluation (N = 10000)', () {
      const x = Variable('x');
      final expr =
          (x * const RationalNumber(5, 2) + const RationalNumber(3, 2)) /
          (x + const RationalNumber(1));
      final kernel = expr.compileTensorKernel(['x']);

      const size = 10000;
      final xBuf = Float64List(size);
      final out = Float64List(size);
      for (var i = 0; i < size; i++) {
        xBuf[i] = i.toDouble();
      }

      kernel([xBuf], out);

      for (var i = 0; i < 10; i++) {
        final expected = (i * 2.5 + 1.5) / (i + 1.0);
        check(out[i]).isCloseTo(expected, 1e-12);
      }
      const lastIdx = size - 1;
      const expectedLast = (lastIdx * 2.5 + 1.5) / (lastIdx + 1.0);
      check(out[lastIdx]).isCloseTo(expectedLast, 1e-12);
    });

    test('deep expression tree and stack depth calculation', () {
      // (((((x + 1) + 2) + 3) + 4) + 5)
      Expr expr = const Variable('x');
      for (var i = 1; i <= 20; i++) {
        expr = expr + RationalNumber(i);
      }
      final kernel = expr.compileTensorKernel(['x']);

      final xBuf = Float64List.fromList([0.0, 10.0]);
      final out = Float64List(2);

      kernel([xBuf], out);
      // sum(1..20) = 210
      check(out[0]).equals(210.0);
      check(out[1]).equals(220.0);
    });

    test('unbound variable throws ArgumentError at compile time', () {
      const x = Variable('x');
      const y = Variable('y');
      final expr = x + y;

      check(() => expr.compileTensorKernel(['x'])).throws<ArgumentError>();
    });

    test(
      'kernel with expanded transcendentals, special functions, and clamping',
      () {
        const x = Variable('x');
        final expr =
            const Tan(x) +
            Asin(x * const RationalNumber(1, 2)) +
            Acos(x * const RationalNumber(1, 2)) +
            const Atan(x) +
            const Sinh(x) +
            const Cosh(x) +
            const Tanh(x) +
            const Abs(x) +
            const Sqrt(Abs(x));
        final kernel = expr.compileTensorKernel(['x']);

        final inVals = [-0.8, -0.2, 0.0, 0.2, 0.8];
        final xBuf = Float64List.fromList(inVals);
        final out = Float64List(inVals.length);
        kernel([xBuf], out);

        for (var i = 0; i < inVals.length; i++) {
          final v = inVals[i];
          final halfV = v * 0.5;
          final expected =
              math.tan(v) +
              math.asin(halfV) +
              math.acos(halfV) +
              math.atan(v) +
              (math.exp(v) - math.exp(-v)) / 2.0 +
              (math.exp(v) + math.exp(-v)) / 2.0 +
              (math.exp(2 * v) - 1.0) / (math.exp(2 * v) + 1.0) +
              v.abs() +
              math.sqrt(v.abs());
          check(out[i]).isCloseTo(expected, 1e-10);
        }

        // Test clamping on large inputs
        const largeExpr = Tanh(x);
        final largeKernel = largeExpr.compileTensorKernel(['x']);
        final largeBuf = Float64List.fromList([-50.0, -25.0, 25.0, 50.0]);
        final largeOut = Float64List(4);
        largeKernel([largeBuf], largeOut);
        check(largeOut[0]).equals(-1.0);
        check(largeOut[1]).equals(-1.0);
        check(largeOut[2]).equals(1.0);
        check(largeOut[3]).equals(1.0);
      },
    );
  });

  group('Compiler - Fast 1D and Positional Parity', () {
    test('parity between toFunction1D and compile', () {
      const x = Variable('x');
      final expr =
          Sin(x.pow(const RationalNumber(2))) + const RationalNumber(3) * x;

      final fn1D = expr.toFunction1D('x');
      final fnPos = expr.compile(['x']);

      for (final v in [0.0, 0.5, 1.0, 2.0, -1.5]) {
        check(fn1D(v)).isCloseTo(fnPos([v]), 1e-12);
      }
    });
  });
}
