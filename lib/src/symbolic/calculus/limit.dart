import 'package:more/number.dart' show Fraction;

import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import 'series.dart';

/// Direction for computing directional limits of symbolic expressions.
enum LimitDirection {
  /// Two-sided limit $\lim_{x \to a} f(x)$. Requires left and right limits to agree.
  both,

  /// Right-hand limit $\lim_{x \to a^+} f(x)$ (approaching from above).
  fromAbove,

  /// Left-hand limit $\lim_{x \to a^-} f(x)$ (approaching from below).
  fromBelow,
}

/// Symbolic limit evaluation extension on [Expr].
extension LimitExtension on Expr {
  /// Computes the symbolic limit $\lim_{variable \to point} f(variable)$.
  ///
  /// Evaluates finite limits ($x \to a$), directional limits ($x \to a^+$, $x \to a^-$),
  /// and infinite limits ($x \to \pm\infty$).
  ///
  /// Conceptually, the limit represents the value that a function approaches as
  /// the input approaches a specified target value or infinity. Formally, it computes
  /// finite limits via Laurent series expansion and infinite limits via the
  /// Dominik Gruntz Most Rapidly Varying (MRV) algorithm.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = Sin(x) / x;
  /// final lim = expr.limit('x', RationalNumber.zero); // 1
  /// ```
  Expr limit(
    String variable,
    Expr point, {
    LimitDirection direction = LimitDirection.both,
  }) => computeLimit(this, variable, point, direction: direction);
}

/// Computes the symbolic limit of [expr] as [variable] approaches [point].
Expr computeLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
}) {
  if (!expr.dependsOn(variable)) return expr.simplify();

  if (expr is Pow &&
      expr.base.dependsOn(variable) &&
      expr.exponent.dependsOn(variable)) {
    final logForm = Mul(expr.exponent, Ln(expr.base));
    final innerLim = computeLimit(
      logForm,
      variable,
      point,
      direction: direction,
    );
    if (_isPositiveInfinity(innerLim)) return ConstantNumber.infinity;
    if (_isNegativeInfinity(innerLim)) return RationalNumber.zero;
    return Exp(innerLim).simplify();
  }

  if (expr is Exp) {
    try {
      final innerLim = computeLimit(
        expr.expr,
        variable,
        point,
        direction: direction,
      );
      if (_isPositiveInfinity(innerLim)) return ConstantNumber.infinity;
      if (_isNegativeInfinity(innerLim)) return RationalNumber.zero;
      return Exp(innerLim).simplify();
    } catch (_) {}
  }

  if (expr is Ln) {
    try {
      final innerLim = computeLimit(
        expr.expr,
        variable,
        point,
        direction: direction,
      );
      if (_isPositiveInfinity(innerLim)) return ConstantNumber.infinity;
      if (innerLim is RationalNumber && innerLim.isZero) {
        return const Neg(ConstantNumber.infinity).simplify();
      }
      if (innerLim is RealNumber && innerLim.value == 0.0) {
        return const Neg(ConstantNumber.infinity).simplify();
      }
      if (_isWellDefinedFinite(innerLim)) {
        return Ln(innerLim).simplify();
      }
    } catch (_) {}
  }

  if (expr is Sin || expr is Cos || expr is Atan || expr is Tanh) {
    final inner = (expr as UnaryExpr).expr;
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
      );
      if (_isWellDefinedFinite(innerLim)) {
        return expr.copyWith(innerLim).simplify();
      }
      if (_isPositiveInfinity(innerLim) || _isNegativeInfinity(innerLim)) {
        if (expr is Sin || expr is Cos) {
          throw UnsupportedError('Limit does not exist due to oscillation');
        }
        if (expr is Atan) {
          return _isPositiveInfinity(innerLim)
              ? const Div(ConstantNumber.pi, RationalNumber(2))
              : const Neg(Div(ConstantNumber.pi, RationalNumber(2)));
        }
        if (expr is Tanh) {
          return _isPositiveInfinity(innerLim)
              ? RationalNumber.one
              : RationalNumber.negativeOne;
        }
      }
    } on UnsupportedError {
      rethrow;
    } catch (_) {}
  }

  if (_isPositiveInfinity(point)) {
    return _computeInfiniteLimit(expr, variable, isPositive: true);
  }
  if (_isNegativeInfinity(point)) {
    return _computeInfiniteLimit(expr, variable, isPositive: false);
  }

  return _computeFiniteLimit(expr, variable, point, direction: direction);
}

