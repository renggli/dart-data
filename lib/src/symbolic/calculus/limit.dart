import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import 'limit_asymptotic.dart';
import 'series.dart';

/// Symbolic limit evaluation extension on [Expr].
extension LimitExtension on Expr {
  /// Computes the symbolic limit `lim_{variable -> point} f(variable)`.
  ///
  /// Evaluates finite limits (`x -> a`), directional limits (`x -> a^+`, `x -> a^-`),
  /// and infinite limits (`x -> +/-oo`).
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
  required Assumptions assumptions,
}) {
  expr = expr.simplify(assumptions: assumptions);
  if (!expr.dependsOn(variable)) return expr;

  if (expr case Add(:final terms)) {
    final termLims = <Expr>[];
    var indeterminate = false;
    var hasInfinity = false;
    var hasNegInfinity = false;
    for (final t in terms) {
      final Expr tLim;
      try {
        tLim = computeLimit(
          t,
          variable,
          point,
          direction: direction,
          assumptions: assumptions,
        );
      } on UnsupportedError catch (e) {
        if (e.message?.contains('in R:') ?? false) {
          rethrow;
        }
        indeterminate = true;
        break;
      }
      if (tLim.anyNode((n) => n is Limit)) {
        indeterminate = true;
        break;
      }
      if (isPositiveInfinity(tLim)) {
        hasInfinity = true;
      } else if (isNegativeInfinity(tLim)) {
        hasNegInfinity = true;
      }
      termLims.add(tLim);
    }
    if (!indeterminate && !(hasInfinity && hasNegInfinity)) {
      if (hasInfinity) return Constant.infinity;
      if (hasNegInfinity) return negInfinity;
      final combinedSum = Add(termLims).simplify(assumptions: assumptions);
      if (!combinedSum.dependsOn(variable) &&
          !combinedSum.anyNode((n) => n is Limit) &&
          combinedSum != Constant.undefined) {
        return combinedSum;
      }
    } else if (combineLogAddTerms(terms, variable, assumptions)
        case final combinedLogs? when combinedLogs != expr) {
      return computeLimit(
        combinedLogs,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
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
      try {
        final varLim = computeLimit(
          varMul,
          variable,
          point,
          direction: direction,
          assumptions: assumptions,
        );
        if (isPositiveInfinity(varLim)) {
          final sign = getSign(constMul, assumptions);
          if (sign != 0) {
            return sign > 0 ? Constant.infinity : negInfinity;
          }
          return Limit(
            expr,
            variable,
            point.simplify(assumptions: assumptions),
            direction: direction,
            isSimplified: true,
          );
        }
        if (isNegativeInfinity(varLim)) {
          final sign = getSign(constMul, assumptions);
          if (sign != 0) {
            return sign > 0 ? negInfinity : Constant.infinity;
          }
          return Limit(
            expr,
            variable,
            point.simplify(assumptions: assumptions),
            direction: direction,
            isSimplified: true,
          );
        }
        if (!varLim.dependsOn(variable) &&
            !varLim.anyNode((n) => n is Limit) &&
            varLim != Constant.undefined) {
          return (constMul * varLim).simplify(assumptions: assumptions);
        }
      } on UnsupportedError catch (e) {
        if (e.message?.contains('does not exist') ?? false) {
          rethrow;
        }
      }
    }
  }

  if (expr case Pow(:final base, :final exponent)
      when base.dependsOn(variable) && exponent.dependsOn(variable)) {
    var oscillating = false;
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
      if (baseLim is RealNumeric &&
          baseLim.isNegative &&
          (isPositiveInfinity(expLim) || isNegativeInfinity(expLim))) {
        oscillating = true;
      } else if (isWellDefinedFinite(baseLim) &&
          isWellDefinedFinite(expLim) &&
          !(baseLim is Number && baseLim.isZero)) {
        final direct = Pow(baseLim, expLim).simplify(assumptions: assumptions);
        if (isWellDefinedFinite(direct)) {
          return direct;
        }
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on ArgumentError {
      // Fall through to log-exponential form
    } on StateError {
      // Fall through to log-exponential form
    }
    if (oscillating) {
      throw UnsupportedError('Limit does not exist due to oscillation');
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
      if (isPositiveInfinity(innerLim)) return Constant.infinity;
      if (isNegativeInfinity(innerLim)) return IntegerNumber.zero;
      if (!innerLim.anyNode((n) => n is Limit)) {
        return Pow(Constant.e, innerLim).simplify(assumptions: assumptions);
      }
    } on UnsupportedError {
      // Fall through to general limit pipeline
    } on ArgumentError {
      // Fall through to general limit pipeline
    } on StateError {
      // Fall through to general limit pipeline
    }
  }

  if (expr case Pow(:final base, :final exponent)
      when base.dependsOn(variable) && !exponent.dependsOn(variable)) {
    try {
      final baseLim = computeLimit(
        base,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (isPositiveInfinity(baseLim) &&
          exponent is RealNumeric &&
          !exponent.isZero) {
        return exponent.isNegative ? IntegerNumber.zero : Constant.infinity;
      }
      if (isNegativeInfinity(baseLim) &&
          exponent is FractionNumber &&
          exponent.denominator.isEven) {
        throw UnsupportedError(
          'Limit does not exist in R: even root of negative infinity',
        );
      }
      if (baseLim is Number &&
          baseLim.isZero &&
          exponent is RealNumeric &&
          !exponent.isNegative &&
          !exponent.isZero) {
        if (exponent is FractionNumber && exponent.denominator.isEven) {
          final recip = (IntegerNumber.one / base).simplify(
            assumptions: assumptions,
          );
          final recipLim = computeLimit(
            recip,
            variable,
            point,
            direction: direction,
            assumptions: assumptions,
          );
          if (isNegativeInfinity(recipLim)) {
            throw UnsupportedError(
              'Limit does not exist in R: even root of negative values as $variable -> $point',
            );
          }
        }
        return exponent is RealNumber ? RealNumber.zero : IntegerNumber.zero;
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on ArgumentError {
      // Fall through
    } on StateError {
      // Fall through
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
        if (isPositiveInfinity(innerLim)) return Constant.infinity;
        if (isNegativeInfinity(innerLim)) return IntegerNumber.zero;
        if (!innerLim.anyNode((n) => n is Limit)) {
          return Pow(Constant.e, innerLim).simplify(assumptions: assumptions);
        }
      } else if (base is RealNumeric) {
        final cmpOne = base.abs().compareTo(IntegerNumber.one);
        if (isPositiveInfinity(innerLim)) {
          if (base.isZero) return IntegerNumber.zero;
          if (cmpOne < 0) return IntegerNumber.zero;
          if (cmpOne > 0) {
            if (base.sign > 0) return Constant.infinity;
            throw UnsupportedError('Limit does not exist due to oscillation');
          }
          if (base.sign > 0) {
            return base is RealNumber
                ? const RealNumber(1.0)
                : IntegerNumber.one;
          }
          throw UnsupportedError('Limit does not exist due to oscillation');
        }
        if (isNegativeInfinity(innerLim)) {
          if (base.isZero) {
            throw UnsupportedError(
              'Limit does not exist: zero raised to negative infinity',
            );
          }
          if (cmpOne > 0) return IntegerNumber.zero;
          if (cmpOne < 0) {
            if (base.sign > 0) return Constant.infinity;
            throw UnsupportedError('Limit does not exist due to oscillation');
          }
          if (base.sign > 0) {
            return base is RealNumber
                ? const RealNumber(1.0)
                : IntegerNumber.one;
          }
          throw UnsupportedError('Limit does not exist due to oscillation');
        }
        if (!innerLim.anyNode((n) => n is Limit)) {
          return Pow(base, innerLim).simplify(assumptions: assumptions);
        }
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on ArgumentError {
      // Fall through
    } on StateError {
      // Fall through
    }
  }

  if (expr case Abs(expr: final inner)) {
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (isPositiveInfinity(innerLim) || isNegativeInfinity(innerLim)) {
        return Constant.infinity;
      }
      if (!innerLim.dependsOn(variable) &&
          !innerLim.anyNode((n) => n is Limit) &&
          innerLim != Constant.undefined) {
        return Abs(innerLim).simplify(assumptions: assumptions);
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('in R:') ?? false) {
        rethrow;
      }
    } on ArgumentError {
      // Fall through
    } on StateError {
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
      if (isPositiveInfinity(innerLim)) return Constant.infinity;
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
        if (isPositiveInfinity(recipLim)) {
          return negInfinity;
        }
        if (isNegativeInfinity(recipLim)) {
          throw UnsupportedError(
            'Limit of Ln($inner) does not exist as $variable -> $point: argument approaches 0 from below',
          );
        }
      }
      if (isWellDefinedFinite(innerLim)) {
        return Ln(innerLim).simplify(assumptions: assumptions);
      }
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on ArgumentError {
      // Fall through
    } on StateError {
      // Fall through
    }
  }

  if (expr case Factorial(expr: final inner) || Gamma(expr: final inner)) {
    try {
      final innerLim = computeLimit(
        inner,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (isPositiveInfinity(innerLim)) return Constant.infinity;
    } on UnsupportedError catch (e) {
      if (e.message?.contains('does not exist') ?? false) {
        rethrow;
      }
    } on ArgumentError {
      // Fall through
    } on StateError {
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
          if (isNegativeInfinity(recipLim)) {
            return negInfinity;
          }
          if (isPositiveInfinity(recipLim)) {
            throw UnsupportedError(
              'Limit of LambertW($inner, branch: -1) does not exist as $variable -> $point: argument approaches 0 from above',
            );
          }
        }
        if (isWellDefinedFinite(innerLim)) {
          return LambertW(
            innerLim,
            branch: branch,
          ).simplify(assumptions: assumptions);
        }
      } else if (branch == 0) {
        if (isPositiveInfinity(innerLim)) return Constant.infinity;
        if (isWellDefinedFinite(innerLim)) {
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
    } on ArgumentError {
      // Fall through
    } on StateError {
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
      if (isWellDefinedFinite(innerLim)) {
        return expr
            .mapChildren((_) => innerLim)
            .simplify(assumptions: assumptions);
      }
      if (isPositiveInfinity(innerLim) || isNegativeInfinity(innerLim)) {
        return switch (expr) {
          Atan() =>
            isPositiveInfinity(innerLim)
                ? (Constant.pi / IntegerNumber.two).simplify(
                    assumptions: assumptions,
                  )
                : (-(Constant.pi / IntegerNumber.two)).simplify(
                    assumptions: assumptions,
                  ),
          Tanh() || Erf() =>
            isPositiveInfinity(innerLim)
                ? IntegerNumber.one
                : IntegerNumber.negativeOne,
          Erfc() =>
            isPositiveInfinity(innerLim)
                ? IntegerNumber.zero
                : IntegerNumber.two,
          Sinh() || Asinh() =>
            isPositiveInfinity(innerLim) ? Constant.infinity : negInfinity,
          Cosh() => Constant.infinity,
          Acosh() =>
            isPositiveInfinity(innerLim)
                ? Constant.infinity
                : Constant.undefined,
          _ => throw UnsupportedError(
            'Limit does not exist due to oscillation',
          ),
        };
      }
    } on UnsupportedError {
      rethrow;
    } on ArgumentError {
      // Fall through
    } on StateError {
      // Fall through
    }
  }

  try {
    if (isPositiveInfinity(point)) {
      return computeInfiniteLimit(
        expr,
        variable,
        isPositive: true,
        assumptions: assumptions,
      );
    }
    if (isNegativeInfinity(point)) {
      return computeInfiniteLimit(
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
  required Assumptions assumptions,
}) {
  try {
    final sub = expr
        .substitute(variable, point)
        .simplify(assumptions: assumptions);
    if (isWellDefinedFinite(sub)) {
      if (isEverywhereContinuous(expr, variable)) {
        return sub;
      }
    }
  } on UnsupportedError {
    // Falls through to Laurent series expansion
  } on ArgumentError {
    // Falls through to Laurent series expansion
  } on StateError {
    // Falls through to Laurent series expansion
  }

  final hName = freshLimitVar('_h', expr, point);
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
          return _deduceLimitFromLaurentLeading(
            m,
            cm,
            direction,
            point,
            assumptions,
          );
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
    if (lead == null) {
      if (series.order > 0) return IntegerNumber.zero;
    } else {
      return _deduceLimitFromLaurentLeading(
        lead.exponent,
        lead.coefficient.simplify(assumptions: assumptions),
        direction,
        point,
        assumptions,
      );
    }
  } on UnsupportedError catch (e) {
    if ((e.message?.contains('Two-sided limit') ?? false) ||
        (e.message?.contains('Sign of leading coefficient') ?? false)) {
      rethrow;
    }
  } on ArgumentError {
    // Ignored.
  } on StateError {
    // Ignored.
  }

  final tName = freshLimitVar('_t', expr, point);
  final t = Variable(tName);
  final tAssumptions = assumptions.copyWith(
    domains: {tName: VariableDomain.positive},
  );
  final invT = IntegerNumber.one / t;
  return switch (direction) {
    LimitDirection.fromAbove => computeInfiniteLimit(
      expr
          .substitute(variable, point + invT)
          .simplify(assumptions: tAssumptions),
      tName,
      isPositive: true,
      assumptions: tAssumptions,
    ),
    LimitDirection.fromBelow => computeInfiniteLimit(
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
      final rightLim = computeInfiniteLimit(
        rightExpr,
        tName,
        isPositive: true,
        assumptions: tAssumptions,
      );
      final leftLim = computeInfiniteLimit(
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
  Assumptions assumptions,
) {
  if (m > 0) return IntegerNumber.zero;
  if (m == 0) return cm;

  final poleOrder = -m;
  final sign = getSign(cm, assumptions);
  if (sign == 0) {
    throw UnsupportedError('Sign of leading coefficient $cm is unknown');
  }

  if (poleOrder.isEven) {
    return sign > 0 ? Constant.infinity : negInfinity;
  }

  return switch (direction) {
    LimitDirection.fromAbove => sign > 0 ? Constant.infinity : negInfinity,
    LimitDirection.fromBelow => sign > 0 ? negInfinity : Constant.infinity,
    LimitDirection.both => throw UnsupportedError(
      'Two-sided limit does not exist at $point: left and right limits differ',
    ),
  };
}

bool isEverywhereContinuous(Expr expr, String variable) => switch (expr) {
  Number() || Constant() || Variable() => true,
  Add(:final terms) => terms.every((t) => isEverywhereContinuous(t, variable)),
  Mul(:final factors) => factors.every(
    (f) => isEverywhereContinuous(f, variable),
  ),
  Pow(base: Constant.e, :final exponent) => isEverywhereContinuous(
    exponent,
    variable,
  ),
  Pow(:final base, exponent: final IntegerNumber n) when !n.isNegative =>
    isEverywhereContinuous(base, variable),
  Sin(:final expr) ||
  Cos(:final expr) ||
  Sinh(:final expr) ||
  Cosh(:final expr) ||
  Tanh(:final expr) ||
  Atan(:final expr) ||
  Asinh(:final expr) ||
  Erf(:final expr) ||
  Erfc(:final expr) ||
  Erfi(:final expr) ||
  FresnelS(:final expr) ||
  FresnelC(:final expr) ||
  SinIntegral(:final expr) ||
  SinhIntegral(:final expr) ||
  Abs(:final expr) => isEverywhereContinuous(expr, variable),
  _ => false,
};

bool isWellDefinedFinite(Expr expr) {
  if (expr == Constant.infinity || expr == Constant.undefined) return false;
  if (isNegativeInfinity(expr)) return false;
  if (expr is RationalNumber) return true;
  if (expr is RealNumber && expr.value.isFinite) return true;
  if (expr is Constant && expr.isReal && expr.value.a.isFinite) {
    return true;
  }
  if (expr.freeVariables.isEmpty) {
    try {
      final v = expr.evaluate(const {});
      return v.isFinite;
    } on ArgumentError {
      return false;
    } on UnsupportedError {
      return false;
    } on StateError {
      return false;
    }
  }
  return _isSymbolicFinite(expr);
}

bool _isSymbolicFinite(Expr expr) => switch (expr) {
  RationalNumber() => true,
  RealNumber(:final value) => value.isFinite,
  Constant(:final isReal, :final value) => isReal && value.a.isFinite,
  Variable() => true,
  Add(:final terms) => terms.every(_isSymbolicFinite),
  Mul(:final factors) => factors.every(_isSymbolicFinite),
  Pow(:final base, :final exponent) =>
    (base == Constant.e ||
            (exponent is IntegerNumber && !exponent.isNegative)) &&
        _isSymbolicFinite(base) &&
        _isSymbolicFinite(exponent),
  Sin(:final expr) ||
  Cos(:final expr) ||
  Sinh(:final expr) ||
  Cosh(:final expr) ||
  Atan(:final expr) ||
  Tanh(:final expr) ||
  Asinh(:final expr) ||
  Erf(:final expr) ||
  Erfc(:final expr) ||
  Abs(:final expr) => _isSymbolicFinite(expr),
  _ => false,
};

int getSign(Expr expr, [Assumptions assumptions = Assumptions.none]) {
  final s = expr.simplify(assumptions: assumptions);
  if (isPositiveExpr(s, assumptions: assumptions)) return 1;
  if (isNegativeExpr(s, assumptions: assumptions)) return -1;
  if (s is RealNumeric) {
    return s.sign;
  }
  if (s case Mul(factors: [final RealNumeric first, ...final rest])
      when rest.isNotEmpty) {
    final restExpr = switch (rest) {
      [final single] => single,
      _ => Mul(rest),
    };
    return first.sign * getSign(restExpr, assumptions);
  }
  if (s.freeVariables.isEmpty) {
    try {
      final v = s.evaluate(const {});
      if (v.isFinite && v != 0.0) return v > 0.0 ? 1 : -1;
    } on ArgumentError {
      // Ignore
    } on UnsupportedError {
      // Ignore
    } on StateError {
      // Ignore
    }
  }
  return 0;
}

int asymptoticSignAtInfinity(
  Expr expr,
  String variable, [
  Set<Expr>? visited,
  Assumptions assumptions = Assumptions.none,
]) {
  final s = expr.simplify(assumptions: assumptions);
  if (!s.dependsOn(variable)) return getSign(s, assumptions);
  if (s is Pow &&
      s.base == Constant.e &&
      isProvenReal(s.exponent, assumptions)) {
    return 1;
  }
  if (s case Mul(factors: [final RealNumeric first, ...final rest])
      when rest.isNotEmpty) {
    final restExpr = switch (rest) {
      [final single] => single,
      _ => Mul(rest),
    };
    return first.sign *
        asymptoticSignAtInfinity(restExpr, variable, visited, assumptions);
  }

  if (polynomialDegreeAndLead(s, variable) case (_, final leadCoeff)) {
    return getSign(leadCoeff, assumptions);
  }

  final seen = visited ?? <Expr>{};
  if (seen.add(s)) {
    try {
      final lim = computeLimit(
        s,
        variable,
        Constant.infinity,
        assumptions: assumptions,
      );
      if (isPositiveInfinity(lim)) return 1;
      if (isNegativeInfinity(lim)) return -1;
      if (!lim.anyNode((n) => n is Limit) &&
          lim.freeVariables.isEmpty &&
          !(lim is Number && lim.isZero)) {
        return getSign(lim, assumptions);
      }
    } on UnsupportedError {
      // Fall through to asymptotic sampling.
    }
  }

  var agreedSign = 0;
  for (final sample in const [1e3, 1e6, 1e9, 1e12]) {
    try {
      final val = s.evaluate({variable: sample});
      if (val.isNaN || val == 0.0) return 0;
      if (!val.isFinite) continue;
      final sgn = val > 0.0 ? 1 : -1;
      if (agreedSign == 0) {
        agreedSign = sgn;
      } else if (agreedSign != sgn) {
        return 0;
      }
    } on ArgumentError {
      return 0;
    } on UnsupportedError {
      return 0;
    } on StateError {
      return 0;
    }
  }
  return agreedSign;
}

bool isPositiveInfinity(Expr expr) => switch (expr) {
  Constant.infinity => true,
  Mul(factors: [final RealNumeric a, final b]) ||
  Mul(
    factors: [final b, final RealNumeric a],
  ) when !a.isNegative && !a.isZero && b == Constant.infinity => true,
  _ => false,
};

bool isNegativeInfinity(Expr expr) => switch (expr) {
  Mul(factors: [final RealNumeric a, final b]) ||
  Mul(
    factors: [final b, final RealNumeric a],
  ) when a.isNegative && isPositiveInfinity(b) => true,
  _ => false,
};

String freshLimitVar(String base, Expr expr, [Expr? point]) {
  final used = <String>{...expr.freeVariables, ...?point?.freeVariables};
  if (!used.contains(base)) return base;
  var i = 1;
  while (used.contains('${base}_$i')) {
    i++;
  }
  return '${base}_$i';
}

final Expr negInfinity = Mul(const [
  IntegerNumber.negativeOne,
  Constant.infinity,
], isSimplified: true);
