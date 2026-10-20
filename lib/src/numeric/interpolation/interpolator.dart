/// Base interface for 1D interpolators.
abstract class Interpolator {
  /// Evaluates the interpolated function at [x].
  double call(num x);
}

/// Base interface for 2D surface interpolators.
abstract class Interpolator2D {
  /// Evaluates the interpolated surface at coordinates `([x], [y])`.
  double evaluate(double x, double y);

  /// Evaluates the interpolated surface at coordinates `([x], [y])`.
  double call(double x, double y);
}
