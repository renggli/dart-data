import 'dart:math' as math;

import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../number/integer.dart';
import '../../solver/univariate.dart';
import '../differentiation.dart';
import '../limit.dart';
import '../linear_form.dart';
import '../summation.dart';
import 'definite_tables.dart';

/// Canonical negative infinity expression `-oo`.
final Expr negInfinity = Mul(const [
  IntegerNumber.negativeOne,
  Constant.infinity,
], isSimplified: true);

/// Returns `true` if [bound] represents positive or negative infinity.
bool isInfiniteBound(Expr bound) =>
    bound == Constant.infinity ||
    bound == negInfinity ||
    bound == -Constant.infinity;

/// Returns `true` if [expr] evaluates to a strictly positive constant.
bool isPositiveConstant(Expr expr) {
  if (expr is RationalNumber) return !expr.isNegative && !expr.isZero;
  if (expr is RealNumber) return expr.value > 0.0;
  if (expr.freeVariables.isEmpty) {
    try {
      final val = expr.evaluate(const {});
      return val.isFinite && val > 0.0;
    } on ArgumentError {
      // Ignored.
    } on UnsupportedError {
      // Ignored.
    }
  }
  return false;
}

/// Returns `true` if [expr] evaluates to a strictly negative constant.
bool isNegativeConstant(Expr expr) => isPositiveConstant((-expr).simplify());

