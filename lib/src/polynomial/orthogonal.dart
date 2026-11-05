import '../type/data_type.dart';
import 'polynomial.dart';

/// Evaluates the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$ of degree [n]
/// at [x] with parameter [alpha] (defaulting to `0.0` for standard Laguerre polynomials).
double laguerreEvaluate(int n, num x, {num alpha = 0.0}) {
  if (n < 0) {
    throw ArgumentError.value(n, 'n', 'Degree must be non-negative');
  }
  if (n == 0) return 1.0;
  final xd = x.toDouble();
  final a = alpha.toDouble();
  var l0 = 1.0;
  var l1 = 1.0 + a - xd;
  if (n == 1) return l1;
  for (var k = 1; k < n; k++) {
    final next = ((2.0 * k + 1.0 + a - xd) * l1 - (k + a) * l0) / (k + 1.0);
    l0 = l1;
    l1 = next;
  }
  return l1;
}

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

  /// Generalized Laguerre polynomials $L_n^{(\alpha)}(x)$.
  laguerreL,
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
/// When [family] is [OrthogonalFamily.laguerreL], the generalized parameter
/// [alpha] (defaulting to `0.0`) specifies $L_k^{(\alpha)}(x)$.
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

/// Generates the Chebyshev polynomial of the first kind $T_n(x)$.
Polynomial<double> chebyshevT(int degree) {
  if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
  if (degree == 0) {
    return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  }
  if (degree == 1) {
    return Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);
  }
  var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  var p1 = Polynomial<double>.fromCoefficients([
    0.0,
    1.0,
  ], type: DataType.float64);
  final twoX = Polynomial<double>.fromCoefficients([
    0.0,
    2.0,
  ], type: DataType.float64);

  for (var k = 2; k <= degree; k++) {
    final pNext = twoX * p1 - p0;
    p0 = p1;
    p1 = pNext;
  }
  return p1;
}

/// Generates the Chebyshev polynomial of the second kind $U_n(x)$.
Polynomial<double> chebyshevU(int degree) {
  if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
  if (degree == 0) {
    return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  }
  if (degree == 1) {
    return Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);
  }
  var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  var p1 = Polynomial<double>.fromCoefficients([
    0.0,
    2.0,
  ], type: DataType.float64);
  final twoX = Polynomial<double>.fromCoefficients([
    0.0,
    2.0,
  ], type: DataType.float64);

  for (var k = 2; k <= degree; k++) {
    final pNext = twoX * p1 - p0;
    p0 = p1;
    p1 = pNext;
  }
  return p1;
}

/// Generates the Legendre polynomial $P_n(x)$.
Polynomial<double> legendreP(int degree) {
  if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
  if (degree == 0) {
    return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  }
  if (degree == 1) {
    return Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);
  }
  var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  var p1 = Polynomial<double>.fromCoefficients([
    0.0,
    1.0,
  ], type: DataType.float64);

  for (var k = 1; k < degree; k++) {
    final alpha = (2.0 * k + 1.0) / (k + 1.0);
    final gamma = k.toDouble() / (k + 1.0);
    final alphaX = Polynomial<double>.fromCoefficients([
      0.0,
      alpha,
    ], type: DataType.float64);
    final pNext = alphaX * p1 - p0.scale(gamma);
    p0 = p1;
    p1 = pNext;
  }
  return p1;
}

/// Generates the Physicists' Hermite polynomial $H_n(x)$.
Polynomial<double> hermiteH(int degree) {
  if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
  if (degree == 0) {
    return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  }
  if (degree == 1) {
    return Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);
  }
  var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  var p1 = Polynomial<double>.fromCoefficients([
    0.0,
    2.0,
  ], type: DataType.float64);
  final twoX = Polynomial<double>.fromCoefficients([
    0.0,
    2.0,
  ], type: DataType.float64);

  for (var k = 1; k < degree; k++) {
    final pNext = twoX * p1 - p0.scale(2.0 * k);
    p0 = p1;
    p1 = pNext;
  }
  return p1;
}

/// Generates the Probabilists' Hermite polynomial $He_n(x)$.
Polynomial<double> hermiteHe(int degree) {
  if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
  if (degree == 0) {
    return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  }
  if (degree == 1) {
    return Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);
  }
  var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
  var p1 = Polynomial<double>.fromCoefficients([
    0.0,
    1.0,
  ], type: DataType.float64);
  final x = Polynomial<double>.fromCoefficients([
    0.0,
    1.0,
  ], type: DataType.float64);

  for (var k = 1; k < degree; k++) {
    final pNext = x * p1 - p0.scale(k.toDouble());
    p0 = p1;
    p1 = pNext;
  }
  return p1;
}

/// Generates the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$.
///
/// Conceptually, Laguerre polynomials are orthogonal functions frequently
/// used in quantum physics (such as modeling the radial wavefunctions of
/// hydrogen atoms) and numerical analysis. Formally, these are classical
/// orthogonal polynomials on $[0, \infty)$ with respect to weighting measure
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
