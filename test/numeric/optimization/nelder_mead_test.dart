import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization/nelder_mead.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('nelderMead', () {
    test('optimizes 2D paraboloid', () {
      // f(x, y) = (x - 1)^2 + (y - 2)^2
      double f(Vector<double> v) =>
          (v[0] - 1.0) * (v[0] - 1.0) + (v[1] - 2.0) * (v[1] - 2.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final res = nelderMead(f, start, tolerance: 1e-6);

      check(res.point[0]).isCloseTo(1.0, 1e-4);
      check(res.point[1]).isCloseTo(2.0, 1e-4);
      check(res.value).isCloseTo(0.0, 1e-4);
      check(res.iterations).isGreaterThan(0);
    });

    test('optimizes Rosenbrock banana function', () {
      double rosenbrock(Vector<double> v) {
        final x = v[0];
        final y = v[1];
        final d1 = 1.0 - x;
        final d2 = y - x * x;
        return d1 * d1 + 100.0 * d2 * d2;
      }

      final start = Vector<double>.fromList([
        -1.2,
        1.0,
      ], type: DataType.float64);
      final res = nelderMead(
        rosenbrock,
        start,
        tolerance: 1e-5,
        maxIterations: 2000,
      );

      check(res.point[0]).isCloseTo(1.0, 0.02);
      check(res.point[1]).isCloseTo(1.0, 0.02);
      check(res.value).isCloseTo(0.0, 0.01);
    });

    test('stops after maxIterations', () {
      double f(Vector<double> v) => v[0] * v[0] + v[1] * v[1];
      final start = Vector<double>.fromList([
        10.0,
        10.0,
      ], type: DataType.float64);
      final res = nelderMead(f, start, maxIterations: 5);
      check(res.iterations).isLessOrEqual(5);
    });

    test(
      'does not select NaN vertex and replaces NaN vertices with finite trials',
      () {
        double f(Vector<double> v) {
          if (v[0] < 0.0) return double.nan;
          return (v[0] - 1.0) * (v[0] - 1.0) + (v[1] - 1.0) * (v[1] - 1.0);
        }

        final start = Vector<double>.fromList([
          0.1,
          0.1,
        ], type: DataType.float64);
        final limited = nelderMead(f, start, step: 0.5, maxIterations: 1);
        check(limited.value.isNaN).isFalse;

        final full = nelderMead(
          (v) => v[0] < 0.0 || v[1] < 0.0
              ? double.nan
              : (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 2.0) * (v[1] - 2.0),
          Vector<double>.fromList([0.2, 0.2], type: DataType.float64),
          step: 0.5,
        );
        check(full.point[0]).isCloseTo(2.0, 1e-3);
        check(full.point[1]).isCloseTo(2.0, 1e-3);
      },
    );

    test('validates arguments', () {
      final valid = Vector<double>.fromList([1.0], type: DataType.float64);
      check(() => nelderMead((v) => 0.0, Vector<double>.fromList([])))
          .throws<ArgumentError>();
      check(() => nelderMead((v) => 0.0, valid, step: 0.0))
          .throws<ArgumentError>();
      check(() => nelderMead((v) => 0.0, valid, tolerance: double.nan))
          .throws<ArgumentError>();
      check(() => nelderMead((v) => 0.0, valid, maxIterations: 0))
          .throws<ArgumentError>();
    });
  });
}
