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
double clenshawEvaluate(
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

/// Generates the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$.
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