Expr _computeFiniteLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
}) {
  // Try direct substitution for continuous points
  try {
    final sub = expr.substitute(variable, point).simplify();
    if (_isWellDefinedFinite(sub)) {
      if (_isEverywhereContinuous(expr, variable)) {
        return sub;
      }
    }
  } catch (_) {
    // Falls through to Laurent series expansion
  }

  // Laurent series expansion via PowerSeries around local coordinate h = 0 (where x = point + h)
  const h = Variable('_h');
  final localExpr = expr.substitute(variable, Add(point, h)).simplify();

  // Check if localExpr is a rational fraction Div(p, q)
  if (localExpr is Div) {
    for (final ord in const [6, 14]) {
      try {
        final sNum = localExpr.left.toPowerSeries(
          '_h',
          point: RationalNumber.zero,
          order: ord,
        );
        final sDen = localExpr.right.toPowerSeries(
          '_h',
          point: RationalNumber.zero,
          order: ord,
        );
        final leadNum = sNum.leadingTerm;
        final leadDen = sDen.leadingTerm;
        if (leadNum != null && leadDen != null) {
          final m = leadNum.exponent - leadDen.exponent;
          final cm = Div(leadNum.coefficient, leadDen.coefficient).simplify();
          return _deduceLimitFromLaurentLeading(m, cm, direction, point);
        }
      } catch (e) {
        if (e is UnsupportedError &&
            (e.message?.contains('Two-sided limit') ?? false)) {
          rethrow;
        }
        break;
      }
    }
  }

  try {
    var series = localExpr.toPowerSeries(
      '_h',
      point: RationalNumber.zero,
      order: 6,
    );
    var lead = series.leadingTerm;
    if (lead == null) {
      series = localExpr.toPowerSeries(
        '_h',
        point: RationalNumber.zero,
        order: 14,
      );
      lead = series.leadingTerm;
    }
    if (lead == null) return RationalNumber.zero;
    return _deduceLimitFromLaurentLeading(
      lead.exponent,
      lead.coefficient,
      direction,
      point,
    );
  } catch (e) {
    if (e is UnsupportedError &&
        (e.message?.contains('Two-sided limit') ?? false)) {
      rethrow;
    }

    // Essential singularities or non-analytic points (such as Abs):
    // Transform h = +1/t (fromAbove) or h = -1/t (fromBelow) as t -> +oo
    const t = Variable('_t');
    if (direction == LimitDirection.fromAbove) {
      final transformed = expr
          .substitute(variable, Add(point, const Div(RationalNumber.one, t)))
          .simplify();
      return _computeInfiniteLimit(transformed, '_t', isPositive: true);
    }
    if (direction == LimitDirection.fromBelow) {
      final transformed = expr
          .substitute(variable, Sub(point, const Div(RationalNumber.one, t)))
          .simplify();
      return _computeInfiniteLimit(transformed, '_t', isPositive: true);
    }
    if (direction == LimitDirection.both) {
      final rightExpr = expr
          .substitute(variable, Add(point, const Div(RationalNumber.one, t)))
          .simplify();
      final leftExpr = expr
          .substitute(variable, Sub(point, const Div(RationalNumber.one, t)))
          .simplify();
      final rightLim = _computeInfiniteLimit(rightExpr, '_t', isPositive: true);
      final leftLim = _computeInfiniteLimit(leftExpr, '_t', isPositive: true);
      if (rightLim == leftLim) return rightLim;
      throw UnsupportedError(
        'Two-sided limit does not exist at $point: left ($leftLim) and right ($rightLim) limits differ',
      );
    }
    rethrow;
  }
}

