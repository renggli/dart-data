import '../assumptions.dart';
import '../ast.dart';
import '../number/integer.dart';
import 'expand.dart';
import 'factor/fraction.dart';
import 'factor/multivariate.dart';
import 'factor/univariate.dart';
import 'simplify.dart';
import 'simplify/additive.dart';
import 'simplify/multiplicative.dart';
import 'simplify/power.dart';

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
  Expr factor({Assumptions assumptions = Assumptions.none}) =>
      factorExpr(this, assumptions: assumptions);
}

/// Recursively factors [expr] into irreducible products and groups like powers.
Expr factorExpr(Expr expr, {Assumptions assumptions = Assumptions.none}) {
  // 1. Structural base cases
  if (expr is IntegerNumber) return _factorInteger(expr.value);
  if (expr is FractionNumber) {
    final numFact = _factorInteger(expr.numerator);
    final denFact = _factorPositiveIntegerFactors(expr.denominator);
    return Mul([
      if (numFact != IntegerNumber.one || denFact.isEmpty) numFact,
      for (final (:prime, :exponent) in denFact)
        Pow(IntegerNumber(prime), IntegerNumber.of(-exponent)),
    ]);
  }
  if (expr is Number || expr is Constant || expr is Variable) return expr;

  // 2. Pure power: factor base
  if (expr case Pow(
    :final base,
    exponent: RationalNumber(asInt: final intExp?),
  )) {
    if (intExp > 0) {
      return distributePower(
        factorExpr(base, assumptions: assumptions),
        intExp,
      );
    }
    if (intExp < 0) {
      final den = distributePower(
        factorExpr(base, assumptions: assumptions),
        -intExp,
      );
      return cancelFactoredFraction(IntegerNumber.one, den);
    }
  }

  // 3. Pure multiplication (including division represented via negative powers)
  if (expr case Mul(:final factors)) {
    final numFactored = <Expr>[];
    final denFactored = <Expr>[];
    for (final factor in factors) {
      if (factor
          case Pow(:final base, exponent: IntegerNumber(asInt: final intExp?))
          when intExp < 0) {
        denFactored.add(
          distributePower(factorExpr(base, assumptions: assumptions), -intExp),
        );
      } else if (factor is Number) {
        numFactored.add(factor);
      } else {
        numFactored.add(factorExpr(factor, assumptions: assumptions));
      }
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
  final expanded = expr.expand().simplify(assumptions: assumptions);
  if (expanded is Number || expanded is Constant || expanded is Variable) {
    return expanded;
  }
  if ((expanded is Mul || expanded is Pow) && expanded != expr) {
    return factorExpr(expanded, assumptions: assumptions);
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
      ], assumptions: assumptions);
      if (cofactor != expanded) {
        final factoredCofactor = factorExpr(cofactor, assumptions: assumptions);
        return combineFactoredProducts([commonGcd, factoredCofactor]);
      }
    }

    // 6b. 4-Term grouping
    if (additiveTerms.length == 4) {
      final grouped = factorByGrouping4(additiveTerms);
      if (grouped != null) return grouped;
    }

    // 6c. Difference of squares: A^2 - B^2
    if (matchDifferenceOfSquares(additiveTerms) case (final a, final b)) {
      return combineFactoredProducts([
        factorExpr(
          simplifySub(a, b, assumptions: assumptions),
          assumptions: assumptions,
        ),
        factorExpr(
          simplifyAdd([a, b], assumptions: assumptions),
          assumptions: assumptions,
        ),
      ]);
    }

    // 6d. Sum or difference of cubes: A^3 ± B^3
    if (matchSumOrDifferenceOfCubes(additiveTerms) case (
      :final a,
      :final b,
      :final isDifference,
    )) {
      final a2 = simplifyPow(a, IntegerNumber.two, assumptions: assumptions);
      final ab = simplifyMul([a, b], assumptions: assumptions);
      final b2 = simplifyPow(b, IntegerNumber.two, assumptions: assumptions);
      final linear = isDifference
          ? simplifySub(a, b, assumptions: assumptions)
          : simplifyAdd([a, b], assumptions: assumptions);
      final quad = isDifference
          ? simplifyAdd([a2, ab, b2], assumptions: assumptions)
          : simplifyAdd([a2, simplifyNeg(ab), b2], assumptions: assumptions);
      return combineFactoredProducts([
        factorExpr(linear, assumptions: assumptions),
        factorExpr(quad, assumptions: assumptions),
      ]);
    }
  }

  return expr.simplify(assumptions: assumptions);
}

