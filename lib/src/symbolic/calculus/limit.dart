import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../functions/fn.dart';
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
  /// final expr = Fn.sin(x) / x;
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
    final finiteLims = <Expr>[];
    final unresolvedTerms = <Expr>[];
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
        unresolvedTerms.add(t);
        continue;
      }
      if (tLim.anyNode((n) => n is Limit)) {
        indeterminate = true;
        unresolvedTerms.add(t);
        continue;
      }
      if (isPositiveInfinity(tLim)) {
        hasInfinity = true;
        unresolvedTerms.add(t);
      } else if (isNegativeInfinity(tLim)) {
        hasNegInfinity = true;
        unresolvedTerms.add(t);
      } else if (tLim == Constant.undefined || tLim.dependsOn(variable)) {
        indeterminate = true;
        unresolvedTerms.add(t);
      } else {
        finiteLims.add(tLim);
      }
      termLims.add(tLim);
    }
    if (!indeterminate && !(hasInfinity && hasNegInfinity)) {
      if (hasInfinity) return Constant.infinity;
      if (hasNegInfinity) return negInfinity;
      final combinedSum = Add.of(termLims).simplify(assumptions: assumptions);
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
    } else if (finiteLims.isNotEmpty &&
        unresolvedTerms.isNotEmpty &&
        unresolvedTerms.length < terms.length) {
      final finiteSum = Add.of(finiteLims).simplify(assumptions: assumptions);
      final rest = unresolvedTerms.length == 1
          ? unresolvedTerms.first
          : Add.of(unresolvedTerms);
      final restLim = computeLimit(
        rest,
        variable,
        point,
        direction: direction,
        assumptions: assumptions,
      );
      if (!restLim.anyNode((n) => n is Limit) &&
          restLim != Constant.undefined) {
        if (isPositiveInfinity(restLim)) return Constant.infinity;
        if (isNegativeInfinity(restLim)) return negInfinity;
        return (finiteSum + restLim).simplify(assumptions: assumptions);
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
      final constMul = Mul.of(constFactors).simplify(assumptions: assumptions);
      final varMul = Mul.of(varFactors).simplify(assumptions: assumptions);
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
        final direct = Pow.of(
          baseLim,
          expLim,
        ).simplify(assumptions: assumptions);
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
    final logForm = exponent * Fn.ln(base);
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
        return Pow.of(Constant.e, innerLim).simplify(assumptions: assumptions);
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
      int? constantExpSign() {
        if (exponent is RealNumeric) {
          return exponent.isZero ? null : (exponent.isNegative ? -1 : 1);
        }
        if (exponent.anyNode((n) => n is ComplexNumber)) return null;
        if (isPositiveExpr(exponent, assumptions: assumptions)) return 1;
        if (isNegativeExpr(exponent, assumptions: assumptions)) return -1;
        if (exponent.freeVariables.isEmpty) {
          try {
            final v = exponent.evaluate(const {});
            if (v.isFinite && v != 0.0) return v > 0 ? 1 : -1;
          } on ArgumentError {
            // Ignored.
          } on UnsupportedError {
            // Ignored.
          } on StateError {
            // Ignored.
          }
        }
        return null;
      }

      if (isPositiveInfinity(baseLim)) {
        if (constantExpSign() case final s?) {
          return s < 0 ? IntegerNumber.zero : Constant.infinity;
        }
      }
      if (isNegativeInfinity(baseLim) &&
          exponent is FractionNumber &&
          exponent.denominator.isEven) {
        throw UnsupportedError(
          'Limit does not exist in R: even root of negative infinity',
        );
      }
      if (baseLim is Number && baseLim.isZero && constantExpSign() == 1) {
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
      if (isWellDefinedFinite(baseLim) &&
          !(baseLim is Number && baseLim.isZero)) {
        final direct = Pow.of(
          baseLim,
          exponent,
        ).simplify(assumptions: assumptions);
        if (isWellDefinedFinite(direct) &&
            (baseLim is! RealNumeric ||
                !baseLim.isNegative ||
                !direct.anyNode((n) => n is ComplexNumber))) {
          return direct;
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
          return Pow.of(
            Constant.e,
            innerLim,
          ).simplify(assumptions: assumptions);
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
          return Pow.of(base, innerLim).simplify(assumptions: assumptions);
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

  if (expr case Call(id: FunctionId.abs, args: [final inner])) {
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
        return Fn.abs(innerLim).simplify(assumptions: assumptions);
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

  if (expr case Call(id: FunctionId.ln, args: [final inner])) {
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
            'Limit of ln($inner) does not exist as $variable -> $point: argument approaches 0 from below',
          );
        }
      }
      if (isWellDefinedFinite(innerLim)) {
        return Fn.ln(innerLim).simplify(assumptions: assumptions);
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

  if (expr case Call(
    id: FunctionId.factorial || FunctionId.gamma,
    args: [final inner],
  )) {
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

  if (expr case Call(id: FunctionId.lambertW, :final args)) {
    final inner = args[0];
    final branch = args.length > 1 && args[1] is IntegerNumber
        ? (args[1] as IntegerNumber).toInt()
        : 0;
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
              'Limit of lambertW($inner, -1) does not exist as $variable -> $point: argument approaches 0 from above',
            );
          }
        }
        if (isWellDefinedFinite(innerLim)) {
          return Fn.lambertW(
            innerLim,
            IntegerNumber.of(branch),
          ).simplify(assumptions: assumptions);
        }
      } else if (branch == 0) {
        if (isPositiveInfinity(innerLim)) return Constant.infinity;
        if (isWellDefinedFinite(innerLim)) {
          return Fn.lambertW(innerLim).simplify(assumptions: assumptions);
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

  if (expr case Call(:final id, args: [final inner])
      when id == FunctionId.sin ||
          id == FunctionId.cos ||
          id == FunctionId.atan ||
          id == FunctionId.tanh ||
          id == FunctionId.sinh ||
          id == FunctionId.cosh ||
          id == FunctionId.asinh ||
          id == FunctionId.acosh ||
          id == FunctionId.erf ||
          id == FunctionId.erfc) {
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
        return switch (id) {
          FunctionId.atan =>
            isPositiveInfinity(innerLim)
                ? (Constant.pi / IntegerNumber.two).simplify(
                    assumptions: assumptions,
                  )
                : (-(Constant.pi / IntegerNumber.two)).simplify(
                    assumptions: assumptions,
                  ),
          FunctionId.tanh || FunctionId.erf =>
            isPositiveInfinity(innerLim)
                ? IntegerNumber.one
                : IntegerNumber.negativeOne,
          FunctionId.erfc =>
            isPositiveInfinity(innerLim)
                ? IntegerNumber.zero
                : IntegerNumber.two,
          FunctionId.sinh || FunctionId.asinh =>
            isPositiveInfinity(innerLim) ? Constant.infinity : negInfinity,
          FunctionId.cosh => Constant.infinity,
          FunctionId.acosh =>
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
  Call(
    id: FunctionId.sin ||
        FunctionId.cos ||
        FunctionId.sinh ||
        FunctionId.cosh ||
        FunctionId.tanh ||
        FunctionId.atan ||
        FunctionId.asinh ||
        FunctionId.erf ||
        FunctionId.erfc ||
        FunctionId.erfi ||
        FunctionId.fresnelS ||
        FunctionId.fresnelC ||
        FunctionId.si ||
        FunctionId.shi ||
        FunctionId.abs,
    args: [final expr],
  ) =>
    isEverywhereContinuous(expr, variable),
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
  Call(
    id: FunctionId.sin ||
        FunctionId.cos ||
        FunctionId.sinh ||
        FunctionId.cosh ||
        FunctionId.atan ||
        FunctionId.tanh ||
        FunctionId.asinh ||
        FunctionId.erf ||
        FunctionId.erfc ||
        FunctionId.abs,
    args: [final expr],
  ) =>
    _isSymbolicFinite(expr),
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
      _ => Mul.of(rest),
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
      _ => Mul.of(rest),
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

final Expr negInfinity = -Constant.infinity;
