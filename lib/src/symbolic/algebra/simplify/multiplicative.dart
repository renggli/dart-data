import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../simplify.dart';
import '../term_accumulator.dart';

/// Simplifies a multiplication expression [left] * [right].
Expr simplifyMul(Expr left, Expr right) {
  // Imaginary unit multiplication fast path: i * i = -1
  if (left == ConstantNumber.i && right == ConstantNumber.i) {
    return RationalNumber.negativeOne;
  }

  // Negation pull-through: (-a) * b => -(a * b), a * (-b) => -(a * b)
  if (left is Neg) {
    return simplifyNeg(simplifyMul(left.expr, right));
  }
  if (right is Neg) {
    return simplifyNeg(simplifyMul(left, right.expr));
  }

  // Annihilator: 0 * x = x * 0 = 0
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (right is RationalNumber && right.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (right is RealNumber && right.value == 0.0) return RationalNumber.zero;
  // Multiplicative identity: 1 * x = x, x * 1 = x
  if (left is RationalNumber && left.isOne) return right;
  if (right is RationalNumber && right.isOne) return left;
  if (left is RealNumber && left.value == 1.0) return right;
  if (right is RealNumber && right.value == 1.0) return left;

  // Negation: -1 * x = -x, x * -1 = -x
  if (left is RationalNumber && left.isNegativeOne) return simplifyNeg(right);
  if (right is RationalNumber && right.isNegativeOne) return simplifyNeg(left);
  if (left is RealNumber && left.value == -1.0) return simplifyNeg(right);
  if (right is RealNumber && right.value == -1.0) return simplifyNeg(left);

  // Two numbers:
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() * right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value * right.value);
  }

  // Exponential multiplication: e^a * e^b => e^(a + b)
  if (left is Exp && right is Exp) {
    return simplifyExp(simplifyAdd(left.expr, right.expr));
  }
  // Power multiplication with identical exponents: a^k * b^k => (a * b)^k
  if (left is Pow && right is Pow && left.exponent == right.exponent) {
    if (left.base == right.base) {
      return simplifyPow(left.base, simplifyAdd(left.exponent, right.exponent));
    }
    return simplifyPow(simplifyMul(left.base, right.base), left.exponent);
  }

  // Associative constant folding:
  // (expr * c1) * c2 => expr * (c1 * c2)
  if (left is Mul && left.right is RationalNumber && right is RationalNumber) {
    return simplifyMul(
      left.left,
      RationalNumber.fraction(
        (left.right as RationalNumber).toFraction() * right.toFraction(),
      ),
    );
  }
  // (c1 * expr) * c2 => (c1 * c2) * expr
  if (left is Mul && left.left is RationalNumber && right is RationalNumber) {
    return simplifyMul(
      RationalNumber.fraction(
        (left.left as RationalNumber).toFraction() * right.toFraction(),
      ),
      left.right,
    );
  }
  // c1 * (c2 * expr) => (c1 * c2) * expr
  if (left is RationalNumber && right is Mul && right.left is RationalNumber) {
    return simplifyMul(
      RationalNumber.fraction(
        left.toFraction() * (right.left as RationalNumber).toFraction(),
      ),
      right.right,
    );
  }
  // c1 * (expr * c2) => (c1 * c2) * expr
  if (left is RationalNumber && right is Mul && right.right is RationalNumber) {
    return simplifyMul(
      RationalNumber.fraction(
        left.toFraction() * (right.right as RationalNumber).toFraction(),
      ),
      right.left,
    );
  }

  // Pull out constant scalar from left or right to fold factors:
  if (left is Mul && left.left is RationalNumber) {
    final c1 = left.left as RationalNumber;
    final sub = simplifyMul(left.right, right);
    return simplifyMul(c1, sub);
  }
  if (left is Mul && left.right is RationalNumber) {
    final c1 = left.right as RationalNumber;
    final sub = simplifyMul(left.left, right);
    return simplifyMul(c1, sub);
  }
  if (right is Mul && right.left is RationalNumber) {
    final c2 = right.left as RationalNumber;
    final sub = simplifyMul(left, right.right);
    return simplifyMul(c2, sub);
  }
  if (right is Mul && right.right is RationalNumber) {
    final c2 = right.right as RationalNumber;
    final sub = simplifyMul(left, right.left);
    return simplifyMul(c2, sub);
  }

  // Like-factor multiplications:
  final (baseL, expL) = decomposeFactor(left);
  final (baseR, expR) = decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = simplifyAdd(expL, expR);
    return simplifyPow(baseL, newExp);
  }

  // Associative like-factor multiplications:
  if (left is Mul) {
    final (baseSubR, _) = decomposeFactor(left.right);
    if (baseSubR == baseR) {
      return simplifyMul(left.left, simplifyMul(left.right, right));
    }
    final (baseSubL, _) = decomposeFactor(left.left);
    if (baseSubL == baseR) {
      return simplifyMul(simplifyMul(left.left, right), left.right);
    }
  }
  if (right is Mul) {
    final (baseSubL, _) = decomposeFactor(right.left);
    if (baseSubL == baseL) {
      return simplifyMul(simplifyMul(left, right.left), right.right);
    }
    final (baseSubR, _) = decomposeFactor(right.right);
    if (baseSubR == baseL) {
      return simplifyMul(right.left, simplifyMul(left, right.right));
    }
  }

  // Put numbers on the left of non-numbers, and scalar numbers on the left of constant numbers:
  if (right is Number && left is! Number) {
    return simplifyMul(right, left);
  }
  if ((right is RationalNumber || right is RealNumber) &&
      left is ConstantNumber) {
    return simplifyMul(right, left);
  }

  return Mul(left, right);
}

