import 'package:more/number.dart' show Complex;

import '../../../special/bessel.dart' as special_bessel;
import '../../../special/beta.dart' as special_beta;
import '../../../special/binomial.dart' as special_binomial;
import '../../../special/digamma.dart' as special_digamma;
import '../../../special/erf.dart' as special_erf;
import '../../../special/factorial.dart' as special_factorial;
import '../../../special/gamma.dart' as special_gamma;
import '../../../special/lambert_w.dart' as special_lambert;
import '../../../special/zeta.dart' as special_zeta;
import '../../assumptions.dart';
import '../../ast.dart';
import '../../calculus/summation.dart' show evenZetaValue;
import '../../compiler/evaluator_helpers.dart';
import '../../number/integer.dart';
import '../structural_order.dart';
import 'additive.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'transcendental.dart';

/// Simplifies a Lambert W expression `LambertW(expr, branch: branch)`.
Expr simplifyLambertW(
  Expr expr,
  int branch, {
  required Assumptions assumptions,
}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(
      special_lambert.lambertWComplex(toComplex(expr), branch: branch),
    );
  }
  if (expr is RealNumber) {
    final v = expr.value;
    final res = branch == 0
        ? special_lambert.lambertW(v)
        : special_lambert.lambertW(v, branch: -1);
    return res.isNaN ? Constant.undefined : RealNumber.fromDouble(res);
  }
  if (branch == 0) {
    if (expr is Number && expr.isZero) {
      return IntegerNumber.zero;
    }
    if (expr == Constant.e) {
      return IntegerNumber.one;
    }
  }
  // W(-1 / e) = -1
  if (expr case Mul(
    factors: [
      IntegerNumber.negativeOne,
      Pow(base: Constant.e, exponent: IntegerNumber.negativeOne),
    ],
  )) {
    return IntegerNumber.negativeOne;
  }
  return LambertW(expr, branch: branch, isSimplified: true);
}

/// Simplifies an error function expression `erf(expr)`.
Expr simplifyErf(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_erf.erfComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_erf.erf(expr.value));
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyErf(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (expr == Constant.infinity) {
    return IntegerNumber.one;
  }
  return Erf(expr, isSimplified: true);
}

/// Simplifies a complementary error function expression `erfc(expr)`.
Expr simplifyErfc(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_erf.erfcComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_erf.erfc(expr.value));
  }
  if (expr is Number && expr.isZero) {
    return IntegerNumber.one;
  }
  if (expr == Constant.infinity) {
    return IntegerNumber.zero;
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg && posExpr == Constant.infinity) {
    return IntegerNumber.two;
  }
  return Erfc(expr, isSimplified: true);
}

/// Simplifies an Euler gamma function expression `gamma(expr)`.
Expr simplifyGamma(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_gamma.gammaComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    final v = expr.value;
    if (v <= 0.0 && v == v.roundToDouble()) return Constant.undefined;
    return RealNumber.fromDouble(special_gamma.gamma(v));
  }
  if (expr is IntegerNumber) {
    if (expr.isZero || expr.isNegative) return Constant.undefined;
    if (expr.asInt case final n? when n <= 101) {
      return IntegerNumber(Integer.from(n - 1).factorial());
    }
  }
  if (expr == FractionNumber.half) {
    return Pow(Constant.pi, FractionNumber.half, isSimplified: true);
  }
  // Half-integer Gamma(n + 1/2)
  if (expr case FractionNumber(:final numerator, :final denominator)
      when denominator == Integer.two) {
    final n = ((numerator - Integer.one) ~/ Integer.two).asInt;
    if (n != null && n.abs() <= 50) {
      final RationalNumber coeff;
      if (n >= 0) {
        final numFact = Integer.from(2 * n).factorial();
        final denFact = const Integer(4).pow(n)! * Integer.from(n).factorial();
        coeff = RationalNumber.of(numFact, denFact);
      } else {
        final m = -n;
        final numVal = const Integer(-4).pow(m)! * Integer.from(m).factorial();
        final denFact = Integer.from(2 * m).factorial();
        coeff = RationalNumber.of(numVal, denFact);
      }
      return simplifyMul([
        coeff,
        Pow(Constant.pi, FractionNumber.half, isSimplified: true),
      ], assumptions: assumptions);
    }
  }
  return Gamma(expr, isSimplified: true);
}

