import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

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
        check(sol.converged).isTrue;
      },
    );

    test('validates arguments including empty initial state', () {
      Vector<double> derivative(double time, Vector<double> y) => y;
      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);

      check(
        () =>
            solveOde(f: derivative, t0: 0.0, tEnd: 1.0, y0: y0, stepSize: 0.0),
      ).throws<ArgumentError>();
      check(
        () => solveOde(f: derivative, t0: 0.0, tEnd: 1.0, y0: y0, maxSteps: 0),
      ).throws<ArgumentError>();
      check(
        () => solveOde(
          f: derivative,
          t0: 0.0,
          tEnd: 1.0,
          y0: Vector<double>.fromList([]),
        ),
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
      check(rk4Sol.converged).isFalse;

      final rk45Sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 10.0,
        y0: y0,
        method: OdeMethod.dormandPrince45,
        maxSteps: 5,
      );
      check(rk45Sol.converged).isFalse;
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
      check(sol.converged).isFalse;
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

      check(sol.converged).isTrue;
      check(sol.last[0]).isCloseTo(math.exp(-50.0 * 0.5), 1e-4);
    });

    test('OdeMethod.bdf2 reports converged: true when trial steps are rejected and halved', () {
      // Non-linear problem dy/dt = y^2, y(0) = 1.0 => y(t) = 1 / (1 - t)
      // With stepSize = 0.45, startup step fails Newton and halves adaptively to reach 0.5
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([y[0] * y[0]], type: DataType.float64);

      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 0.5,
        y0: y0,
        method: OdeMethod.bdf2,
        stepSize: 0.45,
      );

      check(sol.converged).isTrue;
      check(sol.last[0]).isCloseTo(1.0 / (1.0 - 0.5), 1e-3);
    });

    test(
      'OdeMethod.bdf2 aborts with converged: false when minStep is exhausted',
      () {
        Vector<double> derivative(double time, Vector<double> y) =>
            Vector<double>.fromList([y[0] * y[0]], type: DataType.float64);

        final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
        final sol = solveOde(
          f: derivative,
          t0: 0.0,
          tEnd: 0.5,
          y0: y0,
          method: OdeMethod.bdf2,
          stepSize: 0.45,
          minStep: 0.45,
        );

        check(sol.converged).isFalse;
      },
    );

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

      check(sol.converged).isTrue;
      check(sol.last[0]).isCloseTo(math.exp(-2.0 * 0.503), 1e-4);
    });

    test('OdeMethod.bdf2 adaptively controls step size based on tolerance', () {
      Vector<double> derivative(double time, Vector<double> y) =>
          Vector<double>.fromList([-y[0]], type: DataType.float64);

      final y0 = Vector<double>.fromList([1.0], type: DataType.float64);
      final solLoose = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 2.0,
        y0: y0,
        method: OdeMethod.bdf2,
        relativeTolerance: 1e-2,
        absoluteTolerance: 1e-3,
      );
      final solTight = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 2.0,
        y0: y0,
        method: OdeMethod.bdf2,
        relativeTolerance: 1e-6,
        absoluteTolerance: 1e-8,
      );

      check(solLoose.converged).isTrue;
      check(solTight.converged).isTrue;
      check(solLoose.stepCount).isLessThan(solTight.stepCount);
      check(solTight.last[0]).isCloseTo(math.exp(-2.0), 1e-4);
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

      // Descending t (tEnd < t0) with tEval dense Hermite interpolation
      final tGridDesc = [1.0, 0.75, 0.5, 0.25, 0.0];
      final solDesc = solveOde(
        f: derivative,
        t0: 1.0,
        tEnd: 0.0,
        y0: Vector<double>.fromList([math.exp(1.0)], type: DataType.float64),
        stepSize: 0.1,
        tEval: tGridDesc,
      );
      check(solDesc.t).deepEquals(tGridDesc);
      for (var i = 0; i < tGridDesc.length; i++) {
        check(solDesc.y[i][0]).isCloseTo(math.exp(tGridDesc[i]), 1e-4);
      }
    });

    test(
      'RK45 shrinks truncated final step below minStep without aborting',
      () {
        // Rapid change near tEnd where the final truncated step < minStep needs
        // step reduction to meet tight tolerance.
        Vector<double> derivative(double time, Vector<double> y) =>
            Vector<double>.fromList([
              50.0 * math.cos(50.0 * time),
            ], type: DataType.float64);

        final y0 = Vector<double>.fromList([0.0], type: DataType.float64);
        final sol = solveOde(
          f: derivative,
          t0: 0.0,
          tEnd: 0.1005,
          y0: y0,
          method: OdeMethod.dormandPrince45,
          stepSize: 0.1,
          minStep: 0.002,
          relativeTolerance: 1e-9,
          absoluteTolerance: 1e-9,
        );
        check(sol.converged).isTrue;
        check(sol.last[0]).isCloseTo(math.sin(50.0 * 0.1005), 1e-6);
      },
    );

    test('RK45 rejects NaN trial steps and marks converged false', () {
      // dy/dt = sqrt(y) with y(0) = 0.05. If step is too big, y < 0 produces NaN
      Vector<double> derivative(double time, Vector<double> y) {
        if (y[0] < 0.0) {
          return Vector<double>.fromList([double.nan], type: DataType.float64);
        }
        return Vector<double>.fromList([
          -100.0 * math.sqrt(y[0]),
        ], type: DataType.float64);
      }

      final sol = solveOde(
        f: derivative,
        t0: 0.0,
        tEnd: 1.0,
        y0: Vector<double>.fromList([0.05], type: DataType.float64),
        method: OdeMethod.dormandPrince45,
        stepSize: 0.1,
        minStep: 0.05,
      );
      check(sol.converged).isFalse;
    });

    test(
      'handles tiny intervals, large time offsets, and exact final tEnd',
      () {
        Vector<double> expDecay(double t, Vector<double> y) =>
            Vector<double>.fromList([-y[0]], type: DataType.float64);

        // Tiny interval smaller than absolute 1e-12
        final tiny = solveOde(
          f: expDecay,
          t0: 0.0,
          tEnd: 1e-13,
          y0: Vector<double>.fromList([1.0], type: DataType.float64),
          stepSize: 1e-13,
          minStep: 1e-15,
        );
        check(tiny.converged).isTrue;
        check(tiny.t.last).equals(1e-13);
        check(tiny.last[0]).isCloseTo(math.exp(-1e-13), 1e-12);

        // Large time offset
        const tStart = 1e6;
        const tStop = 1e6 + 0.5;
        for (final method in OdeMethod.values) {
          final sol = solveOde(
            f: expDecay,
            t0: tStart,
            tEnd: tStop,
            y0: Vector<double>.fromList([1.0], type: DataType.float64),
            method: method,
            stepSize: 0.05,
          );
          check(sol.converged).isTrue;
          check(sol.t.last).equals(tStop);
          check(sol.last[0]).isCloseTo(math.exp(-0.5), 1e-4);
        }
      },
    );

    test('RK4 aborts with converged=false on non-finite state', () {
      final sol = solveOde(
        f: (t, y) => Vector<double>.fromList([
          if (y[0] > 2.0) double.nan else 100.0,
        ], type: DataType.float64),
        t0: 0.0,
        tEnd: 1.0,
        y0: Vector<double>.fromList([0.0], type: DataType.float64),
        method: OdeMethod.rk4,
        stepSize: 0.1,
      );
      check(sol.converged).isFalse;
    });

    test('BDF2 handles truncated first step, nonlinear Jacobian refresh, and singular recovery', () {
      // Truncated first step (tEnd < stepSize)
      final shortSol = solveOde(
        f: (t, y) => Vector<double>.fromList([-y[0]], type: DataType.float64),
        t0: 0.0,
        tEnd: 0.005,
        y0: Vector<double>.fromList([1.0], type: DataType.float64),
        method: OdeMethod.bdf2,
        stepSize: 0.1,
      );
      check(shortSol.converged).isTrue;
      check(shortSol.t.last).equals(0.005);

      // Strongly nonlinear problem requiring Newton Jacobian refresh (iter >= 3)
      final nonLin = solveOde(
        f: (t, y) => Vector<double>.fromList([
          -50.0 * y[0] * y[0] * y[0],
        ], type: DataType.float64),
        t0: 0.0,
        tEnd: 0.5,
        y0: Vector<double>.fromList([1.0], type: DataType.float64),
        method: OdeMethod.bdf2,
        stepSize: 0.1,
        relativeTolerance: 1e-8,
        absoluteTolerance: 1e-10,
      );
      check(nonLin.converged).isTrue;
      check(nonLin.last[0]).isCloseTo(1.0 / math.sqrt(1.0 + 100.0 * 0.5), 1e-3);

      // Non-finite derivative mid-step recovers or aborts cleanly
      final badJac = solveOde(
        f: (t, y) => Vector<double>.fromList([
          if (t > 0.2) double.nan else -y[0],
        ], type: DataType.float64),
        t0: 0.0,
        tEnd: 0.5,
        y0: Vector<double>.fromList([1.0], type: DataType.float64),
        method: OdeMethod.bdf2,
        stepSize: 0.05,
        minStep: 0.02,
      );
      check(badJac.converged).isFalse;
    });

    test(
      'Hermite interpolation handles NaN tEval and single-step solution',
      () {
        final singleNaN = solveOde(
          f: (t, y) => y,
          t0: 1.0,
          tEnd: 1.0,
          y0: Vector<double>.fromList([2.0], type: DataType.float64),
          tEval: [double.nan, 1.0],
        );
        check(singleNaN.y[0][0].isNaN).isTrue;
        check(singleNaN.y[1][0]).equals(2.0);

        final multiNaN = solveOde(
          f: (t, y) => Vector<double>.fromList([y[0]], type: DataType.float64),
          t0: 0.0,
          tEnd: 0.1,
          y0: Vector<double>.fromList([1.0], type: DataType.float64),
          tEval: [double.nan, 0.05],
        );
        check(multiNaN.y[0][0].isNaN).isTrue;
        check(multiNaN.y[1][0]).isCloseTo(math.exp(0.05), 1e-5);
      },
    );
  });
}
