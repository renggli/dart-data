import '../algebra/expand.dart';
import '../algebra/factor.dart';
import '../algebra/rational.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../assumptions.dart';
import '../ast.dart';
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
  /// Returns an unevaluated `VariableFunction('sum', ...)` node when no
  /// closed-form sum can be determined.
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
    _wrapBound(from),
    _wrapBound(to),
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
  /// Returns an unevaluated `VariableFunction('product', ...)` node when no
  /// closed-form product can be determined.
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
    _wrapBound(from),
    _wrapBound(to),
    assumptions: assumptions,
  );
}

Expr _wrapBound(Object bound) => switch (bound) {
  final Expr e => e,
  final int n => IntegerNumber.of(n),
  final BigInt b => IntegerNumber(Integer.big(b)),
  final double d => RealNumber.fromDouble(d),
  final String s => Variable(s),
  _ => throw ArgumentError('Unsupported bound type: ${bound.runtimeType}'),
};

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

  // Handle infinite upper bound via limit of finite sum
  if (b == Constant.infinity) {
    const limitVarName = '__sum_N';
    const limitVar = Variable(limitVarName);
    final finite = computeSum(
      simplifiedTerm,
      variable,
      a,
      limitVar,
      assumptions: assumptions,
    );
    if (finite is VariableFunction && finite.name == 'sum') {
      return VariableFunction('sum', [
        simplifiedTerm,
        Variable(variable),
        a,
        b,
      ], isSimplified: true);
    }
    return finite.limit(
      limitVarName,
      Constant.infinity,
      assumptions: assumptions,
    );
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

  return VariableFunction('sum', [
    simplifiedTerm,
    Variable(variable),
    a,
    b,
  ], isSimplified: true);
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

  return VariableFunction('product', [
    simplifiedFactor,
    Variable(variable),
    a,
    b,
  ], isSimplified: true);
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
  final constFactors = <Expr>[];
  final varFactors = <Expr>[];
  for (final f in factors) {
    if (f.dependsOn(variable)) {
      varFactors.add(f);
    } else {
      constFactors.add(f);
    }
  }
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
    final binom = Integer(pPlus1).binomial(Integer(j));
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
      final binom = IntegerNumber(Integer(m + 1).binomial(Integer(j)));
      sum = sum.addRational(binom.mulRational(b[j]));
    }
    b.add(sum.neg().divRational(IntegerNumber.of(m + 1)));
  }
  return b;
}

({Expr ratio, Expr scale})? _matchGeometric(Expr term, String variable) {
  if (term case Pow(:final base, :final exponent)
      when !base.dependsOn(variable) && exponent.dependsOn(variable)) {
    if (exponent.matchLinear(variable) case (:final a, b: _)) {
      final ratio = Pow(base, a).simplify();
      return (ratio: ratio, scale: IntegerNumber.one);
    }
  }
  return null;
}

({Map<int, Expr> polyCoeffs, Expr ratio, Expr expNode})?
_matchPolynomialGeometric(Expr term, String variable) {
  final factors = term is Mul ? term.factors : [term];

  Expr? expNode;
  Expr? ratio;
  final otherFactors = <Expr>[];

  for (final f in factors) {
    if (expNode == null && _matchGeometric(f, variable) != null) {
      final m = _matchGeometric(f, variable)!;
      expNode = f;
      ratio = m.ratio;
    } else {
      otherFactors.add(f);
    }
  }

  if (expNode == null || ratio == null || otherFactors.isEmpty) return null;
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
      final binom = IntegerNumber(Integer(j).binomial(Integer(i)));
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
      final binom = IntegerNumber(Integer(j + 1).binomial(Integer(m)));
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
    if (slope == IntegerNumber.one) {
      final lowerShifted = (a + shift).simplify();
      final upperShifted = (b + shift).simplify();
      if (lowerShifted == IntegerNumber.one) {
        return Factorial(upperShifted).simplify();
      }
      if (lowerShifted case IntegerNumber(asInt: final l?) when l > 1) {
        return (Factorial(upperShifted) / Factorial(IntegerNumber.of(l - 1)))
            .simplify();
      }
      return (Gamma((upperShifted + IntegerNumber.one).simplify()) /
              Gamma(lowerShifted))
          .simplify();
    }
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
