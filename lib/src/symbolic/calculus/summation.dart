import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/additive.dart';
import '../algebra/simplify/domain.dart';
import '../algebra/simplify/multiplicative.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../number/combinatorics.dart';
import '../number/integer.dart';
import 'limit.dart';
import 'linear_form.dart';
import 'product.dart';
import 'summation_infinite.dart';

/// Closed-form symbolic summation and product extension on [Expr].
extension SummationExtension on Expr {
  /// Computes the definite sum `sum_{variable=from}^to this`.
  ///
  /// Supports:
  /// - Concrete integer ranges (including empty sums when `to < from`).
  /// - Polynomial sums `sumk^p` via Faulhaber / Bernoulli polynomial formulas.
  /// - Geometric and polynomial-geometric sums `sumP(k) r^k`.
  /// - Rational telescoping sums via partial fraction decomposition (`apart`)
  ///   and shift-difference matching (e.g. `sum(1)/(k(k+1))`).
  /// - Factorial polynomial sums `sumP(k) k!` via Gosper antidifferences.
  /// - Infinite convergent series when `to` is [Constant.infinity] or
  ///   [double.infinity].
  ///
  /// Returns an unevaluated [Sum] node when no closed-form sum can be
  /// determined.
  ///
  /// ```dart
  /// final k = Variable('k');
  /// print((k * k).sum('k', 1, Variable('n')).factor());
  /// // 1/6 * n * (1 + n) * (1 + 2 * n)
  /// ```
  Expr sum(
    String variable,
    Object from,
    Object to, {
    Assumptions assumptions = Assumptions.none,
  }) => computeSum(
    this,
    variable,
    Expr.wrap(from),
    Expr.wrap(to),
    assumptions: assumptions,
  );

  /// Computes the indefinite antidifference `F(k)` such that
  /// `F(k + 1) - F(k) = this`, or returns `null` if no closed-form
  /// antidifference is found.
  Expr? indefiniteSum(
    String variable, {
    Assumptions assumptions = Assumptions.none,
  }) => _antidifference(
    simplify(assumptions: assumptions),
    variable,
  )?.simplify(assumptions: assumptions);

  /// Computes the definite product `prod_{variable=from}^to this`.
  ///
  /// Supports:
  /// - Concrete integer ranges (including empty products when `to < from`).
  /// - Constant factors `prod_{k=a}^b c = c^{b - a + 1}`.
  /// - Factorial and shifted linear factors `prod_{k=1}^n k = n!`.
  /// - Exponential factors `prodr^{g(k)} = r^{sumg(k)}`.
  /// - Telescoping rational products `prod(g(k+1))/(g(k)) = (g(b+1))/(g(a))`.
  ///
  /// Returns an unevaluated [Product] node when no closed-form product can be
  /// determined.
  ///
  /// ```dart
  /// final k = Variable('k');
  /// print(k.product('k', 1, Variable('n'))); // n!
  /// ```
  Expr product(
    String variable,
    Object from,
    Object to, {
    Assumptions assumptions = Assumptions.none,
  }) => computeProduct(
    this,
    variable,
    Expr.wrap(from),
    Expr.wrap(to),
    assumptions: assumptions,
  );
}

