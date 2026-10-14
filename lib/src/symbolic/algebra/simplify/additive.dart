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
    if (left is ComplexNumber &&
        right is ComplexNumber &&
        !_isImaginaryUnit(left) &&
        !_isImaginaryUnit(right)) {
      return _buildComplexOrReal(
        left.real + right.real,
        left.imaginary + right.imaginary,
      );
    }
    if (left is ComplexNumber &&
        !_isImaginaryUnit(left) &&
        right is Number &&
        right is! ConstantNumber &&
        right.isReal) {
      return _buildComplexOrReal(left.real + right.value, left.imaginary);
    }
    if (right is ComplexNumber &&
        !_isImaginaryUnit(right) &&
        left is Number &&
        left is! ConstantNumber &&
        left.isReal) {
      return _buildComplexOrReal(left.value + right.real, right.imaginary);
    }
  } else {
    if (left == right &&
        left is! OrderTerm &&
        left != ConstantNumber.infinity &&
        !left.anyNode((n) => n is OrderTerm || n == ConstantNumber.infinity)) {
      return RationalNumber.zero;
    }
    if (right is RationalNumber && right.isZero) return left;
    if (right is RealNumber && right.value == 0.0) return left;
    if (right is ComplexNumber && right.isZero) return left;
    if (left is RationalNumber && left.isZero) return simplifyNeg(right);
    if (left is RealNumber && left.value == 0.0) return simplifyNeg(right);
    if (left is ComplexNumber && left.isZero) return simplifyNeg(right);
    if (left is RationalNumber && right is RationalNumber) {
      return RationalNumber.fraction(left.toFraction() - right.toFraction());
    }
    if (left is RealNumber && right is RealNumber) {
      return RealNumber(left.value - right.value);
    }
    if (left is ComplexNumber &&
        right is ComplexNumber &&
        !_isImaginaryUnit(left) &&
        !_isImaginaryUnit(right)) {
      return _buildComplexOrReal(
        left.real - right.real,
        left.imaginary - right.imaginary,
      );
    }
    if (left is ComplexNumber &&
        !_isImaginaryUnit(left) &&
        right is Number &&
        right is! ConstantNumber &&
        right.isReal) {
      return _buildComplexOrReal(left.real - right.value, left.imaginary);
    }
    if (right is ComplexNumber &&
        !_isImaginaryUnit(right) &&
        left is Number &&
        left is! ConstantNumber &&
        left.isReal) {
      return _buildComplexOrReal(left.value - right.real, -right.imaginary);
    }
  }

  final acc = MonomialAccumulator(simplify: simplifyExpr);
  acc.add(left);
  acc.add(right, isSubtraction ? -Fraction.one : Fraction.one);
  acc.reduceIdentities();
  return acc.build();
}

bool _isImaginaryUnit(Expr expr) =>
    expr == ConstantNumber.i ||
    (expr is ComplexNumber &&
        expr.real == 0.0 &&
        (expr.imaginary == 1.0 || expr.imaginary == -1.0));

Expr _buildComplexOrReal(double r, double im) {
  if (im == 0.0) {
    if (r == 0.0) return RationalNumber.zero;
    if (r.isFinite && r == r.roundToDouble() && r.abs() < 9007199254740992) {
      return RationalNumber(r.round());
    }
    return RealNumber(r);
  }
  return ComplexNumber(r, im);
}

/// Simplifies a negation expression -[expr].
Expr simplifyNeg(Expr expr) => switch (expr) {
  RationalNumber(isZero: true) => RationalNumber.zero,
  RealNumber(value: 0.0) => RationalNumber.zero,
  ComplexNumber(real: 0.0, imaginary: 0.0) => RationalNumber.zero,
  RationalNumber() => RationalNumber.fraction(-expr.toFraction()),
  RealNumber(:final value) => RealNumber(-value),
  ComplexNumber(:final real, :final imaginary) when !_isImaginaryUnit(expr) =>
    ComplexNumber(-real, -imaginary),
  Neg(:final expr) => expr,
  OrderTerm() => expr,
  _ => Neg(expr),
};
