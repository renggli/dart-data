import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'integration.dart';
import 'integration_elementary.dart' show logAntiderivative;

Expr? tryRepeatedQuadratic(Expr left, Expr quad, int m, String variable) {
  final quadCoeffs = extractPolynomialCoefficients(quad, variable);
  if (quadCoeffs == null || maxPolynomialDegree(quadCoeffs) != 2) return null;
  final a = quadCoeffs[2] ?? IntegerNumber.zero;
  final b = quadCoeffs[1] ?? IntegerNumber.zero;
  final c = quadCoeffs[0] ?? IntegerNumber.zero;

  final rawDegLeft = polynomialDegree(left, variable);
  if (rawDegLeft == null) return null;
  final degLeft = polynomialDegree(left.expand().simplify(), variable);
  if (degLeft == null) return null;
  if (degLeft >= 2) {
    final (:quotient, :remainder) = left.polynomialDivide(quad, variable);
    final qTerm = antiDerivative(
      (quotient / Pow(quad, IntegerNumber.of(m - 1))).simplify(),
      variable,
      assumptions: Assumptions.none,
    );
    if (hasUnevaluatedIntegral(qTerm, variable)) return null;
    if (remainder is Number && remainder.isZero) return qTerm;
    final rTerm = tryRepeatedQuadratic(remainder, quad, m, variable);
    if (rTerm == null) return null;
    return (qTerm + rTerm).simplify();
  }

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 1) return null;
  final d = numCoeffs[1] ?? IntegerNumber.zero;
  final e = numCoeffs[0] ?? IntegerNumber.zero;

  final twoA = (IntegerNumber.two * a).simplify();
  final mMinus1 = IntegerNumber.of(m - 1);
  var result = IntegerNumber.zero as Expr;

  if (d != IntegerNumber.zero) {
    result = (-d / (twoA * mMinus1 * Pow(quad, mMinus1))).simplify();
  }

  final eRem = (e - (d * b) / twoA).simplify();
  if (eRem != IntegerNumber.zero) {
    final constPart = _integrateRepeatedQuadConst(quad, a, b, c, m, variable);
    if (constPart == null) return null;
    result = (result + eRem * constPart).simplify();
  }
  return result;
}

Expr? _integrateRepeatedQuadConst(
  Expr quad,
  Expr a,
  Expr b,
  Expr c,
  int m,
  String variable,
) {
  if (m == 1) {
    final res = antiDerivative(
      IntegerNumber.one / quad,
      variable,
      assumptions: Assumptions.none,
    );
    return hasUnevaluatedIntegral(res, variable) ? null : res;
  }
  final disc = (const IntegerNumber(Integer(4)) * a * c - b * b).simplify();
  if (disc is Number && disc.isZero) return null;

  final prev = _integrateRepeatedQuadConst(quad, a, b, c, m - 1, variable);
  if (prev == null) return null;

  final mMinus1 = IntegerNumber.of(m - 1);
  final twoAxPlusB = (IntegerNumber.two * a * Variable(variable) + b)
      .simplify();
  final denom = (mMinus1 * disc).simplify();
  final term1 = (twoAxPlusB / (denom * Pow(quad, mMinus1))).simplify();
  final coeff2 = ((IntegerNumber.two * IntegerNumber.of(2 * m - 3) * a) / denom)
      .simplify();
  return (term1 + coeff2 * prev).simplify();
}

Expr integrateLinearOverQuad(
  Expr d,
  Expr e,
  Expr quad,
  Expr a,
  Expr b,
  String variable,
) {
  final twoA = (IntegerNumber.two * a).simplify();
  var result = IntegerNumber.zero as Expr;
  if (d != IntegerNumber.zero) {
    result = ((d / twoA) * logAntiderivative(quad, Assumptions.none))
        .simplify();
  }
  final eRem = (e - (d * b) / twoA).simplify();
  if (eRem != IntegerNumber.zero) {
    final constInt = antiDerivative(
      (eRem / quad).simplify(),
      variable,
      assumptions: Assumptions.none,
    );
    result = (result + constInt).simplify();
  }
  return result;
}

