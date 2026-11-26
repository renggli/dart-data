import '../../../special/elliptic.dart' as special_elliptic;
import '../../../special/erf.dart' as special_erf;
import '../../../special/exp_integral.dart' as special_exp_int;
import '../../../special/fresnel.dart' as special_fresnel;
import '../../../special/gamma.dart' as special_gamma;
import '../../../special/hypergeometric.dart' as special_hyper;
import '../../../special/polylog.dart' as special_polylog;
import '../../../special/trig_integral.dart' as special_trig_int;
import '../../assumptions.dart';
import '../../ast.dart';
import '../simplify.dart';
import 'additive.dart';
import 'multiplicative.dart';
import 'power.dart';
import 'special.dart'
    show
        complexToExpr,
        isFloatComplex,
        isFloatComplexPair,
        simplifyGamma,
        simplifyZeta,
        toComplex;
import 'transcendental.dart';

Expr simplifyEllipticK(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_elliptic.ellipticKComplex(toComplex(expr)));
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
    if (isFloatComplexPair(amplitude, expr)) {
      return complexToExpr(
        special_elliptic.ellipticEComplex(
          toComplex(expr),
          phi: toComplex(amplitude),
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
    if (amplitude is RealNumeric &&
        expr is RealNumeric &&
        (amplitude is RealNumber || expr is RealNumber)) {
      return RealNumber.fromDouble(
        special_elliptic.ellipticE(expr.toDouble(), phi: amplitude.toDouble()),
      );
    }
    return EllipticE(expr, amplitude: amplitude, isSimplified: true);
  }
  if (isFloatComplex(expr)) {
    return complexToExpr(special_elliptic.ellipticEComplex(toComplex(expr)));
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
  if (isFloatComplex(expr)) {
    return complexToExpr(special_erf.erfiComplex(toComplex(expr)));
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
  if (isFloatComplex(expr)) {
    return complexToExpr(special_fresnel.fresnelSComplex(toComplex(expr)));
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
  if (isFloatComplex(expr)) {
    return complexToExpr(special_fresnel.fresnelCComplex(toComplex(expr)));
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
  if (expr == IntegerNumber.zero) {
    return Mul(const [
      IntegerNumber.negativeOne,
      Constant.infinity,
    ], isSimplified: true);
  }
  if (expr == Constant.infinity) return Constant.infinity;
  if (expr case Mul(
    factors: [IntegerNumber(isNegativeOne: true), Constant.infinity],
  )) {
    return IntegerNumber.zero;
  }
  if (isFloatComplex(expr)) {
    return complexToExpr(special_exp_int.expIntegralComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_exp_int.expIntegral(expr.value));
  }
  return ExpIntegral(expr, isSimplified: true);
}

/// Simplifies a logarithmic integral `li(x)`.
Expr simplifyLogIntegralLi(Expr expr) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_exp_int.logIntegralComplex(toComplex(expr)));
  }
  if (expr == IntegerNumber.zero) return IntegerNumber.zero;
  if (expr == IntegerNumber.one) {
    return Mul(const [
      IntegerNumber.negativeOne,
      Constant.infinity,
    ], isSimplified: true);
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_exp_int.logIntegral(expr.value));
  }
  return LogIntegral(expr, isSimplified: true);
}

/// Simplifies a sine integral `Si(x)`.
Expr simplifySinIntegralSi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.sinIntegralComplex(toComplex(expr)));
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
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.cosIntegralComplex(toComplex(expr)));
  }
  if (expr is RealNumber) {
    return RealNumber.fromDouble(special_trig_int.cosIntegral(expr.value));
  }
  return CosIntegral(expr, isSimplified: true);
}