Expr _deduceLimitFromLaurentLeading(
  int m,
  Expr cm,
  LimitDirection direction,
  Expr point,
) {
  if (m > 0) return RationalNumber.zero;
  if (m == 0) return cm;

  // m < 0: pole of order |m|
  final poleOrder = -m;
  final sign = _getSign(cm);

  if (poleOrder % 2 == 0) {
    // Even pole (e.g. 1/x^2): both sides approach the same infinity
    return sign > 0
        ? ConstantNumber.infinity
        : const Neg(ConstantNumber.infinity).simplify();
  }

  // Odd pole (e.g. 1/x): sides have opposite signs
  return switch (direction) {
    LimitDirection.fromAbove =>
      sign > 0
          ? ConstantNumber.infinity
          : const Neg(ConstantNumber.infinity).simplify(),
    LimitDirection.fromBelow =>
      sign > 0
          ? const Neg(ConstantNumber.infinity).simplify()
          : ConstantNumber.infinity,
    LimitDirection.both => throw UnsupportedError(
      'Two-sided limit does not exist at $point: left and right limits differ',
    ),
  };
}

Expr _computeInfiniteLimit(
  Expr expr,
  String variable, {
  required bool isPositive,
}) {
  if (!isPositive) {
    // x -> -oo: substitute x -> -x and evaluate limit as x -> +oo
    final reflected = expr
        .substitute(variable, Neg(Variable(variable)))
        .simplify();
    return _computeInfiniteLimit(reflected, variable, isPositive: true);
  }

  // Resolve Abs and Piecewise for large positive values of variable (x -> +oo)
  final resolved = _resolveAsymptoticAbsAndPiecewise(expr, variable).simplify();
  if (!resolved.dependsOn(variable)) return resolved;

  // Check for rational functions fast path
  final ratLim = _rationalFunctionLimitAtInfinity(resolved, variable);
  if (ratLim != null) return ratLim;

  // Dominik Gruntz MRV algorithm for exp-log expressions
  return _gruntzLimit(resolved, variable);
}

Expr _resolveAsymptoticAbsAndPiecewise(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return expr;
  final mapped = expr.mapChildren(
    (c) => _resolveAsymptoticAbsAndPiecewise(c, variable),
  );
  if (mapped is Abs) {
    final sign = _asymptoticSignAtInfinity(mapped.expr, variable);
    return sign >= 0 ? mapped.expr : Neg(mapped.expr).simplify();
  }
  if (mapped is Piecewise) {
    for (final (cond, branchExpr) in mapped.branches) {
      try {
        if (cond.evaluate({variable: 1e9}) == 1.0) {
          return branchExpr;
        }
      } catch (_) {}
    }
    if (mapped.otherwise != null) {
      return mapped.otherwise!;
    }
  }
  return mapped;
}

Expr? _rationalFunctionLimitAtInfinity(Expr expr, String variable) {
  Expr num;
  Expr den;
  if (expr is Div) {
    num = expr.left;
    den = expr.right;
  } else {
    num = expr;
    den = RationalNumber.one;
  }

  final degNum = _polynomialDegreeAndLead(num, variable);
  final degDen = _polynomialDegreeAndLead(den, variable);

  if (degNum == null || degDen == null) return null;

  final (dP, cP) = degNum;
  final (dQ, cQ) = degDen;

  if (dP < dQ) return RationalNumber.zero;
  if (dP == dQ) {
    return Div(cP, cQ).simplify();
  }

  // dP > dQ: approaches infinity
  final ratio = Div(cP, cQ).simplify();
  final sign = _getSign(ratio);
  return sign > 0
      ? ConstantNumber.infinity
      : const Neg(ConstantNumber.infinity).simplify();
}

(int, Expr)? _polynomialDegreeAndLead(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (0, expr.simplify());
  }

  final acc = MonomialAccumulator();
  acc.add(expr.simplify());

  var maxDegree = -1;
  Expr? leadCoeff;

  for (final entry in acc.rationalTerms.entries) {
    final (base, coeff) = (entry.key, entry.value);
    final deg = _monomialDegree(base, variable);
    if (deg == null) return null;
    if (deg > maxDegree) {
      maxDegree = deg;
      leadCoeff = RationalNumber.fraction(coeff);
    }
  }

  for (final entry in acc.realTerms.entries) {
    final (base, coeff) = (entry.key, entry.value);
    final deg = _monomialDegree(base, variable);
    if (deg == null) return null;
    if (deg > maxDegree) {
      maxDegree = deg;
      leadCoeff = RealNumber(coeff);
    }
  }

  if (maxDegree < 0) {
    return (0, RationalNumber.zero);
  }

  return (maxDegree, leadCoeff ?? RationalNumber.one);
}

