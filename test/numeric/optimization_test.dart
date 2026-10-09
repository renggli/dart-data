import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('Optimization Algorithms', () {
    test('1D Brent minimization of quadratic function', () {
      // f(x) = (x - 3)^2 + 5, minimum at x = 3, f(3) = 5
      double f(double x) => (x - 3.0) * (x - 3.0) + 5.0;

      final result = brentMinimize(f, a: 0.0, b: 6.0);
      expect(result.point, closeTo(3.0, 1e-6));
      expect(result.value, closeTo(5.0, 1e-6));
    });

    test('1D Brent minimization with Expr', () {
      const x = Variable('x');
      // f(x) = (x - 2)^2 - 4
      final f = (x - const Constant(2.0)).pow(2) - const Constant(4.0);

      final result = brentMinimize(f, a: -1.0, b: 5.0, variable: 'x');
      expect(result.point, closeTo(2.0, 1e-6));
      expect(result.value, closeTo(-4.0, 1e-6));
    });

    test('Nelder-Mead simplex optimization on Rosenbrock banana function', () {
      // Rosenbrock: f(x, y) = (1 - x)^2 + 100*(y - x^2)^2
      // Global minimum at (1, 1), f(1, 1) = 0
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
      final result = nelderMead(
        rosenbrock,
        start,
        tolerance: 1e-5,
        maxIterations: 2000,
      );

      expect(result.point[0], closeTo(1.0, 0.02));
      expect(result.point[1], closeTo(1.0, 0.02));
      expect(result.value, closeTo(0.0, 0.01));
    });

    test('BFGS optimization on quadratic bowl', () {
      // f(x, y) = (x - 2)^2 + 3*(y + 1)^2 + 4
      // Minimum at (2, -1) with value 4
      double f(Vector<double> v) =>
          (v[0] - 2.0) * (v[0] - 2.0) + 3.0 * (v[1] + 1.0) * (v[1] + 1.0) + 4.0;

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = bfgs(f, start);

      expect(result.point[0], closeTo(2.0, 1e-5));
      expect(result.point[1], closeTo(-1.0, 1e-5));
      expect(result.value, closeTo(4.0, 1e-5));
    });

    test('BFGS seamlessly accepting symbolic Expr', () {
      const x = Variable('x');
      const y = Variable('y');
      // f(x, y) = x^2 + y^2 - 4*x - 6*y + 13 = (x-2)^2 + (y-3)^2
      final f =
          x.pow(2) +
          y.pow(2) -
          const Constant(4.0) * x -
          const Constant(6.0) * y +
          const Constant(13.0);

      final start = Vector<double>.fromList([0.0, 0.0], type: DataType.float64);
      final result = bfgs(f, start, variables: ['x', 'y']);

      expect(result.point[0], closeTo(2.0, 1e-5));
      expect(result.point[1], closeTo(3.0, 1e-5));
      expect(result.value, closeTo(0.0, 1e-5));
    });

    test('L-BFGS optimization on 3D quadratic form', () {
      // f(x, y, z) = (x-1)^2 + 2*(y-2)^2 + 3*(z-3)^2
      double f(Vector<double> v) =>
          (v[0] - 1.0) * (v[0] - 1.0) +
          2.0 * (v[1] - 2.0) * (v[1] - 2.0) +
          3.0 * (v[2] - 3.0) * (v[2] - 3.0);

      final start = Vector<double>.fromList([
        0.0,
        0.0,
        0.0,
      ], type: DataType.float64);
      final result = lbfgs(f, start, memorySize: 5);

      expect(result.point[0], closeTo(1.0, 1e-5));
      expect(result.point[1], closeTo(2.0, 1e-5));
      expect(result.point[2], closeTo(3.0, 1e-5));
      expect(result.value, closeTo(0.0, 1e-5));
    });
  });
}
