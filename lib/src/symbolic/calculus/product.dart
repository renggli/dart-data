import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/multiplicative.dart';
import '../algebra/simplify/transcendental.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../number/integer.dart';
import 'limit.dart';
import 'linear_form.dart';
import 'summation.dart';

/// Evaluates the definite product $\prod_{k=a}^b \text{factor}$.
Expr computeProduct(
  Expr factor,
  String variable,
  Expr from,
  Expr to, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplifiedFactor = factor.simplify(assumptions: assumptions);
  final a = from.simplify(assumptions: assumptions);
  final b = to.simplify(assumptions: assumptions);

  if (simplifiedFactor is Number && simplifiedFactor.isOne) {
    return IntegerNumber.one;
  }
  if (simplifiedFactor is Number && simplifiedFactor.isZero) {
    return IntegerNumber.zero;
  }

  if (b == Constant.infinity) {
    const limitVarName = '__prod_N';
    const limitVar = Variable(limitVarName);
    final mergedAssumptions = assumptions.assume(
      limitVarName,
      VariableDomain.integer,
    );
    final finite = computeProduct(
      simplifiedFactor,
      variable,
      a,
      limitVar,
      assumptions: mergedAssumptions,
    );
    if (finite is! Product) {
      try {
        final lim = finite.limit(
          limitVarName,
          Constant.infinity,
          assumptions: mergedAssumptions,
        );
        if (lim is! Limit && lim != Constant.undefined) {
          return lim.simplify(assumptions: assumptions);
        }
      } on UnsupportedError {
        // Fall through to closed-form infinite product matching.
      }
    }

    final infClosed = infiniteProductClosedForm(
      simplifiedFactor,
      variable,
      a,
      assumptions: assumptions,
    );
    if (infClosed != null) {
      return infClosed.simplify(assumptions: assumptions);
    }

    return Product(simplifiedFactor, variable, a, b, isSimplified: true);
  }

  // Concrete integer bounds
  if ((a, b) case (
    IntegerNumber(asInt: final start?),
    IntegerNumber(asInt: final end?),
  )) {
    if (end < start) {
      return IntegerNumber.one;
    }
    if (end - start <= 128) {
      final factors = <Expr>[];
      for (var k = start; k <= end; k++) {
        factors.add(
          simplifiedFactor
              .substitute(variable, IntegerNumber.of(k))
              .simplify(assumptions: assumptions),
        );
      }
      return simplifyMul(factors).simplify(assumptions: assumptions);
    }
  }

  final closed = closedFormProduct(simplifiedFactor, variable, a, b);
  if (closed != null) {
    return closed.simplify(assumptions: assumptions);
  }

  return Product(simplifiedFactor, variable, a, b, isSimplified: true);
}

