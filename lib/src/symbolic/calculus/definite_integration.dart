import 'dart:math' as math;

import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/domain.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../number/integer.dart';
import '../solver/univariate.dart';
import 'limit.dart';
import 'linear_form.dart';
import 'summation.dart';

final Expr _negInfinity = Mul(const [
  IntegerNumber.negativeOne,
  Constant.infinity,
], isSimplified: true);

/// Returns `true` if [bound] represents positive or negative infinity.
bool isInfiniteBound(Expr bound) =>
    bound == Constant.infinity ||
    bound == _negInfinity ||
    bound == -Constant.infinity;

/// Returns `true` if [expr] evaluates to a strictly positive constant.
bool isPositiveConstant(Expr expr) {
  if (expr is RationalNumber) return !expr.isNegative && !expr.isZero;
  if (expr is RealNumber) return expr.value > 0.0;
  if (expr.freeVariables.isEmpty) {
    try {
      return expr.evaluate(const {}) > 0.0;
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

/// Evaluates a definite symbolic integral $\int_a^b f(x) dx$ with respect to
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
  Assumptions assumptions = Assumptions.none,
  required Expr Function(
    Expr function,
    String variable, {
    Assumptions assumptions,
  })
  antiDerivative,
}) {
  final fromExpr = Expr.wrap(from).simplify(assumptions: assumptions);
  final toExpr = Expr.wrap(to).simplify(assumptions: assumptions);
  if (fromExpr == toExpr) {
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

    if (!hasInteriorPole) {
      final effectiveAntiDeriv = wrapLnWithAbs(antiDeriv, assumptions);
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
        final diff = (upper - lower).simplify(assumptions: assumptions);
        if (!diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
          return diff;
        }
      } on Object {
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
        final diff = (upper - lower).simplify(assumptions: assumptions);
        if (!diff.anyNode((n) => n is Limit || n == Constant.undefined)) {
          return diff;
        }
      } on Object {
        // Fall through to definite integral special cases.
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
  if (bound == _negInfinity || bound == -Constant.infinity) {
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

bool _hasInteriorPole(Expr expr, String variable, double low, double high) {
  final poles = findDenominatorRoots(expr, variable);
  for (final pole in poles) {
    if (pole > low && pole < high) {
      return true;
    }
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
      } on Object {
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
      } on Object {
        // Ignored.
      }
    }
    return false;
  });
}

/// Extracts all subexpressions that appear in negative power denominators.
List<Expr> extractDenominatorFactors(Expr expr) {
  final factors = <Expr>[];
  void visit(Expr e) {
    if (e is Pow) {
      final exp = e.exponent;
      if (exp is Number && exp.toDouble() < 0) {
        factors.add(e.base);
      } else {
        visit(e.base);
      }
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
Expr wrapLnWithAbs(Expr expr, [Assumptions assumptions = Assumptions.none]) {
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
  Assumptions assumptions = Assumptions.none,
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
  final poles = findDenominatorRoots(sFunc, variable);
  if (poles.isNotEmpty) {
    if (isInfiniteBound(fromExpr) || isInfiniteBound(toExpr)) {
      return false;
    }
    final numFrom = evaluateBoundNumeric(fromExpr);
    final numTo = evaluateBoundNumeric(toExpr);
    if (numFrom == null || numTo == null) return false;
    final low = numFrom < numTo ? numFrom : numTo;
    final high = numFrom < numTo ? numTo : numFrom;
    for (final pole in poles) {
      if (pole >= low - 1e-12 && pole <= high + 1e-12) {
        return false;
      }
    }
  }
  return true;
}

/// Pattern-table lookup and closed-form evaluation of famous improper and
/// definite integrals.
Expr? definiteIntegralSpecialCases(
  Expr function,
  String variable,
  Expr fromExpr,
  Expr toExpr, {
  Assumptions assumptions = Assumptions.none,
}) {
  // Flip reversed bounds: int_a^b f(x) dx = -int_b^a f(x) dx when a > b
  if ((fromExpr == Constant.infinity) ||
      (toExpr == _negInfinity || toExpr == -Constant.infinity) ||
      (toExpr == IntegerNumber.zero && isPositiveConstant(fromExpr))) {
    final flipped = definiteIntegralSpecialCases(
      function,
      variable,
      toExpr,
      fromExpr,
      assumptions: assumptions,
    );
    return flipped != null
        ? (-flipped).simplify(assumptions: assumptions)
        : null;
  }

  // Extract constant factors independent of variable
  final rawFactors = function is Mul ? function.factors : [function];
  final (:constFactors, :varFactors) = partitionFactors(rawFactors, variable);
  if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
    final constPart = constFactors.length == 1
        ? constFactors.first
        : Mul(constFactors).simplify(assumptions: assumptions);
    final varPart = varFactors.length == 1
        ? varFactors.first
        : Mul(varFactors).simplify(assumptions: assumptions);
    final inner = definiteIntegralSpecialCases(
      varPart,
      variable,
      fromExpr,
      toExpr,
      assumptions: assumptions,
    );
    if (inner != null) {
      return (constPart * inner).simplify(assumptions: assumptions);
    }
  }

  // Even integrand over [-infty, infty] -> 2 * int_0^infty f(x) dx
  if ((fromExpr == _negInfinity || fromExpr == -Constant.infinity) &&
      toExpr == Constant.infinity) {
    final reflected = function
        .substitute(variable, -Variable(variable))
        .simplify(assumptions: assumptions);
    if ((function - reflected).expand().simplify(assumptions: assumptions) ==
        IntegerNumber.zero) {
      final halfInt = definiteIntegralZeroToInfinity(
        function,
        variable,
        assumptions: assumptions,
      );
      if (halfInt != null) {
        return (IntegerNumber.two * halfInt).simplify(assumptions: assumptions);
      }
    }
  }

  // Domain [0, infty)
  if (fromExpr == IntegerNumber.zero && toExpr == Constant.infinity) {
    final res = definiteIntegralZeroToInfinity(
      function,
      variable,
      assumptions: assumptions,
    );
    if (res != null) return res;
  }

  // Domain [0, pi/2] or [0, pi]
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();
  if (fromExpr == IntegerNumber.zero &&
      (toExpr == halfPi || toExpr == Constant.pi)) {
    final trigRes = definiteIntegralTrigDomain(
      function,
      variable,
      toExpr,
      assumptions: assumptions,
    );
    if (trigRes != null) return trigRes;
  }

  // Domain [0, 1]
  if (fromExpr == IntegerNumber.zero && toExpr == IntegerNumber.one) {
    final unitRes = definiteIntegralUnitInterval(
      function,
      variable,
      assumptions: assumptions,
    );
    if (unitRes != null) return unitRes;
  }

  return null;
}

/// Improper integrals evaluated over the semi-infinite interval $[0, \infty)$.
Expr? definiteIntegralZeroToInfinity(
  Expr function,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final xVar = Variable(variable);
  final (num, den) = splitNumeratorDenominator(function);

  // 1. Dirichlet integral: sin(a*x) / x -> pi/2 * sign(a)
  //    and sin(a*x)^2 / x^2 -> pi/2 * |a|
  if (den == xVar && num is Sin) {
    if (num.expr.matchLinear(variable) case (a: final slope, :final b)
        when b == IntegerNumber.zero) {
      return (Constant.pi / IntegerNumber.two * Sign(slope)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (den case Pow(base: final b, exponent: IntegerNumber(asInt: 2))
      when b == xVar) {
    if (num case Pow(
      base: Sin(expr: final inner),
      exponent: IntegerNumber(asInt: 2),
    )) {
      if (inner.matchLinear(variable) case (a: final slope, b: final shift)
          when shift == IntegerNumber.zero) {
        return (Constant.pi / IntegerNumber.two * Abs(slope)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // 2. Fresnel integrals: sin(a*x^2) or cos(a*x^2) -> 1/4 * sqrt(2*pi / |a|)
  if (function case Sin(expr: final inner) || Cos(expr: final inner)) {
    final coeffs = extractPolynomialCoefficients(inner, variable);
    if (coeffs != null &&
        maxPolynomialDegree(coeffs) == 2 &&
        (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
        (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
      final a2 = coeffs[2] ?? IntegerNumber.zero;
      final absA = Abs(a2).simplify(assumptions: assumptions);
      if (isPositiveConstant(absA)) {
        final fresnelVal =
            (FractionNumber.quarter *
                    Pow(
                      (IntegerNumber.two * Constant.pi) / absA,
                      FractionNumber.half,
                    ))
                .simplify(assumptions: assumptions);
        return function is Sin
            ? (Sign(a2) * fresnelVal).simplify(assumptions: assumptions)
            : fresnelVal;
      }
    }
  }

  // 3. Euler Gamma integral: x^s * e^(-a*x) -> Gamma(s + 1) / a^(s + 1) for a > 0, s > -1
  final factors = function is Mul ? function.factors : [function];
  Expr? expSlope;
  Expr? xExponent;
  var validGamma = true;
  for (final f in factors) {
    if (expSlope == null && f is Pow && f.base == Constant.e) {
      if (f.exponent.matchLinear(variable) case (a: final slope, :final b)
          when b == IntegerNumber.zero) {
        final posA = (-slope).simplify(assumptions: assumptions);
        if (isPositiveConstant(posA) ||
            (posA is Variable &&
                assumptions.domainOf(posA.name) == VariableDomain.positive)) {
          expSlope = posA;
          continue;
        }
      }
    }
    if (xExponent == null && f == xVar) {
      xExponent = IntegerNumber.one;
      continue;
    }
    if (xExponent == null &&
        f is Pow &&
        f.base == xVar &&
        !f.exponent.dependsOn(variable)) {
      xExponent = f.exponent;
      continue;
    }
    validGamma = false;
    break;
  }
  if (validGamma && expSlope != null) {
    final s = xExponent ?? IntegerNumber.zero;
    final sPlus1 = (s + IntegerNumber.one).simplify(assumptions: assumptions);
    if (isPositiveConstant(sPlus1) ||
        (s is Variable &&
            assumptions.domainOf(s.name) == VariableDomain.positive)) {
      return (Gamma(sPlus1) / Pow(expSlope, sPlus1)).simplify(
        assumptions: assumptions,
      );
    }
  }

  // 4. Generalized Gaussian / Gamma integral: x^s * e^(-a*x^2) -> 1/2 * Gamma((s+1)/2) / a^((s+1)/2)
  Expr? gaussCoeff;
  Expr? gaussXExp;
  var validGaussGamma = true;
  for (final f in factors) {
    if (gaussCoeff == null && f is Pow && f.base == Constant.e) {
      final coeffs = extractPolynomialCoefficients(f.exponent, variable);
      if (coeffs != null &&
          maxPolynomialDegree(coeffs) == 2 &&
          (coeffs[1] ?? IntegerNumber.zero) == IntegerNumber.zero &&
          (coeffs[0] ?? IntegerNumber.zero) == IntegerNumber.zero) {
        final posA = (-(coeffs[2] ?? IntegerNumber.zero)).simplify(
          assumptions: assumptions,
        );
        if (isPositiveConstant(posA)) {
          gaussCoeff = posA;
          continue;
        }
      }
    }
    if (gaussXExp == null && f == xVar) {
      gaussXExp = IntegerNumber.one;
      continue;
    }
    if (gaussXExp == null &&
        f is Pow &&
        f.base == xVar &&
        !f.exponent.dependsOn(variable)) {
      gaussXExp = f.exponent;
      continue;
    }
    validGaussGamma = false;
    break;
  }
  if (validGaussGamma && gaussCoeff != null) {
    final s = gaussXExp ?? IntegerNumber.zero;
    final alpha = ((s + IntegerNumber.one) / IntegerNumber.two).simplify(
      assumptions: assumptions,
    );
    if (isPositiveConstant(alpha)) {
      return (FractionNumber.half * Gamma(alpha) / Pow(gaussCoeff, alpha))
          .simplify(assumptions: assumptions);
    }
  }

  // 5. Bose-Einstein & Fermi-Dirac integrals:
  //    int_0^infty x^(s-1) / (e^x - 1) dx = Gamma(s) * zeta(s)
  //    int_0^infty x^(s-1) / (e^x + 1) dx = Gamma(s) * eta(s)
  if (den case Add(terms: [final d0, final d1])) {
    final expTerm = d0 is Pow && d0.base == Constant.e && d0.exponent == xVar
        ? d0
        : (d1 is Pow && d1.base == Constant.e && d1.exponent == xVar
              ? d1
              : null);
    final constTerm = expTerm == d0 ? d1 : d0;
    if (expTerm != null &&
        (constTerm == IntegerNumber.negativeOne ||
            constTerm == IntegerNumber.one)) {
      int? s;
      if (num == xVar) {
        s = 2;
      } else if (num
          case Pow(base: final b, exponent: IntegerNumber(asInt: final m?))
          when b == xVar && m >= 1 && m.isOdd && m <= 15) {
        s = m + 1;
      }
      if (s != null && s.isEven) {
        final factSMinus1 = IntegerNumber(Integer.from(s - 1).factorial());
        final zetaS = evenZetaValue(s);
        if (constTerm == IntegerNumber.negativeOne) {
          return (factSMinus1 * zetaS).simplify(assumptions: assumptions);
        } else {
          final etaFactor =
              (IntegerNumber.one -
                      Pow(IntegerNumber.two, IntegerNumber.of(1 - s)))
                  .simplify();
          return (factSMinus1 * etaFactor * zetaS).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }

  return null;
}

/// Definite trigonometric integrals evaluated over $[0, \pi/2]$ or $[0, \pi]$.
Expr? definiteIntegralTrigDomain(
  Expr function,
  String variable,
  Expr toExpr, {
  Assumptions assumptions = Assumptions.none,
}) {
  final xVar = Variable(variable);
  final halfPi = (Constant.pi / IntegerNumber.two).simplify();

  // 1. Euler's log-sine / log-cosine integrals:
  //    int_0^(pi/2) ln(sin(x)) dx = int_0^(pi/2) ln(cos(x)) dx = -pi/2 * ln(2)
  //    int_0^pi ln(sin(x)) dx = -pi * ln(2)
  if (function case Ln(expr: Sin(expr: final inner)) when inner == xVar) {
    if (toExpr == halfPi) {
      return (-halfPi * Ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
    if (toExpr == Constant.pi) {
      return (-Constant.pi * Ln(IntegerNumber.two)).simplify(
        assumptions: assumptions,
      );
    }
  }
  if (function case Ln(expr: Cos(expr: final inner))
      when inner == xVar && toExpr == halfPi) {
    return (-halfPi * Ln(IntegerNumber.two)).simplify(assumptions: assumptions);
  }

  // 2. Wallis / Beta trigonometric integrals on [0, pi/2]:
  //    int_0^(pi/2) sin(x)^m * cos(x)^n dx = 1/2 * Beta((m+1)/2, (n+1)/2)
  if (toExpr == halfPi) {
    final factors = function is Mul ? function.factors : [function];
    Expr mExp = IntegerNumber.zero;
    Expr nExp = IntegerNumber.zero;
    var validWallis = true;
    for (final f in factors) {
      if (f case Sin(expr: final inner) when inner == xVar) {
        mExp = (mExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Cos(expr: final inner) when inner == xVar) {
        nExp = (nExp + IntegerNumber.one).simplify();
        continue;
      }
      if (f case Pow(base: Sin(expr: final inner), :final exponent)
          when inner == xVar && !exponent.dependsOn(variable)) {
        mExp = (mExp + exponent).simplify();
        continue;
      }
      if (f case Pow(base: Cos(expr: final inner), :final exponent)
          when inner == xVar && !exponent.dependsOn(variable)) {
        nExp = (nExp + exponent).simplify();
        continue;
      }
      validWallis = false;
      break;
    }
    if (validWallis &&
        (mExp != IntegerNumber.zero || nExp != IntegerNumber.zero)) {
      final aArg = ((mExp + IntegerNumber.one) / IntegerNumber.two).simplify();
      final bArg = ((nExp + IntegerNumber.one) / IntegerNumber.two).simplify();
      if (isPositiveConstant(aArg) && isPositiveConstant(bArg)) {
        return (FractionNumber.half * Beta(aArg, bArg)).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  return null;
}

/// Definite integrals evaluated over the unit interval $[0, 1]$.
Expr? definiteIntegralUnitInterval(
  Expr function,
  String variable, {
  Assumptions assumptions = Assumptions.none,
}) {
  final xVar = Variable(variable);
  final (num, den) = splitNumeratorDenominator(function);

  // 1. Logarithmic zeta/eta integrals on [0, 1]:
  //    int_0^1 ln(x) / (1 - x) dx = -pi^2 / 6
  //    int_0^1 ln(x) / (1 + x) dx = -pi^2 / 12
  //    int_0^1 ln(1 + x) / x dx = pi^2 / 12
  //    int_0^1 ln(1 - x) / x dx = -pi^2 / 6
  if (num case Ln(expr: final lnArg) when lnArg == xVar) {
    if ((den - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
    if ((den - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
  }
  if (den == xVar && num is Ln) {
    if ((num.expr - (IntegerNumber.one + xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12))
          .simplify(assumptions: assumptions);
    }
    if ((num.expr - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      return (-Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(6))
          .simplify(assumptions: assumptions);
    }
  }

  // 2. Euler Beta integral on [0, 1]:
  //    int_0^1 x^(a - 1) * (1 - x)^(b - 1) dx = Beta(a, b)
  final factors = function is Mul ? function.factors : [function];
  Expr aMinus1 = IntegerNumber.zero;
  Expr bMinus1 = IntegerNumber.zero;
  var hasOneMinusX = false;
  var validBeta = true;
  for (final f in factors) {
    if (f == xVar) {
      aMinus1 = (aMinus1 + IntegerNumber.one).simplify();
      continue;
    }
    if (f case Pow(base: final b, :final exponent)
        when b == xVar && !exponent.dependsOn(variable)) {
      aMinus1 = (aMinus1 + exponent).simplify();
      continue;
    }
    if ((f - (IntegerNumber.one - xVar)).expand().simplify() ==
        IntegerNumber.zero) {
      bMinus1 = (bMinus1 + IntegerNumber.one).simplify();
      hasOneMinusX = true;
      continue;
    }
    if (f case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            (base - (IntegerNumber.one - xVar)).expand().simplify() ==
                IntegerNumber.zero) {
      bMinus1 = (bMinus1 + exponent).simplify();
      hasOneMinusX = true;
      continue;
    }
    validBeta = false;
    break;
  }
  if (validBeta && hasOneMinusX) {
    final aArg = (aMinus1 + IntegerNumber.one).simplify();
    final bArg = (bMinus1 + IntegerNumber.one).simplify();
    if (isPositiveConstant(aArg) && isPositiveConstant(bArg)) {
      return Beta(aArg, bArg).simplify(assumptions: assumptions);
    }
  }

  return null;
}
