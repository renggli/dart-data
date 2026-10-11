import '../../../linear.dart';

/// Method used for numerical optimization.
enum OptimizationMethod {
  /// 1D Brent minimization combining golden section search and parabolic interpolation.
  brent,

  /// Derivative-free Nelder-Mead downhill simplex algorithm.
  nelderMead,

  /// Quasi-Newton Broyden-Fletcher-Goldfarb-Shanno (BFGS) algorithm.
  bfgs,

  /// Limited-memory BFGS (L-BFGS) algorithm for high-dimensional problems.
  lbfgs,
}

/// Result of a numerical optimization.
class OptimizationResult {
  /// Constructs an optimization result.
  const new({
    required this.point,
    required this.value,
    required this.iterations,
    this.gradientNorm,
    this.converged = true,
  });

  /// The optimal parameter vector found by the optimizer.
  final Vector<double> point;

  /// The objective function value at [point].
  final double value;

  /// Number of iterations executed.
  final int iterations;

  /// The norm of the gradient at [point], if computed.
  final double? gradientNorm;

  /// Whether the optimizer converged within tolerance.
  final bool converged;

  /// Convenience getter returning the first coordinate `point[0]`, useful for 1D problems.
  double get point1D => point[0];

  @override
  String toString() =>
      'OptimizationResult(point: $point, value: $value, iterations: $iterations, converged: $converged)';
}

/// Defines lower and upper bounds for a coordinate in constrained optimization.
class BoxBound {
  /// Creates a box bound with optional [lower] and [upper] limits.
  const new({this.lower, this.upper});

  /// The lower bound, or `null` if unbounded below ($-\infty$).
  final double? lower;

  /// The upper bound, or `null` if unbounded above ($+\infty$).
  final double? upper;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxBound && other.lower == lower && other.upper == upper;

  @override
  int get hashCode => Object.hash(lower, upper);

  @override
  String toString() => 'BoxBound(lower: $lower, upper: $upper)';
}
