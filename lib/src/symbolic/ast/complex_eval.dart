part of '../ast.dart';

Complex _evaluateComplex(
  Expr expr,
  Map<String, Complex> context,
) => switch (expr) {
  Variable(:final name) =>
    context[name] ??
        (throw ArgumentError('Variable "$name" not provided in context')),
  Number() => expr.complexValue,
  Add(:final left, :final right) =>
    _evaluateComplex(left, context) + _evaluateComplex(right, context),
  Sub(:final left, :final right) =>
    _evaluateComplex(left, context) - _evaluateComplex(right, context),
  Mul(:final left, :final right) =>
    _evaluateComplex(left, context) * _evaluateComplex(right, context),
  Div(:final left, :final right) =>
    _evaluateComplex(left, context) / _evaluateComplex(right, context),
  Pow(:final base, :final exponent) => complexPow(
    _evaluateComplex(base, context),
    _evaluateComplex(exponent, context),
  ),
  Neg(:final expr) => -_evaluateComplex(expr, context),
  Sin(:final expr) => _evaluateComplex(expr, context).sin(),
  Cos(:final expr) => _evaluateComplex(expr, context).cos(),
  Tan(:final expr) => _evaluateComplex(expr, context).tan(),
  Asin(:final expr) => _evaluateComplex(expr, context).asin(),
  Acos(:final expr) => _evaluateComplex(expr, context).acos(),
  Atan(:final expr) => _evaluateComplex(expr, context).atan(),
  Sinh(:final expr) => _evaluateComplex(expr, context).sinh(),
  Cosh(:final expr) => _evaluateComplex(expr, context).cosh(),
  Tanh(:final expr) => _evaluateComplex(expr, context).tanh(),
  Exp(:final expr) => _evaluateComplex(expr, context).exp(),
  Ln(:final expr) => _evaluateComplex(expr, context).log(),
  Abs(:final expr) => Complex(_evaluateComplex(expr, context).abs(), 0),
  OrderTerm() => Complex.zero,
  LambertW(:final expr, :final branch) => evaluateComplexLambertW(
    _evaluateComplex(expr, context),
    branch,
  ),
  Erf(:final expr) => evaluateComplexErf(_evaluateComplex(expr, context)),
  Erfc(:final expr) =>
    Complex.one - evaluateComplexErf(_evaluateComplex(expr, context)),
  Gamma(:final expr) => evaluateComplexGamma(_evaluateComplex(expr, context)),
  Beta(:final left, :final right) => () {
    final zA = _evaluateComplex(left, context);
    final zB = _evaluateComplex(right, context);
    return (evaluateComplexGamma(zA) * evaluateComplexGamma(zB)) /
        evaluateComplexGamma(zA + zB);
  }(),
  Asinh(:final expr) => evaluateComplexAsinh(_evaluateComplex(expr, context)),
  Acosh(:final expr) => evaluateComplexAcosh(_evaluateComplex(expr, context)),
  Atanh(:final expr) => evaluateComplexAtanh(_evaluateComplex(expr, context)),
  LessThan(:final left, :final right) =>
    _evaluateComplex(left, context).a < _evaluateComplex(right, context).a
        ? Complex.one
        : Complex.zero,
  LessEqual(:final left, :final right) =>
    _evaluateComplex(left, context).a <= _evaluateComplex(right, context).a
        ? Complex.one
        : Complex.zero,
  GreaterThan(:final left, :final right) =>
    _evaluateComplex(left, context).a > _evaluateComplex(right, context).a
        ? Complex.one
        : Complex.zero,
  GreaterEqual(:final left, :final right) =>
    _evaluateComplex(left, context).a >= _evaluateComplex(right, context).a
        ? Complex.one
        : Complex.zero,
  Equal(:final left, :final right) =>
    _evaluateComplex(left, context) == _evaluateComplex(right, context)
        ? Complex.one
        : Complex.zero,
  Piecewise(:final branches, :final otherwise) => _evaluateComplexPiecewise(
    branches,
    otherwise,
    context,
  ),
};

Complex _evaluateComplexPiecewise(
  List<(Expr, Expr)> branches,
  Expr? otherwise,
  Map<String, Complex> context,
) {
  for (final (cond, e) in branches) {
    final cVal = _evaluateComplex(cond, context);
    if (cVal.a != 0.0 && !cVal.a.isNaN) {
      return _evaluateComplex(e, context);
    }
  }
  if (otherwise != null) return _evaluateComplex(otherwise, context);
  throw StateError('No matching Piecewise branch in complex evaluation');
}

