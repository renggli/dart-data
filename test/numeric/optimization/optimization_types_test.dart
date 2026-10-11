import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/src/numeric/optimization/optimization_types.dart';
import 'package:test/test.dart';

void main() {
  group('OptimizationMethod', () {
    test('values enumeration', () {
      check(OptimizationMethod.values).contains(OptimizationMethod.brent);
      check(OptimizationMethod.values).contains(OptimizationMethod.nelderMead);
      check(OptimizationMethod.values).contains(OptimizationMethod.bfgs);
      check(OptimizationMethod.values).contains(OptimizationMethod.lbfgs);
    });
  });

  group('BoxBound', () {
    test('default constructor creates unbounded box', () {
      const bound = BoxBound();
      check(bound.lower).isNull();
      check(bound.upper).isNull();
    });

    test('equality and hashCode', () {
      const b1 = BoxBound(lower: -1.0, upper: 2.0);
      const b2 = BoxBound(lower: -1.0, upper: 2.0);
      const b3 = BoxBound(lower: 0.0, upper: 2.0);

      check(b1).equals(b2);
      check(b1.hashCode).equals(b2.hashCode);
      check(b1 == b3).isFalse();
    });

    test('toString formatting', () {
      const bound = BoxBound(lower: -2.5, upper: 3.5);
      final str = bound.toString();
      check(str).contains('BoxBound');
      check(str).contains('lower: -2.5');
      check(str).contains('upper: 3.5');
    });
  });

  group('OptimizationResult', () {
    test('properties and 1D accessor', () {
      final point = Vector<double>.fromList([3.14]);
      final result = OptimizationResult(
        point: point,
        value: 42.0,
        iterations: 15,
        gradientNorm: 1e-5,
        converged: true,
      );

      check(result.point).equals(point);
      check(result.point1D).isCloseTo(3.14, 1e-12);
      check(result.value).equals(42.0);
      check(result.iterations).equals(15);
      check(result.gradientNorm).equals(1e-5);
      check(result.converged).isTrue();
    });

    test('toString formatting', () {
      final point = Vector<double>.fromList([1.0]);
      final result = OptimizationResult(
        point: point,
        value: 2.5,
        iterations: 10,
        converged: true,
      );
      check(result.toString()).contains('OptimizationResult');
      check(result.toString()).contains('value: 2.5');
    });
  });
}
