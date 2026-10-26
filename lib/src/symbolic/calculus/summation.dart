import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/simplify/additive.dart';
import '../algebra/simplify/multiplicative.dart';
import '../algebra/simplify/transcendental.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../number/integer.dart';
import 'limit.dart';
import 'linear_form.dart';

/// Closed-form symbolic summation and product extension on [Expr].
extension SummationExtension on Expr {
  /// Computes the definite sum $\sum_{\text{variable}=\text{from}}^{\text{to}} \text{this}$.
  ///
  /// Supports:
  /// - Concrete integer ranges (including empty sums when $\text{to} < \text{from}$).
  /// - Polynomial sums $\sum k^p$ via Faulhaber / Bernoulli polynomial formulas.
  /// - Geometric and polynomial-geometric sums $\sum P(k) r^k$.
  /// - Rational telescoping sums via partial fraction decomposition (`apart`)
  ///   and shift-difference matching (e.g. $\sum \frac{1}{k(k+1)}$).
  /// - Factorial polynomial sums $\sum P(k) k!$ via Gosper antidifferences.
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

  /// Computes the indefinite antidifference $F(k)$ such that
  /// $F(k + 1) - F(k) = \text{this}$, or returns `null` if no closed-form
  /// antidifference is found.
  Expr? indefiniteSum(
    String variable, {
    Assumptions assumptions = Assumptions.none,
  }) => _antidifference(
    simplify(assumptions: assumptions),
    variable,
  )?.simplify(assumptions: assumptions);

  /// Computes the definite product $\prod_{\text{variable}=\text{from}}^{\text{to}} \text{this}$.
  ///
  /// Supports:
  /// - Concrete integer ranges (including empty products when $\text{to} < \text{from}$).
  /// - Constant factors $\prod_{k=a}^b c = c^{b - a + 1}$.
  /// - Factorial and shifted linear factors $\prod_{k=1}^n k = n!$.
  /// - Exponential factors $\prod r^{g(k)} = r^{\sum g(k)}$.
  /// - Telescoping rational products $\prod \frac{g(k+1)}{g(k)} = \frac{g(b+1)}{g(a)}$.
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

/// Evaluates the definite sum $\sum_{k=a}^b \text{term}$.
Expr computeSum(
  Expr term,
  String variable,
  Expr from,
  Expr to, {
  Assumptions assumptions = Assumptions.none,
}) {
  final simplifiedTerm = term.simplify(assumptions: assumptions);
  final a = from.simplify(assumptions: assumptions);
  final b = to.simplify(assumptions: assumptions);

  if (simplifiedTerm is Number && simplifiedTerm.isZero) {
    return IntegerNumber.zero;
  }

  // Normalize infinite series starting at k = a (integer) by shifting to k = 0 or k = 1,
  // or check known closed-form infinite series directly.
  if (b == Constant.infinity) {
    const limitVarName = '__sum_N';
    const limitVar = Variable(limitVarName);
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

    final infClosed = _infiniteSeriesClosedForm(
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
              .simplify(assumptions: assumptions),
        );
      }
      return simplifyAdd(terms).simplify(assumptions: assumptions);
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
    final prod = _closedFormProduct(expr, variable, a, b);
    if (prod != null) {
      return Ln(prod).simplify(assumptions: assumptions);
    }
  }

  // Binomial series: sum_{k=a..b} C(n, k) * x^k * y^(n-k)
  final binomSum = _tryBinomialSum(simplifiedTerm, variable, a, b);
  if (binomSum != null) {
    return binomSum.simplify(assumptions: assumptions);
  }

