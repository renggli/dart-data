import 'dart:math' as math;

import 'package:more/math.dart';

import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/combinatorics.dart';
import '../../oracle/sign.dart';
import 'additive.dart';
import 'complex.dart';
import 'multiplicative.dart';
import 'special.dart';
import 'transcendental.dart';

/// Simplifies an exponentiation expression [base] ^ [exponent].
Expr simplifyPow(Expr base, Expr exponent, {required Assumptions assumptions}) {
  if (base == Constant.undefined || exponent == Constant.undefined) {
    return Constant.undefined;
  }

  // 1. Trivial exponent identities: b^0 = 1, b^1 = b
  if (exponent is Number && exponent.isZero) {
    if (base == Constant.infinity) return Constant.undefined;
    return (base is RealNumber ||
            exponent is RealNumber ||
            (base is ComplexNumber &&
                (base.real is RealNumber || base.imaginary is RealNumber)))
        ? const RealNumber(1.0)
        : IntegerNumber.one;
  }
  if (exponent is IntegerNumber && exponent.isOne) {
    return base;
  }

  // 2. Trivial base identities: 0^e, 1^e
  if (base is Number && base.isZero) {
    if (isNegativeExpr(exponent, assumptions: assumptions)) {
      return Constant.undefined;
    }
    final re = simplifyRe(exponent, assumptions: assumptions);
    if (re is RealNumeric && re.isNegative) {
      return Constant.undefined;
    }
    if (isPositiveExpr(re, assumptions: assumptions)) {
      return (base is RealNumber || exponent is RealNumber)
          ? const RealNumber(0.0)
          : IntegerNumber.zero;
    }
    return Pow.of(base, exponent);
  }
  if (base is Number && base.isOne) {
    if (exponent.anyNode((n) => n == Constant.infinity)) {
      return Constant.undefined;
    }
    return (base is RealNumber || exponent is RealNumber)
        ? const RealNumber(1.0)
        : IntegerNumber.one;
  }
  if (base == Constant.infinity) {
    if (isNegativeExpr(exponent, assumptions: assumptions)) {
      return IntegerNumber.zero;
    }
    if (isPositiveExpr(exponent, assumptions: assumptions)) {
      return Constant.infinity;
    }
  }

  // 3. Natural exponential base e: e^(ln(u)) = u, e^(k * ln(u)) = u^k, e^(i * k * pi)
  if (base == Constant.e) {
    if (exponent is RealNumber) {
      return RealNumber.fromDouble(math.exp(exponent.value));
    }
    if (exponent is ComplexNumber && isFloatComplex(exponent)) {
      return complexToExpr(exponent.toComplex().exp());
    }
    if (exponent case Call(id: FunctionId.ln, args: [final inner])) {
      return inner;
    }
    if (exponent is Mul) {
      final lnIdx = exponent.factors.indexWhere(
        (f) => f is Call && f.id == FunctionId.ln,
      );
      if (lnIdx != -1) {
        if (exponent.factors[lnIdx] case Call(
          id: FunctionId.ln,
          args: [final inner],
        )) {
          final otherFactors = <Expr>[
            for (var i = 0; i < exponent.factors.length; i++)
              if (i != lnIdx) exponent.factors[i],
          ];
          final k = otherFactors.length == 1
              ? otherFactors.first
              : simplifyMul(otherFactors, assumptions: assumptions);
          return simplifyPow(inner, k, assumptions: assumptions);
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
    final invHyp = _simplifyExpInvHyperbolic(exponent, assumptions);
    if (invHyp != null) return invHyp;
    return Pow.of(Constant.e, exponent);
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
              simplifyPow(
                base.neg(),
                FractionNumber.half,
                assumptions: assumptions,
              ),
            ], assumptions: assumptions);
          }
          if (exponent == FractionNumber.negativeHalf) {
            return simplifyMul([
              ComplexNumber.negativeI,
              simplifyPow(
                base.neg(),
                FractionNumber.negativeHalf,
                assumptions: assumptions,
              ),
            ], assumptions: assumptions);
          }
          if (assumptions.defaultDomain == VariableDomain.complex) {
            if (base == IntegerNumber.negativeOne) {
              return Pow.of(base, exponent);
            }
            return simplifyMul([
              Pow.of(IntegerNumber.negativeOne, exponent),
              simplifyPow(base.neg(), exponent, assumptions: assumptions),
            ], assumptions: assumptions);
          }
        }
        final folded = base.powNumber(exponent);
        if (folded != null) return folded;
        final extracted = _extractRationalRadical(
          base,
          exponent,
          assumptions: assumptions,
        );
        if (extracted != null) return extracted;
      }
      return Pow.of(base, exponent);
    }
    if (base is ComplexNumber) {
      final folded = base.powNumber(exponent);
      if (folded != null) return folded;
    }
    return Pow.of(base, exponent);
  }

  // 4b. (-1)^k = 1 for even integer expression k, -1 for odd integer expression k
  if (base is Number && base.isNegativeOne) {
    if (isEvenIntegerExpr(exponent, assumptions: assumptions)) {
      return IntegerNumber.one;
    }
    if (isOddInteger(exponent, assumptions: assumptions)) {
      return IntegerNumber.negativeOne;
    }
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
          p > BigInt.zero &&
          p.isEven &&
          exponent == RationalNumber.of(BigInt.one, p)) {
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
    } else if (isNonNegativeExpr(innerBase, assumptions: assumptions) &&
        isProvenReal(innerExp, assumptions)) {
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
        return Pow.of(base, exponent);
      }
      if (innerExp is FractionNumber &&
          innerExp.numerator.isEven &&
          innerExp.denominator.isOdd &&
          isProvenReal(innerBase, assumptions)) {
        final prod = innerExp.mulRational(exponent);
        if (!isNonNegativeExpr(innerBase, assumptions: assumptions)) {
          return simplifyPow(
            simplifyAbs(innerBase, assumptions: assumptions),
            prod,
            assumptions: assumptions,
          );
        }
        return simplifyPow(innerBase, prod, assumptions: assumptions);
      }
      if (innerExp is FractionNumber &&
          innerExp.numerator == BigInt.one &&
          exponent is FractionNumber &&
          exponent.numerator.abs() <= innerExp.denominator) {
        return simplifyPow(
          innerBase,
          innerExp.mulRational(exponent),
          assumptions: assumptions,
        );
      }
      return Pow.of(base, exponent);
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
        final extracted = _extractRationalRadical(
          f,
          exponent,
          assumptions: assumptions,
        );
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
          when isProvenReal(innerExp, assumptions)) {
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
          when m.abs().gcd(q) > BigInt.one &&
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
        simplifyPow(remBase, exponent, assumptions: assumptions),
      ], assumptions: assumptions);
    }
  }

  // 7c. Square-root radical denesting: sqrt(a ± b*sqrt(c))
  if (base is Add &&
      (exponent == FractionNumber.half ||
          exponent == FractionNumber.negativeHalf)) {
    final denested = _denestSqrt(base, assumptions);
    if (denested != null) {
      return exponent == FractionNumber.half
          ? denested
          : simplifyPow(
              denested,
              IntegerNumber.negativeOne,
              assumptions: assumptions,
            );
    }
  }

  // 8. |u|^2 => u^2 for real u
  if (base case Call(id: FunctionId.abs, args: [final inner])
      when _isTwo(exponent) && isProvenReal(inner, assumptions)) {
    return simplifyPow(inner, exponent, assumptions: assumptions);
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

  return Pow.of(base, exponent);
}

