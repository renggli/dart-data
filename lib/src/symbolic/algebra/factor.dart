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
  /// factoring $x^2 - 5x + 6$ into $(x - 2)(x - 3)$, or $2x^3 - 8x$ into
  /// $2x(x - 2)(x + 2)$). Formally, this implements univariate polynomial
  /// content extraction, Rational Root Theorem root search with synthetic
  /// division, quadratic discriminant factorization, common monomial grouping,
  /// and multivariate factoring by grouping.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = x * x - const RationalNumber(5) * x + const RationalNumber(6);
  /// print(expr.factor()); // (x - 2) * (x - 3)
  /// ```
  Expr factor() => factorExpr(this);
}

/// Recursively factors [expr] into irreducible products and groups like powers.
Expr factorExpr(Expr expr) {
  // 1. Structural base cases
  if (expr is Number || expr is Variable) return expr;

  // 2. Pure division: factor numerator and denominator recursively and cancel common factors
  if (expr is Div) {
    final num = factorExpr(expr.left);
    final den = factorExpr(expr.right);
    return cancelFactoredFraction(num, den);
  }

  // 3. Pure power: factor base
  if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator > 0) {
      final base = factorExpr(expr.base);
      return distributePower(base, exp.numerator);
    }
  }

  // 4. Pure multiplication: factor components and combine
  if (expr is Mul) {
    final leftFactored = factorExpr(expr.left);
    final rightFactored = factorExpr(expr.right);
    return combineFactoredProducts([leftFactored, rightFactored]);
  }

  // 5. Expand additive sums into canonical polynomial form
  final expanded = expr.expand();
  final vars = expanded.freeVariables;

  // 6. Univariate polynomial factorization over Q[x]
  if (vars.length == 1) {
    final v = vars.first;
    final poly = extractPoly(expanded, v);
    if (poly != null) {
      return factorUnivariatePoly(poly, v);
    }
  }

  // 7. Multivariate / multi-term grouping
  final additiveTerms = <Expr>[];
  collectAdditiveTerms(expanded, 1, additiveTerms);
  if (additiveTerms.length > 1) {
    // 7a. Common monomial GCD extraction
    final commonGcd = extractMonomialGcd(additiveTerms);
    if (commonGcd != null && !isOne(commonGcd)) {
      final cofactorTerms = additiveTerms
          .map((t) => divideMonomial(t, commonGcd))
          .toList();
      var cofactor = cofactorTerms.first;
      for (var i = 1; i < cofactorTerms.length; i++) {
        cofactor = Add(cofactor, cofactorTerms[i]);
      }
      cofactor = cofactor.simplify();
      if (cofactor != expanded) {
        final factoredCofactor = factorExpr(cofactor);
        return combineFactoredProducts([commonGcd, factoredCofactor]);
      }
    }

    // 7b. 4-Term grouping
    if (additiveTerms.length == 4) {
      final grouped = factorByGrouping4(additiveTerms);
      if (grouped != null) return grouped;
    }

    // 7c. Difference of squares: A^2 - B^2
    final diffSq = matchDifferenceOfSquares(additiveTerms);
    if (diffSq != null) {
      final (a, b) = diffSq;
      return combineFactoredProducts([factorExpr(a - b), factorExpr(a + b)]);
    }
  }

  return expanded;
}
