import '../../ast.dart';
import '../simplify.dart';

/// Simplifies an exponentiation expression [base] ^ [exponent].
Expr simplifyPow(Expr base, Expr exponent) {
  // 1. Trivial exponent identities: b^0 = 1, b^1 = b
  if (exponent is Number && exponent.isZero) {
    return IntegerNumber.one;
  }
  if (exponent is Number && exponent.isOne) {
    return base;
  }

  // 2. Trivial base identities: 0^e, 1^e
  if (base is Number && base.isZero) {
    if (exponent is RealNumeric && exponent.isNegative) {
      throw UnsupportedError('Division by zero in negative power of zero');
    }
    if (exponent is Mul &&
        exponent.factors.isNotEmpty &&
        exponent.factors.first is RealNumeric &&
        (exponent.factors.first as RealNumeric).isNegative) {
      throw UnsupportedError('Division by zero in negative power of zero');
    }
    return IntegerNumber.zero;
  }
  if (base is Number && base.isOne) {
    return IntegerNumber.one;
  }

  // 3. Natural exponential base e: e^(ln(u)) = u, e^(k * ln(u)) = u^k
  if (base == Constant.e) {
    if (exponent is Ln) {
      return exponent.expr;
    }
    if (exponent is Mul) {
      final lnIdx = exponent.factors.indexWhere((f) => f is Ln);
      if (lnIdx != -1) {
        final lnNode = exponent.factors[lnIdx] as Ln;
        final otherFactors = <Expr>[
          for (var i = 0; i < exponent.factors.length; i++)
            if (i != lnIdx) exponent.factors[i],
        ];
        final k = otherFactors.length == 1
            ? otherFactors.first
            : simplifyMul(otherFactors);
        return simplifyPow(lnNode.expr, k);
      }
    }
    return Pow(Constant.e, exponent, isSimplified: true);
  }

  // 4. Numeric base and numeric exponent
  if (base is Number && exponent is Number) {
    if (base is RationalNumber && exponent is RationalNumber) {
      if (exponent is IntegerNumber) {
        final folded = base.powNumber(exponent);
        if (folded != null) return folded;
      } else if (exponent is FractionNumber) {
        if (base.isNegative) {
          if (exponent == FractionNumber.half) {
            return simplifyMul([
              ComplexNumber.i,
              simplifyPow(base.neg(), FractionNumber.half),
            ]);
          }
          if (exponent == FractionNumber.negativeHalf) {
            return simplifyMul([
              ComplexNumber.negativeI,
              simplifyPow(base.neg(), FractionNumber.negativeHalf),
            ]);
          }
        } else {
          final folded = base.powNumber(exponent);
          if (folded != null) return folded;
        }
      }
      return Pow(base, exponent, isSimplified: true);
    }
    if (base is ComplexNumber) {
      final folded = base.powNumber(exponent);
      if (folded != null) return folded;
    }
    return Pow(base, exponent, isSimplified: true);
  }

  // 5. Involution: (u^2)^(1/2) => |u|
  if (base is Pow && _isTwo(base.exponent) && _isHalf(exponent)) {
    return simplifyAbs(base.base);
  }

  // 6. Nested powers: (u^e1)^e2
  if (base is Pow) {
    if (base.base == Constant.e) {
      return simplifyPow(Constant.e, simplifyMul([base.exponent, exponent]));
    }
    if (base.exponent is RationalNumber && exponent is RationalNumber) {
      return simplifyPow(
        base.base,
        (base.exponent as RationalNumber).mulRational(exponent),
      );
    }
    if (exponent is IntegerNumber) {
      return simplifyPow(base.base, simplifyMul([base.exponent, exponent]));
    }
  }

  // 7. Product raised to an integer power: (a * b)^k => a^k * b^k
  if (base is Mul && exponent is IntegerNumber) {
    return simplifyMul([
      for (final f in base.factors) simplifyPow(f, exponent),
    ]);
  }

  // 8. |u|^2 => u^2
  if (base is Abs && _isTwo(exponent)) {
    return simplifyPow(base.expr, exponent);
  }

  // 9. OrderTerm^k for positive integer k
  if (base is OrderTerm &&
      exponent is IntegerNumber &&
      exponent.value > Integer.zero) {
    final k = exponent.asInt;
    if (k != null) {
      return OrderTerm(base.variable, base.order * k, point: base.point);
    }
  }

  return Pow(base, exponent, isSimplified: true);
}

/// Evaluates integer powers of rational numbers.
Expr foldRationalPower(Integer num, Integer den, int exp) {
  final rat = RationalNumber.of(num, den);
  final folded = rat.powNumber(IntegerNumber(Integer(exp)));
  return folded ?? Pow(rat, IntegerNumber(Integer(exp)), isSimplified: true);
}

bool _isTwo(Expr expr) =>
    expr == IntegerNumber.two || (expr is RealNumber && expr.value == 2.0);

bool _isHalf(Expr expr) =>
    expr == FractionNumber.half || (expr is RealNumber && expr.value == 0.5);
