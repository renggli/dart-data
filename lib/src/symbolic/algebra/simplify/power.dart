import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import 'additive.dart';
import 'multiplicative.dart';
import 'transcendental.dart';

/// Simplifies an exponentiation expression [base] ^ [exponent].
Expr simplifyPow(
  Expr base,
  Expr exponent, {
  Assumptions assumptions = Assumptions.none,
}) {
  if (base == Constant.undefined || exponent == Constant.undefined) {
    return Constant.undefined;
  }

  // 1. Trivial exponent identities: b^0 = 1, b^1 = b
  if (exponent is Number && exponent.isZero) {
    if (base == Constant.infinity) return Constant.undefined;
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
      return Constant.undefined;
    }
    final re = simplifyRe(exponent, assumptions: assumptions);
    if (re is RealNumeric && re.isNegative) {
      return Constant.undefined;
    }
    if (isPositiveExpr(re, assumptions: assumptions)) {
      return IntegerNumber.zero;
    }
    return Pow(base, exponent, isSimplified: true);
  }
  if (base is Number && base.isOne) {
    return IntegerNumber.one;
  }
  if (base == Constant.infinity) {
    if (exponent
        case RealNumeric(isNegative: true) ||
            Mul(factors: [RealNumeric(isNegative: true), ...])) {
      return IntegerNumber.zero;
    }
    if (exponent is RealNumeric && !exponent.isNegative) {
      return Constant.infinity;
    }
  }

  // 3. Natural exponential base e: e^(ln(u)) = u, e^(k * ln(u)) = u^k, e^(i * k * pi)
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
              : simplifyMul(otherFactors, assumptions: assumptions);
          return simplifyPow(expr, k, assumptions: assumptions);
        }
      }

      // Euler's identity: exp(i * theta) where theta is a rational multiple of pi
      var iIdx = exponent.factors.indexOf(ComplexNumber.i);
      Expr? scale;
      if (iIdx == -1) {
        for (var idx = 0; idx < exponent.factors.length; idx++) {
          final f = exponent.factors[idx];
          if (f is ComplexNumber &&
              f.real.isZero &&
              f.imaginary is RationalNumber) {
            iIdx = idx;
            scale = f.imaginary;
            break;
          }
        }
      }
      if (iIdx != -1) {
        final otherFactors = <Expr>[
          ?scale,
          for (var i = 0; i < exponent.factors.length; i++)
            if (i != iIdx) exponent.factors[i],
        ];
        final theta = otherFactors.length == 1
            ? otherFactors.first
            : simplifyMul(otherFactors, assumptions: assumptions);
        final piMult = matchPiMultiple(theta);
        if (piMult != null) {
          final cosVal = simplifyCos(theta, assumptions: assumptions);
          final sinVal = simplifySin(theta, assumptions: assumptions);
          return simplifyAdd([
            cosVal,
            simplifyMul([ComplexNumber.i, sinVal], assumptions: assumptions),
          ], assumptions: assumptions);
        }
      }
    }
    return Pow(Constant.e, exponent, isSimplified: true);
  }

  // 4. Numeric base and numeric exponent
  if (base is Number && exponent is Number) {
    if (base is RealNumber || exponent is RealNumber) {
      final folded = base.powNumber(exponent);
      if (folded != null) return folded;
    }
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
  if (base is Number &&
      base.isNegativeOne &&
      isEvenIntegerExpr(exponent, assumptions: assumptions)) {
    return IntegerNumber.one;
  }

  // 5. Involution: (u^2)^(1/2) => |u| (or (u^(2*k))^(1/(2*k)) => |u| for real u)
  if (base is Pow &&
      _isTwo(base.exponent) &&
      _isHalf(exponent) &&
      isProvenReal(base.base, assumptions)) {
    return simplifyAbs(base.base, assumptions: assumptions);
  }
  if (base
      case Pow(base: final innerBase, exponent: IntegerNumber(value: final p))
      when isProvenReal(innerBase, assumptions) &&
          p > Integer.zero &&
          p.isEven &&
          exponent == RationalNumber.of(Integer.one, p)) {
    return simplifyAbs(innerBase, assumptions: assumptions);
  }

  // 6. Nested powers: (u^e1)^e2
  if (base case Pow(base: final innerBase, exponent: final innerExp)) {
    if (exponent is IntegerNumber) {
      return simplifyPow(
        innerBase,
        simplifyMul([innerExp, exponent], assumptions: assumptions),
        assumptions: assumptions,
      );
    }
    if (innerBase == Constant.e) {
      if (isProvenReal(innerExp, assumptions)) {
        return simplifyPow(
          innerBase,
          simplifyMul([innerExp, exponent], assumptions: assumptions),
          assumptions: assumptions,
        );
      }
    } else if (isNonNegativeExpr(innerBase, assumptions: assumptions)) {
      return simplifyPow(
        innerBase,
        simplifyMul([innerExp, exponent], assumptions: assumptions),
        assumptions: assumptions,
      );
    }
    if (innerExp is RationalNumber && exponent is RationalNumber) {
      if (innerExp is IntegerNumber &&
          innerExp.value.isEven &&
          exponent is FractionNumber &&
          exponent.denominator.isEven) {
        final prod = innerExp.mulRational(exponent);
        if (isProvenReal(innerBase, assumptions)) {
          if (prod is IntegerNumber && prod.value.isEven) {
            return simplifyPow(innerBase, prod, assumptions: assumptions);
          }
          return simplifyPow(
            simplifyAbs(innerBase, assumptions: assumptions),
            prod,
            assumptions: assumptions,
          );
        }
        return Pow(base, exponent, isSimplified: true);
      }
      if (innerExp.numerator > -innerExp.denominator &&
          innerExp.numerator <= innerExp.denominator) {
        return simplifyPow(
          innerBase,
          innerExp.mulRational(exponent),
          assumptions: assumptions,
        );
      }
      return Pow(base, exponent, isSimplified: true);
    }
  }

  // 7. Product raised to an integer power: (a * b)^k => a^k * b^k
  if (base is Mul && exponent is IntegerNumber) {
    return simplifyMul([
      for (final f in base.factors)
        simplifyPow(f, exponent, assumptions: assumptions),
    ], assumptions: assumptions);
  }

  // 7b. Product raised to a fractional power: extract positive rational roots
  // and non-negative power factors whose exponents cancel with the root.
  if (base is Mul && exponent is FractionNumber) {
    final q = exponent.denominator;
    final extractedFactors = <Expr>[];
    final remainingBaseFactors = <Expr>[];

    for (final f in base.factors) {
      if (f is RationalNumber && !f.isNegative && !f.isZero) {
        final exact = f.powNumber(exponent);
        if (exact != null) {
          extractedFactors.add(exact);
          continue;
        }
        final extracted = _extractRationalRadical(f, exponent);
        if (extracted
            case Mul(
              factors: [
                final RationalNumber coeff,
                Pow(base: final remBase, exponent: final remExp),
              ],
            )
            when remExp == exponent) {
          extractedFactors.add(coeff);
          remainingBaseFactors.add(remBase);
          continue;
        }
        remainingBaseFactors.add(f);
      } else if (f case Pow(base: Constant.e, exponent: final innerExp)
          when isRealExpr(innerExp, assumptions)) {
        extractedFactors.add(
          simplifyPow(
            Constant.e,
            simplifyMul([innerExp, exponent], assumptions: assumptions),
            assumptions: assumptions,
          ),
        );
      } else if (f
          case Pow(
            base: final innerBase,
            exponent: IntegerNumber(value: final m),
          )
          when m.abs().gcd(q) > Integer.one &&
              ((m.isEven && isProvenReal(innerBase, assumptions)) ||
                  isNonNegativeExpr(innerBase, assumptions: assumptions))) {
        extractedFactors.add(
          simplifyPow(f, exponent, assumptions: assumptions),
        );
      } else {
        remainingBaseFactors.add(f);
      }
    }

    if (extractedFactors.isNotEmpty) {
      if (remainingBaseFactors.isEmpty) {
        return simplifyMul(extractedFactors, assumptions: assumptions);
      }
      final remBase = remainingBaseFactors.length == 1
          ? remainingBaseFactors.first
          : simplifyMul(remainingBaseFactors, assumptions: assumptions);
      return simplifyMul([
        ...extractedFactors,
        Pow(remBase, exponent, isSimplified: true),
      ], assumptions: assumptions);
    }
  }

  // 8. |u|^2 => u^2 for real u
  if (base is Abs && _isTwo(exponent) && isProvenReal(base.expr, assumptions)) {
    return simplifyPow(base.expr, exponent, assumptions: assumptions);
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
  final expNumber = IntegerNumber.of(exp);
  final folded = rat.powNumber(expNumber);
  return folded ?? Pow(rat, expNumber, isSimplified: true);
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
    return (Integer.from(root), Integer.from(finalRem));
  }
  return (Integer.one, n);
}