/// Evaluates a finite product using algebraic rules (constants, linear factors,
/// exponentials, telescoping ratios).
Expr? closedFormProduct(Expr factor, String variable, Expr a, Expr b) {
  final count = (b - a + IntegerNumber.one).simplify();
  if (!factor.dependsOn(variable)) {
    return Pow(factor, count).simplify();
  }

  // Exponential factor: base^exponent where base is independent of variable
  if (factor case Pow(:final base, :final exponent)
      when !base.dependsOn(variable)) {
    final expSum = computeSum(exponent, variable, a, b);
    if (expSum is! Sum) {
      return Pow(base, expSum).simplify();
    }
  }

  // Power of variable-dependent base: (u(k))^p -> (prod u(k))^p
  if (factor case Pow(:final base, :final exponent)
      when !exponent.dependsOn(variable)) {
    final baseProd = closedFormProduct(base, variable, a, b);
    if (baseProd != null) {
      return Pow(baseProd, exponent).simplify();
    }
  }

  // Telescoping ratio or general product of factors
  final combined = factor.together().factor();
  final (num, den) = splitNumeratorDenominator(combined);
  if (den != IntegerNumber.one &&
      num.dependsOn(variable) &&
      den.dependsOn(variable)) {
    final tele = tryProductTelescoping(num, den, variable, a, b);
    if (tele != null) return tele;
  }

  // Split multiplication into constituent factors
  if (combined case Mul(:final factors) when factors.length > 1) {
    final prodParts = <Expr>[];
    for (final f in factors) {
      final p = closedFormProduct(f, variable, a, b);
      if (p == null) return null;
      prodParts.add(p);
    }
    return simplifyMul(prodParts);
  }

  // Linear factor: k + c (or c * k + d)
  if (factor.matchLinear(variable) case (a: final slope, b: final shift)) {
    final unitShift = (shift / slope).simplify();
    final lowerShifted = (a + unitShift).simplify();
    final upperShifted = (b + unitShift).simplify();
    final slopePow = slope == IntegerNumber.one
        ? IntegerNumber.one
        : Pow(slope, count).simplify();
    if (lowerShifted == IntegerNumber.one) {
      return (slopePow * Factorial(upperShifted)).simplify();
    }
    if ((lowerShifted, upperShifted) case (
      IntegerNumber(asInt: final l?),
      IntegerNumber(asInt: final u?),
    )) {
      if (l <= 0 && u >= 0) {
        return IntegerNumber.zero;
      }
      if (u < 0) {
        final nTerms = u - l + 1;
        final sign = nTerms.isOdd
            ? IntegerNumber.negativeOne
            : IntegerNumber.one;
        final numFact = Factorial(IntegerNumber.of(-l));
        final denFact = Factorial(IntegerNumber.of(-u - 1));
        return (slopePow * sign * numFact / denFact).simplify();
      }
      if (l > 1) {
        return (slopePow *
                Factorial(upperShifted) /
                Factorial(IntegerNumber.of(l - 1)))
            .simplify();
      }
    }
    if (lowerShifted is IntegerNumber && lowerShifted.isZero) {
      return IntegerNumber.zero;
    }
    if (lowerShifted case IntegerNumber(asInt: final l?) when l > 1) {
      return (slopePow *
              Factorial(upperShifted) /
              Factorial(IntegerNumber.of(l - 1)))
          .simplify();
    }
    return (slopePow *
            Gamma((upperShifted + IntegerNumber.one).simplify()) /
            Gamma(lowerShifted))
        .simplify();
  }

  return null;
}

List<Expr> expandPositivePowerFactors(Expr expr) {
  final raw = expr is Mul ? expr.factors : [expr];
  final expanded = <Expr>[];
  for (final f in raw) {
    if (f case Pow(:final base, exponent: IntegerNumber(asInt: final m?))
        when m > 1 && m <= 8) {
      for (var i = 0; i < m; i++) {
        expanded.add(base);
      }
    } else {
      expanded.add(f);
    }
  }
  return expanded;
}

Expr? tryProductTelescoping(
  Expr num,
  Expr den,
  String variable,
  Expr a,
  Expr b,
) {
  final single = trySingleRatioTelescoping(num, den, variable, a, b);
  if (single != null) return single;

  final numFactors = expandPositivePowerFactors(num);
  final denFactors = expandPositivePowerFactors(den);
  if (numFactors.length < 2 && denFactors.length < 2) return null;

  final constFactors = <Expr>[];
  final varNum = <Expr>[];
  final varDen = <Expr>[];
  for (final f in numFactors) {
    if (f.dependsOn(variable)) {
      varNum.add(f);
    } else {
      constFactors.add(f);
    }
  }
  for (final f in denFactors) {
    if (f.dependsOn(variable)) {
      varDen.add(f);
    } else {
      constFactors.add(Pow(f, IntegerNumber.negativeOne).simplify());
    }
  }
  if (varNum.length != varDen.length || varNum.isEmpty) return null;

  final usedDen = List<bool>.filled(varDen.length, false);
  final pairProducts = <Expr>[];
  for (final nf in varNum) {
    Expr? matchedProd;
    for (var j = 0; j < varDen.length; j++) {
      if (usedDen[j]) continue;
      final p = trySingleRatioTelescoping(nf, varDen[j], variable, a, b);
      if (p != null) {
        usedDen[j] = true;
        matchedProd = p;
        break;
      }
    }
    if (matchedProd == null) return null;
    pairProducts.add(matchedProd);
  }

  if (constFactors.isNotEmpty) {
    final count = (b - a + IntegerNumber.one).simplify();
    pairProducts.add(Pow(simplifyMul(constFactors), count).simplify());
  }
  return simplifyMul(pairProducts);
}

