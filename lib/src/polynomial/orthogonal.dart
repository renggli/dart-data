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
