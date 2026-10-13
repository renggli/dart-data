import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  const x = Variable('x');
  const y = Variable('y');
  const z = Variable('z');

  group('Compiler - compileTensorKernel Execution', () {
    test('linearized arithmetic kernel', () {
      final expr =
          const RationalNumber(3) * x.pow(const RationalNumber(2)) -
          const RationalNumber(2) * y +
          const RationalNumber(5);
      final kernel = expr.compileTensorKernel(['x', 'y']);

      final xBuf = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final yBuf = Float64List.fromList([10.0, 20.0, 30.0, 40.0]);
      final out = Float64List(4);

      kernel([xBuf, yBuf], out);

      check(out.toList()).deepEquals([-12.0, -23.0, -28.0, -27.0]);
    });

    test('kernel with transcendentals and negation', () {
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
      Expr expr = const Variable('x');
      for (var i = 1; i <= 20; i++) {
        expr = expr + RationalNumber(i);
      }
      final kernel = expr.compileTensorKernel(['x']);

      final xBuf = Float64List.fromList([0.0, 10.0]);
      final out = Float64List(2);

      kernel([xBuf], out);
      check(out[0]).equals(210.0);
      check(out[1]).equals(220.0);
    });

    test('unbound variable throws ArgumentError at compile time', () {
      final expr = x + y;
      check(() => expr.compileTensorKernel(['x'])).throws<ArgumentError>();
    });

    test(
      'kernel with expanded transcendentals, special functions, and clamping',
      () {
        final expr =
            const Tan(x) +
            Asin(x * const RationalNumber(1, 2)) +
            Acos(x * const RationalNumber(1, 2)) +
            const Atan(x) +
            const Sinh(x) +
            const Cosh(x) +
            const Tanh(x) +
            const Abs(x) +
            const Pow(Abs(x), RationalNumber(1, 2));
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

    test('10,000 iterations tight loop execution with memory and numerical stability', () {
      // f(x, y, z) = sin(x) * cos(y) + exp(x - y) - ln(z) + (x * y) / (z + 1)
      final expr =
          (const Sin(x) * const Cos(y)) +
          Exp(x - y) -
          const Ln(z) +
          ((x * y) / (z + const RationalNumber(1)));

      final kernel = expr.compileTensorKernel(['x', 'y', 'z']);

      const bufferLen = 64;
      final xBuf = Float64List(bufferLen);
      final yBuf = Float64List(bufferLen);
      final zBuf = Float64List(bufferLen);
      final outBuf = Float64List(bufferLen);
      final expectedBuf = Float64List(bufferLen);

      for (var i = 0; i < bufferLen; i++) {
        final xVal = (i + 1) * 0.05;
        final yVal = (i + 1) * 0.03;
        final zVal = (i + 1) * 0.1 + 1.0;
        xBuf[i] = xVal;
        yBuf[i] = yVal;
        zBuf[i] = zVal;

        expectedBuf[i] =
            math.sin(xVal) * math.cos(yVal) +
            math.exp(xVal - yVal) -
            math.log(zVal) +
            (xVal * yVal) / (zVal + 1.0);
      }

      final stopwatch = Stopwatch()..start();
      const iterations = 10000;
      for (var iter = 0; iter < iterations; iter++) {
        kernel([xBuf, yBuf, zBuf], outBuf);
      }
      stopwatch.stop();

      for (var i = 0; i < bufferLen; i++) {
        check(outBuf[i]).isCloseTo(expectedBuf[i], 1e-12);
      }

      check(stopwatch.elapsedMilliseconds).isLessThan(2000);

      // Phase B: dynamically mutating inputs
      for (var iter = 0; iter < 1000; iter++) {
        final factor = (iter % 100 + 1) * 0.01;
        xBuf[0] = factor;
        yBuf[0] = factor * 0.5;
        zBuf[0] = factor + 1.5;

        kernel([xBuf, yBuf, zBuf], outBuf);

        final expected =
            math.sin(xBuf[0]) * math.cos(yBuf[0]) +
            math.exp(xBuf[0] - yBuf[0]) -
            math.log(zBuf[0]) +
            (xBuf[0] * yBuf[0]) / (zBuf[0] + 1.0);
        check(outBuf[0]).isCloseTo(expected, 1e-12);
      }
    });

    test('kernel execution with deeply nested unary and stack operations', () {
      final expr =
          const Exp(Neg(Neg(Neg(Sin(Cos(Sin(x))))))) +
          x.pow(const RationalNumber(2)) -
          x.pow(const RationalNumber(3)) +
          x.pow(const RationalNumber(4));

      final kernel = expr.compileTensorKernel(['x']);

      final xBuf = Float64List.fromList([0.1, 0.5, 1.0, 1.5, 2.0]);
      final outBuf = Float64List(5);

      for (var iter = 0; iter < 1000; iter++) {
        kernel([xBuf], outBuf);
      }

      for (var i = 0; i < 5; i++) {
        final xVal = xBuf[i];
        final inner = -math.sin(math.cos(math.sin(xVal)));
        final expected =
            math.exp(inner) +
            math.pow(xVal, 2) -
            math.pow(xVal, 3) +
            math.pow(xVal, 4);
        check(outBuf[i]).isCloseTo(expected, 1e-12);
      }
    });

    test(
      'Sinh and Cosh tensor kernel evaluate correctly across magnitude tiers',
      () {
        const exprSinh = Sinh(x);
        const exprCosh = Cosh(x);
        final sinhKernel = exprSinh.compileTensorKernel(['x']);
        final coshKernel = exprCosh.compileTensorKernel(['x']);

        // Tier 1: normal magnitudes [0.0 to 20.0]
        final midInputs = [0.0, 1.0, 5.0, 10.0, 15.0, 20.0];
        final midBuf = Float64List.fromList(midInputs);
        final sinhMidOut = Float64List(midInputs.length);
        final coshMidOut = Float64List(midInputs.length);

        sinhKernel([midBuf], sinhMidOut);
        coshKernel([midBuf], coshMidOut);

        for (var i = 0; i < midInputs.length; i++) {
          final v = midInputs[i];
          final expV = math.exp(v);
          final expNegV = math.exp(-v);
          check(sinhMidOut[i]).isCloseTo((expV - expNegV) / 2.0, 1e-9);
          check(coshMidOut[i]).isCloseTo((expV + expNegV) / 2.0, 1e-9);
        }

        // Tier 3: IEEE 754 overflow tier (> 710)
        final overflowInputs = [800.0, 1000.0];
        final overflowBuf = Float64List.fromList(overflowInputs);
        final sinhOverflowOut = Float64List(overflowInputs.length);
        final coshOverflowOut = Float64List(overflowInputs.length);

        sinhKernel([overflowBuf], sinhOverflowOut);
        coshKernel([overflowBuf], coshOverflowOut);

        for (var i = 0; i < overflowInputs.length; i++) {
          check(sinhOverflowOut[i]).equals(double.infinity);
          check(coshOverflowOut[i]).equals(double.infinity);
        }
      },
    );

    test('high-throughput composite tensor kernel stress execution', () {
      final composite =
          (const Tanh(x) * Cosh(x / const RationalNumber(4))) +
          const Pow(Add(Abs(x), RationalNumber(1)), RationalNumber(1, 2)) -
          const Atan(x) +
          const Tan(Mul(Sin(x), RationalNumber(1, 2)));

      final kernel = composite.compileTensorKernel(['x']);

      const bufferSize = 128;
      final xBuf = Float64List(bufferSize);
      final outBuf = Float64List(bufferSize);
      final expectedBuf = Float64List(bufferSize);

      for (var i = 0; i < bufferSize; i++) {
        final t = -10.0 + (20.0 / (bufferSize - 1)) * i;
        xBuf[i] = t;

        final ch = (math.exp(t / 4.0) + math.exp(-t / 4.0)) / 2.0;
        final th = t > 20.0
            ? 1.0
            : (t < -20.0
                  ? -1.0
                  : (math.exp(2 * t) - 1) / (math.exp(2 * t) + 1));
        final s = math.sqrt(t.abs() + 1.0);
        final at = math.atan(t);
        final tn = math.tan(math.sin(t) / 2.0);
        expectedBuf[i] = th * ch + s - at + tn;
      }

      final stopwatch = Stopwatch()..start();
      const iterations = 10000;
      for (var iter = 0; iter < iterations; iter++) {
        kernel([xBuf], outBuf);
      }
      stopwatch.stop();

      for (var i = 0; i < bufferSize; i++) {
        check(outBuf[i]).isCloseTo(expectedBuf[i], 1e-9);
      }

      check(stopwatch.elapsedMilliseconds).isLessThan(2500);
    });

    test('tensor kernel large buffer throughput and edge conditions', () {
      final kernel = Expr.parse('sqrt(x) + pow(x, 2)')
          .compileTensorKernel(['x']);
      const size = 10000;
      final input = Float64List(size);
      for (var i = 0; i < size; i++) {
        input[i] = (i % 100).toDouble();
      }
      final output = Float64List(size);
      kernel([input], output);

      for (var i = 0; i < 100; i++) {
        final expected = math.sqrt(i.toDouble()) + (i * i).toDouble();
        check(output[i]).isCloseTo(expected, 1e-12);
      }

      // Zero-length buffer handling
      final emptyIn = Float64List(0);
      final emptyOut = Float64List(0);
      kernel([emptyIn], emptyOut);
      check(emptyOut.length).equals(0);
    });
  });

  group('Compiler - Fast 1D, Positional, and Vector Parity', () {
    test('parity between toFunction1D and compile', () {
      final expr =
          Sin(x.pow(const RationalNumber(2))) + const RationalNumber(3) * x;

      final fn1D = expr.toFunction1D('x');
      final fnPos = expr.compile(['x']);

      for (final v in [0.0, 0.5, 1.0, 2.0, -1.5]) {
        check(fn1D(v)).isCloseTo(fnPos([v]), 1e-12);
      }
    });

    test('multi-variable compile() and toVectorFunction()', () {
      final fPos = Expr.parse('sqrt(pow(x, 2) + pow(y, 2))')
          .compile(['x', 'y']);
      check(fPos([3.0, 4.0])).equals(5.0);
      check(fPos([5.0, 12.0])).equals(13.0);
      check(fPos([-3.0, -4.0])).equals(5.0);

      final fVec = Expr.parse('pow(x, y)').toVectorFunction(['x', 'y']);
      check(fVec(Vector.fromList([2.0, 3.0]))).equals(8.0);
      check(fVec(Vector.fromList([3.0, 2.0]))).equals(9.0);
      check(fVec(Vector.fromList([4.0, 0.5]))).equals(2.0);
    });

    test('toFunction1D JIT compilation for square roots and powers', () {
      final fSqrt = Expr.parse('sqrt(x)').toFunction1D('x');
      check(fSqrt(0.0)).equals(0.0);
      check(fSqrt(1.0)).equals(1.0);
      check(fSqrt(4.0)).equals(2.0);
      check(fSqrt(9.0)).equals(3.0);
      check(fSqrt(16.0)).equals(4.0);
      check(fSqrt(-1.0).isNaN).isTrue();

      final fSqrtSqrt = Expr.parse('sqrt(sqrt(x))').toFunction1D('x');
      check(fSqrtSqrt(16.0)).equals(2.0);
      check(fSqrtSqrt(81.0)).equals(3.0);

      final fSqrtX2 = Expr.parse('sqrt(pow(x, 2))').toFunction1D('x');
      check(fSqrtX2(5.0)).equals(5.0);
      check(fSqrtX2(-5.0)).equals(5.0);

      final fPowNeg = Expr.parse('pow(x, -2)').toFunction1D('x');
      check(fPowNeg(2.0)).equals(0.25);
      check(fPowNeg(4.0)).equals(0.0625);
    });
  });
}