/// Evaluates the definite sum `sum_{k=a}^b term`.
Expr computeSum(
  Expr term,
  String variable,
  Expr from,
  Expr to, {
  required Assumptions assumptions,
}) {
  final indexAssumptions = assumptions.copyWith(
    domains: {variable: VariableDomain.integer},
  );
  final simplifiedTerm = term.simplify(assumptions: indexAssumptions);
  final a = from.simplify(assumptions: assumptions);
  final b = to.simplify(assumptions: assumptions);

  if (simplifiedTerm is Number && simplifiedTerm.isZero) {
    return IntegerNumber.zero;
  }

  // Normalize infinite series starting at k = a (integer) by shifting to k = 0 or k = 1,
  // or check known closed-form infinite series directly.
  if (b == Constant.infinity) {
    final limitVarName = freshLimitVar('_sum_N', simplifiedTerm, a);
    final limitVar = Variable(limitVarName);
    final mergedAssumptions = assumptions.copyWith(
      domains: {limitVarName: VariableDomain.integer},
    );
    final finite = computeSum(
      simplifiedTerm,
      variable,
      a,
      limitVar,
      assumptions: mergedAssumptions,
    );
    if (finite is! Sum) {
      final symPow = findSymbolicBasePow(finite, limitVarName, assumptions);
      if (symPow != null) {
        try {
          final assumedZero = zeroOutBasePow(finite, symPow.base, limitVarName);
          final closedForm = assumedZero
              .limit(
                limitVarName,
                Constant.infinity,
                assumptions: mergedAssumptions,
              )
              .simplify(assumptions: assumptions);
          if (closedForm is! Limit && closedForm != Constant.undefined) {
            final absBase = Abs(symPow.base, isSimplified: true);
            final domainRel = symPow.expSign > 0
                ? LessThan(absBase, IntegerNumber.one)
                : GreaterThan(absBase, IntegerNumber.one);
            return Piecewise(
              [(relation: domainRel, expr: closedForm)],
              otherwise: Sum(
                simplifiedTerm,
                variable,
                a,
                b,
                isSimplified: true,
              ),
            );
          }
        } on UnsupportedError {
          // Fall through to closed-form infinite series matching.
        }
      } else {
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
          // Fall through to closed-form infinite series matching.
        }
      }
    }

    final infClosed = infiniteSeriesClosedForm(
      simplifiedTerm,
      variable,
      a,
      assumptions: assumptions,
    );
    if (infClosed != null) {
      return infClosed.simplify(assumptions: assumptions);
    }

    return Sum(simplifiedTerm, variable, a, b, isSimplified: true);
  }

  // Concrete integer bounds
  if ((a, b) case (
    IntegerNumber(asInt: final start?),
    IntegerNumber(asInt: final end?),
  )) {
    if (end < start) {
      return IntegerNumber.zero;
    }
    if (end - start <= 256) {
      final terms = <Expr>[];
      for (var k = start; k <= end; k++) {
        terms.add(
          simplifiedTerm
              .substitute(variable, IntegerNumber.of(k))
              .simplify(assumptions: indexAssumptions),
        );
      }
      return simplifyAdd(
        terms,
        assumptions: assumptions,
      ).simplify(assumptions: assumptions);
    }
  }

  // Try closed-form antidifference F(k) where F(k + 1) - F(k) = term(k)
  final anti = _antidifference(simplifiedTerm, variable);
  if (anti != null) {
    final upperVal = anti
        .substitute(variable, (b + IntegerNumber.one).simplify())
        .simplify(assumptions: assumptions);
    final lowerVal = anti
        .substitute(variable, a)
        .simplify(assumptions: assumptions);
    return (upperVal - lowerVal)
        .expand(assumptions: assumptions)
        .simplify(assumptions: assumptions);
  }

  // Sum of logarithms: sum_{k=a..b} ln(u(k)) = ln(prod_{k=a..b} u(k))
  if (simplifiedTerm case Ln(:final expr)) {
    final prod = closedFormProduct(expr, variable, a, b);
    if (prod != null) {
      return Ln(prod).simplify(assumptions: assumptions);
    }
  }

  // Binomial series: sum_{k=a..b} C(n, k) * x^k * y^(n-k)
  final binomSum = _tryBinomialSum(
    simplifiedTerm,
    variable,
    a,
    b,
    assumptions: assumptions,
  );
  if (binomSum != null) {
    return binomSum.simplify(assumptions: assumptions);
  }

  return Sum(simplifiedTerm, variable, a, b, isSimplified: true);
}

/// Computes `zeta(2m) = (|B_2m| (2pi)^2m)/(2 (2m)!)` for even `p = 2m >=2`.
Expr evenZetaValue(int p) {
  final bernoulli = bernoulliNumbers(p);
  final bpAbs = bernoulli[p].abs();
  final twoPowP = Integer.big(BigInt.two.pow(p));
  final factP = Integer.from(p).factorial();
  final coeff = bpAbs.mulRational(
    RationalNumber.of(twoPowP, Integer.two * factP),
  );
  return (coeff * Pow(Constant.pi, IntegerNumber.of(p))).simplify();
}

