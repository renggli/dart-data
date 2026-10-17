import '../ast.dart';
import 'expand.dart';
import 'factor/fraction.dart';
import 'factor/multivariate.dart';
import 'factor/univariate.dart';
import 'simplify.dart';

/// Extension providing polynomial factorization and factor grouping on [Expr].
extension FactorExtension on Expr {
  /// Factors this algebraic expression into irreducible products and groups
  /// like powers.
  ///
  /// Conceptually, this reverses polynomial expansion, decomposing polynomial
  /// expressions into products of irreducible factors over $\mathbb{Q}\[x\]$ (such as
  /// factoring $x^2 - 5x + 6$ into $(-3 + x)(-2 + x)$, or $2x^3 - 8x$ into
  /// $2x(-2 + x)(2 + x)$). Formally, this implements univariate polynomial
  /// content extraction, Rational Root Theorem root search with synthetic
  /// division, quadratic discriminant factorization, common monomial grouping,
  /// and multivariate factoring by grouping.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = x * x - const IntegerNumber.from(5) * x + const IntegerNumber.from(6);
  /// print(expr.factor()); // (-3 + x) * (-2 + x)
  /// ```
  Expr factor() => factorExpr(this);
}

/// Recursively factors [expr] into irreducible products and groups like powers.
Expr factorExpr(Expr expr) {
  // 1. Structural base cases
  if (expr is Number || expr is Constant || expr is Variable) return expr;

  // 2. Pure power: factor base
  if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    final intExp = exp.asInt;
    if (intExp != null && intExp > 0) {
      final base = factorExpr(expr.base);
      return distributePower(base, intExp);
    }
    if (intExp != null && intExp < 0) {
      final base = factorExpr(expr.base);
      final den = distributePower(base, -intExp);
      return cancelFactoredFraction(IntegerNumber.one, den);
    }
  }

  // 3. Pure multiplication (including division represented via negative powers)
  if (expr is Mul) {
    final numFactored = <Expr>[];
    final denFactored = <Expr>[];
    for (final factor in expr.factors) {
      if (factor is Pow && factor.exponent is IntegerNumber) {
        final intExp = (factor.exponent as IntegerNumber).asInt;
        if (intExp != null && intExp < 0) {
          final baseFactored = factorExpr(factor.base);
          denFactored.add(distributePower(baseFactored, -intExp));
          continue;
        }
      }
      numFactored.add(factorExpr(factor));
    }
    if (denFactored.isNotEmpty) {
      final num = numFactored.isEmpty
          ? IntegerNumber.one
          : combineFactoredProducts(numFactored);
      final den = combineFactoredProducts(denFactored);
      return cancelFactoredFraction(num, den);
    }
    return combineFactoredProducts(numFactored);
  }

  // 4. Expand additive sums into canonical polynomial form
  final expanded = expr.expand().simplify();
  if (expanded is Number || expanded is Constant || expanded is Variable) {
    return expanded;
  }
  if ((expanded is Mul || expanded is Pow) && expanded != expr) {
    return factorExpr(expanded);
  }
  final vars = expanded.freeVariables;

  // 5. Univariate polynomial factorization over Q[x]
  if (vars.length == 1) {
    final v = vars.first;
    final poly = extractPoly(expanded, v);
    if (poly != null) {
      return factorUnivariatePoly(poly, v);
    }
  }

  // 6. Multivariate / multi-term grouping
  final additiveTerms = <Expr>[];
  collectAdditiveTerms(expanded, 1, additiveTerms);
  if (additiveTerms.length > 1) {
    // 6a. Common monomial GCD extraction
    final commonGcd = extractMonomialGcd(additiveTerms);
    if (commonGcd != null && !isOne(commonGcd)) {
      final cofactor = simplifyAdd([
        for (final t in additiveTerms) divideMonomial(t, commonGcd),
      ]);
      if (cofactor != expanded) {
        final factoredCofactor = factorExpr(cofactor);
        return combineFactoredProducts([commonGcd, factoredCofactor]);
      }
    }

    // 6b. 4-Term grouping
    if (additiveTerms.length == 4) {
      final grouped = factorByGrouping4(additiveTerms);
      if (grouped != null) return grouped;
    }

    // 6c. Difference of squares: A^2 - B^2
    final diffSq = matchDifferenceOfSquares(additiveTerms);
    if (diffSq != null) {
      final (a, b) = diffSq;
      return combineFactoredProducts([
        factorExpr(simplifySub(a, b)),
        factorExpr(simplifyAdd([a, b])),
      ]);
    }

    // 6d. Sum or difference of cubes: A^3 ± B^3
    final cubes = matchSumOrDifferenceOfCubes(additiveTerms);
    if (cubes != null) {
      final (:a, :b, :isDifference) = cubes;
      final a2 = simplifyPow(a, IntegerNumber.two);
      final ab = simplifyMul([a, b]);
      final b2 = simplifyPow(b, IntegerNumber.two);
      final linear = isDifference ? simplifySub(a, b) : simplifyAdd([a, b]);
      final quad = isDifference
          ? simplifyAdd([a2, ab, b2])
          : simplifyAdd([a2, simplifyNeg(ab), b2]);
      return combineFactoredProducts([factorExpr(linear), factorExpr(quad)]);
    }
  }

  return expr.simplify();
}