/// Evaluates a definite symbolic integral `integrate _a^b f(x) dx` with respect to
/// [variable] between [from] and [to].
///
/// Uses the Fundamental Theorem of Calculus via [antiDerivative] and endpoint
/// limits, while automatically handling improper integrals, interior poles,
/// symmetric odd integrands, and closed-form special function integrals (Euler
/// Gamma, Beta, Dirichlet, Fresnel, Wallis, Bose-Einstein/Fermi-Dirac).
Expr evaluateDefiniteIntegral(
  Expr function,
  String variable,
  Object from,
  Object to, {
  required Assumptions assumptions,
  required Expr Function(
    Expr function,
    String variable, {
    required Assumptions assumptions,
  })
  antiDerivative,
}) {
  final fromExpr = Expr.wrap(from).simplify(assumptions: assumptions);
  final toExpr = Expr.wrap(to).simplify(assumptions: assumptions);
  if (fromExpr == toExpr) {
    if (isInfiniteBound(fromExpr) || fromExpr == Constant.undefined) {
      return Constant.undefined;
    }
    return IntegerNumber.zero;
  }

  // Odd integrand over symmetric interval [-a, a]
  if ((fromExpr + toExpr).simplify(assumptions: assumptions) ==
      IntegerNumber.zero) {
    if (isOddIntegrandWithoutInteriorPoles(
      function,
      variable,
      fromExpr,
      toExpr,
      assumptions: assumptions,
    )) {
      return IntegerNumber.zero;
    }
  }

  // Floor / Ceil piecewise splitting and summation on finite intervals
  if (function.anyNode(
    (n) => (n is Floor || n is Ceil) && n.dependsOn(variable),
  )) {
    if (_tryFloorCeilDefinite(
          function,
          variable,
          fromExpr,
          toExpr,
          assumptions: assumptions,
          antiDerivative: antiDerivative,
        )
        case final floorRes?) {
      return floorRes;
    }
  }

  // Abs / Min / Max piecewise region splitting on finite intervals
  if (function.anyNode(
    (n) => (n is Abs || n is Min || n is Max) && n.dependsOn(variable),
  )) {
    if (_tryPiecewiseAbsMinMax(
          function,
          variable,
          fromExpr,
          toExpr,
          assumptions: assumptions,
          antiDerivative: antiDerivative,
        )
        case final pwRes?) {
      return pwRes;
    }
  }

  // King's property reflection symmetry: int_a^b f(x) dx = 1/2 int_a^b (f(x) + f(a+b-x)) dx
  if (_tryKingsProperty(
        function,
        variable,
        fromExpr,
        toExpr,
        assumptions: assumptions,
      )
      case final kingsRes?) {
    return kingsRes;
  }

  // Half-period anti-symmetry: f(x + (b - a)/2) = -f(x)
  if (_tryHalfPeriodAntiSymmetry(
        function,
        variable,
        fromExpr,
        toExpr,
        assumptions: assumptions,
      )
      case final halfSymRes?) {
    return halfSymRes;
  }

  // Reciprocal inversion symmetry on [1/a, a]: x -> 1/x
  if (_tryReciprocalSymmetry(
        function,
        variable,
        fromExpr,
        toExpr,
        assumptions: assumptions,
        antiDerivative: antiDerivative,
      )
      case final recSymRes?) {
    return recSymRes;
  }

  // Fast table lookup on [0, infty), [0, 1], [0, pi], [0, 2*pi], or high-degree integrands
  // before running general indefinite integration.
  final twoPi = (IntegerNumber.two * Constant.pi).simplify();
  if ((fromExpr == IntegerNumber.zero &&
          (toExpr == Constant.infinity ||
              toExpr == IntegerNumber.one ||
              toExpr == Constant.pi ||
              toExpr == twoPi)) ||
      function.anyNode(
        (n) =>
            n is Pow &&
            n.exponent is IntegerNumber &&
            (n.exponent as IntegerNumber).value.abs() > const Integer(20),
      )) {
    final quickDef = definiteIntegralSpecialCases(
      function.simplify(assumptions: assumptions),
      variable,
      fromExpr,
      toExpr,
      assumptions: assumptions,
    );
    if (quickDef != null) {
      return quickDef.simplify(assumptions: assumptions);
    }
  }

  final antiDeriv = antiDerivative(
    function,
    variable,
    assumptions: assumptions,
  ).simplify(assumptions: assumptions);

  if (!hasUnevaluatedIntegral(antiDeriv, variable)) {
    var hasInteriorPole = false;
    final numFrom = evaluateBoundNumeric(fromExpr);
    final numTo = evaluateBoundNumeric(toExpr);
    if (numFrom != null && numTo != null && !numFrom.isNaN && !numTo.isNaN) {
      final low = numFrom < numTo ? numFrom : numTo;
      final high = numFrom < numTo ? numTo : numFrom;
      hasInteriorPole = _hasInteriorPole(function, variable, low, high);
    }

    if (hasInteriorPole &&
        numFrom != null &&
        numTo != null &&
        !numFrom.isNaN &&
        !numTo.isNaN) {
      final low = numFrom < numTo ? numFrom : numTo;
      final high = numFrom < numTo ? numTo : numFrom;
      final poles = _collectSymbolicInteriorPoles(
        function,
        variable,
        low,
        high,
      );
      if (poles != null && poles.isNotEmpty) {
        final hasEvenPowerFrac = function.anyNode(
          (n) =>
              n is Pow &&
              n.base is Pow &&
              (n.base as Pow).exponent == IntegerNumber.two &&
              n.exponent is FractionNumber &&
              (n.exponent as FractionNumber).denominator.isOdd,
        );
        final effectiveAntiDeriv = wrapLnWithAbs(antiDeriv, assumptions);
        final isAscending = numFrom <= numTo;
        final points = <Expr>[
          if (isAscending) fromExpr else toExpr,
          for (final p in poles) p.expr,
          if (isAscending) toExpr else fromExpr,
        ];
        final pieces = <Expr>[];
        var ok = true;
        var hasPosInf = false;
        var hasNegInf = false;
        for (var i = 0; i < points.length - 1; i++) {
          final pLow = points[i];
          final pHigh = points[i + 1];
          final vLow = evaluateBoundNumeric(pLow);
          final vHigh = evaluateBoundNumeric(pHigh);
          if (vLow != null &&
              vHigh != null &&
              vLow.isFinite &&
              vHigh.isFinite) {
            final mid = 0.5 * (vLow + vHigh);
            final hasNegLnArg = function.anyNode((n) {
              if (n case Ln(:final expr) when expr.dependsOn(variable)) {
                try {
                  final v = expr.evaluate({variable: mid});
                  return v.isNaN || v <= 0.0;
                } on ArgumentError {
                  return true;
                } on UnsupportedError {
                  return true;
                } on StateError {
                  return true;
                }
              }
              return false;
            });
            if (hasNegLnArg) {
              ok = false;
              break;
            }
          }
          var pieceAnti = effectiveAntiDeriv;
          if (hasEvenPowerFrac) {
            final vLow = evaluateBoundNumeric(pLow);
            final vHigh = evaluateBoundNumeric(pHigh);
            if (vLow == null ||
                vHigh == null ||
                !vLow.isFinite ||
                !vHigh.isFinite) {
              ok = false;
              break;
            }
            final subFn = _resolveEvenPowerOnInterval(
              function,
              variable,
              0.5 * (vLow + vHigh),
              assumptions,
            );
            final subAnti = antiDerivative(
              subFn,
              variable,
              assumptions: assumptions,
            ).simplify(assumptions: assumptions);
            if (hasUnevaluatedIntegral(subAnti, variable)) {
              ok = false;
              break;
            }
            pieceAnti = wrapLnWithAbs(subAnti, assumptions);
          }
          try {
            final upper = isInfiniteBound(pHigh)
                ? pieceAnti.limit(variable, pHigh, assumptions: assumptions)
                : pieceAnti.limit(
                    variable,
                    pHigh,
                    direction: LimitDirection.fromBelow,
                    assumptions: assumptions,
                  );
            final lower = isInfiniteBound(pLow)
                ? pieceAnti.limit(variable, pLow, assumptions: assumptions)
                : pieceAnti.limit(
                    variable,
                    pLow,
                    direction: LimitDirection.fromAbove,
                    assumptions: assumptions,
                  );
            if (upper.anyNode((n) => n is Limit || n == Constant.undefined) ||
                lower.anyNode((n) => n is Limit || n == Constant.undefined)) {
              ok = false;
              break;
            }
            if (upper == Constant.infinity) {
              if (lower == Constant.infinity) {
                ok = false;
                break;
              }
              hasPosInf = true;
              continue;
            }
            if (upper == negInfinity) {
              if (lower == negInfinity) {
                ok = false;
                break;
              }
              hasNegInf = true;
              continue;
            }
            if (lower == Constant.infinity) {
              hasNegInf = true;
              continue;
            }
            if (lower == negInfinity) {
              hasPosInf = true;
              continue;
            }
            final diff = (upper - lower).simplify(assumptions: assumptions);
            if (diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
              ok = false;
              break;
            }
            pieces.add(diff);
          } on Object {
            ok = false;
            break;
          }
        }
        if (ok && hasPosInf && hasNegInf) {
          return Integral(function, variable, lower: fromExpr, upper: toExpr);
        }
        if (ok) {
          if (hasPosInf) {
            return isAscending ? Constant.infinity : negInfinity;
          }
          if (hasNegInf) {
            return isAscending ? negInfinity : Constant.infinity;
          }
          final total = Add(pieces).simplify(assumptions: assumptions);
          if (!total.anyNode((n) => n is Limit || n == Constant.undefined)) {
            return isAscending
                ? total
                : (-total).simplify(assumptions: assumptions);
          }
        }
      }
    }

    if (!hasInteriorPole) {
      final effectiveAntiDeriv = wrapLnWithAbs(antiDeriv, assumptions);
      final List<({double value, Expr expr})>? jumps;
      if (numFrom != null && numTo != null && !numFrom.isNaN && !numTo.isNaN) {
        final low = numFrom < numTo ? numFrom : numTo;
        final high = numFrom < numTo ? numTo : numFrom;
        jumps = _antiderivativeJumps(
          effectiveAntiDeriv,
          variable,
          low,
          high,
          assumptions,
        );
      } else {
        jumps = const [];
      }

      if (jumps != null && jumps.isNotEmpty) {
        final isAscending = numFrom! <= numTo!;
        final points = <Expr>[
          if (isAscending) fromExpr else toExpr,
          for (final j in jumps) j.expr,
          if (isAscending) toExpr else fromExpr,
        ];
        final pieces = <Expr>[];
        var ok = true;
        for (var i = 0; i < points.length - 1; i++) {
          final pLow = points[i];
          final pHigh = points[i + 1];
          try {
            final upper = isInfiniteBound(pHigh)
                ? effectiveAntiDeriv.limit(
                    variable,
                    pHigh,
                    assumptions: assumptions,
                  )
                : effectiveAntiDeriv.limit(
                    variable,
                    pHigh,
                    direction: LimitDirection.fromBelow,
                    assumptions: assumptions,
                  );
            final lower = isInfiniteBound(pLow)
                ? effectiveAntiDeriv.limit(
                    variable,
                    pLow,
                    assumptions: assumptions,
                  )
                : effectiveAntiDeriv.limit(
                    variable,
                    pLow,
                    direction: LimitDirection.fromAbove,
                    assumptions: assumptions,
                  );
            final diff = (upper - lower).simplify(assumptions: assumptions);
            if (diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
              ok = false;
              break;
            }
            pieces.add(diff);
          } on ArgumentError {
            ok = false;
            break;
          } on UnsupportedError {
            ok = false;
            break;
          } on StateError {
            ok = false;
            break;
          }
        }
        if (ok) {
          final total = Add(pieces).simplify(assumptions: assumptions);
          return isAscending
              ? total
              : (-total).simplify(assumptions: assumptions);
        }
      } else if (jumps != null) {
        Expr? validUpper;
        Expr? validLower;
        try {
          final upper = isInfiniteBound(toExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  toExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.substitute(variable, toExpr);
          final lower = isInfiniteBound(fromExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  fromExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.substitute(variable, fromExpr);
          final upperSimp = upper.simplify(assumptions: assumptions);
          if (!upperSimp.anyNode(
            (n) => n is Limit || n == Constant.undefined,
          )) {
            validUpper = upperSimp;
          }
          final lowerSimp = lower.simplify(assumptions: assumptions);
          if (!lowerSimp.anyNode(
            (n) => n is Limit || n == Constant.undefined,
          )) {
            validLower = lowerSimp;
          }
          final diff = _subtractEndpointValues(
            upperSimp,
            lowerSimp,
            assumptions,
          );
          if (diff != null) {
            return diff;
          }
        } on ArgumentError {
          // Fall through to definite integral special cases or endpoint limit.
        } on UnsupportedError {
          // Fall through to definite integral special cases or endpoint limit.
        } on StateError {
          // Fall through to definite integral special cases or endpoint limit.
        }

        // Try one-sided limits at finite endpoints (e.g. int_0^1 ln(x) dx)
        for (final prepAnti in [
          effectiveAntiDeriv,
          _expandLnForEndpointLimit(effectiveAntiDeriv),
        ]) {
          try {
            final isAscending =
                (evaluateBoundNumeric(fromExpr) ?? 0.0) <=
                (evaluateBoundNumeric(toExpr) ?? 1.0);
            final upper = isInfiniteBound(toExpr)
                ? prepAnti.limit(variable, toExpr, assumptions: assumptions)
                : (prepAnti == effectiveAntiDeriv ? validUpper : null) ??
                      prepAnti.limit(
                        variable,
                        toExpr,
                        direction: isAscending
                            ? LimitDirection.fromBelow
                            : LimitDirection.fromAbove,
                        assumptions: assumptions,
                      );
            final lower = isInfiniteBound(fromExpr)
                ? prepAnti.limit(variable, fromExpr, assumptions: assumptions)
                : (prepAnti == effectiveAntiDeriv ? validLower : null) ??
                      prepAnti.limit(
                        variable,
                        fromExpr,
                        direction: isAscending
                            ? LimitDirection.fromAbove
                            : LimitDirection.fromBelow,
                        assumptions: assumptions,
                      );
            final diff = _subtractEndpointValues(upper, lower, assumptions);
            if (diff != null) {
              return diff;
            }
          } on ArgumentError {
            // Fall through to expanded log form or special cases.
          } on UnsupportedError {
            // Fall through to expanded log form or special cases.
          } on StateError {
            // Fall through to expanded log form or special cases.
          }
        }
      }
    }
  }

  final specialDef = definiteIntegralSpecialCases(
    function.simplify(assumptions: assumptions),
    variable,
    fromExpr,
    toExpr,
    assumptions: assumptions,
  );
  if (specialDef != null) {
    return specialDef.simplify(assumptions: assumptions);
  }

  // Fallback: if antiderivative failed due to an even-power fractional
  // singularity like ((x - 1)^2)^(-1/3), split at interior poles and resolve
  // the base sign on each sub-interval.
  if (hasUnevaluatedIntegral(antiDeriv, variable)) {
    final numFrom = evaluateBoundNumeric(fromExpr);
    final numTo = evaluateBoundNumeric(toExpr);
    if (numFrom != null && numTo != null && !numFrom.isNaN && !numTo.isNaN) {
      final low = numFrom < numTo ? numFrom : numTo;
      final high = numFrom < numTo ? numTo : numFrom;
      if (_hasInteriorPole(function, variable, low, high)) {
        final poles = _collectSymbolicInteriorPoles(
          function,
          variable,
          low,
          high,
        );
        if (poles != null && poles.isNotEmpty) {
          final isAscending = numFrom <= numTo;
          final points = <Expr>[
            if (isAscending) fromExpr else toExpr,
            for (final p in poles) p.expr,
            if (isAscending) toExpr else fromExpr,
          ];
          final pieces = <Expr>[];
          var ok = true;
          for (var i = 0; i < points.length - 1; i++) {
            final pLow = points[i];
            final pHigh = points[i + 1];
            final vLow = evaluateBoundNumeric(pLow);
            final vHigh = evaluateBoundNumeric(pHigh);
            if (vLow == null ||
                vHigh == null ||
                !vLow.isFinite ||
                !vHigh.isFinite) {
              ok = false;
              break;
            }
            final mid = 0.5 * (vLow + vHigh);
            final subFn = _resolveEvenPowerOnInterval(
              function,
              variable,
              mid,
              assumptions,
            );
            final subAnti = antiDerivative(
              subFn,
              variable,
              assumptions: assumptions,
            ).simplify(assumptions: assumptions);
            if (hasUnevaluatedIntegral(subAnti, variable)) {
              ok = false;
              break;
            }
            final effSub = wrapLnWithAbs(subAnti, assumptions);
            try {
              final upper = effSub.limit(
                variable,
                pHigh,
                direction: LimitDirection.fromBelow,
                assumptions: assumptions,
              );
              final lower = effSub.limit(
                variable,
                pLow,
                direction: LimitDirection.fromAbove,
                assumptions: assumptions,
              );
              final diff = (upper - lower).simplify(assumptions: assumptions);
              if (diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
                ok = false;
                break;
              }
              pieces.add(diff);
            } on ArgumentError {
              ok = false;
              break;
            } on UnsupportedError {
              ok = false;
              break;
            } on StateError {
              ok = false;
              break;
            }
          }
          if (ok) {
            final total = Add(pieces).simplify(assumptions: assumptions);
            if (!total.anyNode((n) => n is Limit || n == Constant.undefined)) {
              return isAscending
                  ? total
                  : (-total).simplify(assumptions: assumptions);
            }
          }
        }
      }
    }
  }

  return Integral(
    function.simplify(assumptions: assumptions),
    variable,
    lower: fromExpr,
    upper: toExpr,
    isSimplified: true,
  );
}

/// Evaluates a numeric boundary value, returning `double.infinity`,
/// `double.negativeInfinity`, or a finite double if determinable.
double? evaluateBoundNumeric(Expr bound) {
  if (bound == Constant.infinity) return double.infinity;
  if (bound == negInfinity || bound == -Constant.infinity) {
    return double.negativeInfinity;
  }
  if (bound is Number) return bound.toDouble();
  if (bound.freeVariables.isEmpty) {
    try {
      final v = bound.evaluate(const {});
      if (!v.isNaN) return v;
    } on ArgumentError {
      // Ignored.
    } on UnsupportedError {
      // Ignored.
    }
  }
  return null;
}

/// Extracts all subexpressions that appear in negative power denominators.
List<Expr> extractDenominatorFactors(Expr expr) {
  final factors = <Expr>[];
  void visit(Expr e) {
    if (e is Pow) {
      final exp = e.exponent;
      if (exp is Number && exp.toDouble() < 0) {
        factors.add(e.base);
      }
      visit(e.base);
    } else if (e is Mul) {
      for (final f in e.factors) {
        visit(f);
      }
    } else if (e is Add) {
      for (final t in e.terms) {
        visit(t);
      }
    } else if (e case Tan(expr: final arg)) {
      factors.add(Cos(arg));
      visit(arg);
    } else if (e case Ln(expr: final arg)) {
      factors.add(arg);
      visit(arg);
    }
  }

  visit(expr);
  return factors;
}

/// Finds the real roots of any denominator factor in [expr].
List<double> findDenominatorRoots(Expr expr, String variable) {
  final roots = <double>{};
  final factors = extractDenominatorFactors(expr);
  for (final factor in factors) {
    if (factor.dependsOn(variable)) {
      if (exceedsNodeBudget(factor, 100) ||
          isPositiveExpr(
            factor,
            assumptions: Assumptions(domains: {variable: VariableDomain.real}),
          )) {
        continue;
      }
      try {
        final solutions = factor.solve(variable);
        for (final sol in solutions) {
          if (sol is Number) {
            final val = sol.toDouble();
            if (val.isFinite) roots.add(val);
          } else {
            try {
              final val = sol.evaluate(const {});
              if (val.isFinite) roots.add(val);
            } on ArgumentError {
              // Ignored.
            } on UnsupportedError {
              // Ignored.
            }
          }
        }
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      } on StateError {
        // Ignored.
      }
    }
  }
  return roots.toList();
}

/// Wraps any [Ln] call in [expr] with an [Abs] if the argument is not already
/// guaranteed positive.
Expr wrapLnWithAbs(Expr expr, Assumptions assumptions) {
  if (expr is Ln) {
    if (expr.expr is Abs ||
        isPositiveConstant(expr.expr) ||
        isPositiveExpr(expr.expr, assumptions: assumptions)) {
      return Ln(wrapLnWithAbs(expr.expr, assumptions));
    }
    return Ln(Abs(wrapLnWithAbs(expr.expr, assumptions)));
  }
  return expr.mapChildren((e) => wrapLnWithAbs(e, assumptions));
}

/// Returns `true` if [expr] contains an unevaluated [Integral] node in [variable].
bool hasUnevaluatedIntegral(Expr expr, String variable) => expr.anyNode(
  (e) => e is Integral && !e.isDefinite && e.variable == variable,
);

/// Checks whether [function] is an odd function over symmetric bounds [-a, a]
/// without interior singularities/poles.
bool isOddIntegrandWithoutInteriorPoles(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
}) {
  final sFunc = function.simplify(assumptions: assumptions);
  final reflected = sFunc
      .substitute(variable, -Variable(variable))
      .simplify(assumptions: assumptions);
  if ((sFunc + reflected).expand().simplify(assumptions: assumptions) !=
      IntegerNumber.zero) {
    return false;
  }

  // Ensure no denominator vanishes on the interval
  final numFrom = evaluateBoundNumeric(fromExpr);
  final numTo = evaluateBoundNumeric(toExpr);
  if (numFrom == null || numTo == null) {
    return extractDenominatorFactors(sFunc)
        .every((f) => !f.dependsOn(variable));
  }
  final low = numFrom < numTo ? numFrom : numTo;
  final high = numFrom < numTo ? numTo : numFrom;
  if (_hasAnyDenominatorPole(
    sFunc,
    variable,
    low,
    high,
    inclusive: true,
    assumptions: assumptions,
  )) {
    return false;
  }
  return true;
}

bool _hasAnyDenominatorPole(
  Expr expr,
  String variable,
  double low,
  double high, {
  required bool inclusive,
  Assumptions assumptions = Assumptions.none,
}) {
  final eps = inclusive ? -1e-12 : 1e-12;
  final factors = extractDenominatorFactors(expr);
  for (final factor in factors) {
    if (!factor.dependsOn(variable)) continue;
    // Periodic trig factors: Sin(arg), Cos(arg)
    if (factor case Sin(:final expr) || Cos(:final expr)
        when expr.dependsOn(variable)) {
      if (low.isFinite && high.isFinite) {
        try {
          final u1 = expr.evaluate({variable: low});
          final u2 = expr.evaluate({variable: high});
          if (u1.isFinite && u2.isFinite) {
            final uMin = math.min(u1, u2);
            final uMax = math.max(u1, u2);
            if (factor is Sin) {
              final kMin = ((uMin + eps) / math.pi).ceil();
              final kMax = ((uMax - eps) / math.pi).floor();
              if (kMin <= kMax) return true;
            } else {
              final kMin = ((uMin + eps) / math.pi - 0.5).ceil();
              final kMax = ((uMax - eps) / math.pi - 0.5).floor();
              if (kMin <= kMax) return true;
            }
          }
        } on ArgumentError {
          // Fall through
        } on UnsupportedError {
          // Fall through
        } on StateError {
          // Fall through
        }
      }
    }
    try {
      final realAssumptions = assumptions.copyWith(
        domains: {
          variable: low > 0 ? VariableDomain.positive : VariableDomain.real,
        },
      );
      if (isPositiveExpr(factor, assumptions: realAssumptions) ||
          exceedsNodeBudget(factor, 100)) {
        continue;
      }
      final solutions = factor.solve(variable, assumptions: realAssumptions);
      for (final sol in solutions) {
        if (sol.anyNode((n) => n is ComplexNumber)) continue;
        final v = evaluateBoundNumeric(sol);
        if (v == null || v.isNaN) {
          // Symbolic parameter pole (e.g. a in x^2 - a^2) may lie in [low, high].
          if (!isPositiveExpr(factor, assumptions: realAssumptions) &&
              !isNegativeExpr(factor, assumptions: realAssumptions)) {
            return true;
          }
          continue;
        }
        if (inclusive
            ? (v >= low - 1e-12 && v <= high + 1e-12)
            : (v > low + 1e-12 && v < high - 1e-12)) {
          return true;
        }
      }
    } on ArgumentError {
      // Unsolvable factor; fall through to numeric endpoint check.
    } on UnsupportedError {
      // Unsolvable factor; fall through to numeric endpoint check.
    } on StateError {
      // Unsolvable factor; fall through to numeric endpoint check.
    }
    // Check endpoint zeros directly if finite
    if (inclusive && low.isFinite && high.isFinite) {
      try {
        final vL = factor.evaluate({variable: low});
        final vH = factor.evaluate({variable: high});
        if (vL == 0.0 || vH == 0.0) return true;
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      }
    }
  }
  return false;
}

/// Pattern-table lookup and closed-form evaluation of famous improper and
/// definite integrals.
Expr _resolveEvenPowerOnInterval(
  Expr expr,
  String variable,
  double midpoint,
  Assumptions assumptions,
) {
  if (expr
      case Pow(
        base: Pow(base: final u, exponent: IntegerNumber(asInt: 2)),
        exponent: final r,
      )
      when r is FractionNumber && r.denominator.isOdd) {
    try {
      final val = u.evaluate({variable: midpoint});
      if (val.isFinite && val != 0.0) {
        final signedBase = val > 0
            ? u
            : (-u).simplify(assumptions: assumptions);
        return Pow(
          signedBase,
          r.mulRational(IntegerNumber.two),
        ).simplify(assumptions: assumptions);
      }
    } on ArgumentError {
      // Fall through
    } on UnsupportedError {
      // Fall through
    } on StateError {
      // Fall through
    }
  }
  return expr.mapChildren(
    (c) => _resolveEvenPowerOnInterval(c, variable, midpoint, assumptions),
  );
}

List<({double value, Expr expr})>? _collectSymbolicInteriorPoles(
  Expr expr,
  String variable,
  double low,
  double high,
) {
  final poles = <({double value, Expr expr})>[];
  void addPole(double v, Expr rootExpr) {
    if (v > low + 1e-12 && v < high - 1e-12) {
      if (!poles.any((p) => (p.value - v).abs() < 1e-12)) {
        poles.add((value: v, expr: rootExpr));
      }
    }
  }

  for (final factor in extractDenominatorFactors(expr)) {
    if (!factor.dependsOn(variable)) continue;
    if (factor case Sin(expr: final arg) || Cos(expr: final arg)
        when arg.dependsOn(variable) && low.isFinite && high.isFinite) {
      try {
        final u1 = arg.evaluate({variable: low});
        final u2 = arg.evaluate({variable: high});
        if (u1.isFinite && u2.isFinite) {
          final uMin = math.min(u1, u2);
          final uMax = math.max(u1, u2);
          final isSin = factor is Sin;
          final kMin = ((uMin + 1e-9) / math.pi - (isSin ? 0.0 : 0.5)).ceil();
          final kMax = ((uMax - 1e-9) / math.pi - (isSin ? 0.0 : 0.5)).floor();
          if (kMax - kMin <= 16 && kMin <= kMax) {
            for (var k = kMin; k <= kMax; k++) {
              final target = isSin
                  ? (IntegerNumber.of(k) * Constant.pi).simplify()
                  : ((IntegerNumber.of(k) + FractionNumber.half) * Constant.pi)
                        .simplify();
              for (final root in (arg - target).solve(
                variable,
                assumptions: Assumptions.real,
              )) {
                final v = evaluateBoundNumeric(root);
                if (v != null && v.isFinite) {
                  addPole(v, root);
                }
              }
            }
          }
        }
      } on ArgumentError {
        return null;
      } on UnsupportedError {
        return null;
      } on StateError {
        return null;
      }
    }
    try {
      final roots = factor.solve(variable, assumptions: Assumptions.real);
      for (final root in roots) {
        if (root.anyNode((n) => n is ComplexNumber)) continue;
        final v = evaluateBoundNumeric(root);
        if (v == null || v.isNaN) return null;
        addPole(v, root);
      }
    } on ArgumentError {
      return null;
    } on UnsupportedError {
      return null;
    } on StateError {
      return null;
    }
  }
  poles.sort((a, b) => a.value.compareTo(b.value));
  return poles;
}

bool _hasInteriorPole(Expr expr, String variable, double low, double high) {
  if (_hasAnyDenominatorPole(expr, variable, low, high, inclusive: false)) {
    return true;
  }

  return expr.anyNode((node) {
    if (node case Tan(expr: final arg) when arg.dependsOn(variable)) {
      try {
        final u1 = arg.evaluate({variable: low});
        final u2 = arg.evaluate({variable: high});
        if (u1.isFinite && u2.isFinite) {
          final uMin = math.min(u1, u2);
          final uMax = math.max(u1, u2);
          final kMin = ((uMin + 1e-9) / math.pi - 0.5).ceil();
          final kMax = ((uMax - 1e-9) / math.pi - 0.5).floor();
          if (kMin <= kMax) return true;
        }
      } on ArgumentError {
        // Fall back to root checking
      } on UnsupportedError {
        // Fall back to root checking
      } on StateError {
        // Fall back to root checking
      }
    }
    if (node case Ln(expr: final arg) when arg.dependsOn(variable)) {
      try {
        final u1 = arg.evaluate({variable: low});
        final u2 = arg.evaluate({variable: high});
        if (u1.isFinite && u2.isFinite) {
          final uMin = math.min(u1, u2);
          final uMax = math.max(u1, u2);
          if (uMin < 0 || (uMin == 0 && uMax == 0)) return true;
        }
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      } on StateError {
        // Ignored.
      }
    }
    return false;
  });
}

List<({double value, Expr expr})>? _antiderivativeJumps(
  Expr antiDeriv,
  String variable,
  double low,
  double high,
  Assumptions assumptions,
) {
  final jumps = <({double value, Expr expr})>[];
  var tooMany = false;

  void addJump(double xk, Expr xExpr) {
    if (xk > low + 1e-9 && xk < high - 1e-9) {
      if (!jumps.any((j) => (j.value - xk).abs() <= 1e-9)) {
        if (jumps.length >= 16) {
          tooMany = true;
          return;
        }
        jumps.add((value: xk, expr: xExpr));
      }
    }
  }

  void collect(Expr node) {
    if (tooMany) return;
    if (node case Tan(expr: final arg) when arg.dependsOn(variable)) {
      if (!low.isFinite || !high.isFinite) {
        tooMany = true;
        return;
      }
      if (arg.matchLinear(variable) case (:final a, :final b)) {
        final aVal = evaluateBoundNumeric(a);
        final bVal = evaluateBoundNumeric(b);
        if (aVal != null &&
            bVal != null &&
            aVal.isFinite &&
            bVal.isFinite &&
            aVal != 0.0) {
          final uLow = aVal * low + bVal;
          final uHigh = aVal * high + bVal;
          final uMin = math.min(uLow, uHigh);
          final uMax = math.max(uLow, uHigh);
          final kMin = (uMin / math.pi - 0.5).floor() - 1;
          final kMax = (uMax / math.pi - 0.5).ceil() + 1;
          if (kMax - kMin > 32) {
            tooMany = true;
            return;
          }
          for (var k = kMin; k <= kMax; k++) {
            final xk = ((k + 0.5) * math.pi - bVal) / aVal;
            final xExpr =
                (((IntegerNumber.of(k) + FractionNumber.half) * Constant.pi -
                            b) /
                        a)
                    .simplify(assumptions: assumptions);
            addJump(xk, xExpr);
          }
        }
      } else {
        try {
          final u1 = arg.evaluate({variable: low});
          final u2 = arg.evaluate({variable: high});
          if (u1.isFinite && u2.isFinite) {
            final uMin = math.min(u1, u2);
            final uMax = math.max(u1, u2);
            final kMin = (uMin / math.pi - 0.5).floor() - 1;
            final kMax = (uMax / math.pi - 0.5).ceil() + 1;
            if (kMax - kMin <= 16) {
              for (var k = kMin; k <= kMax; k++) {
                final target =
                    ((IntegerNumber.of(k) + FractionNumber.half) * Constant.pi)
                        .simplify();
                for (final root in (arg - target).solve(
                  variable,
                  assumptions: Assumptions.real,
                )) {
                  final xk = evaluateBoundNumeric(root);
                  if (xk != null && xk.isFinite) {
                    addJump(xk, root);
                  }
                }
              }
            }
          }
        } on ArgumentError {
          // Ignored.
        } on UnsupportedError {
          // Ignored.
        } on StateError {
          // Ignored.
        }
      }
    } else if (node case Sign(expr: final arg) when arg.dependsOn(variable)) {
      if (!low.isFinite || !high.isFinite) {
        tooMany = true;
        return;
      }
      try {
        for (final root in arg.solve(variable, assumptions: Assumptions.real)) {
          final xk = evaluateBoundNumeric(root);
          if (xk != null && xk.isFinite) {
            addJump(xk, root);
          }
        }
      } on ArgumentError {
        // Ignored.
      } on UnsupportedError {
        // Ignored.
      } on StateError {
        // Ignored.
      }
    }
    node.mapChildren((child) {
      collect(child);
      return child;
    });
  }

  collect(antiDeriv);
  if (tooMany) return null;
  jumps.sort((x, y) => x.value.compareTo(y.value));
  return jumps;
}

Expr? _tryKingsProperty(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
}) {
  if (isInfiniteBound(fromExpr) || isInfiniteBound(toExpr)) return null;
  final numFrom = evaluateBoundNumeric(fromExpr);
  final numTo = evaluateBoundNumeric(toExpr);
  if (numFrom == null ||
      numTo == null ||
      numFrom.isNaN ||
      numTo.isNaN ||
      !numFrom.isFinite ||
      !numTo.isFinite) {
    return null;
  }
  if (exceedsNodeBudget(function, 120)) return null;

  final reflected = function
      .substitute(
        variable,
        (fromExpr + toExpr - Variable(variable)).simplify(
          assumptions: assumptions,
        ),
      )
      .simplify(assumptions: assumptions);
  if (reflected == function) return null;

  Expr normalizeReciprocalNegPow(Expr e) {
    final mapped = e.mapChildren(normalizeReciprocalNegPow);
    if (mapped case Pow(
      base: Pow(base: final innerBase, exponent: Number(isNegativeOne: true)),
      :final exponent,
    )) {
      return Pow(innerBase, (-exponent).simplify(assumptions: assumptions));
    }
    if (mapped case Pow(
      base: Add(terms: [final t0, final t1]),
      exponent: Number(isNegativeOne: true),
    )) {
      Expr? findNegPow(Expr t) {
        bool isNegExp(Expr exp) =>
            (exp is RealNumeric && exp.sign < 0) || isNegativeConstant(exp);
        if (t case Pow(:final base, :final exponent) when isNegExp(exponent)) {
          return Pow(base, (-exponent).simplify(assumptions: assumptions));
        }
        if (t case Mul(:final factors)) {
          for (final f in factors) {
            if (f case Pow(:final base, :final exponent)
                when isNegExp(exponent)) {
              return Pow(base, (-exponent).simplify(assumptions: assumptions));
            }
          }
        }
        return null;
      }

      final posPow = findNegPow(t0) ?? findNegPow(t1);
      if (posPow != null) {
        final newDen = (posPow * t0 + posPow * t1).simplify(
          assumptions: assumptions,
        );
        return (posPow / newDen).simplify(assumptions: assumptions);
      }
    }
    return mapped;
  }

  Expr canonicalizeOddEvenTrigArgs(Expr e) {
    final mapped = e.mapChildren(canonicalizeOddEvenTrigArgs);
    bool isLeadingNegAdd(Expr arg) {
      if (arg is! Add || arg.terms.isEmpty) return false;
      final first = arg.terms.first;
      return (first is RealNumeric && first.sign < 0) ||
          (first is Mul &&
              first.factors.isNotEmpty &&
              first.factors.first is RealNumeric &&
              (first.factors.first as RealNumeric).sign < 0);
    }

    Expr posArg(Expr e) => (-e).expand().simplify(assumptions: assumptions);

    if (mapped case Sin(:final expr) when isLeadingNegAdd(expr)) {
      return (-Sin(
        posArg(expr),
        isSimplified: true,
      )).simplify(assumptions: assumptions);
    }
    if (mapped case Tan(:final expr) when isLeadingNegAdd(expr)) {
      return (-Tan(
        posArg(expr),
        isSimplified: true,
      )).simplify(assumptions: assumptions);
    }
    if (mapped case Sinh(:final expr) when isLeadingNegAdd(expr)) {
      return (-Sinh(
        posArg(expr),
        isSimplified: true,
      )).simplify(assumptions: assumptions);
    }
    if (mapped case Tanh(:final expr) when isLeadingNegAdd(expr)) {
      return (-Tanh(
        posArg(expr),
        isSimplified: true,
      )).simplify(assumptions: assumptions);
    }
    if (mapped case Cos(:final expr) when isLeadingNegAdd(expr)) {
      return Cos(posArg(expr), isSimplified: true);
    }
    if (mapped case Cosh(:final expr) when isLeadingNegAdd(expr)) {
      return Cosh(posArg(expr), isSimplified: true);
    }
    return mapped;
  }

  final normFunc = canonicalizeOddEvenTrigArgs(
    function.simplify(assumptions: assumptions),
  );
  final normRefl = canonicalizeOddEvenTrigArgs(
    normalizeReciprocalNegPow(reflected),
  );
  var sum = (normFunc + normRefl).simplify(assumptions: assumptions);
  final hasHighIntPow = sum.anyNode(
    (n) =>
        n is Pow &&
        n.exponent is IntegerNumber &&
        ((n.exponent as IntegerNumber).asInt?.abs() ?? 0) > 20,
  );
  if (sum.dependsOn(variable) &&
      sum is Add &&
      !hasHighIntPow &&
      !exceedsNodeBudget(sum, 160)) {
    sum = sum
        .together(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  if (sum.dependsOn(variable)) return null;

  final low = numFrom < numTo ? numFrom : numTo;
  final high = numFrom < numTo ? numTo : numFrom;
  if (_hasInteriorPole(function, variable, low, high)) {
    return null;
  }
  if (_hasAnyDenominatorPole(
    function,
    variable,
    low,
    high,
    inclusive: true,
    assumptions: assumptions,
  )) {
    final isAscending = numFrom <= numTo;
    try {
      final fromLim = function.limit(
        variable,
        fromExpr,
        direction: isAscending
            ? LimitDirection.fromAbove
            : LimitDirection.fromBelow,
        assumptions: assumptions,
      );
      final toLim = function.limit(
        variable,
        toExpr,
        direction: isAscending
            ? LimitDirection.fromBelow
            : LimitDirection.fromAbove,
        assumptions: assumptions,
      );
      bool isBadLimit(Expr e) => e.anyNode(
        (n) => n is Limit || n == Constant.infinity || n == Constant.undefined,
      );
      if (isBadLimit(fromLim) || isBadLimit(toLim)) {
        return null;
      }
    } on ArgumentError {
      return null;
    } on UnsupportedError {
      return null;
    } on StateError {
      return null;
    }
  }

  return (sum * (toExpr - fromExpr) / IntegerNumber.two).simplify(
    assumptions: assumptions,
  );
}

Expr? _subtractEndpointValues(Expr upper, Expr lower, Assumptions assumptions) {
  final u = upper.simplify(assumptions: assumptions);
  final l = lower.simplify(assumptions: assumptions);
  if (u.anyNode((n) => n is Limit || n == Constant.undefined) ||
      l.anyNode((n) => n is Limit || n == Constant.undefined)) {
    return null;
  }
  final uPosInf = u == Constant.infinity;
  final uNegInf = u == negInfinity;
  final lPosInf = l == Constant.infinity;
  final lNegInf = l == negInfinity;
  if (uPosInf || uNegInf || lPosInf || lNegInf) {
    if ((uPosInf && lPosInf) || (uNegInf && lNegInf)) return null;
    if (uPosInf || lNegInf) return Constant.infinity;
    return negInfinity;
  }
  final diff = (u - l).simplify(assumptions: assumptions);
  if (diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
    return null;
  }
  return diff;
}

Expr _expandLnForEndpointLimit(Expr expr) {
  if (expr case Ln(:final expr)) {
    if (expr case Abs(:final expr)) {
      final (num, den) = splitNumeratorDenominator(expr);
      if (den != IntegerNumber.one) {
        return (Ln(Abs(num)) - Ln(Abs(den))).simplify();
      }
    } else {
      final (num, den) = splitNumeratorDenominator(expr);
      if (den != IntegerNumber.one) {
        return (Ln(Abs(num)) - Ln(Abs(den))).simplify();
      }
    }
  }
  return expr.mapChildren(_expandLnForEndpointLimit);
}

Expr? _tryHalfPeriodAntiSymmetry(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
}) {
  if (isInfiniteBound(fromExpr) || isInfiniteBound(toExpr)) return null;
  final numFrom = evaluateBoundNumeric(fromExpr);
  final numTo = evaluateBoundNumeric(toExpr);
  if (numFrom == null ||
      numTo == null ||
      !numFrom.isFinite ||
      !numTo.isFinite ||
      exceedsNodeBudget(function, 100)) {
    return null;
  }
  final halfPeriod = ((toExpr - fromExpr) / IntegerNumber.two).simplify(
    assumptions: assumptions,
  );
  final shifted = function
      .substitute(variable, Variable(variable) + halfPeriod)
      .simplify(assumptions: assumptions);
  if ((function + shifted).simplify(assumptions: assumptions) !=
      IntegerNumber.zero) {
    return null;
  }
  final low = math.min(numFrom, numTo);
  final high = math.max(numFrom, numTo);
  if (_hasAnyDenominatorPole(
    function,
    variable,
    low,
    high,
    inclusive: true,
    assumptions: assumptions,
  )) {
    return null;
  }
  var hasUnsafeTan = false;
  function.anyNode((n) {
    if (n case Tan(:final expr) when expr.dependsOn(variable)) {
      final isBoundedTrig = switch (expr) {
        Sin() || Cos() => true,
        Mul(:final factors) when factors.length == 2 =>
          factors.any((f) => f is Sin || f is Cos) &&
              factors.whereType<Number>().every(
                (c) => c.toDouble().abs() < 1.5,
              ),
        _ => false,
      };
      if (!isBoundedTrig) hasUnsafeTan = true;
    }
    return false;
  });
  if (hasUnsafeTan) return null;
  return IntegerNumber.zero;
}

Expr? _tryReciprocalSymmetry(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
  required Expr Function(
    Expr function,
    String variable, {
    required Assumptions assumptions,
  })
  antiDerivative,
}) {
  if (isInfiniteBound(fromExpr) || isInfiniteBound(toExpr)) return null;
  if (fromExpr == IntegerNumber.one ||
      toExpr == IntegerNumber.one ||
      !isPositiveConstant(fromExpr) ||
      !isPositiveConstant(toExpr)) {
    return null;
  }
  if ((fromExpr * toExpr).simplify(assumptions: assumptions) !=
      IntegerNumber.one) {
    return null;
  }
  if (exceedsNodeBudget(function, 120)) return null;

  final xVar = Variable(variable);
  final subst = function
      .substitute(variable, IntegerNumber.one / xVar)
      .simplify(assumptions: assumptions);
  var jac = (subst / Pow(xVar, IntegerNumber.two)).simplify(
    assumptions: assumptions,
  );
  {
    final (jnRaw, jdRaw) = splitNumeratorDenominator(jac);
    final jnExp = jnRaw.expand().simplify(assumptions: assumptions);
    final jdExp = jdRaw.expand().simplify(assumptions: assumptions);
    var minExp = 0;
    void scanNeg(Expr e) {
      e.anyNode((n) {
        if (n case Pow(:final base, exponent: IntegerNumber(asInt: final k?))
            when base == xVar && k < minExp) {
          minExp = k;
        }
        return false;
      });
    }

    scanNeg(jnExp);
    scanNeg(jdExp);
    if (minExp < 0) {
      final scalePow = Pow(xVar, IntegerNumber.of(-minExp));
      final jnPos = (jnExp * scalePow).expand().simplify(
        assumptions: assumptions,
      );
      final jdPos = (jdExp * scalePow).expand().simplify(
        assumptions: assumptions,
      );
      jac = (jnPos / jdPos).simplify(assumptions: assumptions);
    }
  }

  // Pull common x^k factors in numerator/denominator of rational expressions
  // like (1 + x^2) / (x^2 + x^2022) without expanding high-degree polynomials.
  final sum = (function + jac).simplify(assumptions: assumptions);
  Expr? avg;
  if (sum case Add(terms: [final s0, final s1])) {
    final (n0, d0) = splitNumeratorDenominator(s0);
    final (n1, d1) = splitNumeratorDenominator(s1);
    if (d0 != IntegerNumber.one && d1 != IntegerNumber.one) {
      int minXDeg(Expr e) {
        final coeffs = extractPolynomialCoefficients(e, variable);
        if (coeffs == null || coeffs.isEmpty) return 0;
        return coeffs.keys.reduce(math.min);
      }

      final min0 = minXDeg(d0);
      final min1 = minXDeg(d1);
      final shift = min0 - min1;
      if (shift != 0) {
        final sPow = Pow(xVar, IntegerNumber.of(shift.abs()));
        final effD0 = shift < 0
            ? (d0 * sPow).expand().simplify(assumptions: assumptions)
            : d0;
        final effN0 = shift < 0
            ? (n0 * sPow).expand().simplify(assumptions: assumptions)
            : n0;
        final effD1 = shift > 0
            ? (d1 * sPow).expand().simplify(assumptions: assumptions)
            : d1;
        final effN1 = shift > 0
            ? (n1 * sPow).expand().simplify(assumptions: assumptions)
            : n1;
        if ((effD0 - effD1).simplify(assumptions: assumptions) ==
            IntegerNumber.zero) {
          avg = ((effN0 + effN1) / (IntegerNumber.two * effD0)).simplify(
            assumptions: assumptions,
          );
        }
      }
      // Check if d0 / x^k == d1 / x^m or if (n0*d1 + n1*d0) has simple form.
      final ratioD = avg == null
          ? (d1 / d0).simplify(assumptions: assumptions)
          : IntegerNumber.zero;
      if (avg == null &&
          ratioD is Pow &&
          ratioD.base == xVar &&
          !ratioD.exponent.dependsOn(variable)) {
        final scaledN = (n0 * ratioD + n1).simplify(assumptions: assumptions);
        avg = (scaledN / (IntegerNumber.two * d1)).simplify(
          assumptions: assumptions,
        );
      } else if (avg == null) {
        final ratio0 = (d0 / d1).simplify(assumptions: assumptions);
        if (ratio0 case Pow(base: final rb, exponent: final re)
            when rb == xVar && !re.dependsOn(variable)) {
          final scaledN = (n0 + n1 * ratio0).simplify(assumptions: assumptions);
          avg = (scaledN / (IntegerNumber.two * d0)).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }
  if (avg == null) {
    final tog = sum
        .together(assumptions: assumptions)
        .simplify(assumptions: assumptions);
    var maxExp = 0;
    tog.anyNode((n) {
      if (n case Pow(:final base, exponent: IntegerNumber(asInt: final k?))
          when base == xVar) {
        if (k.abs() > maxExp) maxExp = k.abs();
      }
      return false;
    });
    if (maxExp <= 12 && !exceedsNodeBudget(tog, 160)) {
      avg = (tog.cancel(assumptions: assumptions) / IntegerNumber.two).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (avg == null) return null;

  // Require sparse/algebraic reduction to actually simplify high-degree factors.
  final (aNum, aDen) = splitNumeratorDenominator(avg);
  if (aDen != IntegerNumber.one &&
      aNum.freeVariables.length <= 1 &&
      aDen.freeVariables.length <= 1) {
    // Check factor cancellation when aNum = A * F and aDen = B * F (or common binomial factor)
    final numFacts = aNum is Mul ? aNum.factors : [aNum];
    final denFacts = aDen is Mul ? aDen.factors : [aDen];
    final keptNum = List<Expr>.from(numFacts);
    final keptDen = List<Expr>.from(denFacts);
    for (var i = keptNum.length - 1; i >= 0; i--) {
      for (var j = keptDen.length - 1; j >= 0; j--) {
        if (keptNum[i] == keptDen[j]) {
          keptNum.removeAt(i);
          keptDen.removeAt(j);
          break;
        }
        // Check factor * x^k or common factor inside simple binomials:
        final ratio = (keptNum[i] / keptDen[j]).simplify(
          assumptions: assumptions,
        );
        if (!ratio.dependsOn(variable)) {
          keptNum[i] = ratio;
          keptDen.removeAt(j);
          break;
        }
      }
    }
    if (keptNum.length != numFacts.length ||
        keptDen.length != denFacts.length) {
      final nNew = keptNum.isEmpty
          ? IntegerNumber.one
          : (keptNum.length == 1
                ? keptNum.first
                : Mul(keptNum).simplify(assumptions: assumptions));
      final dNew = keptDen.isEmpty
          ? IntegerNumber.one
          : (keptDen.length == 1
                ? keptDen.first
                : Mul(keptDen).simplify(assumptions: assumptions));
      avg = (nNew / dNew).simplify(assumptions: assumptions);
    } else if (aNum.anyNode((n) => n is Pow && n.exponent is IntegerNumber)) {
      // Sparse polynomial divisibility check via explicit term division
      try {
        final nc = extractPolynomialCoefficients(aNum, variable);
        final dc = extractPolynomialCoefficients(aDen, variable);
        if (nc != null && dc != null && maxPolynomialDegree(nc) >= 0) {
          // Strip common x^m monomial factor first so x^2 * (1 + x^2020) divides cleanly!
          final minN = nc.keys.reduce(math.min);
          final minD = dc.keys.reduce(math.min);
          if (minD > 0 && minN == 0) {
            // Pull x^minD out of denominator, factor remaining denominator part.
            final remD = <int, Expr>{
              for (final e in dc.entries) e.key - minD: e.value,
            };
            final dRest = buildPolynomialFromCoefficients(remD, variable);
            final div = aNum.polynomialDivide(
              dRest,
              variable,
              assumptions: assumptions,
            );
            if (div.remainder == IntegerNumber.zero) {
              avg = (div.quotient / Pow(xVar, IntegerNumber.of(minD))).simplify(
                assumptions: assumptions,
              );
            }
          }
        }
      } on ArgumentError {
        // Ignored.
      }
    }
  }

  // Only take the symmetric form if it avoids re-triggering or simplifies away the
  // high-degree denominator cleanly.
  if (avg == null ||
      avg == function ||
      avg.anyNode(
        (n) =>
            n is Pow &&
            n.exponent is IntegerNumber &&
            ((n.exponent as IntegerNumber).asInt?.abs() ?? 0) > 20,
      )) {
    return null;
  }

  final numFrom = evaluateBoundNumeric(fromExpr)!;
  final numTo = evaluateBoundNumeric(toExpr)!;
  final low = math.min(numFrom, numTo);
  final high = math.max(numFrom, numTo);
  if (_hasAnyDenominatorPole(
    function,
    variable,
    low,
    high,
    inclusive: true,
    assumptions: assumptions,
  )) {
    return null;
  }
  final res = evaluateDefiniteIntegral(
    avg,
    variable,
    fromExpr,
    toExpr,
    assumptions: assumptions,
    antiDerivative: antiDerivative,
  );
  return res.anyNode((n) => n is Integral && n.variable == variable)
      ? null
      : res;
}

Expr? _tryFloorCeilDefinite(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
  required Expr Function(
    Expr function,
    String variable, {
    required Assumptions assumptions,
  })
  antiDerivative,
  int depth = 0,
}) {
  if (depth >= 3 || isInfiniteBound(fromExpr) || isInfiniteBound(toExpr)) {
    return null;
  }
  final numFrom = evaluateBoundNumeric(fromExpr);
  final numTo = evaluateBoundNumeric(toExpr);
  if (numFrom == null ||
      numTo == null ||
      !numFrom.isFinite ||
      !numTo.isFinite) {
    return null;
  }
  if (numFrom > numTo) {
    final flipped = _tryFloorCeilDefinite(
      function,
      variable,
      toExpr,
      fromExpr,
      assumptions: assumptions,
      antiDerivative: antiDerivative,
      depth: depth,
    );
    return flipped != null
        ? (-flipped).simplify(assumptions: assumptions)
        : null;
  }

  final xVar = Variable(variable);
  var allSimpleVar = true;
  function.anyNode((n) {
    if ((n is Floor || n is Ceil) && n.dependsOn(variable)) {
      final arg = n is Floor ? n.expr : (n as Ceil).expr;
      if (arg != xVar) allSimpleVar = false;
    }
    return false;
  });

  if (allSimpleVar && fromExpr is IntegerNumber && toExpr is IntegerNumber) {
    final m = fromExpr.asInt;
    final n = toExpr.asInt;
    if (m != null && n != null && m < n) {
      if (n - m <= 64) {
        final parts = <Expr>[];
        for (var k = m; k < n; k++) {
          Expr substStep(Expr e) {
            if (e is Floor && e.expr == xVar) return IntegerNumber.of(k);
            if (e is Ceil && e.expr == xVar) return IntegerNumber.of(k + 1);
            return e.mapChildren(substStep);
          }

          final pieceFn = substStep(function)
              .simplify(assumptions: assumptions);
          final pieceVal = evaluateDefiniteIntegral(
            pieceFn,
            variable,
            IntegerNumber.of(k),
            IntegerNumber.of(k + 1),
            assumptions: assumptions,
            antiDerivative: antiDerivative,
          );
          if (hasUnevaluatedIntegral(pieceVal, variable)) return null;
          parts.add(pieceVal);
        }
        return Add(parts).simplify(assumptions: assumptions);
      } else {
        const kName = '_fk';
        const tName = '_ft';
        const kVar = Variable(kName);
        const tVar = Variable(tName);
        Expr substShift(Expr e) {
          if (e is Floor && e.expr == xVar) return kVar;
          if (e is Ceil && e.expr == xVar) return kVar + IntegerNumber.one;
          if (e == xVar) return kVar + tVar;
          return e.mapChildren(substShift);
        }

        final cellFn = substShift(function).simplify(assumptions: assumptions);
        final cellVal = evaluateDefiniteIntegral(
          cellFn,
          tName,
          IntegerNumber.zero,
          IntegerNumber.one,
          assumptions: assumptions,
          antiDerivative: antiDerivative,
        );
        if (hasUnevaluatedIntegral(cellVal, tName)) return null;
        final sumRes = cellVal.sum(
          kName,
          fromExpr,
          IntegerNumber.of(n - 1),
          assumptions: assumptions,
        );
        if (!sumRes.anyNode((node) => node is Sum)) {
          return sumRes.simplify(assumptions: assumptions);
        }
        return null;
      }
    }
  }

  // Case 2: General monotone innermost Floor(g) or Ceil(g) splitting
  Expr? innermostNode;
  Expr? innermostArg;
  var isFloorNode = true;
  void findInnermost(Expr e) {
    if (innermostNode != null) return;
    if (e is Floor && e.expr.dependsOn(variable)) {
      if (!e.expr.anyNode(
        (c) => (c is Floor || c is Ceil) && c.dependsOn(variable),
      )) {
        innermostNode = e;
        innermostArg = e.expr;
        isFloorNode = true;
        return;
      }
    }
    if (e is Ceil && e.expr.dependsOn(variable)) {
      if (!e.expr.anyNode(
        (c) => (c is Floor || c is Ceil) && c.dependsOn(variable),
      )) {
        innermostNode = e;
        innermostArg = e.expr;
        isFloorNode = false;
        return;
      }
    }
    e.mapChildren((c) {
      findInnermost(c);
      return c;
    });
  }

  findInnermost(function);
  if (innermostNode == null || innermostArg == null) return null;
  if (innermostArg!.anyNode(
    (n) => n is Sin || n is Cos || n is Tan || n is Sinh || n is Cosh,
  )) {
    return null;
  }

  try {
    final gPrime = innermostArg!.derivative(variable, assumptions: assumptions);
    var sign = 0;
    for (var s = 1; s <= 7; s++) {
      final sx = numFrom + (numTo - numFrom) * (s / 8.0);
      final dv = gPrime.evaluate({variable: sx});
      if (!dv.isFinite || dv == 0.0) return null;
      final curSign = dv > 0 ? 1 : -1;
      if (sign == 0) {
        sign = curSign;
      } else if (curSign != sign) {
        return null;
      }
    }
    final gFrom = innermostArg!.evaluate({variable: numFrom});
    final gTo = innermostArg!.evaluate({variable: numTo});
    if (!gFrom.isFinite || !gTo.isFinite) return null;
    final kMin = math.min(gFrom, gTo).floor() - 1;
    final kMax = math.max(gFrom, gTo).ceil() + 1;
    if (kMax - kMin > 24) return null;

    final breaks = <({double val, Expr expr})>[];
    for (var k = kMin; k <= kMax; k++) {
      final roots = (innermostArg! - IntegerNumber.of(k)).solve(
        variable,
        assumptions: Assumptions.real,
      );
      for (final root in roots) {
        if (root.anyNode((n) => n is ComplexNumber)) continue;
        final rv = evaluateBoundNumeric(root);
        if (rv != null && rv > numFrom + 1e-11 && rv < numTo - 1e-11) {
          if (!breaks.any((b) => (b.val - rv).abs() < 1e-11)) {
            breaks.add((val: rv, expr: root));
          }
        }
      }
    }
    if (breaks.length > 24) return null;
    breaks.sort((a, b) => a.val.compareTo(b.val));
    final pts = <Expr>[fromExpr, for (final b in breaks) b.expr, toExpr];
    final parts = <Expr>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final v0 = evaluateBoundNumeric(p0);
      final v1 = evaluateBoundNumeric(p1);
      if (v0 == null || v1 == null) return null;
      final mid = 0.5 * (v0 + v1);
      final gMid = innermostArg!.evaluate({variable: mid});
      if (!gMid.isFinite) return null;
      final expectedStep = isFloorNode ? gMid.floor() : gMid.ceil();
      for (final frac in const [0.2, 0.8]) {
        final gv = innermostArg!.evaluate({variable: v0 + (v1 - v0) * frac});
        if (!gv.isFinite) return null;
        final step = isFloorNode ? gv.floor() : gv.ceil();
        if (step != expectedStep) return null;
      }
      final intVal = IntegerNumber.of(expectedStep);
      Expr replaceNode(Expr e) {
        if (e == innermostNode) return intVal;
        return e.mapChildren(replaceNode);
      }

      final pieceFn = replaceNode(function).simplify(assumptions: assumptions);
      final pieceVal =
          pieceFn.anyNode(
            (n) => (n is Floor || n is Ceil) && n.dependsOn(variable),
          )
          ? _tryFloorCeilDefinite(
              pieceFn,
              variable,
              p0,
              p1,
              assumptions: assumptions,
              antiDerivative: antiDerivative,
              depth: depth + 1,
            )
          : evaluateDefiniteIntegral(
              pieceFn,
              variable,
              p0,
              p1,
              assumptions: assumptions,
              antiDerivative: antiDerivative,
            );
      if (pieceVal == null || hasUnevaluatedIntegral(pieceVal, variable)) {
        return null;
      }
      parts.add(pieceVal);
    }
    return Add(parts).simplify(assumptions: assumptions);
  } on ArgumentError {
    return null;
  } on UnsupportedError {
    return null;
  } on StateError {
    return null;
  }
}

Expr? _tryPiecewiseAbsMinMax(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  required Assumptions assumptions,
  required Expr Function(
    Expr function,
    String variable, {
    required Assumptions assumptions,
  })
  antiDerivative,
  int depth = 0,
}) {
  if (depth >= 3 || isInfiniteBound(fromExpr) || isInfiniteBound(toExpr)) {
    return null;
  }
  final numFrom = evaluateBoundNumeric(fromExpr);
  final numTo = evaluateBoundNumeric(toExpr);
  if (numFrom == null ||
      numTo == null ||
      !numFrom.isFinite ||
      !numTo.isFinite) {
    return null;
  }
  if (numFrom > numTo) {
    final flipped = _tryPiecewiseAbsMinMax(
      function,
      variable,
      toExpr,
      fromExpr,
      assumptions: assumptions,
      antiDerivative: antiDerivative,
      depth: depth,
    );
    return flipped != null
        ? (-flipped).simplify(assumptions: assumptions)
        : null;
  }

  // Fast exact antiderivative for standalone c * |sin(a*x + b)| or c * |cos(a*x + b)|
  {
    final (constPart, absNode) = switch (function) {
      Abs() => (IntegerNumber.one as Expr, function),
      Mul(:final factors)
          when factors.where((f) => f.dependsOn(variable)).length == 1 &&
              factors.firstWhere((f) => f.dependsOn(variable)) is Abs =>
        (
          Mul([
            for (final f in factors)
              if (f is! Abs) f,
          ]).simplify(assumptions: assumptions),
          factors.firstWhere((f) => f.dependsOn(variable)) as Abs,
        ),
      _ => (null, null),
    };
    if (constPart != null && absNode != null) {
      final arg = absNode.expr;
      Expr? linArg;
      var shift = IntegerNumber.zero as Expr;
      if (arg case Sin(:final expr)) {
        linArg = expr;
      } else if (arg case Cos(:final expr)) {
        linArg = expr;
        shift = (Constant.pi / IntegerNumber.two).simplify();
      }
      if (linArg != null) {
        if (linArg.matchLinear(variable) case (:final a, :final b)
            when isProvenReal(a, assumptions)) {
          final absA = Abs(a).simplify(assumptions: assumptions);
          final uFrom = (a * fromExpr + b + shift).simplify(
            assumptions: assumptions,
          );
          final uTo = (a * toExpr + b + shift).simplify(
            assumptions: assumptions,
          );
          final uLow = evaluateBoundNumeric(uFrom);
          final uHigh = evaluateBoundNumeric(uTo);
          if (uLow != null &&
              uHigh != null &&
              uLow.isFinite &&
              uHigh.isFinite) {
            Expr evalF(Expr uExpr, double uVal) {
              final q = uVal / math.pi;
              var m = q.floor();
              if ((q - q.roundToDouble()).abs() < 1e-11) {
                m = q.round();
              }
              final sign = m.isEven
                  ? IntegerNumber.one
                  : IntegerNumber.negativeOne;
              return (IntegerNumber.of(2 * m) - sign * Cos(uExpr)).simplify(
                assumptions: assumptions,
              );
            }

            final fLow = evalF(uFrom, uLow);
            final fHigh = evalF(uTo, uHigh);
            final diff = (uHigh >= uLow ? (fHigh - fLow) : (fLow - fHigh))
                .simplify(assumptions: assumptions);
            return (constPart * diff / absA).simplify(assumptions: assumptions);
          }
        }
      }
    }
  }

  // General region splitting for Abs(g), Min(args), Max(args)
  final zeroTargets = <Expr>[];
  void collectTargets(Expr e) {
    if (e case Abs(:final expr) when expr.dependsOn(variable)) {
      zeroTargets.add(expr);
    } else if (e case Min(:final args) when e.dependsOn(variable)) {
      for (var i = 0; i < args.length; i++) {
        for (var j = i + 1; j < args.length; j++) {
          final diff = (args[i] - args[j]).simplify(assumptions: assumptions);
          if (diff.dependsOn(variable)) zeroTargets.add(diff);
        }
      }
    } else if (e case Max(:final args) when e.dependsOn(variable)) {
      for (var i = 0; i < args.length; i++) {
        for (var j = i + 1; j < args.length; j++) {
          final diff = (args[i] - args[j]).simplify(assumptions: assumptions);
          if (diff.dependsOn(variable)) zeroTargets.add(diff);
        }
      }
    }
    e.mapChildren((c) {
      collectTargets(c);
      return c;
    });
  }

  collectTargets(function);
  if (zeroTargets.isEmpty) return null;

  final breaks = <({double val, Expr expr})>[];
  void addBreak(double rv, Expr root) {
    if (rv > numFrom + 1e-11 && rv < numTo - 1e-11) {
      if (!breaks.any((b) => (b.val - rv).abs() < 1e-11)) {
        breaks.add((val: rv, expr: root));
      }
    }
  }

  void addTrigZeroFamilies(Expr linInner, Expr targetPhase, Expr period) {
    if (linInner.matchLinear(variable) case (:final a, :final b)) {
      final aNum = evaluateBoundNumeric(a);
      final bNum = evaluateBoundNumeric(b);
      final tNum = evaluateBoundNumeric(targetPhase);
      final pNum = evaluateBoundNumeric(period);
      if (aNum == null ||
          bNum == null ||
          tNum == null ||
          pNum == null ||
          aNum == 0) {
        return;
      }
      final kLo =
          ((math.min(aNum * numFrom, aNum * numTo) + bNum - tNum) / pNum)
              .floor() -
          1;
      final kHi =
          ((math.max(aNum * numFrom, aNum * numTo) + bNum - tNum) / pNum)
              .ceil() +
          1;
      if (kHi - kLo > 32) return;
      for (var k = kLo; k <= kHi; k++) {
        final root = ((targetPhase + IntegerNumber.of(k) * period - b) / a)
            .simplify(assumptions: assumptions);
        final rv = evaluateBoundNumeric(root);
        if (rv != null) addBreak(rv, root);
      }
    }
  }

  for (final target in zeroTargets) {
    // Handle c0 + c1 * sin(lin) = 0 or c0 + c1 * cos(lin) = 0
    var handledTrig = false;
    final terms = target is Add ? target.terms : [target];
    if (terms.length == 2) {
      final cTerms = [
        for (final t in terms)
          if (!t.dependsOn(variable)) t,
      ];
      final vTerms = [
        for (final t in terms)
          if (t.dependsOn(variable)) t,
      ];
      if (cTerms.length == 1 && vTerms.length == 1) {
        final (cVar, fn) = switch (vTerms.first) {
          Sin() || Cos() => (IntegerNumber.one as Expr, vTerms.first),
          Mul(:final factors)
              when factors.where((f) => f.dependsOn(variable)).length == 1 =>
            (
              Mul([
                for (final f in factors)
                  if (!f.dependsOn(variable)) f,
              ]).simplify(assumptions: assumptions),
              factors.firstWhere((f) => f.dependsOn(variable)),
            ),
          _ => (null, null),
        };
        if (cVar != null && fn is Sin) {
          final rhs = (-cTerms.first / cVar).simplify(assumptions: assumptions);
          final theta = Asin(rhs).simplify(assumptions: assumptions);
          if (!theta.anyNode((n) => n is Asin)) {
            addTrigZeroFamilies(
              fn.expr,
              theta,
              IntegerNumber.two * Constant.pi,
            );
            addTrigZeroFamilies(
              fn.expr,
              (Constant.pi - theta).simplify(assumptions: assumptions),
              IntegerNumber.two * Constant.pi,
            );
            handledTrig = true;
          }
        } else if (cVar != null && fn is Cos) {
          final rhs = (-cTerms.first / cVar).simplify(assumptions: assumptions);
          final theta = Acos(rhs).simplify(assumptions: assumptions);
          if (!theta.anyNode((n) => n is Acos)) {
            addTrigZeroFamilies(
              fn.expr,
              theta,
              IntegerNumber.two * Constant.pi,
            );
            addTrigZeroFamilies(
              fn.expr,
              (-theta).simplify(assumptions: assumptions),
              IntegerNumber.two * Constant.pi,
            );
            handledTrig = true;
          }
        }
      } else if (vTerms.length == 2 && vTerms[0] is Sin) {
        if (vTerms[1] case Mul(:final factors)
            when factors.length == 2 &&
                factors.contains(IntegerNumber.negativeOne) &&
                factors.any((f) => f is Sin)) {
          final u = (vTerms[0] as Sin).expr;
          final v = (factors.firstWhere((f) => f is Sin) as Sin).expr;
          addTrigZeroFamilies(
            ((u - v) / IntegerNumber.two).simplify(assumptions: assumptions),
            IntegerNumber.zero,
            Constant.pi,
          );
          addTrigZeroFamilies(
            ((u + v) / IntegerNumber.two).simplify(assumptions: assumptions),
            (Constant.pi / IntegerNumber.two).simplify(),
            Constant.pi,
          );
          handledTrig = true;
        }
      } else if (vTerms.length == 2 && vTerms[1] is Sin) {
        if (vTerms[0] case Mul(:final factors)
            when factors.length == 2 &&
                factors.contains(IntegerNumber.negativeOne) &&
                factors.any((f) => f is Sin)) {
          final u = (vTerms[1] as Sin).expr;
          final v = (factors.firstWhere((f) => f is Sin) as Sin).expr;
          addTrigZeroFamilies(
            ((u - v) / IntegerNumber.two).simplify(assumptions: assumptions),
            IntegerNumber.zero,
            Constant.pi,
          );
          addTrigZeroFamilies(
            ((u + v) / IntegerNumber.two).simplify(assumptions: assumptions),
            (Constant.pi / IntegerNumber.two).simplify(),
            Constant.pi,
          );
          handledTrig = true;
        }
      }
    }
    if (!handledTrig) {
      try {
        for (final root in target.solve(
          variable,
          assumptions: Assumptions.real,
        )) {
          if (root.anyNode((n) => n is ComplexNumber)) continue;
          final rv = evaluateBoundNumeric(root);
          if (rv != null) addBreak(rv, root);
        }
      } on ArgumentError {
        return null;
      } on UnsupportedError {
        return null;
      } on StateError {
        return null;
      }
    }
  }

  if (breaks.length > 32) return null;
  breaks.sort((a, b) => a.val.compareTo(b.val));
  final pts = <Expr>[fromExpr, for (final b in breaks) b.expr, toExpr];
  final parts = <Expr>[];
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = pts[i];
    final p1 = pts[i + 1];
    final v0 = evaluateBoundNumeric(p0);
    final v1 = evaluateBoundNumeric(p1);
    if (v0 == null || v1 == null) return null;
    final mid = 0.5 * (v0 + v1);

    Expr resolvePiecewise(Expr e) {
      final mChild = e.mapChildren(resolvePiecewise);
      if (mChild case Abs(:final expr) when expr.dependsOn(variable)) {
        final mv = expr.evaluate({variable: mid});
        if (!mv.isFinite) return mChild;
        return mv >= 0 ? expr : (-expr).simplify(assumptions: assumptions);
      }
      if (mChild case Min(:final args) when mChild.dependsOn(variable)) {
        var best = args.first;
        var bestVal = best.evaluate({variable: mid});
        for (var j = 1; j < args.length; j++) {
          final av = args[j].evaluate({variable: mid});
          if (av < bestVal) {
            bestVal = av;
            best = args[j];
          }
        }
        return best;
      }
      if (mChild case Max(:final args) when mChild.dependsOn(variable)) {
        var best = args.first;
        var bestVal = best.evaluate({variable: mid});
        for (var j = 1; j < args.length; j++) {
          final av = args[j].evaluate({variable: mid});
          if (av > bestVal) {
            bestVal = av;
            best = args[j];
          }
        }
        return best;
      }
      return mChild;
    }

    try {
      final pieceFn = resolvePiecewise(function)
          .simplify(assumptions: assumptions);
      if (pieceFn.anyNode(
        (n) => (n is Abs || n is Min || n is Max) && n.dependsOn(variable),
      )) {
        return null;
      }
      final pieceVal = evaluateDefiniteIntegral(
        pieceFn,
        variable,
        p0,
        p1,
        assumptions: assumptions,
        antiDerivative: antiDerivative,
      );
      if (hasUnevaluatedIntegral(pieceVal, variable)) return null;
      parts.add(pieceVal);
    } on ArgumentError {
      return null;
    } on UnsupportedError {
      return null;
    } on StateError {
      return null;
    }
  }
  return Add(parts).simplify(assumptions: assumptions);
}
