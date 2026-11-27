import 'package:more/math.dart';

import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/additive.dart';
import '../algebra/simplify/multiplicative.dart';
import '../algebra/simplify/transcendental.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../functions/fn.dart';
import '../number/combinatorics.dart';
import '../oracle/domain_oracle.dart';
import 'limit.dart';
import 'linear_form.dart';
import 'summation.dart';

Expr? infiniteSeriesClosedForm(
  Expr term,
  String variable,
  Expr a, {
  required Assumptions assumptions,
}) {
  if (a is! IntegerNumber) return null;
  final startInt = a.asInt;
  if (startInt == null) return null;

  // Separate constant factors independent of summation variable
  final rawFactors = term is Mul ? term.factors : [term];
  final (:constFactors, :varFactors) = partitionFactors(rawFactors, variable);
  if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
    final constPart = simplifyMul(constFactors, assumptions: assumptions);
    final varPart = simplifyMul(varFactors, assumptions: assumptions);
    final inner = infiniteSeriesClosedForm(
      varPart,
      variable,
      a,
      assumptions: assumptions,
    );
    if (inner != null) {
      return (constPart * inner).simplify(assumptions: assumptions);
    }
  }

  // Try matching directly on a single canonical series family
  final direct = _matchInfiniteSeriesFamily(
    term,
    variable,
    startInt,
    assumptions: assumptions,
  );
  if (direct != null) return direct;

  // If term is a rational function in variable, try partial fractions (apart)
  // before splitting additive terms so that convergent combinations work.
  if (isRationalIn(term, variable)) {
    final apartExpr = term.apart(variable).simplify(assumptions: assumptions);
    if (apartExpr != term && apartExpr is Add) {
      final apartSum = _tryAdditiveInfiniteSeries(
        apartExpr.terms,
        variable,
        a,
        assumptions: assumptions,
      );
      if (apartSum != null) return apartSum;
    }
  }

  // Linearity across additive terms when every term converges to a finite value
  if (term case Add(:final terms)) {
    final addSum = _tryAdditiveInfiniteSeries(
      terms,
      variable,
      a,
      assumptions: assumptions,
    );
    if (addSum != null) return addSum;
  }

  return null;
}

Expr? _tryAdditiveInfiniteSeries(
  List<Expr> terms,
  String variable,
  Expr a, {
  required Assumptions assumptions,
}) {
  final results = <Expr>[];
  for (final t in terms) {
    final res = computeSum(
      t,
      variable,
      a,
      Constant.infinity,
      assumptions: assumptions,
    );
    if (res is Sum ||
        res == Constant.infinity ||
        res == -Constant.infinity ||
        res == Constant.undefined) {
      return null;
    }
    results.add(res);
  }
  return simplifyAdd(
    results,
    assumptions: assumptions,
  ).simplify(assumptions: assumptions);
}

/// Evaluates `sum_{k=startInt}^oof(k)` given a canonical series
/// value `sum_{k=canonStart}^oof(k) = canonSum` by adding
/// or subtracting finite head terms, provided all head terms are finite and
/// well-defined.
Expr? _adjustSeriesStart(
  Expr term,
  String variable,
  int startInt,
  int canonStart,
  Expr canonSum, {
  required Assumptions assumptions,
}) {
  if ((startInt - canonStart).abs() > 64) return null;
  if (startInt == canonStart) return canonSum;

  if (canonSum == Constant.infinity || canonSum == -Constant.infinity) {
    // Check that no head term between min(startInt, canonStart) and max is undefined
    final lo = startInt < canonStart ? startInt : canonStart;
    final hi = startInt < canonStart ? canonStart - 1 : startInt - 1;
    for (var k = lo; k <= hi; k++) {
      final val = _evalTermAtInt(term, variable, k, assumptions: assumptions);
      if (val == null) return null;
    }
    return canonSum;
  }

  if (startInt < canonStart) {
    // sum_{k=startInt..inf} = sum_{k=startInt..canonStart-1} + canonSum
    final headTerms = <Expr>[];
    for (var k = startInt; k < canonStart; k++) {
      final val = _evalTermAtInt(term, variable, k, assumptions: assumptions);
      if (val == null) return null;
      headTerms.add(val);
    }
    return simplifyAdd([
      ...headTerms,
      canonSum,
    ], assumptions: assumptions).simplify(assumptions: assumptions);
  } else {
    // startInt > canonStart: sum_{k=startInt..inf} = canonSum - sum_{k=canonStart..startInt-1}
    final headTerms = <Expr>[];
    for (var k = canonStart; k < startInt; k++) {
      final val = _evalTermAtInt(term, variable, k, assumptions: assumptions);
      if (val == null) return null;
      headTerms.add(val);
    }
    final headSum = simplifyAdd(headTerms, assumptions: assumptions);
    return (canonSum - headSum).simplify(assumptions: assumptions);
  }
}