Expr? trySingleRatioTelescoping(
  Expr num,
  Expr den,
  String variable,
  Expr a,
  Expr b,
) {
  final kVar = Variable(variable);
  for (var d = 1; d <= 4; d++) {
    final kPlusD = (kVar + IntegerNumber.of(d)).simplify();
    // Case 1: num(k) == den(k + d) => prod_{k=a..b} g(k + d) / g(k)
    if (den.substitute(variable, kPlusD).expand().simplify() ==
        num.expand().simplify()) {
      final numParts = <Expr>[
        for (var s = 1; s <= d; s++)
          den
              .substitute(variable, (b + IntegerNumber.of(s)).simplify())
              .simplify(),
      ];
      final denParts = <Expr>[
        for (var s = 0; s < d; s++)
          den
              .substitute(variable, (a + IntegerNumber.of(s)).simplify())
              .simplify(),
      ];
      return (simplifyMul(numParts) / simplifyMul(denParts)).simplify();
    }
    // Case 2: den(k) == num(k + d) => prod_{k=a..b} g(k) / g(k + d)
    if (num.substitute(variable, kPlusD).expand().simplify() ==
        den.expand().simplify()) {
      final numParts = <Expr>[
        for (var s = 0; s < d; s++)
          num.substitute(
            variable,
            (a + IntegerNumber.of(s)).simplify(),
          ).simplify(),
      ];
      final denParts = <Expr>[
        for (var s = 1; s <= d; s++)
          num.substitute(
            variable,
            (b + IntegerNumber.of(s)).simplify(),
          ).simplify(),
      ];
      return (simplifyMul(numParts) / simplifyMul(denParts)).simplify();
    }
  }
  return null;
}

Expr? infiniteProductClosedForm(
  Expr factor,
  String variable,
  Expr a, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (a is! IntegerNumber) return null;
  final startInt = a.asInt;
  if (startInt == null) return null;

  // 1. Power of variable-dependent base: (u(k))^p -> (prod u(k))^p
  if (factor case Pow(:final base, :final exponent)
      when !exponent.dependsOn(variable)) {
    final baseProd = computeProduct(
      base,
      variable,
      a,
      Constant.infinity,
      assumptions: assumptions,
    );
    if (baseProd is! Product) {
      return Pow(baseProd, exponent).simplify(assumptions: assumptions);
    }
  }

  // 2. Exponential factor: base^exponent -> base^(sum exponent)
  if (factor case Pow(:final base, :final exponent)
      when !base.dependsOn(variable)) {
    final expSum = computeSum(
      exponent,
      variable,
      a,
      Constant.infinity,
      assumptions: assumptions,
    );
    if (expSum is! Sum) {
      return Pow(base, expSum).simplify(assumptions: assumptions);
    }
  }

  // 3. Viète / dyadic cosine product: prod_{k=1..inf} cos(x / 2^k) = sin(x) / x
  if (factor case Cos(expr: final inner) when inner.dependsOn(variable)) {
    final vRes = matchVieteCosineProduct(
      factor,
      inner,
      variable,
      startInt,
      assumptions: assumptions,
    );
    if (vRes != null) return vRes;
  }

  // 4. Rational / quadratic infinite products (Wallis, Euler sinc/sinh/cos/cosh)
  final quadRes = matchQuadraticInfiniteProduct(
    factor,
    variable,
    startInt,
    assumptions: assumptions,
  );
  if (quadRes != null) return quadRes;

  return null;
}