int? _monomialDegree(Expr base, String variable) {
  if (base is Variable && base.name == variable) return 1;
  if (base is Pow &&
      base.base is Variable &&
      (base.base as Variable).name == variable &&
      base.exponent is RationalNumber &&
      (base.exponent as RationalNumber).isInteger) {
    final n = (base.exponent as RationalNumber).numerator;
    return n >= 0 ? n : null;
  }
  if (!base.dependsOn(variable)) return 0;
  return null;
}

Expr _gruntzLimit(Expr expr, String variable) {
  var f = expr.simplify();
  if (!f.dependsOn(variable)) return f;

  // Handle bounded oscillations multiplied by decaying factors (Squeeze Theorem)
  if (_containsUnboundedOscillation(f, variable)) {
    final squeezed = _trySqueezeBoundedOscillation(f, variable);
    if (squeezed != null) return squeezed;
    throw UnsupportedError('Limit does not exist due to oscillation');
  }

  // Gruntz logarithmic argument expansion: rewrite ln(x + e^x) -> x + ln(1 + x * e^-x)
  f = _expandLogArguments(f, variable);

  // Check for exponentials
  final expScale = _findDominantExpScale(f, variable);

  // If no exponentials, but contains Ln(variable), substitute variable = Exp(u)
  // This converts powers of logs and polynomials into exp-log form: ln(x) -> u, x -> e^u
  if (expScale == null && _containsLogOfVariable(f, variable)) {
    const u = Variable('_u');
    final transformed = f.substitute(variable, const Exp(u)).simplify();
    return _computeInfiniteLimit(transformed, '_u', isPositive: true);
  }

  if (expScale == null) {
    // MRV is {x}, scale representative is omega = 1/x
    const omega = Variable('_omega');
    final rewritten = f
        .substitute(variable, const Div(RationalNumber.one, omega))
        .simplify();

    for (final ord in const [4, 10]) {
      try {
        final series = rewritten.toPowerSeries(
          '_omega',
          point: RationalNumber.zero,
          order: ord,
        );
        final lead = series.leadingTerm;
        if (lead != null) {
          if (lead.exponent > 0) return RationalNumber.zero;
          if (lead.exponent == 0) {
            if (!lead.coefficient.dependsOn(variable)) return lead.coefficient;
            return computeLimit(
              lead.coefficient,
              variable,
              ConstantNumber.infinity,
            );
          }
          final sign = _asymptoticSignAtInfinity(lead.coefficient, variable);
          return sign > 0
              ? ConstantNumber.infinity
              : const Neg(ConstantNumber.infinity).simplify();
        }
      } catch (_) {
        break;
      }
    }

    throw UnsupportedError(
      'Limit could not be determined for $expr as $variable -> infinity',
    );
  }

  // Exponentials present: scale representative is omega = exp(-alpha * x^maxDeg)
  const omega = Variable('_omega');
  final rewritten = _rewriteExpInOmega(
    f,
    variable,
    omega,
    expScale.degree,
    expScale.alpha,
  ).simplify();

  for (final ord in const [4, 10]) {
    try {
      final series = rewritten.toPowerSeries(
        '_omega',
        point: RationalNumber.zero,
        order: ord,
      );
      final lead = series.leadingTerm;
      if (lead != null) {
        if (lead.exponent > 0) return RationalNumber.zero;
        if (lead.exponent < 0) {
          final sign = _asymptoticSignAtInfinity(lead.coefficient, variable);
          return sign > 0
              ? ConstantNumber.infinity
              : const Neg(ConstantNumber.infinity).simplify();
        }
        // lead.exponent == 0: evaluate limit of leading coefficient recursively
        return computeLimit(
          lead.coefficient,
          variable,
          ConstantNumber.infinity,
        );
      }
    } catch (_) {
      break;
    }
  }

  throw UnsupportedError(
    'Limit could not be determined for $expr as $variable -> infinity',
  );
}

Expr _rewriteExpInOmega(
  Expr expr,
  String variable,
  Expr omega,
  int targetDeg,
  Fraction alpha,
) {
  if (!expr.dependsOn(variable)) return expr;
  if (expr is Exp) {
    return _rewriteSingleExp(expr.expr, variable, omega, targetDeg, alpha);
  }
  return expr.mapChildren(
    (c) => _rewriteExpInOmega(c, variable, omega, targetDeg, alpha),
  );
}

