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
        check(sol.converged).isTrue();
      },
    );

    test('validates non-positive arguments', () {
      Vector<double> derivative(double time, Vector<double> y) => y;
      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);

      check(
        () =>
            solveOde(f: derivative, t0: 0.0, tEnd: 1.0, y0: y0, stepSize: 0.0),
      ).throws<ArgumentError>();
      check(
        () => solveOde(f: derivative, t0: 0.0, tEnd: 1.0, y0: y0, maxSteps: 0),
      ).throws<ArgumentError>();
    });

    test('convergence flag is false when maxSteps is exceeded', () {
      Vector<double> derivative(double time, Vector<double> y) => y;
      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);

      final rk4Sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 10.0,
        y0: y0,
        method: OdeMethod.rk4,
        stepSize: 0.1,
        maxSteps: 5,
      );
      check(rk4Sol.converged).isFalse();

      final rk45Sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 10.0,
        y0: y0,
        method: OdeMethod.dormandPrince45,
        maxSteps: 5,
      );
      check(rk45Sol.converged).isFalse();
    });

    test('RK45 aborts with converged=false when step cannot be reduced below minStep', () {
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([
            1000.0 * math.cos(1000.0 * time),
          ], type: DataType.float64);

      final y0 = Vector<double>.fromList([0.0], type: DataType.float64);
      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 1.0,
        y0: y0,
        method: OdeMethod.dormandPrince45,
        stepSize: 0.1,
        minStep: 0.1,
        relativeTolerance: 1e-12,
        absoluteTolerance: 1e-12,
        maxSteps: 100000,
      );
      check(sol.converged).isFalse();
      check(sol.stepCount).isLessThan(10);
    });

    test('OdeMethod.bdf2 solves stiff decay stably', () {
      // Stiff problem: dy/dt = -50y, y(0) = 1.0 => y(t) = exp(-50t)
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([-50.0 * y[0]], type: DataType.float64);

      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 0.5,
        y0: y0,
        method: OdeMethod.bdf2,
        stepSize: 0.005,
      );

      check(sol.converged).isTrue();
      check(sol.last[0]).isCloseTo(math.exp(-50.0 * 0.5), 1e-4);
    });

    test('OdeMethod.bdf2 accurately handles truncated last step', () {
      // dy/dt = -2y, y(0) = 1.0 => y(t) = exp(-2t)
      // tEnd = 0.503 with stepSize = 0.01 leaves last step h = 0.003
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([-2.0 * y[0]], type: DataType.float64);

      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 0.503,
        y0: y0,
        method: OdeMethod.bdf2,
        stepSize: 0.01,
      );

      check(sol.converged).isTrue();
      check(sol.last[0]).isCloseTo(math.exp(-2.0 * 0.503), 1e-4);
    });

    test('solveOde with tEval dense Hermite interpolation', () {
      // dy/dt = y, y(0) = 1 => y(t) = exp(t)
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([y[0]], type: DataType.float64);

      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
      final tGrid = [0.0, 0.25, 0.5, 0.75, 1.0];
      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 1.0,
        y0: y0,
        stepSize: 0.1,
        tEval: tGrid,
      );

      check(sol.t).deepEquals(tGrid);
      check(sol.y.length).equals(5);
      for (var i = 0; i < tGrid.length; i++) {
        final expected = math.exp(tGrid[i]);
        check(sol.y[i][0]).isCloseTo(expected, 1e-4);
      }
    });
  });
}