Expr? matchVieteCosineProduct(
  Expr factor,
  Expr inner,
  String variable,
  int startInt, {
  Assumptions assumptions = Assumptions.none,
}) {
  final factors = inner is Mul ? inner.factors : [inner];
  final ratios = <Expr>[];
  final scales = <Expr>[];
  final remaining = <Expr>[];

  for (final f in factors) {
    if (f case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, :final b)) {
        ratios.add(Pow(base, a).simplify());
        if (b != IntegerNumber.zero) {
          scales.add(Pow(base, b).simplify());
        }
        continue;
      }
    }
    remaining.add(f);
  }

  final ratio = simplifyMul(ratios);
  final scale = simplifyMul(scales);
  if (ratio != FractionNumber.half) return null;
  if (remaining.any((f) => f.dependsOn(variable))) return null;
  final xPart = (scale * simplifyMul(remaining)).simplify();
  if (xPart is Number && xPart.isZero) return IntegerNumber.one;

  // At k = 1, inner(1) = xPart / 2, so prod_{k=1..inf} cos(xPart / 2^k) = sin(xPart) / xPart
  final canonProd = (Sin(xPart) / xPart).simplify(assumptions: assumptions);
  return adjustProductStart(
    factor,
    variable,
    startInt,
    1,
    canonProd,
    assumptions: assumptions,
  );
}

Expr? matchQuadraticInfiniteProduct(
  Expr factor,
  String variable,
  int startInt, {
  Assumptions assumptions = Assumptions.none,
}) {
  final together = factor.together();
  final (num, den) = splitNumeratorDenominator(together);
  final numExpanded = num.expand().simplify();
  final denExpanded = den.expand().simplify();

  final numCoeffs = extractPolynomialCoefficients(numExpanded, variable);
  final denCoeffs = extractPolynomialCoefficients(denExpanded, variable);
  if (numCoeffs == null || denCoeffs == null) return null;
  if (maxPolynomialDegree(numCoeffs) != 2 ||
      maxPolynomialDegree(denCoeffs) != 2) {
    return null;
  }

  final n2 = numCoeffs[2] ?? IntegerNumber.zero;
  final n1 = numCoeffs[1] ?? IntegerNumber.zero;
  final n0 = numCoeffs[0] ?? IntegerNumber.zero;

  final d2 = denCoeffs[2] ?? IntegerNumber.zero;
  final d1 = denCoeffs[1] ?? IntegerNumber.zero;
  final d0 = denCoeffs[0] ?? IntegerNumber.zero;

  if (n2 != d2 || n2 == IntegerNumber.zero) return null;

  // Case A: Pure quadratic in k (n1 == 0 && d1 == 0)
  if (n1 == IntegerNumber.zero && d1 == IntegerNumber.zero) {
    if (d0 == IntegerNumber.zero && n0 != IntegerNumber.zero) {
      final zSquared = (-n0 / n2).simplify();
      final canonProd = eulerSineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (canonProd != null) {
        return adjustProductStart(
          factor,
          variable,
          startInt,
          1,
          canonProd,
          assumptions: assumptions,
        );
      }
    }
    if (n0 == IntegerNumber.zero && d0 != IntegerNumber.zero) {
      final zSquared = (-d0 / d2).simplify();
      final invProd = eulerSineProductValue(zSquared, assumptions: assumptions);
      if (invProd != null && invProd != IntegerNumber.zero) {
        final canonProd = (IntegerNumber.one / invProd).simplify(
          assumptions: assumptions,
        );
        return adjustProductStart(
          factor,
          variable,
          startInt,
          1,
          canonProd,
          assumptions: assumptions,
        );
      }
    }
  }

  // Case B: Odd-indexed quadratic (2k - 1)^2 = 4k^2 - 4k + 1 or (2k + 1)^2 = 4k^2 + 4k + 1
  for (final s in const [-1, 1]) {
    final c = (d2 / IntegerNumber.of(4)).simplify();
    if ((IntegerNumber.of(4 * s) * c - d1).expand().simplify() ==
            IntegerNumber.zero &&
        (c - d0).expand().simplify() == IntegerNumber.zero &&
        (n1 - d1).expand().simplify() == IntegerNumber.zero) {
      final zSquared = (-(n0 - d0) / d2).simplify();
      final canonProd = eulerCosineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (canonProd != null) {
        final canonStart = s == -1 ? 1 : 0;
        return adjustProductStart(
          factor,
          variable,
          startInt,
          canonStart,
          canonProd,
          assumptions: assumptions,
        );
      }
    }
    final cNum = (n2 / IntegerNumber.of(4)).simplify();
    if ((IntegerNumber.of(4 * s) * cNum - n1).expand().simplify() ==
            IntegerNumber.zero &&
        (cNum - n0).expand().simplify() == IntegerNumber.zero &&
        (n1 - d1).expand().simplify() == IntegerNumber.zero) {
      final zSquared = (-(d0 - n0) / n2).simplify();
      final invProd = eulerCosineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (invProd != null && invProd != IntegerNumber.zero) {
        final canonProd = (IntegerNumber.one / invProd).simplify(
          assumptions: assumptions,
        );
        final canonStart = s == -1 ? 1 : 0;
        return adjustProductStart(
          factor,
          variable,
          startInt,
          canonStart,
          canonProd,
          assumptions: assumptions,
        );
      }
    }
  }

  return null;
}

