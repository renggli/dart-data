import '../algebra/approximate.dart';
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
  /// final lim = expr.limit('x', IntegerNumber.zero); // 1
  /// ```
  Expr limit(
    String variable,
    Expr point, {
    LimitDirection direction = LimitDirection.both,
  }) => computeLimit(this, variable, point, direction: direction);
}

final Expr _negInfinity = Mul(const [
  IntegerNumber.negativeOne,
  Constant.infinity,
], isSimplified: true);

/// Computes the symbolic limit of [expr] as [variable] approaches [point].
Expr computeLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
}) {
  if (!expr.dependsOn(variable)) return expr.simplify();

  if (expr case Pow(:final base, :final exponent)
      when base.dependsOn(variable) && exponent.dependsOn(variable)) {
    final logForm = exponent * Ln(base);
    final innerLim = computeLimit(
      logForm,
      variable,
      point,
      direction: direction,
    );
    if (_isPositiveInfinity(innerLim)) return Constant.infinity;
    if (_isNegativeInfinity(innerLim)) return IntegerNumber.zero;
    return Pow(Constant.e, innerLim).simplify();
  }

  if (expr case Pow(base: Constant.e, :final exponent)) {
    try {
      final innerLim = computeLimit(
        exponent,
        variable,
        point,
        direction: direction,
      );
      if (_isPositiveInfinity(innerLim)) return Constant.infinity;
      if (_isNegativeInfinity(innerLim)) return IntegerNumber.zero;
      return Pow(Constant.e, innerLim).simplify();
    } on Object {
      // Fall through
    }
  }

  if (expr case Ln(expr: final inner)) {
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
      );
      if (_isPositiveInfinity(innerLim)) return Constant.infinity;
      if (innerLim is Number && innerLim.isZero) {
        return _negInfinity;
      }
      if (_isWellDefinedFinite(innerLim)) {
        return Ln(innerLim).simplify();
      }
    } on Object {
      // Fall through
    }
  }

  if (expr
      case Sin(expr: final inner) ||
          Cos(expr: final inner) ||
          Atan(expr: final inner) ||
          Tanh(expr: final inner)) {
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
      );
      if (_isWellDefinedFinite(innerLim)) {
        return expr.mapChildren((_) => innerLim).simplify();
      }
      if (_isPositiveInfinity(innerLim) || _isNegativeInfinity(innerLim)) {
        return switch (expr) {
          Atan() =>
            _isPositiveInfinity(innerLim)
                ? (Constant.pi / IntegerNumber.two).simplify()
                : (-(Constant.pi / IntegerNumber.two)).simplify(),
          Tanh() =>
            _isPositiveInfinity(innerLim)
                ? IntegerNumber.one
                : IntegerNumber.negativeOne,
          _ => throw UnsupportedError(
            'Limit does not exist due to oscillation',
          ),
        };
      }
    } on UnsupportedError {
      rethrow;
    } on Object {
      // Fall through
    }
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
  try {
    final sub = expr.substitute(variable, point).simplify();
    if (_isWellDefinedFinite(sub)) {
      if (_isEverywhereContinuous(expr, variable)) {
        return sub;
      }
    }
  } on Object {
    // Falls through to Laurent series expansion
  }

  const h = Variable('_h');
  final localExpr = expr.substitute(variable, point + h).simplify();

  final (numExpr, denExpr) = splitNumeratorDenominator(localExpr);
  if (denExpr != IntegerNumber.one) {
    for (final ord in const [6, 14]) {
      try {
        final sNum = numExpr.toPowerSeries(
          '_h',
          point: IntegerNumber.zero,
          order: ord,
        );
        final sDen = denExpr.toPowerSeries(
          '_h',
          point: IntegerNumber.zero,
          order: ord,
        );
        if ((sNum.leadingTerm, sDen.leadingTerm) case (
          final leadNum?,
          final leadDen?,
        )) {
          final m = leadNum.exponent - leadDen.exponent;
          final cm = (leadNum.coefficient / leadDen.coefficient).simplify();
          return _deduceLimitFromLaurentLeading(m, cm, direction, point);
        }
      } on Object catch (e) {
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
      point: IntegerNumber.zero,
      order: 6,
    );
    var lead = series.leadingTerm;
    if (lead == null) {
      series = localExpr.toPowerSeries(
        '_h',
        point: IntegerNumber.zero,
        order: 14,
      );
      lead = series.leadingTerm;
    }
    if (lead == null) return IntegerNumber.zero;
    return _deduceLimitFromLaurentLeading(
      lead.exponent,
      lead.coefficient,
      direction,
      point,
    );
  } on Object catch (e) {
    if (e is UnsupportedError &&
        (e.message?.contains('Two-sided limit') ?? false)) {
      rethrow;
    }

    const t = Variable('_t');
    final invT = IntegerNumber.one / t;
    return switch (direction) {
      LimitDirection.fromAbove => _computeInfiniteLimit(
        expr.substitute(variable, point + invT).simplify(),
        '_t',
        isPositive: true,
      ),
      LimitDirection.fromBelow => _computeInfiniteLimit(
        expr.substitute(variable, point - invT).simplify(),
        '_t',
        isPositive: true,
      ),
      LimitDirection.both => () {
        final rightExpr = expr.substitute(variable, point + invT).simplify();
        final leftExpr = expr.substitute(variable, point - invT).simplify();
        final rightLim = _computeInfiniteLimit(
          rightExpr,
          '_t',
          isPositive: true,
        );
        final leftLim = _computeInfiniteLimit(leftExpr, '_t', isPositive: true);
        if (rightLim == leftLim) return rightLim;
        throw UnsupportedError(
          'Two-sided limit does not exist at $point: left ($leftLim) and right ($rightLim) limits differ',
        );
      }(),
    };
  }
}