bool _isTwo(Expr expr) => expr == IntegerNumber.two;

bool _isHalf(Expr expr) => expr == FractionNumber.half;

Expr? _extractRationalRadical(
  RationalNumber base,
  FractionNumber exponent, {
  required Assumptions assumptions,
}) {
  if (base.isZero || base.isOne) return null;
  if (base.isNegative) {
    if (exponent.denominator.isEven) return null;
    final posExtracted = _extractRationalRadical(
      base.abs(),
      exponent,
      assumptions: assumptions,
    );
    if (posExtracted == null) return null;
    return exponent.numerator.isOdd
        ? simplifyNeg(posExtracted, assumptions: assumptions)
        : posExtracted;
  }
  final p = exponent.numerator.isValidInt ? exponent.numerator.toInt() : null;
  final q = exponent.denominator.isValidInt
      ? exponent.denominator.toInt()
      : null;
  if (p == null || q == null || q <= 1 || q > 1024 || p.abs() > 1024) {
    return null;
  }

  // Split rational base u / v into u^(p/q) * v^(-p/q).
  if (base.denominator > BigInt.one) {
    final u = IntegerNumber(base.numerator);
    final v = IntegerNumber(base.denominator);
    return simplifyMul([
      if (!u.isOne) simplifyPow(u, exponent, assumptions: assumptions),
      simplifyPow(v, exponent.neg(), assumptions: assumptions),
    ], assumptions: assumptions);
  }

  // Integer base > 1: floorDiv(p, q) ensures remaining exponent r/q is in (0, 1).
  var m = p ~/ q;
  var r = p - m * q;
  if (r < 0) {
    m -= 1;
    r += q;
  }
  if (m != 0) {
    final intPart = base.powInteger(m);
    if (intPart != null) {
      final remExp = RationalNumber(r, q);
      return simplifyMul([
        intPart,
        simplifyPow(base, remExp, assumptions: assumptions),
      ], assumptions: assumptions);
    }
  }

  // Extract q-th powers from integer base: n = k^q * r
  final (kNum, rNum) = _extractQthPower(base.numerator, q);
  if (kNum > BigInt.one) {
    final extractedFactor = IntegerNumber(kNum).powInteger(p);
    if (extractedFactor != null) {
      final remPow = rNum == BigInt.one
          ? IntegerNumber.one
          : Pow.of(IntegerNumber(rNum), exponent);
      return simplifyMul([extractedFactor, remPow], assumptions: assumptions);
    }
  }

  return null;
}

