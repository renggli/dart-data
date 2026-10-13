import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';

/// Simplifies an addition expression [left] + [right].
Expr simplifyAdd(Expr left, Expr right) =>
    simplifyAdditive(left, right, isSubtraction: false);

/// Simplifies a subtraction expression [left] - [right].
Expr simplifySub(Expr left, Expr right) =>
    simplifyAdditive(left, right, isSubtraction: true);

/// Evaluates and simplifies additive combinations of [left] and [right].
Expr simplifyAdditive(Expr left, Expr right, {required bool isSubtraction}) {
  // Fast paths for zero identities and constant evaluation
  if (!isSubtraction) {
    if (left is RationalNumber && left.isZero) return right;
    if (right is RationalNumber && right.isZero) return left;
    if (left is RealNumber && left.value == 0.0) return right;
    if (right is RealNumber && right.value == 0.0) return left;
    if (left is RationalNumber && right is RationalNumber) {
      return RationalNumber.fraction(left.toFraction() + right.toFraction());
    }
    if (left is RealNumber && right is RealNumber) {
      return RealNumber(left.value + right.value);
    }
  } else {
    if (left == right) return RationalNumber.zero;
    if (right is RationalNumber && right.isZero) return left;
    if (right is RealNumber && right.value == 0.0) return left;
    if (left is RationalNumber && left.isZero) return simplifyNeg(right);
    if (left is RealNumber && left.value == 0.0) return simplifyNeg(right);
    if (left is RationalNumber && right is RationalNumber) {
      return RationalNumber.fraction(left.toFraction() - right.toFraction());
    }
    if (left is RealNumber && right is RealNumber) {
      return RealNumber(left.value - right.value);
    }
  }

  final acc = MonomialAccumulator(simplify: simplifyExpr);
  acc.add(left);
  acc.add(right, isSubtraction ? -Fraction.one : Fraction.one);
  acc.reduceIdentities();
  return acc.build();
}

/// Simplifies a negation expression -[expr].
Expr simplifyNeg(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => RationalNumber.zero,
  RealNumber(value: 0.0) => RationalNumber.zero,
  RationalNumber() => RationalNumber.fraction(-expr.toFraction()),
  RealNumber(:final value) => RealNumber(-value),
  Neg(:final expr) => expr,
  OrderTerm() => expr,
  _ => Neg(expr),
};
