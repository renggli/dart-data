import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../numeric/calculus/derivative.dart' as numeric_derivative;
import '../../numeric/integration/integration.dart' as numeric_integration;
import '../../special/binomial.dart' as special_binomial;
import '../../special/gamma.dart' as special_gamma;
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/limit.dart';
import '../calculus/summation.dart';
import 'evaluator.dart';

double evalRealBinomial(double n, double k) {
  if (!n.isFinite || !k.isFinite) return double.nan;
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

/// Computes (ln|Gamma(z)|, sgn Gamma(z)) for real [z].
///
/// Returns `sign == 0` and `logAbs == double.infinity` at non-positive integer
/// poles, or `logAbs == double.nan` for `NaN`.
({double logAbs, int sign}) logAbsGammaWithSign(double z) {
  if (!z.isFinite) {
    return z == double.infinity
        ? (logAbs: double.infinity, sign: 1)
        : (logAbs: double.nan, sign: 0);
  }
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

/// Computes (ln|C(n, k)|, sgn C(n, k)) for real [n] and [k].
({double logAbs, int sign}) logAbsBinomialWithSign(double n, double k) {
  if (!n.isFinite || !k.isFinite) return (logAbs: double.nan, sign: 0);
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
    return numeric_integration.integrate(
      (x) {
        localContext[variable] = x;
        return integrandEval.evaluateMap(localContext);
      },
      a,
      b,
      onWarning: (_, _) {},
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
    if (order <= 0) {
      return compileInner(substituted).evaluateMap(evalContext);
    }
    if (order <= 6) {
      final eval = compileInner(substituted);
      return numeric_derivative.derivative(
        (x) {
          evalContext[variable] = x;
          return eval.evaluateMap(evalContext);
        },
        evalPt,
        order: order,
        accuracy: 4,
      );
    }
    return double.nan;
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
    final aIsInt = a.isFinite && a == a.roundToDouble();
    final bIsInt = b.isFinite && b == b.roundToDouble();
    if (aIsInt && bIsInt && b < a) return 0.0;
    if (aIsInt &&
        bIsInt &&
        a.abs() <= 1e15 &&
        b.abs() <= 1e15 &&
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
    if ((a.isFinite && !aIsInt) || (b.isFinite && !bIsInt)) return double.nan;
    var substituted = expr;
    for (final MapEntry(:key, :value) in context.entries) {
      if (key != variable) {
        substituted = substituted.substitute(key, Expr.wrap(value));
      }
    }
    final s = substituted.sum(variable, Expr.wrap(a), Expr.wrap(b));
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
    final aIsInt = a.isFinite && a == a.roundToDouble();
    final bIsInt = b.isFinite && b == b.roundToDouble();
    if (aIsInt && bIsInt && b < a) return 1.0;
    if (aIsInt &&
        bIsInt &&
        a.abs() <= 1e15 &&
        b.abs() <= 1e15 &&
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
    if ((a.isFinite && !aIsInt) || (b.isFinite && !bIsInt)) return double.nan;
    var substituted = expr;
    for (final MapEntry(:key, :value) in context.entries) {
      if (key != variable) {
        substituted = substituted.substitute(key, Expr.wrap(value));
      }
    }
    final p = substituted.product(variable, Expr.wrap(a), Expr.wrap(b));
    if (!p.anyNode((n) => n is Product)) {
      return compileInner(p).evaluateMap(context);
    }
    return double.nan;
  }
  return double.nan;
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
