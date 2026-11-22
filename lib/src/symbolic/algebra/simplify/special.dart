import 'package:more/number.dart' show Complex;

import '../../../special/bessel.dart' as special_bessel;
import '../../../special/beta.dart' as special_beta;
import '../../../special/binomial.dart' as special_binomial;
import '../../../special/digamma.dart' as special_digamma;
import '../../../special/elliptic.dart' as special_elliptic;
import '../../../special/erf.dart' as special_erf;
import '../../../special/exp_integral.dart' as special_exp_int;
import '../../../special/factorial.dart' as special_factorial;
import '../../../special/fresnel.dart' as special_fresnel;
import '../../../special/gamma.dart' as special_gamma;
import '../../../special/hypergeometric.dart' as special_hyper;
import '../../../special/lambert_w.dart' as special_lambert;
import '../../../special/polylog.dart' as special_polylog;
import '../../../special/trig_integral.dart' as special_trig_int;
import '../../../special/zeta.dart' as special_zeta;
import '../../assumptions.dart';
import '../../ast.dart';
import '../../calculus/summation.dart' show evenZetaValue;
import '../../compiler/evaluator.dart';
import '../../number/integer.dart';
import '../simplify.dart';
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
  if (_isFloatComplex(expr)) {
    return _complexToExpr(
      special_lambert.lambertWComplex(_toComplex(expr), branch: branch),
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
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_erf.erfComplex(_toComplex(expr)));
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
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_erf.erfcComplex(_toComplex(expr)));
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
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_gamma.gammaComplex(_toComplex(expr)));
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
    if (_isFloatComplex(expr) ||
        _isFloatComplex(shift) ||
        ((expr is RealNumber || shift is RealNumber) &&
            expr is Number &&
            shift is Number)) {
      if (expr is RealNumber && shift is RealNumber) {
        final v = special_zeta.hurwitzZeta(expr.value, shift.value);
        if (!v.isNaN) return RealNumber.fromDouble(v);
      }
      return _complexToExpr(
        special_zeta.hurwitzZetaComplex(_toComplex(expr), _toComplex(shift)),
      );
    }
    if (expr == IntegerNumber.one) return Constant.undefined;
    return Zeta(expr, shift: shift, isSimplified: true);
  }
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_zeta.zetaComplex(_toComplex(expr)));
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
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_digamma.digammaComplex(_toComplex(expr)));
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
      _isFloatComplex(x)) {
    return _complexToExpr(
      special_digamma.polygammaComplex(m.asInt!, _toComplex(x)),
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
  if (_isFloatComplexPair(nu, x)) {
    return _complexToExpr(
      special_bessel.besselJComplex(_toComplex(nu), _toComplex(x)),
    );
  }
  if (x == IntegerNumber.zero) {
    if (nu == IntegerNumber.zero) return IntegerNumber.one;
    if (nu is RealNumeric && !nu.isNegative) return IntegerNumber.zero;
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
  if (_isFloatComplexPair(nu, x)) {
    return _complexToExpr(
      special_bessel.besselYComplex(_toComplex(nu), _toComplex(x)),
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
  if (_isFloatComplexPair(nu, x)) {
    return _complexToExpr(
      special_bessel.besselIComplex(_toComplex(nu), _toComplex(x)),
    );
  }
  if (x == IntegerNumber.zero) {
    if (nu == IntegerNumber.zero) return IntegerNumber.one;
    if (nu is RealNumeric && !nu.isNegative) return IntegerNumber.zero;
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
  if (_isFloatComplexPair(nu, x)) {
    return _complexToExpr(
      special_bessel.besselKComplex(_toComplex(nu), _toComplex(x)),
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

/// Simplifies a complete elliptic integral of the first kind `ellipticK(k)`.
Expr simplifyEllipticK(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_elliptic.ellipticKComplex(_toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) {
    return simplifyMul([
      FractionNumber.half,
      Constant.pi,
    ], assumptions: assumptions);
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_elliptic.ellipticK(expr.value));
  }
  return EllipticK(expr, isSimplified: true);
}

/// Simplifies a complete or incomplete elliptic integral of the second kind
/// `ellipticE(k)` or `ellipticE(k, amplitude: phi)`.
Expr simplifyEllipticE(
  Expr expr, {
  Expr? amplitude,
  required Assumptions assumptions,
}) {
  if (expr == Constant.undefined || amplitude == Constant.undefined) {
    return Constant.undefined;
  }
  if (amplitude != null) {
    if (_isFloatComplexPair(amplitude, expr)) {
      return _complexToExpr(
        special_elliptic.ellipticEComplex(
          _toComplex(expr),
          phi: _toComplex(amplitude),
        ),
      );
    }
    if (amplitude == IntegerNumber.zero) return IntegerNumber.zero;
    if (expr == IntegerNumber.zero) return amplitude;
    if (amplitude ==
        simplifyMul([
          FractionNumber.half,
          Constant.pi,
        ], assumptions: assumptions)) {
      return simplifyEllipticE(expr, assumptions: assumptions);
    }
    if (amplitude is RealNumber && expr is RealNumber) {
      return RealNumber.fromDouble(
        special_elliptic.ellipticE(expr.value, phi: amplitude.value),
      );
    }
    return EllipticE(expr, amplitude: amplitude, isSimplified: true);
  }
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_elliptic.ellipticEComplex(_toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) {
    return simplifyMul([
      FractionNumber.half,
      Constant.pi,
    ], assumptions: assumptions);
  }
  if (expr == IntegerNumber.one) {
    return IntegerNumber.one;
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_elliptic.ellipticE(expr.value));
  }
  return EllipticE(expr, isSimplified: true);
}

/// Simplifies an imaginary error function `erfi(x)`.
Expr simplifyErfi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_erf.erfiComplex(_toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_erf.erfi(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyErfi(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return Erfi(expr, isSimplified: true);
}

/// Simplifies a Fresnel sine integral `fresnelS(x)`.
Expr simplifyFresnelS(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_fresnel.fresnelSComplex(_toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_fresnel.fresnelS(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyFresnelS(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return FresnelS(expr, isSimplified: true);
}

/// Simplifies a Fresnel cosine integral `fresnelC(x)`.
Expr simplifyFresnelC(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_fresnel.fresnelCComplex(_toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_fresnel.fresnelC(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifyFresnelC(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return FresnelC(expr, isSimplified: true);
}

/// Simplifies an exponential integral `Ei(x)`.
Expr simplifyExpIntegralEi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_exp_int.expIntegralComplex(_toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_exp_int.expIntegral(expr.value));
  }
  return ExpIntegral(expr, isSimplified: true);
}

/// Simplifies a logarithmic integral `li(x)`.
Expr simplifyLogIntegralLi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_exp_int.logIntegralComplex(_toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_exp_int.logIntegral(expr.value));
  }
  return LogIntegral(expr, isSimplified: true);
}

/// Simplifies a sine integral `Si(x)`.
Expr simplifySinIntegralSi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(
      special_trig_int.sinIntegralComplex(_toComplex(expr)),
    );
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.sinIntegral(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySinIntegralSi(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return SinIntegral(expr, isSimplified: true);
}

/// Simplifies a cosine integral `Ci(x)`.
Expr simplifyCosIntegralCi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(
      special_trig_int.cosIntegralComplex(_toComplex(expr)),
    );
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.cosIntegral(expr.value));
  }
  return CosIntegral(expr, isSimplified: true);
}

/// Simplifies a hyperbolic sine integral `Shi(x)`.
Expr simplifySinhIntegralShi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(
      special_trig_int.sinhIntegralComplex(_toComplex(expr)),
    );
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.sinhIntegral(expr.value));
  }
  final (posExpr, isNeg) = extractSign(expr);
  if (isNeg) {
    return simplifyNeg(
      simplifySinhIntegralShi(posExpr, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  return SinhIntegral(expr, isSimplified: true);
}

/// Simplifies a hyperbolic cosine integral `Chi(x)`.
Expr simplifyCoshIntegralChi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (_isFloatComplex(expr)) {
    return _complexToExpr(
      special_trig_int.coshIntegralComplex(_toComplex(expr)),
    );
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.coshIntegral(expr.value));
  }
  return CoshIntegral(expr, isSimplified: true);
}

/// Simplifies an upper incomplete gamma function `upperGamma(s, x)`.
Expr simplifyUpperGamma(Expr s, Expr x, {required Assumptions assumptions}) {
  if (s == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (_isFloatComplexPair(s, x)) {
    return _complexToExpr(
      special_gamma.upperGammaComplex(_toComplex(s), _toComplex(x)),
    );
  }
  if (x == IntegerNumber.zero && s is RealNumeric && s.sign > 0) {
    return simplifyGamma(s, assumptions: assumptions);
  }
  if (s == IntegerNumber.one) {
    return simplifyPow(
      Constant.e,
      simplifyNeg(x, assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (s is RealNumber && x is RealNumber) {
    return RealNumber.fromDouble(special_gamma.upperGamma(s.value, x.value));
  }
  return UpperGamma(s, x, isSimplified: true);
}

/// Simplifies a lower incomplete gamma function `lowerGamma(s, x)`.
Expr simplifyLowerGamma(Expr s, Expr x, {required Assumptions assumptions}) {
  if (s == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (_isFloatComplexPair(s, x)) {
    return _complexToExpr(
      special_gamma.lowerGammaComplex(_toComplex(s), _toComplex(x)),
    );
  }
  if (x == IntegerNumber.zero && s is RealNumeric && s.sign > 0) {
    return IntegerNumber.zero;
  }
  if (s == IntegerNumber.one) {
    return simplifyAdd([
      IntegerNumber.one,
      simplifyNeg(
        simplifyPow(
          Constant.e,
          simplifyNeg(x, assumptions: assumptions),
          assumptions: assumptions,
        ),
        assumptions: assumptions,
      ),
    ], assumptions: assumptions);
  }
  if (s is RealNumber && x is RealNumber) {
    return RealNumber.fromDouble(special_gamma.lowerGamma(s.value, x.value));
  }
  return LowerGamma(s, x, isSimplified: true);
}

/// Simplifies a polylogarithm `polylog(s, z)`.
Expr simplifyPolylog(Expr s, Expr z, {required Assumptions assumptions}) {
  if (s == Constant.undefined || z == Constant.undefined) {
    return Constant.undefined;
  }
  if (_isFloatComplexPair(s, z)) {
    return _complexToExpr(
      special_polylog.polylogComplex(_toComplex(s), _toComplex(z)),
    );
  }
  if (z == IntegerNumber.zero) return IntegerNumber.zero;
  if (s == IntegerNumber.one) {
    return simplifyNeg(
      simplifyLn(
        simplifyAdd([
          IntegerNumber.one,
          simplifyNeg(z, assumptions: assumptions),
        ], assumptions: assumptions),
        assumptions: assumptions,
      ),
      assumptions: assumptions,
    );
  }
  if (s == IntegerNumber.zero) {
    return simplifyDiv(
      z,
      simplifyAdd([
        IntegerNumber.one,
        simplifyNeg(z, assumptions: assumptions),
      ], assumptions: assumptions),
      assumptions: assumptions,
    );
  }
  if (z == IntegerNumber.one && s is RealNumeric && s.toDouble() > 1.0) {
    return simplifyZeta(s);
  }
  if (z == IntegerNumber.negativeOne &&
      s is RealNumeric &&
      s.toDouble() > 1.0) {
    final zetaVal = simplifyZeta(s);
    if (zetaVal is! Zeta) {
      return simplifyMul([
        simplifyAdd([
          simplifyPow(
            IntegerNumber.two,
            simplifyAdd([
              IntegerNumber.one,
              simplifyNeg(s, assumptions: assumptions),
            ], assumptions: assumptions),
            assumptions: assumptions,
          ),
          IntegerNumber.negativeOne,
        ], assumptions: assumptions),
        zetaVal,
      ], assumptions: assumptions);
    }
  }
  if (s is RealNumber && z is RealNumber) {
    return RealNumber.fromDouble(special_polylog.polylog(s.value, z.value));
  }
  return Polylog(s, z, isSimplified: true);
}

/// Simplifies an incomplete elliptic integral of the first kind `ellipticF(phi, k)`.
Expr simplifyEllipticF(Expr phi, Expr k, {required Assumptions assumptions}) {
  if (phi == Constant.undefined || k == Constant.undefined) {
    return Constant.undefined;
  }
  if (_isFloatComplexPair(phi, k)) {
    return _complexToExpr(
      special_elliptic.ellipticFComplex(_toComplex(phi), _toComplex(k)),
    );
  }
  if (phi == IntegerNumber.zero) return IntegerNumber.zero;
  if (k == IntegerNumber.zero) return phi;
  if (phi ==
      simplifyMul([
        FractionNumber.half,
        Constant.pi,
      ], assumptions: assumptions)) {
    return simplifyEllipticK(k, assumptions: assumptions);
  }
  if (phi is RealNumber && k is RealNumber) {
    return RealNumber.fromDouble(
      special_elliptic.ellipticF(phi.value, k.value),
    );
  }
  return EllipticF(phi, k, isSimplified: true);
}

/// Simplifies an incomplete elliptic integral of the second kind `ellipticE(phi, k)`.
/// Simplifies an incomplete elliptic integral of the third kind $\Pi(n; \phi \mid k)$.
Expr simplifyEllipticPi(
  Expr n,
  Expr phi,
  Expr k, {
  required Assumptions assumptions,
}) {
  if (n == Constant.undefined ||
      phi == Constant.undefined ||
      k == Constant.undefined) {
    return Constant.undefined;
  }
  if (phi == IntegerNumber.zero) return IntegerNumber.zero;
  if (n == IntegerNumber.zero) {
    return simplifyEllipticF(phi, k, assumptions: assumptions);
  }
  if (_isFloatComplex(n) || _isFloatComplex(phi) || _isFloatComplex(k)) {
    if ((n is RealNumeric || _isFloatComplex(n)) &&
        (phi is RealNumeric || _isFloatComplex(phi)) &&
        (k is RealNumeric || _isFloatComplex(k))) {
      return _complexToExpr(
        special_elliptic.ellipticPiComplex(
          _toComplex(n),
          _toComplex(k),
          phi: _toComplex(phi),
        ),
      );
    }
  }
  if (n is RealNumeric &&
      phi is RealNumeric &&
      k is RealNumeric &&
      (n is RealNumber || phi is RealNumber || k is RealNumber)) {
    final val = special_elliptic.ellipticPi(
      n.toDouble(),
      k.toDouble(),
      phi: phi.toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
    return _complexToExpr(
      special_elliptic.ellipticPiComplex(
        _toComplex(n),
        _toComplex(k),
        phi: _toComplex(phi),
      ),
    );
  }
  return EllipticPi(n, phi, k, isSimplified: true);
}

/// Simplifies a generalized exponential integral `E_n(z)`.
Expr simplifyExpIntegralE(Expr n, Expr z) {
  if (n == Constant.undefined || z == Constant.undefined) {
    return Constant.undefined;
  }
  if (n is Number && n.isZero) {
    return (Pow(Constant.e, -z) / z).simplify();
  }
  if (n is Number && z is Number && (n is RealNumber || z is RealNumber)) {
    if (_isFloatComplex(n) || _isFloatComplex(z)) {
      return _complexToExpr(
        special_exp_int.expIntegralEComplex(_toComplex(n), _toComplex(z)),
      );
    }
    final val = special_exp_int.expIntegralE(
      (n as RealNumeric).toDouble(),
      (z as RealNumeric).toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
    return _complexToExpr(
      special_exp_int.expIntegralEComplex(_toComplex(n), _toComplex(z)),
    );
  }
  return ExpIntegralE(n, z, isSimplified: true);
}

/// Simplifies a generalized hypergeometric function `pFq(upper; lower; z)`.
Expr simplifyHypergeometric(List<Expr> upper, List<Expr> lower, Expr z) {
  if (z == Constant.undefined ||
      upper.any((e) => e == Constant.undefined) ||
      lower.any((e) => e == Constant.undefined)) {
    return Constant.undefined;
  }
  if (z is Number && z.isZero) return IntegerNumber.one;
  if (upper.any((e) => e is Number && e.isZero)) return IntegerNumber.one;

  // Cancel identical upper and lower parameters.
  final remUpper = <Expr>[];
  final remLower = List<Expr>.from(lower);
  for (final u in upper) {
    final idx = remLower.indexOf(u);
    if (idx != -1) {
      remLower.removeAt(idx);
    } else {
      remUpper.add(u);
    }
  }

  if (z is Number &&
      remUpper.every((e) => e is Number) &&
      remLower.every((e) => e is Number) &&
      (z is RealNumber ||
          remUpper.any((e) => e is RealNumber) ||
          remLower.any((e) => e is RealNumber))) {
    if (_isFloatComplex(z) ||
        remUpper.any(_isFloatComplex) ||
        remLower.any(_isFloatComplex)) {
      return _complexToExpr(
        special_hyper.hypergeometricPFQComplex(
          remUpper.map(_toComplex).toList(),
          remLower.map(_toComplex).toList(),
          _toComplex(z),
        ),
      );
    }
    final val = special_hyper.hypergeometricPFQ(
      remUpper.map((e) => (e as RealNumeric).toDouble()).toList(),
      remLower.map((e) => (e as RealNumeric).toDouble()).toList(),
      (z as RealNumeric).toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
  }

  return Hypergeometric(remUpper, remLower, z, isSimplified: true);
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
        final takeA = isMin
            ? a.toDouble() < bestNum.toDouble()
            : a.toDouble() > bestNum.toDouble();
        if (takeA) bestNum = a;
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

/// Simplifies an Euler beta function expression `beta(a, b)`.
Expr simplifyBeta(Expr a, Expr b, {required Assumptions assumptions}) {
  if (a == Constant.undefined || b == Constant.undefined) {
    return Constant.undefined;
  }
  if (_isFloatComplexPair(a, b)) {
    return _complexToExpr(
      special_beta.betaComplex(_toComplex(a), _toComplex(b)),
    );
  }
  if (a is RealNumeric &&
      b is RealNumeric &&
      (a is RealNumber || b is RealNumber)) {
    final da = a.toDouble();
    final db = b.toDouble();
    if (da <= 0.0 || db <= 0.0) return Constant.undefined;
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
  if (_isFloatComplex(expr)) {
    return _complexToExpr(special_factorial.factorialComplex(_toComplex(expr)));
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
  if (_isFloatComplexPair(nExpr, kExpr)) {
    return _complexToExpr(
      special_binomial.binomialComplex(_toComplex(nExpr), _toComplex(kExpr)),
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

bool _isFloatComplex(Expr expr) =>
    expr is ComplexNumber &&
    (expr.real is RealNumber || expr.imaginary is RealNumber);

bool _isFloatComplexPair(Expr a, Expr b) =>
    a is Number &&
    b is Number &&
    (_isFloatComplex(a) ||
        _isFloatComplex(b) ||
        ((a is ComplexNumber || b is ComplexNumber) &&
            (a is RealNumber || b is RealNumber)));

Complex _toComplex(Expr expr) => switch (expr) {
  ComplexNumber(:final real, :final imaginary) => Complex(
    real.toDouble(),
    imaginary.toDouble(),
  ),
  RealNumeric() => Complex(expr.toDouble()),
  _ => const Complex(double.nan, double.nan),
};

Expr _complexToExpr(Complex c) {
  if (c.isNaN) return Constant.undefined;
  final re = c.a.toDouble();
  final im = c.b.toDouble();
  if (!re.isFinite || !im.isFinite) return Constant.undefined;
  if (im == 0.0) return RealNumber.fromDouble(re);
  return ComplexNumber.of(RealNumber(re), RealNumber(im));
}
