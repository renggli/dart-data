import 'dart:math' as math;

import '../../ast.dart';
import '../simplify.dart';

/// Whether [expr] is a pure monomial.
bool isMonomial(Expr expr) => switch (expr) {
  Variable() => true,
  Pow(base: Variable()) => true,
  Mul(:final factors) => factors.every(isMonomial),
  _ => false,
};

/// Builds a canonically sorted product expression from [scalar] and [factors]
/// using the same canonical product builder as [simplifyMul].
Expr buildFactoredExpr({
  required RationalNumber scalar,
  required Map<Expr, int> factors,
}) {
  final factorList = <Expr>[
    for (final entry in factors.entries)
      if (entry.value == 1)
        entry.key
      else if (entry.value != 0)
        Pow(
          entry.key,
          IntegerNumber.of(entry.value),
          isSimplified: entry.key.isSimplified,
        ),
  ];
  return simplifySymbolicProduct(scalar, factorList);
}

/// Cancels common symbolic factors and numerical scalar between [num] and [den].
Expr cancelFactoredFraction(Expr num, Expr den) {
  final numFactors = <Expr, int>{};
  RationalNumber numScalar = IntegerNumber.one;
  flattenFactored(num, numFactors, (s) {
    numScalar = numScalar.mulRational(s);
  });

  final denFactors = <Expr, int>{};
  RationalNumber denScalar = IntegerNumber.one;
  flattenFactored(den, denFactors, (s) {
    denScalar = denScalar.mulRational(s);
  });

  if (denScalar.isZero) {
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

  final totalScalar = numScalar.divRational(denScalar);
  final allFactors = <Expr, int>{
    ...numFactors,
    for (final entry in denFactors.entries) entry.key: -entry.value,
  };
  return buildFactoredExpr(scalar: totalScalar, factors: allFactors);
}

/// Distributes an integer [exponent] across factored [base].
Expr distributePower(Expr base, int exponent) {
  if (exponent == 1) return base;
  if (base is Mul) {
    final newFactors = <Expr>[];
    for (final f in base.factors) {
      if (f is IntegerNumber && f.isNegativeOne) {
        if (exponent.isOdd) {
          newFactors.add(IntegerNumber.negativeOne);
        }
      } else {
        newFactors.add(distributePower(f, exponent));
      }
    }
    if (newFactors.isEmpty) return IntegerNumber.one;
    if (newFactors.length == 1) return newFactors.first;
    return Mul(newFactors);
  }
  if (base is RationalNumber) {
    return base.powInteger(exponent) ?? Pow(base, IntegerNumber.of(exponent));
  }
  if (base is Pow && base.exponent is RationalNumber) {
    final existingExp = base.exponent as RationalNumber;
    return Pow(
      base.base,
      existingExp.mul(IntegerNumber.of(exponent)),
    ).simplify();
  }
  return Pow(base, IntegerNumber.of(exponent));
}

/// Combines multiple factored expressions into a single canonical product.
Expr combineFactoredProducts(List<Expr> factoredExprs) {
  final factors = <Expr, int>{};
  RationalNumber scalar = IntegerNumber.one;

  for (final e in factoredExprs) {
    flattenFactored(e, factors, (s) {
      scalar = scalar.mulRational(s);
    });
  }

  return buildFactoredExpr(scalar: scalar, factors: factors);
}

/// Flattens a factored expression into [factors] and calls [onScalar] for numeric coefficients.
void flattenFactored(
  Expr expr,
  Map<Expr, int> factors,
  void Function(RationalNumber) onScalar,
) {
  if (expr is RationalNumber) {
    onScalar(expr);
  } else if (expr is Mul) {
    for (final f in expr.factors) {
      flattenFactored(f, factors, onScalar);
    }
  } else if (expr is Pow && expr.exponent is IntegerNumber) {
    final exp = (expr.exponent as IntegerNumber).asInt;
    if (exp != null && exp > 0) {
      factors[expr.base] = (factors[expr.base] ?? 0) + exp;
    } else {
      factors[expr] = (factors[expr] ?? 0) + 1;
    }
  } else {
    factors[expr] = (factors[expr] ?? 0) + 1;
  }
}