Complex evaluateComplexLambertW(Complex z, int branch) {
  if (z.b == 0.0) {
    const invE = 0.36787944117144232159587;
    if (branch == 0 && z.a >= -invE) {
      return Complex(evaluateLambertW(z.a.toDouble(), 0), 0.0);
    } else if (branch == -1 && z.a >= -invE && z.a < 0.0) {
      return Complex(evaluateLambertW(z.a.toDouble(), -1), 0.0);
    }
  }
  var w = branch == 0
      ? (z.abs() < 1.0 ? z : z.log() - z.log().log())
      : (z.log() - const Complex(0.0, 2.0 * math.pi)) -
            (z.log() - const Complex(0.0, 2.0 * math.pi)).log();
  for (var i = 0; i < 30; i++) {
    final ew = w.exp();
    final fVal = w * ew - z;
    if (fVal.abs() < 1e-14 * (1.0 + w.abs())) break;
    final w1 = w + Complex.one;
    final denom =
        ew * w1 -
        (w + const Complex(2.0, 0.0)) * fVal / (const Complex(2.0, 0.0) * w1);
    if (denom.abs() == 0.0) break;
    final step = fVal / denom;
    w = w - step;
    if (step.abs() < 1e-14 * (1.0 + w.abs())) break;
  }
  return w;
}

Complex evaluateComplexErf(Complex z) {
  if (z.b == 0.0) return Complex(special_erf.erf(z.a.toDouble()), 0.0);
  if (z.a < 0.0) return -evaluateComplexErf(-z);
  final absZ = z.abs();
  const twoOverSqrtPi = Complex(2.0 / 1.7724538509055159, 0.0);
  if (absZ <= 2.5) {
    final z2 = z * z;
    var term = z;
    var sum = term;
    for (var n = 1; n <= 60; n++) {
      term = -term * z2 * Complex((2 * n - 1) / (n * (2 * n + 1)), 0.0);
      sum = sum + term;
      if (term.abs() < 1e-15 * sum.abs()) break;
    }
    return sum * twoOverSqrtPi;
  }
  // Laplace continued fraction for erfc(z) in Re(z) >= 0:
  // erfc(z) = (exp(-z^2) / sqrt(pi)) * (1 / (z + (1/2) / (z + 1 / (z + (3/2) / ...))))
  var cf = z;
  for (var n = 30; n >= 1; n--) {
    cf = z + Complex(0.5 * n, 0.0) / cf;
  }
  final expNegZ2 = (-z * z).exp();
  if (expNegZ2.a == 0.0 && expNegZ2.b == 0.0) {
    return Complex.one;
  }
  final erfcVal =
      (expNegZ2 * const Complex(1.0 / 1.7724538509055159, 0.0)) / cf;
  return Complex.one - erfcVal;
}

Complex evaluateComplexGamma(Complex z) {
  if (z.b == 0.0) {
    if (z.a <= 0.0 && z.a == z.a.roundToDouble()) {
      throw ArgumentError('Gamma pole at non-positive integer ${z.a}');
    }
    return Complex(special_gamma.gamma(z.a), 0.0);
  }
  if (z.a < 0.5) {
    final piZ = z * const Complex(math.pi, 0.0);
    return const Complex(math.pi, 0.0) /
        (piZ.sin() * evaluateComplexGamma(Complex.one - z));
  }
  const lanczosG = 7;
  const lanczosCoeffs = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  final zAdj = z - Complex.one;
  var y = Complex(lanczosCoeffs[0], 0.0);
  for (var i = 1; i < lanczosG + 2; i++) {
    y =
        y +
        Complex(lanczosCoeffs[i], 0.0) / (zAdj + Complex(i.toDouble(), 0.0));
  }
  final tVal = zAdj + const Complex(lanczosG + 0.5, 0.0);
  final sqrt2Pi = Complex(math.sqrt(2.0 * math.pi), 0.0);
  return sqrt2Pi * tVal.pow(zAdj + const Complex(0.5, 0.0)) * (-tVal).exp() * y;
}

Complex evaluateComplexAsinh(Complex z) =>
    (z + (z * z + Complex.one).sqrt()).log();

Complex evaluateComplexAcosh(Complex z) =>
    (z + (z - Complex.one).sqrt() * (z + Complex.one).sqrt()).log();

Complex evaluateComplexAtanh(Complex z) =>
    ((Complex.one + z).log() - (Complex.one - z).log()) *
    const Complex(0.5, 0.0);

/// Computes complex power [base]^[exponent] handling zero-base edge cases.
Complex complexPow(Complex base, Complex exponent) {
  if (base.a == 0 && base.b == 0) {
    if (exponent.a == 0 && exponent.b == 0) return Complex.one;
    if (exponent.a > 0) return Complex.zero;
    if (exponent.a < 0) {
      return exponent.b == 0
          ? const Complex(double.infinity, 0.0)
          : const Complex(double.infinity, double.nan);
    }
    return Complex.nan;
  }
  return base.pow(exponent);
}