Expr? _evalTermAtInt(
  Expr term,
  String variable,
  int k, {
  required Assumptions assumptions,
}) {
  try {
    final v = term
        .substitute(variable, IntegerNumber.of(k))
        .simplify(assumptions: assumptions);
    if (v == Constant.undefined ||
        v == Constant.infinity ||
        v == -Constant.infinity ||
        v.anyNode((n) => n == Constant.undefined || n == Constant.infinity)) {
      return null;
    }
    return v;
  } on UnsupportedError {
    return null;
  } on ArgumentError {
    return null;
  } on StateError {
    return null;
  }
}

Expr? _matchInfiniteSeriesFamily(
  Expr term,
  String variable,
  int startInt, {
  required Assumptions assumptions,
}) {
  // 1. Factorial / Taylor series: P(k) * r^k / (a*k + b)!
  final factRes = _matchFactorialSeries(
    term,
    variable,
    startInt,
    assumptions: assumptions,
  );
  if (factRes != null) return factRes;

  // 2. Zeta, Eta, Beta, Mercator, and Gregory-Leibniz series:
  //    r^(a*k + b) / (m*k + c)^p
  final powerDenRes = _matchPowerDenominatorSeries(
    term,
    variable,
    startInt,
    assumptions: assumptions,
  );
  if (powerDenRes != null) return powerDenRes;

  // 3. Two-pole Digamma infinite sums:
  //    c / ((m1*k + d1) * (m2*k + d2)) or c1/(m1*k + d1) + c2/(m2*k + d2)
  final digammaRes = _matchTwoPoleDigammaSeries(
    term,
    variable,
    startInt,
    assumptions: assumptions,
  );
  if (digammaRes != null) return digammaRes;

  return null;
}

