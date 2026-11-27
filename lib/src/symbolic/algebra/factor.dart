import 'package:more/math.dart';

import '../assumptions.dart';
import '../ast.dart';
import '../number/combinatorics.dart';
import '../poly/bridge.dart';
import '../poly/factor.dart';
import 'expand.dart';
import 'factor/fraction.dart';
import 'factor/multivariate.dart';
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
  /// expressions into products of irreducible factors over `Q[x]` (such as
  /// factoring `x^2 - 5x + 6` into `(-3 + x)(-2 + x)`, or `2x^3 - 8x` into
  /// `2x(-2 + x)(2 + x)`). Formally, this implements univariate polynomial
  /// content extraction, Rational Root Theorem root search with synthetic
  /// division, quadratic discriminant factorization, common monomial grouping,
  /// and multivariate factoring by grouping.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final expr = x * x - const IntegerNumber.of(5) * x + const IntegerNumber.of(6);
  /// print(expr.factor()); // (-3 + x) * (-2 + x)
  /// ```
  Expr factor({Assumptions assumptions = Assumptions.none}) =>
      factorExpr(this, assumptions: assumptions);
}

/// Recursively factors [expr] into irreducible products and groups like powers.
Expr factorExpr(Expr expr, {required Assumptions assumptions}) {
  // 1. Structural base cases
  if (expr is RationalNumber) return _factorRational(expr);
  if (expr is Number || expr is Constant || expr is Variable) return expr;

  // 2. Pure power: factor base
  if (expr case Pow(
    :final base,
    exponent: RationalNumber(asInt: final intExp?),
  )) {
    if (intExp > 0) {
      final res = distributePower(
        factorExpr(base, assumptions: assumptions),
        intExp,
      );
      return res is RationalNumber ? _factorRational(res) : res;
    }
    if (intExp < 0) {
      final den = distributePower(
        factorExpr(base, assumptions: assumptions),
        -intExp,
      );
      final res = cancelFactoredFraction(IntegerNumber.one, den);
      return res is RationalNumber ? _factorRational(res) : res;
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
    final combined = denFactored.isNotEmpty
        ? cancelFactoredFraction(
            numFactored.isEmpty
                ? IntegerNumber.one
                : combineFactoredProducts(numFactored),
            combineFactoredProducts(denFactored),
          )
        : combineFactoredProducts(numFactored);
    return combined is RationalNumber ? _factorRational(combined) : combined;
  }

  // 4. Univariate fast path when already polynomial (avoids redundant expand/simplify)
  final inputVars = expr.freeVariables;
  if (inputVars.length == 1 && assumptions.isEmpty) {
    final v = inputVars.first;
    final poly = exprToPolyQ(expr, v);
    if (poly != null) {
      return factorPolyQToExpr(poly, v);
    }
  }

  // 5. Expand additive sums into canonical polynomial form
  final rawExpanded = expr.expand(assumptions: assumptions);
  final expanded = assumptions.isEmpty
      ? rawExpanded
      : rawExpanded.simplify(assumptions: assumptions);
  if (expanded is RationalNumber) {
    return _factorRational(expanded);
  }
  if (expanded is Number || expanded is Constant || expanded is Variable) {
    return expanded;
  }
  if ((expanded is Mul || expanded is Pow) && expanded != expr) {
    return factorExpr(expanded, assumptions: assumptions);
  }
  final vars = expanded.freeVariables;

  // 6. Univariate polynomial factorization over Q[x]
  if (vars.length == 1) {
    final v = vars.first;
    final poly = exprToPolyQ(expanded, v, expanded: true);
    if (poly != null) {
      return factorPolyQToExpr(poly, v);
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
      final grouped = factorByGrouping4(
        additiveTerms,
        assumptions: assumptions,
      );
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
          : simplifyAdd([
              a2,
              simplifyNeg(ab, assumptions: assumptions),
              b2,
            ], assumptions: assumptions);
      return combineFactoredProducts([
        factorExpr(linear, assumptions: assumptions),
        factorExpr(quad, assumptions: assumptions),
      ]);
    }

    // 6e. General multivariate quadratic, linear content, or homogeneous factorization
    if (vars.length >= 2) {
      final multi = factorMultivariatePolynomial(
        expanded,
        vars.toList(),
        assumptions: assumptions,
      );
      if (multi != null) return multi;
    }
  }

  return expr.simplify(assumptions: assumptions);
}

Expr _factorRational(RationalNumber expr) {
  if (expr is IntegerNumber) return _factorInteger(expr.value);
  if (expr is FractionNumber) {
    final numFactors = <Expr>[];
    if (expr.numerator != BigInt.one) {
      final numFact = _factorInteger(expr.numerator);
      if (numFact case Mul(:final factors)) {
        numFactors.addAll(factors);
      } else {
        numFactors.add(numFact);
      }
    }
    final denFact = _factorPositiveIntegerFactors(expr.denominator);
    final all = <Expr>[
      ...numFactors,
      for (final (:prime, :exponent) in denFact)
        if (exponent == 1)
          Pow.raw(IntegerNumber(prime), IntegerNumber.negativeOne)
        else
          Pow.raw(IntegerNumber(prime), IntegerNumber.of(-exponent)),
    ];
    return all.length == 1 ? all.first : Mul.raw(all);
  }
  return expr;
}

Expr _factorInteger(BigInt n) {
  if (n == BigInt.zero ||
      n == BigInt.one ||
      n == -BigInt.one ||
      n.bitLength > 96) {
    return IntegerNumber(n);
  }
  final factors = <Expr>[];
  if (n.isNegative) {
    factors.add(IntegerNumber.negativeOne);
  }
  for (final (:prime, :exponent) in _factorPositiveIntegerFactors(n.abs())) {
    final pExpr = IntegerNumber(prime);
    factors.add(
      exponent == 1 ? pExpr : Pow.raw(pExpr, IntegerNumber.of(exponent)),
    );
  }
  return switch (factors) {
    [final single] => single,
    _ => Mul.raw(factors),
  };
}

/// Recursively collects all irreducible base factors of [expr] into [target],
/// expanding positive integer powers.
void collectFactors(Expr expr, List<Expr> target) {
  switch (expr) {
    case Mul(:final factors):
      for (final f in factors) {
        collectFactors(f, target);
      }
    case Pow(:final base, exponent: IntegerNumber(asInt: final n))
        when n != null && n > 0:
      for (var i = 0; i < n; i++) {
        collectFactors(base, target);
      }
    case _:
      target.add(expr);
  }
}

List<({BigInt prime, int exponent})> _factorPositiveIntegerFactors(BigInt n) {
  final result = <({BigInt prime, int exponent})>[];
  var rem = n;
  var exp2 = 0;
  while (rem.isEven && rem != BigInt.zero) {
    rem = rem ~/ BigInt.two;
    exp2++;
  }
  if (exp2 > 0) {
    result.add((prime: BigInt.two, exponent: exp2));
  }
  var exp3 = 0;
  final three = BigInt.from(3);
  while (rem % three == BigInt.zero && rem != BigInt.zero) {
    rem = rem ~/ three;
    exp3++;
  }
  if (exp3 > 0) {
    result.add((prime: three, exponent: exp3));
  }

  var d = BigInt.from(5);
  var step = BigInt.two;
  final six = BigInt.from(6);
  final maxTrial = BigInt.from(1000000);
  while (d * d <= rem && d <= maxTrial) {
    if (rem % d == BigInt.zero) {
      var exp = 0;
      while (rem % d == BigInt.zero) {
        rem = rem ~/ d;
        exp++;
      }
      result.add((prime: d, exponent: exp));
    }
    d = d + step;
    step = six - step;
  }
  if (rem > BigInt.one) {
    if (rem.isProbablyPrime) {
      result.add((prime: rem, exponent: 1));
    } else {
      final bigFactors = <BigInt>[];
      final queue = <BigInt>[rem];
      while (queue.isNotEmpty) {
        final curr = queue.removeLast();
        if (curr <= BigInt.one) continue;
        if (curr.isProbablyPrime) {
          bigFactors.add(curr);
        } else {
          final factor = pollardsRho(curr);
          if (factor != null && factor > BigInt.one && factor < curr) {
            queue.add(factor);
            queue.add(curr ~/ factor);
          } else {
            bigFactors.add(curr);
          }
        }
      }
      bigFactors.sort((a, b) => a.compareTo(b));
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
