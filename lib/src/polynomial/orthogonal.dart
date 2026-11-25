import 'dart:typed_data';

import '../type/data_type.dart';
import 'impl/dense_polynomial.dart';
import 'polynomial.dart';

/// Supported classical orthogonal polynomial families for recurrence generation,
/// single-point evaluation, and Clenshaw series summation.
enum OrthogonalFamily {
  /// Chebyshev polynomials of the first kind `T_n(x)`.
  chebyshevT,

  /// Chebyshev polynomials of the second kind `U_n(x)`.
  chebyshevU,

  /// Legendre polynomials `P_n(x)`.
  legendreP,

  /// Physicists' Hermite polynomials `H_n(x)`.
  hermiteH,

  /// Probabilists' Hermite polynomials `He_n(x)`.
  hermiteHe,

  /// Generalized Laguerre polynomials `L_n^(α)(x)`.
  laguerreL,
}

/// Evaluates an orthogonal polynomial of [degree] from [family] at [x] in
/// O(degree) time and O(1) auxiliary space using its three-term recurrence.
///
/// For [OrthogonalFamily.laguerreL], the optional finite parameter [alpha]
/// (defaulting to `0.0`) specifies `L_n^(α)(x)`.
///
/// Throws a [RangeError] if [degree] is negative, or an [ArgumentError] if
/// [alpha] is non-finite for [OrthogonalFamily.laguerreL].
///
/// ```dart
/// final val = evaluateOrthogonal(
///   2,
///   3.0,
///   family: OrthogonalFamily.chebyshevT,
/// ); // T_2(3) = 2(9) - 1 = 17.0
/// ```
double evaluateOrthogonal(
  int degree,
  num x, {
  required OrthogonalFamily family,
  double alpha = 0.0,
}) {
  RangeError.checkNotNegative(degree, 'degree');
  if (family == OrthogonalFamily.laguerreL && !alpha.isFinite) {
    throw ArgumentError.value(alpha, 'alpha', 'Parameter alpha must be finite');
  }
  if (degree == 0) return 1.0;

  final xd = x.toDouble();
  switch (family) {
    case OrthogonalFamily.chebyshevT:
      var p0 = 1.0;
      var p1 = xd;
      for (var k = 1; k < degree; k++) {
        final next = 2.0 * xd * p1 - p0;
        p0 = p1;
        p1 = next;
      }
      return p1;

    case OrthogonalFamily.chebyshevU:
      var p0 = 1.0;
      var p1 = 2.0 * xd;
      for (var k = 1; k < degree; k++) {
        final next = 2.0 * xd * p1 - p0;
        p0 = p1;
        p1 = next;
      }
      return p1;

    case OrthogonalFamily.legendreP:
      var p0 = 1.0;
      var p1 = xd;
      for (var k = 1; k < degree; k++) {
        final next = ((2.0 * k + 1.0) * xd * p1 - k * p0) / (k + 1.0);
        p0 = p1;
        p1 = next;
      }
      return p1;

    case OrthogonalFamily.hermiteH:
      var p0 = 1.0;
      var p1 = 2.0 * xd;
      for (var k = 1; k < degree; k++) {
        final next = 2.0 * xd * p1 - 2.0 * k * p0;
        p0 = p1;
        p1 = next;
      }
      return p1;

    case OrthogonalFamily.hermiteHe:
      var p0 = 1.0;
      var p1 = xd;
      for (var k = 1; k < degree; k++) {
        final next = xd * p1 - k * p0;
        p0 = p1;
        p1 = next;
      }
      return p1;

    case OrthogonalFamily.laguerreL:
      var p0 = 1.0;
      var p1 = 1.0 + alpha - xd;
      for (var k = 1; k < degree; k++) {
        final next =
            ((2.0 * k + 1.0 + alpha - xd) * p1 - (k + alpha) * p0) / (k + 1.0);
        p0 = p1;
        p1 = next;
      }
      return p1;
  }
}

/// Evaluates a linear combination `∑ c_k P_k(x)` of orthogonal polynomials
/// [coefficients] at [x] using the Clenshaw recurrence algorithm.
///
/// Conceptually, this calculates the value of combined orthogonal polynomial
/// expansions (such as Chebyshev or Legendre series) accurately while
/// minimizing rounding errors. More formally, Clenshaw recurrence evaluates
/// polynomial sums backwards from degree `n` to `0` using the three-term
/// recurrence relation in O(n) time and O(1) auxiliary memory.
///
/// When [family] is [OrthogonalFamily.laguerreL], the finite parameter
/// [alpha] (defaulting to `0.0`) specifies `L_k^(α)(x)`.
///
/// Throws an [ArgumentError] if [alpha] is non-finite for
/// [OrthogonalFamily.laguerreL].
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
  double alpha = 0.0,
}) {
  if (family == OrthogonalFamily.laguerreL && !alpha.isFinite) {
    throw ArgumentError.value(alpha, 'alpha', 'Parameter alpha must be finite');
  }
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

    case OrthogonalFamily.laguerreL:
      for (var k = degree; k >= 1; k--) {
        final alphaK = (2.0 * k + 1.0 + alpha - xd) / (k + 1.0);
        final gammaKPlus1 = (k + 1.0 + alpha) / (k + 2.0);
        final b0 = coefficients[k].toDouble() + alphaK * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() +
          (1.0 + alpha - xd) * b1 -
          0.5 * (1.0 + alpha) * b2;
  }
}