/// Simplifies a hyperbolic sine integral `Shi(x)`.
Expr simplifySinhIntegralShi(Expr expr, {required Assumptions assumptions}) {
  if (expr == Constant.undefined) return Constant.undefined;
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.sinhIntegralComplex(toComplex(expr)));
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
  if (isFloatComplex(expr)) {
    return complexToExpr(special_trig_int.coshIntegralComplex(toComplex(expr)));
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
  if (isFloatComplexPair(s, x)) {
    return complexToExpr(
      special_gamma.upperGammaComplex(toComplex(s), toComplex(x)),
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
  if (s is RealNumeric &&
      x is RealNumeric &&
      (s is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_gamma.upperGamma(s.toDouble(), x.toDouble()),
    );
  }
  return UpperGamma(s, x, isSimplified: true);
}

/// Simplifies a lower incomplete gamma function `lowerGamma(s, x)`.
Expr simplifyLowerGamma(Expr s, Expr x, {required Assumptions assumptions}) {
  if (s == Constant.undefined || x == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(s, x)) {
    return complexToExpr(
      special_gamma.lowerGammaComplex(toComplex(s), toComplex(x)),
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
  if (s is RealNumeric &&
      x is RealNumeric &&
      (s is RealNumber || x is RealNumber)) {
    return RealNumber.fromDouble(
      special_gamma.lowerGamma(s.toDouble(), x.toDouble()),
    );
  }
  return LowerGamma(s, x, isSimplified: true);
}

/// Simplifies a polylogarithm `polylog(s, z)`.
Expr simplifyPolylog(Expr s, Expr z, {required Assumptions assumptions}) {
  if (s == Constant.undefined || z == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(s, z)) {
    return complexToExpr(
      special_polylog.polylogComplex(toComplex(s), toComplex(z)),
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
  if (s is RealNumeric &&
      z is RealNumeric &&
      (s is RealNumber || z is RealNumber)) {
    return RealNumber.fromDouble(
      special_polylog.polylog(s.toDouble(), z.toDouble()),
    );
  }
  return Polylog(s, z, isSimplified: true);
}

/// Simplifies an incomplete elliptic integral of the first kind `ellipticF(phi, k)`.
Expr simplifyEllipticF(Expr phi, Expr k, {required Assumptions assumptions}) {
  if (phi == Constant.undefined || k == Constant.undefined) {
    return Constant.undefined;
  }
  if (isFloatComplexPair(phi, k)) {
    return complexToExpr(
      special_elliptic.ellipticFComplex(toComplex(phi), toComplex(k)),
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
  if (phi is RealNumeric &&
      k is RealNumeric &&
      (phi is RealNumber || k is RealNumber)) {
    return RealNumber.fromDouble(
      special_elliptic.ellipticF(phi.toDouble(), k.toDouble()),
    );
  }
  return EllipticF(phi, k, isSimplified: true);
}

/// Simplifies an incomplete elliptic integral of the second kind `ellipticE(phi, k)`.
/// Simplifies an incomplete elliptic integral of the third kind `Pi(n; phi | k)`.
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
  if (isFloatComplex(n) || isFloatComplex(phi) || isFloatComplex(k)) {
    if ((n is RealNumeric || isFloatComplex(n)) &&
        (phi is RealNumeric || isFloatComplex(phi)) &&
        (k is RealNumeric || isFloatComplex(k))) {
      return complexToExpr(
        special_elliptic.ellipticPiComplex(
          toComplex(n),
          toComplex(k),
          phi: toComplex(phi),
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
    return complexToExpr(
      special_elliptic.ellipticPiComplex(
        toComplex(n),
        toComplex(k),
        phi: toComplex(phi),
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
  if (z is Number && z.isZero) {
    if (n is RationalNumber && n.compareTo(IntegerNumber.one) > 0) {
      return (IntegerNumber.one / (n - IntegerNumber.one)).simplify();
    }
    if (n is RealNumeric && n.toDouble() <= 1.0) {
      return Constant.undefined;
    }
  }
  if (n is Number && z is Number && (n is RealNumber || z is RealNumber)) {
    if (n is ComplexNumber || z is ComplexNumber) {
      return complexToExpr(
        special_exp_int.expIntegralEComplex(toComplex(n), toComplex(z)),
      );
    }
    final val = special_exp_int.expIntegralE(
      (n as RealNumeric).toDouble(),
      (z as RealNumeric).toDouble(),
    );
    if (!val.isNaN) return RealNumber.fromDouble(val);
    return complexToExpr(
      special_exp_int.expIntegralEComplex(toComplex(n), toComplex(z)),
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
  if (upper.any((e) => e is Number && e.isZero)) {
    if (lower.any((e) => e is IntegerNumber && (e.isNegative || e.isZero))) {
      return Constant.undefined;
    }
    return IntegerNumber.one;
  }

  // Cancel identical upper and lower parameters (skipping non-positive integer poles).
  final remUpper = <Expr>[];
  final remLower = List<Expr>.from(lower);
  for (final u in upper) {
    final isPole = u is IntegerNumber && (u.isNegative || u.isZero);
    final idx = isPole ? -1 : remLower.indexOf(u);
    if (idx != -1) {
      remLower.removeAt(idx);
    } else {
      remUpper.add(u);
    }
  }

  if (remUpper.isEmpty && remLower.isEmpty) {
    return Pow(Constant.e, z).simplify();
  }
  if (remUpper.length == 1 && remLower.isEmpty) {
    return Pow(IntegerNumber.one - z, -remUpper.first).simplify();
  }

  if (z is Number &&
      remUpper.every((e) => e is Number) &&
      remLower.every((e) => e is Number) &&
      (z is RealNumber ||
          remUpper.any((e) => e is RealNumber) ||
          remLower.any((e) => e is RealNumber))) {
    if (z is ComplexNumber ||
        remUpper.any((e) => e is ComplexNumber) ||
        remLower.any((e) => e is ComplexNumber)) {
      return complexToExpr(
        special_hyper.hypergeometricPFQComplex(
          remUpper.map(toComplex).toList(),
          remLower.map(toComplex).toList(),
          toComplex(z),
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
