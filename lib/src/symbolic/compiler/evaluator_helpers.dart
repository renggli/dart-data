import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../special/binomial.dart' as special_binomial;
import '../../special/gamma.dart' as special_gamma;
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/limit.dart';
import '../calculus/summation.dart';
import 'evaluator.dart';

double evalRealBinomial(double n, double k) {
  if (n.isNaN || k.isNaN) return double.nan;
  if (k == k.roundToDouble() && k < 0.0) return 0.0;
  if (n == n.roundToDouble() && k == k.roundToDouble() && n >= 0.0 && k > n) {
    return 0.0;
  }
  if (k == 0.0) return 1.0;
  if (n >= 0.0 && k >= 0.0 && k <= n) {
    return special_binomial.binomial(n, k);
  }
  if (n <= -1.0 && k == k.roundToDouble() && k >= 0.0) {
    final absVal = special_binomial.binomial(-n + k - 1.0, k);
    final isOdd = (k - 2.0 * (k / 2.0).floorToDouble()) != 0.0;
    return isOdd ? -absVal : absVal;
  }
  final (:logAbs, :sign) = logAbsBinomialWithSign(n, k);
  if (logAbs.isNaN) return double.nan;
  if (sign == 0) return 0.0;
  return sign * math.exp(logAbs);
}

/// Computes $(\ln|\Gamma(z)|, \operatorname{sgn}\Gamma(z))$ for real [z].
///
/// Returns `sign == 0` and `logAbs == double.infinity` at non-positive integer
/// poles, or `logAbs == double.nan` for `NaN`.
({double logAbs, int sign}) logAbsGammaWithSign(double z) {
  if (z.isNaN) return (logAbs: double.nan, sign: 0);
  if (z <= 0.0 && z == z.roundToDouble()) {
    return (logAbs: double.infinity, sign: 0);
  }
  if (z > 0.0) {
    return (logAbs: special_gamma.gammaLn(z), sign: 1);
  }
  final r = z - 2.0 * (z / 2.0).roundToDouble();
  final s = math.sin(math.pi * r);
  if (s == 0.0) return (logAbs: double.infinity, sign: 0);
  final logAbs =
      math.log(math.pi) - math.log(s.abs()) - special_gamma.gammaLn(1.0 - z);
  return (logAbs: logAbs, sign: s > 0.0 ? 1 : -1);
}

/// Computes $(\ln|\binom{n}{k}|, \operatorname{sgn}\binom{n}{k})$ for real
/// [n] and [k].
({double logAbs, int sign}) logAbsBinomialWithSign(double n, double k) {
  if (n.isNaN || k.isNaN) return (logAbs: double.nan, sign: 0);
  if (k == k.roundToDouble() && k < 0.0) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  if (n == n.roundToDouble() && k == k.roundToDouble() && n >= 0.0 && k > n) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  if (k == 0.0) return (logAbs: 0.0, sign: 1);
  if (n >= 0.0 && k >= 0.0 && k <= n) {
    return (logAbs: special_binomial.binomialLn(n, k), sign: 1);
  }
  if (n <= -1.0 && k == k.roundToDouble() && k >= 0.0) {
    final logAbs = special_binomial.binomialLn(-n + k - 1.0, k);
    final isOdd = (k - 2.0 * (k / 2.0).floorToDouble()) != 0.0;
    return (logAbs: logAbs, sign: isOdd ? -1 : 1);
  }
  final numG = logAbsGammaWithSign(n + 1.0);
  final den1G = logAbsGammaWithSign(k + 1.0);
  final den2G = logAbsGammaWithSign(n - k + 1.0);
  if (numG.logAbs.isNaN || den1G.logAbs.isNaN || den2G.logAbs.isNaN) {
    return (logAbs: double.nan, sign: 0);
  }
  if (numG.sign == 0) {
    return (logAbs: double.nan, sign: 0);
  }
  if (den1G.sign == 0 || den2G.sign == 0) {
    return (logAbs: double.negativeInfinity, sign: 0);
  }
  return (
    logAbs: numG.logAbs - den1G.logAbs - den2G.logAbs,
    sign: numG.sign * den1G.sign * den2G.sign,
  );
}

bool isEffectivelyReal(Complex z) =>
    !z.isNaN && z.b.abs() <= 1e-15 * (z.a.abs() + 1.0);

