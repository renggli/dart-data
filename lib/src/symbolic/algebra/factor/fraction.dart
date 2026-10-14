import 'dart:math' as math;

import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../simplify.dart';
import '../structural_order.dart';
import 'univariate.dart';

/// Whether [expr] is a pure monomial.
bool isMonomial(Expr expr) => switch (expr) {
  Variable() => true,
  Pow(base: Variable()) => true,
  Mul(left: final l, right: final r) => isMonomial(l) && isMonomial(r),
  _ => false,
};

/// Degree of [expr] for factor ordering.
double factorDegree(Expr expr) => switch (expr) {
  Variable() => 1.0,
  Pow(base: Variable(), exponent: final Number exp) when exp.isReal =>
    exp.toDouble(),
  Pow(base: Variable(), exponent: Neg(expr: final Number exp))
      when exp.isReal =>
    -exp.toDouble(),
  Mul(left: final l, right: final r) => factorDegree(l) + factorDegree(r),
  Add(left: final l, right: final r) => math.max(
    factorDegree(l),
    factorDegree(r),
  ),
  Sub(left: final l, right: final r) => math.max(
    factorDegree(l),
    factorDegree(r),
  ),
  Neg(:final expr) => factorDegree(expr),
  Number() => 0.0,
  _ => 0.0,
};

/// Compares two factored expressions for canonical ordering.
int compareFactor(Expr a, Expr b) {
  if (identical(a, b)) return 0;
  // 1. Monomials (x, y, x^2) come before compound polynomial factors ((x-2), (x+y))
  final isMonoA = isMonomial(a);
  final isMonoB = isMonomial(b);
  if (isMonoA != isMonoB) {
    return isMonoA ? -1 : 1;
  }

  // 2. Ascending polynomial degree (linear before quadratic, etc.)
  final degA = factorDegree(a);
  final degB = factorDegree(b);
  if (degA != degB) {
    return degA.compareTo(degB);
  }

  // 3. Primary variable symbol name alphabetically
  final symA = primarySymbol(a);
  final symB = primarySymbol(b);
  final cmpSym = symA.compareTo(symB);
  if (cmpSym != 0) return cmpSym;

  // 4. For linear factors, sort by ascending root magnitude
  if (degA == 1.0) {
    final rA = linearRootMagnitude(a);
    final rB = linearRootMagnitude(b);
    if (rA != null && rB != null && rA != rB) {
      return rA.compareTo(rB);
    }
  }

  // 5. Sub (difference) before Add (sum) for identical degree & root magnitude
  final isSubA = a is Sub;
  final isSubB = b is Sub;
  if (isSubA != isSubB) {
    return isSubA ? -1 : 1;
  }

  // 6. Fallback to compareStructural
  return compareStructural(a, b);
}

/// Builds a canonically sorted product expression from [scalar] and [factors].
Expr buildFactoredExpr({
  required Fraction scalar,
  required Map<Expr, int> factors,
}) {
  if (factors.isEmpty) {
    return RationalNumber.fraction(scalar);
  }

  final sortedFactors = factors.entries.toList()
    ..sort((a, b) => compareFactor(a.key, b.key));

  Expr? product;
  if (scalar != Fraction.one && scalar != -Fraction.one) {
    product = RationalNumber.fraction(scalar);
  }

  for (final entry in sortedFactors) {
    final factorExpr = entry.value == 1
        ? entry.key
        : Pow(entry.key, RationalNumber(entry.value));
    product = product == null ? factorExpr : Mul(product, factorExpr);
  }

  if (scalar == -Fraction.one) {
    return Neg(product!);
  }
  return product ?? RationalNumber.fraction(scalar);
}

/// Cancels common symbolic factors and numerical scalar between [num] and [den].
Expr cancelFactoredFraction(Expr num, Expr den) {
  final numFactors = <Expr, int>{};
  var numScalar = Fraction.one;
  flattenFactored(num, numFactors, (s) => numScalar *= s);

  final denFactors = <Expr, int>{};
  var denScalar = Fraction.one;
  flattenFactored(den, denFactors, (s) => denScalar *= s);

  if (denScalar.a == 0) {
    throw UnsupportedError('Division by zero in factorization');
  }

  // Cancel common symbolic factors
  for (final key in numFactors.keys.toList()) {
    if (denFactors.containsKey(key)) {
      final nExp = numFactors[key]!;
      final dExp = denFactors[key]!;
      final common = math.min(nExp, dExp);
      final newN = nExp - common;
      final newD = dExp - common;
      if (newN == 0) {
        numFactors.remove(key);
      } else {
        numFactors[key] = newN;
      }
      if (newD == 0) {
        denFactors.remove(key);
      } else {
        denFactors[key] = newD;
      }
    }
  }

  final totalScalar = numScalar / denScalar;
  final numExpr = buildFactoredExpr(scalar: totalScalar, factors: numFactors);
  if (denFactors.isEmpty) {
    return numExpr;
  }
  final denExpr = buildFactoredExpr(scalar: Fraction.one, factors: denFactors);
  return Div(numExpr, denExpr);
}

/// Distributes an integer [exponent] across factored [base].
Expr distributePower(Expr base, int exponent) {
  if (exponent == 1) return base;
  if (base is Mul) {
    return Mul(
      distributePower(base.left, exponent),
      distributePower(base.right, exponent),
    );
  }
  if (base is Neg) {
    final inner = distributePower(base.expr, exponent);
    return exponent.isEven ? inner : Neg(inner);
  }
  if (base is RationalNumber) {
    return foldRationalPower(base.numerator, base.denominator, exponent);
  }
  if (base is Pow && base.exponent is RationalNumber) {
    final existingExp = (base.exponent as RationalNumber).toFraction();
    return Pow(
      base.base,
      RationalNumber.fraction(existingExp * Fraction(exponent)),
    ).simplify();
  }
  return Pow(base, RationalNumber(exponent));
}

/// Combines multiple factored expressions into a single canonical product.
Expr combineFactoredProducts(List<Expr> factoredExprs) {
  final factors = <Expr, int>{};
  var scalar = Fraction.one;

  for (final e in factoredExprs) {
    flattenFactored(e, factors, (s) => scalar *= s);
  }

  return buildFactoredExpr(scalar: scalar, factors: factors);
}

/// Flattens a factored expression into [factors] and calls [onScalar] for numeric coefficients.
void flattenFactored(
  Expr expr,
  Map<Expr, int> factors,
  void Function(Fraction) onScalar,
) {
  if (expr is RationalNumber) {
    onScalar(expr.toFraction());
  } else if (expr is Neg) {
    onScalar(-Fraction.one);
    flattenFactored(expr.expr, factors, onScalar);
  } else if (expr is Mul) {
    flattenFactored(expr.left, factors, onScalar);
    flattenFactored(expr.right, factors, onScalar);
  } else if (expr is Pow && expr.exponent is RationalNumber) {
    final exp = expr.exponent as RationalNumber;
    if (exp.isInteger && exp.numerator > 0) {
      factors[expr.base] = (factors[expr.base] ?? 0) + exp.numerator;
    } else {
      factors[expr] = (factors[expr] ?? 0) + 1;
    }
  } else {
    factors[expr] = (factors[expr] ?? 0) + 1;
  }
}
