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
    for (final MapEntry(:key, :value) in factors.entries)
      if (value == 1)
        key
      else if (value != 0)
        Pow(key, IntegerNumber.of(value), isSimplified: key.isSimplified),
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
    for (final MapEntry(:key, :value) in denFactors.entries) key: -value,
  };
  return buildFactoredExpr(scalar: totalScalar, factors: allFactors);
}

/// Distributes an integer [exponent] across factored [base].
Expr distributePower(Expr base, int exponent) {
  if (exponent == 1) return base;
  return switch (base) {
    Mul(:final factors) => () {
      final newFactors = <Expr>[
        for (final f in factors)
          if (f is IntegerNumber && f.isNegativeOne)
            if (exponent.isOdd) IntegerNumber.negativeOne else ...<Expr>[]
          else
            distributePower(f, exponent),
      ];
      return switch (newFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul(newFactors),
      };
    }(),
    RationalNumber() =>
      base.powInteger(exponent) ?? Pow(base, IntegerNumber.of(exponent)),
    Pow(base: final innerBase, exponent: final RationalNumber existingExp) =>
      Pow(innerBase, existingExp.mul(IntegerNumber.of(exponent))).simplify(),
    _ => Pow(base, IntegerNumber.of(exponent)),
  };
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
  switch (expr) {
    case final RationalNumber r:
      onScalar(r);
    case Mul(factors: final mulFactors):
      for (final f in mulFactors) {
        flattenFactored(f, factors, onScalar);
      }
    case Pow(:final base, exponent: IntegerNumber(asInt: final exp?))
        when exp > 0:
      factors[base] = (factors[base] ?? 0) + exp;
    default:
      factors[expr] = (factors[expr] ?? 0) + 1;
  }
}