/// Generates the Chebyshev polynomial of the first kind `T_n(x)`.
Polynomial<double> chebyshevT(int degree) =>
    _threeTermLinearRecurrence(degree, 1.0, (_) => 2.0, (_) => 1.0);

/// Generates the Chebyshev polynomial of the second kind `U_n(x)`.
Polynomial<double> chebyshevU(int degree) =>
    _threeTermLinearRecurrence(degree, 2.0, (_) => 2.0, (_) => 1.0);

/// Generates the Legendre polynomial `P_n(x)`.
Polynomial<double> legendreP(int degree) => _threeTermLinearRecurrence(
  degree,
  1.0,
  (k) => (2.0 * k + 1.0) / (k + 1.0),
  (k) => k.toDouble() / (k + 1.0),
);

/// Generates the Physicists' Hermite polynomial `H_n(x)`.
Polynomial<double> hermiteH(int degree) =>
    _threeTermLinearRecurrence(degree, 2.0, (_) => 2.0, (k) => 2.0 * k);

/// Generates the Probabilists' Hermite polynomial `He_n(x)`.
Polynomial<double> hermiteHe(int degree) =>
    _threeTermLinearRecurrence(degree, 1.0, (_) => 1.0, (k) => k.toDouble());

/// Generates the generalized Laguerre polynomial `L_n^(α)(x)`.
///
/// Conceptually, Laguerre polynomials are orthogonal functions frequently
/// used in quantum physics (such as modeling the radial wavefunctions of
/// hydrogen atoms) and numerical analysis. Formally, these are classical
/// orthogonal polynomials on `[0, ∞)` with respect to weighting measure
/// `w(x) = x^α e^(-x)`.
///
/// Throws a [RangeError] if [degree] is negative, or an [ArgumentError] if
/// [alpha] is non-finite.
///
/// ```dart
/// final l2 = laguerreL(2); // 1 - 2x + 0.5x^2
/// ```
Polynomial<double> laguerreL(int degree, {double alpha = 0.0}) {
  RangeError.checkNotNegative(degree, 'degree');
  if (!alpha.isFinite) {
    throw ArgumentError.value(alpha, 'alpha', 'Parameter alpha must be finite');
  }
  if (degree == 0) {
    return DensePolynomial<double>.fromCoefficients([
      1.0,
    ], type: DataType.float64);
  }
  if (degree == 1) {
    return DensePolynomial<double>.fromCoefficients([
      1.0 + alpha,
      -1.0,
    ], type: DataType.float64);
  }

  var prev = Float64List(degree + 1);
  var curr = Float64List(degree + 1);
  var next = Float64List(degree + 1);
  prev[0] = 1.0;
  curr[0] = 1.0 + alpha;
  curr[1] = -1.0;

  for (var k = 1; k < degree; k++) {
    final cConst = 2.0 * k + 1.0 + alpha;
    final g = k + alpha;
    final invK1 = 1.0 / (k + 1.0);
    next[0] = (cConst * curr[0] - g * prev[0]) * invK1;
    for (var i = 1; i < k; i++) {
      next[i] = (cConst * curr[i] - curr[i - 1] - g * prev[i]) * invK1;
    }
    next[k] = (cConst * curr[k] - curr[k - 1]) * invK1;
    next[k + 1] = -curr[k] * invK1;

    final rotated = prev;
    prev = curr;
    curr = next;
    next = rotated;
  }

  return DensePolynomial<double>.fromCoefficients(curr, type: DataType.float64);
}

Polynomial<double> _threeTermLinearRecurrence(
  int degree,
  double c1,
  double Function(int k) xScale,
  double Function(int k) prevScale,
) {
  RangeError.checkNotNegative(degree, 'degree');
  if (degree == 0) {
    return DensePolynomial<double>.fromCoefficients([
      1.0,
    ], type: DataType.float64);
  }
  if (degree == 1) {
    return DensePolynomial<double>.fromCoefficients([
      0.0,
      c1,
    ], type: DataType.float64);
  }

  var prev = Float64List(degree + 1);
  var curr = Float64List(degree + 1);
  var next = Float64List(degree + 1);
  prev[0] = 1.0;
  curr[1] = c1;

  for (var k = 1; k < degree; k++) {
    final a = xScale(k);
    final g = prevScale(k);
    next[0] = -g * prev[0];
    for (var i = 1; i < k; i++) {
      next[i] = a * curr[i - 1] - g * prev[i];
    }
    next[k] = a * curr[k - 1];
    next[k + 1] = a * curr[k];

    final rotated = prev;
    prev = curr;
    curr = next;
    next = rotated;
  }

  return DensePolynomial<double>.fromCoefficients(curr, type: DataType.float64);
}
