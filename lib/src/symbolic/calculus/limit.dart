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
    try {
      final sNum = localExpr.left.toPowerSeries(
        '_h',
        point: RationalNumber.zero,
        order: 6,
      );
      final sDen = localExpr.right.toPowerSeries(
        '_h',
        point: RationalNumber.zero,
        order: 6,
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
    }
  }

  try {
    final series = localExpr.toPowerSeries(
      '_h',
      point: RationalNumber.zero,
      order: 6,
    );
    final lead = series.leadingTerm;
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

    // Essential singularities at the origin or expansion point:
    // Transform h = 1/t as t -> +oo
    if (direction == LimitDirection.fromAbove ||
        (point is RationalNumber && point.isZero)) {
      const t = Variable('_t');
      final transformed = expr
          .substitute(variable, Add(point, const Div(RationalNumber.one, t)))
          .simplify();
      return _computeInfiniteLimit(transformed, '_t', isPositive: true);
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

  // Check for rational functions fast path
  final ratLim = _rationalFunctionLimitAtInfinity(expr, variable);
  if (ratLim != null) return ratLim;

  // Dominik Gruntz MRV algorithm for exp-log expressions
  return _gruntzLimit(expr, variable);
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
    return (base.exponent as RationalNumber).numerator;
  }
  if (!base.dependsOn(variable)) return 0;
  return null;
}

Expr _gruntzLimit(Expr expr, String variable) {
  var f = expr.simplify();
  if (!f.dependsOn(variable)) return f;

  // Check for unbounded oscillations
  if (_containsUnboundedOscillation(f, variable)) {
    throw UnsupportedError('Limit does not exist due to oscillation');
  }

  // Gruntz logarithmic argument expansion: rewrite ln(x + e^x) -> x + ln(1 + x * e^-x)
  f = _expandLogArguments(f, variable);

  // Check for exponentials
  final hasExp = _hasExponentialGrowth(f, variable);

  // If no exponentials, but contains Ln(variable), substitute variable = Exp(u)
  // This converts powers of logs and polynomials into exp-log form: ln(x) -> u, x -> e^u
  if (!hasExp && _containsLogOfVariable(f, variable)) {
    const u = Variable('_u');
    final transformed = f.substitute(variable, const Exp(u)).simplify();
    return _computeInfiniteLimit(transformed, '_u', isPositive: true);
  }

  if (!hasExp) {
    // MRV is {x}, scale representative is omega = 1/x
    const omega = Variable('_omega');
    final rewritten = f
        .substitute(variable, const Div(RationalNumber.one, omega))
        .simplify();

    try {
      final series = rewritten.toPowerSeries(
        '_omega',
        point: RationalNumber.zero,
        order: 4,
      );
      final lead = series.leadingTerm;
      if (lead != null) {
        if (lead.exponent > 0) return RationalNumber.zero;
        if (lead.exponent == 0) return lead.coefficient;
        final sign = _asymptoticSignAtInfinity(lead.coefficient, variable);
        return sign > 0
            ? ConstantNumber.infinity
            : const Neg(ConstantNumber.infinity).simplify();
      }
    } catch (_) {}

    return f;
  }

  // Exponentials present: scale representative is omega = e^-x
  const omega = Variable('_omega');
  final rewritten = _rewriteExpInOmega(f, variable, omega).simplify();

  try {
    final series = rewritten.toPowerSeries(
      '_omega',
      point: RationalNumber.zero,
      order: 4,
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
      return computeLimit(lead.coefficient, variable, ConstantNumber.infinity);
    }
  } catch (_) {}

  return f;
}

