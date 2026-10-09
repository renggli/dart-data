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
  final n = coefficients.length - 1;
  if (n == 0) return coefficients[0].toDouble();

  final xd = x.toDouble();
  var b2 = 0.0;
  var b1 = 0.0;

  switch (family) {
    case OrthogonalFamily.chebyshevT:
      for (var k = n; k >= 1; k--) {
        final b0 = coefficients[k].toDouble() + 2.0 * xd * b1 - b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + xd * b1 - b2;

    case OrthogonalFamily.chebyshevU:
      for (var k = n; k >= 1; k--) {
        final b0 = coefficients[k].toDouble() + 2.0 * xd * b1 - b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + 2.0 * xd * b1 - b2;

    case OrthogonalFamily.legendreP:
      for (var k = n; k >= 1; k--) {
        final alphaK = (2.0 * k + 1.0) / (k + 1.0);
        final gammaKPlus1 = (k + 1.0) / (k + 2.0);
        final b0 =
            coefficients[k].toDouble() + alphaK * xd * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + xd * b1 - 0.5 * b2;

    case OrthogonalFamily.hermiteH:
      for (var k = n; k >= 1; k--) {
        final gammaKPlus1 = 2.0 * (k + 1.0);
        final b0 =
            coefficients[k].toDouble() + 2.0 * xd * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + 2.0 * xd * b1 - 2.0 * b2;

    case OrthogonalFamily.hermiteHe:
      for (var k = n; k >= 1; k--) {
        final gammaKPlus1 = (k + 1.0).toDouble();
        final b0 = coefficients[k].toDouble() + xd * b1 - gammaKPlus1 * b2;
        b2 = b1;
        b1 = b0;
      }
      return coefficients[0].toDouble() + xd * b1 - b2;
  }
}