/// Factors positive [n] into `(root, remainder)` such that `n = root^q * remainder`
/// and `remainder` is free of prime factors `<=997` of multiplicity `>=q`.
(BigInt, BigInt) _extractQthPower(BigInt n, int q) {
  if (n <= BigInt.one || q <= 1) return (BigInt.one, n);
  var unfactored = n;
  var root = BigInt.one;
  var restored = BigInt.one;

  var count2 = 0;
  while (unfactored.isEven) {
    unfactored ~/= BigInt.two;
    count2++;
  }
  if (count2 >= q) {
    final extracted = count2 ~/ q;
    for (var i = 0; i < extracted; i++) {
      root *= BigInt.two;
    }
    count2 %= q;
  }
  for (var i = 0; i < count2; i++) {
    restored *= BigInt.two;
  }

  var d = BigInt.from(3);
  final limit = BigInt.from(997);
  while (d * d <= unfactored && d <= limit) {
    if (unfactored % d == BigInt.zero) {
      var c = 0;
      while (unfactored % d == BigInt.zero) {
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
    d += BigInt.two;
  }

  if (unfactored > BigInt.one) {
    final exactRoot = Number.exactIntegerRoot(unfactored, q);
    if (exactRoot != null) {
      root *= exactRoot;
      unfactored = BigInt.one;
    } else if (q == 2 &&
        unfactored.bitLength <= 64 &&
        !unfactored.isProbablyPrime) {
      final primeCounts = <BigInt, int>{};
      final queue = <BigInt>[unfactored];
      while (queue.isNotEmpty) {
        final curr = queue.removeLast();
        if (curr <= BigInt.one) continue;
        if (curr.isProbablyPrime) {
          primeCounts[curr] = (primeCounts[curr] ?? 0) + 1;
        } else {
          final factor = pollardsRho(curr);
          if (factor != null && factor > BigInt.one && factor < curr) {
            queue.add(factor);
            queue.add(curr ~/ factor);
          } else {
            primeCounts[curr] = (primeCounts[curr] ?? 0) + 1;
          }
        }
      }
      var rem = BigInt.one;
      for (final MapEntry(key: p, value: c) in primeCounts.entries) {
        final ext = c ~/ 2;
        for (var i = 0; i < ext; i++) {
          root *= p;
        }
        if (c.isOdd) {
          rem *= p;
        }
      }
      unfactored = rem;
    }
  }

  return (root, restored * unfactored);
}

Expr? _simplifyExpInvHyperbolic(Expr exponent, Assumptions assumptions) {
  RationalNumber? k;
  Call? fn;
  if (exponent is Call &&
      (exponent.id == FunctionId.atanh ||
          exponent.id == FunctionId.asinh ||
          exponent.id == FunctionId.acosh)) {
    k = IntegerNumber.one;
    fn = exponent;
  } else if (exponent is Mul && exponent.factors.length == 2) {
    final f0 = exponent.factors[0];
    final f1 = exponent.factors[1];
    if (f0 is RationalNumber &&
        f1 is Call &&
        (f1.id == FunctionId.atanh ||
            f1.id == FunctionId.asinh ||
            f1.id == FunctionId.acosh)) {
      k = f0;
      fn = f1;
    } else if (f1 is RationalNumber &&
        f0 is Call &&
        (f0.id == FunctionId.atanh ||
            f0.id == FunctionId.asinh ||
            f0.id == FunctionId.acosh)) {
      k = f1;
      fn = f0;
    }
  }
  if (k == null || fn == null) return null;

  final u = fn.args[0];
  switch (fn.id) {
    case FunctionId.atanh:
      if (k.denominator != BigInt.one) return null;
      if (k.numerator.isOdd) {
        if (u is ComplexNumber) return null;
        if (tryStaticRealValue(u) case final v? when v.abs() >= 1.0) {
          return null;
        }
      }
      final num = simplifyAdd([IntegerNumber.one, u], assumptions: assumptions);
      final negU = simplifyMul([
        IntegerNumber.negativeOne,
        u,
      ], assumptions: assumptions);
      final den = simplifyAdd([
        IntegerNumber.one,
        negU,
      ], assumptions: assumptions);
      final ratio = simplifyMul([
        num,
        simplifyPow(den, IntegerNumber.negativeOne, assumptions: assumptions),
      ], assumptions: assumptions);
      final expHalf = simplifyMul([
        k,
        FractionNumber.half,
      ], assumptions: assumptions);
      return simplifyPow(ratio, expHalf, assumptions: assumptions);
    case FunctionId.asinh when k is IntegerNumber:
      final u2Plus1 = simplifyAdd([
        simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
        IntegerNumber.one,
      ], assumptions: assumptions);
      final root = simplifyPow(
        u2Plus1,
        FractionNumber.half,
        assumptions: assumptions,
      );
      final signedU = k.isNegative
          ? simplifyMul([
              IntegerNumber.negativeOne,
              u,
            ], assumptions: assumptions)
          : u;
      final base = simplifyAdd([root, signedU], assumptions: assumptions);
      final absK = IntegerNumber(k.value.abs());
      return absK == IntegerNumber.one
          ? base
          : simplifyPow(base, absK, assumptions: assumptions);
    case FunctionId.acosh when k is IntegerNumber:
      if (u is ComplexNumber) return null;
      if (tryStaticRealValue(u) case final v? when v < 1.0) return null;
      final u2Minus1 = simplifyAdd([
        simplifyPow(u, IntegerNumber.two, assumptions: assumptions),
        IntegerNumber.negativeOne,
      ], assumptions: assumptions);
      final root = simplifyPow(
        u2Minus1,
        FractionNumber.half,
        assumptions: assumptions,
      );
      final signedRoot = k.isNegative
          ? simplifyMul([
              IntegerNumber.negativeOne,
              root,
            ], assumptions: assumptions)
          : root;
      final base = simplifyAdd([u, signedRoot], assumptions: assumptions);
      final absK = IntegerNumber(k.value.abs());
      return absK == IntegerNumber.one
          ? base
          : simplifyPow(base, absK, assumptions: assumptions);
    default:
      return null;
  }
}

Expr? _denestSqrt(Add base, Assumptions assumptions) {
  if (base.terms.length != 2) return null;
  RationalNumber? a;
  Expr? other;
  if (base.terms[0] is RationalNumber) {
    a = base.terms[0] as RationalNumber;
    other = base.terms[1];
  } else if (base.terms[1] is RationalNumber) {
    a = base.terms[1] as RationalNumber;
    other = base.terms[0];
  }
  if (a == null || other == null || a.isNegative || a.isZero) return null;

  RationalNumber? b;
  RationalNumber? c;
  switch (other) {
    case Pow(base: final RationalNumber rc, exponent: final exp)
        when exp == FractionNumber.half:
      b = IntegerNumber.one;
      c = rc;
    case Mul(factors: [final f0, final f1]):
      if (f0 is RationalNumber &&
          f1 is Pow &&
          f1.exponent == FractionNumber.half &&
          f1.base is RationalNumber) {
        b = f0;
        c = f1.base as RationalNumber;
      } else if (f1 is RationalNumber &&
          f0 is Pow &&
          f0.exponent == FractionNumber.half &&
          f0.base is RationalNumber) {
        b = f1;
        c = f0.base as RationalNumber;
      }
    default:
      break;
  }
  if (b == null || c == null || c.isNegative || c.isZero || b.isZero) {
    return null;
  }

  final disc = simplifyAdd([
    simplifyPow(a, IntegerNumber.two, assumptions: assumptions),
    simplifyMul([
      IntegerNumber.negativeOne,
      simplifyPow(b, IntegerNumber.two, assumptions: assumptions),
      c,
    ], assumptions: assumptions),
  ], assumptions: assumptions);
  if (disc is! RationalNumber || disc.isNegative) return null;

  final d = disc.powNumber(FractionNumber.half);
  if (d is! RationalNumber) return null;

  final u = simplifyMul([
    simplifyAdd([a, d], assumptions: assumptions),
    FractionNumber.half,
  ], assumptions: assumptions);
  final v = simplifyMul([
    simplifyAdd([
      a,
      simplifyMul([IntegerNumber.negativeOne, d], assumptions: assumptions),
    ], assumptions: assumptions),
    FractionNumber.half,
  ], assumptions: assumptions);
  final sqrtU = simplifyPow(u, FractionNumber.half, assumptions: assumptions);
  final sqrtV = simplifyPow(v, FractionNumber.half, assumptions: assumptions);
  final signedSqrtV = b.isNegative
      ? simplifyMul([
          IntegerNumber.negativeOne,
          sqrtV,
        ], assumptions: assumptions)
      : sqrtV;
  return simplifyAdd([sqrtU, signedSqrtV], assumptions: assumptions);
}
