import 'types.dart';

/// Returns the root of the provided [function] bracketed between [a] and [b],
/// that is _f(x) = 0_ is solved for _x_ in the range of _[a, b]_.
///
/// [bracketEpsilon], [solutionEpsilon] and [maxIterations] define conditions
/// to terminate the search for a root:
///
/// - If the bracketed interval on the x-axis has been reduced to below
///   [bracketEpsilon] (_|b - a| < bracketEpsilon_), the center point of
///   the interval is returned.
/// - If the solution is closer to zero than [solutionEpsilon] (_|f(x)| <
///   solutionEpsilon_), the value _x_ is returned.
/// - If the number of iterations performed is more than [maxIterations],
///   [double.nan] is returned to signify an error.
///
double solve(
  NumericFunction function,
  double a,
  double b, {
  double bracketEpsilon = 1e-10,
  double solutionEpsilon = 1e-50,
  int maxIterations = 50,
}) {
  // https://en.wikipedia.org/wiki/Brent%27s_method
  var y0 = function(a), y1 = function(b);
  if (y0.abs() < y1.abs()) {
    final tx = a;
    a = b;
    b = tx;
    final ty = y0;
    y0 = y1;
    y1 = ty;
  }
  final y2 = y0;
  var x2 = a, x3 = x2;
  var bisection = true;
  for (var i = 0; i < maxIterations; i++) {
    if ((b - a).abs() < bracketEpsilon) {
      return 0.5 * (a + b);
    }
    // Use inverse quadratic interpolation if f(x0) != f(x1) != f(x2)
    // and linear interpolation (secant method) otherwise.
    double x;
    if ((y0 - y2).abs() > solutionEpsilon &&
        (y1 - y2).abs() > solutionEpsilon) {
      x = a * y1 * y2 / ((y0 - y1) * (y0 - y2)) +
          b * y0 * y2 / ((y1 - y0) * (y1 - y2)) +
          x2 * y0 * y1 / ((y2 - y0) * (y2 - y1));
    } else {
      x = b - y1 * (b - a) / (y1 - y0);
    }
    // Use bisection method if satisfies the conditions.
    final delta = (2 * 1e-52 * b).abs();
    final min1 = (x - b).abs();
    final min2 = (b - x2).abs();
    final min3 = (x2 - x3).abs();
    if ((x < (3 * a + b) / 4 && x > b) ||
        (bisection && min1 >= min2 / 2) ||
        (!bisection && min1 >= min3 / 2) ||
        (bisection && min2 < delta) ||
        (!bisection && min3 < delta)) {
      x = (a + b) / 2;
      bisection = true;
    } else {
      bisection = false;
    }
    final y = function(x);
    if (y.abs() < solutionEpsilon) {
      return x;
    }
    x3 = x2;
    x2 = b;
    if (y0.sign != y.sign) {
      b = x;
      y1 = y;
    } else {
      a = x;
      y0 = y;
    }
    if (y0.abs() < y1.abs()) {
      final tx = a;
      a = b;
      b = tx;
      final ty = y0;
      y0 = y1;
      y1 = ty;
    }
  }
  return double.nan;
}