Expr? _antidifference(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (expr * Variable(variable)).simplify();
  }

  // Try telescoping rational partial fractions first before expanding
  if (isRationalIn(expr, variable)) {
    final apartExpr = expr.apart(variable);
    final tele = _tryRationalTelescoping(apartExpr, variable);
    if (tele != null) return tele;
  }

  // Check direct shift difference g(k + d) - g(k)
  final directTele = _tryGeneralTelescoping(expr, variable);
  if (directTele != null) return directTele;

  if (expr is! Add) {
    final single = _antidifferenceSingleTerm(expr, variable);
    if (single != null) return single;
  }

  // Expand and try term-by-term linearity
  final expanded = expr.expand().simplify();
  if (expanded case Add(:final terms)) {
    final antiTerms = <Expr>[];
    for (final t in terms) {
      final anti = _antidifferenceSingleTerm(t, variable);
      if (anti == null) return null;
      antiTerms.add(anti);
    }
    return simplifyAdd(antiTerms, assumptions: Assumptions.none);
  }

  return _antidifferenceSingleTerm(expanded, variable);
}

Expr? _antidifferenceSingleTerm(Expr term, String variable) {
  if (!term.dependsOn(variable)) {
    return (term * Variable(variable)).simplify();
  }

  // Separate constant factors from variable-dependent factors
  final factors = term is Mul ? term.factors : [term];
  final (:constFactors, :varFactors) = partitionFactors(factors, variable);
  if (constFactors.isNotEmpty) {
    final constPart = simplifyMul(constFactors, assumptions: Assumptions.none);
    final varPart = simplifyMul(varFactors, assumptions: Assumptions.none);
    final innerAnti = _antidifferenceCore(varPart, variable);
    if (innerAnti != null) {
      return (constPart * innerAnti).simplify();
    }
    return null;
  }

  return _antidifferenceCore(term, variable);
}

Expr? _antidifferenceCore(Expr term, String variable) {
  final kVar = Variable(variable);

  // 1. Pure monomial k^p (p >= 0 integer)
  if (term == kVar) {
    return _faulhaberAntidifference(variable, 1);
  }
  if (term case Pow(base: final b, exponent: IntegerNumber(asInt: final p?))
      when b == kVar && p >= 0 && p <= 32) {
    return _faulhaberAntidifference(variable, p);
  }

  // 2. Geometric term r^(a*k + b)
  if (_matchGeometric(term, variable) case final ratio?
      when ratio != IntegerNumber.one) {
    return (term / (ratio - IntegerNumber.one)).simplify();
  }

  // 3. Polynomial * Geometric: P(k) * r^k (Gosper polynomial-geometric)
  if (_matchPolynomialGeometric(term, variable)
      case (:final polyCoeffs, :final ratio, :final expNode)
      when ratio != IntegerNumber.one) {
    final qPoly = _solvePolynomialGeometricGosper(polyCoeffs, ratio, variable);
    if (qPoly != null) {
      return (qPoly * expNode).simplify();
    }
  }

  // 4. Polynomial * Factorial: P(k) * k! (Gosper factorial)
  if (_matchPolynomialFactorial(term, variable) case (
    :final polyCoeffs,
    :final factNode,
  )) {
    final qPoly = _solvePolynomialFactorialGosper(polyCoeffs, variable);
    if (qPoly != null) {
      return (qPoly * factNode).simplify();
    }
  }

  // 5. Upper-index Binomial(k + c, m) where m is independent of k
  if (term case Binomial(:final left, :final right)
      when !right.dependsOn(variable)) {
    if (left.matchLinear(variable) case (:final a, :final b)
        when a == IntegerNumber.one) {
      return Binomial(
        (kVar + b).simplify(),
        (right + IntegerNumber.one).simplify(),
        isSimplified: true,
      );
    }
  }

  return null;
}

