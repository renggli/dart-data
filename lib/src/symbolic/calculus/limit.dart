import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import 'series.dart';

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
  /// final lim = expr.limit('x', 0); // 1
  /// ```
  Expr limit(
    String variable,
    Object point, {
    LimitDirection direction = LimitDirection.both,
    Assumptions assumptions = Assumptions.none,
  }) => computeLimit(
    this,
    variable,
    Expr.wrap(point),
    direction: direction,
    assumptions: assumptions,
  );
}

/// Computes the symbolic limit of [expr] as [variable] approaches [point].
Expr computeLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) {
  if (!assumptions.isEmpty) {
    expr = expr.simplify(assumptions: assumptions);
  }
  if (!expr.dependsOn(variable)) return expr.simplify(assumptions: assumptions);

  if (expr case Add(:final terms)) {
    final termLims = <Expr>[];
    var indeterminate = false;
    var hasInfinity = false;
    var hasNegInfinity = false;
    for (final t in terms) {
      final tLim = computeLimit(
        t,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (tLim.anyNode((n) => n is Limit)) {
        indeterminate = true;
        break;
      }
      if (_isPositiveInfinity(tLim)) {
        hasInfinity = true;
      } else if (_isNegativeInfinity(tLim)) {
        hasNegInfinity = true;
      }
      termLims.add(tLim);
    }
    if (!indeterminate && !(hasInfinity && hasNegInfinity)) {
      if (hasInfinity) return Constant.infinity;
      if (hasNegInfinity) return _negInfinity;
      final combinedSum = Add(termLims).simplify(assumptions: assumptions);
      if (!combinedSum.dependsOn(variable) &&
          !combinedSum.anyNode((n) => n is Limit) &&
          combinedSum != Constant.undefined) {
        return combinedSum;
      }
    }
  }

  if (expr case Mul(:final factors)) {
    final constFactors = <Expr>[];
    final varFactors = <Expr>[];
    for (final f in factors) {
      if (f.dependsOn(variable)) {
        varFactors.add(f);
      } else {
        constFactors.add(f);
      }
    }
    if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
      final constMul = Mul(constFactors).simplify(assumptions: assumptions);
      final varMul = Mul(varFactors).simplify(assumptions: assumptions);
      final varLim = computeLimit(
        varMul,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (_isPositiveInfinity(varLim)) {
        final sign = _getSign(constMul);
        return sign > 0 ? Constant.infinity : _negInfinity;
      }
      if (_isNegativeInfinity(varLim)) {
        final sign = _getSign(constMul);
        return sign > 0 ? _negInfinity : Constant.infinity;
      }
      if (!varLim.dependsOn(variable) &&
          !varLim.anyNode((n) => n is Limit) &&
          varLim != Constant.undefined) {
        return (constMul * varLim).simplify(assumptions: assumptions);
      }
      if (_isPositiveInfinity(varLim)) {
        final sign = _getSign(constMul);
        return sign > 0 ? Constant.infinity : _negInfinity;
      }
      if (_isNegativeInfinity(varLim)) {
        final sign = _getSign(constMul);
        return sign > 0 ? _negInfinity : Constant.infinity;
      }
    }
  }

  if (expr case Pow(:final base, :final exponent)
      when base.dependsOn(variable) && exponent.dependsOn(variable)) {
    try {
      final baseLim = computeLimit(
        base,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      final expLim = computeLimit(
        exponent,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (_isWellDefinedFinite(baseLim) &&
          _isWellDefinedFinite(expLim) &&
          !(baseLim is Number && baseLim.isZero)) {
        final direct = Pow(baseLim, expLim).simplify(assumptions: assumptions);
        if (_isWellDefinedFinite(direct)) {
          return direct;
        }
      }
    } on Object {
      // Fall through to log-exponential form
    }
    final logForm = exponent * Ln(base);
    try {
      final innerLim = computeLimit(
        logForm,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (_isPositiveInfinity(innerLim)) return Constant.infinity;
      if (_isNegativeInfinity(innerLim)) return IntegerNumber.zero;
      if (!innerLim.anyNode((n) => n is Limit)) {
        return Pow(Constant.e, innerLim).simplify(assumptions: assumptions);
      }
    } on Object {
      // Fall through to general limit pipeline
    }
  }

  if (expr case Pow(:final base, :final exponent)
      when (base == Constant.e || base is RealNumeric)) {
    try {
      final innerLim = computeLimit(
        exponent,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (base == Constant.e) {
        if (_isPositiveInfinity(innerLim)) return Constant.infinity;
        if (_isNegativeInfinity(innerLim)) return IntegerNumber.zero;
        if (!innerLim.anyNode((n) => n is Limit)) {
          return Pow(Constant.e, innerLim).simplify(assumptions: assumptions);
        }
      } else if (base is RealNumeric) {
        final cmpOne = base.abs().compareTo(IntegerNumber.one);
        if (_isPositiveInfinity(innerLim)) {
          if (cmpOne < 0) return IntegerNumber.zero;
          if (cmpOne > 0) {
            if (base.sign > 0) return Constant.infinity;
            throw UnsupportedError('Limit does not exist due to oscillation');
          }
          return IntegerNumber.one;
        }
        if (_isNegativeInfinity(innerLim)) {
          if (cmpOne > 0) return IntegerNumber.zero;
          if (cmpOne < 0) {
            if (base.sign > 0) return Constant.infinity;
            throw UnsupportedError('Limit does not exist due to oscillation');
          }
          return IntegerNumber.one;
        }
        if (!innerLim.anyNode((n) => n is Limit)) {
          return Pow(base, innerLim).simplify(assumptions: assumptions);
        }
      }
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
        assumptions: assumptions,
      );
      if (_isPositiveInfinity(innerLim)) return Constant.infinity;
      if (innerLim is Number && innerLim.isZero) {
        final recip = (IntegerNumber.one / inner).simplify(
          assumptions: assumptions,
        );
        final recipLim = computeLimit(
          recip,
          variable,
          point,
          direction: direction,
          assumptions: assumptions,
        );
        if (_isPositiveInfinity(recipLim)) {
          return _negInfinity;
        }
        if (_isNegativeInfinity(recipLim)) {
          throw UnsupportedError(
            'Limit of Ln($inner) does not exist as $variable -> $point: argument approaches 0 from below',
          );
        }
      }
      if (_isWellDefinedFinite(innerLim)) {
        return Ln(innerLim).simplify(assumptions: assumptions);
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on Object {
      // Fall through
    }
  }

  if (expr case LambertW(expr: final inner, :final branch)) {
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (branch == -1) {
        if (innerLim is Number && innerLim.isZero) {
          final recip = (IntegerNumber.one / inner).simplify(
            assumptions: assumptions,
          );
          final recipLim = computeLimit(
            recip,
            variable,
            point,
            direction: direction,
            assumptions: assumptions,
          );
          if (_isNegativeInfinity(recipLim)) {
            return _negInfinity;
          }
          if (_isPositiveInfinity(recipLim)) {
            throw UnsupportedError(
              'Limit of LambertW($inner, branch: -1) does not exist as $variable -> $point: argument approaches 0 from above',
            );
          }
        }
        if (_isWellDefinedFinite(innerLim)) {
          return LambertW(
            innerLim,
            branch: branch,
          ).simplify(assumptions: assumptions);
        }
      } else if (branch == 0) {
        if (_isPositiveInfinity(innerLim)) return Constant.infinity;
        if (_isWellDefinedFinite(innerLim)) {
          return LambertW(
            innerLim,
            branch: branch,
          ).simplify(assumptions: assumptions);
        }
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on Object {
      // Fall through
    }
  }

  if (expr
      case Sin(expr: final inner) ||
          Cos(expr: final inner) ||
          Atan(expr: final inner) ||
          Tanh(expr: final inner) ||
          Sinh(expr: final inner) ||
          Cosh(expr: final inner) ||
          Asinh(expr: final inner) ||
          Acosh(expr: final inner) ||
          Erf(expr: final inner) ||
          Erfc(expr: final inner)) {
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (_isWellDefinedFinite(innerLim)) {
        return expr
            .mapChildren((_) => innerLim)
            .simplify(assumptions: assumptions);
      }
      if (_isPositiveInfinity(innerLim) || _isNegativeInfinity(innerLim)) {
        return switch (expr) {
          Atan() =>
            _isPositiveInfinity(innerLim)
                ? (Constant.pi / IntegerNumber.two).simplify(
                    assumptions: assumptions,
                  )
                : (-(Constant.pi / IntegerNumber.two)).simplify(
                    assumptions: assumptions,
                  ),
          Tanh() || Erf() =>
            _isPositiveInfinity(innerLim)
                ? IntegerNumber.one
                : IntegerNumber.negativeOne,
          Erfc() =>
            _isPositiveInfinity(innerLim)
                ? IntegerNumber.zero
                : IntegerNumber.two,
          Sinh() || Asinh() =>
            _isPositiveInfinity(innerLim) ? Constant.infinity : _negInfinity,
          Cosh() => Constant.infinity,
          Acosh() =>
            _isPositiveInfinity(innerLim)
                ? Constant.infinity
                : Constant.undefined,
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

  try {
    if (_isPositiveInfinity(point)) {
      return _computeInfiniteLimit(
        expr,
        variable,
        isPositive: true,
        assumptions: assumptions,
      );
    }
    if (_isNegativeInfinity(point)) {
      return _computeInfiniteLimit(
        expr,
        variable,
        isPositive: false,
        assumptions: assumptions,
      );
    }

    return _computeFiniteLimit(
      expr,
      variable,
      point,
      direction: direction,
      assumptions: assumptions,
    );
  } on UnsupportedError catch (e) {
    if (e.message?.contains('does not exist') ?? false) {
      rethrow;
    }
    return Limit(
      expr.simplify(assumptions: assumptions),
      variable,
      point.simplify(assumptions: assumptions),
      direction: direction,
      isSimplified: true,
    );
  }
}

Expr _computeFiniteLimit(
  Expr expr,
  String variable,
  Expr point, {
  LimitDirection direction = LimitDirection.both,
  Assumptions assumptions = Assumptions.none,
}) {
  try {
    final sub = expr
        .substitute(variable, point)
        .simplify(assumptions: assumptions);
    if (_isWellDefinedFinite(sub)) {
      if (_isEverywhereContinuous(expr, variable)) {
        return sub;
      }
    }
  } on Object {
    // Falls through to Laurent series expansion
  }

  final hName = _freshLimitVar('_h', expr, point);
  final h = Variable(hName);
  final localExpr = expr
      .substitute(variable, point + h)
      .simplify(assumptions: assumptions);

  final (numExpr, denExpr) = splitNumeratorDenominator(localExpr);
  if (denExpr != IntegerNumber.one) {
    for (final ord in const [6, 14]) {
      try {
        final sNum = numExpr.toPowerSeries(
          hName,
          point: IntegerNumber.zero,
          order: ord,
        );
        final sDen = denExpr.toPowerSeries(
          hName,
          point: IntegerNumber.zero,
          order: ord,
        );
        if ((sNum.leadingTerm, sDen.leadingTerm) case (
          final leadNum?,
          final leadDen?,
        )) {
          final m = leadNum.exponent - leadDen.exponent;
          final cm = (leadNum.coefficient / leadDen.coefficient).simplify(
            assumptions: assumptions,
          );
          return _deduceLimitFromLaurentLeading(m, cm, direction, point);
        }
      } on UnsupportedError catch (e) {
        if (e.message?.contains('Two-sided limit') ?? false) {
          rethrow;
        }
        break;
      } on ArgumentError {
        break;
      } on StateError {
        break;
      }
    }
  }

  try {
    var series = localExpr.toPowerSeries(
      hName,
      point: IntegerNumber.zero,
      order: 6,
    );
    var lead = series.leadingTerm;
    if (lead == null) {
      series = localExpr.toPowerSeries(
        hName,
        point: IntegerNumber.zero,
        order: 14,
      );
      lead = series.leadingTerm;
    }
    if (lead == null) return IntegerNumber.zero;
    return _deduceLimitFromLaurentLeading(
      lead.exponent,
      lead.coefficient.simplify(assumptions: assumptions),
      direction,
      point,
    );
  } on UnsupportedError catch (e) {
    if (e.message?.contains('Two-sided limit') ?? false) {
      rethrow;
    }
  } on ArgumentError {
    // Ignored.
  } on StateError {
    // Ignored.
  }

  final tName = _freshLimitVar('_t', expr, point);
  final t = Variable(tName);
  final tAssumptions = assumptions.copyWith(
    domains: {tName: VariableDomain.positive},
  );
  final invT = IntegerNumber.one / t;
  return switch (direction) {
    LimitDirection.fromAbove => _computeInfiniteLimit(
      expr
          .substitute(variable, point + invT)
          .simplify(assumptions: tAssumptions),
      tName,
      isPositive: true,
      assumptions: tAssumptions,
    ),
    LimitDirection.fromBelow => _computeInfiniteLimit(
      expr
          .substitute(variable, point - invT)
          .simplify(assumptions: tAssumptions),
      tName,
      isPositive: true,
      assumptions: tAssumptions,
    ),
    LimitDirection.both => () {
      final rightExpr = expr
          .substitute(variable, point + invT)
          .simplify(assumptions: tAssumptions);
      final leftExpr = expr
          .substitute(variable, point - invT)
          .simplify(assumptions: tAssumptions);
      final rightLim = _computeInfiniteLimit(
        rightExpr,
        tName,
        isPositive: true,
        assumptions: tAssumptions,
      );
      final leftLim = _computeInfiniteLimit(
        leftExpr,
        tName,
        isPositive: true,
        assumptions: tAssumptions,
      );
      if (rightLim == leftLim) return rightLim;
      throw UnsupportedError(
        'Two-sided limit does not exist at $point: left ($leftLim) and right ($rightLim) limits differ',
      );
    }(),
  };
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
  Assumptions assumptions = Assumptions.none,
}) {
  if (!isPositive) {
    final posAssumptions = assumptions.copyWith(
      domains: {variable: VariableDomain.positive},
    );
    final reflected = expr
        .substitute(variable, -Variable(variable))
        .simplify(assumptions: posAssumptions);
    return _computeInfiniteLimit(
      reflected,
      variable,
      isPositive: true,
      assumptions: posAssumptions,
    );
  }

  final posAssumptions = assumptions.copyWith(
    domains: {variable: VariableDomain.positive},
  );
  final resolved = _resolveAsymptoticAbsAndPiecewise(
    expr,
    variable,
  ).simplify(assumptions: posAssumptions);
  if (!resolved.dependsOn(variable)) return resolved;

  final combined = _combineNumericPowers(resolved, variable, posAssumptions);
  if (!combined.dependsOn(variable)) return combined;

  if (combined != resolved) {
    return computeLimit(
      combined,
      variable,
      Constant.infinity,
      assumptions: posAssumptions,
    );
  }

  final ratLim = _rationalFunctionLimitAtInfinity(combined, variable);
  if (ratLim != null) return ratLim.simplify(assumptions: posAssumptions);

  final expPolyLim = _exponentialPolynomialLimitAtInfinity(combined, variable);
  if (expPolyLim != null) {
    return expPolyLim.simplify(assumptions: posAssumptions);
  }

  return _gruntzLimit(combined, variable, posAssumptions);
}

Expr _combineNumericPowers(
  Expr expr,
  String variable,
  Assumptions assumptions,
) {
  final mapped = expr.mapChildren(
    (c) => _combineNumericPowers(c, variable, assumptions),
  );
  if (mapped case Mul(:final factors)) {
    final numericPowers = <(RealNumeric base, RationalNumber k, Expr rem)>[];
    final otherFactors = <Expr>[];

    for (final f in factors) {
      if (f case Pow(:final base, :final exponent)
          when base is RealNumeric &&
              !base.isZero &&
              !base.isOne &&
              exponent.dependsOn(variable)) {
        final dom = _extractDominantPolynomialTerm(exponent, variable);
        if (dom != null &&
            dom.degree == 1 &&
            (base.sign > 0 || dom.coeff.denominator == 1)) {
          numericPowers.add((base, dom.coeff, dom.remainder));
          continue;
        }
      }
      otherFactors.add(f);
    }

    if (numericPowers.isNotEmpty) {
      Expr combinedBase = IntegerNumber.one;
      final remFactors = <Expr>[];

      for (final (base, k, rem) in numericPowers) {
        final powered = base.pow(k);
        combinedBase = (combinedBase * powered).simplify(
          assumptions: assumptions,
        );
        if (rem != IntegerNumber.zero) {
          remFactors.add(Pow(base, rem).simplify(assumptions: assumptions));
        }
      }

      final combinedPow = combinedBase == IntegerNumber.one
          ? IntegerNumber.one
          : Pow(
              combinedBase,
              Variable(variable),
            ).simplify(assumptions: assumptions);

      return Mul([...otherFactors, ...remFactors, combinedPow])
          .simplify(assumptions: assumptions);
    }
  }
  return mapped.simplify(assumptions: assumptions);
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
    for (final (:relation, :expr) in branches) {
      try {
        if (relation.evaluate({variable: 1e9}) == 1.0) {
          return expr;
        }
      } on Object {
        // Ignore
      }
    }
    if (otherwise != null) {
      return otherwise;
    }
  }
  if (mapped case Mul(:final factors)
      when factors.contains(IntegerNumber.zero)) {
    final nonZero = <Expr>[];
    for (final f in factors) {
      if (f != IntegerNumber.zero) {
        if (f == Constant.infinity ||
            f == _negInfinity ||
            f == Constant.undefined) {
          return mapped;
        }
        nonZero.add(f);
      }
    }
    if (nonZero.every((f) => _isBoundedFactorAtInfinity(f, variable))) {
      return IntegerNumber.zero;
    }
  }
  return mapped;
}

bool _isBoundedFactorAtInfinity(Expr expr, String variable) => switch (expr) {
  _ when !expr.dependsOn(variable) => _isWellDefinedFinite(expr),
  Sin() || Cos() => true,
  Pow(base: final RealNumeric b, :final exponent) => () {
    final cmp = b.abs().compareTo(IntegerNumber.one);
    if (cmp == 0) return true;
    try {
      final expLim = _computeInfiniteLimit(
        exponent,
        variable,
        isPositive: true,
      );
      if (cmp < 0 && _isPositiveInfinity(expLim)) return true;
      if (cmp > 0 && _isNegativeInfinity(expLim)) return true;
    } on Object {
      // Ignore
    }
    return false;
  }(),
  _ => false,
};

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

Expr? _exponentialPolynomialLimitAtInfinity(Expr expr, String variable) {
  if (expr case Mul(:final factors)) {
    Expr? expFactor;
    final polyFactors = <Expr>[];
    for (final f in factors) {
      if (f case Pow(:final base, exponent: Variable(name: final v))
          when v == variable && base is RealNumeric && !base.isZero) {
        if (expFactor == null) {
          expFactor = f;
          continue;
        }
      }
      polyFactors.add(f);
    }
    if (expFactor case Pow(:final RealNumeric base, exponent: _)) {
      final poly = polyFactors.isEmpty
          ? IntegerNumber.one
          : Mul(polyFactors).simplify();
      final polyDeg = _polynomialDegreeAndLead(poly, variable);
      if (polyDeg != null) {
        final (deg, lead) = polyDeg;
        final cmpOne = base.abs().compareTo(IntegerNumber.one);
        if (cmpOne < 0) {
          return IntegerNumber.zero;
        }
        if (cmpOne > 0 && base.sign > 0) {
          final sign = _getSign(lead);
          return sign > 0 ? Constant.infinity : _negInfinity;
        }
      }
    }
  }
  return null;
}

(int, Expr)? _polynomialDegreeAndLead(Expr expr, String variable) {
  final expanded = expr.expand().simplify();
  if (!expanded.dependsOn(variable)) {
    return (0, expanded);
  }

  final acc = MonomialAccumulator();
  acc.add(expanded);

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

Expr _rewriteHyperbolicsToExp(Expr expr, Assumptions assumptions) {
  final mapped = expr.mapChildren(
    (c) => _rewriteHyperbolicsToExp(c, assumptions),
  );
  return switch (mapped) {
    Sinh(expr: final u) =>
      (FractionNumber.half *
              (Pow(Constant.e, u) -
                  Pow(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Cosh(expr: final u) =>
      (FractionNumber.half *
              (Pow(Constant.e, u) +
                  Pow(Constant.e, (-u).simplify(assumptions: assumptions))))
          .simplify(assumptions: assumptions),
    Tanh(expr: final u) => () {
      final ePos = Pow(Constant.e, u);
      final eNeg = Pow(Constant.e, (-u).simplify(assumptions: assumptions));
      return ((ePos - eNeg) / (ePos + eNeg)).simplify(assumptions: assumptions);
    }(),
    Asinh(expr: final u) => Ln(
      u +
          Pow(
            Pow(u, IntegerNumber.two) + IntegerNumber.one,
            FractionNumber.half,
          ),
    ).simplify(assumptions: assumptions),
    Acosh(expr: final u) => Ln(
      u +
          Pow(u - IntegerNumber.one, FractionNumber.half) *
              Pow(u + IntegerNumber.one, FractionNumber.half),
    ).simplify(assumptions: assumptions),
    Atanh(expr: final u) =>
      (FractionNumber.half *
              Ln((IntegerNumber.one + u) / (IntegerNumber.one - u)))
          .simplify(assumptions: assumptions),
    _ => mapped.simplify(assumptions: assumptions),
  };
}

Expr _gruntzLimit(
  Expr expr,
  String variable, [
  Assumptions assumptions = Assumptions.none,
]) {
  var f = _rewriteHyperbolicsToExp(
    expr.simplify(assumptions: assumptions),
    assumptions,
  );
  if (!f.dependsOn(variable)) return f;

  if (_containsUnboundedOscillation(f, variable)) {
    final squeezed = _trySqueezeBoundedOscillation(f, variable);
    if (squeezed != null) return squeezed;
    throw UnsupportedError('Limit does not exist due to oscillation');
  }

  f = _expandLogArguments(f, variable);

  final expScale = _findDominantExpScale(f, variable);

  if (expScale == null && _containsLogOfVariable(f, variable)) {
    final uName = _freshLimitVar('_u', f);
    final u = Variable(uName);
    final uAssumptions = assumptions.copyWith(
      domains: {uName: VariableDomain.real},
    );
    final transformed = f
        .substitute(variable, Pow(Constant.e, u))
        .simplify(assumptions: uAssumptions);
    return _computeInfiniteLimit(
      transformed,
      uName,
      isPositive: true,
      assumptions: uAssumptions,
    );
  }

  final omegaName = _freshLimitVar('_omega', f);
  final omega = Variable(omegaName);

  if (expScale == null) {
    final rewritten = f
        .substitute(variable, IntegerNumber.one / omega)
        .simplify(assumptions: assumptions);

    for (final ord in const [4, 10]) {
      try {
        final series = rewritten.toPowerSeries(
          omegaName,
          point: IntegerNumber.zero,
          order: ord,
        );
        final lead = series.leadingTerm;
        if (lead != null) {
          if (lead.exponent > 0) return IntegerNumber.zero;
          if (lead.exponent == 0) {
            return lead.coefficient.simplify(assumptions: assumptions);
          }
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

  final rewritten = _rewriteExpInOmega(
    f,
    variable,
    omega,
    expScale.degree,
    expScale.alpha,
  ).simplify(assumptions: assumptions);

  for (final ord in const [4, 10]) {
    try {
      final series = rewritten.toPowerSeries(
        omegaName,
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
        return computeLimit(
          lead.coefficient,
          variable,
          Constant.infinity,
          assumptions: assumptions,
        );
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
  final expanded = expr.expand().simplify();
  final acc = MonomialAccumulator();
  acc.add(expanded);

  var maxDeg = 0;
  RationalNumber leadCoeff = IntegerNumber.zero;
  Expr? leadKey;

  for (final entry in acc.terms.entries) {
    final deg = _monomialDegree(entry.key, variable);
    if (deg == null) return null;
    if (deg > maxDeg) {
      if (entry.value case final RationalNumber val) {
        maxDeg = deg;
        leadCoeff = val;
        leadKey = entry.key;
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
        for (final (:relation, :expr) in branches) {
          scan(relation);
          scan(expr);
        }
      case Integral(:final integrand, :final lower, :final upper):
        scan(integrand);
        if (lower != null) scan(lower);
        if (upper != null) scan(upper);
      case Derivative(:final expr):
        scan(expr);
      case Limit(:final expr, :final point):
        scan(expr);
        scan(point);
      case Sum(:final expr, :final lower, :final upper) ||
          Product(:final expr, :final lower, :final upper):
        scan(expr);
        scan(lower);
        scan(upper);
      case VariableFunction(:final arguments):
        for (final argument in arguments) {
          scan(argument);
        }
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

  if (_polynomialDegreeAndLead(s, variable) case (_, final leadCoeff)) {
    return _getSign(leadCoeff);
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

String _freshLimitVar(String base, Expr expr, [Expr? point]) {
  final used = <String>{...expr.freeVariables, ...?point?.freeVariables};
  if (!used.contains(base)) return base;
  var i = 1;
  while (used.contains('${base}_$i')) {
    i++;
  }
  return '${base}_$i';
}

final Expr _negInfinity = Mul(const [
  IntegerNumber.negativeOne,
  Constant.infinity,
], isSimplified: true);
