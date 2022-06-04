import '../vector/vector.dart';
import 'types.dart';

/// Curve fitting is the process of constructing a curve, or mathematical
/// function, that has the best fit to a series of data points, possibly subject
/// to constraints.
///
/// See https://en.wikipedia.org/wiki/Curve_fitting.
abstract class CurveFit<T> {
  /// Fits a list of data points to the configured model.
  CurveFitResult fit({
    required Vector<double> x,
    required Vector<double> y,
  });
}

/// Generic result of a curve fitting.
class CurveFitResult {
  CurveFitResult(this.function);

  final NumericFunction function;
}