/// Computes `F_p(k) = (1)/(p+1) sum_{j=0}^p binomial(p+1, j) B_j^- k^p+1-j`
/// satisfying `F_p(k+1) - F_p(k) = k^p`.
Expr _faulhaberAntidifference(String variable, int p) {
  final kVar = Variable(variable);
  if (p == 0) return kVar;
  final bernoulli = bernoulliNumbers(p);
  final pPlus1 = p + 1;
  final terms = <Expr>[];
  for (var j = 0; j <= p; j++) {
    final bj = bernoulli[j];
    if (bj.isZero) continue;
    final binom = Integer.from(pPlus1).binomial(Integer.from(j));
    final coeff = bj
        .mulRational(IntegerNumber(binom))
        .divRational(IntegerNumber.of(pPlus1));
    final exp = pPlus1 - j;
    final kPow = exp == 1 ? kVar : Pow(kVar, IntegerNumber.of(exp));
    terms.add(coeff.isOne ? kPow : coeff * kPow);
  }
  return simplifyAdd(terms, assumptions: Assumptions.none);
}

Expr? _matchGeometric(Expr term, String variable) {
  final factors = term is Mul ? term.factors : [term];
  final ratios = <Expr>[];
  for (final f in factors) {
    if (f case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, b: _)) {
        ratios.add(Pow(base, a).simplify());
        continue;
      }
    }
    return null;
  }
  if (ratios.isEmpty) return null;
  return simplifyMul(ratios, assumptions: Assumptions.none).simplify();
}

({Map<int, Expr> polyCoeffs, Expr ratio, Expr expNode})?
_matchPolynomialGeometric(Expr term, String variable) {
  final factors = term is Mul ? term.factors : [term];

  final expFactors = <Expr>[];
  final ratios = <Expr>[];
  final otherFactors = <Expr>[];

  for (final f in factors) {
    if (f case Pow(:final base, :final exponent)
        when !base.dependsOn(variable) && exponent.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, b: _)) {
        expFactors.add(f);
        ratios.add(Pow(base, a).simplify());
        continue;
      }
    }
    otherFactors.add(f);
  }

  if (expFactors.isEmpty || otherFactors.isEmpty) return null;
  final expNode = simplifyMul(expFactors, assumptions: Assumptions.none);
  final ratio = simplifyMul(ratios, assumptions: Assumptions.none).simplify();
  final polyExpr = simplifyMul(
    otherFactors,
    assumptions: Assumptions.none,
  ).expand().simplify();
  final polyCoeffs = extractPolynomialCoefficients(polyExpr, variable);
  if (polyCoeffs == null) return null;
  return (polyCoeffs: polyCoeffs, ratio: ratio, expNode: expNode);
}

/// Solves `r * Q(k + 1) - Q(k) = P(k)` for the polynomial `Q(k)` by
/// upper-triangular back-substitution from degree `d` down to `0`.
Expr? _solvePolynomialGeometricGosper(
  Map<int, Expr> pCoeffs,
  Expr r,
  String variable,
) {
  var maxDeg = 0;
  for (final deg in pCoeffs.keys) {
    if (deg < 0 || deg > 16) return null;
    if (deg > maxDeg) maxDeg = deg;
  }
  final rMinus1 = (r - IntegerNumber.one).simplify();
  if (rMinus1 is Number && rMinus1.isZero) return null;

  final qCoeffs = List<Expr>.filled(maxDeg + 1, IntegerNumber.zero);
  for (var i = maxDeg; i >= 0; i--) {
    var rhs = pCoeffs[i] ?? IntegerNumber.zero;
    for (var j = i + 1; j <= maxDeg; j++) {
      final binom = IntegerNumber(Integer.from(j).binomial(Integer.from(i)));
      rhs = (rhs - r * binom * qCoeffs[j]).simplify();
    }
    qCoeffs[i] = (rhs / rMinus1).simplify();
  }

  return buildPolynomialFromCoefficients({
    for (var i = 0; i <= maxDeg; i++) i: qCoeffs[i],
  }, variable);
}