Expr _rewriteExpInOmega(Expr expr, String variable, Expr omega) =>
    switch (expr) {
      Number() || Variable() || OrderTerm() => expr,
      Exp(:final expr) => _rewriteSingleExp(expr, variable, omega),
      Add(:final left, :final right) => Add(
        _rewriteExpInOmega(left, variable, omega),
        _rewriteExpInOmega(right, variable, omega),
      ),
      Sub(:final left, :final right) => Sub(
        _rewriteExpInOmega(left, variable, omega),
        _rewriteExpInOmega(right, variable, omega),
      ),
      Mul(:final left, :final right) => Mul(
        _rewriteExpInOmega(left, variable, omega),
        _rewriteExpInOmega(right, variable, omega),
      ),
      Div(:final left, :final right) => Div(
        _rewriteExpInOmega(left, variable, omega),
        _rewriteExpInOmega(right, variable, omega),
      ),
      Pow(:final base, :final exponent) => Pow(
        _rewriteExpInOmega(base, variable, omega),
        _rewriteExpInOmega(exponent, variable, omega),
      ),
      Neg(:final expr) => Neg(_rewriteExpInOmega(expr, variable, omega)),
      Ln(:final expr) => Ln(_rewriteExpInOmega(expr, variable, omega)),
      Sin(:final expr) => Sin(_rewriteExpInOmega(expr, variable, omega)),
      Cos(:final expr) => Cos(_rewriteExpInOmega(expr, variable, omega)),
      Tan(:final expr) => Tan(_rewriteExpInOmega(expr, variable, omega)),
      Sinh(:final expr) => Sinh(_rewriteExpInOmega(expr, variable, omega)),
      Cosh(:final expr) => Cosh(_rewriteExpInOmega(expr, variable, omega)),
      Tanh(:final expr) => Tanh(_rewriteExpInOmega(expr, variable, omega)),
      Asin(:final expr) => Asin(_rewriteExpInOmega(expr, variable, omega)),
      Acos(:final expr) => Acos(_rewriteExpInOmega(expr, variable, omega)),
      Atan(:final expr) => Atan(_rewriteExpInOmega(expr, variable, omega)),
      Abs(:final expr) => Abs(_rewriteExpInOmega(expr, variable, omega)),
    };

Expr _rewriteSingleExp(Expr inner, String variable, Expr omega) {
  if (!inner.dependsOn(variable)) {
    return Exp(_rewriteExpInOmega(inner, variable, omega));
  }

  final (k, remainder) = _extractLinearVariableCoeff(inner, variable);
  if (k != 0) {
    final omegaPower = k == 1
        ? Pow(omega, RationalNumber.negativeOne)
        : k == -1
        ? omega
        : Pow(omega, RationalNumber(-k));
    final remRewritten = _rewriteExpInOmega(remainder, variable, omega);
    final expRemainder = remRewritten == RationalNumber.zero
        ? RationalNumber.one
        : Exp(remRewritten);
    return Mul(omegaPower, expRemainder).simplify();
  }

  return Exp(_rewriteExpInOmega(inner, variable, omega));
}

(int, Expr) _extractLinearVariableCoeff(Expr expr, String variable) {
  final acc = MonomialAccumulator();
  acc.add(expr.simplify());

  var k = 0;
  final remainingTerms = <Expr>[];

  for (final entry in acc.rationalTerms.entries) {
    if (entry.key is Variable && (entry.key as Variable).name == variable) {
      if (entry.value.denominator == 1) {
        k += entry.value.numerator;
      }
    } else {
      final term = entry.value == Fraction.one
          ? entry.key
          : Mul(RationalNumber.fraction(entry.value), entry.key);
      remainingTerms.add(term);
    }
  }

  if (acc.constantRational != Fraction.zero) {
    remainingTerms.add(RationalNumber.fraction(acc.constantRational));
  }

  if (remainingTerms.isEmpty) return (k, RationalNumber.zero);
  var res = remainingTerms.first;
  for (var i = 1; i < remainingTerms.length; i++) {
    res = Add(res, remainingTerms[i]);
  }
  return (k, res.simplify());
}

Expr _expandLogArguments(Expr expr, String variable) => switch (expr) {
  Ln(expr: Add(:final left, :final right)) =>
    _tryFactorLogAdd(left, right, variable) ?? Ln(Add(left, right)),
  Add(:final left, :final right) => Add(
    _expandLogArguments(left, variable),
    _expandLogArguments(right, variable),
  ),
  Sub(:final left, :final right) => Sub(
    _expandLogArguments(left, variable),
    _expandLogArguments(right, variable),
  ),
  Mul(:final left, :final right) => Mul(
    _expandLogArguments(left, variable),
    _expandLogArguments(right, variable),
  ),
  Div(:final left, :final right) => Div(
    _expandLogArguments(left, variable),
    _expandLogArguments(right, variable),
  ),
  Neg(:final expr) => Neg(_expandLogArguments(expr, variable)),
  _ => expr,
};

