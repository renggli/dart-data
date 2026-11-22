import 'dart:math' as math;

/// Overflow- and underflow-safe Euclidean norm accumulator using Blue/LAPACK
/// scaled sum-of-squares (`scale * sqrt(sumsq)`).
final class ScaledNormAccumulator {
  /// Creates an accumulator initialized to zero.
  new();

  double _scale = 0.0;
  double _sumsq = 1.0;
  bool _hasNaN = false;

  /// Adds a non-negative magnitude [absVal] to the accumulator.
  void addAbs(double absVal) {
    if (absVal == 0.0) return;
    if (absVal.isNaN) {
      _hasNaN = true;
      return;
    }
    if (absVal.isInfinite) {
      _scale = double.infinity;
    } else if (_scale < absVal) {
      final ratio = _scale / absVal;
      _sumsq = 1.0 + _sumsq * ratio * ratio;
      _scale = absVal;
    } else if (_scale.isFinite) {
      final ratio = absVal / _scale;
      _sumsq += ratio * ratio;
    }
  }

  /// Adds a signed scalar [value] by accumulating `value.abs()`.
  void add(double value) => addAbs(value.abs());

  /// Returns the accumulated Euclidean norm (`double.nan` if any `NaN` was
  /// observed, `double.infinity` if any `±∞` was observed without `NaN`).
  double get norm => _hasNaN ? double.nan : _scale * math.sqrt(_sumsq);
}