({Map<int, Expr> polyCoeffs, Expr factNode})? _matchPolynomialFactorial(
  Expr term,
  String variable,
) {
  final kVar = Variable(variable);
  final factors = term is Mul ? term.factors : [term];

  Expr? factNode;
  final otherFactors = <Expr>[];
  for (final f in factors) {
    if (factNode == null && f is Factorial && f.expr == kVar) {
      factNode = f;
    } else {
      otherFactors.add(f);
    }
  }
  if (factNode == null || otherFactors.isEmpty) return null;
  final polyExpr = simplifyMul(
    otherFactors,
    assumptions: Assumptions.none,
  ).expand().simplify();
  final polyCoeffs = extractPolynomialCoefficients(polyExpr, variable);
  if (polyCoeffs == null) return null;
  return (polyCoeffs: polyCoeffs, factNode: factNode);
}

/// Solves `(k + 1) Q(k + 1) - Q(k) = P(k)` for polynomial `Q(k)` of degree
/// `deg(P) - 1`. Returns `null` if the constant residual does not vanish.
Expr? _solvePolynomialFactorialGosper(Map<int, Expr> pCoeffs, String variable) {
  var maxDeg = 0;
  for (final deg in pCoeffs.keys) {
    if (deg < 0 || deg > 12) return null;
    if (deg > maxDeg) maxDeg = deg;
  }
  if (maxDeg == 0) return null;

  final qDeg = maxDeg - 1;
  final qCoeffs = List<Expr>.filled(qDeg + 1, IntegerNumber.zero);

  // Build (k + 1) * Q(k + 1) - Q(k) from highest degree maxDeg down to 1:
  // At degree m (1 <= m <= maxDeg), the leading unknown is qCoeffs[m - 1] with coefficient 1.
  for (var m = maxDeg; m >= 1; m--) {
    var rhs = pCoeffs[m] ?? IntegerNumber.zero;
    // Subtract contributions from already-determined qCoeffs[j] for j >= m:
    // In (k + 1) * sum_{j} q_j (k + 1)^j - sum_j q_j k^j = sum_j q_j ((k + 1)^(j + 1) - k^j)
    for (var j = m; j <= qDeg; j++) {
      // Coefficient of k^m in (k + 1)^(j + 1) - k^j:
      final binom = IntegerNumber(
        Integer.from(j + 1).binomial(Integer.from(m)),
      );
      final subCoeff = j == m ? (binom - IntegerNumber.one).simplify() : binom;
      rhs = (rhs - subCoeff * qCoeffs[j]).simplify();
    }
    qCoeffs[m - 1] = rhs;
  }

  // Verify degree-0 consistency: sum_{j=0..qDeg} q_j * 1 - q_0 == pCoeffs[0]
  var deg0Lhs = IntegerNumber.zero as Expr;
  for (var j = 1; j <= qDeg; j++) {
    deg0Lhs = (deg0Lhs + qCoeffs[j]).simplify();
  }
  final deg0Rhs = pCoeffs[0] ?? IntegerNumber.zero;
  if ((deg0Lhs - deg0Rhs).expand().simplify() != IntegerNumber.zero) {
    return null;
  }

  return buildPolynomialFromCoefficients({
    for (var i = 0; i <= qDeg; i++) i: qCoeffs[i],
  }, variable);
}

bool isRationalIn(Expr expr, String variable) {
  final (num, den) = splitNumeratorDenominator(expr);
  if (!den.dependsOn(variable)) return false;
  return polynomialDegree(num.expand().simplify(), variable) != null &&
      polynomialDegree(den.expand().simplify(), variable) != null;
}