Expr? _matchTwoPoleDigammaSeries(
  Expr term,
  String variable,
  int startInt, {
  required Assumptions assumptions,
}) {
  final startExpr = IntegerNumber.of(startInt);

  bool isValidDigammaArg(Expr arg) {
    if (arg is IntegerNumber) return arg.value > BigInt.zero;
    if (arg is RationalNumber) return !arg.isNegative && !arg.isZero;
    if (arg is RealNumber) return arg.value.isFinite && arg.value > 0.0;
    return true;
  }

  // Form A: c / ((m1*k + d1) * (m2*k + d2))
  final (num, den) = splitNumeratorDenominator(term);
  if (!num.dependsOn(variable)) {
    final denFactors = den is Mul ? den.factors : [den];
    final linPoles = <({Expr m, Expr d})>[];
    final constDen = <Expr>[];
    var valid = true;
    for (final f in denFactors) {
      if (!f.dependsOn(variable)) {
        constDen.add(f);
        continue;
      }
      if (f.matchLinear(variable) case (:final a, :final b)
          when a != IntegerNumber.zero) {
        linPoles.add((m: a, d: b));
      } else {
        valid = false;
        break;
      }
    }
    if (valid && linPoles.length == 2) {
      final p1 = linPoles[0];
      final p2 = linPoles[1];
      final a = (p1.d / p1.m).simplify(assumptions: assumptions);
      final b = (p2.d / p2.m).simplify(assumptions: assumptions);
      final diff = (b - a).simplify(assumptions: assumptions);
      if (diff != IntegerNumber.zero) {
        final argA = (startExpr + a).simplify(assumptions: assumptions);
        final argB = (startExpr + b).simplify(assumptions: assumptions);
        if (isValidDigammaArg(argA) && isValidDigammaArg(argB)) {
          final totalDen = Mul.of([...constDen, p1.m, p2.m, diff])
              .simplify(assumptions: assumptions);
          return ((num / totalDen) * (Fn.digamma(argB) - Fn.digamma(argA)))
              .simplify(assumptions: assumptions);
        }
      }
    }
  }

  // Form B: c1 / (m1*k + d1) + c2 / (m2*k + d2) with c1/m1 + c2/m2 == 0
  if (term case Add(terms: [final t1, final t2])) {
    ({Expr coeff, Expr shift})? parseSinglePole(Expr t) {
      final (tn, td) = splitNumeratorDenominator(t);
      if (tn.dependsOn(variable)) return null;
      final factors = td is Mul ? td.factors : [td];
      Expr? m;
      Expr? d;
      final consts = <Expr>[];
      for (final f in factors) {
        if (!f.dependsOn(variable)) {
          consts.add(f);
        } else if (m == null) {
          if (f.matchLinear(variable) case (:final a, :final b)
              when a != IntegerNumber.zero) {
            m = a;
            d = b;
          } else {
            return null;
          }
        } else {
          return null;
        }
      }
      if (m == null || d == null) return null;
      final denConst = consts.isEmpty
          ? m
          : Mul.of([...consts, m]).simplify(assumptions: assumptions);
      return (
        coeff: (tn / denConst).simplify(assumptions: assumptions),
        shift: (d / m).simplify(assumptions: assumptions),
      );
    }

    final p1 = parseSinglePole(t1);
    final p2 = parseSinglePole(t2);
    if (p1 != null && p2 != null) {
      final sumCoeff = (p1.coeff + p2.coeff).simplify(assumptions: assumptions);
      if (sumCoeff == IntegerNumber.zero && p1.shift != p2.shift) {
        final arg1 = (startExpr + p1.shift).simplify(assumptions: assumptions);
        final arg2 = (startExpr + p2.shift).simplify(assumptions: assumptions);
        if (isValidDigammaArg(arg1) && isValidDigammaArg(arg2)) {
          return (p1.coeff * (Fn.digamma(arg2) - Fn.digamma(arg1))).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }

  return null;
}

/// Decomposes all exponential factors `base^(a*k + b)` in [factors] into a
/// combined effective ratio `r = prodbase_i^{a_i}` and constant
/// multiplier `scale = prodbase_i^{b_i}` such that the product
/// of those factors equals `scale * r^k`.
({Expr ratio, Expr scale, List<Expr> remaining}) _extractExponentialFactors(
  List<Expr> factors,
  String variable,
) {
  final ratios = <Expr>[];
  final scales = <Expr>[];
  final remaining = <Expr>[];

  for (final f in factors) {
    if (f case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, :final b)) {
        ratios.add(Pow.of(base, a).simplify());
        if (b != IntegerNumber.zero) {
          scales.add(Pow.of(base, b).simplify());
        }
        continue;
      }
    }
    remaining.add(f);
  }

  return (
    ratio: ratios.isEmpty
        ? IntegerNumber.one
        : simplifyMul(ratios, assumptions: Assumptions.none).simplify(),
    scale: scales.isEmpty
        ? IntegerNumber.one
        : simplifyMul(scales, assumptions: Assumptions.none).simplify(),
    remaining: remaining,
  );
}

Expr? _matchFactorialSeries(
  Expr term,
  String variable,
  int startInt, {
  required Assumptions assumptions,
}) {
  final (num, den) = splitNumeratorDenominator(term);
  final denFactors = den is Mul ? den.factors : [den];

  Call? factNode;
  final otherDen = <Expr>[];
  for (final f in denFactors) {
    if (factNode == null &&
        f is Call &&
        f.id == FunctionId.factorial &&
        f.args[0].dependsOn(variable)) {
      factNode = f;
    } else {
      otherDen.add(f);
    }
  }
  if (factNode == null) return null;
  if (otherDen.any((f) => f.dependsOn(variable))) return null;

  final linFact = factNode.args[0].matchLinear(variable);
  if (linFact == null) return null;
  final mSlope = linFact.a;
  final cShift = linFact.b;
  if (mSlope is! IntegerNumber || cShift is! IntegerNumber) return null;
  final m = mSlope.asInt;
  final c = cShift.asInt;
  if (m == null || c == null || (m != 1 && m != 2)) return null;

  final numFactors = <Expr>[
    ...(num is Mul ? num.factors : [num]),
    for (final d in otherDen) Pow.of(d, IntegerNumber.negativeOne).simplify(),
  ];

  final (:ratio, :scale, :remaining) = _extractExponentialFactors(
    numFactors,
    variable,
  );

  // Case A: m == 1 => (k + c)! in denominator
  if (m == 1) {
    final polyExpr = remaining.isEmpty
        ? IntegerNumber.one
        : simplifyMul(
            remaining,
            assumptions: Assumptions.none,
          ).expand().simplify();
    final polyCoeffs = extractPolynomialCoefficients(polyExpr, variable);
    if (polyCoeffs == null) return null;

    // Shift index u = k + c so denominator is u! starting at u = 0 (k = -c).
    // In terms of u = k + c (k = u - c):
    // scale * ratio^k * P(k) / (k + c)! = scale * ratio^(-c) * ratio^u * P(u - c) / u!
    final canonStart = -c;
    final uVar = Variable(variable);
    final shiftedPoly = polyExpr
        .substitute(variable, (uVar - IntegerNumber.of(c)).simplify())
        .expand()
        .simplify();
    final uCoeffs = extractPolynomialCoefficients(shiftedPoly, variable);
    if (uCoeffs == null) return null;

    // Convert P(u) = sum_{j=0..d} a_j * u(u-1)...(u-j+1) into falling factorial basis
    final fallingCoeffs = _toFallingFactorialBasis(uCoeffs);
    if (fallingCoeffs == null) return null;

    // sum_{u=0..inf} u^(underline j) * ratio^u / u! = ratio^j * e^ratio
    final bellPolyTerms = <Expr>[];
    for (var j = 0; j < fallingCoeffs.length; j++) {
      final cj = fallingCoeffs[j];
      if (cj is Number && cj.isZero) continue;
      final rPow = j == 0
          ? IntegerNumber.one
          : Pow.of(ratio, IntegerNumber.of(j)).simplify();
      bellPolyTerms.add((cj * rPow).simplify());
    }
    final bellFactor = simplifyAdd(
      bellPolyTerms,
      assumptions: Assumptions.none,
    );
    final shiftScale = c == 0
        ? scale
        : (scale * Pow.of(ratio, IntegerNumber.of(-c))).simplify();
    final canonSum = (shiftScale * bellFactor * Pow.of(Constant.e, ratio))
        .simplify(assumptions: assumptions);

    return _adjustSeriesStart(
      term,
      variable,
      startInt,
      canonStart,
      canonSum,
      assumptions: assumptions,
    );
  }

  // Case B: m == 2 => (2*k)! or (2*k + 1)! in denominator (cos, sin, cosh, sinh)
  if (m == 2 && remaining.every((f) => !f.dependsOn(variable))) {
    final constRem = remaining.isEmpty
        ? IntegerNumber.one
        : simplifyMul(remaining, assumptions: Assumptions.none);
    final totalScale = (scale * constRem).simplify();

    // Check if ratio = -x^2 (trig) or +x^2 (hyperbolic)
    final (posRatio, isAlternating) = extractSign(ratio);
    final xVal = _extractEvenRoot(posRatio);

    if (c == 0) {
      // sum_{k=0..inf} ratio^k / (2k)! = cos(sqrt(-ratio)) or cosh(sqrt(ratio))
      final canonVal = isAlternating ? Fn.cos(xVal) : Fn.cosh(xVal);
      final canonSum = (totalScale * canonVal).simplify(
        assumptions: assumptions,
      );
      return _adjustSeriesStart(
        term,
        variable,
        startInt,
        0,
        canonSum,
        assumptions: assumptions,
      );
    }
    if (c == 1) {
      // sum_{k=0..inf} ratio^k / (2k + 1)! = sin(x) / x or sinh(x) / x
      if (xVal is Number && xVal.isZero) {
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          0,
          totalScale,
          assumptions: assumptions,
        );
      }
      final canonVal = isAlternating
          ? (Fn.sin(xVal) / xVal)
          : (Fn.sinh(xVal) / xVal);
      final canonSum = (totalScale * canonVal).simplify(
        assumptions: assumptions,
      );
      return _adjustSeriesStart(
        term,
        variable,
        startInt,
        0,
        canonSum,
        assumptions: assumptions,
      );
    }
  }

  return null;
}

