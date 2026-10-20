import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:test/test.dart';

void main() {
  group('solveSystem', () {
    test('solves linear 2x2 system', () {
      // 3x + 2y - 12 = 0
      // x - y - 1 = 0
      // (3x + 2(x - 1) = 12 => 5x = 14 => x = 2.8, y = 1.8)
      final eq = <double Function(Vector<double>)>[
        (v) => 3.0 * v[0] + 2.0 * v[1] - 12.0,
        (v) => v[0] - v[1] - 1.0,
      ];
      final res = solveSystem(eq, Vector.fromList([0.0, 0.0]));
      check(res[0]).isCloseTo(2.8, 1e-9);
      check(res[1]).isCloseTo(1.8, 1e-9);
    });

    test('solves nonlinear trigonometric system', () {
      // sin(x) + cos(y) - 1.2 = 0
      // cos(x) - sin(y) - 0.2 = 0
      final eq = <double Function(Vector<double>)>[
        (v) => math.sin(v[0]) + math.cos(v[1]) - 1.2,
        (v) => math.cos(v[0]) - math.sin(v[1]) - 0.2,
      ];
      final guess = Vector.fromList([0.5, 0.5]);
      final res = solveSystem(eq, guess);
      check(eq[0](res).abs()).isLessThan(1e-9);
      check(eq[1](res).abs()).isLessThan(1e-9);
    });

    test('dimension mismatch throws ArgumentError', () {
      final eq = <double Function(Vector<double>)>[(v) => v[0]];
      check(() => solveSystem(eq, Vector.fromList([0.0, 0.0])))
          .throws<ArgumentError>();
    });

    test('supports explicit analytical Jacobian', () {
      final eq = <double Function(Vector<double>)>[
        (v) => 2.0 * v[0] + v[1] - 4.0,
        (v) => v[0] - v[1] - 2.0,
      ];
      Matrix<double> analyticalJac(Vector<double> v) => Matrix<double>.generate(
        2,
        2,
        (r, c) => switch ((r, c)) {
          (0, 0) => 2.0,
          (0, 1) => 1.0,
          (1, 0) => 1.0,
          (1, 1) => -1.0,
          _ => 0.0,
        },
      );

      final res = solveSystem(
        eq,
        Vector.fromList([0.0, 0.0]),
        jacobian: analyticalJac,
      );
      check(res[0]).isCloseTo(2.0, 1e-9);
      check(res[1]).isCloseTo(0.0, 1e-9);
    });

    test('throws StateError when Jacobian is singular', () {
      final eq = <double Function(Vector<double>)>[
        (v) => v[0] + v[1] - 1.0,
        (v) => v[0] + v[1] - 2.0,
      ];
      check(() => solveSystem(eq, Vector.fromList([0.0, 0.0])))
          .throws<StateError>();
    });

    test('converges on final iteration check', () {
      final eq = <double Function(Vector<double>)>[
        (v) => 2.0 * v[0] - 4.0,
        (v) => 3.0 * v[1] - 9.0,
      ];
      final res = solveSystem(
        eq,
        Vector.fromList([0.0, 0.0]),
        maxIterations: 1,
        tolerance: 1e-6,
      );
      check(res[0]).isCloseTo(2.0, 1e-9);
      check(res[1]).isCloseTo(3.0, 1e-9);
    });

    test('throws StateError when maxIterations exceeded', () {
      final eq = <double Function(Vector<double>)>[
        (v) => v[0] + 0.1 * math.sin(v[1]) - 100.0,
        (v) => 0.1 * math.sin(v[0]) + v[1] - 100.0,
      ];
      check(
        () => solveSystem(eq, Vector.fromList([0.0, 0.0]), maxIterations: 1),
      ).throws<StateError>();
    });
  });
}