/// Checks if a partial-fraction-decomposed rational expression telescopes:
/// `sum_i (c_i)/((k + alpha_i)^m)` where poles differ by integers and
/// residues sum to zero in each shift class.
Expr? _tryRationalTelescoping(Expr apartExpr, String variable) {
  final rawTerms = <Expr>[];
  MonomialAccumulator.collectTerms(apartExpr, rawTerms);
  if (rawTerms.length < 2) return null;

  // Each term must be c / (a*k + b)^m
  final parsedTerms = <({Expr coeff, Expr a, Expr b, int m})>[];
  for (final t in rawTerms) {
    final (num, den) = splitNumeratorDenominator(t);
    if (num.dependsOn(variable) || !den.dependsOn(variable)) return null;
    var base = den;
    var m = 1;
    if (den
        case Pow(base: final inner, exponent: IntegerNumber(asInt: final exp?))
        when exp >= 1) {
      base = inner;
      m = exp;
    }
    final lin = base.matchLinear(variable);
    if (lin == null) return null;
    parsedTerms.add((coeff: num, a: lin.a, b: lin.b, m: m));
  }

  // Group terms by (a, m) and integer shifts of b / a where sum of coeffs == 0.
  final used = List<bool>.filled(parsedTerms.length, false);
  final antiParts = <Expr>[];
  final kVar = Variable(variable);

  for (var i = 0; i < parsedTerms.length; i++) {
    if (used[i]) continue;
    final ti = parsedTerms[i];
    final groupIndices = <int>[i];
    final shifts = <int>[0];
    for (var j = i + 1; j < parsedTerms.length; j++) {
      if (used[j]) continue;
      final tj = parsedTerms[j];
      if (ti.m != tj.m || ti.a != tj.a) continue;
      final shiftExpr = ((tj.b - ti.b) / ti.a).simplify();
      if (shiftExpr case IntegerNumber(asInt: final d?)
          when d != 0 && d.abs() <= 16) {
        groupIndices.add(j);
        shifts.add(d);
      }
    }
    if (groupIndices.length < 2) return null;
    final totalCoeff = Add([
      for (final idx in groupIndices) parsedTerms[idx].coeff,
    ]).simplify();
    if (totalCoeff != IntegerNumber.zero) return null;

    var minShift = 0;
    var maxShift = 0;
    for (final s in shifts) {
      if (s < minShift) minShift = s;
      if (s > maxShift) maxShift = s;
    }
    final span = maxShift - minShift;
    if (span == 0 || span > 16) return null;

    final coeffByShift = <int, Expr>{};
    for (var idx = 0; idx < groupIndices.length; idx++) {
      used[groupIndices[idx]] = true;
      final rel = shifts[idx] - minShift;
      final cur = coeffByShift[rel];
      final c = parsedTerms[groupIndices[idx]].coeff;
      coeffByShift[rel] = cur == null ? c : (cur + c).simplify();
    }

    final minTjB = (ti.b + IntegerNumber.of(minShift) * ti.a).simplify();
    Expr prefixSum = IntegerNumber.zero;
    for (var s = 0; s < span; s++) {
      final cs = coeffByShift[s];
      if (cs != null) {
        prefixSum = (prefixSum + cs).simplify();
      }
      if (prefixSum != IntegerNumber.zero) {
        final shiftedDenBase = (ti.a * (kVar + IntegerNumber.of(s)) + minTjB)
            .simplify();
        final shiftedDen = ti.m == 1
            ? shiftedDenBase
            : Pow(shiftedDenBase, IntegerNumber.of(ti.m));
        antiParts.add((-prefixSum / shiftedDen).simplify());
      }
    }
  }

  return simplifyAdd(antiParts, assumptions: Assumptions.none);
}

/// Detects general telescoping differences `g(k + d) - g(k)` or `g(k) - g(k + d)`
/// for `1 <=d <=4`.
Expr? _tryGeneralTelescoping(Expr expr, String variable) {
  if (expr is! Add || expr.terms.length != 2) return null;
  final t0 = expr.terms[0];
  final t1 = expr.terms[1];
  final kVar = Variable(variable);

  for (var d = 1; d <= 4; d++) {
    final kPlusD = (kVar + IntegerNumber.of(d)).simplify();
    // Case 1: t0(k) == -t1(k + d) => expr = t1(k + d) - (-t0(k)) = g(k + d) - g(k) with g = -t0
    final negT0 = (-t0).simplify();
    if (negT0.substitute(variable, kPlusD).simplify() == t1.simplify()) {
      final parts = <Expr>[
        for (var s = 0; s < d; s++)
          negT0
              .substitute(variable, (kVar + IntegerNumber.of(s)).simplify())
              .simplify(),
      ];
      return simplifyAdd(parts, assumptions: Assumptions.none);
    }
    // Case 2: t1(k) == -t0(k + d) => expr = t0(k + d) - (-t1(k)) = g(k + d) - g(k) with g = -t1
    final negT1 = (-t1).simplify();
    if (negT1.substitute(variable, kPlusD).simplify() == t0.simplify()) {
      final parts = <Expr>[
        for (var s = 0; s < d; s++)
          negT1
              .substitute(variable, (kVar + IntegerNumber.of(s)).simplify())
              .simplify(),
      ];
      return simplifyAdd(parts, assumptions: Assumptions.none);
    }
  }
  return null;
}