Expr _extractEvenRoot(Expr expr) {
  if (expr case Pow(:final base, exponent: IntegerNumber(:final value))
      when value.isEven) {
    final halfExp = value ~/ BigInt.two;
    return halfExp == BigInt.one
        ? base
        : Pow.of(base, IntegerNumber(halfExp)).simplify();
  }
  if (expr is Mul) {
    final factors = <Expr>[];
    for (final factor in expr.factors) {
      if (factor case Pow(:final base, exponent: IntegerNumber(:final value))
          when value.isEven) {
        final halfExp = value ~/ BigInt.two;
        factors.add(
          halfExp == BigInt.one
              ? base
              : Pow.of(base, IntegerNumber(halfExp)).simplify(),
        );
      } else if (factor is RationalNumber && factor.sign > 0) {
        final numSqrt = Number.exactIntegerRoot(factor.numerator, 2);
        final denSqrt = Number.exactIntegerRoot(factor.denominator, 2);
        if (numSqrt != null && denSqrt != null) {
          factors.add(RationalNumber.of(numSqrt, denSqrt));
        } else {
          factors.add(Pow.of(factor, FractionNumber.half).simplify());
        }
      } else {
        factors.add(Pow.of(factor, FractionNumber.half).simplify());
      }
    }
    return simplifyMul(factors, assumptions: Assumptions.none);
  }
  if (expr is RationalNumber && expr.sign > 0) {
    final numSqrt = Number.exactIntegerRoot(expr.numerator, 2);
    final denSqrt = Number.exactIntegerRoot(expr.denominator, 2);
    if (numSqrt != null && denSqrt != null) {
      return RationalNumber.of(numSqrt, denSqrt);
    }
  }
  return Pow.of(expr, FractionNumber.half).simplify();
}

