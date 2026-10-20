import '../../linear.dart';
import '../../type.dart';
import 'optimization/brent.dart';
import 'optimization/constrained.dart';
import 'optimization/nelder_mead.dart';
import 'optimization/optimization_types.dart';
import 'optimization/quasi_newton.dart';

/// 1D and multivariate numerical optimization algorithms.

/// Minimizes a scalar-valued function [function] starting from [initialPoint]
/// or within an interval `[a, b]`.
///
/// Supports unconstrained and constrained optimization using
/// [OptimizationMethod]:
/// - [OptimizationMethod.brent]: 1D bounded minimization (Brent's method).
/// - [OptimizationMethod.nelderMead]: derivative-free simplex search for
///   unconstrained problems.
/// - [OptimizationMethod.bfgs]: quasi-Newton method with line search for smooth
///   problems.
/// - [OptimizationMethod.lbfgs]: limited-memory BFGS for higher dimensions.
///
/// When [bounds], [inequalities], or [equalities] are supplied, augmented
/// Lagrangian and box-transformation methods are automatically applied. For 1D
/// problems, [a] and [b] can be provided to specify the bounded interval.
///
/// ```dart
/// final min = minimize(
///   (v) => (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0),
///   initialPoint: Vector<double>.fromList([0.0, 0.0]),
/// );
/// print(min.point); // Vector([2.0, 3.0])
/// ```
OptimizationResult minimize(
  double Function(Vector<double>) function, {
  Vector<double>? initialPoint,
  OptimizationMethod? method,
  Vector<double> Function(Vector<double>)? gradient,
  List<BoxBound>? bounds,
  List<double Function(Vector<double>)>? inequalities,
  List<double Function(Vector<double>)>? equalities,
  double? a,
  double? b,
  double tolerance = 1e-8,
  int maxIterations = 500,
  double step = 1.0,
  int memorySize = 7,
}) {
  if (tolerance <= 0) {
    throw ArgumentError('Tolerance must be positive: $tolerance');
  }
  if (maxIterations <= 0) {
    throw ArgumentError('Max iterations must be positive: $maxIterations');
  }

  var init = initialPoint;
  var bnds = bounds;
  var resolvedMethod = method;

  if (init == null) {
    if (a != null && b != null) {
      init = Vector<double>.fromList([(a + b) / 2.0], type: DataType.float64);
      bnds ??= [BoxBound(lower: a, upper: b)];
      resolvedMethod ??= OptimizationMethod.brent;
    } else {
      throw ArgumentError(
        'Either initialPoint or both interval bounds a and b must be provided.',
      );
    }
  }

  if (init.length == 0) {
    throw ArgumentError('Initial point cannot be empty.');
  }

  final hasConstraints =
      (bnds != null && bnds.isNotEmpty) ||
      (inequalities != null && inequalities.isNotEmpty) ||
      (equalities != null && equalities.isNotEmpty);

  resolvedMethod ??= hasConstraints
      ? OptimizationMethod.bfgs
      : OptimizationMethod.nelderMead;

  if (resolvedMethod == OptimizationMethod.brent) {
    final low =
        a ??
        (bnds != null && bnds.isNotEmpty ? bnds[0].lower : null) ??
        (init[0] - 1.0);
    final high =
        b ??
        (bnds != null && bnds.isNotEmpty ? bnds[0].upper : null) ??
        (init[0] + 1.0);
    final res = brentMinimize(
      (x) => function(Vector<double>.fromList([x], type: DataType.float64)),
      a: low,
      b: high,
      tolerance: tolerance,
      maxIterations: maxIterations,
    );
    return OptimizationResult(
      point: Vector<double>.fromList([res.point], type: DataType.float64),
      value: res.value,
      iterations: res.iterations,
      converged: true,
    );
  }

  if (hasConstraints) {
    final res = minimizeConstrained(
      function,
      init,
      gradient: gradient,
      bounds: bnds,
      inequalities: inequalities,
      equalities: equalities,
      tolerance: tolerance,
      maxIterations: maxIterations,
    );
    return OptimizationResult(
      point: res.point,
      value: res.value,
      iterations: res.iterations,
      gradientNorm: res.gradientNorm,
      converged: res.converged,
    );
  }

  switch (resolvedMethod) {
    case OptimizationMethod.nelderMead:
      final res = nelderMead(
        function,
        init,
        step: step,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      return OptimizationResult(
        point: res.point,
        value: res.value,
        iterations: res.iterations,
        converged: true,
      );
    case OptimizationMethod.bfgs:
      final res = bfgs(
        function,
        init,
        gradient: gradient,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      return OptimizationResult(
        point: res.point,
        value: res.value,
        iterations: res.iterations,
        gradientNorm: res.gradientNorm,
        converged: res.gradientNorm <= tolerance,
      );
    case OptimizationMethod.lbfgs:
      final res = lbfgs(
        function,
        init,
        gradient: gradient,
        memorySize: memorySize,
        tolerance: tolerance,
        maxIterations: maxIterations,
      );
      return OptimizationResult(
        point: res.point,
        value: res.value,
        iterations: res.iterations,
        gradientNorm: res.gradientNorm,
        converged: res.gradientNorm <= tolerance,
      );
    case OptimizationMethod.brent:
      throw StateError('Unreachable');
  }
}