Expr? _tryBinomialSum(
  Expr term,
  String variable,
  Expr a,
  Expr b, {
  required Assumptions assumptions,
}) {
  final kVar = Variable(variable);
  final factors = term is Mul ? term.factors : [term];

  Expr adjustLowerBound(Expr fullSum) => a == IntegerNumber.zero
      ? fullSum
      : (fullSum -
                term
                    .substitute(variable, IntegerNumber.zero)
                    .simplify(assumptions: assumptions))
            .simplify(assumptions: assumptions);

  // Check for squared binomial sum: C(n, k)^2 or Vandermonde: C(m, k) * C(n, r - k)
  if (a == IntegerNumber.zero || a == IntegerNumber.one) {
    final (:constFactors, :varFactors) = partitionFactors(factors, variable);
    final constPart = constFactors.isEmpty
        ? IntegerNumber.one
        : simplifyMul(constFactors, assumptions: assumptions);

    if (varFactors
        case [
          Pow(
            base: Binomial(left: final nExpr, right: final kExpr),
            exponent: IntegerNumber(asInt: 2),
          ),
        ]
        when !nExpr.dependsOn(variable) && kExpr == kVar && b == nExpr) {
      final fullSum =
          (constPart *
                  Binomial(
                    (IntegerNumber.two * nExpr).simplify(
                      assumptions: assumptions,
                    ),
                    nExpr,
                  ))
              .simplify(assumptions: assumptions);
      return adjustLowerBound(fullSum);
    }

    if (varFactors case [final Binomial b1, final Binomial b2]) {
      final (Binomial? kBinom, Binomial? rBinom) = switch ((b1, b2)) {
        (Binomial(left: final m, right: final k), final other)
            when !m.dependsOn(variable) && k == kVar =>
          (b1, other),
        (final other, Binomial(left: final m, right: final k))
            when !m.dependsOn(variable) && k == kVar =>
          (b2, other),
        _ => (null, null),
      };
      if (kBinom != null &&
          rBinom != null &&
          !rBinom.left.dependsOn(variable)) {
        final lin = rBinom.right.matchLinear(variable);
        if (lin != null && lin.a == IntegerNumber.negativeOne && lin.b == b) {
          final fullSum =
              (constPart *
                      Binomial(
                        (kBinom.left + rBinom.left).simplify(
                          assumptions: assumptions,
                        ),
                        b,
                      ))
                  .simplify(assumptions: assumptions);
          return adjustLowerBound(fullSum);
        }
      }
    }
  }

  Binomial? binomNode;
  final otherFactors = <Expr>[];

  for (final f in factors) {
    if (binomNode == null &&
        f is Binomial &&
        !f.left.dependsOn(variable) &&
        f.right == kVar) {
      binomNode = f;
    } else {
      otherFactors.add(f);
    }
  }

  if (binomNode == null) return null;
  final nExpr = binomNode.left;
  if ((a != IntegerNumber.zero && a != IntegerNumber.one) || b != nExpr) {
    return null;
  }

  if (otherFactors.isEmpty) {
    return adjustLowerBound(Pow(IntegerNumber.two, nExpr).simplify());
  }

  // Extract geometric factors x^k * y^(n - k), polynomial factors P(k), and constant factors
  final (:constFactors, :varFactors) = partitionFactors(otherFactors, variable);
  final constPart = constFactors.isEmpty
      ? IntegerNumber.one
      : simplifyMul(constFactors, assumptions: Assumptions.none);
  if (varFactors.isEmpty) {
    return adjustLowerBound(
      (constPart * Pow(IntegerNumber.two, nExpr)).simplify(),
    );
  }

  var xRatio = IntegerNumber.one as Expr;
  var yRatio = IntegerNumber.one as Expr;
  var extraScale = IntegerNumber.one as Expr;
  final polyFactors = <Expr>[];

  for (final vf in varFactors) {
    if (vf case Pow(:final base, :final exponent)
        when !base.dependsOn(variable)) {
      final lin = exponent.matchLinear(variable);
      if (lin == null) return null;
      if (lin.a == IntegerNumber.one) {
        xRatio = (xRatio * base).simplify();
        if (lin.b != IntegerNumber.zero) {
          extraScale = (extraScale * Pow(base, lin.b)).simplify();
        }
        continue;
      }
      if (lin.a == IntegerNumber.negativeOne) {
        yRatio = (yRatio * base).simplify();
        final remShift = (lin.b - nExpr).simplify();
        if (remShift != IntegerNumber.zero) {
          extraScale = (extraScale * Pow(base, remShift)).simplify();
        }
        continue;
      }
      xRatio = (xRatio * Pow(base, lin.a)).simplify();
      if (lin.b != IntegerNumber.zero) {
        extraScale = (extraScale * Pow(base, lin.b)).simplify();
      }
      continue;
    }
    polyFactors.add(vf);
  }

  final sumBase = (xRatio + yRatio).simplify();
  if (polyFactors.isEmpty) {
    if (sumBase is Number && sumBase.isZero) {
      if (isPositiveExpr(nExpr, assumptions: assumptions)) {
        return adjustLowerBound(IntegerNumber.zero);
      }
      return null;
    }
    return adjustLowerBound(
      (constPart * extraScale * Pow(sumBase, nExpr)).simplify(),
    );
  }

  final polyExpr = polyFactors.length == 1
      ? polyFactors.first
      : simplifyMul(polyFactors, assumptions: Assumptions.none);
  final coeffs = extractPolynomialCoefficients(polyExpr, variable);
  if (coeffs == null) return null;

  var maxDeg = 0;
  for (final d in coeffs.keys) {
    if (d > maxDeg) maxDeg = d;
  }
  if (maxDeg > 4) return null;

  if (sumBase is Number && sumBase.isZero) {
    final diff = (nExpr - IntegerNumber.of(maxDeg)).simplify(
      assumptions: assumptions,
    );
    if (isPositiveExpr(diff, assumptions: assumptions)) {
      return adjustLowerBound(IntegerNumber.zero);
    }
    return null;
  }

  final stirling2 = stirlingSecondKind(maxDeg);

  // Express P(k) = sum_{j=0}^maxDeg s_j * k^{falling j}
  final sCoeffs = List<Expr>.filled(maxDeg + 1, IntegerNumber.zero);
  for (var j = 0; j <= maxDeg; j++) {
    Expr sj = IntegerNumber.zero;
    for (var i = j; i <= maxDeg; i++) {
      final ci = coeffs[i];
      if (ci != null) {
        final s = stirling2[i][j];
        if (!s.isZero) {
          sj = (sj + IntegerNumber(s) * ci).simplify();
        }
      }
    }
    sCoeffs[j] = sj;
  }

  // Sum_{k=0}^n k^{falling j} C(n,k) x^k y^{n-k} = n^{falling j} x^j (x+y)^{n-j}
  Expr polyFactorSum = IntegerNumber.zero;
  Expr fallingN = IntegerNumber.one;
  Expr xPow = IntegerNumber.one;
  for (var j = 0; j <= maxDeg; j++) {
    if (j > 0) {
      fallingN = (fallingN * (nExpr - IntegerNumber.of(j - 1))).simplify();
      xPow = (xPow * xRatio).simplify();
    }
    final sj = sCoeffs[j];
    if (sj is Number && sj.isZero) continue;
    final basePow = Pow(sumBase, IntegerNumber.of(maxDeg - j)).simplify();
    polyFactorSum = (polyFactorSum + sj * fallingN * xPow * basePow).simplify();
  }

  final expandedPoly = polyFactorSum.expand().simplify();
  final tailPow = Pow(sumBase, (nExpr - IntegerNumber.of(maxDeg)).simplify());
  return adjustLowerBound(
    (constPart * extraScale * expandedPoly * tailPow).simplify(),
  );
}