double evalNodeReal(
  Expr node,
  Map<String, double> context,
  BytecodeEvaluator Function(Expr) compileInner,
) {
  if (node case Integral(
    :final integrand,
    :final variable,
    :final lower?,
    :final upper?,
  )) {
    final a = compileInner(lower).evaluateMap(context);
    final b = compileInner(upper).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (a == b) return 0.0;
    final integrandEval = compileInner(integrand);
    final localContext = Map<String, double>.of(context);
    return _quadratureDefinite(
      (x) {
        localContext[variable] = x;
        return integrandEval.evaluateMap(localContext);
      },
      a,
      b,
    );
  }
  if (node case Derivative(
    :final expr,
    :final variable,
    :final order,
    :final point,
  )) {
    var substituted = expr;
    for (final MapEntry(:key, :value) in context.entries) {
      if (key != variable) {
        substituted = substituted.substitute(key, Expr.wrap(value));
      }
    }
    final d = substituted.derivative(variable, order: order);
    final evalPt = point != null
        ? compileInner(point).evaluateMap(context)
        : context[variable];
    if (evalPt == null || evalPt.isNaN) return double.nan;
    final evalContext = Map<String, double>.of(context)..[variable] = evalPt;
    if (!d.anyNode((n) => n is Derivative)) {
      return compileInner(d).evaluateMap(evalContext);
    }
    return _numericDerivativeReal(
      compileInner(substituted),
      variable,
      evalContext,
      evalPt,
      order,
    );
  }
  if (node case Limit(
    :final expr,
    :final variable,
    :final point,
    :final direction,
  )) {
    var substituted = expr;
    for (final MapEntry(:key, :value) in context.entries) {
      if (key != variable) {
        substituted = substituted.substitute(key, Expr.wrap(value));
      }
    }
    final ptVal = compileInner(point).evaluateMap(context);
    if (ptVal.isNaN) return double.nan;
    final ptExpr = ptVal.isInfinite
        ? (ptVal > 0 ? Constant.infinity : -Constant.infinity)
        : Expr.wrap(ptVal);
    final lim = substituted.limit(variable, ptExpr, direction: direction);
    if (lim.anyNode((n) => n is Limit)) return double.nan;
    return compileInner(lim).evaluateMap(context);
  }
  if (node case Sum(:final expr, :final variable, :final lower, :final upper)) {
    final a = compileInner(lower).evaluateMap(context);
    final b = compileInner(upper).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (b < a) return 0.0;
    if (a.isFinite &&
        b.isFinite &&
        a == a.roundToDouble() &&
        b == b.roundToDouble() &&
        (b - a) <= 100000) {
      final start = a.round();
      final end = b.round();
      final eval = compileInner(expr);
      final localCtx = Map<String, double>.of(context);
      var total = 0.0;
      for (var k = start; k <= end; k++) {
        localCtx[variable] = k.toDouble();
        total += eval.evaluateMap(localCtx);
      }
      return total;
    }
    final s = expr.sum(variable, Expr.wrap(a), Expr.wrap(b));
    if (!s.anyNode((n) => n is Sum)) {
      return compileInner(s).evaluateMap(context);
    }
    return double.nan;
  }
  if (node case Product(
    :final expr,
    :final variable,
    :final lower,
    :final upper,
  )) {
    final a = compileInner(lower).evaluateMap(context);
    final b = compileInner(upper).evaluateMap(context);
    if (a.isNaN || b.isNaN) return double.nan;
    if (b < a) return 1.0;
    if (a.isFinite &&
        b.isFinite &&
        a == a.roundToDouble() &&
        b == b.roundToDouble() &&
        (b - a) <= 100000) {
      final start = a.round();
      final end = b.round();
      final eval = compileInner(expr);
      final localCtx = Map<String, double>.of(context);
      var total = 1.0;
      for (var k = start; k <= end; k++) {
        localCtx[variable] = k.toDouble();
        total *= eval.evaluateMap(localCtx);
      }
      return total;
    }
    final p = expr.product(variable, Expr.wrap(a), Expr.wrap(b));
    if (!p.anyNode((n) => n is Product)) {
      return compileInner(p).evaluateMap(context);
    }
    return double.nan;
  }
  return double.nan;
}