Expr? eulerSineProductValue(
  Expr zSquared, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (posZ2, isNeg) = extractSign(zSquared);
  final z = extractProductRoot(posZ2, assumptions: assumptions);
  if (!isNeg && z is IntegerNumber) {
    return null;
  }
  final piZ = (Constant.pi * z).simplify(assumptions: assumptions);
  if (isNeg) {
    return (Sinh(piZ) / piZ).simplify(assumptions: assumptions);
  }
  return (Sin(piZ) / piZ).simplify(assumptions: assumptions);
}

Expr? eulerCosineProductValue(
  Expr zSquared, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (posZ2, isNeg) = extractSign(zSquared);
  final z = extractProductRoot(posZ2, assumptions: assumptions);
  final twoZ = (IntegerNumber.two * z).simplify();
  if (!isNeg && twoZ is IntegerNumber && twoZ.value.isOdd) {
    return null;
  }
  final piZ = (Constant.pi * z).simplify(assumptions: assumptions);
  if (isNeg) {
    return Cosh(piZ).simplify(assumptions: assumptions);
  }
  return Cos(piZ).simplify(assumptions: assumptions);
}

Expr extractProductRoot(
  Expr posZ2, {
  Assumptions assumptions = Assumptions.none,
}) {
  final factors = posZ2 is Mul ? posZ2.factors : [posZ2];
  final rootFactors = <Expr>[];
  for (final f in factors) {
    if (f case Pow(:final base, exponent: IntegerNumber(:final value))
        when value.isEven) {
      final halfExp = value ~/ Integer.two;
      rootFactors.add(
        halfExp == Integer.one
            ? base
            : Pow(
                base,
                IntegerNumber(halfExp),
              ).simplify(assumptions: assumptions),
      );
    } else {
      rootFactors.add(
        Pow(f, FractionNumber.half).simplify(assumptions: assumptions),
      );
    }
  }
  return simplifyMul(rootFactors, assumptions: assumptions);
}

Expr? adjustProductStart(
  Expr factor,
  String variable,
  int startInt,
  int canonStart,
  Expr canonProd, {
  Assumptions assumptions = Assumptions.none,
}) {
  if ((startInt - canonStart).abs() > 64) return null;
  if (startInt == canonStart) return canonProd;

  if (startInt < canonStart) {
    final headFactors = <Expr>[];
    for (var k = startInt; k < canonStart; k++) {
      final val = evalTermAtInt(factor, variable, k, assumptions: assumptions);
      if (val == null) return null;
      headFactors.add(val);
    }
    return simplifyMul([...headFactors, canonProd])
        .simplify(assumptions: assumptions);
  } else {
    final headFactors = <Expr>[];
    for (var k = canonStart; k < startInt; k++) {
      final val = evalTermAtInt(factor, variable, k, assumptions: assumptions);
      if (val == null || (val is Number && val.isZero)) return null;
      headFactors.add(val);
    }
    final headProd = simplifyMul(headFactors);
    return (canonProd / headProd).simplify(assumptions: assumptions);
  }
}

/// Evaluates [expr] at integer coordinate [value] for [variable].
Expr? evalTermAtInt(
  Expr expr,
  String variable,
  int value, {
  Assumptions assumptions = Assumptions.none,
}) {
  try {
    final sub = expr.substitute(variable, IntegerNumber.of(value));
    return sub.simplify(assumptions: assumptions);
  } catch (_) {
    return null;
  }
}