/// Converts standard power basis polynomial coefficients `sum_{i=0}^d p_i k^i`
/// into falling factorial basis coefficients `c_j` via Stirling numbers of the
/// second kind `S(i, j)`:
/// `k^i = sum_{j=0}^i S(i, j) k^{underline{j}}`
List<Expr>? _toFallingFactorialBasis(Map<int, Expr> polyCoeffs) {
  var maxDeg = 0;
  for (final d in polyCoeffs.keys) {
    if (d < 0 || d > 16) return null;
    if (d > maxDeg) maxDeg = d;
  }

  final stirling = stirlingSecondKind(maxDeg);

  final c = List<Expr>.filled(maxDeg + 1, IntegerNumber.zero);
  for (final entry in polyCoeffs.entries) {
    final i = entry.key;
    final pi = entry.value;
    for (var j = 0; j <= i; j++) {
      final s = stirling[i][j];
      if (s == BigInt.zero) continue;
      c[j] = (c[j] + pi * IntegerNumber(s)).simplify();
    }
  }
  return c;
}

/// Matches infinite series of the form `(c * r^k)/((m k + d)^p)`:
/// - Riemann zeta `zeta(2s) = sum_{n=1}^oo(1)/(n^2s)`
/// - Odd zeta `sum_{n=0}^oo(1)/((2n+1)^2s) = (1 - 2^-2s) zeta(2s)`
/// - Dirichlet eta `eta(2s) = sum_{n=1}^oo((-1)^n-1)/(n^2s) = (1 - 2^1-2s) zeta(2s)`
/// - Dirichlet beta `beta(2s+1) = sum_{n=0}^oo((-1)^n)/((2n+1)^2s+1)`
/// - Mercator / logarithm `sum_{n=1}^oo (r^n)/n = -ln(1 - r)` for `-1 <= r < 1`
/// - Polylogarithm `Li_2(1/2) = sum_{n=1}^oo 1/(n^2 * 2^n) = pi^2/12 - 1/2 * ln(2)^2`
/// - Gregory / arctan / atanh `sum_{n=0}^oo (r^n)/(2*n + 1)` for `|r| <= 1`
Expr? _matchPowerDenominatorSeries(
  Expr term,
  String variable,
  int startInt, {
  required Assumptions assumptions,
}) {
  final (num, den) = splitNumeratorDenominator(term);
  if (!den.dependsOn(variable)) return null;

  // Extract exponential factors from numerator and denominator
  final numFactors = num is Mul ? num.factors : [num];
  final denFactors = den is Mul ? den.factors : [den];

  final combinedFactors = <Expr>[
    ...numFactors,
    for (final df in denFactors)
      Pow.of(df, IntegerNumber.negativeOne).simplify(),
  ];

  final (:ratio, :scale, :remaining) = _extractExponentialFactors(
    combinedFactors,
    variable,
  );

  // Remaining factors must consist of constants and a single linear power (m*k + d)^(-p)
  final (:constFactors, :varFactors) = partitionFactors(remaining, variable);
  if (varFactors.length != 1) return null;

  final constScale =
      (scale * simplifyMul(constFactors, assumptions: assumptions)).simplify();
  final vf = varFactors.first;

  Expr linBase;
  int p;
  if (vf case Pow(base: final b, exponent: IntegerNumber(asInt: final exp?))
      when exp < 0) {
    linBase = b;
    p = -exp;
  } else {
    return null;
  }

  final lin = linBase.matchLinear(variable);
  if (lin == null) return null;

  // Normalize (a*k + b) so slope m is a positive integer
  var mExpr = lin.a;
  var dExpr = lin.b;
  var signFactor = IntegerNumber.one as Expr;
  if (mExpr is RationalNumber && mExpr.isNegative) {
    mExpr = mExpr.neg();
    dExpr = (-dExpr).simplify();
    if (p.isOdd) {
      signFactor = IntegerNumber.negativeOne;
    }
  }
  if (mExpr is FractionNumber) {
    // Factor out 1 / denominator^p
    final denInt = IntegerNumber(mExpr.denominator);
    mExpr = IntegerNumber(mExpr.numerator);
    dExpr = (dExpr * denInt).simplify();
    signFactor = (signFactor * Pow.of(denInt, IntegerNumber.of(p))).simplify();
  }
  if (mExpr is! IntegerNumber || dExpr is! IntegerNumber) return null;
  final m = mExpr.asInt;
  final d = dExpr.asInt;
  if (m == null || d == null || m <= 0) return null;

  final effectiveScale = (constScale * signFactor).simplify();

  // Case 1: m == 1 => denominator is (k + d)^p
  // Let n = k + d (so k = n - d, and n = 1 corresponds to k = 1 - d).
  if (m == 1) {
    final canonStart = 1 - d;
    final shiftRatioScale = d == 0
        ? IntegerNumber.one
        : Pow.of(ratio, IntegerNumber.of(-d)).simplify();
    final totalPrefactor = (effectiveScale * shiftRatioScale).simplify();

    // 1a. ratio == 1: p-series sum_{n=1..inf} 1 / n^p
    if (ratio == IntegerNumber.one) {
      if (p == 1) {
        // Harmonic series diverges to +infinity
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          (totalPrefactor * Constant.infinity).simplify(),
          assumptions: assumptions,
        );
      }
      if (p >= 2 && p.isEven && p <= 32) {
        final zetaVal = evenZetaValue(p);
        final canonSum = (totalPrefactor * zetaVal).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
      return null;
    }

    // 1b. ratio == -1: Alternating series sum_{n=1..inf} (-1)^n / n^p = -eta(p)
    if (ratio == IntegerNumber.negativeOne) {
      if (p == 1) {
        // sum_{n=1..inf} (-1)^n / n = -ln(2)
        final canonSum = (-totalPrefactor * Fn.ln(IntegerNumber.two)).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
      if (p >= 2 && p.isEven && p <= 32) {
        // sum_{n=1..inf} (-1)^n / n^(2s) = -(1 - 2^(1 - p)) * zeta(p)
        final zetaVal = evenZetaValue(p);
        final twoPow = Pow.of(
          IntegerNumber.two,
          IntegerNumber.of(1 - p),
        ).simplify();
        final etaVal = ((IntegerNumber.one - twoPow) * zetaVal).simplify();
        final canonSum = (-totalPrefactor * etaVal).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
      return null;
    }

    // 1c. Mercator / Polylogarithm Li_p(r): sum_{n=1..inf} r^n / n^p for |r| < 1
    if (_isStrictlyInsideUnitDisk(ratio, assumptions)) {
      if (p == 1) {
        // sum_{n=1..inf} r^n / n = -ln(1 - r) = ln(1 / (1 - r))
        final oneMinusR = (IntegerNumber.one - ratio).simplify();
        final canonVal = switch (oneMinusR) {
          FractionNumber(:final numerator, :final denominator)
              when numerator < denominator =>
            Fn.ln(RationalNumber.of(denominator, numerator)),
          _ => -Fn.ln(oneMinusR),
        };
        final canonSum = (totalPrefactor * canonVal).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
      if (p == 2 && ratio == FractionNumber.half) {
        // Euler's dilogarithm identity: Li_2(1/2) = pi^2 / 12 - ln(2)^2 / 2
        final li2Half =
            (Pow.of(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12) -
                    FractionNumber.half *
                        Pow.of(Fn.ln(IntegerNumber.two), IntegerNumber.two))
                .simplify();
        final canonSum = (totalPrefactor * li2Half).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
    }
    return null;
  }

  // Case 2: m == 2 and d is odd => denominator is (2*k + d)^p
  // Write 2*k + d = 2*(k + s) + 1 where d = 2*s + 1, so s = (d - 1) ~/ 2.
  // Then u = k + s starts at u = 0 when k = -s = (1 - d) ~/ 2.
  if (m == 2 && d.isOdd) {
    final s = (d - 1) ~/ 2;
    final canonStart = -s;
    final shiftRatioScale = s == 0
        ? IntegerNumber.one
        : Pow.of(ratio, IntegerNumber.of(-s)).simplify();
    final totalPrefactor = (effectiveScale * shiftRatioScale).simplify();

    // 2a. ratio == 1: sum_{u=0..inf} 1 / (2u + 1)^p
    if (ratio == IntegerNumber.one) {
      if (p == 1) {
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          (totalPrefactor * Constant.infinity).simplify(),
          assumptions: assumptions,
        );
      }
      if (p >= 2 && p.isEven && p <= 32) {
        // sum_{u=0..inf} 1 / (2u + 1)^(2s) = (1 - 2^(-p)) * zeta(p)
        final zetaVal = evenZetaValue(p);
        final twoPow = Pow.of(
          IntegerNumber.two,
          IntegerNumber.of(-p),
        ).simplify();
        final oddZeta = ((IntegerNumber.one - twoPow) * zetaVal).simplify();
        final canonSum = (totalPrefactor * oddZeta).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
      return null;
    }

    // 2b. ratio == -1: Dirichlet beta function beta(p) = sum_{u=0..inf} (-1)^u / (2u + 1)^p
    if (ratio == IntegerNumber.negativeOne) {
      if (p.isOdd && p >= 1 && p <= 17) {
        final betaVal = _oddDirichletBetaValue(p);
        final canonSum = (totalPrefactor * betaVal).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
      return null;
    }

    // 2c. Gregory / arctan / atanh series: sum_{u=0..inf} r^u / (2u + 1) for |r| < 1
    if (p == 1 && _isStrictlyInsideUnitDisk(ratio, assumptions)) {
      final (posR, isNegR) = extractSign(ratio);
      final sqrtR = switch (posR) {
        FractionNumber(isOne: _, :final numerator, :final denominator)
            when numerator == BigInt.one =>
          Pow.of(
            IntegerNumber(denominator),
            FractionNumber.negativeHalf,
          ).simplify(),
        _ => Pow.of(posR, FractionNumber.half).simplify(),
      };
      final invSqrtR = switch (posR) {
        FractionNumber(:final numerator, :final denominator)
            when numerator == BigInt.one =>
          Pow.of(IntegerNumber(denominator), FractionNumber.half).simplify(),
        _ => (IntegerNumber.one / sqrtR).simplify(),
      };
      if (isNegR) {
        // sum_{u=0..inf} (-posR)^u / (2u + 1) = atan(sqrt(posR)) / sqrt(posR)
        final canonVal = (invSqrtR * Fn.atan(sqrtR)).simplify(
          assumptions: assumptions,
        );
        final canonSum = (totalPrefactor * canonVal).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      } else {
        // sum_{u=0..inf} posR^u / (2u + 1) = (1 / (2 * sqrt(posR))) * ln((1 + sqrt(posR)) / (1 - sqrt(posR)))
        final logArg =
            ((IntegerNumber.one + sqrtR) / (IntegerNumber.one - sqrtR))
                .simplify(assumptions: assumptions);
        final canonVal = (FractionNumber.half * invSqrtR * Fn.ln(logArg))
            .simplify(assumptions: assumptions);
        final canonSum = (totalPrefactor * canonVal).simplify(
          assumptions: assumptions,
        );
        return _adjustSeriesStart(
          term,
          variable,
          startInt,
          canonStart,
          canonSum,
          assumptions: assumptions,
        );
      }
    }
  }

  // Case 3: General even m = 2*q and d = 0 (or multiple of m): handled by factoring m^p
  if (d % m == 0) {
    final shift = d ~/ m;
    final mPow = Pow.of(IntegerNumber.of(m), IntegerNumber.of(p)).simplify();
    final kVar = Variable(variable);
    final reducedTerm =
        (term /
                Pow.of(mExpr * kVar + dExpr, IntegerNumber.of(-p)) *
                Pow.of(kVar + IntegerNumber.of(shift), IntegerNumber.of(-p)))
            .simplify();
    if (reducedTerm != term) {
      final subRes = _matchPowerDenominatorSeries(
        reducedTerm,
        variable,
        startInt,
        assumptions: assumptions,
      );
      if (subRes != null) {
        return (subRes / mPow).simplify(assumptions: assumptions);
      }
    }
  }

  return null;
}

bool _isStrictlyInsideUnitDisk(
  Expr r, [
  Assumptions assumptions = Assumptions.none,
]) {
  if (r is RationalNumber) {
    return !r.isZero && r.numerator.abs() < r.denominator;
  }
  if (r is RealNumber) {
    return r.value != 0.0 && r.value.abs() < 1.0;
  }
  final oracle = DomainOracle(assumptions);
  if (oracle.isNonZero(r) &&
      oracle.isPositive(IntegerNumber.one - r) &&
      oracle.isPositive(IntegerNumber.one + r)) {
    return true;
  }
  if (r.freeVariables.isEmpty) {
    try {
      final v = r.evaluate();
      return v.isFinite && v != 0.0 && v.abs() < 1.0;
    } on UnsupportedError {
      return false;
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }
  }
  return false;
}

/// Computes the Dirichlet beta value `beta(2m + 1) = sum_{n=0}^oo((-1)^n)/((2n+1)^2m+1) = (|E_2m| pi^2m+1)/(2^2m+2 (2m)!)`
/// using Euler numbers `E_2m`.
Expr _oddDirichletBetaValue(int p) {
  final twoM = p - 1;
  final m = twoM ~/ 2;
  final euler = _eulerNumbers(m);
  final emAbs = euler[m].abs();
  final denom = BigInt.two.pow(twoM + 2) * BigInt.from(twoM).factorial();
  final coeff = RationalNumber.of(emAbs, denom);
  return (coeff * Pow.of(Constant.pi, IntegerNumber.of(p))).simplify();
}

/// Computes even-indexed Euler numbers `E_0, E_2, ..., E_2m` via
/// `sum_{k=0}^n binomial(2n, 2k) E_2k = 0`.
List<BigInt> _eulerNumbers(int maxM) {
  final e = <BigInt>[BigInt.one];
  for (var n = 1; n <= maxM; n++) {
    var sum = BigInt.zero;
    for (var k = 0; k < n; k++) {
      final binom = BigInt.from((2 * n).binomial(2 * k));
      sum += binom * e[k];
    }
    e.add(-sum);
  }
  return e;
}

({Expr base, int expSign})? findSymbolicBasePow(
  Expr expr,
  String limitVarName, [
  Assumptions assumptions = Assumptions.none,
]) {
  ({Expr base, int expSign})? found;
  expr.anyNode((node) {
    if (node case Pow(:final base, exponent: final e)
        when e.dependsOn(limitVarName) &&
            base.freeVariables.isNotEmpty &&
            !base.dependsOn(limitVarName)) {
      final sign = asymptoticSignAtInfinity(e, limitVarName, null, assumptions);
      if (sign == 0) return false;
      found = (base: base, expSign: sign);
      return true;
    }
    return false;
  });
  return found;
}

Expr zeroOutBasePow(Expr expr, Expr targetBase, String limitVarName) {
  if (expr case Pow(:final base, exponent: final e)
      when base == targetBase && e.dependsOn(limitVarName)) {
    return IntegerNumber.zero;
  }
  return expr.mapChildren((c) => zeroOutBasePow(c, targetBase, limitVarName));
}