Expr _rewriteSingleExp(
  Expr inner,
  String variable,
  Expr omega,
  int targetDeg,
  Fraction alpha,
) {
  if (!inner.dependsOn(variable)) {
    return Exp(_rewriteExpInOmega(inner, variable, omega, targetDeg, alpha));
  }

  final dom = _extractDominantPolynomialTerm(inner, variable);
  if (dom != null && dom.degree == targetDeg && dom.coeff != Fraction.zero) {
    final ratio = dom.coeff / alpha;
    if (ratio.denominator == 1) {
      final k = ratio.numerator;
      final omegaPower = k == 1
          ? Pow(omega, RationalNumber.negativeOne)
          : k == -1
          ? omega
          : Pow(omega, RationalNumber(-k));
      final remRewritten = _rewriteExpInOmega(
        dom.remainder,
        variable,
        omega,
        targetDeg,
        alpha,
      );
      final expRemainder = remRewritten == RationalNumber.zero
          ? RationalNumber.one
          : Exp(remRewritten);
      return Mul(omegaPower, expRemainder).simplify();
    }
  }

  return Exp(_rewriteExpInOmega(inner, variable, omega, targetDeg, alpha));
}

({int degree, Fraction coeff, Expr remainder})? _extractDominantPolynomialTerm(
  Expr expr,
  String variable,
) {
  final acc = MonomialAccumulator();
  acc.add(expr.simplify());

  var maxDeg = 0;
  var leadCoeff = Fraction.zero;
  Expr? leadKey;
  var isRealLead = false;

  for (final entry in acc.rationalTerms.entries) {
    final deg = _monomialDegree(entry.key, variable);
    if (deg != null && deg > maxDeg) {
      maxDeg = deg;
      leadCoeff = entry.value;
      leadKey = entry.key;
      isRealLead = false;
    }
  }

  for (final entry in acc.realTerms.entries) {
    final deg = _monomialDegree(entry.key, variable);
    if (deg != null && deg > maxDeg) {
      final frac = Fraction.fromDouble(entry.value, maxDenominator: 64);
      if ((entry.value - frac.toDouble()).abs() < 1e-12) {
        maxDeg = deg;
        leadCoeff = frac;
        leadKey = entry.key;
        isRealLead = true;
      }
    }
  }

  if (maxDeg == 0 || leadCoeff == Fraction.zero || leadKey == null) {
    return null;
  }

  final remainingTerms = <Expr>[];
  for (final entry in acc.rationalTerms.entries) {
    if (!isRealLead && entry.key == leadKey) continue;
    final term = entry.value == Fraction.one
        ? entry.key
        : Mul(RationalNumber.fraction(entry.value), entry.key);
    remainingTerms.add(term);
  }
  for (final entry in acc.realTerms.entries) {
    if (isRealLead && entry.key == leadKey) continue;
    final term = entry.value == 1.0
        ? entry.key
        : Mul(RealNumber(entry.value), entry.key);
    remainingTerms.add(term);
  }
  if (acc.constantRational != Fraction.zero) {
    remainingTerms.add(RationalNumber.fraction(acc.constantRational));
  }
  if (acc.constantReal != 0.0) {
    remainingTerms.add(RealNumber(acc.constantReal));
  }

  if (remainingTerms.isEmpty) {
    return (degree: maxDeg, coeff: leadCoeff, remainder: RationalNumber.zero);
  }
  var res = remainingTerms.first;
  for (var i = 1; i < remainingTerms.length; i++) {
    res = Add(res, remainingTerms[i]);
  }
  return (degree: maxDeg, coeff: leadCoeff, remainder: res.simplify());
}

Expr _expandLogArguments(Expr expr, String variable) => switch (expr) {
  Ln(expr: Add(:final left, :final right)) =>
    _tryFactorLogAdd(left, right, variable) ?? Ln(Add(left, right)),
  _ => expr.mapChildren((c) => _expandLogArguments(c, variable)),
};