Expr? tryCubicBinomialDenominator(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 3) return null;
  if ((denCoeffs[2] != null && denCoeffs[2] != IntegerNumber.zero) ||
      (denCoeffs[1] != null && denCoeffs[1] != IntegerNumber.zero)) {
    return null;
  }
  final a3 = denCoeffs[3] ?? IntegerNumber.zero;
  final c0 = denCoeffs[0] ?? IntegerNumber.zero;
  if (a3 == IntegerNumber.zero || c0 == IntegerNumber.zero) return null;

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 2) return null;
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a3).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a3).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a3).simplify();
  final c = (c0 / a3).simplify();

  final r = (c is RealNumeric && c.isNegative)
      ? (-Pow(
          c.neg(),
          const FractionNumber(Integer.one, Integer(3)),
        )).simplify()
      : Pow(c, const FractionNumber(Integer.one, Integer(3))).simplify();
  final xVar = Variable(variable);
  final linFactor = (xVar + r).simplify();
  final quadFactor = (xVar * xVar - r * xVar + r * r).simplify();

  final aCoeff = ((p2 * r * r - p1 * r + p0) / (IntegerNumber.of(3) * r * r))
      .simplify();
  final bCoeff = (p2 - aCoeff).simplify();
  final cCoeff = (p0 / r - aCoeff * r).simplify();

  final linInt = antiDerivative(
    (aCoeff / linFactor).simplify(),
    variable,
    assumptions: Assumptions.none,
  );
  final quadInt = integrateLinearOverQuad(
    bCoeff,
    cCoeff,
    quadFactor,
    IntegerNumber.one,
    (-r).simplify(),
    variable,
  );
  if (hasUnevaluatedIntegral(linInt, variable) ||
      hasUnevaluatedIntegral(quadInt, variable)) {
    return null;
  }
  return (linInt + quadInt).simplify();
}

Expr? trySophieGermainQuartic(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 4) return null;
  for (var deg = 1; deg <= 3; deg++) {
    if (denCoeffs[deg] != null && denCoeffs[deg] != IntegerNumber.zero) {
      return null;
    }
  }
  final a4 = denCoeffs[4] ?? IntegerNumber.zero;
  final c0 = denCoeffs[0] ?? IntegerNumber.zero;
  if (a4 == IntegerNumber.zero || c0 == IntegerNumber.zero) return null;

  final c = (c0 / a4).simplify();
  if (!isSymbolicPositive(c)) return null;

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 3) return null;
  final p3 = ((numCoeffs[3] ?? IntegerNumber.zero) / a4).simplify();
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a4).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a4).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a4).simplify();

  final r = Pow(c, FractionNumber.half).simplify();
  final s =
      (Pow(IntegerNumber.two, FractionNumber.half) *
              Pow(c, const FractionNumber(Integer.one, Integer(4))))
          .simplify();
  return _integrateSymmetricQuartic(p0, p1, p2, p3, r, s, variable);
}