Expr? _tryFactorLogAdd(Expr a, Expr b, String variable) {
  if (b is Exp && b.expr.dependsOn(variable)) {
    final (k, _) = _extractLinearVariableCoeff(b.expr, variable);
    if (k > 0) {
      final negU = Neg(b.expr).simplify();
      return Add(
        b.expr,
        Ln(Add(RationalNumber.one, Mul(a, Exp(negU)))),
      ).simplify();
    }
  }
  if (a is Exp && a.expr.dependsOn(variable)) {
    final (k, _) = _extractLinearVariableCoeff(a.expr, variable);
    if (k > 0) {
      final negU = Neg(a.expr).simplify();
      return Add(
        a.expr,
        Ln(Add(RationalNumber.one, Mul(b, Exp(negU)))),
      ).simplify();
    }
  }
  return null;
}

bool _hasExponentialGrowth(Expr expr, String variable) {
  var found = false;
  void scan(Expr e) {
    if (e is Exp && e.expr.dependsOn(variable)) {
      final (k, _) = _extractLinearVariableCoeff(e.expr, variable);
      if (k != 0) found = true;
    }
    switch (e) {
      case Add(:final left, :final right):
      case Sub(:final left, :final right):
      case Mul(:final left, :final right):
      case Div(:final left, :final right):
        scan(left);
        scan(right);
      case Pow(:final base, :final exponent):
        scan(base);
        scan(exponent);
      case Neg(:final expr):
      case Exp(:final expr):
      case Ln(:final expr):
      case Sin(:final expr):
      case Cos(:final expr):
      case Tan(:final expr):
      case Sinh(:final expr):
      case Cosh(:final expr):
      case Tanh(:final expr):
      case Asin(:final expr):
      case Acos(:final expr):
      case Atan(:final expr):
      case Abs(:final expr):
        scan(expr);
      case Number() || Variable() || OrderTerm():
        break;
    }
  }

  scan(expr);
  return found;
}

bool _containsLogOfVariable(Expr expr, String variable) {
  var found = false;
  void scan(Expr e) {
    if (e is Ln && e.expr.dependsOn(variable)) {
      found = true;
    }
    switch (e) {
      case Add(:final left, :final right):
      case Sub(:final left, :final right):
      case Mul(:final left, :final right):
      case Div(:final left, :final right):
        scan(left);
        scan(right);
      case Pow(:final base, :final exponent):
        scan(base);
        scan(exponent);
      case Neg(:final expr):
      case Exp(:final expr):
      case Ln(:final expr):
      case Sin(:final expr):
      case Cos(:final expr):
      case Tan(:final expr):
      case Sinh(:final expr):
      case Cosh(:final expr):
      case Tanh(:final expr):
      case Asin(:final expr):
      case Acos(:final expr):
      case Atan(:final expr):
      case Abs(:final expr):
        scan(expr);
      case Number() || Variable() || OrderTerm():
        break;
    }
  }

  scan(expr);
  return found;
}

bool _containsUnboundedOscillation(Expr expr, String variable) {
  if (expr is Sin && expr.expr.dependsOn(variable)) return true;
  if (expr is Cos && expr.expr.dependsOn(variable)) return true;
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
  if (expr is ConstantNumber && expr.value.isFinite) return true;
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
  return 1;
}

int _asymptoticSignAtInfinity(Expr expr, String variable) {
  final s = expr.simplify();
  if (s is RationalNumber) {
    return s.numerator > 0 ? 1 : (s.numerator < 0 ? -1 : 0);
  }
  if (s is RealNumber) {
    return s.value > 0.0 ? 1 : (s.value < 0.0 ? -1 : 0);
  }
  if (s is Neg) return -_asymptoticSignAtInfinity(s.expr, variable);

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