/// Simplifies a Riemann or Hurwitz zeta function expression `zeta(s)` or `zeta(s, a)`.
Expr simplifyZeta(Expr expr, {Expr? shift}) {
  if (expr == Constant.undefined || shift == Constant.undefined) {
    return Constant.undefined;
  }
  if (shift == IntegerNumber.one) {
    shift = null;
  }
  if (shift != null) {
    if (isFloatComplex(expr) ||
        isFloatComplex(shift) ||
        ((expr is RealNumber || shift is RealNumber) &&
            expr is Number &&
            shift is Number)) {
      if (expr is RealNumber && shift is RealNumber) {
        final v = special_zeta.hurwitzZeta(expr.value, shift.value);
        if (!v.isNaN) return RealNumber.fromDouble(v);
      }
      return complexToExpr(
        special_zeta.hurwitzZetaComplex(toComplex(expr), toComplex(shift)),
      );
    }
    if (expr == IntegerNumber.one) return Constant.undefined;
    if (shift case IntegerNumber(asInt: final m?) when m > 1 && m <= 20) {
      final base = simplifyZeta(expr);
      if (base is! Zeta) {
        final terms = <Expr>[base];
        for (var k = 1; k < m; k++) {
          terms.add(
            simplifyNeg(
              simplifyPow(
                IntegerNumber.of(k),
                simplifyNeg(expr, assumptions: Assumptions.none),
                assumptions: Assumptions.none,
              ),
              assumptions: Assumptions.none,
            ),
          );
        }
        return simplifyAdd(terms, assumptions: Assumptions.none);
      }
    }
    return Zeta(expr, shift: shift, isSimplified: true);
  }
  if (isFloatComplex(expr)) {
    return complexToExpr(special_zeta.zetaComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_zeta.zeta(expr.value));
  }
  if (expr == IntegerNumber.zero) {
    return FractionNumber.negativeHalf;
  }
  if (expr == IntegerNumber.one) {
    return Constant.undefined;
  }
  if (expr case IntegerNumber(asInt: final n?) when n < 0 && n.isEven) {
    return IntegerNumber.zero;
  }
  if (expr case IntegerNumber(asInt: final n?) when n < 0 && n.isOdd) {
    return switch (n) {
      -1 => RationalNumber(-1, 12),
      -3 => RationalNumber(1, 120),
      -5 => RationalNumber(-1, 252),
      -7 => RationalNumber(1, 240),
      -9 => RationalNumber(-1, 132),
      -11 => RationalNumber(691, 32760),
      -13 => RationalNumber(-1, 12),
      -15 => RationalNumber(3617, 8160),
      _ => Zeta(expr, isSimplified: true),
    };
  }
  if (expr case IntegerNumber(asInt: final n?)
      when n > 0 && n.isEven && n <= 16) {
    return evenZetaValue(n);
  }
  return Zeta(expr, isSimplified: true);
}

/// Simplifies a digamma function expression `digamma(x)`.
Expr simplifyDigamma(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_digamma.digammaComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    final v = expr.value;
    if (v <= 0.0 && v == v.roundToDouble()) return Constant.undefined;
    return RealNumber.fromDouble(special_digamma.digamma(v));
  }
  return Digamma(expr, isSimplified: true);
}

