import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('solveOde', () {
    test('solveOde with OdeMethod.rk4 on exponential decay dy/dt = -2y', () {
      // dy/dt = -2y, y(0) = 1.0 => y(t) = exp(-2t)
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([-2.0 * y[0]], type: DataType.float64);

      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 1.0,
        y0: y0,
        method: OdeMethod.rk4,
        stepSize: 0.01,
      );

      check(sol.last[0]).isCloseTo(math.exp(-2.0), 1e-5);
    });

    test(
      'solveOde default (OdeMethod.dormandPrince45) on harmonic oscillator',
      () {
        // y' = v, v' = -y
        // Initial: y(0) = 0, v(0) = 1 => y(t) = sin(t), v(t) = cos(t)
        Vector<double> derivative(double time, Vector<double> state) {
          final y = state[0];
          final velocity = state[1];
          return Vector<double>.fromList([
            velocity,
            -y,
          ], type: DataType.float64);
        }

        final y0 = Vector<double>.fromList([0.0, 1.0], type: DataType.float64);
        final sol = solveOde(
          f: derivative,
          t0: 0.0,
          tEnd: 2.0 * math.pi,
          y0: y0,
          relativeTolerance: 1e-7,
          absoluteTolerance: 1e-9,
        );

        // At t = 2*pi: y(2*pi) = 0, v(2*pi) = 1
        check(sol.last[0]).isCloseTo(0.0, 1e-5);
        check(sol.last[1]).isCloseTo(1.0, 1e-5);

        // Test intermediate point t = pi/2
        final halfPiIdx = sol.t.length ~/ 4;
        final tMid = sol.t[halfPiIdx];
        check(sol.y[halfPiIdx][0]).isCloseTo(math.sin(tMid), 1e-4);
        check(sol.y[halfPiIdx][1]).isCloseTo(math.cos(tMid), 1e-4);
      },
    );
  });
}
