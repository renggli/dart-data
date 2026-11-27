import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../../numeric/calculus/derivative.dart' as numeric_derivative;
import '../../numeric/integration/integration.dart' as numeric_integration;
import '../../polynomial/polynomial.dart';
import '../../type/data_type.dart';
import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../calculus/differentiation.dart';
import '../calculus/limit.dart';
import '../calculus/summation.dart';
import 'evaluator.dart';

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
  if (node case final RootSum rootSum) {
    final complexCtx = <String, Complex>{
      for (final MapEntry(:key, :value) in context.entries) key: Complex(value),
    };
    final z = evalRootSumComplex(rootSum, complexCtx, compileInner);
    if (!z.a.isFinite || !z.b.isFinite) return double.nan;
    return z.b.abs() <= 1e-9 * math.max(1.0, z.a.abs())
        ? z.a.toDouble()
        : double.nan;
  }
  return double.nan;
}

/// Evaluates a symbolic [RootSum] node in complex arithmetic given [context].
Complex evalRootSumComplex(
  RootSum node,
  Map<String, Complex> context,
  BytecodeEvaluator Function(Expr) compileInner,
) {
  final isClosedPoly = node.polynomial.freeVariables.every(
    (v) => v == node.variable,
  );
  var roots = isClosedPoly ? _rootSumCache[node] : null;
  if (roots == null) {
    final coeffMap = extractPolynomialCoefficients(
      node.polynomial.expand().simplify(),
      node.variable,
    );
    if (coeffMap == null) return Complex.nan;
    final deg = maxPolynomialDegree(coeffMap);
    if (deg <= 0) return Complex.zero;

    final evaluated = List<Complex>.filled(deg + 1, Complex.zero);
    for (var i = 0; i <= deg; i++) {
      final coeffExpr = coeffMap[i];
      if (coeffExpr == null) continue;
      final val = compileInner(coeffExpr).evaluateComplexMap(context);
      if (!val.a.isFinite || !val.b.isFinite) return Complex.nan;
      evaluated[i] = val;
    }

    var effDeg = deg;
    while (effDeg >= 0 && evaluated[effDeg].abs() == 0.0) {
      effDeg--;
    }
    if (effDeg <= 0) return Complex.zero;

    final trimmed = evaluated.sublist(0, effDeg + 1);
    final allReal = trimmed.every(
      (c) => c.b.abs() <= 1e-14 * math.max(1.0, c.a.abs()),
    );
    if (allReal) {
      roots = Polynomial<double>.fromCoefficients([
        for (final c in trimmed) c.a.toDouble(),
      ], type: DataType.float64).roots;
    } else if (effDeg <= 2) {
      roots = Polynomial<Complex>.fromCoefficients(
        trimmed,
        type: DataType.complex,
      ).roots;
    } else if (effDeg <= 64) {
      roots = _findComplexPolyRoots(trimmed);
    } else {
      return Complex.nan;
    }

    if (isClosedPoly) {
      _rootSumCache[node] = roots;
    }
  }

  final bodyEval = compileInner(node.body);
  final localCtx = Map<String, Complex>.of(context);
  var total = Complex.zero;
  for (final root in roots) {
    localCtx[node.variable] = root;
    final term = bodyEval.evaluateComplexMap(localCtx);
    if (!term.a.isFinite || !term.b.isFinite) return Complex.nan;
    total += term;
  }
  return total;
}

double realPow(double base, double exponent, [int oddRootMode = 0]) {
  if (oddRootMode != 0 && base < 0.0) {
    final mag = math.pow(-base, exponent).toDouble();
    return oddRootMode == 1 ? -mag : mag;
  }
  return math.pow(base, exponent).toDouble();
}

/// Normalizes negative zeros (`-0.0`) on real and imaginary parts to `+0.0`
/// so complex branch-cut operations (`log`, `sqrt`, `pow`, inverse
/// trigonometric/hyperbolic functions) follow principal-branch semantics.
Complex normalizeComplexZero(Complex z) =>
    Complex(z.a == 0.0 ? 0.0 : z.a, z.b == 0.0 ? 0.0 : z.b);

Complex complexPow(Complex base, Complex exponent) {
  base = normalizeComplexZero(base);
  exponent = normalizeComplexZero(exponent);
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
    if (n == 2) return normalizeComplexZero(base * base);
    if (n == -1) return normalizeComplexZero(Complex.one / base);
    var result = Complex.one;
    var cur = n < 0 ? normalizeComplexZero(Complex.one / base) : base;
    var m = n.abs();
    while (m > 0) {
      if (m.isOdd) result *= cur;
      cur *= cur;
      m >>= 1;
    }
    return normalizeComplexZero(result);
  }
  return base.pow(exponent);
}

final Expando<List<Complex>> _rootSumCache = Expando<List<Complex>>(
  'rootSumRoots',
);

List<Complex> _findComplexPolyRoots(List<Complex> coeffs) {
  var minExp = 0;
  while (minExp < coeffs.length && coeffs[minExp].abs() == 0.0) {
    minExp++;
  }
  final zeroRoots = List<Complex>.filled(minExp, Complex.zero);
  final effDeg = coeffs.length - 1 - minExp;
  if (effDeg <= 0) return zeroRoots;
  if (effDeg <= 2) {
    return [
      ...zeroRoots,
      ...Polynomial<Complex>.fromCoefficients(
        coeffs.sublist(minExp),
        type: DataType.complex,
      ).roots,
    ];
  }

  final lead = coeffs.last;
  final monic = <Complex>[
    for (var i = 0; i <= effDeg; i++) coeffs[minExp + i] / lead,
  ];
  var cauchy = 1.0;
  for (var i = 0; i < effDeg; i++) {
    cauchy = math.max(cauchy, 1.0 + monic[i].abs());
  }
  final geom = math.pow(monic[0].abs(), 1.0 / effDeg).toDouble();
  final radius = math.min(cauchy, math.max(0.5, geom));

  final roots = List<Complex>.generate(effDeg, (k) {
    final angle = 2.0 * math.pi * k / effDeg + 0.137;
    return Complex(radius * math.cos(angle), radius * math.sin(angle));
  });

  final tol = 1e-13 * math.max(1.0, radius);
  for (var iter = 0; iter < 200; iter++) {
    var maxStep = 0.0;
    for (var k = 0; k < effDeg; k++) {
      final zk = roots[k];
      var p = Complex.one;
      var dp = Complex.zero;
      for (var i = effDeg - 1; i >= 0; i--) {
        dp = dp * zk + p;
        p = p * zk + monic[i];
      }
      if (p.abs() == 0.0) continue;
      if (dp.abs() == 0.0) {
        roots[k] = zk + const Complex(1e-7, 1.3e-7);
        continue;
      }
      final w = p / dp;
      var sum = Complex.zero;
      for (var j = 0; j < effDeg; j++) {
        if (j == k) continue;
        final diff = zk - roots[j];
        if (diff.abs() != 0.0) {
          sum += Complex.one / diff;
        }
      }
      final denom = Complex.one - w * sum;
      final delta = denom.abs() > 1e-18 ? w / denom : w;
      roots[k] = zk - delta;
      maxStep = math.max(maxStep, delta.abs());
    }
    if (maxStep < tol) break;
  }

  return [...zeroRoots, ...roots];
}