/// Simplifies a polygamma function expression `polygamma(m, x)`.
Expr simplifyPolygamma(Expr m, Expr x) {
  if (m == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (m is IntegerNumber &&
      m.asInt != null &&
      m.asInt! >= 0 &&
      isFloatComplex(x)) {
    return complexToExpr(
      special_digamma.polygammaComplex(m.asInt!, toComplex(x)),
    );
  }
  if (m is RealNumeric &&
      x is RealNumeric &&
      (m is RealNumber || x is RealNumber)) {
    final mDouble = m.toDouble();
    if (mDouble != mDouble.roundToDouble()) {
      return Polygamma(m, x, isSimplified: true);
    }
    final dm = mDouble.toInt();
    final dx = x.toDouble();
    if (dm < 0 || (dx <= 0.0 && dx == dx.roundToDouble())) {
      return Constant.undefined;
    }
    return RealNumber.fromDouble(special_digamma.polygamma(dm, dx));
  }
  return Polygamma(m, x, isSimplified: true);
}

/// Simplifies a Bessel function of the first kind `besselJ(nu, x)`.
Expr simplifyBesselJ(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(nu, x)) {
    return complexToExpr(
      special_bessel.besselJComplex(toComplex(nu), toComplex(x)),
    );
  }
  if (x is Number && x.isZero) {
    if (nu is Number && nu.isZero) {
      return (nu is RealNumber || x is RealNumber)
          ? const RealNumber(1.0)
          : IntegerNumber.one;
    }
    if (nu is RealNumeric && !nu.isNegative) {
      return (nu is RealNumber || x is RealNumber)
          ? const RealNumber(0.0)
          : IntegerNumber.zero;
    }
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselJ(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselJ(nu, x, isSimplified: true);
}

/// Simplifies a Bessel function of the second kind `besselY(nu, x)`.
Expr simplifyBesselY(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(nu, x)) {
    return complexToExpr(
      special_bessel.besselYComplex(toComplex(nu), toComplex(x)),
    );
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselY(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselY(nu, x, isSimplified: true);
}

/// Simplifies a modified Bessel function of the first kind `besselI(nu, x)`.
Expr simplifyBesselI(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(nu, x)) {
    return complexToExpr(
      special_bessel.besselIComplex(toComplex(nu), toComplex(x)),
    );
  }
  if (x is Number && x.isZero) {
    if (nu is Number && nu.isZero) {
      return (nu is RealNumber || x is RealNumber)
          ? const RealNumber(1.0)
          : IntegerNumber.one;
    }
    if (nu is RealNumeric && !nu.isNegative) {
      return (nu is RealNumber || x is RealNumber)
          ? const RealNumber(0.0)
          : IntegerNumber.zero;
    }
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselI(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselI(nu, x, isSimplified: true);
}

/// Simplifies a modified Bessel function of the second kind `besselK(nu, x)`.
Expr simplifyBesselK(Expr nu, Expr x) {
  if (nu == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(nu, x)) {
    return complexToExpr(
      special_bessel.besselKComplex(toComplex(nu), toComplex(x)),
    );
  }
  if (nu is RealNumeric &&
      x is RealNumeric &&
      (nu is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_bessel.besselK(nu.toDouble(), x.toDouble()),
    );
  }
  return BesselK(nu, x, isSimplified: true);
}

/// Simplifies a `min(...)` expression.
Expr simplifyMin(List<Expr> args) => _simplifyMinMax(args, isMin: true);

/// Simplifies a `max(...)` expression.
Expr simplifyMax(List<Expr> args) => _simplifyMinMax(args, isMin: false);

Expr _simplifyMinMax(List<Expr> args, {required bool isMin}) {
  if (args.isEmpty) return Constant.undefined;
  final flat = <Expr>[];
  for (final a in args) {
    if (a == Constant.undefined) return Constant.undefined;
    if (isMin && a is Min) {
      flat.addAll(a.args);
    } else if (!isMin && a is Max) {
      flat.addAll(a.args);
    } else {
      flat.add(a);
    }
  }
  RealNumeric? bestNum;
  final other = <Expr>[];
  final seen = <Expr>{};
  for (final a in flat) {
    if (a is RealNumeric) {
      if (bestNum == null) {
        bestNum = a;
      } else {
        final cmp = a.compareTo(bestNum);
        final takeA = isMin ? cmp < 0 : cmp > 0;
        if (takeA || (cmp == 0 && a is RealNumber && bestNum is! RealNumber)) {
          bestNum = a;
        }
      }
    } else if (seen.add(a)) {
      other.add(a);
    }
  }
  final merged = <Expr>[?bestNum, ...other]..sort(compareStructural);
  if (merged.length == 1) return merged.first;
  return isMin
      ? Min(merged, isSimplified: true)
      : Max(merged, isSimplified: true);
}

/// Simplifies a greatest common divisor `gcd(...)` expression.
Expr simplifyGcd(
  List<Expr> args, {
  Assumptions assumptions = Assumptions.none,
}) => _simplifyGcdLcm(args, isGcd: true, assumptions: assumptions);

/// Simplifies a least common multiple `lcm(...)` expression.
Expr simplifyLcm(
  List<Expr> args, {
  Assumptions assumptions = Assumptions.none,
}) => _simplifyGcdLcm(args, isGcd: false, assumptions: assumptions);

Expr _simplifyGcdLcm(
  List<Expr> args, {
  required bool isGcd,
  required Assumptions assumptions,
}) {
  if (args.isEmpty) return Constant.undefined;
  final flat = <Expr>[];
  for (final a in args) {
    if (a == Constant.undefined) return Constant.undefined;
    if (isGcd && a is Gcd) {
      flat.addAll(a.args);
    } else if (!isGcd && a is Lcm) {
      flat.addAll(a.args);
    } else {
      flat.add(a);
    }
  }
  RationalNumber? acc;
  final other = <Expr>[];
  final seen = <Expr>{};
  for (final a in flat) {
    if (a is RationalNumber) {
      final absA = a.abs();
      acc = acc == null ? absA : (isGcd ? acc.gcd(absA) : acc.lcm(absA));
    } else if (seen.add(a)) {
      other.add(a);
    }
  }
  if (!isGcd && acc != null && acc.isZero) {
    return IntegerNumber.zero;
  }
  if (isGcd && acc != null && acc.isZero && other.isNotEmpty) {
    acc = null;
  }
  if (other.isEmpty) {
    return acc ?? IntegerNumber.zero;
  }
  final normalizedOther = isGcd && acc == null && other.length == 1
      ? [simplifyAbs(other.first, assumptions: assumptions)]
      : other;
  final merged = <Expr>[?acc, ...normalizedOther]..sort(compareStructural);
  if (merged.length == 1) return merged.first;
  return isGcd
      ? Gcd(merged, isSimplified: true)
      : Lcm(merged, isSimplified: true);
}

/// Simplifies an Euler beta function expression `beta(a, b)`.
Expr simplifyBeta(Expr a, Expr b, {required Assumptions assumptions}) {
  if (a == Constant.undefined || b == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(a, b)) {
    return complexToExpr(special_beta.betaComplex(toComplex(a), toComplex(b)));
  }
  if (a is RealNumeric &&
      b is RealNumeric &&
      (a is RealNumber || b is RealNumber)) {
    final da = a.toDouble();
    final db = b.toDouble();
    final res = special_beta.beta(da, db);
    return res.isNaN ? Constant.undefined : RealNumber.fromDouble(res);
  }
  if (compareStructural(a, b) > 0) {
    return simplifyBeta(b, a, assumptions: assumptions);
  }
  if (a case IntegerNumber(asInt: final m?) when m > 0) {
    if (b case IntegerNumber(asInt: final n?) when n > 0 && m <= 1000) {
      final denom =
          Integer.from(n) *
          Integer.from(m + n - 1).binomial(Integer.from(m - 1));
      return RationalNumber.of(Integer.one, denom);
    }
    if (m == 1) {
      return simplifyPow(
        b,
        IntegerNumber.negativeOne,
        assumptions: assumptions,
      );
    }
    if (m <= 12) {
      var fact = 1;
      for (var j = 2; j < m; j++) {
        fact *= j;
      }
      final factors = <Expr>[
        b,
        for (var j = 1; j < m; j++)
          simplifyAdd([b, IntegerNumber.of(j)], assumptions: assumptions),
      ];
      return simplifyMul([
        IntegerNumber.of(fact),
        simplifyPow(
          simplifyMul(factors, assumptions: assumptions),
          IntegerNumber.negativeOne,
          assumptions: assumptions,
        ),
      ], assumptions: assumptions);
    }
  }
  if (b == IntegerNumber.one) {
    return simplifyPow(a, IntegerNumber.negativeOne, assumptions: assumptions);
  }
  // Rational arguments where Gamma(a), Gamma(b), Gamma(a + b) simplify
  if (a is RationalNumber &&
      b is RationalNumber &&
      !a.isNegative &&
      !a.isZero &&
      !b.isNegative &&
      !b.isZero) {
    final sum = a.addRational(b);
    if ((a.denominator == Integer.one || a.denominator == Integer.two) &&
        (b.denominator == Integer.one || b.denominator == Integer.two) &&
        (sum.denominator == Integer.one || sum.denominator == Integer.two)) {
      final ga = simplifyGamma(a, assumptions: assumptions);
      final gb = simplifyGamma(b, assumptions: assumptions);
      final gab = simplifyGamma(sum, assumptions: assumptions);
      if (ga is! Gamma && gb is! Gamma && gab is! Gamma) {
        return simplifyMul([
          ga,
          gb,
          simplifyPow(gab, IntegerNumber.negativeOne, assumptions: assumptions),
        ], assumptions: assumptions);
      }
    }
  }
  return Beta(a, b, isSimplified: true);
}

/// Simplifies a factorial expression `n!`.
Expr simplifyFactorial(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_factorial.factorialComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return simplifyGamma(
      RealNumber.fromDouble(expr.value + 1.0),
      assumptions: assumptions,
    );
  }
  if (expr is IntegerNumber) {
    if (expr.isNegative) return Constant.undefined;
    if (expr.asInt case final n? when n <= 100) {
      return IntegerNumber(Integer.from(n).factorial());
    }
  }
  if (expr case FractionNumber(:final numerator, :final denominator)
      when denominator == Integer.two && numerator.abs() <= const Integer(41)) {
    return simplifyGamma(
      FractionNumber(numerator + Integer.two, Integer.two),
      assumptions: assumptions,
    );
  }
  return Factorial(expr, isSimplified: true);
}

/// Simplifies a binomial coefficient `binomial(n, k)`.
Expr simplifyBinomial(
  Expr nExpr,
  Expr kExpr, {
  required Assumptions assumptions,
}) {
  if (nExpr == Constant.undefined || kExpr == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(nExpr, kExpr)) {
    return complexToExpr(
      special_binomial.binomialComplex(toComplex(nExpr), toComplex(kExpr)),
    );
  }
  if (nExpr is RealNumeric &&
      kExpr is RealNumeric &&
      (nExpr is RealNumber || kExpr is RealNumber)) {
    final res = evalRealBinomial(nExpr.toDouble(), kExpr.toDouble());
    return res.isNaN ? Constant.undefined : RealNumber.fromDouble(res);
  }
  if (kExpr is Number && kExpr.isZero) {
    return (nExpr is RealNumber || kExpr is RealNumber)
        ? const RealNumber(1.0)
        : IntegerNumber.one;
  }
  if (kExpr is Number && kExpr.isOne) {
    return kExpr is RealNumber
        ? simplifyMul([const RealNumber(1.0), nExpr], assumptions: assumptions)
        : nExpr;
  }
  if (nExpr == kExpr) {
    return nExpr is RealNumber ? const RealNumber(1.0) : IntegerNumber.one;
  }
  if (kExpr case IntegerNumber(:final value) when value.isNegative) {
    return nExpr is RealNumber ? const RealNumber(0.0) : IntegerNumber.zero;
  }
  if (nExpr case IntegerNumber(asInt: final n?) when n >= 0) {
    if (kExpr case IntegerNumber(asInt: final k?)) {
      if (k < 0 || k > n) return IntegerNumber.zero;
      final m = k < n - k ? k : n - k;
      if (m <= 1000) {
        return IntegerNumber(Integer.from(n).binomial(Integer.from(k)));
      }
    }
  }
  if (nExpr case IntegerNumber(:final value) when value.isNegative) {
    if (kExpr case IntegerNumber(asInt: final k?) when k >= 0 && k <= 1000) {
      final binom = (-value + Integer.from(k) - Integer.one).binomial(
        Integer.from(k),
      );
      return IntegerNumber(k.isEven ? binom : -binom);
    }
  }
  return Binomial(nExpr, kExpr, isSimplified: true);
}

bool isFloatComplex(Expr expr) =>
    expr is ComplexNumber &&
    (expr.real is RealNumber || expr.imaginary is RealNumber);

bool isFloatComplexPair(Expr a, Expr b) =>
    a is Number &&
    b is Number &&
    (isFloatComplex(a) ||
        isFloatComplex(b) ||
        ((a is ComplexNumber || b is ComplexNumber) &&
            (a is RealNumber || b is RealNumber)));

Complex toComplex(Expr expr) => switch (expr) {
  ComplexNumber(:final real, :final imaginary) => Complex(
    real.toDouble(),
    imaginary.toDouble(),
  ),
  RealNumeric() => Complex(expr.toDouble()),
  _ => const Complex(double.nan, double.nan),
};

Expr complexToExpr(Complex c) {
  if (c.isNaN) return Constant.undefined;
  final re = c.a.toDouble();
  final im = c.b.toDouble();
  if (!re.isFinite || !im.isFinite) return Constant.undefined;
  if (im == 0.0) return RealNumber.fromDouble(re);
  return ComplexNumber.of(RealNumber(re), RealNumber(im));
}