Expr _factorInteger(Integer n) {
  if (n.isZero || n.isOne || n == Integer.negativeOne) {
    return IntegerNumber(n);
  }
  final factors = <Expr>[];
  if (n.isNegative) {
    factors.add(IntegerNumber.negativeOne);
  }
  for (final (:prime, :exponent) in _factorPositiveIntegerFactors(n.abs())) {
    final pExpr = IntegerNumber(prime);
    factors.add(exponent == 1 ? pExpr : Pow(pExpr, IntegerNumber.of(exponent)));
  }
  return switch (factors) {
    [final single] => single,
    _ => Mul(factors),
  };
}

List<({Integer prime, int exponent})> _factorPositiveIntegerFactors(Integer n) {
  final result = <({Integer prime, int exponent})>[];
  var rem = n;
  var exp2 = 0;
  while (rem.isEven && !rem.isZero) {
    rem = rem ~/ Integer.two;
    exp2++;
  }
  if (exp2 > 0) {
    result.add((prime: Integer.two, exponent: exp2));
  }
  var exp3 = 0;
  const three = Integer(3);
  while ((rem % three).isZero && !rem.isZero) {
    rem = rem ~/ three;
    exp3++;
  }
  if (exp3 > 0) {
    result.add((prime: three, exponent: exp3));
  }

  var d = const Integer(5);
  var step = Integer.two;
  const six = Integer(6);
  const maxTrial = Integer(1000000);
  while (d * d <= rem && d <= maxTrial) {
    if ((rem % d).isZero) {
      var exp = 0;
      while ((rem % d).isZero) {
        rem = rem ~/ d;
        exp++;
      }
      result.add((prime: d, exponent: exp));
    }
    d = d + step;
    step = six - step;
  }
  if (rem > Integer.one) {
    if (rem.isPrime) {
      result.add((prime: rem, exponent: 1));
    } else {
      final bigFactors = <Integer>[];
      final queue = <Integer>[rem];
      while (queue.isNotEmpty) {
        final curr = queue.removeLast();
        if (curr <= Integer.one) continue;
        if (curr.isPrime) {
          bigFactors.add(curr);
        } else {
          final factor = _pollardsRho(curr);
          if (factor != null && factor > Integer.one && factor < curr) {
            queue.add(factor);
            queue.add(curr ~/ factor);
          } else {
            bigFactors.add(curr);
          }
        }
      }
      bigFactors.sort();
      var idx = 0;
      while (idx < bigFactors.length) {
        final p = bigFactors[idx];
        var count = 0;
        while (idx < bigFactors.length && bigFactors[idx] == p) {
          count++;
          idx++;
        }
        result.add((prime: p, exponent: count));
      }
    }
  }
  return result;
}

Integer? _pollardsRho(Integer n) {
  if (n <= Integer.one) return null;
  if (n.isEven) return Integer.two;
  if (n.isPrime) return n;

  for (var cVal = 1; cVal <= 10; cVal++) {
    final c = Integer.from(cVal);
    var x = Integer.two;
    var y = Integer.two;
    var d = Integer.one;

    Integer f(Integer val) => (val * val + c) % n;

    while (d == Integer.one) {
      x = f(x);
      y = f(f(y));
      d = (x - y).abs().gcd(n);
    }

    if (d > Integer.one && d < n) {
      return d;
    }
  }
  return null;
}
