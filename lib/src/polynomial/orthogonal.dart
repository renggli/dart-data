import '../../type.dart';
import 'polynomial.dart';

/// Supported orthogonal polynomial families for recurrence generation and
/// Clenshaw summation.
enum OrthogonalFamily {
  /// Chebyshev polynomials of the first kind $T_n(x)$.
  chebyshevT,

  /// Chebyshev polynomials of the second kind $U_n(x)$.
  chebyshevU,

  /// Legendre polynomials $P_n(x)$.
  legendreP,

  /// Physicists' Hermite polynomials $H_n(x)$.
  hermiteH,

  /// Probabilists' Hermite polynomials $He_n(x)$.
  hermiteHe,
}

/// Evaluates a linear combination $\sum_{k=0}^n c_k P_k(x)$ of orthogonal
/// polynomials [coefficients] at [x] using the Clenshaw recurrence algorithm.
///
/// Conceptually, this calculates the value of combined orthogonal polynomial
/// expansions (such as Chebyshev or Legendre series) accurately while
/// minimizing rounding errors. More formally, Clenshaw recurrence evaluates
/// polynomial sums backwards from degree $n$ to 0 using the 3-term recurrence
/// relation in $\mathcal{O}(n)$ time and $\mathcal{O}(1)$ auxiliary memory.
///
/// ```dart
/// final val = evaluateOrthogonalSeries(
///   [1.0, 2.0],
///   0.5,
///   family: OrthogonalFamily.chebyshevT,
/// );
/// // T_0(0.5)*1 + T_1(0.5)*2 = 1.0 + 0.5*2 = 2.0
/// ```
double evaluateOrthogonalSeries(
  List<num> coefficients,
  num x, {
  required OrthogonalFamily family,
}) {
  if (coefficients.isEmpty) return 0.0;
  final degree = coefficients.length - 1;
  if (degree == 0) return coefficients[0].toDouble();

  final xd = x.toDouble();
  var b2 = 0.0;
  var b1 = 0.0;

  switch (family) {
    case OrthogonalFamily.chebyshevT:
      for (var k = degree; k >= 1; k--) {
        final b0 = coefficients[k].toDouble() + 2.0 * xd * b1 - b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + xd * b1 - b2;

    case OrthogonalFamily.chebyshevU:
      for (var k = degree; k >= 1; k--) {
        final b0 = coefficients[k].toDouble() + 2.0 * xd * b1 - b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + 2.0 * xd * b1 - b2;

    case OrthogonalFamily.legendreP:
      for (var k = degree; k >= 1; k--) {
        final alphaK = (2.0 * k + 1.0) / (k + 1.0);
        final gammaKPlus1 = (k + 1.0) / (k + 2.0);
        final b0 =
            coefficients[k].toDouble() + alphaK * xd * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + xd * b1 - 0.5 * b2;

    case OrthogonalFamily.hermiteH:
      for (var k = degree; k >= 1; k--) {
        final gammaKPlus1 = 2.0 * (k + 1.0);
        final b0 =
            coefficients[k].toDouble() + 2.0 * xd * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + 2.0 * xd * b1 - 2.0 * b2;

    case OrthogonalFamily.hermiteHe:
      for (var k = degree; k >= 1; k--) {
        final gammaKPlus1 = (k + 1.0).toDouble();
        final b0 = coefficients[k].toDouble() + xd * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + xd * b1 - b2;
  }
}

/// Generates the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$ as a
/// [Polynomial].
///
/// Conceptually, Laguerre polynomials are orthogonal functions frequently used
/// in quantum physics (such as modeling the radial wavefunctions of hydrogen
/// atoms) and numerical analysis. Formally, these are classical orthogonal
/// polynomials on $[0, \infty)$ with respect to weighting measure
/// $w(x) = x^\alpha e^{-x}$.
///
/// ```dart
/// final l2 = laguerreL(2); // 1 - 2x + 0.5x^2
/// ```
Polynomial<double> laguerreL(int degree, {double alpha = 0.0}) {
  if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
  if (degree == 0) {
    return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  }
  if (degree == 1) {
    return Polynomial<double>.fromCoefficients([
      1.0 + alpha,
      -1.0,
    ], type: DataType.float64);
  }
  var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  var p1 = Polynomial<double>.fromCoefficients([
    1.0 + alpha,
    -1.0,
  ], type: DataType.float64);

  for (var k = 1; k < degree; k++) {
    final term1 = Polynomial<double>.fromCoefficients([
      2.0 * k + 1.0 + alpha,
      -1.0,
    ], type: DataType.float64);
    final pNext = (term1 * p1 - p0.scale(k + alpha)).scale(1.0 / (k + 1.0));
    p0 = p1;
    p1 = pNext;
  }
  return p1;
}

/// Evaluates the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$ at [x]
/// using the 3-term recurrence relation.
double laguerreEvaluate(int n, num x, {double alpha = 0.0}) {
  if (n < 0) throw ArgumentError('Degree must be non-negative: $n');
  final xd = x.toDouble();
  if (n == 0) return 1.0;
  if (n == 1) return 1.0 + alpha - xd;

  var l0 = 1.0;
  var l1 = 1.0 + alpha - xd;
  for (var k = 1; k < n; k++) {
    final lNext =
        ((2.0 * k + 1.0 + alpha - xd) * l1 - (k + alpha) * l0) / (k + 1.0);
    l0 = l1;
    l1 = lNext;
  }
  return l1;
}