Expr? _tryFactorLogAdd(Expr a, Expr b, String variable) {
  if (b is Exp && b.expr.dependsOn(variable)) {
    final dom = _extractDominantPolynomialTerm(b.expr, variable);
    if (dom != null && dom.coeff > Fraction.zero) {
      final negU = Neg(b.expr).simplify();
      return Add(
        b.expr,
        Ln(Add(RationalNumber.one, Mul(a, Exp(negU)))),
      ).simplify();
    }
  }
  if (a is Exp && a.expr.dependsOn(variable)) {
    final dom = _extractDominantPolynomialTerm(a.expr, variable);
    if (dom != null && dom.coeff > Fraction.zero) {
      final negU = Neg(a.expr).simplify();
      return Add(
        a.expr,
        Ln(Add(RationalNumber.one, Mul(b, Exp(negU)))),
      ).simplify();
    }
  }
  return null;
}

({int degree, Fraction alpha})? _findDominantExpScale(
  Expr expr,
  String variable,
) {
  var maxDeg = 0;
  final coeffsAtMax = <Fraction>[];

  void scan(Expr e) {
    if (e is Exp && e.expr.dependsOn(variable)) {
      final dom = _extractDominantPolynomialTerm(e.expr, variable);
      if (dom != null && dom.coeff != Fraction.zero) {
        if (dom.degree > maxDeg) {
          maxDeg = dom.degree;
          coeffsAtMax
            ..clear()
            ..add(dom.coeff.abs());
        } else if (dom.degree == maxDeg) {
          coeffsAtMax.add(dom.coeff.abs());
        }
      }
    }
    switch (e) {
      case BinaryExpr(:final left, :final right):
        scan(left);
        scan(right);
      case UnaryExpr(:final expr):
        scan(expr);
      case Piecewise(:final branches, :final otherwise):
        for (final (cond, b) in branches) {
          scan(cond);
          scan(b);
        }
        if (otherwise != null) scan(otherwise);
      case Number() || Variable() || OrderTerm():
        break;
    }
  }

  scan(expr);
  if (maxDeg == 0 || coeffsAtMax.isEmpty) return null;

  var numGcd = coeffsAtMax.first.numerator.abs();
  var denLcm = coeffsAtMax.first.denominator;
  for (var i = 1; i < coeffsAtMax.length; i++) {
    final c = coeffsAtMax[i];
    numGcd = numGcd.gcd(c.numerator.abs());
    final g = denLcm.gcd(c.denominator);
    denLcm = (denLcm ~/ g) * c.denominator;
  }
  return (degree: maxDeg, alpha: Fraction(numGcd, denLcm));
}

bool _containsLogOfVariable(Expr expr, String variable) =>
    expr.anyNode((e) => e is Ln && e.expr.dependsOn(variable));

bool _containsUnboundedOscillation(Expr expr, String variable) =>
    expr.anyNode((e) {
      if ((e is Sin || e is Cos || e is Tan) &&
          (e as UnaryExpr).expr.dependsOn(variable)) {
        try {
          final lim = computeLimit(e.expr, variable, ConstantNumber.infinity);
          return _isPositiveInfinity(lim) || _isNegativeInfinity(lim);
        } catch (_) {
          return true;
        }
      }
      return false;
    });

Expr? _trySqueezeBoundedOscillation(Expr expr, String variable) {
  final numFactors = <Expr>[];
  final denFactors = <Expr>[];

  void collect(Expr e, List<Expr> target) {
    if (e is Mul) {
      collect(e.left, target);
      collect(e.right, target);
    } else if (e is Neg) {
      target.add(RationalNumber.negativeOne);
      collect(e.expr, target);
    } else {
      target.add(e);
    }
  }

  if (expr is Div) {
    collect(expr.left, numFactors);
    collect(expr.right, denFactors);
  } else if (expr is Mul || expr is Neg) {
    collect(expr, numFactors);
  } else {
    return null;
  }

  // Separate bounded oscillating factors (Sin, Cos, Pow(Sin/Cos, k>0)) in numerator
  final nonOscNum = <Expr>[];
  var hasOsc = false;
  for (final f in numFactors) {
    if (_isBoundedOscillator(f, variable)) {
      hasOsc = true;
    } else {
      nonOscNum.add(f);
    }
  }
  if (!hasOsc) return null;

  // Denominator must not contain oscillating factors that vanish at infinity
  for (final f in denFactors) {
    if (_containsUnboundedOscillation(f, variable)) return null;
  }

  Expr buildProduct(List<Expr> list) {
    if (list.isEmpty) return RationalNumber.one;
    var res = list.first;
    for (var i = 1; i < list.length; i++) {
      res = Mul(res, list[i]);
    }
    return res;
  }

  final envelope = Div(
    buildProduct(nonOscNum),
    buildProduct(denFactors),
  ).simplify();
  try {
    final envLim = computeLimit(envelope, variable, ConstantNumber.infinity);
    if (envLim is RationalNumber && envLim.isZero) {
      return RationalNumber.zero;
    }
    if (envLim is RealNumber && envLim.value == 0.0) {
      return RationalNumber.zero;
    }
  } catch (_) {}
  return null;
}

