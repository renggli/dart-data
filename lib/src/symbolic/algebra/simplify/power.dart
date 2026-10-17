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
    if (exponent
        case RealNumeric(isNegative: true) ||
            Mul(factors: [RealNumeric(isNegative: true), ...])) {
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
        if (exponent.factors[lnIdx] case Ln(:final expr)) {
          final otherFactors = <Expr>[
            for (var i = 0; i < exponent.factors.length; i++)
              if (i != lnIdx) exponent.factors[i],
          ];
          final k = otherFactors.length == 1
              ? otherFactors.first
              : simplifyMul(otherFactors);
          return simplifyPow(expr, k);
        }
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
          final extracted = _extractRationalRadical(base, exponent);
          if (extracted != null) return extracted;
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

  // 4b. (-1)^k = 1 for even integer expression k
  if (base is Number && base.isNegativeOne && isEvenIntegerExpr(exponent)) {
    return IntegerNumber.one;
  }

  // 5. Involution: (u^2)^(1/2) => |u| (or (u^(2*k))^(1/(2*k)) => |u| for real u)
  if (base is Pow &&
      _isTwo(base.exponent) &&
      _isHalf(exponent) &&
      base.base.isReal) {
    return simplifyAbs(base.base);
  }
  if (base
      case Pow(base: final innerBase, exponent: IntegerNumber(value: final p))
      when innerBase.isReal &&
          p > Integer.zero &&
          p.isEven &&
          exponent == RationalNumber.of(Integer.one, p)) {
    return simplifyAbs(innerBase);
  }

  // 6. Nested powers: (u^e1)^e2
  if (base case Pow(base: final innerBase, exponent: final innerExp)) {
    if (innerBase == Constant.e || isNonNegativeExpr(innerBase)) {
      return simplifyPow(innerBase, simplifyMul([innerExp, exponent]));
    }
    if (innerExp is RationalNumber && exponent is RationalNumber) {
      if (innerExp is IntegerNumber &&
          innerExp.value.isEven &&
          exponent is FractionNumber &&
          exponent.denominator.isEven) {
        final prod = innerExp.mulRational(exponent);
        if (innerBase.isReal && prod is IntegerNumber && prod.value.isOdd) {
          return simplifyPow(simplifyAbs(innerBase), prod);
        }
        if (!innerBase.isReal) {
          return Pow(base, exponent, isSimplified: true);
        }
      }
      return simplifyPow(innerBase, innerExp.mulRational(exponent));
    }
    if (exponent is IntegerNumber) {
      return simplifyPow(innerBase, simplifyMul([innerExp, exponent]));
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
  if ((base, exponent)
      case (
        OrderTerm(:final variable, :final order, :final point),
        IntegerNumber(asInt: final k?),
      )
      when k > 0) {
    return OrderTerm(variable, order * k, point: point);
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

Expr? _extractRationalRadical(RationalNumber base, FractionNumber exponent) {
  final p = exponent.numerator.asInt;
  final q = exponent.denominator.asInt;
  if (p == null || q == null || q <= 1 || q > 64 || p.abs() > 64) {
    return null;
  }

  // Split improper fractional exponent: |p| >= q => p = m * q + rem
  if (p.abs() >= q) {
    final m = p ~/ q;
    final rem = p.remainder(q);
    final intPart = base.powInteger(m);
    if (intPart != null) {
      final remExp = RationalNumber(rem, q);
      return simplifyMul([intPart, simplifyPow(base, remExp)]);
    }
  }

  // Extract q-th powers from numerator and denominator: n = k^q * r
  final (kNum, rNum) = _extractQthPower(base.numerator, q);
  final (kDen, rDen) = _extractQthPower(base.denominator, q);

  if (kNum > Integer.one || kDen > Integer.one) {
    final extractedRoot = RationalNumber.of(kNum, kDen);
    final extractedFactor = extractedRoot.powInteger(p);
    if (extractedFactor != null) {
      final remBase = RationalNumber.of(rNum, rDen);
      final remPow = remBase.isOne
          ? IntegerNumber.one
          : Pow(remBase, exponent, isSimplified: true);
      return simplifyMul([extractedFactor, remPow]);
    }
  }

  return null;
}

/// Factors positive [n] into `(root, remainder)` such that $n = \text{root}^q \cdot \text{remainder}$
/// and $\text{remainder}$ is free of prime factors $\le 997$ of multiplicity $\ge q$.
(Integer, Integer) _extractQthPower(Integer n, int q) {
  if (n <= Integer.one || q <= 1) return (Integer.one, n);
  final val = n.asInt;
  if (val != null) {
    var rem = val;
    var root = 1;

    var count2 = 0;
    while ((rem & 1) == 0) {
      rem >>= 1;
      count2++;
    }
    if (count2 >= q) {
      final extracted = count2 ~/ q;
      for (var i = 0; i < extracted; i++) {
        root *= 2;
      }
      count2 %= q;
    }
    for (var i = 0; i < count2; i++) {
      rem <<= 1;
    }

    var d = 3;
    var unfactored = rem >> count2;
    var restored = 1 << count2;
    while (d * d <= unfactored && d <= 997) {
      if (unfactored % d == 0) {
        var c = 0;
        while (unfactored % d == 0) {
          unfactored ~/= d;
          c++;
        }
        if (c >= q) {
          final ext = c ~/ q;
          for (var i = 0; i < ext; i++) {
            root *= d;
          }
          c %= q;
        }
        for (var i = 0; i < c; i++) {
          restored *= d;
        }
      }
      d += 2;
    }
    final finalRem = restored * unfactored;
    return (Integer(root), Integer(finalRem));
  }
  return (Integer.one, n);
}