Expr _deduceLimitFromLaurentLeading(
  int m,
  Expr cm,
  LimitDirection direction,
  Expr point,
) {
  if (m > 0) return IntegerNumber.zero;
  if (m == 0) return cm;

  final poleOrder = -m;
  final sign = _getSign(cm);

  if (poleOrder.isEven) {
    return sign > 0 ? Constant.infinity : _negInfinity;
  }

  return switch (direction) {
    LimitDirection.fromAbove => sign > 0 ? Constant.infinity : _negInfinity,
    LimitDirection.fromBelow => sign > 0 ? _negInfinity : Constant.infinity,
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
    final reflected = expr.substitute(variable, -Variable(variable)).simplify();
    return _computeInfiniteLimit(reflected, variable, isPositive: true);
  }

  final resolved = _resolveAsymptoticAbsAndPiecewise(expr, variable).simplify();
  if (!resolved.dependsOn(variable)) return resolved;

  final ratLim = _rationalFunctionLimitAtInfinity(resolved, variable);
  if (ratLim != null) return ratLim;

  return _gruntzLimit(resolved, variable);
}

Expr _resolveAsymptoticAbsAndPiecewise(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) return expr;
  final mapped = expr.mapChildren(
    (c) => _resolveAsymptoticAbsAndPiecewise(c, variable),
  );
  if (mapped case Abs(expr: final inner)) {
    final sign = _asymptoticSignAtInfinity(inner, variable);
    return sign >= 0 ? inner : (-inner).simplify();
  }
  if (mapped case Piecewise(:final branches, :final otherwise)) {
    for (final (cond, branchExpr) in branches) {
      try {
        if (cond.evaluate({variable: 1e9}) == 1.0) {
          return branchExpr;
        }
      } on Object {
        // Ignore
      }
    }
    if (otherwise != null) {
      return otherwise;
    }
  }
  return mapped;
}

Expr? _rationalFunctionLimitAtInfinity(Expr expr, String variable) {
  final (num, den) = splitNumeratorDenominator(expr);

  if ((
        _polynomialDegreeAndLead(num, variable),
        _polynomialDegreeAndLead(den, variable),
      )
      case ((final dP, final cP), (final dQ, final cQ))) {
    if (dP < dQ) return IntegerNumber.zero;
    if (dP == dQ) {
      return (cP / cQ).simplify();
    }

    final ratio = (cP / cQ).simplify();
    final sign = _getSign(ratio);
    return sign > 0 ? Constant.infinity : _negInfinity;
  }

  return null;
}

(int, Expr)? _polynomialDegreeAndLead(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (0, expr.simplify());
  }

  final acc = MonomialAccumulator();
  acc.add(expr.simplify());

  var maxDegree = -1;
  Expr? leadCoeff;

  for (final entry in acc.terms.entries) {
    final (base, coeff) = (entry.key, entry.value);
    final deg = _monomialDegree(base, variable);
    if (deg == null) return null;
    if (deg > maxDegree) {
      maxDegree = deg;
      leadCoeff = coeff;
    }
  }

  return (maxDegree, leadCoeff ?? IntegerNumber.one);
}

