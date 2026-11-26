import 'dart:math' as math;

import '../../algebra/expand.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../algebra/simplify/domain.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../solver/univariate.dart';
import '../limit.dart';
import '../linear_form.dart';
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
          final diff = _subtractEndpointValues(upper, lower, assumptions);
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
        try {
          final isAscending =
              (evaluateBoundNumeric(fromExpr) ?? 0.0) <=
              (evaluateBoundNumeric(toExpr) ?? 1.0);
          final upper = isInfiniteBound(toExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  toExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.limit(
                  variable,
                  toExpr,
                  direction: isAscending
                      ? LimitDirection.fromBelow
                      : LimitDirection.fromAbove,
                  assumptions: assumptions,
                );
          final lower = isInfiniteBound(fromExpr)
              ? effectiveAntiDeriv.limit(
                  variable,
                  fromExpr,
                  assumptions: assumptions,
                )
              : effectiveAntiDeriv.limit(
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
          // Fall through to definite integral special cases.
        } on UnsupportedError {
          // Fall through to definite integral special cases.
        } on StateError {
          // Fall through to definite integral special cases.
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
        domains: {variable: VariableDomain.real},
      );
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
    if (e case Pow(
      base: Add(terms: [final t0, final t1]),
      exponent: Number(isNegativeOne: true),
    )) {
      Expr? findNegPow(Expr t) {
        if (t case Pow(:final base, exponent: RealNumeric(:final sign))
            when sign < 0) {
          return Pow(base, (-t.exponent).simplify(assumptions: assumptions));
        }
        if (t case Mul(:final factors)) {
          for (final f in factors) {
            if (f case Pow(:final base, exponent: RealNumeric(:final sign))
                when sign < 0) {
              return Pow(
                base,
                (-f.exponent).simplify(assumptions: assumptions),
              );
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
    return e;
  }

  final normRefl = normalizeReciprocalNegPow(reflected);
  var sum = (function + normRefl).simplify(assumptions: assumptions);
  if (sum.dependsOn(variable) && sum is Add) {
    sum = sum
        .together(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }
  if (!sum.dependsOn(variable)) {
    return (sum * (toExpr - fromExpr) / IntegerNumber.two).simplify(
      assumptions: assumptions,
    );
  }
  return null;
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