Expr? tryBiquadraticDenominator(Expr left, Expr right, String variable) {
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (denCoeffs == null || maxPolynomialDegree(denCoeffs) != 4) return null;
  if ((denCoeffs[3] != null && denCoeffs[3] != IntegerNumber.zero) ||
      (denCoeffs[1] != null && denCoeffs[1] != IntegerNumber.zero)) {
    return null;
  }
  final a = denCoeffs[4] ?? IntegerNumber.zero;
  final b = denCoeffs[2] ?? IntegerNumber.zero;
  final c = denCoeffs[0] ?? IntegerNumber.zero;
  if (a == IntegerNumber.zero || c == IntegerNumber.zero) {
    return null;
  }

  final numCoeffs = extractPolynomialCoefficients(left, variable);
  if (numCoeffs == null || maxPolynomialDegree(numCoeffs) > 3) return null;
  final p3 = ((numCoeffs[3] ?? IntegerNumber.zero) / a).simplify();
  final p2 = ((numCoeffs[2] ?? IntegerNumber.zero) / a).simplify();
  final p1 = ((numCoeffs[1] ?? IntegerNumber.zero) / a).simplify();
  final p0 = ((numCoeffs[0] ?? IntegerNumber.zero) / a).simplify();
  final xVar = Variable(variable);

  // Case 1: b^2 - 4ac > 0 -> a*(x^2 + r1)*(x^2 + r2)
  final disc = (b * b - const IntegerNumber(Integer(4)) * a * c)
      .expand()
      .simplify();
  if (disc is Number && disc.isZero) return null;
  if (isSymbolicPositive(disc)) {
    final sqrtDisc = Pow(disc, FractionNumber.half).simplify();
    final r1 = ((b + sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final r2 = ((b - sqrtDisc) / (IntegerNumber.two * a)).simplify();
    final diffR = (r2 - r1).expand().simplify();
    if (diffR is Number && diffR.isZero) return null;
    final q1 = (xVar * xVar + r1).simplify();
    final q2 = (xVar * xVar + r2).simplify();
    final c1Lin = ((p1 - p3 * r1) / diffR).simplify();
    final c1Const = ((p0 - p2 * r1) / diffR).simplify();
    final c2Lin = (-(p1 - p3 * r2) / diffR).simplify();
    final c2Const = (-(p0 - p2 * r2) / diffR).simplify();
    final int1 = integrateLinearOverQuad(
      c1Lin,
      c1Const,
      q1,
      IntegerNumber.one,
      IntegerNumber.zero,
      variable,
    );
    final int2 = integrateLinearOverQuad(
      c2Lin,
      c2Const,
      q2,
      IntegerNumber.one,
      IntegerNumber.zero,
      variable,
    );
    if (!hasUnevaluatedIntegral(int1, variable) &&
        !hasUnevaluatedIntegral(int2, variable)) {
      return (int1 + int2).simplify();
    }
  }

  final cNorm = (c / a).simplify();
  final bNorm = (b / a).simplify();
  if (!isSymbolicPositive(cNorm)) return null;

  final r = Pow(cNorm, FractionNumber.half).simplify();
  final sSq = (IntegerNumber.two * r - bNorm).simplify();
  if (!isSymbolicPositive(sSq)) return null;
  final s = Pow(sSq, FractionNumber.half).simplify();

  return _integrateSymmetricQuartic(p0, p1, p2, p3, r, s, variable);
}

Expr? _integrateSymmetricQuartic(
  Expr p0,
  Expr p1,
  Expr p2,
  Expr p3,
  Expr r,
  Expr s,
  String variable,
) {
  final xVar = Variable(variable);
  final q1 = (xVar * xVar - s * xVar + r).simplify();
  final q2 = (xVar * xVar + s * xVar + r).simplify();

  final diffAlpha = ((p2 - p0 / r) / s).simplify();
  final sumBeta = (p0 / r).simplify();
  final diffBeta = ((p1 - r * p3) / s).simplify();

  final alpha1 = ((p3 + diffAlpha) / IntegerNumber.two).simplify();
  final alpha2 = ((p3 - diffAlpha) / IntegerNumber.two).simplify();
  final beta1 = ((sumBeta + diffBeta) / IntegerNumber.two).simplify();
  final beta2 = ((sumBeta - diffBeta) / IntegerNumber.two).simplify();

  final int1 = integrateLinearOverQuad(
    alpha1,
    beta1,
    q1,
    IntegerNumber.one,
    (-s).simplify(),
    variable,
  );
  final int2 = integrateLinearOverQuad(
    alpha2,
    beta2,
    q2,
    IntegerNumber.one,
    s,
    variable,
  );
  if (hasUnevaluatedIntegral(int1, variable) ||
      hasUnevaluatedIntegral(int2, variable)) {
    return null;
  }
  return (int1 + int2).simplify();
}

Expr? tryDistinctLinearPartialFractions(
  Expr left,
  Expr right,
  String variable,
) {
  if (right is! Mul) return null;
  final linFactors = <({Expr factor, Expr a, Expr b})>[];
  var constScale = IntegerNumber.one as Expr;
  for (final f in right.factors) {
    if (!f.dependsOn(variable)) {
      constScale = (constScale * f).simplify();
      continue;
    }
    if (f.matchLinear(variable) case (:final a, :final b)) {
      linFactors.add((factor: f, a: a, b: b));
    } else {
      return null;
    }
  }
  if (linFactors.length < 2 || linFactors.length > 5) return null;
  final rawDegLeft = polynomialDegree(left, variable);
  if (rawDegLeft == null) return null;
  final degLeft = rawDegLeft < linFactors.length
      ? rawDegLeft
      : polynomialDegree(left.expand().simplify(), variable);
  if (degLeft == null || degLeft >= linFactors.length) return null;

  final terms = <Expr>[];
  for (var i = 0; i < linFactors.length; i++) {
    final fi = linFactors[i];
    final root = (-fi.b / fi.a).simplify();
    final numAtRoot = left.substitute(variable, root).simplify();
    var denAtRoot = constScale * fi.a;
    for (var j = 0; j < linFactors.length; j++) {
      if (i != j) {
        denAtRoot =
            (denAtRoot * linFactors[j].factor.substitute(variable, root))
                .simplify();
      }
    }
    if (denAtRoot is Number && denAtRoot.isZero) return null;
    final coeff = (numAtRoot / denAtRoot).simplify();
    terms.add((coeff * Ln(Abs(fi.factor))).simplify());
  }
  return Add(terms).simplify();
}

Expr? tryPowerSubstitution(
  Expr left,
  Expr right,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  if (depth >= 2) return null;
  final numCoeffs = extractPolynomialCoefficients(left, variable);
  final denCoeffs = extractPolynomialCoefficients(right, variable);
  if (numCoeffs == null ||
      denCoeffs == null ||
      numCoeffs.isEmpty ||
      denCoeffs.isEmpty) {
    return null;
  }

  var n0 = numCoeffs.keys.first;
  for (final e in numCoeffs.keys) {
    if (e < n0) n0 = e;
  }
  var d0 = denCoeffs.keys.first;
  for (final e in denCoeffs.keys) {
    if (e < d0) d0 = e;
  }
  final common = n0 < d0 ? n0 : d0;
  final shiftedNum = {
    for (final MapEntry(:key, :value) in numCoeffs.entries) key - common: value,
  };
  final shiftedDen = {
    for (final MapEntry(:key, :value) in denCoeffs.entries) key - common: value,
  };
  d0 -= common;

  var k = 0;
  for (final e in shiftedDen.keys) {
    final diff = e - d0;
    if (diff > 0) {
      k = k == 0 ? diff : k.gcd(diff);
    }
  }
  if (k < 2) return null;

  for (final e in shiftedNum.keys) {
    final shifted = e + 1 - d0;
    if (shifted < 0) return null;
    if (shifted > 0) k = k.gcd(shifted);
  }
  if (k < 2) return null;

  final uName = '_upow$depth';
  final uVar = Variable(uName);

  var uNum = IntegerNumber.zero as Expr;
  for (final MapEntry(key: e, value: c) in shiftedNum.entries) {
    final q = (e + 1 - d0) ~/ k;
    final uPow = q == 0
        ? IntegerNumber.one
        : (q == 1 ? uVar : Pow(uVar, IntegerNumber.of(q)));
    uNum = uNum + c * uPow;
  }

  var uDen = IntegerNumber.zero as Expr;
  for (final MapEntry(key: e, value: c) in shiftedDen.entries) {
    final q = (e - d0) ~/ k;
    final uPow = q == 0
        ? IntegerNumber.one
        : (q == 1 ? uVar : Pow(uVar, IntegerNumber.of(q)));
    uDen = uDen + c * uPow;
  }

  final transformed = (uNum / (IntegerNumber.of(k) * uVar * uDen)).simplify(
    assumptions: assumptions,
  );
  final uInt = antiDerivative(
    transformed,
    uName,
    depth: depth + 1,
    assumptions: assumptions,
  );
  if (hasUnevaluatedIntegral(uInt, uName)) return null;
  return uInt
      .substitute(uName, Pow(Variable(variable), IntegerNumber.of(k)))
      .simplify(assumptions: assumptions);
}

List<({Expr factor, int mult})>? squareFreeFactorization(
  Expr poly,
  String variable,
) {
  final deg = polynomialDegree(poly, variable);
  if (deg == null || deg < 2) return null;
  final deriv = poly.derivative(variable).simplify();
  final g0 = _polyGcd(poly, deriv, variable);
  if (g0 == null) return null;
  final degG = polynomialDegree(g0, variable);
  if (degG == null || degG == 0) return null;

  var c = poly.polynomialDivide(g0, variable).quotient.simplify();
  var g = g0;
  final result = <({Expr factor, int mult})>[];
  var i = 1;

  while ((polynomialDegree(c, variable) ?? 0) > 0) {
    final y = _polyGcd(c, g, variable);
    if (y == null) return null;
    final z = c.polynomialDivide(y, variable).quotient.simplify();
    final degZ = polynomialDegree(z, variable) ?? 0;
    if (degZ > 0) {
      result.add((factor: _makeMonic(z, variable), mult: i));
    }
    c = y;
    g = g.polynomialDivide(y, variable).quotient.simplify();
    i++;
    if (i > deg + 1) return null;
  }
  return result;
}

Expr _makeMonic(Expr poly, String variable) {
  final coeffs = extractPolynomialCoefficients(poly, variable);
  if (coeffs == null || coeffs.isEmpty) return poly;
  final deg = maxPolynomialDegree(coeffs);
  final lead = coeffs[deg];
  if (lead == null || lead == IntegerNumber.one) return poly;
  return (poly / lead).expand().simplify();
}

Expr? _polyGcd(Expr a, Expr b, String variable) {
  if (isIntegrationBudgetExhausted() ||
      exceedsNodeBudget(a, 250) ||
      exceedsNodeBudget(b, 250)) {
    return null;
  }
  var u = a.expand().simplify();
  var v = b.expand().simplify();
  for (var iter = 0; iter < 20; iter++) {
    if (isIntegrationBudgetExhausted() ||
        exceedsNodeBudget(u, 250) ||
        exceedsNodeBudget(v, 250)) {
      return null;
    }
    final degV = polynomialDegree(v, variable);
    if (degV == null) return null;
    if (v is Number && v.isZero) {
      return _makeMonic(u, variable);
    }
    if (degV == 0) return IntegerNumber.one;
    final rem = u.polynomialDivide(v, variable).remainder.expand().simplify();
    u = v;
    v = rem;
  }
  return null;
}

Expr? tryConjugateRadicalDenominator(
  Expr left,
  Expr t1,
  Expr t2,
  String variable, {
  required int depth,
  required Assumptions assumptions,
}) {
  bool isSqrtTerm(Expr e) {
    final factors = e is Mul ? e.factors : [e];
    return factors.any(
      (f) =>
          f is Pow &&
          (f.exponent == FractionNumber.half ||
              (f.exponent is RealNumber &&
                  (f.exponent as RealNumber).value == 0.5)),
    );
  }

  if (!isSqrtTerm(t1) && !isSqrtTerm(t2)) return null;
  final conjDen = (t1 * t1 - t2 * t2).expand().simplify(
    assumptions: assumptions,
  );
  if (conjDen is Number && conjDen.isZero) return null;
  bool hasFracPow(Expr e) {
    if (e is Pow && e.exponent is FractionNumber) return true;
    var found = false;
    e.mapChildren((c) {
      if (!found && hasFracPow(c)) found = true;
      return c;
    });
    return found;
  }

  if (hasFracPow(conjDen)) return null;
  final rationalized = (left * (t1 - t2) / conjDen).simplify(
    assumptions: assumptions,
  );
  final res = antiDerivative(
    rationalized,
    variable,
    depth: depth + 1,
    assumptions: assumptions,
  );
  return hasUnevaluatedIntegral(res, variable) ? null : res;
}

bool containsComplexSubexpr(Expr expr) => expr.anyNode(
  (node) =>
      node is ComplexNumber ||
      (node is Pow &&
          node.exponent is FractionNumber &&
          (node.exponent as FractionNumber).denominator.isEven &&
          (isSyntacticallyNegative(node.base) ||
              isNegativeConstant(node.base))),
);

bool isPositiveCoeffMonomial(Expr expr) => switch (expr) {
  RealNumeric(:final sign) => sign > 0,
  Variable() => true,
  Pow(:final base) => isPositiveCoeffMonomial(base),
  Mul(:final factors) => factors.every(isPositiveCoeffMonomial),
  _ => false,
};
