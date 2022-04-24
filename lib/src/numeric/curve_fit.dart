import 'types.dart';

/// Curve fitting is the process of constructing a curve, or mathematical
/// function, that has the best fit to a series of data points, possibly subject
/// to constraints.
///
/// See https://en.wikipedia.org/wiki/Curve_fitting.
abstract class CurveFit {
  CurveFit(this.function);

  /// A function with a list of params and the current value.
  ParameterizedFunction function;

  /// Fits a list of data points to the configured function.
  FitResult fit({
    required List<double> x,
    required List<double> y,
    double weight = 1.0,
    List<double>? weights,
  });
}

class FitResult {
  FitResult({
    required this.parameterValues,
    required this.parameterError,
    required this.iterationCount,
  });

  final List<double> parameterValues;
  final double parameterError;
  final int iterationCount;
}