  return Sum(simplifiedTerm, variable, a, b, isSimplified: true);
}

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
    final mergedAssumptions = assumptions.copyWith(
      domains: {limitVarName: VariableDomain.integer},
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

    final infClosed = _infiniteProductClosedForm(
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

  final closed = _closedFormProduct(simplifiedFactor, variable, a, b);
  if (closed != null) {
    return closed.simplify(assumptions: assumptions);
  }

  return Product(simplifiedFactor, variable, a, b, isSimplified: true);
}

Expr? _antidifference(Expr expr, String variable) {
  if (!expr.dependsOn(variable)) {
    return (expr * Variable(variable)).simplify();
  }

  // Try telescoping rational partial fractions first before expanding
  if (_isRationalIn(expr, variable)) {
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
    return simplifyAdd(antiTerms);
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
    final constPart = simplifyMul(constFactors);
    final varPart = simplifyMul(varFactors);
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
  if (_matchGeometric(term, variable) case (:final ratio, :final scale)
      when ratio != IntegerNumber.one) {
    return (scale * term / (ratio - IntegerNumber.one)).simplify();
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

  return null;
}

/// Computes $F_p(k) = \frac{1}{p+1} \sum_{j=0}^p \binom{p+1}{j} B_j^- k^{p+1-j}$
/// satisfying $F_p(k+1) - F_p(k) = k^p$.
Expr _faulhaberAntidifference(String variable, int p) {
  final kVar = Variable(variable);
  if (p == 0) return kVar;
  final bernoulli = _bernoulliNumbers(p);
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
  return simplifyAdd(terms);
}

List<RationalNumber> _bernoulliNumbers(int maxIndex) {
  final b = <RationalNumber>[IntegerNumber.one];
  for (var m = 1; m <= maxIndex; m++) {
    if (m == 1) {
      b.add(FractionNumber.negativeHalf);
      continue;
    }
    if (m.isOdd) {
      b.add(IntegerNumber.zero);
      continue;
    }
    var sum = IntegerNumber.zero as RationalNumber;
    for (var j = 0; j < m; j++) {
      if (b[j].isZero) continue;
      final binom = IntegerNumber(
        Integer.from(m + 1).binomial(Integer.from(j)),
      );
      sum = sum.addRational(binom.mulRational(b[j]));
    }
    b.add(sum.neg().divRational(IntegerNumber.of(m + 1)));
  }
  return b;
}

({Expr ratio, Expr scale})? _matchGeometric(Expr term, String variable) {
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
  final ratio = simplifyMul(ratios).simplify();
  return (ratio: ratio, scale: IntegerNumber.one);
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
  final expNode = simplifyMul(expFactors);
  final ratio = simplifyMul(ratios).simplify();
  final polyExpr = simplifyMul(otherFactors).expand().simplify();
  final polyCoeffs = extractPolynomialCoefficients(polyExpr, variable);
  if (polyCoeffs == null) return null;
  return (polyCoeffs: polyCoeffs, ratio: ratio, expNode: expNode);
}

/// Solves $r \cdot Q(k + 1) - Q(k) = P(k)$ for the polynomial $Q(k)$ by
/// upper-triangular back-substitution from degree $d$ down to $0$.
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
  final polyExpr = simplifyMul(otherFactors).expand().simplify();
  final polyCoeffs = extractPolynomialCoefficients(polyExpr, variable);
  if (polyCoeffs == null) return null;
  return (polyCoeffs: polyCoeffs, factNode: factNode);
}

/// Solves $(k + 1) Q(k + 1) - Q(k) = P(k)$ for polynomial $Q(k)$ of degree
/// $\deg(P) - 1$. Returns `null` if the constant residual does not vanish.
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

bool _isRationalIn(Expr expr, String variable) {
  final (num, den) = splitNumeratorDenominator(expr);
  if (!den.dependsOn(variable)) return false;
  return polynomialDegree(num.expand().simplify(), variable) != null &&
      polynomialDegree(den.expand().simplify(), variable) != null;
}

/// Checks if a partial-fraction-decomposed rational expression telescopes:
/// $\sum_i \frac{c_i}{(k + \alpha_i)^m}$ where poles differ by integers and
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

  // Group terms by (a, m) and integer shifts of b / a:
  // If b_j / a - b_i / a = d (integer), then a*k + b_j = a*(k + d) + b_i.
  final used = List<bool>.filled(parsedTerms.length, false);
  final antiParts = <Expr>[];
  final kVar = Variable(variable);

  for (var i = 0; i < parsedTerms.length; i++) {
    if (used[i]) continue;
    final ti = parsedTerms[i];
    // Find a partner j with the same (a, m), opposite coeff, and integer shift d = (b_j - b_i) / a
    var matched = false;
    for (var j = i + 1; j < parsedTerms.length; j++) {
      if (used[j]) continue;
      final tj = parsedTerms[j];
      if (ti.m != tj.m || ti.a != tj.a) continue;
      if ((ti.coeff + tj.coeff).simplify() != IntegerNumber.zero) continue;

      final shiftExpr = ((tj.b - ti.b) / ti.a).simplify();
      if (shiftExpr case IntegerNumber(asInt: final d?)
          when d != 0 && d.abs() <= 16) {
        used[i] = true;
        used[j] = true;
        matched = true;
        // If d > 0: ti is c / f(k) and tj is -c / f(k + d).
        // Since Delta(-c * sum_{s=0..d-1} 1 / f(k + s)) = c / f(k) - c / f(k + d):
        final absD = d.abs();
        final baseB = d > 0 ? ti.b : tj.b;
        final c = d > 0 ? ti.coeff : tj.coeff;
        for (var s = 0; s < absD; s++) {
          final shiftedDenBase = (ti.a * (kVar + IntegerNumber.of(s)) + baseB)
              .simplify();
          final shiftedDen = ti.m == 1
              ? shiftedDenBase
              : Pow(shiftedDenBase, IntegerNumber.of(ti.m));
          antiParts.add((-c / shiftedDen).simplify());
        }
        break;
      }
    }
    if (!matched) return null;
  }

  return simplifyAdd(antiParts);
}

/// Detects general telescoping differences $g(k + d) - g(k)$ or $g(k) - g(k + d)$
/// for $1 \le d \le 4$.
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
      return simplifyAdd(parts);
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
      return simplifyAdd(parts);
    }
  }
  return null;
}

