import 'dart:math' as math;

import '../../assumptions.dart';
import '../../ast.dart';
import '../../number/integer.dart';
import 'additive.dart';
import 'complex.dart';
import 'domain.dart';
import 'multiplicative.dart';
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
      return (base is RealNumber || exponent is RealNumber)
          ? const RealNumber(0.0)
          : IntegerNumber.zero;
    }
    return Pow(base, exponent, isSimplified: true);
  }
  if (base is Number && base.isOne) {
    return (base is RealNumber || exponent is RealNumber)
        ? const RealNumber(1.0)
        : IntegerNumber.one;
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
    if (exponent is RealNumber) {
      return RealNumber.fromDouble(math.exp(exponent.value));
    }
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
    final invHyp = _simplifyExpInvHyperbolic(exponent, assumptions);
    if (invHyp != null) return invHyp;
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
          innerExp.numerator == Integer.one &&
          exponent is FractionNumber &&
          exponent.numerator.abs() <= innerExp.denominator) {
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
  final p = exponent.numerator.asInt;
  final q = exponent.denominator.asInt;
  if (p == null || q == null || q <= 1 || q > 1024 || p.abs() > 1024) {
    return null;
  }

  // Split rational base u / v into u^(p/q) * v^(-p/q).
  if (base.denominator > Integer.one) {
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
  if (kNum > Integer.one) {
    final extractedFactor = IntegerNumber(kNum).powInteger(p);
    if (extractedFactor != null) {
      final remPow = rNum.isOne
          ? IntegerNumber.one
          : Pow(IntegerNumber(rNum), exponent, isSimplified: true);
      return simplifyMul([extractedFactor, remPow], assumptions: assumptions);
    }
  }

  return null;
}

/// Factors positive [n] into `(root, remainder)` such that $n = \text{root}^q \cdot \text{remainder}$
/// and $\text{remainder}$ is free of prime factors $\le 997$ of multiplicity $\ge q$.
(Integer, Integer) _extractQthPower(Integer n, int q) {
  if (n <= Integer.one || q <= 1) return (Integer.one, n);
  var unfactored = n;
  var root = Integer.one;
  var restored = Integer.one;

  var count2 = 0;
  while (unfactored.isEven) {
    unfactored ~/= Integer.two;
    count2++;
  }
  if (count2 >= q) {
    final extracted = count2 ~/ q;
    for (var i = 0; i < extracted; i++) {
      root *= Integer.two;
    }
    count2 %= q;
  }
  for (var i = 0; i < count2; i++) {
    restored *= Integer.two;
  }

  var d = const Integer(3);
  const limit = Integer(997);
  while (d * d <= unfactored && d <= limit) {
    if ((unfactored % d).isZero) {
      var c = 0;
      while ((unfactored % d).isZero) {
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
    d += Integer.two;
  }

  if (unfactored > Integer.one) {
    final exactRoot = Number.exactIntegerRoot(unfactored, q);
    if (exactRoot != null) {
      root *= exactRoot;
      unfactored = Integer.one;
    } else if (q == 2 && unfactored.bitLength <= 64 && !unfactored.isPrime) {
      final primeCounts = <Integer, int>{};
      final queue = <Integer>[unfactored];
      while (queue.isNotEmpty) {
        final curr = queue.removeLast();
        if (curr <= Integer.one) continue;
        if (curr.isPrime) {
          primeCounts[curr] = (primeCounts[curr] ?? 0) + 1;
        } else {
          final factor = pollardsRho(curr);
          if (factor != null && factor > Integer.one && factor < curr) {
            queue.add(factor);
            queue.add(curr ~/ factor);
          } else {
            primeCounts[curr] = (primeCounts[curr] ?? 0) + 1;
          }
        }
      }
      var rem = Integer.one;
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
  Expr? fn;
  if (exponent is Atanh || exponent is Asinh || exponent is Acosh) {
    k = IntegerNumber.one;
    fn = exponent;
  } else if (exponent is Mul && exponent.factors.length == 2) {
    final f0 = exponent.factors[0];
    final f1 = exponent.factors[1];
    if (f0 is RationalNumber && (f1 is Atanh || f1 is Asinh || f1 is Acosh)) {
      k = f0;
      fn = f1;
    } else if (f1 is RationalNumber &&
        (f0 is Atanh || f0 is Asinh || f0 is Acosh)) {
      k = f1;
      fn = f0;
    }
  }
  if (k == null || fn == null) return null;

  switch (fn) {
    case Atanh(expr: final u):
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
    case Asinh(expr: final u) when k is IntegerNumber:
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
    case Acosh(expr: final u) when k is IntegerNumber:
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
