import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization/constrained.dart';
import 'package:data/src/numeric/optimization/optimization_types.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('minimizeConstrained', () {
    test('1D scalar with two-sided box bounds', () {
      // f(x) = (x - 5)^2 + 2, unconstrained min at x = 5.
      // With bounds [0, 2], constrained min at x = 2, f(2) = 11.
      double f(Vector<double> v) => (v[0] - 5.0) * (v[0] - 5.0) + 2.0;

      final start = Vector<double>.fromList([0.0], type: DataType.float64);
      final res = minimizeConstrained(
        f,
        start,
        bounds: const [BoxBound(lower: 0.0, upper: 2.0)],
      );

      check(res.point[0]).isCloseTo(2.0, 1e-4);
      check(res.value).isCloseTo(11.0, 1e-4);
      check(res.converged).isTrue();
    });

    test('2D quadratic with active box bounds', () {
      // f(x, y) = (x - 2)^2 + (y - 3)^2, min at (2, 3).
      // Bounds [0, 1] x [0, 1] -> min at (1, 1), value = 5.
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final res = minimizeConstrained(
        f,
        start,
        bounds: const [
          BoxBound(lower: 0.0, upper: 1.0),
          BoxBound(lower: 0.0, upper: 1.0),
        ],
      );

      check(res.point[0]).isCloseTo(1.0, 1e-4);
      check(res.point[1]).isCloseTo(1.0, 1e-4);
      check(res.value).isCloseTo(5.0, 1e-4);
    });

    test('augmented Lagrangian with equality and inequality constraints', () {
      // f(x, y) = x^2 + y^2
      // Subject to x + y = 3 and x <= 1
      double f(Vector<double> v) => v[0] * v[0] + v[1] * v[1];
      double eq(Vector<double> v) => v[0] + v[1] - 3.0;
      double ineq(Vector<double> v) => v[0] - 1.0; // x - 1 <= 0 => x <= 1

      final start = Vector<double>.fromList([0.5, 2.5], type: DataType.float64);
      final res = minimizeConstrained(
        f,
        start,
        equalities: [eq],
        inequalities: [ineq],
      );

      check(res.point[0]).isCloseTo(1.0, 1e-2);
      check(res.point[1]).isCloseTo(2.0, 1e-2);
      check(res.value).isCloseTo(5.0, 1e-2);
      check(eq(res.point).abs()).isLessThan(1e-2);
    });

    test('argument validation', () {
      final start = Vector<double>.fromList([1.0], type: DataType.float64);

      check(
        () => minimizeConstrained(
          (v) => 0.0,
          Vector<double>.fromList([], type: DataType.float64),
        ),
      ).throws<ArgumentError>();
      check(() => minimizeConstrained((v) => 0.0, start, tolerance: 0.0))
          .throws<ArgumentError>();
      check(() => minimizeConstrained((v) => 0.0, start, maxIterations: 0))
          .throws<ArgumentError>();
      check(
        () => minimizeConstrained(
          (v) => 0.0,
          start,
          bounds: const [BoxBound(), BoxBound()],
        ),
      ).throws<ArgumentError>();
    });
  });
}