/// Simplifies a division expression [left] / [right].
Expr simplifyDiv(Expr left, Expr right) {
  // Division by imaginary unit: z / i => -z * i, z / (-i) => z * i
  if (right == ConstantNumber.i) {
    return simplifyMul(simplifyNeg(left), ConstantNumber.i);
  }
  if (right is Neg && right.expr == ConstantNumber.i) {
    return simplifyMul(left, ConstantNumber.i);
  }

  if (right is RationalNumber && right.isZero) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (right is RealNumber && right.value == 0.0) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (left == right) return RationalNumber.one;
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() / right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value / right.value);
  }

  // Exponential division: e^a / e^b => e^(a - b)
  if (left is Exp && right is Exp) {
    return simplifyExp(simplifySub(left.expr, right.expr));
  }
  // Power division with identical exponents: a^k / b^k => (a / b)^k
  if (left is Pow && right is Pow && left.exponent == right.exponent) {
    return simplifyPow(simplifyDiv(left.base, right.base), left.exponent);
  }
  if (right is RationalNumber && right.isOne) return left;
  if (right is RealNumber && right.value == 1.0) return left;
  if (right is RationalNumber && right.isNegativeOne) return simplifyNeg(left);
  if (right is RealNumber && right.value == -1.0) return simplifyNeg(left);

  // Canonicalize expr / RationalNumber(c) => RationalNumber(1/c) * expr
  if (right is RationalNumber) {
    return simplifyMul(
      RationalNumber.fraction(Fraction.one / right.toFraction()),
      left,
    );
  }

  // Like factors: x^a / x^b => x^(a - b)
  final (baseL, expL) = decomposeFactor(left);
  final (baseR, expR) = decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = simplifySub(expL, expR);
    return simplifyPow(baseL, newExp);
  }

  // Mul numerator: (c * r) / r => c, (a * b) / r
  if (left is Mul) {
    final (baseSubL, _) = decomposeFactor(left.left);
    if (baseSubL == baseR) {
      return simplifyMul(simplifyDiv(left.left, right), left.right);
    }
    final (baseSubR, _) = decomposeFactor(left.right);
    if (baseSubR == baseR) {
      return simplifyMul(left.left, simplifyDiv(left.right, right));
    }
  }

  // Distribute over Add / Sub if both parts simplify cleanly:
  if (left is Add) {
    final dL = simplifyDiv(left.left, right);
    final dR = simplifyDiv(left.right, right);
    if (dL is! Div && dR is! Div) {
      return simplifyAdd(dL, dR);
    }
  }
  if (left is Sub) {
    final dL = simplifyDiv(left.left, right);
    final dR = simplifyDiv(left.right, right);
    if (dL is! Div && dR is! Div) {
      return simplifySub(dL, dR);
    }
  }

  return Div(left, right);
}