int? _monomialDegree(Expr base, String variable) => switch (base) {
  Variable(:final name) when name == variable => 1,
  Pow(base: Variable(:final name), exponent: IntegerNumber(:final asInt?))
      when name == variable && asInt >= 0 =>
    asInt,
  _ when !base.dependsOn(variable) => 0,
  _ => null,
};

Expr _gruntzLimit(Expr expr, String variable) {
  var f = expr.simplify();
  if (!f.dependsOn(variable)) return f;

  if (_containsUnboundedOscillation(f, variable)) {
    final squeezed = _trySqueezeBoundedOscillation(f, variable);
    if (squeezed != null) return squeezed;
    throw UnsupportedError('Limit does not exist due to oscillation');
  }

  f = _expandLogArguments(f, variable);

  final expScale = _findDominantExpScale(f, variable);

  if (expScale == null && _containsLogOfVariable(f, variable)) {
    const u = Variable('_u');
    final transformed = f.substitute(variable, Pow(Constant.e, u)).simplify();
    return _computeInfiniteLimit(transformed, '_u', isPositive: true);
  }

  if (expScale == null) {
    const omega = Variable('_omega');
    final rewritten = f
        .substitute(variable, IntegerNumber.one / omega)
        .simplify();

    for (final ord in const [4, 10]) {
      try {
        final series = rewritten.toPowerSeries(
          '_omega',
          point: IntegerNumber.zero,
          order: ord,
        );
        final lead = series.leadingTerm;
        if (lead != null) {
          if (lead.exponent > 0) return IntegerNumber.zero;
          if (lead.exponent == 0) return lead.coefficient;
          final sign = _asymptoticSignAtInfinity(lead.coefficient, variable);
          return sign > 0 ? Constant.infinity : _negInfinity;
        }
      } on Object {
        break;
      }
    }

    throw UnsupportedError(
      'Limit could not be determined for $expr as $variable -> infinity',
    );
  }

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
        point: IntegerNumber.zero,
        order: ord,
      );
      final lead = series.leadingTerm;
      if (lead != null) {
        if (lead.exponent > 0) return IntegerNumber.zero;
        if (lead.exponent < 0) {
          final sign = _asymptoticSignAtInfinity(lead.coefficient, variable);
          return sign > 0 ? Constant.infinity : _negInfinity;
        }
        return computeLimit(lead.coefficient, variable, Constant.infinity);
      }
    } on Object {
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
  RationalNumber alpha,
) {
  if (!expr.dependsOn(variable)) return expr;
  if (expr case Pow(base: Constant.e, :final exponent)) {
    return _rewriteSingleExp(exponent, variable, omega, targetDeg, alpha);
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
  RationalNumber alpha,
) {
  if (_extractDominantPolynomialTerm(inner, variable)
      case (:final degree, :final coeff, :final remainder)
      when degree == targetDeg && !coeff.isZero) {
    if (coeff.divRational(alpha) case IntegerNumber(:final asInt?)) {
      final omegaPower = switch (asInt) {
        1 => Pow(omega, IntegerNumber.negativeOne),
        -1 => omega,
        _ => Pow(omega, IntegerNumber.of(-asInt)),
      };
      final remRewritten = _rewriteExpInOmega(
        remainder,
        variable,
        omega,
        targetDeg,
        alpha,
      );
      final expRemainder = (remRewritten is Number && remRewritten.isZero)
          ? IntegerNumber.one
          : Pow(Constant.e, remRewritten);
      return (omegaPower * expRemainder).simplify();
    }
  }

  return Pow(
    Constant.e,
    _rewriteExpInOmega(inner, variable, omega, targetDeg, alpha),
  );
}

({int degree, RationalNumber coeff, Expr remainder})?
_extractDominantPolynomialTerm(Expr expr, String variable) {
  final acc = MonomialAccumulator();
  acc.add(expr.simplify());

  var maxDeg = 0;
  RationalNumber leadCoeff = IntegerNumber.zero;
  Expr? leadKey;

  for (final entry in acc.terms.entries) {
    final deg = _monomialDegree(entry.key, variable);
    if (deg != null && deg > maxDeg) {
      switch (entry.value) {
        case final RationalNumber val:
          maxDeg = deg;
          leadCoeff = val;
          leadKey = entry.key;
        case final RealNumber val:
          if (val.rationalize(maxDenominator: 64) case final RationalNumber rat
              when (val.value - rat.toDouble()).abs() < 1e-12) {
            maxDeg = deg;
            leadCoeff = rat;
            leadKey = entry.key;
          }
        case ComplexNumber():
          break;
      }
    }
  }

  if (maxDeg == 0 || leadCoeff.isZero || leadKey == null) {
    return null;
  }

  final remainingTerms = <Expr>[];
  for (final entry in acc.terms.entries) {
    if (entry.key == leadKey) continue;
    final term = entry.value.isOne ? entry.key : entry.value * entry.key;
    remainingTerms.add(term);
  }
  if (!acc.constant.isZero) {
    remainingTerms.add(acc.constant);
  }

  if (remainingTerms.isEmpty) {
    return (degree: maxDeg, coeff: leadCoeff, remainder: IntegerNumber.zero);
  }
  return (
    degree: maxDeg,
    coeff: leadCoeff,
    remainder: Add(remainingTerms).simplify(),
  );
}

Expr _expandLogArguments(Expr expr, String variable) => switch (expr) {
  Ln(expr: Add(terms: [final a, final b])) =>
    _tryFactorLogAdd(a, b, variable) ?? expr,
  _ => expr.mapChildren((c) => _expandLogArguments(c, variable)),
};

Expr? _tryFactorLogAdd(Expr a, Expr b, String variable) {
  if (b case Pow(base: Constant.e, :final exponent)
      when exponent.dependsOn(variable)) {
    final dom = _extractDominantPolynomialTerm(exponent, variable);
    if (dom != null && dom.coeff.sign > 0) {
      final negU = (-exponent).simplify();
      return (exponent + Ln(IntegerNumber.one + a * Pow(Constant.e, negU)))
          .simplify();
    }
  }
  return null;
}

({int degree, RationalNumber alpha})? _findDominantExpScale(
  Expr expr,
  String variable,
) {
  var maxDeg = 0;
  final coeffsAtMax = <RationalNumber>[];

  void scan(Expr e) {
    if (e case Pow(base: Constant.e, :final exponent)
        when exponent.dependsOn(variable)) {
      final dom = _extractDominantPolynomialTerm(exponent, variable);
      if (dom != null && !dom.coeff.isZero) {
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
      case Add(:final terms):
        for (final t in terms) {
          scan(t);
        }
      case Mul(:final factors):
        for (final f in factors) {
          scan(f);
        }
      case BinaryExpr(:final left, :final right):
        scan(left);
        scan(right);
      case UnaryExpr(:final expr):
        scan(expr);
      case Piecewise(:final branches):
        for (final (cond, b) in branches) {
          scan(cond);
          scan(b);
        }
      case Integral(:final integrand, :final lower, :final upper):
        scan(integrand);
        if (lower != null) scan(lower);
        if (upper != null) scan(upper);
      case Number() || Constant() || Variable() || OrderTerm():
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
  return (degree: maxDeg, alpha: RationalNumber.of(numGcd, denLcm));
}

bool _containsLogOfVariable(Expr expr, String variable) =>
    expr.anyNode((e) => e is Ln && e.expr.dependsOn(variable));

bool _containsUnboundedOscillation(Expr expr, String variable) =>
    expr.anyNode((e) {
      if (e
          case Sin(expr: final inner) ||
              Cos(expr: final inner) ||
              Tan(expr: final inner)
          when inner.dependsOn(variable)) {
        try {
          final lim = computeLimit(inner, variable, Constant.infinity);
          return _isPositiveInfinity(lim) || _isNegativeInfinity(lim);
        } on Object {
          return true;
        }
      }
      return false;
    });

Expr? _trySqueezeBoundedOscillation(Expr expr, String variable) {
  final (numExpr, denExpr) = splitNumeratorDenominator(expr);
  if (denExpr == IntegerNumber.one && expr is! Mul) return null;

  final numFactors = numExpr is Mul ? numExpr.factors : <Expr>[numExpr];
  final denFactors = denExpr is Mul
      ? denExpr.factors
      : (denExpr == IntegerNumber.one ? <Expr>[] : <Expr>[denExpr]);

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

  for (final f in denFactors) {
    if (_containsUnboundedOscillation(f, variable)) return null;
  }

  final numPart = switch (nonOscNum) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(nonOscNum),
  };
  final denPart = switch (denFactors) {
    [] => IntegerNumber.one,
    [final single] => single,
    _ => Mul(denFactors),
  };

  final envelope = (numPart / denPart).simplify();
  try {
    final envLim = computeLimit(envelope, variable, Constant.infinity);
    if (envLim is Number && envLim.isZero) {
      return IntegerNumber.zero;
    }
  } on Object {
    // Ignore
  }
  return null;
}

bool _isBoundedOscillator(Expr expr, String variable) => switch (expr) {
  Sin() || Cos() => _containsUnboundedOscillation(expr, variable),
  Pow(:final base, exponent: final RealNumeric exp)
      when !exp.isNegative && !exp.isZero =>
    _isBoundedOscillator(base, variable),
  _ => false,
};

bool _isEverywhereContinuous(Expr expr, String variable) => switch (expr) {
  Number() || Constant() || Variable() => true,
  Add(:final terms) => terms.every((t) => _isEverywhereContinuous(t, variable)),
  Mul(:final factors) => factors.every(
    (f) => _isEverywhereContinuous(f, variable),
  ),
  Pow(base: Constant.e, :final exponent) => _isEverywhereContinuous(
    exponent,
    variable,
  ),
  Pow(:final base, exponent: final IntegerNumber n) when !n.isNegative =>
    _isEverywhereContinuous(base, variable),
  Sin(:final expr) ||
  Cos(:final expr) ||
  Sinh(:final expr) ||
  Cosh(:final expr) => _isEverywhereContinuous(expr, variable),
  _ => false,
};

bool _isWellDefinedFinite(Expr expr) {
  if (expr == Constant.infinity || expr == Constant.undefined) return false;
  if (_isNegativeInfinity(expr)) return false;
  if (expr is RationalNumber) return true;
  if (expr is RealNumber && expr.value.isFinite) return true;
  if (expr is Constant && expr.isReal && expr.value.a.isFinite) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final v = expr.evaluate(const {});
      return v.isFinite;
    } on Object {
      return false;
    }
  }
  return false;
}

int _getSign(Expr expr) {
  final s = expr.simplify();
  if (s is RealNumeric) {
    return s.sign;
  }
  if (s case Mul(factors: [final RealNumeric first, ...final rest])
      when rest.isNotEmpty) {
    final restExpr = switch (rest) {
      [final single] => single,
      _ => Mul(rest),
    };
    return first.sign * _getSign(restExpr);
  }
  if (s.freeVariables.isEmpty) {
    try {
      final v = s.evaluate(const {});
      if (v.isFinite && v != 0.0) return v > 0.0 ? 1 : -1;
    } on Object {
      // Ignore
    }
  }
  return 1;
}

int _asymptoticSignAtInfinity(Expr expr, String variable) {
  final s = expr.simplify();
  if (!s.dependsOn(variable)) return _getSign(s);
  if (s is Pow && s.base == Constant.e) return 1;
  if (s case Mul(factors: [final RealNumeric first, ...final rest])
      when rest.isNotEmpty) {
    final restExpr = switch (rest) {
      [final single] => single,
      _ => Mul(rest),
    };
    return first.sign * _asymptoticSignAtInfinity(restExpr, variable);
  }

  final poly = _polynomialDegreeAndLead(s, variable);
  if (poly != null) {
    return _getSign(poly.$2);
  }

  try {
    final val1 = s.evaluate({variable: 100.0});
    if (val1.isFinite && val1 != 0.0) return val1 > 0.0 ? 1 : -1;
    final val2 = s.evaluate({variable: 1000.0});
    if (val2.isFinite && val2 != 0.0) return val2 > 0.0 ? 1 : -1;
  } on Object {
    // Ignore
  }

  return 1;
}

bool _isPositiveInfinity(Expr expr) => switch (expr) {
  Constant.infinity || Variable(name: '∞' || 'infinity') => true,
  _ => false,
};

bool _isNegativeInfinity(Expr expr) => switch (expr) {
  Mul(factors: [final RealNumeric a, final b]) ||
  Mul(
    factors: [final b, final RealNumeric a],
  ) when a.isNegative && _isPositiveInfinity(b) => true,
  _ => false,
};
