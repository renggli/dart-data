import 'package:more/number.dart' show Fraction;

import '../../ast.dart';
import '../simplify.dart';
import '../structural_order.dart';
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
  if (left is RationalNumber && right is RealNumber) {
    return RealNumber(left.toDouble() * right.value);
  }
  if (left is RealNumber && right is RationalNumber) {
    return RealNumber(left.value * right.toDouble());
  }
  if (left is ComplexNumber &&
      right is ComplexNumber &&
      !_isImaginaryUnit(left) &&
      !_isImaginaryUnit(right)) {
    final r = left.real * right.real - left.imaginary * right.imaginary;
    final im = left.real * right.imaginary + left.imaginary * right.real;
    return _buildComplexProduct(r, im);
  }
  if (left is ComplexNumber &&
      !_isImaginaryUnit(left) &&
      right is Number &&
      right is! ConstantNumber &&
      right.isReal) {
    final k = right.value;
    return _buildComplexProduct(left.real * k, left.imaginary * k);
  }
  if (right is ComplexNumber &&
      !_isImaginaryUnit(right) &&
      left is Number &&
      left is! ConstantNumber &&
      left.isReal) {
    final k = left.value;
    return _buildComplexProduct(right.real * k, right.imaginary * k);
  }

  // Reciprocal cancellation fast path: u * (1 / u) => 1, (1 / u) * u => 1
  if (right is Div &&
      (right.left is RationalNumber && (right.left as RationalNumber).isOne) &&
      left == right.right) {
    return RationalNumber.one;
  }
  if (left is Div &&
      (left.left is RationalNumber && (left.left as RationalNumber).isOne) &&
      right == left.right) {
    return RationalNumber.one;
  }

  // Div product folding: a * (b / c) => (a * b) / c, (a / b) * c => (a * c) / b
  if (right is Div) {
    return simplifyDiv(simplifyMul(left, right.left), right.right);
  }
  if (left is Div) {
    return simplifyDiv(simplifyMul(left.left, right), left.right);
  }

  // OrderTerm products and scalings
  if (left is OrderTerm && right is OrderTerm) {
    if (left.variable == right.variable && left.point == right.point) {
      return OrderTerm(
        left.variable,
        left.order + right.order,
        point: left.point,
      );
    }
  }
  if (left is Number && right is OrderTerm) {
    return left.isZero ? RationalNumber.zero : right;
  }
  if (right is Number && left is OrderTerm) {
    return right.isZero ? RationalNumber.zero : left;
  }
  if (left is OrderTerm) {
    final res = _multiplyWithOrderTerm(left, right);
    if (res != null) return res;
  }
  if (right is OrderTerm) {
    final res = _multiplyWithOrderTerm(right, left);
    if (res != null) return res;
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

  if (left is Mul || right is Mul) {
    return _simplifyMulFlattened(left, right);
  }

  // Like-factor multiplications:
  final (baseL, expL) = decomposeFactor(left);
  final (baseR, expR) = decomposeFactor(right);
  if (baseL == baseR) {
    final newExp = simplifyAdd(expL, expR);
    return simplifyPow(baseL, newExp);
  }

  // Put numbers on the left of non-numbers, and scalar numbers on the left of constant numbers:
  if (right is Number && left is! Number) {
    return simplifyMul(right, left);
  }
  if ((right is RationalNumber || right is RealNumber) &&
      (left is ConstantNumber || left == ComplexNumber.i)) {
    return simplifyMul(right, left);
  }
  if (left is! Number &&
      right is! Number &&
      compareStructural(baseL, baseR) > 0) {
    return Mul(right, left);
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

  // Negation pull-through: (-a) / (-b) => a / b, (-a) / b => -(a / b), a / (-b) => -(a / b)
  if (left is Neg && right is Neg) {
    return simplifyDiv(left.expr, right.expr);
  }
  if (left is Neg) {
    return simplifyNeg(simplifyDiv(left.expr, right));
  }
  if (right is Neg) {
    return simplifyNeg(simplifyDiv(left, right.expr));
  }

  if (right is RationalNumber && right.isZero) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (right is RealNumber && right.value == 0.0) {
    throw UnsupportedError('Division by zero in simplification');
  }
  if (left == right &&
      left is! OrderTerm &&
      left != ConstantNumber.infinity &&
      !left.anyNode((n) => n is OrderTerm || n == ConstantNumber.infinity)) {
    return RationalNumber.one;
  }
  if (left is RationalNumber && left.isZero) return RationalNumber.zero;
  if (left is RealNumber && left.value == 0.0) return RationalNumber.zero;
  if (left is RationalNumber && right is RationalNumber) {
    return RationalNumber.fraction(left.toFraction() / right.toFraction());
  }
  if (left is RealNumber && right is RealNumber) {
    return RealNumber(left.value / right.value);
  }
  if (left is RationalNumber && right is RealNumber) {
    return RealNumber(left.toDouble() / right.value);
  }
  if (left is RealNumber && right is RationalNumber) {
    return RealNumber(left.value / right.toDouble());
  }
  if (left is ComplexNumber && right is ComplexNumber) {
    final d = right.real * right.real + right.imaginary * right.imaginary;
    if (d == 0.0) {
      throw UnsupportedError('Division by zero in simplification');
    }
    final r = (left.real * right.real + left.imaginary * right.imaginary) / d;
    final im = (left.imaginary * right.real - left.real * right.imaginary) / d;
    return _buildComplexProduct(r, im);
  }
  if (left is ComplexNumber &&
      right is Number &&
      right is! ConstantNumber &&
      right.isReal) {
    final k = right.value;
    if (k == 0.0) {
      throw UnsupportedError('Division by zero in simplification');
    }
    return _buildComplexProduct(left.real / k, left.imaginary / k);
  }

  // Exponential division: e^a / e^b => e^(a - b), 1 / e^b => e^(-b)
  if (left is Exp && right is Exp) {
    return simplifyExp(simplifySub(left.expr, right.expr));
  }
  if (left is RationalNumber && left.isOne && right is Exp) {
    return simplifyExp(simplifyNeg(right.expr));
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

  // Cancel common factors across numerator and denominator products
  if (left is Mul || right is Mul) {
    final numFactors = <(Expr, Expr)>[];
    final denFactors = <(Expr, Expr)>[];
    _collectProductFactors(left, numFactors);
    _collectProductFactors(right, denFactors);

    var changed = false;
    for (var i = 0; i < numFactors.length; i++) {
      final (baseN, expN) = numFactors[i];
      for (var j = 0; j < denFactors.length; j++) {
        final (baseD, expD) = denFactors[j];
        if (baseN == baseD) {
          final diff = simplifySub(expN, expD);
          if (diff == RationalNumber.zero) {
            numFactors.removeAt(i);
            denFactors.removeAt(j);
            i--;
            changed = true;
            break;
          } else if (diff is RationalNumber && diff.numerator > 0) {
            numFactors[i] = (baseN, diff);
            denFactors.removeAt(j);
            changed = true;
            break;
          } else if (diff is RationalNumber && diff.numerator < 0) {
            denFactors[j] = (baseD, simplifyNeg(diff));
            numFactors.removeAt(i);
            i--;
            changed = true;
            break;
          }
        }
      }
    }

    if (changed) {
      Expr rebuild(List<(Expr, Expr)> factors) {
        if (factors.isEmpty) return RationalNumber.one;
        var res = simplifyPow(factors.first.$1, factors.first.$2);
        for (var k = 1; k < factors.length; k++) {
          res = simplifyMul(res, simplifyPow(factors[k].$1, factors[k].$2));
        }
        return res;
      }

      return simplifyDiv(rebuild(numFactors), rebuild(denFactors));
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

  if (left is OrderTerm && right is Number && !right.isZero) {
    return left;
  }

  return Div(left, right);
}

Expr? _multiplyWithOrderTerm(OrderTerm orderTerm, Expr other) {
  final v = orderTerm.variable;
  final p = orderTerm.point;
  final n = orderTerm.order;
  final isZeroPoint = p is RationalNumber && p.isZero;

  if (other is Number) {
    return other.isZero ? RationalNumber.zero : orderTerm;
  }

  if (isZeroPoint && other is Variable && other.name == v) {
    return OrderTerm(v, n + 1, point: p);
  }

  if (isZeroPoint &&
      other is Pow &&
      other.base is Variable &&
      (other.base as Variable).name == v &&
      other.exponent is RationalNumber &&
      (other.exponent as RationalNumber).isInteger) {
    final k = (other.exponent as RationalNumber).numerator;
    if (k > 0) {
      return OrderTerm(v, n + k, point: p);
    }
  }

  if (!isZeroPoint && other == Sub(Variable(v), p)) {
    return OrderTerm(v, n + 1, point: p);
  }

  if (!isZeroPoint &&
      other is Pow &&
      other.base == Sub(Variable(v), p) &&
      other.exponent is RationalNumber &&
      (other.exponent as RationalNumber).isInteger) {
    final k = (other.exponent as RationalNumber).numerator;
    if (k > 0) {
      return OrderTerm(v, n + k, point: p);
    }
  }

  if (other is Add) {
    return simplifyAdd(
      simplifyMul(other.left, orderTerm),
      simplifyMul(other.right, orderTerm),
    );
  }

  if (other is Sub) {
    return simplifySub(
      simplifyMul(other.left, orderTerm),
      simplifyMul(other.right, orderTerm),
    );
  }

  if (other is Mul) {
    if (other.left is Number) {
      final inner = _multiplyWithOrderTerm(orderTerm, other.right);
      if (inner != null) return simplifyMul(other.left, inner);
    } else if (other.right is Number) {
      final inner = _multiplyWithOrderTerm(orderTerm, other.left);
      if (inner != null) return simplifyMul(other.right, inner);
    } else {
      final inner = _multiplyWithOrderTerm(orderTerm, other.left);
      if (inner != null) return simplifyMul(inner, other.right);
    }
  }

  return null;
}

void _collectProductFactors(Expr expr, List<(Expr, Expr)> list) {
  if (expr is Mul) {
    _collectProductFactors(expr.left, list);
    _collectProductFactors(expr.right, list);
  } else if (expr is Neg) {
    list.add((RationalNumber.negativeOne, RationalNumber.one));
    _collectProductFactors(expr.expr, list);
  } else {
    list.add(decomposeFactor(expr));
  }
}

bool _isScalarNumber(Expr expr) =>
    expr is RationalNumber ||
    expr is RealNumber ||
    (expr is ComplexNumber && !_isImaginaryUnit(expr));

bool _isImaginaryUnit(Expr expr) =>
    expr == ConstantNumber.i ||
    (expr is ComplexNumber &&
        expr.real == 0.0 &&
        (expr.imaginary == 1.0 || expr.imaginary == -1.0));

void _flattenMulFactors(Expr expr, List<Expr> factors) {
  if (expr is Mul) {
    _flattenMulFactors(expr.left, factors);
    _flattenMulFactors(expr.right, factors);
  } else {
    factors.add(expr);
  }
}

Expr _simplifyMulFlattened(Expr left, Expr right) {
  final allFactors = <Expr>[];
  _flattenMulFactors(left, allFactors);
  _flattenMulFactors(right, allFactors);

  Expr scalar = RationalNumber.one;
  final baseExponents = <Expr, Expr>{};

  for (final f in allFactors) {
    if (_isScalarNumber(f)) {
      scalar = simplifyMul(scalar, f);
      if (scalar is RationalNumber && scalar.isZero) {
        return RationalNumber.zero;
      }
      if (scalar is RealNumber && scalar.value == 0.0) {
        return RationalNumber.zero;
      }
      if (scalar is ComplexNumber && scalar.isZero) {
        return RationalNumber.zero;
      }
    } else {
      final (base, exp) = decomposeFactor(f);
      if (baseExponents.containsKey(base)) {
        final sumExp = simplifyAdd(baseExponents[base]!, exp);
        if (sumExp == RationalNumber.zero ||
            (sumExp is RealNumber && sumExp.value == 0.0)) {
          baseExponents.remove(base);
        } else {
          baseExponents[base] = sumExp;
        }
      } else {
        baseExponents[base] = exp;
      }
    }
  }

  final remainingFactors = <Expr>[];
  for (final entry in baseExponents.entries) {
    final term = simplifyPow(entry.key, entry.value);
    if (_isScalarNumber(term)) {
      scalar = simplifyMul(scalar, term);
      if (scalar is RationalNumber && scalar.isZero) {
        return RationalNumber.zero;
      }
      if (scalar is RealNumber && scalar.value == 0.0) {
        return RationalNumber.zero;
      }
      if (scalar is ComplexNumber && scalar.isZero) {
        return RationalNumber.zero;
      }
    } else {
      remainingFactors.add(term);
    }
  }

  if (remainingFactors.isEmpty) {
    return scalar;
  }

  remainingFactors.sort((a, b) {
    if (a is Number && b is! Number) return -1;
    if (a is! Number && b is Number) return 1;
    return compareStructural(decomposeFactor(a).$1, decomposeFactor(b).$1);
  });

  var symbolicPart = remainingFactors.first;
  for (var i = 1; i < remainingFactors.length; i++) {
    symbolicPart = Mul(symbolicPart, remainingFactors[i]);
  }
  if ((scalar is RationalNumber && scalar.isOne) ||
      (scalar is RealNumber && scalar.value == 1.0)) {
    return symbolicPart;
  }
  if ((scalar is RationalNumber && scalar.isNegativeOne) ||
      (scalar is RealNumber && scalar.value == -1.0)) {
    return simplifyNeg(symbolicPart);
  }
  return Mul(scalar, symbolicPart);
}

Expr _buildComplexProduct(double r, double im) {
  if (im == 0.0) {
    if (r == 0.0) return RationalNumber.zero;
    if (r.isFinite && r == r.roundToDouble() && r.abs() < 9007199254740992) {
      return RationalNumber(r.round());
    }
    return RealNumber(r);
  }
  return ComplexNumber(r, im);
}
