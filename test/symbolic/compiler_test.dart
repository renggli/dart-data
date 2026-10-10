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
          const Constant(3.0) * x.pow(const Constant(2.0)) -
          const Constant(2.0) * y +
          const Constant(5.0);
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
          (x * const Constant(2.5) + const Constant(1.5)) /
          (x + const Constant(1.0));
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
        expr = expr + Constant(i.toDouble());
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
  });

  group('Compiler - Fast 1D and Positional Parity', () {
    test('parity between compile1D and compile', () {
      const x = Variable('x');
      final expr = Sin(x.pow(const Constant(2.0))) + const Constant(3.0) * x;

      final fn1D = expr.compile1D('x');
      final fnPos = expr.compile(['x']);

      for (final v in [0.0, 0.5, 1.0, 2.0, -1.5]) {
        check(fn1D(v)).isCloseTo(fnPos([v]), 1e-12);
      }
    });
  });
}