bool _isBoundedOscillator(Expr expr, String variable) {
  if (expr is Sin || expr is Cos) {
    return _containsUnboundedOscillation(expr, variable);
  }
  if (expr is Pow &&
      expr.exponent is RationalNumber &&
      (expr.exponent as RationalNumber).numerator > 0) {
    return _isBoundedOscillator(expr.base, variable);
  }
  return false;
}

bool _isEverywhereContinuous(Expr expr, String variable) => switch (expr) {
  Number() || Variable() => true,
  Add(:final left, :final right) ||
  Sub(:final left, :final right) ||
  Mul(:final left, :final right) =>
    _isEverywhereContinuous(left, variable) &&
        _isEverywhereContinuous(right, variable),
  Neg(:final expr) ||
  Sin(:final expr) ||
  Cos(:final expr) ||
  Sinh(:final expr) ||
  Cosh(:final expr) ||
  Exp(:final expr) => _isEverywhereContinuous(expr, variable),
  _ => false,
};

bool _isWellDefinedFinite(Expr expr) {
  if (expr is RationalNumber) return true;
  if (expr is RealNumber && expr.value.isFinite) return true;
  if (expr is ConstantNumber && expr.isReal && expr.value.isFinite) return true;
  if (!expr.freeVariables.isNotEmpty) {
    try {
      final v = expr.evaluate(const {});
      return v.isFinite;
    } catch (_) {}
  }
  return false;
}

int _getSign(Expr expr) {
  final s = expr.simplify();
  if (s is RationalNumber) {
    return s.numerator > 0 ? 1 : (s.numerator < 0 ? -1 : 0);
  }
  if (s is RealNumber) {
    return s.value > 0.0 ? 1 : (s.value < 0.0 ? -1 : 0);
  }
  if (s is Neg) return -_getSign(s.expr);
  if (s.freeVariables.isEmpty) {
    try {
      final v = s.evaluate(const {});
      if (v.isFinite && v != 0.0) return v > 0.0 ? 1 : -1;
    } catch (_) {}
  }
  return 1;
}

int _asymptoticSignAtInfinity(Expr expr, String variable) {
  final s = expr.simplify();
  if (!s.dependsOn(variable)) return _getSign(s);
  if (s is Neg) return -_asymptoticSignAtInfinity(s.expr, variable);
  if (s is Exp) return 1;

  final poly = _polynomialDegreeAndLead(s, variable);
  if (poly != null) {
    return _getSign(poly.$2);
  }

  try {
    final val1 = s.evaluate({variable: 100.0});
    if (val1.isFinite && val1 != 0.0) return val1 > 0.0 ? 1 : -1;
    final val2 = s.evaluate({variable: 1000.0});
    if (val2.isFinite && val2 != 0.0) return val2 > 0.0 ? 1 : -1;
  } catch (_) {}

  return 1;
}

bool _isPositiveInfinity(Expr expr) {
  if (expr is RealNumber && expr.value == double.infinity) return true;
  if (expr is ConstantNumber &&
      (expr.name == 'oo' || expr.name == 'infinity')) {
    return true;
  }
  if (expr is Variable && (expr.name == 'oo' || expr.name == 'infinity')) {
    return true;
  }
  return false;
}

bool _isNegativeInfinity(Expr expr) {
  if (expr is RealNumber && expr.value == double.negativeInfinity) return true;
  if (expr is Neg && _isPositiveInfinity(expr.expr)) return true;
  if (expr is Mul) {
    if (expr.left is RationalNumber &&
        (expr.left as RationalNumber).isNegativeOne &&
        _isPositiveInfinity(expr.right)) {
      return true;
    }
    if (expr.right is RationalNumber &&
        (expr.right as RationalNumber).isNegativeOne &&
        _isPositiveInfinity(expr.left)) {
      return true;
    }
  }
  return false;
}