double _quadratureDefinite(double Function(double) f, double a, double b) {
  if (b < a) {
    return -_quadratureDefinite(f, b, a);
  }
  if (a == double.negativeInfinity && b == double.infinity) {
    return _gaussLegendre16(
      (t) {
        final denom = 1.0 - t * t;
        if (denom == 0.0) return 0.0;
        final x = t / denom;
        final dx = (1.0 + t * t) / (denom * denom);
        return f(x) * dx;
      },
      -1.0,
      1.0,
    );
  }
  if (a.isFinite && b == double.infinity) {
    return _gaussLegendre16(
      (t) {
        if (t >= 1.0) return 0.0;
        final d = 1.0 - t;
        final x = a + t / d;
        final dx = 1.0 / (d * d);
        return f(x) * dx;
      },
      0.0,
      1.0,
    );
  }
  if (a == double.negativeInfinity && b.isFinite) {
    return _gaussLegendre16(
      (t) {
        if (t >= 1.0) return 0.0;
        final d = 1.0 - t;
        final x = b - t / d;
        final dx = 1.0 / (d * d);
        return f(x) * dx;
      },
      0.0,
      1.0,
    );
  }
  return _gaussLegendre16(f, a, b);
}

const _glNodes8 = <double>[
  0.09501250983763744,
  0.2816035507792589,
  0.45801677765722737,
  0.6178762444026438,
  0.755404408355003,
  0.8656312023878318,
  0.9445750230732326,
  0.9894009349916499,
];

const _glWeights8 = <double>[
  0.1894506104550685,
  0.18260341504492358,
  0.16915651939500254,
  0.14959598881657674,
  0.12462897125553388,
  0.09515851168249279,
  0.062253523938647894,
  0.027152459411754096,
];

double _gaussLegendre16(double Function(double) f, double a, double b) {
  final half = 0.5 * (b - a);
  final mid = 0.5 * (a + b);
  var sum = 0.0;
  for (var i = 0; i < 8; i++) {
    final dx = half * _glNodes8[i];
    final y1 = f(mid - dx);
    final y2 = f(mid + dx);
    sum +=
        _glWeights8[i] * ((y1.isFinite ? y1 : 0.0) + (y2.isFinite ? y2 : 0.0));
  }
  return half * sum;
}

double realPow(double base, double exponent, [int oddRootMode = 0]) {
  if (oddRootMode != 0 && base < 0.0) {
    final mag = math.pow(-base, exponent).toDouble();
    return oddRootMode == 1 ? -mag : mag;
  }
  return math.pow(base, exponent).toDouble();
}

Complex complexPow(Complex base, Complex exponent) {
  if (exponent == Complex.zero) return Complex.one;
  if (base == Complex.zero) {
    if (exponent.a > 0) return Complex.zero;
    if (exponent.a < 0 && exponent.b == 0.0) {
      return const Complex(double.infinity);
    }
    return Complex.nan;
  }
  if (exponent.b == 0.0 &&
      exponent.a == exponent.a.roundToDouble() &&
      exponent.a.abs() <= 64) {
    final n = exponent.a.round();
    if (n == 1) return base;
    if (n == 2) return base * base;
    if (n == -1) return Complex.one / base;
    var result = Complex.one;
    var cur = n < 0 ? Complex.one / base : base;
    var m = n.abs();
    while (m > 0) {
      if (m.isOdd) result *= cur;
      cur *= cur;
      m >>= 1;
    }
    return result;
  }
  return base.pow(exponent);
}

double _numericDerivativeReal(
  BytecodeEvaluator eval,
  String variable,
  Map<String, double> context,
  double x,
  int order,
) {
  if (order <= 0) {
    context[variable] = x;
    return eval.evaluateMap(context);
  }
  if (order == 1) {
    final h = 1.0e-5 * math.max(1.0, x.abs());
    context[variable] = x + 2.0 * h;
    final fp2 = eval.evaluateMap(context);
    context[variable] = x + h;
    final fp1 = eval.evaluateMap(context);
    context[variable] = x - h;
    final fm1 = eval.evaluateMap(context);
    context[variable] = x - 2.0 * h;
    final fm2 = eval.evaluateMap(context);
    return (-fp2 + 8.0 * fp1 - 8.0 * fm1 + fm2) / (12.0 * h);
  }
  final h = 1.0e-3 * math.max(1.0, x.abs());
  final fPlus = _numericDerivativeReal(
    eval,
    variable,
    context,
    x + h,
    order - 1,
  );
  final fMinus = _numericDerivativeReal(
    eval,
    variable,
    context,
    x - h,
    order - 1,
  );
  return (fPlus - fMinus) / (2.0 * h);
}