Expr? _closedFormProduct(Expr factor, String variable, Expr a, Expr b) {
  final count = (b - a + IntegerNumber.one).simplify();
  if (!factor.dependsOn(variable)) {
    return Pow(factor, count).simplify();
  }

  // Exponential factor: base^exponent where base is independent of variable
  if (factor case Pow(:final base, :final exponent)
      when !base.dependsOn(variable)) {
    final expSum = computeSum(exponent, variable, a, b);
    if (expSum is! VariableFunction || expSum.name != 'sum') {
      return Pow(base, expSum).simplify();
    }
  }

  // Power of variable-dependent base: (u(k))^p -> (prod u(k))^p
  if (factor case Pow(:final base, :final exponent)
      when !exponent.dependsOn(variable)) {
    final baseProd = _closedFormProduct(base, variable, a, b);
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
    final tele = _tryProductTelescoping(num, den, variable, a, b);
    if (tele != null) return tele;
  }

  // Split multiplication into constituent factors
  if (combined case Mul(:final factors) when factors.length > 1) {
    final prodParts = <Expr>[];
    for (final f in factors) {
      final p = _closedFormProduct(f, variable, a, b);
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

List<Expr> _expandPositivePowerFactors(Expr expr) {
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

Expr? _tryProductTelescoping(
  Expr num,
  Expr den,
  String variable,
  Expr a,
  Expr b,
) {
  final single = _trySingleRatioTelescoping(num, den, variable, a, b);
  if (single != null) return single;

  final numFactors = _expandPositivePowerFactors(num);
  final denFactors = _expandPositivePowerFactors(den);
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
      final p = _trySingleRatioTelescoping(nf, varDen[j], variable, a, b);
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

Expr? _trySingleRatioTelescoping(
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

Expr? _tryBinomialSum(Expr term, String variable, Expr a, Expr b) {
  final kVar = Variable(variable);
  final factors = term is Mul ? term.factors : [term];
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
  if (a != IntegerNumber.zero || b != nExpr) return null;

  if (otherFactors.isEmpty) {
    return Pow(IntegerNumber.two, nExpr).simplify();
  }

  // Extract geometric factors x^k * y^(n - k) and constant factors
  final (:constFactors, :varFactors) = partitionFactors(otherFactors, variable);
  final constPart = constFactors.isEmpty
      ? IntegerNumber.one
      : simplifyMul(constFactors);
  if (varFactors.isEmpty) {
    return (constPart * Pow(IntegerNumber.two, nExpr)).simplify();
  }

  var xRatio = IntegerNumber.one as Expr;
  var yRatio = IntegerNumber.one as Expr;
  var extraScale = IntegerNumber.one as Expr;

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
    return null;
  }

  final sumBase = (xRatio + yRatio).simplify();
  if (sumBase is Number && sumBase.isZero) {
    if (nExpr is IntegerNumber && nExpr.value > Integer.zero) {
      return IntegerNumber.zero;
    }
    return null;
  }
  return (constPart * extraScale * Pow(sumBase, nExpr)).simplify();
}

Expr? _infiniteSeriesClosedForm(
  Expr term,
  String variable,
  Expr a, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (a is! IntegerNumber) return null;
  final startInt = a.asInt;
  if (startInt == null) return null;

  // Separate constant factors independent of summation variable
  final rawFactors = term is Mul ? term.factors : [term];
  final (:constFactors, :varFactors) = partitionFactors(rawFactors, variable);
  if (constFactors.isNotEmpty && varFactors.isNotEmpty) {
    final constPart = simplifyMul(constFactors);
    final varPart = simplifyMul(varFactors);
    final inner = _infiniteSeriesClosedForm(
      varPart,
      variable,
      a,
      assumptions: assumptions,
    );
    if (inner != null) {
      if (inner == Constant.infinity || inner == -Constant.infinity) {
        return (constPart * inner).simplify(assumptions: assumptions);
      }
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
  if (_isRationalIn(term, variable)) {
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
  Assumptions assumptions = Assumptions.none,
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
  return simplifyAdd(results).simplify(assumptions: assumptions);
}

/// Evaluates $\sum_{k=\text{startInt}}^\infty f(k)$ given a canonical series
/// value $\sum_{k=\text{canonStart}}^\infty f(k) = \text{canonSum}$ by adding
/// or subtracting finite head terms, provided all head terms are finite and
/// well-defined.
Expr? _adjustSeriesStart(
  Expr term,
  String variable,
  int startInt,
  int canonStart,
  Expr canonSum, {
  Assumptions assumptions = Assumptions.none,
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
    return simplifyAdd([...headTerms, canonSum])
        .simplify(assumptions: assumptions);
  } else {
    // startInt > canonStart: sum_{k=startInt..inf} = canonSum - sum_{k=canonStart..startInt-1}
    final headTerms = <Expr>[];
    for (var k = canonStart; k < startInt; k++) {
      final val = _evalTermAtInt(term, variable, k, assumptions: assumptions);
      if (val == null) return null;
      headTerms.add(val);
    }
    final headSum = simplifyAdd(headTerms);
    return (canonSum - headSum).simplify(assumptions: assumptions);
  }
}

Expr? _evalTermAtInt(
  Expr term,
  String variable,
  int k, {
  Assumptions assumptions = Assumptions.none,
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
  } on Object {
    return null;
  }
}

Expr? _matchInfiniteSeriesFamily(
  Expr term,
  String variable,
  int startInt, {
  Assumptions assumptions = Assumptions.none,
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

  return null;
}

/// Decomposes all exponential factors `base^(a*k + b)` in [factors] into a
/// combined effective ratio $r = \prod \text{base}_i^{a_i}$ and constant
/// multiplier $\text{scale} = \prod \text{base}_i^{b_i}$ such that the product
/// of those factors equals $\text{scale} \cdot r^k$.
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
        ratios.add(Pow(base, a).simplify());
        if (b != IntegerNumber.zero) {
          scales.add(Pow(base, b).simplify());
        }
        continue;
      }
    }
    remaining.add(f);
  }

  return (
    ratio: ratios.isEmpty ? IntegerNumber.one : simplifyMul(ratios).simplify(),
    scale: scales.isEmpty ? IntegerNumber.one : simplifyMul(scales).simplify(),
    remaining: remaining,
  );
}

Expr? _matchFactorialSeries(
  Expr term,
  String variable,
  int startInt, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (num, den) = splitNumeratorDenominator(term);
  final denFactors = den is Mul ? den.factors : [den];

  Factorial? factNode;
  final otherDen = <Expr>[];
  for (final f in denFactors) {
    if (factNode == null && f is Factorial && f.expr.dependsOn(variable)) {
      factNode = f;
    } else {
      otherDen.add(f);
    }
  }
  if (factNode == null) return null;
  if (otherDen.any((f) => f.dependsOn(variable))) return null;

  final linFact = factNode.expr.matchLinear(variable);
  if (linFact == null) return null;
  final mSlope = linFact.a;
  final cShift = linFact.b;
  if (mSlope is! IntegerNumber || cShift is! IntegerNumber) return null;
  final m = mSlope.asInt;
  final c = cShift.asInt;
  if (m == null || c == null || (m != 1 && m != 2)) return null;

  final numFactors = <Expr>[
    ...(num is Mul ? num.factors : [num]),
    for (final d in otherDen) Pow(d, IntegerNumber.negativeOne).simplify(),
  ];

  final (:ratio, :scale, :remaining) = _extractExponentialFactors(
    numFactors,
    variable,
  );

  // Case A: m == 1 => (k + c)! in denominator
  if (m == 1) {
    final polyExpr = remaining.isEmpty
        ? IntegerNumber.one
        : simplifyMul(remaining).expand().simplify();
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
          : Pow(ratio, IntegerNumber.of(j)).simplify();
      bellPolyTerms.add((cj * rPow).simplify());
    }
    final bellFactor = simplifyAdd(bellPolyTerms);
    final shiftScale = c == 0
        ? scale
        : (scale * Pow(ratio, IntegerNumber.of(-c))).simplify();
    final canonSum = (shiftScale * bellFactor * Pow(Constant.e, ratio))
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
        : simplifyMul(remaining);
    final totalScale = (scale * constRem).simplify();

    // Check if ratio = -x^2 (trig) or +x^2 (hyperbolic)
    final (posRatio, isAlternating) = extractSign(ratio);
    final xVal = Pow(posRatio, FractionNumber.half).simplify();

    if (c == 0) {
      // sum_{k=0..inf} ratio^k / (2k)! = cos(sqrt(-ratio)) or cosh(sqrt(ratio))
      final canonVal = isAlternating ? Cos(xVal) : Cosh(xVal);
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
      final canonVal = isAlternating ? (Sin(xVal) / xVal) : (Sinh(xVal) / xVal);
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

/// Converts standard power basis polynomial coefficients $\sum_{i=0}^d p_i k^i$
/// into falling factorial basis coefficients $c_j$ via Stirling numbers of the
/// second kind $S(i, j)$:
/// $$k^i = \sum_{j=0}^i S(i, j) \, k^{\underline{j}}$$
List<Expr>? _toFallingFactorialBasis(Map<int, Expr> polyCoeffs) {
  var maxDeg = 0;
  for (final d in polyCoeffs.keys) {
    if (d < 0 || d > 16) return null;
    if (d > maxDeg) maxDeg = d;
  }

  // Compute Stirling numbers of the second kind S(n, k) up to maxDeg
  final stirling = List<List<Integer>>.generate(
    maxDeg + 1,
    (_) => List<Integer>.filled(maxDeg + 1, Integer.zero),
  );
  stirling[0][0] = Integer.one;
  for (var n = 1; n <= maxDeg; n++) {
    for (var k = 1; k <= n; k++) {
      stirling[n][k] =
          Integer.from(k) * stirling[n - 1][k] + stirling[n - 1][k - 1];
    }
  }

  final c = List<Expr>.filled(maxDeg + 1, IntegerNumber.zero);
  for (final entry in polyCoeffs.entries) {
    final i = entry.key;
    final pi = entry.value;
    for (var j = 0; j <= i; j++) {
      final s = stirling[i][j];
      if (s.isZero) continue;
      c[j] = (c[j] + pi * IntegerNumber(s)).simplify();
    }
  }
  return c;
}

/// Matches infinite series of the form $\frac{c \cdot r^k}{(m k + d)^p}$:
/// - Riemann zeta $\zeta(2s) = \sum_{n=1}^\infty \frac{1}{n^{2s}}$
/// - Odd zeta $\sum_{n=0}^\infty \frac{1}{(2n+1)^{2s}} = (1 - 2^{-2s}) \zeta(2s)$
/// - Dirichlet eta $\eta(2s) = \sum_{n=1}^\infty \frac{(-1)^{n-1}}{n^{2s}} = (1 - 2^{1-2s}) \zeta(2s)$
/// - Dirichlet beta $\beta(2s+1) = \sum_{n=0}^\infty \frac{(-1)^n}{(2n+1)^{2s+1}}$
/// - Mercator / logarithm $\sum_{n=1}^\infty \frac{r^n}{n} = -\ln(1 - r)$ for $-1 \le r < 1$
/// - Polylogarithm $\operatorname{Li}_2(1/2) = \sum_{n=1}^\infty \frac{1}{n^2 2^n} = \frac{\pi^2}{12} - \frac{1}{2}\ln(2)^2$
/// - Gregory / arctan / atanh $\sum_{n=0}^\infty \frac{r^n}{2n+1}$ for $|r| \le 1$
Expr? _matchPowerDenominatorSeries(
  Expr term,
  String variable,
  int startInt, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (num, den) = splitNumeratorDenominator(term);
  if (!den.dependsOn(variable)) return null;

  // Extract exponential factors from numerator and denominator
  final numFactors = num is Mul ? num.factors : [num];
  final denFactors = den is Mul ? den.factors : [den];

  final combinedFactors = <Expr>[
    ...numFactors,
    for (final df in denFactors) Pow(df, IntegerNumber.negativeOne).simplify(),
  ];

  final (:ratio, :scale, :remaining) = _extractExponentialFactors(
    combinedFactors,
    variable,
  );

  // Remaining factors must consist of constants and a single linear power (m*k + d)^(-p)
  final (:constFactors, :varFactors) = partitionFactors(remaining, variable);
  if (varFactors.length != 1) return null;

  final constScale = (scale * simplifyMul(constFactors)).simplify();
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
    signFactor = (signFactor * Pow(denInt, IntegerNumber.of(p))).simplify();
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
        : Pow(ratio, IntegerNumber.of(-d)).simplify();
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
        final zetaVal = _evenZetaValue(p);
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
        final canonSum = (-totalPrefactor * Ln(IntegerNumber.two)).simplify(
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
        final zetaVal = _evenZetaValue(p);
        final twoPow = Pow(
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
    if (_isStrictlyInsideUnitDisk(ratio)) {
      if (p == 1) {
        // sum_{n=1..inf} r^n / n = -ln(1 - r) = ln(1 / (1 - r))
        final oneMinusR = (IntegerNumber.one - ratio).simplify();
        final canonVal = switch (oneMinusR) {
          FractionNumber(:final numerator, :final denominator)
              when numerator < denominator =>
            Ln(RationalNumber.of(denominator, numerator)),
          _ => -Ln(oneMinusR),
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
            (Pow(Constant.pi, IntegerNumber.two) / IntegerNumber.of(12) -
                    FractionNumber.half *
                        Pow(Ln(IntegerNumber.two), IntegerNumber.two))
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
        : Pow(ratio, IntegerNumber.of(-s)).simplify();
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
        final zetaVal = _evenZetaValue(p);
        final twoPow = Pow(IntegerNumber.two, IntegerNumber.of(-p)).simplify();
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
    if (p == 1 && _isStrictlyInsideUnitDisk(ratio)) {
      final (posR, isNegR) = extractSign(ratio);
      final sqrtR = switch (posR) {
        FractionNumber(isOne: _, :final numerator, :final denominator)
            when numerator == Integer.one =>
          Pow(
            IntegerNumber(denominator),
            FractionNumber.negativeHalf,
          ).simplify(),
        _ => Pow(posR, FractionNumber.half).simplify(),
      };
      final invSqrtR = switch (posR) {
        FractionNumber(:final numerator, :final denominator)
            when numerator == Integer.one =>
          Pow(IntegerNumber(denominator), FractionNumber.half).simplify(),
        _ => (IntegerNumber.one / sqrtR).simplify(),
      };
      if (isNegR) {
        // sum_{u=0..inf} (-posR)^u / (2u + 1) = atan(sqrt(posR)) / sqrt(posR)
        final canonVal = (invSqrtR * Atan(sqrtR)).simplify(
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
        final canonVal = (FractionNumber.half * invSqrtR * Ln(logArg)).simplify(
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
      }
    }
  }

  // Case 3: General even m = 2*q and d = 0 (or multiple of m): handled by factoring m^p
  if (d % m == 0) {
    final shift = d ~/ m;
    final mPow = Pow(IntegerNumber.of(m), IntegerNumber.of(p)).simplify();
    final kVar = Variable(variable);
    final reducedTerm =
        (term *
                mPow /
                Pow(mExpr * kVar + dExpr, IntegerNumber.of(-p)) *
                Pow(kVar + IntegerNumber.of(shift), IntegerNumber.of(-p)))
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

bool _isStrictlyInsideUnitDisk(Expr r) {
  if (r is RationalNumber) {
    return !r.isZero && r.numerator.abs() < r.denominator;
  }
  if (r is RealNumber) {
    return r.value != 0.0 && r.value.abs() < 1.0;
  }
  if (r.freeVariables.isEmpty) {
    try {
      final v = r.evaluate();
      return v.isFinite && v != 0.0 && v.abs() < 1.0;
    } on Object {
      return false;
    }
  }
  return false;
}

/// Computes $\zeta(2m) = \frac{|B_{2m}| (2\pi)^{2m}}{2 (2m)!}$ for even $p = 2m \ge 2$.
Expr _evenZetaValue(int p) {
  final bernoulli = _bernoulliNumbers(p);
  final bpAbs = bernoulli[p].abs();
  final twoPowP = Integer.big(BigInt.two.pow(p));
  final factP = Integer.from(p).factorial();
  final coeff = bpAbs.mulRational(
    RationalNumber.of(twoPowP, Integer.two * factP),
  );
  return (coeff * Pow(Constant.pi, IntegerNumber.of(p))).simplify();
}

/// Computes the Dirichlet beta value $\beta(2m + 1) = \sum_{n=0}^\infty \frac{(-1)^n}{(2n+1)^{2m+1}} = \frac{|E_{2m}| \pi^{2m+1}}{2^{2m+2} (2m)!}$
/// using Euler numbers $E_{2m}$.
Expr _oddDirichletBetaValue(int p) {
  final twoM = p - 1;
  final m = twoM ~/ 2;
  final euler = _eulerNumbers(m);
  final emAbs = euler[m].abs();
  final denom =
      Integer.big(BigInt.two.pow(twoM + 2)) * Integer.from(twoM).factorial();
  final coeff = RationalNumber.of(emAbs, denom);
  return (coeff * Pow(Constant.pi, IntegerNumber.of(p))).simplify();
}

/// Computes even-indexed Euler numbers $E_0, E_2, \dots, E_{2m}$ via
/// $\sum_{k=0}^n \binom{2n}{2k} E_{2k} = 0$.
List<Integer> _eulerNumbers(int maxM) {
  final e = <Integer>[Integer.one];
  for (var n = 1; n <= maxM; n++) {
    var sum = Integer.zero;
    for (var k = 0; k < n; k++) {
      final binom = Integer.from(2 * n).binomial(Integer.from(2 * k));
      sum += binom * e[k];
    }
    e.add(-sum);
  }
  return e;
}

Expr? _infiniteProductClosedForm(
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
    final vRes = _matchVieteCosineProduct(
      factor,
      inner,
      variable,
      startInt,
      assumptions: assumptions,
    );
    if (vRes != null) return vRes;
  }

  // 4. Rational / quadratic infinite products (Wallis, Euler sinc/sinh/cos/cosh)
  final quadRes = _matchQuadraticInfiniteProduct(
    factor,
    variable,
    startInt,
    assumptions: assumptions,
  );
  if (quadRes != null) return quadRes;

  return null;
}

Expr? _matchVieteCosineProduct(
  Expr factor,
  Expr inner,
  String variable,
  int startInt, {
  Assumptions assumptions = Assumptions.none,
}) {
  final factors = inner is Mul ? inner.factors : [inner];
  final (:ratio, :scale, :remaining) = _extractExponentialFactors(
    factors,
    variable,
  );
  if (ratio != FractionNumber.half) return null;
  if (remaining.any((f) => f.dependsOn(variable))) return null;
  final xPart = (scale * simplifyMul(remaining)).simplify();
  if (xPart is Number && xPart.isZero) return IntegerNumber.one;

  // At k = 1, inner(1) = xPart / 2, so prod_{k=1..inf} cos(xPart / 2^k) = sin(xPart) / xPart
  final canonProd = (Sin(xPart) / xPart).simplify(assumptions: assumptions);
  return _adjustProductStart(
    factor,
    variable,
    startInt,
    1,
    canonProd,
    assumptions: assumptions,
  );
}

Expr? _matchQuadraticInfiniteProduct(
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

  // Check if num(k) / den(k) is of the form (A * k^2 + B) / (A * k^2) = 1 + B / (A * k^2)
  // or its reciprocal (A * k^2) / (A * k^2 + B) (Wallis product),
  // or shifted odd (2k - 1)^2 or (2k + 1)^2 in denominator (Euler cosine product).

  final n2 = numCoeffs[2] ?? IntegerNumber.zero;
  final n1 = numCoeffs[1] ?? IntegerNumber.zero;
  final n0 = numCoeffs[0] ?? IntegerNumber.zero;

  final d2 = denCoeffs[2] ?? IntegerNumber.zero;
  final d1 = denCoeffs[1] ?? IntegerNumber.zero;
  final d0 = denCoeffs[0] ?? IntegerNumber.zero;

  if (n2 != d2 || n2 == IntegerNumber.zero) return null;

  // Case A: Pure quadratic in k (n1 == 0 && d1 == 0)
  if (n1 == IntegerNumber.zero && d1 == IntegerNumber.zero) {
    // Subcase A1: den = n2 * k^2 (d0 == 0), num = n2 * k^2 + n0 => 1 - (-n0 / n2) / k^2
    if (d0 == IntegerNumber.zero && n0 != IntegerNumber.zero) {
      // Write factor = 1 - z^2 / k^2 where z^2 = -n0 / n2
      final zSquared = (-n0 / n2).simplify();
      final canonProd = _eulerSineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (canonProd != null) {
        return _adjustProductStart(
          factor,
          variable,
          startInt,
          1,
          canonProd,
          assumptions: assumptions,
        );
      }
    }
    // Subcase A2: num = n2 * k^2 (n0 == 0), den = d2 * k^2 + d0 (e.g. Wallis product 4k^2 / (4k^2 - 1))
    if (n0 == IntegerNumber.zero && d0 != IntegerNumber.zero) {
      final zSquared = (-d0 / d2).simplify();
      final invProd = _eulerSineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (invProd != null && invProd != IntegerNumber.zero) {
        final canonProd = (IntegerNumber.one / invProd).simplify(
          assumptions: assumptions,
        );
        return _adjustProductStart(
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
  // Check if denExpanded is c * (2k + s)^2 where s = -1 or s = 1
  for (final s in const [-1, 1]) {
    // (2k + s)^2 = 4k^2 + 4*s*k + 1
    // Ratio d2 / 4 must equal d1 / (4*s) and d0 / 1
    final c = (d2 / IntegerNumber.of(4)).simplify();
    if ((IntegerNumber.of(4 * s) * c - d1).expand().simplify() ==
            IntegerNumber.zero &&
        (c - d0).expand().simplify() == IntegerNumber.zero &&
        (n1 - d1).expand().simplify() == IntegerNumber.zero) {
      // num = c * (2k + s)^2 + (n0 - d0) => factor = 1 - (-(n0 - d0) / c) / (2k + s)^2
      // Recall prod_{m=1..inf} (1 - 4*z^2 / (2m - 1)^2) = cos(pi * z)
      // Here w^2 = -(n0 - d0) / c = 4 * z^2 => z^2 = -(n0 - d0) / (4 * c) = -(n0 - d0) / d2
      final zSquared = (-(n0 - d0) / d2).simplify();
      final canonProd = _eulerCosineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (canonProd != null) {
        final canonStart = s == -1 ? 1 : 0;
        return _adjustProductStart(
          factor,
          variable,
          startInt,
          canonStart,
          canonProd,
          assumptions: assumptions,
        );
      }
    }
    // Reciprocal form: num = c * (2k + s)^2, den = c * (2k + s)^2 + (d0 - n0)
    final cNum = (n2 / IntegerNumber.of(4)).simplify();
    if ((IntegerNumber.of(4 * s) * cNum - n1).expand().simplify() ==
            IntegerNumber.zero &&
        (cNum - n0).expand().simplify() == IntegerNumber.zero &&
        (n1 - d1).expand().simplify() == IntegerNumber.zero) {
      final zSquared = (-(d0 - n0) / n2).simplify();
      final invProd = _eulerCosineProductValue(
        zSquared,
        assumptions: assumptions,
      );
      if (invProd != null && invProd != IntegerNumber.zero) {
        final canonProd = (IntegerNumber.one / invProd).simplify(
          assumptions: assumptions,
        );
        final canonStart = s == -1 ? 1 : 0;
        return _adjustProductStart(
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

/// Evaluates $\prod_{n=1}^\infty \left(1 - \frac{z^2}{n^2}\right) = \frac{\sin(\pi z)}{\pi z}$
/// (or $\frac{\sinh(\pi \sqrt{-z^2})}{\pi \sqrt{-z^2}}$ when $z^2 < 0$).
Expr? _eulerSineProductValue(
  Expr zSquared, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (posZ2, isNeg) = extractSign(zSquared);
  final z = _extractProductRoot(posZ2, assumptions: assumptions);
  if (!isNeg && z is IntegerNumber) {
    return null;
  }
  final piZ = (Constant.pi * z).simplify(assumptions: assumptions);
  if (isNeg) {
    return (Sinh(piZ) / piZ).simplify(assumptions: assumptions);
  }
  return (Sin(piZ) / piZ).simplify(assumptions: assumptions);
}

/// Evaluates $\prod_{n=1}^\infty \left(1 - \frac{4 z^2}{(2n - 1)^2}\right) = \cos(\pi z)$
/// (or $\cosh(\pi \sqrt{-z^2})$ when $z^2 < 0$).
Expr? _eulerCosineProductValue(
  Expr zSquared, {
  Assumptions assumptions = Assumptions.none,
}) {
  final (posZ2, isNeg) = extractSign(zSquared);
  final z = _extractProductRoot(posZ2, assumptions: assumptions);
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

/// Extracts $z$ from $z^2$ by taking square roots of even integer powers
/// directly (since $\frac{\sin(\pi z)}{\pi z}$ and $\cos(\pi z)$ are even
/// functions of $z$).
Expr _extractProductRoot(
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

Expr? _adjustProductStart(
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
      final val = _evalTermAtInt(factor, variable, k, assumptions: assumptions);
      if (val == null) return null;
      headFactors.add(val);
    }
    return simplifyMul([...headFactors, canonProd])
        .simplify(assumptions: assumptions);
  } else {
    final headFactors = <Expr>[];
    for (var k = canonStart; k < startInt; k++) {
      final val = _evalTermAtInt(factor, variable, k, assumptions: assumptions);
      if (val == null || (val is Number && val.isZero)) return null;
      headFactors.add(val);
    }
    final headProd = simplifyMul(headFactors);
    return (canonProd / headProd).simplify(assumptions: assumptions);
  }
}
